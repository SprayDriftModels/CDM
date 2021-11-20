// Copyright (c) 2021 John Buonagurio <jbuonagurio@exponent.com>

#include <algorithm>
#include <cstdarg>
#include <cstdio>
#include <exception>

#include <fmt/core.h>

#include <nlohmann/json.hpp>

#include "CDM.h"
#include "Deposition.hpp"
#include "DropletSizeModel.hpp"
#include "DropletTransport.hpp"
#include "Model.hpp"
#include "NozzleVelocity.hpp"
#include "Serialization.hpp"
#include "WetBulbTemperature.hpp"
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
    if (m->in.dsdfit) {
        m->out.dsmodel = std::make_unique<cdm::DropletSizeModel>(m->in.dsd);
        try {
            m->out.dsmodel->fit();
        } catch (const std::exception& e) {
            cdm_error_handler("[DropletSizeModel] %s\n", e.what());
            return 1;
        }
    }

    try {
        cdm::WindVelocityProfile wvp(m->in.wvu, m->in.wvT, m->in.pppMethod, m->in.hC);
        m->out.z0 = wvp.frictionHeight();
        m->out.Uf = wvp.frictionVelocity();
        m->out.ppp = wvp.psipsipsi();
    } catch (const std::exception& e) {
        cdm_error_handler("[WindVelocityProfile] %s\n", e.what());
        return 1;
    }
    
    try {
        m->out.Twb = cdm::WetBulbTemperature(m->in.Tair, m->in.Patm, m->in.RH);
        m->out.dTwb = m->in.Tair - m->out.Twb; // Wet bulb T depression
    } catch (const std::exception& e) {
        cdm_error_handler("[WetBulbTemperature] %s\n", e.what());
        return 1;
    }
    
    m->out.rhoL = 1. / ((m->in.xs0 / m->in.rhoS) + ((1. - m->in.xs0) / m->in.rhoW));
    cdm::NozzleVelocity nv(m->in.PN, m->in.thetaN, m->out.rhoL);
    m->out.nvz = nv.z;
    m->out.nvx = nv.x;

    m->out.dp.resize(23, 0);
    for (size_t i = 0; i < m->out.dp.size(); ++i) {
        m->out.dp[i] = m->in.dpmin * pow(m->in.dpmax/m->in.dpmin, i/22.);
        for (size_t j = 0; j < m->out.xdist.size(); ++j) { // Centerline, Downwind, Upwind
            try {
                m->out.xdist[j].emplace_back(cdm::DropletTransport(m->in.Tair, m->in.RH, m->out.dTwb,
                    m->out.z0, m->out.Uf, m->in.rhoW, m->in.rhoS, m->in.xs0, m->in.hN, m->in.hC,
                    m->out.nvz[j], m->out.nvx[j], m->out.dp.at(i), m->in.ddd));
            } catch (const std::exception& e) {
                cdm_error_handler("[DropletTransport] %s\n", e.what());
                return 1;
            }
        }
    }
    
    try {
        m->out.applume = cdm::Deposition(m->in.iar, m->in.xactive, m->in.FD, m->in.PL, m->in.dN,
            m->out.ppp, m->out.rhoL, m->out.dp, m->out.xdist, m->in.dsd, m->out.dsmodel,
            m->in.dpmin, m->in.dpmax, m->in.Lmax, m->in.lambda, m->in.dx);
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

    if (m->out.dsmodel) {
        print_header("Droplet Size Distribution");
        fmt::print("{}\n", m->out.dsmodel->report());
        const auto dsparams = m->out.dsmodel->params();
        fmt::print("\nParameters\n");
        fmt::print("a1 = {}\n", dsparams.a1);
        fmt::print("a2 = {}\n", dsparams.a2);
        fmt::print("d1 = {}\n", dsparams.d1);
        fmt::print("d2 = {}\n", dsparams.d2);
        fmt::print("k1 = {}\n", dsparams.k1);
        fmt::print("\n{:<6} {:>6} {:>6}\n", "DD", "Obs.", "Pred.");
        for (const auto& xy : m->in.dsd) {
            fmt::print("{:<6} {:>6.2f} {:>6.2f}\n", xy.first, xy.second*100, m->out.dsmodel->cdf(xy.first)*100);
        }
    }

    print_header("Wind Velocity Profile");
    fmt::print("Uf  = {}\n", m->out.Uf); 
    fmt::print("z0  = {}\n", m->out.z0);
    fmt::print("ψψψ = {}\n", m->out.ppp);

    print_header("Wet Bulb Temperature");
    fmt::print("Twb  = {}\n", m->out.Twb);
    fmt::print("ΔTwb = {}\n", m->out.dTwb);

    print_header("Droplet Transport");
    fmt::print("{:<8} {:>10} {:>10} {:>10}\n", "DD", "Centerline", "Downwind", "Upwind");
    for (size_t i = 0; i < m->out.dp.size(); ++i) {
        fmt::print("{:<8.3f} {:>10.2f} {:>10.2f} {:>10.2f}\n", m->out.dp.at(i),
            m->out.xdist[0].at(i), m->out.xdist[1].at(i), m->out.xdist[2].at(i));
    }

    print_header("Deposition");
    fmt::print("{:<8} {:>9}\n", "Distance", "APPlume");
    for (size_t i = 0; i < m->out.applume.size(); ++i) {
        fmt::print("{:<8.3f} {:>8.4f}%\n", m->out.applume.at(i).first, m->out.applume.at(i).second);
    }
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