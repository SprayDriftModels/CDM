// Copyright (c) 2021 John Buonagurio <jbuonagurio@exponent.com>

#include <nlohmann/json.hpp>

#include "Serialization.hpp"

namespace cdm {

void to_json(nlohmann::ordered_json& j, const InputParameters& p)
{
    j = nlohmann::ordered_json{
        {"dropletSizeDistribution", p.dsd},
        {"dryAirTemperature", p.Tair},
        {"barometricPressure", p.Patm},
        {"relativeHumidity", p.RH},
        {"windVelocityProfile", {
            {"elevation1", p.z1},
            {"elevation2", p.z2},
            {"velocity1", p.ux1},
            {"velocity2", p.ux2}
        }},
        {"dropletTransport", {
            {"nozzleHeight", p.hN},
            {"canopyHeight", p.hC},
            {"nozzlePressure", p.PN},
            {"nozzleAngle", p.thetaN},
            {"waterDensity", p.rhoW},
            {"solidsDensity", p.rhoS},
            {"solidsFraction", p.xs0},
            {"ddd", p.ddd}
        }},
        {"deposition", {
            {"applicationRate", p.iar},
            {"concentrationAI", p.xactive},
            {"downwindFieldDepth", p.fd},
            {"crosswindFieldDepth", p.pl},
            {"nozzleSpacing", p.dN},
            {"windHorizontalVariation", p.psipsipsi},
            {"minDropletSize", p.dpmin},
            {"maxDropletSize", p.dpmax},
            {"lambda", p.lambda}
        }}
    };
}

void from_json(const nlohmann::ordered_json& j, InputParameters& p)
{
    j.at("dropletSizeDistribution").get_to(p.dsd);
    j.at("dryAirTemperature").get_to(p.Tair);
    j.at("barometricPressure").get_to(p.Patm);
    j.at("relativeHumidity").get_to(p.RH);
    auto j1 = j.at("windVelocityProfile");
    j1.at("elevation1").get_to(p.z1);
    j1.at("elevation2").get_to(p.z2);
    j1.at("velocity1").get_to(p.ux1);
    j1.at("velocity2").get_to(p.ux2);
    auto j2 = j.at("dropletTransport");
    j2.at("nozzleHeight").get_to(p.hN);
    j2.at("canopyHeight").get_to(p.hC);
    j2.at("nozzlePressure").get_to(p.PN);
    j2.at("nozzleAngle").get_to(p.thetaN);
    j2.at("waterDensity").get_to(p.rhoW);
    j2.at("solidsDensity").get_to(p.rhoS);
    j2.at("solidsFraction").get_to(p.xs0);
    j2.at("ddd").get_to(p.ddd);
    auto j3 = j.at("deposition");
    j3.at("applicationRate").get_to(p.iar);
    j3.at("concentrationAI").get_to(p.xactive);
    j3.at("downwindFieldDepth").get_to(p.fd);
    j3.at("crosswindFieldDepth").get_to(p.pl);
    j3.at("nozzleSpacing").get_to(p.dN);
    j3.at("windHorizontalVariation").get_to(p.psipsipsi);
    j3.at("minDropletSize").get_to(p.dpmin);
    j3.at("maxDropletSize").get_to(p.dpmax);
    j3.at("lambda").get_to(p.lambda);
}

} // namespace cdm