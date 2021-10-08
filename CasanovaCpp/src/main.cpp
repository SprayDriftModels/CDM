#ifndef _USE_MATH_DEFINES
#define _USE_MATH_DEFINES
#endif

#include <array>
#include <chrono>
#include <cmath>
#include <iostream>
#include <fstream>
#include <sstream>
#include <memory>
#include <string>

#include <fmt/core.h>
#include <nlohmann/json.hpp>
#include <cvode/cvode.h>
#include <nvector/nvector_serial.h>
#include <sunlinsol/sunlinsol_dense.h>
#include <sunmatrix/sunmatrix_dense.h>

#include "Deposition.hpp"
#include "DropletSizeModel.hpp"
#include "DropletTransport.hpp"
#include "InputParameters.hpp"
#include "NozzleVelocity.hpp"
#include "Serialization.hpp"
#include "WetBulbTemperature.hpp"
#include "WVProfile.hpp"

#ifdef CDM_USE_IMGUI
#include "gui/PlotWindow.hpp"
#endif

using namespace cdm;

static std::vector<InputParameters> ParseJSON(const std::string& filename)
{
    using json = nlohmann::ordered_json;

    std::ifstream ifs;
    std::stringstream buffer;
    std::vector<InputParameters> result;

    try {
        ifs.open(filename);
        buffer << ifs.rdbuf();
        json j = json::parse(buffer.str(),
                             /* callback */ nullptr,
                             /* allow_exceptions */ true,
                             /* ignore_comments */ true);
        
        for (auto& element : j) {
            InputParameters p;
            from_json(element, p);
            result.push_back(p);
        }
    } catch (json::exception& e) {
        fmt::print(e.what());
    } catch (std::exception& e) {
        fmt::print(e.what());
    }

    return result;
}

int main(int argc, char *argv[])
{
    auto start = std::chrono::steady_clock::now();
    
    const std::vector<InputParameters> cases;
    const std::string filename = argc > 1 ? argv[1] : "config.json";
    const InputParameters p = ParseJSON(filename).front();

    DropletSizeModel dsdmodel;
    if (p.dsdfit)
    {
        fmt::print("\n{:->{}}\n", "", 80);
        fmt::print("Droplet Size Distribution\n");
        fmt::print("{:->{}}\n\n", "", 80);

        bool rc = dsdmodel.fit(p.dsd);
        fmt::print(dsdmodel.report());
        fmt::print("\n");
        if (rc == false)
            return 1;

        const auto dsdparams = dsdmodel.params();
        fmt::print("\nParameters\n");
        fmt::print("a1 = {}\n", dsdparams.a1);
        fmt::print("a2 = {}\n", dsdparams.a2);
        fmt::print("d1 = {}\n", dsdparams.d1);
        fmt::print("d2 = {}\n", dsdparams.d2);
        fmt::print("k1 = {}\n", dsdparams.k1);

        fmt::print("\n{:<6} {:>6} {:>6}\n", "x", "obs", "pred");
        for (const auto& xy : p.dsd) {
            fmt::print("{:<6} {:>6.2f} {:>6.2f}\n", xy.first, xy.second*100, dsdmodel.cdf(xy.first)*100);
        }
    }

    fmt::print("\n{:->{}}\n", "", 80);
    fmt::print("Wind Velocity Profile\n");
    fmt::print("{:->{}}\n\n", "", 80);

    WVProfileResult wvp;
    try {
        wvp = WVProfile(p.wvu, p.wvT, p.psipsipsiMethod, p.hC);
    } catch (const std::exception& e) {
        fmt::print("Error: {}\n", e.what());
        return 1;
    }
    
    double psipsipsi = p.psipsipsi.value_or(0);
    if (wvp.psipsipsi.has_value())
        psipsipsi = wvp.psipsipsi.value();
    
    fmt::print("Uf  = {}\n", wvp.Uf); 
    fmt::print("z0  = {}\n", wvp.z0);
    fmt::print("ψψψ = {}\n", psipsipsi);

    fmt::print("\n{:->{}}\n", "", 80);
    fmt::print("Wet Bulb Temperature\n");
    fmt::print("{:->{}}\n\n", "", 80);

    double Twb = 0;
    double dTwb = 0;
    try {
        Twb = WetBulbTemperature(p.Tair, p.Patm, p.RH);
        dTwb = p.Tair - Twb; // Wet bulb T depression
        fmt::print("Twb  = {}\n", Twb);
        fmt::print("ΔTwb = {}\n", dTwb);
    } catch (const std::exception& e) {
        fmt::print("Error: {}\n", e.what());
        return 1;
    }

    fmt::print("\n{:->{}}\n", "", 80);
    fmt::print("Nozzle Velocity\n");
    fmt::print("{:->{}}\n\n", "", 80);

    double rhoL = 1. / ((p.xs0 / p.rhoS) + ((1. - p.xs0) / p.rhoW));
    auto nv = NozzleVelocity(p.PN, p.thetaN, rhoL);
    fmt::print("vz1 = {}\n", nv.vz1);
    fmt::print("vx1 = {}\n", nv.vx1);
    fmt::print("vz2 = {}\n", nv.vz2);
    fmt::print("vx2 = {}\n", nv.vx2);
    fmt::print("vz3 = {}\n", nv.vz3);
    fmt::print("vx3 = {}\n", nv.vx3);

    std::array<double, 23> dp;
    for (size_t i = 0; i < dp.size(); ++i) {
        dp[i] = p.dpmin * pow(p.dpmax/p.dpmin, i/22.);
    }

    fmt::print("\n{:->{}}\n", "", 80);
    fmt::print("Droplet Transport\n");
    fmt::print("{:->{}}\n\n", "", 80);

    std::array<std::vector<std::pair<double, double>>, 3> xdist;
    fmt::print("{:<8} {:>10} {:>10} {:>10}\n", "DD", "Centerline", "Downwind", "Upwind");
    for (size_t i = 0; i < dp.size(); ++i) {
        try {
            double xdist1 = DropletTransport(p.Tair, p.RH, dTwb, wvp.z0, wvp.Uf, p.rhoW, p.rhoS, p.xs0, p.hN, p.hC, nv.vz1, nv.vx1, dp.at(i), p.ddd); // Centerline
            double xdist2 = DropletTransport(p.Tair, p.RH, dTwb, wvp.z0, wvp.Uf, p.rhoW, p.rhoS, p.xs0, p.hN, p.hC, nv.vz2, nv.vx2, dp.at(i), p.ddd); // Downwind
            double xdist3 = DropletTransport(p.Tair, p.RH, dTwb, wvp.z0, wvp.Uf, p.rhoW, p.rhoS, p.xs0, p.hN, p.hC, nv.vz3, nv.vx3, dp.at(i), p.ddd); // Upwind
            xdist.at(0).emplace_back(std::make_pair(dp.at(i), xdist1));
            xdist.at(1).emplace_back(std::make_pair(dp.at(i), xdist2));
            xdist.at(2).emplace_back(std::make_pair(dp.at(i), xdist3));
            fmt::print("{:<8.3f} {:>10.2f} {:>10.2f} {:>10.2f}\n", dp.at(i), xdist1, xdist2, xdist3);
        } catch (const std::exception& e) {
            fmt::print("CVODE Error: {}\n", e.what());
        }
    }

    fmt::print("\n{:->{}}\n", "", 80);
    fmt::print("Deposition\n");
    fmt::print("{:->{}}\n\n", "", 80);

    try {
        if (p.dsdfit) {
            Deposition(p.iar, p.xactive, p.fd, p.pl, p.dN, psipsipsi, rhoL, xdist, p.dsd, &dsdmodel, p.dpmin, p.dpmax, p.lmax, p.lambda);
        }
        else {
            Deposition(p.iar, p.xactive, p.fd, p.pl, p.dN, psipsipsi, rhoL, xdist, p.dsd, nullptr, p.dpmin, p.dpmax, p.lmax, p.lambda);
        }
    } catch (const std::exception& e) {
        fmt::print("Error: {}\n", e.what());
        return 1;
    }

    auto end = std::chrono::steady_clock::now();
    fmt::print("\nElapsed: {} ms\n", std::chrono::duration_cast<std::chrono::milliseconds>(end - start).count());

#ifdef CDM_USE_IMGUI
    std::vector<std::pair<double, double>> dsd1;
    for (double x = model.dpmin(); x < model.dpmax()+0.5/2; x += 0.5)
        dsd1.emplace_back(std::make_pair(x, model.cdf(x)));
    gui::ShowPlotWindow(p.dsd, dsd1);
#endif

    return 0;
}
