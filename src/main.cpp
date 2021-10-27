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

#include "Deposition.hpp"
#include "DropletSizeModel.hpp"
#include "DropletTransport.hpp"
#include "InputParameters.hpp"
#include "NozzleVelocity.hpp"
#include "Serialization.hpp"
#include "WetBulbTemperature.hpp"
#include "WVProfile.hpp"
#include "CVodeError.hpp"

#include "CDM.hpp"

using namespace cdm;

static InputParameters ParseJSON(const std::string& filename)
{
    using json = nlohmann::ordered_json;
    InputParameters p;
    std::ifstream ifs;
    std::stringstream buffer;

    ifs.open(filename);
    buffer << ifs.rdbuf();
    json j = json::parse(buffer.str(),
                         /* callback */ nullptr,
                         /* allow_exceptions */ true,
                         /* ignore_comments */ true);
    
    from_json(j.front(), p);
    return p;
}

int main(int argc, char *argv[])
{
    InputParameters p;

    auto start = std::chrono::steady_clock::now();

    const std::string filename = argc > 1 ? argv[1] : "config.json";
    try {
        p = ParseJSON(filename);
    } catch (std::exception& e) {
        fmt::print("{}\n", e.what());
        return 1;
    }

    DropletSizeModel dsdmodel;
    if (p.dsdfit) {
        fmt::print("\n{:->{}}\n", "", 80);
        fmt::print("Droplet Size Distribution\n");
        fmt::print("{:->{}}\n\n", "", 80);

        bool rc = false;
        try {
            rc = dsdmodel.fit(p.dsd);
        } catch (const std::exception& e) {
            fmt::print("{}\n", e.what());
            return 1;
        }

        fmt::print("{}\n", dsdmodel.report());
        if (rc == false)
            return 1;
        
        const auto dsdparams = dsdmodel.params();
        fmt::print("\nParameters\n");
        fmt::print("a1 = {}\n", dsdparams.a1);
        fmt::print("a2 = {}\n", dsdparams.a2);
        fmt::print("d1 = {}\n", dsdparams.d1);
        fmt::print("d2 = {}\n", dsdparams.d2);
        fmt::print("k1 = {}\n", dsdparams.k1);

        fmt::print("\n{:<6} {:>6} {:>6}\n", "DD", "Obs.", "Pred.");
        for (const auto& xy : p.dsd) {
            fmt::print("{:<6} {:>6.2f} {:>6.2f}\n", xy.first, xy.second*100, dsdmodel.cdf(xy.first)*100);
        }
    }

    fmt::print("\n{:->{}}\n", "", 80);
    fmt::print("Wind Velocity Profile\n");
    fmt::print("{:->{}}\n\n", "", 80);

    double z0 = 0;
    double Uf = 0;
    double psipsipsi = 0;
    try {
        WindVelocityProfile wvp(p.wvu, p.wvT, p.psipsipsiMethod, p.hC);
        z0 = wvp.frictionHeight();
        Uf = wvp.frictionVelocity();
        psipsipsi = p.psipsipsi.value_or(0);
        if (wvp.psipsipsi().has_value())
            psipsipsi = wvp.psipsipsi().value();
    } catch (const std::exception& e) {
        fmt::print("Error: {}\n", e.what());
        return 1;
    }

    fmt::print("Uf  = {}\n", Uf); 
    fmt::print("z0  = {}\n", z0);
    fmt::print("ψψψ = {}\n", psipsipsi);

    fmt::print("\n{:->{}}\n", "", 80);
    fmt::print("Wet Bulb Temperature\n");
    fmt::print("{:->{}}\n\n", "", 80);
    
    double Twb = 0;
    double dTwb = 0;
    try {
        Twb = WetBulbTemperature(p.Tair, p.Patm, p.RH);
        dTwb = p.Tair - Twb; // Wet bulb T depression
    } catch (const std::exception& e) {
        fmt::print("Error: {}\n", e.what());
        return 1;
    }
    
    fmt::print("Twb  = {}\n", Twb);
    fmt::print("ΔTwb = {}\n", dTwb);

    fmt::print("\n{:->{}}\n", "", 80);
    fmt::print("Nozzle Velocity\n");
    fmt::print("{:->{}}\n\n", "", 80);

    double rhoL = 1. / ((p.xs0 / p.rhoS) + ((1. - p.xs0) / p.rhoW));
    NozzleVelocity nv(p.PN, p.thetaN, rhoL);

    fmt::print("vz1 = {}\n", nv.z[0]);
    fmt::print("vx1 = {}\n", nv.x[0]);
    fmt::print("vz2 = {}\n", nv.z[1]);
    fmt::print("vx2 = {}\n", nv.x[1]);
    fmt::print("vz3 = {}\n", nv.z[2]);
    fmt::print("vx3 = {}\n", nv.x[2]);

    fmt::print("\n{:->{}}\n", "", 80);
    fmt::print("Droplet Transport\n");
    fmt::print("{:->{}}\n\n", "", 80);

    fmt::print("{:<8} {:>10} {:>10} {:>10}\n", "DD", "Centerline", "Downwind", "Upwind");

    std::vector<double> dp(23, 0);
    std::array<std::vector<double>, 3> xdist;
    for (size_t i = 0; i < dp.size(); ++i) {
        dp[i] = p.dpmin * pow(p.dpmax/p.dpmin, i/22.);
        for (size_t j = 0; j < xdist.size(); ++j) { // Centerline, Downwind, Upwind
            try {
                xdist[j].emplace_back(DropletTransport(p.Tair, p.RH, dTwb, z0, Uf, p.rhoW, p.rhoS, p.xs0, p.hN, p.hC, nv.z[j], nv.x[j], dp.at(i), p.ddd));
            } catch (const std::exception& e) {
                fmt::print("Error: {}\n", e.what());
                return 1;
            }
        }
        fmt::print("{:<8.3f} {:>10.2f} {:>10.2f} {:>10.2f}\n", dp.at(i), xdist[0].back(), xdist[1].back(), xdist[2].back());
    }
    
    fmt::print("\n{:->{}}\n", "", 80);
    fmt::print("Deposition\n");
    fmt::print("{:->{}}\n\n", "", 80);

    try {
        if (p.dsdfit)
            Deposition(p.iar, p.xactive, p.FD, p.PL, p.dN, psipsipsi, rhoL, dp, xdist, p.dsd, &dsdmodel, p.dpmin, p.dpmax, p.Lmax, p.lambda);
        else
            Deposition(p.iar, p.xactive, p.FD, p.PL, p.dN, psipsipsi, rhoL, dp, xdist, p.dsd, nullptr, p.dpmin, p.dpmax, p.Lmax, p.lambda);
    } catch (const std::exception& e) {
        fmt::print("Error: {}\n", e.what());
        return 1;
    }

    auto end = std::chrono::steady_clock::now();
    fmt::print("\nElapsed: {} ms\n", std::chrono::duration_cast<std::chrono::milliseconds>(end - start).count());

    return 0;
}
