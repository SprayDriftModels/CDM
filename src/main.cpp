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
#include "Model.hpp"
#include "NozzleVelocity.hpp"
#include "Serialization.hpp"
#include "WetBulbTemperature.hpp"
#include "WindVelocityProfile.hpp"
#include "CVodeError.hpp"

using namespace cdm;

static Model ParseJSON(const std::string& filename)
{
    using json = nlohmann::ordered_json;
    Model m;
    std::ifstream ifs;
    std::stringstream buffer;

    ifs.open(filename);
    buffer << ifs.rdbuf();
    json j = json::parse(buffer.str(),
                         /* callback */ nullptr,
                         /* allow_exceptions */ true,
                         /* ignore_comments */ true);
    
    from_json(j.front(), m.in);
    return m;
}

int main(int argc, char *argv[])
{
    Model m;

    auto start = std::chrono::steady_clock::now();

    const std::string filename = argc > 1 ? argv[1] : "config.json";
    try {
        m = ParseJSON(filename);
    } catch (std::exception& e) {
        fmt::print("{}\n", e.what());
        return 1;
    }

    DropletSizeModel dsdmodel;
    if (m.in.dsdfit) {
        fmt::print("\n{:->{}}\n", "", 80);
        fmt::print("Droplet Size Distribution\n");
        fmt::print("{:->{}}\n\n", "", 80);

        bool rc = false;
        try {
            rc = dsdmodel.fit(m.in.dsd);
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
        for (const auto& xy : m.in.dsd) {
            fmt::print("{:<6} {:>6.2f} {:>6.2f}\n", xy.first, xy.second*100, dsdmodel.cdf(xy.first)*100);
        }
    }

    fmt::print("\n{:->{}}\n", "", 80);
    fmt::print("Wind Velocity Profile\n");
    fmt::print("{:->{}}\n\n", "", 80);

    try {
        WindVelocityProfile wvp(m.in.wvu, m.in.wvT, m.in.pppMethod, m.in.hC);
        m.out.z0 = wvp.frictionHeight();
        m.out.Uf = wvp.frictionVelocity();
        m.out.ppp = m.in.ppp.value_or(0);
        if (wvp.ppp().has_value())
            m.out.ppp = wvp.ppp().value();
    } catch (const std::exception& e) {
        fmt::print("Error: {}\n", e.what());
        return 1;
    }

    fmt::print("Uf  = {}\n", m.out.Uf); 
    fmt::print("z0  = {}\n", m.out.z0);
    fmt::print("ψψψ = {}\n", m.out.ppp);

    fmt::print("\n{:->{}}\n", "", 80);
    fmt::print("Wet Bulb Temperature\n");
    fmt::print("{:->{}}\n\n", "", 80);
    
    try {
        m.out.Twb = WetBulbTemperature(m.in.Tair, m.in.Patm, m.in.RH);
        m.out.dTwb = m.in.Tair - m.out.Twb; // Wet bulb T depression
    } catch (const std::exception& e) {
        fmt::print("Error: {}\n", e.what());
        return 1;
    }
    
    fmt::print("Twb  = {}\n", m.out.Twb);
    fmt::print("ΔTwb = {}\n", m.out.dTwb);

    fmt::print("\n{:->{}}\n", "", 80);
    fmt::print("Nozzle Velocity\n");
    fmt::print("{:->{}}\n\n", "", 80);

    m.out.rhoL = 1. / ((m.in.xs0 / m.in.rhoS) + ((1. - m.in.xs0) / m.in.rhoW));
    NozzleVelocity nv(m.in.PN, m.in.thetaN, m.out.rhoL);

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

    m.out.dp.resize(23, 0);
    for (size_t i = 0; i < m.out.dp.size(); ++i) {
        m.out.dp[i] = m.in.dpmin * pow(m.in.dpmax/m.in.dpmin, i/22.);
        for (size_t j = 0; j < m.out.xdist.size(); ++j) { // Centerline, Downwind, Upwind
            try {
                m.out.xdist[j].emplace_back(DropletTransport(m.in.Tair, m.in.RH, m.out.dTwb,
                    m.out.z0, m.out.Uf, m.in.rhoW, m.in.rhoS, m.in.xs0, m.in.hN, m.in.hC,
                    nv.z[j], nv.x[j], m.out.dp.at(i), m.in.ddd));
            } catch (const std::exception& e) {
                fmt::print("Error: {}\n", e.what());
                return 1;
            }
        }
        fmt::print("{:<8.3f} {:>10.2f} {:>10.2f} {:>10.2f}\n", m.out.dp.at(i),
            m.out.xdist[0].back(), m.out.xdist[1].back(), m.out.xdist[2].back());
    }
    
    fmt::print("\n{:->{}}\n", "", 80);
    fmt::print("Deposition\n");
    fmt::print("{:->{}}\n\n", "", 80);

    try {
        if (m.in.dsdfit)
            Deposition(m.in.iar, m.in.xactive, m.in.FD, m.in.PL, m.in.dN,
                m.out.ppp, m.out.rhoL, m.out.dp, m.out.xdist, m.in.dsd, &dsdmodel,
                m.in.dpmin, m.in.dpmax, m.in.Lmax, m.in.lambda);
        else
            Deposition(m.in.iar, m.in.xactive, m.in.FD, m.in.PL, m.in.dN,
                m.out.ppp, m.out.rhoL, m.out.dp, m.out.xdist, m.in.dsd, nullptr,
                m.in.dpmin, m.in.dpmax, m.in.Lmax, m.in.lambda);
    } catch (const std::exception& e) {
        fmt::print("Error: {}\n", e.what());
        return 1;
    }

    auto end = std::chrono::steady_clock::now();
    fmt::print("\nElapsed: {} ms\n", std::chrono::duration_cast<std::chrono::milliseconds>(end - start).count());

    return 0;
}
