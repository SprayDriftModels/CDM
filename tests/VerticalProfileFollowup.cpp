#include <array>
#include <cmath>
#include <fstream>
#include <iostream>
#include <memory>
#include <stdexcept>
#include <string>

#include <nlohmann/json.hpp>

#include "CDM.h"

namespace {

using Json = nlohmann::ordered_json;

void require(bool condition, const std::string& message)
{
    if (!condition)
        throw std::runtime_error(message);
}

Json run(const Json& input, const char* profile = nullptr, const char* library = nullptr)
{
    const auto config = input.dump();
    std::unique_ptr<cdm_model_t, decltype(&cdm_free_model)> model(
        cdm_create_model_with_dsd_profile(config.c_str(), profile, library), cdm_free_model);
    require(model != nullptr, "Model creation failed");
    require(cdm_run_model(model.get()) == 0, "Model execution failed");
    std::unique_ptr<char, decltype(&cdm_free_string)> output(
        cdm_get_output_string(model.get()), cdm_free_string);
    require(output != nullptr, "Model serialization failed");
    return Json::parse(output.get()).at(1).at("output");
}

double sum(const Json& column)
{
    double total = 0.0;
    for (const auto& bin : column.at("bins"))
        total += bin.at("percentApplied").get<double>();
    return total;
}

void close(double actual, double expected, const std::string& message)
{
    require(std::isfinite(actual) && std::abs(actual - expected) <= 1e-9, message);
}

} // namespace

int main(int argc, char** argv)
{
    try {
        require(argc == 3, "Expected Case B and test DSD library fixture paths");
        std::ifstream inputFile(argv[1]);
        require(inputFile.is_open(), "Cannot open Case B fixture");
        const auto input = Json::parse(inputFile);
        const auto output = run(input);
        const auto& vp = output.at("verticalProfile");
        const std::array<const char*, 4> keys = {
            "resultsByDistanceCellCrossing", "resultsByDistanceCellCrossingSingleNozzle",
            "resultsByDistancePlaneCrossing", "resultsByDistancePlaneCrossingSingleNozzle"
        };
        const auto& config = input.front().at("verticalProfile");
        for (const auto key : keys) {
            require(vp.at(key).size() == config.at("distances").size(), "Missing distance columns");
            for (const auto& column : vp.at(key)) {
                require(column.at("bins").size() == config.at("heights").size(), "Missing height bins");
                for (const auto& bin : column.at("bins"))
                    require(bin.at("percentApplied").get<double>() >= 0.0, "Negative profile weight");
            }
        }
        const auto& multi = vp.at(keys[2]);
        const auto& single = vp.at(keys[3]);
        bool occupancyDiffers = false;
        for (size_t i = 0; i < multi.size(); ++i) {
            require(sum(multi[i]) <= 100.0 + 1e-9, "Multi-nozzle plane sum exceeds applied volume");
            require(sum(single[i]) <= 100.0 + 1e-9, "Single-nozzle plane sum exceeds applied volume");
            occupancyDiffers = occupancyDiffers || sum(vp.at(keys[0])[i]) > sum(multi[i]) + 1e-9;
            close(multi[i].at("bins")[0].at("percentApplied"), 0.0, "Degenerate ground bin has plane weight");
        }
        require(occupancyDiffers, "Case B must distinguish occupancy from plane crossings");

        auto fineInput = input;
        auto& distances = fineInput.front()["verticalProfile"]["distances"];
        distances = Json::array();
        for (const auto& distance : config.at("distances")) {
            distances.push_back(distance.get<double>() - 0.5);
            distances.push_back(distance);
        }
        const auto fine = run(fineInput);
        for (const auto key : {keys[2], keys[3]}) {
            for (size_t i = 0; i < multi.size(); ++i) {
                require(vp.at(key)[i].at("bins") ==
                    fine.at("verticalProfile").at(key)[2 * i + 1].at("bins"),
                    "Plane results changed when intermediate distances were inserted");
            }
        }
        require(output.at("deposition") == fine.at("deposition"), "Profile grid changed ground deposition");
        require(output.at("massBalance") == fine.at("massBalance"), "Profile grid changed final-fate ledger");

        auto noVpInput = input;
        noVpInput.front().erase("verticalProfile");
        const auto noVp = run(noVpInput);
        for (const auto key : keys)
            require(noVp.at("verticalProfile").at(key).is_null(), "Unrequested profiles must remain null");
        require(output.at("deposition") == noVp.at("deposition"), "Profiles changed ground deposition");
        require(output.at("massBalance") == noVp.at("massBalance"), "Profiles changed final-fate ledger");

        const auto& mb = output.at("massBalance");
        const double unresolved = mb.at("unresolvedPercent");
        close(mb.at("inFieldDepositedPercent").get<double>() +
              mb.at("offFieldDepositedPercent").get<double>() +
              mb.at("beyondDomainPercent").get<double>() +
              mb.at("airbornePercent").get<double>() +
              mb.at("evaporatedPercent").get<double>() + unresolved,
              100.0, "Remaining-liquid ledger does not close");
        close(mb.at("inFieldDepositedInitialPercent").get<double>() +
              mb.at("offFieldDepositedInitialPercent").get<double>() +
              mb.at("beyondDomainInitialPercent").get<double>() +
              mb.at("airborneInitialPercent").get<double>() + unresolved,
              100.0, "Initial-volume ledger does not close");

        std::ifstream libraryFile(argv[2]);
        require(libraryFile.is_open(), "Cannot open test DSD library");
        const auto library = Json::parse(libraryFile);
        auto customInput = input;
        customInput.front()["deposition"]["dsdCurveFitting"] = false;
        customInput.front()["dropletSizeDistribution"] =
            library.at("profiles").at("test").at("dropletSizeDistribution");
        const auto custom = run(customInput);
        auto selectedInput = customInput;
        selectedInput.front().erase("dropletSizeDistribution");
        selectedInput.front()["dropletSizeDistributionProfile"] = "test";
        const auto selected = run(selectedInput, nullptr, argv[2]);
        require(custom == selected, "JSON-selected DSD differs from the same custom DSD");

        auto overriddenInput = input;
        overriddenInput.front()["deposition"]["dsdCurveFitting"] = false;
        for (const auto selector : {"test", "Test fixture only", "TEST"}) {
            require(custom == run(overriddenInput, selector, argv[2]),
                "Explicit DSD selector did not override custom distribution");
        }
        const auto invalidConfig = input.dump();
        std::unique_ptr<cdm_model_t, decltype(&cdm_free_model)> invalid(
            cdm_create_model_with_dsd_profile(invalidConfig.c_str(), "missing", argv[2]), cdm_free_model);
        require(invalid == nullptr, "Unknown DSD selector must be rejected");

        std::cout << "Vertical-profile integration checks passed\n";
        return 0;
    }
    catch (const std::exception& error) {
        std::cerr << error.what() << '\n';
        return 1;
    }
}
