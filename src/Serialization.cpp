// Copyright (c) 2021 John Buonagurio <jbuonagurio@exponent.com>

#include <optional>

#include <nlohmann/json.hpp>

#include "Serialization.hpp"

namespace nlohmann {

template <typename T>
struct adl_serializer<std::optional<T>>
{
    template<typename BasicJsonType>
    static void from_json(const BasicJsonType& j, std::optional<T>& opt) {
        if (j.is_null())
            opt = std::nullopt;
        else
            opt = j.template get<T>();
    }

    template<typename BasicJsonType,
             std::enable_if_t<std::is_constructible<BasicJsonType, T>::value, int> = 0>
    static void to_json(BasicJsonType& j, const std::optional<T>& opt) {
        if (opt.has_value())
            j = *opt;
        else
            j = nullptr;
    }
};

} // namespace nlohmann

namespace cdm {

void to_json(nlohmann::ordered_json& json, const std::unique_ptr<DropletSizeModel>& p)
{
    if (p && p->valid()) {
        const auto& params = p->params();
        json = nlohmann::ordered_json{
            {"report", p->report()},
            {"coefficients", {
                {"a1", params.a1},
                {"a2", params.a2},
                {"d1", params.d1},
                {"d2", params.d2},
                {"k1", params.k1}
            }},
            {"predicted", p->predicted()},
            {"residuals", p->residuals()}
        };
    }
    else {
        json = nullptr;
    }
}

void to_json(nlohmann::ordered_json& json, const Model& m)
{
    json = nlohmann::ordered_json{
        m.name, {
            {"dropletSizeDistribution", m.dsd},
            {"dryAirTemperature", m.Tair},
            {"barometricPressure", m.Patm},
            {"relativeHumidity", m.RH},
            {"windVelocityProfile", {
                {"velocityMeasurements", m.wvu},
                {"temperatureMeasurements", m.wvT},
                {"horizontalVariation", m.ppp},
                {"horizontalVariationMethod", m.pppMethod}
            }},
            {"dropletTransport", {
                {"nozzleHeight", m.hN},
                {"canopyHeight", m.hC},
                {"nozzlePressure", m.PN},
                {"nozzleAngle", m.thetaN},
                {"waterDensity", m.rhoW},
                {"solidsDensity", m.rhoS},
                {"solidsFraction", m.xs0},
                {"ddd", m.ddd}
            }},
            {"deposition", {
                {"dsdCurveFitting", m.dsdfit},
                {"applicationRate", m.IAR},
                {"concentrationAI", m.xactive},
                {"downwindFieldDepth", m.FD},
                {"crosswindFieldDepth", m.PL},
                {"nozzleSpacing", m.dN},
                {"minDropletSize", m.dpmin},
                {"maxDropletSize", m.dpmax},
                {"maxDriftDistance", m.Lmax},
                {"lambda", m.lambda},
                {"outputInterval", m.dx}
            }},
            {"integrationOptions", {
                {"relativeTolerance", m.cvreltol},
                {"absoluteTolerances", m.cvabstol},
                {"maxOrder", m.cvmaxord},
                {"maxSteps", m.cvmxsteps},
                {"stabilityLimitDetection", m.cvstldet},
                {"maxErrorTestFailures", m.cvmaxnef},
                {"maxNonlinearIterations", m.cvmaxcor},
                {"maxConvergenceFailures", m.cvmaxncf},
                {"convergenceCoefficient", m.cvnlscoef}
            }},
            {"output", {
                {"dropletSizeModel", m.dsmodel},
                {"mixtureDensity", m.rhoL},
                {"wetAirDensity", m.rhoA},
                {"wetAirDynamicViscosity", m.muA},
                {"dewPointTemperature", m.Tdp},
                {"wetBulbTemperature", m.Twb},
                {"wetBulbTemperatureDepression", m.dTwb},
                {"horizontalVariation", m.pppcalc},
                {"frictionHeight", m.z0},
                {"frictionVelocity", m.Uf},
                {"nozzleVelocityZ", m.nvz},
                {"nozzleVelocityX", m.nvx},
                {"dropletSize", m.dp},
                {"dropletTransportDistance", m.xdist},
                {"deposition", m.applume}
            }}
        }
    };
}

void from_json(const nlohmann::ordered_json& json, Model& m)
{
    m.name = json.begin().key();
    auto j = json.front();

    j.at("dropletSizeDistribution").get_to(m.dsd);
    j.at("dryAirTemperature").get_to(m.Tair);
    j.at("barometricPressure").get_to(m.Patm);
    j.at("relativeHumidity").get_to(m.RH);

    auto j0 = j.at("windVelocityProfile");
    j0.at("velocityMeasurements").get_to(m.wvu);
    if (j0.count("temperatureMeasurements") != 0) {
        j0.at("temperatureMeasurements").get_to(m.wvT);
    }
    if (j0.count("horizontalVariation") != 0) {
        j0.at("horizontalVariation").get_to(m.ppp);
    }
    if (j0.count("horizontalVariationMethod") != 0) {
        j0.at("horizontalVariationMethod").get_to(m.pppMethod);
        switch (m.pppMethod) {
        case PPPMethod::ENTERED:
        case PPPMethod::INTERPOLATE:
        case PPPMethod::SDTF:
            break;
        default: // Invalid
            m.pppMethod = PPPMethod::ENTERED;
            break;
        }
    }
    
    auto j1 = j.at("dropletTransport");
    j1.at("nozzleHeight").get_to(m.hN);
    j1.at("canopyHeight").get_to(m.hC);
    j1.at("nozzlePressure").get_to(m.PN);
    j1.at("nozzleAngle").get_to(m.thetaN);
    j1.at("waterDensity").get_to(m.rhoW);
    j1.at("solidsDensity").get_to(m.rhoS);
    j1.at("solidsFraction").get_to(m.xs0);
    j1.at("ddd").get_to(m.ddd);

    auto j2 = j.at("deposition");
    j2.at("dsdCurveFitting").get_to(m.dsdfit);
    j2.at("applicationRate").get_to(m.IAR);
    j2.at("concentrationAI").get_to(m.xactive);
    j2.at("downwindFieldDepth").get_to(m.FD);
    j2.at("crosswindFieldDepth").get_to(m.PL);
    j2.at("nozzleSpacing").get_to(m.dN);
    j2.at("minDropletSize").get_to(m.dpmin);
    j2.at("maxDropletSize").get_to(m.dpmax);
    if (j2.count("maxDriftDistance") != 0) {
        j2.at("maxDriftDistance").get_to(m.Lmax);
    }
    if (j2.count("lambda") != 0) {
        j2.at("lambda").get_to(m.lambda);
    }
    if (j2.count("outputInterval") != 0) {
        j2.at("outputInterval").get_to(m.dx);
    }

    if (j.count("integrationOptions") != 0) {
        auto j3 = j.at("integrationOptions");
        if (j3.count("relativeTolerance") != 0) {
            j3.at("relativeTolerance").get_to(m.cvreltol);
        }
        if (j3.count("absoluteTolerances") != 0) {
            j3.at("absoluteTolerances").get_to(m.cvabstol);
        }
        if (j3.count("maxOrder") != 0) {
            j3.at("maxOrder").get_to(m.cvmaxord);
        }
        if (j3.count("maxSteps") != 0) {
            j3.at("maxSteps").get_to(m.cvmxsteps);
        }
        if (j3.count("stabilityLimitDetection") != 0) {
            j3.at("stabilityLimitDetection").get_to(m.cvstldet);
        }
        if (j3.count("maxErrorTestFailures") != 0) {
            j3.at("maxErrorTestFailures").get_to(m.cvmaxnef);
        }
        if (j3.count("maxNonlinearIterations") != 0) {
            j3.at("maxNonlinearIterations").get_to(m.cvmaxcor);
        }
        if (j3.count("maxConvergenceFailures") != 0) {
            j3.at("maxConvergenceFailures").get_to(m.cvmaxncf);
        }
        if (j3.count("convergenceCoefficient") != 0) {
            j3.at("convergenceCoefficient").get_to(m.cvnlscoef);
        }
    }
}

} // namespace cdm