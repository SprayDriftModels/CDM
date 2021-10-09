// Copyright (c) 2021 John Buonagurio <jbuonagurio@exponent.com>

#include <optional>

namespace nlohmann {
namespace detail {

template<typename BasicJsonType, typename T>
void from_json(const BasicJsonType& j, std::optional<T>& opt) {
    if (j.is_null())
        opt = std::nullopt;
    else
        opt = j.template get<T>();
}

template<typename BasicJsonType, typename T,
         std::enable_if_t<std::is_constructible<BasicJsonType, T>::value, int> = 0>
void to_json(BasicJsonType& j, const std::optional<T>& opt) {
    if (opt.has_value())
        j = *opt;
    else
        j = nullptr;
}

} // namespace detail
} // namespace nlohmann

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
            {"velocityMeasurements", p.wvu},
            {"temperatureMeasurements", p.wvT},
            {"horizontalVariation", p.psipsipsi},
            {"horizontalVariationMethod", p.psipsipsiMethod}
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
            {"dsdCurveFitting", p.dsdfit},
            {"applicationRate", p.iar},
            {"concentrationAI", p.xactive},
            {"downwindFieldDepth", p.fd},
            {"crosswindFieldDepth", p.pl},
            {"nozzleSpacing", p.dN},
            {"minDropletSize", p.dpmin},
            {"maxDropletSize", p.dpmax},
            {"maxDriftDistance", p.lmax},
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

    auto j0 = j.at("windVelocityProfile");
    j0.at("velocityMeasurements").get_to(p.wvu);
    if (j0.count("temperatureMeasurements") != 0) {
        j0.at("temperatureMeasurements").get_to(p.wvT);
    }
    if (j0.count("horizontalVariation") != 0) {
        //j0.at("horizontalVariation").get_to(p.psipsipsi);
        p.psipsipsi = j0.at("horizontalVariation").get<std::optional<double>>();
        //
    }
    if (j0.count("horizontalVariationMethod") != 0) {
        j0.at("horizontalVariationMethod").get_to(p.psipsipsiMethod);
        switch (p.psipsipsiMethod) {
        case PsiPsiPsiMethod::ENTERED:
        case PsiPsiPsiMethod::INTERPOLATE:
        case PsiPsiPsiMethod::SDTF:
            break;
        default: // Invalid
            p.psipsipsiMethod = PsiPsiPsiMethod::ENTERED;
            break;
        }
    }
    
    auto j1 = j.at("dropletTransport");
    j1.at("nozzleHeight").get_to(p.hN);
    j1.at("canopyHeight").get_to(p.hC);
    j1.at("nozzlePressure").get_to(p.PN);
    j1.at("nozzleAngle").get_to(p.thetaN);
    j1.at("waterDensity").get_to(p.rhoW);
    j1.at("solidsDensity").get_to(p.rhoS);
    j1.at("solidsFraction").get_to(p.xs0);
    j1.at("ddd").get_to(p.ddd);

    auto j2 = j.at("deposition");
    j2.at("dsdCurveFitting").get_to(p.dsdfit);
    j2.at("applicationRate").get_to(p.iar);
    j2.at("concentrationAI").get_to(p.xactive);
    j2.at("downwindFieldDepth").get_to(p.fd);
    j2.at("crosswindFieldDepth").get_to(p.pl);
    j2.at("nozzleSpacing").get_to(p.dN);
    j2.at("minDropletSize").get_to(p.dpmin);
    j2.at("maxDropletSize").get_to(p.dpmax);
    if (j2.count("maxDriftDistance") != 0) {
        j2.at("maxDriftDistance").get_to(p.lmax);
    }
    if (j2.count("lambda") != 0) {
        j2.at("lambda").get_to(p.lambda);
    }
}

} // namespace cdm