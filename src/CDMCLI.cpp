#include <chrono>
#include <cstdlib>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <optional>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

#include <fmt/core.h>

#include <nlohmann/json.hpp>

#include "CDM.h"
#include "CLI11.hpp"

namespace {

std::filesystem::path resolve_dsd_library_path(const std::string& explicitPath, const std::filesystem::path& exePath)
{
    if (!explicitPath.empty()) {
        return std::filesystem::path(explicitPath);
    }

    if (const char *envPath = std::getenv("CDM_DSD_LIBRARY"); envPath != nullptr && std::strlen(envPath) != 0) {
        return std::filesystem::path(envPath);
    }

    const auto cwd = std::filesystem::current_path();
    const auto configCandidate = cwd / "config" / "dsd_profiles.json";
    if (std::filesystem::exists(configCandidate)) {
        return configCandidate;
    }

    const auto rootCandidate = cwd / "dsd_profiles.json";
    if (std::filesystem::exists(rootCandidate)) {
        return rootCandidate;
    }

    const auto exeDir = exePath.parent_path();
    const auto candidateInBin = exeDir / "config" / "dsd_profiles.json";
    if (std::filesystem::exists(candidateInBin)) {
        return candidateInBin;
    }
    const auto candidateFromBin = exeDir.parent_path() / "config" / "dsd_profiles.json";
    if (std::filesystem::exists(candidateFromBin)) {
        return candidateFromBin;
    }

    return std::filesystem::path();
}

nlohmann::ordered_json load_profile_library_or_throw(const std::filesystem::path& libPath)
{
    if (libPath.empty()) {
        throw std::runtime_error(
            "DSD library file not found. Pass --dsd-library (CLI) or set CDM_DSD_LIBRARY.");
    }
    if (!std::filesystem::exists(libPath)) {
        throw std::runtime_error("DSD library file not found: " + libPath.string());
    }

    std::ifstream ifs(libPath);
    if (!ifs.is_open()) {
        throw std::runtime_error("Failed to open DSD library file: " + libPath.string());
    }

    auto dsdLibrary = nlohmann::ordered_json::parse(
        ifs,
        /* callback */ nullptr,
        /* allow_exceptions */ true,
        /* ignore_comments */ true);

    if (!dsdLibrary.is_object() || dsdLibrary.count("profiles") == 0 || !dsdLibrary.at("profiles").is_object()) {
        throw std::runtime_error("Invalid DSD library schema in file: " + libPath.string());
    }
    return dsdLibrary;
}

} // namespace

int main(int argc, char *argv[])
{
    auto trajectories_output_path = [](const std::string& outputPath) {
        const std::filesystem::path out(outputPath);
        const std::string pathStr = out.string();
        if (out.extension() == ".json") {
            return (out.parent_path() / (out.stem().string() + ".trajectories.bin")).string();
        }
        return pathStr + ".trajectories.bin";
    };

    std::string infile, outfile;
    std::string dsdProfile;
    std::string dsdLibrary;
    bool listDsdProfiles = false;
    bool verbose = false;
    
    CLI::App app("Casanova Drift Model");
    app.set_version_flag("--version", "cdm version " CDM_VERSION_STRING);
    app.add_option("-i,--input,input", infile, "Read configuration from FILE")
        ->option_text("FILE")
        ->capture_default_str()
        ->check(CLI::ExistingFile);
    app.add_option("-o,--output", outfile, "Write output to FILE")
        ->option_text("FILE");
    app.add_option("--dsd-profile", dsdProfile,
        "Built-in DSD profile selector from library JSON (profile name or nozzle number). Overrides DSD/profile values in configuration file.");
    app.add_option("--dsd-library", dsdLibrary,
        "Path to a DSD library JSON. Optional if CDM_DSD_LIBRARY is set or default file is found.")
        ->option_text("FILE");
    app.add_flag("--list-dsd-profiles", listDsdProfiles,
        "List available built-in DSD profiles and exit.");
    app.add_flag("-v, --verbose", verbose, "Enable verbose output");
    app.preparse_callback([](std::size_t arity) {
        if (arity == 0) throw CLI::CallForHelp(); });
    
    CLI11_PARSE(app, argc, argv);

    const auto exePath = std::filesystem::absolute(argv[0]);
    const auto dsdLibraryPath = resolve_dsd_library_path(dsdLibrary, exePath);

    if (listDsdProfiles) {
        try {
            const auto dsdLibraryJson = load_profile_library_or_throw(dsdLibraryPath);
            const auto& profiles = dsdLibraryJson.at("profiles");
            fmt::print("Built-in DSD profiles (from {}):\n", dsdLibraryPath.string());
            size_t i = 1;
            for (const auto& item : profiles.items()) {
                const auto& profile = item.value();
                std::string label = item.key();
                if (profile.is_object() && profile.count("label") != 0 && profile.at("label").is_string()) {
                    label = profile.at("label").get<std::string>();
                }
                std::string nozzle;
                if (profile.is_object() && profile.count("nozzle") != 0 && profile.at("nozzle").is_string()) {
                    nozzle = profile.at("nozzle").get<std::string>();
                }
                if (!nozzle.empty()) {
                    fmt::print("{:>2}. {}  [nozzle: {} | selectors: --dsd-profile \"{}\" or --dsd-profile {}]\n",
                               i++, label, nozzle, label, nozzle);
                }
                else {
                    fmt::print("{:>2}. {}  [selector: --dsd-profile \"{}\"]\n", i++, label, label);
                }
            }
            return 0;
        } catch (const std::exception& e) {
            fmt::print("{}\n", e.what());
            return 1;
        }
    }

    if (infile.empty()) {
        fmt::print("Input file is required. Use -i/--input, or pass --list-dsd-profiles to list available defaults.\n");
        return 1;
    }

    std::ifstream ifs;
    std::stringstream buffer;
    ifs.exceptions(std::ios_base::failbit | std::ios_base::badbit);
    try {
        ifs.open(infile);
        buffer << ifs.rdbuf();
        ifs.close();
    } catch (std::exception& e) {
        fmt::print("{}\n", e.what());
        return 1;
    }

    auto start = std::chrono::steady_clock::now();

    const std::string dsdLibraryPathStr = dsdLibraryPath.string();

    cdm_model_t *model = cdm_create_model_with_dsd_profile(
        buffer.str().c_str(),
        dsdProfile.empty() ? nullptr : dsdProfile.c_str(),
        dsdLibraryPath.empty() ? nullptr : dsdLibraryPathStr.c_str());
    if (model == nullptr) {
        return 1;
    }

    int rc = cdm_run_model(model);
    if (rc != 0) {
        cdm_free_model(model);
        return 1;
    }

    cdm_print_report(model);

    if (!outfile.empty()) {
        std::ofstream ofs;
        std::ofstream trj;
        char *out = nullptr;
        unsigned char *trjOut = nullptr;
        size_t trjOutSize = 0;
        try {
            ofs.open(outfile);
            out = cdm_get_output_string(model);
            trjOut = cdm_get_trajectories_binary(model, &trjOutSize);
            if (out == nullptr || trjOut == nullptr)
                throw std::runtime_error("failed to serialize model output");

            ofs << std::string(out);

            trj.open(trajectories_output_path(outfile), std::ios::binary);
            trj.write(reinterpret_cast<const char *>(trjOut), static_cast<std::streamsize>(trjOutSize));

            ofs.close();
            trj.close();
            cdm_free_string(out);
            cdm_free_buffer(trjOut);
        } catch (std::exception& e) {
            if (out != nullptr)
                cdm_free_string(out);
            if (trjOut != nullptr)
                cdm_free_buffer(trjOut);
            fmt::print("{}\n", e.what());
            return 1;
        }
    }
    
    cdm_free_model(model);
    
    auto end = std::chrono::steady_clock::now();
    fmt::print("\nElapsed: {} ms\n", std::chrono::duration_cast<std::chrono::milliseconds>(end - start).count());

    return 0;
}
