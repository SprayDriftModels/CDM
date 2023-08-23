// Copyright (c) 2021 John Buonagurio <jbuonagurio@exponent.com>

#include <algorithm>
#include <cstdarg>
#include <cstdio>
#include <exception>

#include <fmt/core.h>

#include <nlohmann/json.hpp>

#include "CDM.h"
#include "AtmosphericProperties.hpp"
#include "Deposition.hpp"
#include "DropletSizeModel.hpp"
#include "DropletTransport.hpp"
#include "Model.hpp"
#include "NozzleVelocity.hpp"
#include "Serialization.hpp"
#include "WindVelocityProfile.hpp"

static void cdm_default_error_handler(const char *format, ...)
{
    std::va_list ap;
    va_start(ap, format);
    vfprintf(stderr, format, ap);
    va_end(ap);
}

static cdm_error_handler_t cdm_error_handler = cdm_default_error_handler;

cdm_error_handler_t cdm_set_error_handler(cdm_error_handler_t handler)
{
    cdm_error_handler_t previous_handler = cdm_error_handler;
    cdm_error_handler = handler;
    return previous_handler;
}

cdm_model_t * cdm_create_model(const char *config)
{
    cdm::Model *m = new cdm::Model;

    try {
        auto j = nlohmann::ordered_json::parse(config,
                                               /* callback */ nullptr,
                                               /* allow_exceptions */ true,
                                               /* ignore_comments */ true);
        
        cdm::from_json(j, *m);
    }
    catch (std::exception& e) {
        cdm_error_handler("%s\n", e.what());
        delete m;
        return nullptr;
    }

    return reinterpret_cast<cdm_model_t *>(m);
}

void cdm_free_model(cdm_model_t *model)
{
    if (model)
        delete reinterpret_cast<cdm::Model *>(model);
}

int cdm_run_model(cdm_model_t *model)
{
    if (model == nullptr)
        return 1;
    
    cdm::Model *m = reinterpret_cast<cdm::Model *>(model);

    if (m->dsdfit) {
        m->dsmodel = std::make_unique<cdm::DropletSizeModel>(m->dsd);
        try {
            m->dsmodel->fit();
        } catch (const std::exception& e) {
            cdm_error_handler("[DropletSizeModel] %s\n", e.what());
            return 1;
        }
    }

    m->rhoL = 1. / ((m->xs0 / m->rhoS) + ((1. - m->xs0) / m->rhoW));

    try {
        cdm::AtmosphericProperties ap(m->Tair, m->Patm, m->RH);
        m->rhoA = ap.wetAirDensity();
        m->muA = ap.wetAirDynamicViscosity();
        m->Tdp = ap.dewPointTemperature();
        m->Twb = ap.wetBulbTemperature();
        m->dTwb = ap.wetBulbTemperatureDepression();
    } catch (const std::exception& e) {
        cdm_error_handler("[AtmosphericProperties] %s\n", e.what());
        return 1;
    }

    try {
        cdm::WindVelocityProfile wvp(m->wvu, m->wvT, m->pppMethod, m->hC);
        m->z0 = wvp.frictionHeight();
        m->Uf = wvp.frictionVelocity();
        if (m->pppMethod == cdm::PPPMethod::ENTERED)
            m->pppcalc = m->ppp.value_or(cdm::constants::default_psipsipsi);
        else
            m->pppcalc = wvp.psipsipsi();
    } catch (const std::exception& e) {
        cdm_error_handler("[WindVelocityProfile] %s\n", e.what());
        return 1;
    }
    
    cdm::NozzleVelocity nv(m->PN, m->thetaN, m->rhoL);
    m->nva = nv.angle;
    m->nvz = nv.z;
    m->nvx = nv.x;

    cdm::DropletTransport dt(*m);
    m->dp.resize(23, 0);
    for (size_t i = 0; i < m->dp.size(); ++i) {
        m->dp[i] = m->dpmin * pow(m->dpmax/m->dpmin, i/22.);
        for (size_t j = 0; j < m->xdist.size(); ++j) {
            try {
                double xdist = dt(m->nvz[j], m->nvx[j], m->dp.at(i));
                m->xdist[j].emplace_back(xdist);
            } catch (const std::exception& e) {
                cdm_error_handler("[DropletTransport] %s\n", e.what());
                return 1;
            }
        }
    }
    
    try {
        m->applume = cdm::Deposition(m->IAR, m->xactive, m->FD, m->PL, m->dN,
            m->pppcalc, m->rhoL, m->dp, m->xdist, m->dsd, m->dsmodel,
            m->dpmin, m->dpmax, m->Lmax, m->lambda, m->dx);
    } catch (const std::exception& e) {
        cdm_error_handler("[Deposition] %s\n", e.what());
        return 1;
    }

    return 0;
}

void cdm_print_report(cdm_model_t *model)
{
    cdm::Model *m = reinterpret_cast<cdm::Model *>(model);

    auto print_header = [](const std::string& header) {
        fmt::print("\n{:->{}}\n", "", 80);
        fmt::print("{}\n", header);
        fmt::print("{:->{}}\n\n", "", 80);
    };

    if (m->dsmodel) {
        print_header("Droplet Size Distribution");
        fmt::print("{}\n", m->dsmodel->report());
        const auto dsparams = m->dsmodel->params();
        fmt::print("\nParameters\n");
        fmt::print("μ1 = {}\n", dsparams.a1);
        fmt::print("μ2 = {}\n", dsparams.a2);
        fmt::print("σ1 = {}\n", dsparams.d1);
        fmt::print("σ2 = {}\n", dsparams.d2);
        fmt::print("w1 = {}\n", dsparams.k1);
        fmt::print("\n{:<6} {:>6} {:>6}\n", "DD", "Obs.", "Pred.");
        for (const auto& xy : m->dsd)
            fmt::print("{:<6} {:>6.2f} {:>6.2f}\n", xy.first, xy.second*100, m->dsmodel->cdf(xy.first)*100);
    }

    print_header("Atmospheric Properties");
    fmt::print("ρA = {}\n", m->rhoA);
    fmt::print("μA = {}\n", m->muA);
    fmt::print("Tdp = {}\n", m->Tdp);
    fmt::print("Twb = {}\n", m->Twb);
    fmt::print("ΔTwb = {}\n", m->dTwb);

    print_header("Wind Velocity Profile");
    fmt::print("Uf = {}\n", m->Uf); 
    fmt::print("z0 = {}\n", m->z0);
    fmt::print("ψψψ = {} ", m->pppcalc);
    switch (m->pppMethod) {
    case cdm::PPPMethod::ENTERED:
        fmt::print("(ENTERED)\n"); break;
    case cdm::PPPMethod::INTERPOLATE:
        fmt::print("(INTERPOLATE)\n"); break;
    case cdm::PPPMethod::SDTF:
        fmt::print("(SDTF)\n"); break;
    default:
        fmt::print("\n"); break;
    }

    print_header("Droplet Transport");
    fmt::print("{:<8} {:>10} {:>10}\n", "Angle", "Vx", "Vz");
    for (size_t i = 0; i < m->nva.size(); ++i)
        fmt::print("{:<8.3f} {:>10.2f} {:>10.2f}\n", m->nva.at(i), m->nvx.at(i), m->nvz.at(i));
    fmt::print("\n");
    fmt::print("{:<8} {:>10}\n", "DD", "Distance");
    for (size_t i = 0; i < m->dp.size(); ++i) {
        fmt::print("{:<8.3f}", m->dp.at(i));
        for (size_t j = 0; j < m->xdist.size(); ++j)
            fmt::print(" {:>10.2f}", m->xdist[j].at(i));
        fmt::print("\n");
    }

    print_header("Deposition");
    fmt::print("{:<8} {:>9}\n", "Distance", "APPlume");
    for (size_t i = 0; i < m->applume.size(); ++i)
        fmt::print("{:<8.3f} {:>8.4f}%\n", m->applume.at(i).first, m->applume.at(i).second);
}

char * cdm_get_output_string(cdm_model_t *model)
{
    using json = nlohmann::ordered_json;

    cdm::Model *m = reinterpret_cast<cdm::Model *>(model);
    std::string s;

    if (!m)
        return nullptr;

    try {
        nlohmann::ordered_json j(*m);
        s = j.dump();
    } catch (const std::exception& e) {
        cdm_error_handler("%s\n", e.what());
        return nullptr;
    }
    
    char *cs = new char[s.length() + 1];
    std::copy(s.begin(), s.end(), cs);
    cs[s.length()] = '\0';
    return cs;
}

void cdm_free_string(char *s)
{
    if (s)
        delete[] s;
}