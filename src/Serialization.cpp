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
            {"dropletSizeDistribution", m.in.dsd},
            {"dryAirTemperature", m.in.Tair},
            {"barometricPressure", m.in.Patm},
            {"relativeHumidity", m.in.RH},
            {"windVelocityProfile", {
                {"velocityMeasurements", m.in.wvu},
                {"temperatureMeasurements", m.in.wvT},
                {"horizontalVariation", m.in.ppp},
                {"horizontalVariationMethod", m.in.pppMethod}
            }},
            {"dropletTransport", {
                {"nozzleHeight", m.in.hN},
                {"canopyHeight", m.in.hC},
                {"nozzlePressure", m.in.PN},
                {"nozzleAngle", m.in.thetaN},
                {"waterDensity", m.in.rhoW},
                {"solidsDensity", m.in.rhoS},
                {"solidsFraction", m.in.xs0},
                {"ddd", m.in.ddd}
            }},
            {"deposition", {
                {"dsdCurveFitting", m.in.dsdfit},
                {"applicationRate", m.in.iar},
                {"concentrationAI", m.in.xactive},
                {"downwindFieldDepth", m.in.FD},
                {"crosswindFieldDepth", m.in.PL},
                {"nozzleSpacing", m.in.dN},
                {"minDropletSize", m.in.dpmin},
                {"maxDropletSize", m.in.dpmax},
                {"maxDriftDistance", m.in.Lmax},
                {"lambda", m.in.lambda},
                {"outputInterval", m.in.dx}
            }},
            {"integrationOptions", {
                {"relativeTolerance", m.in.cvreltol},
                {"absoluteTolerances", m.in.cvabstol},
                {"maxOrder", m.in.cvmaxord},
                {"maxSteps", m.in.cvmxsteps},
                {"stabilityLimitDetection", m.in.cvstldet},
                {"maxErrorTestFailures", m.in.cvmaxnef},
                {"maxNonlinearIterations", m.in.cvmaxcor},
                {"maxConvergenceFailures", m.in.cvmaxncf},
                {"convergenceCoefficient", m.in.cvnlscoef}
            }},
            {"output", {
                {"dropletSizeModel", m.out.dsmodel},
                {"wetBulbTemperature", m.out.Twb},
                {"wetBulbTemperatureDepression", m.out.dTwb},
                {"horizontalVariation", m.out.ppp},
                {"frictionHeight", m.out.z0},
                {"frictionVelocity", m.out.Uf},
                {"mixtureDensity", m.out.rhoL},
                {"nozzleVelocityZ", m.out.nvz},
                {"nozzleVelocityX", m.out.nvx},
                {"dropletSize", m.out.dp},
                {"dropletTransportDistance", m.out.xdist},
                {"deposition", m.out.applume}
            }}
        }
    };
}

void from_json(const nlohmann::ordered_json& json, Model& m)
{
    m.name = json.begin().key();
    auto j = json.front();

    j.at("dropletSizeDistribution").get_to(m.in.dsd);
    j.at("dryAirTemperature").get_to(m.in.Tair);
    j.at("barometricPressure").get_to(m.in.Patm);
    j.at("relativeHumidity").get_to(m.in.RH);

    auto j0 = j.at("windVelocityProfile");
    j0.at("velocityMeasurements").get_to(m.in.wvu);
    if (j0.count("temperatureMeasurements") != 0) {
        j0.at("temperatureMeasurements").get_to(m.in.wvT);
    }
    if (j0.count("horizontalVariation") != 0) {
        j0.at("horizontalVariation").get_to(m.in.ppp);
    }
    if (j0.count("horizontalVariationMethod") != 0) {
        j0.at("horizontalVariationMethod").get_to(m.in.pppMethod);
        switch (m.in.pppMethod) {
        case Model::Input::PPPMethod::ENTERED:
        case Model::Input::PPPMethod::INTERPOLATE:
        case Model::Input::PPPMethod::SDTF:
            break;
        default: // Invalid
            m.in.pppMethod = Model::Input::PPPMethod::ENTERED;
            break;
        }
    }
    
    auto j1 = j.at("dropletTransport");
    j1.at("nozzleHeight").get_to(m.in.hN);
    j1.at("canopyHeight").get_to(m.in.hC);
    j1.at("nozzlePressure").get_to(m.in.PN);
    j1.at("nozzleAngle").get_to(m.in.thetaN);
    j1.at("waterDensity").get_to(m.in.rhoW);
    j1.at("solidsDensity").get_to(m.in.rhoS);
    j1.at("solidsFraction").get_to(m.in.xs0);
    j1.at("ddd").get_to(m.in.ddd);

    auto j2 = j.at("deposition");
    j2.at("dsdCurveFitting").get_to(m.in.dsdfit);
    j2.at("applicationRate").get_to(m.in.iar);
    j2.at("concentrationAI").get_to(m.in.xactive);
    j2.at("downwindFieldDepth").get_to(m.in.FD);
    j2.at("crosswindFieldDepth").get_to(m.in.PL);
    j2.at("nozzleSpacing").get_to(m.in.dN);
    j2.at("minDropletSize").get_to(m.in.dpmin);
    j2.at("maxDropletSize").get_to(m.in.dpmax);
    if (j2.count("maxDriftDistance") != 0) {
        j2.at("maxDriftDistance").get_to(m.in.Lmax);
    }
    if (j2.count("lambda") != 0) {
        j2.at("lambda").get_to(m.in.lambda);
    }
    if (j2.count("outputInterval") != 0) {
        j2.at("outputInterval").get_to(m.in.dx);
    }

    if (j.count("integrationOptions") != 0) {
        auto j3 = j.at("integrationOptions");
        if (j3.count("relativeTolerance") != 0) {
            j3.at("relativeTolerance").get_to(m.in.cvreltol);
        }
        if (j3.count("absoluteTolerances") != 0) {
            j3.at("absoluteTolerances").get_to(m.in.cvabstol);
        }
        if (j3.count("maxOrder") != 0) {
            j3.at("maxOrder").get_to(m.in.cvmaxord);
        }
        if (j3.count("maxSteps") != 0) {
            j3.at("maxSteps").get_to(m.in.cvmxsteps);
        }
        if (j3.count("stabilityLimitDetection") != 0) {
            j3.at("stabilityLimitDetection").get_to(m.in.cvstldet);
        }
        if (j3.count("maxErrorTestFailures") != 0) {
            j3.at("maxErrorTestFailures").get_to(m.in.cvmaxnef);
        }
        if (j3.count("maxNonlinearIterations") != 0) {
            j3.at("maxNonlinearIterations").get_to(m.in.cvmaxcor);
        }
        if (j3.count("maxConvergenceFailures") != 0) {
            j3.at("maxConvergenceFailures").get_to(m.in.cvmaxncf);
        }
        if (j3.count("convergenceCoefficient") != 0) {
            j3.at("convergenceCoefficient").get_to(m.in.cvnlscoef);
        }
    }
}

} // namespace cdm