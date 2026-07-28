// Copyright (c) 2021 John Buonagurio <jbuonagurio@exponent.com>

#include <algorithm>
#include <cstdlib>
#include <cmath>
#include <cstdint>
#include <cstdarg>
#include <cstdio>
#include <cstring>
#include <exception>
#include <filesystem>
#include <fstream>
#include <limits>
#include <sstream>
#include <vector>

#include <fmt/core.h>

#include <nlohmann/json.hpp>

#include "CDM.h"
#include "AtmosphericProperties.hpp"
#include "Deposition.hpp"
#include "DropletSizeModel.hpp"
#include "DropletTransport.hpp"
#include "DsdWeighting.hpp"
#include "Model.hpp"
#include "NozzleVelocity.hpp"
#include "Serialization.hpp"
#include "VerticalProfileCellCrossing.hpp"
#include "VerticalProfileCellCrossingSingleNozzle.hpp"
#include "WindVelocityProfile.hpp"

static void cdm_default_error_handler(const char *format, ...)
{
    std::va_list ap;
    va_start(ap, format);
    vfprintf(stderr, format, ap);
    va_end(ap);
}

static cdm_error_handler_t cdm_error_handler = cdm_default_error_handler;

namespace {

std::string profile_label(const nlohmann::ordered_json& profile, const std::string& fallback)
{
    if (profile.is_object() && profile.count("label") != 0 && profile.at("label").is_string()) {
        return profile.at("label").get<std::string>();
    }
    return fallback;
}

std::optional<std::string> profile_nozzle(const nlohmann::ordered_json& profile)
{
    if (profile.is_object() && profile.count("nozzle") != 0 && profile.at("nozzle").is_string()) {
        return profile.at("nozzle").get<std::string>();
    }
    return std::nullopt;
}

std::vector<std::string> available_profile_names(const nlohmann::ordered_json& profiles)
{
    std::vector<std::string> names;
    names.reserve(profiles.size());
    for (const auto& item : profiles.items()) {
        const auto label = profile_label(item.value(), item.key());
        const auto nozzle = profile_nozzle(item.value());
        if (nozzle.has_value()) {
            names.push_back(label + " [" + *nozzle + "]");
        }
        else {
            names.push_back(label);
        }
    }
    return names;
}

std::string join_profile_names(const std::vector<std::string>& names)
{
    std::ostringstream os;
    for (size_t i = 0; i < names.size(); ++i) {
        if (i > 0) {
            os << ", ";
        }
        os << names[i];
    }
    return os.str();
}

std::optional<std::string> find_profile_by_label(
    const nlohmann::ordered_json& profiles,
    const std::string& selector)
{
    for (const auto& item : profiles.items()) {
        if (profile_label(item.value(), item.key()) == selector) {
            return item.key();
        }
    }
    return std::nullopt;
}

std::optional<std::string> find_profile_by_nozzle(
    const nlohmann::ordered_json& profiles,
    const std::string& selector)
{
    for (const auto& item : profiles.items()) {
        const auto nozzle = profile_nozzle(item.value());
        if (nozzle.has_value() && *nozzle == selector) {
            return item.key();
        }
    }
    return std::nullopt;
}

std::filesystem::path resolve_dsd_library_path(const char *explicitPath)
{
    if (explicitPath != nullptr && std::strlen(explicitPath) != 0) {
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

    return std::filesystem::path();
}

void apply_dsd_profile_if_needed(nlohmann::ordered_json& rootConfig, const char *cliProfile, const char *libraryPath)
{
    if (!rootConfig.is_object() || rootConfig.empty()) {
        throw std::runtime_error("Invalid model input: expected top-level object with one case entry");
    }

    auto& caseJson = rootConfig.front();
    const bool hasCustomDsd = caseJson.count("dropletSizeDistribution") != 0;

    std::string selectedProfile;
    if (cliProfile != nullptr && std::strlen(cliProfile) != 0) {
        selectedProfile = cliProfile;
    }
    else if (!hasCustomDsd && caseJson.count("dropletSizeDistributionProfile") != 0) {
        selectedProfile = caseJson.at("dropletSizeDistributionProfile").get<std::string>();
    }

    // If no profile selector was provided and a custom DSD exists in the case,
    // use the case-provided distribution directly without requiring a library.
    if (selectedProfile.empty() && hasCustomDsd) {
        return;
    }

    const auto dsdLibraryPath = resolve_dsd_library_path(libraryPath);
    if (dsdLibraryPath.empty()) {
        throw std::runtime_error(
            "No dropletSizeDistribution provided and no DSD library file was found. "
            "Pass --dsd-library (CLI) or set CDM_DSD_LIBRARY.");
    }
    if (!std::filesystem::exists(dsdLibraryPath)) {
        throw std::runtime_error("DSD library file not found: " + dsdLibraryPath.string());
    }

    std::ifstream ifs(dsdLibraryPath);
    if (!ifs.is_open()) {
        throw std::runtime_error("Failed to open DSD library file: " + dsdLibraryPath.string());
    }

    const auto dsdLibrary = nlohmann::ordered_json::parse(
        ifs,
        /* callback */ nullptr,
        /* allow_exceptions */ true,
        /* ignore_comments */ true);

    if (!dsdLibrary.is_object() || dsdLibrary.count("profiles") == 0 || !dsdLibrary.at("profiles").is_object()) {
        throw std::runtime_error("Invalid DSD library schema in file: " + dsdLibraryPath.string());
    }

    const auto& profiles = dsdLibrary.at("profiles");
    const auto available = available_profile_names(profiles);

    if (selectedProfile.empty()) {
        throw std::runtime_error(
            "No dropletSizeDistribution provided in case JSON and no DSD profile selected. "
            "Select one with --dsd-profile \"<name>\" (or set dropletSizeDistributionProfile in case JSON). "
            "\nAvailable profiles: " + join_profile_names(available));
    }

    std::string resolvedProfileName = selectedProfile;
    if (profiles.count(resolvedProfileName) == 0) {
        const auto profileByLabel = find_profile_by_label(profiles, selectedProfile);
        if (profileByLabel.has_value()) {
            resolvedProfileName = *profileByLabel;
        }
        else {
            const auto profileByNozzle = find_profile_by_nozzle(profiles, selectedProfile);
            if (profileByNozzle.has_value()) {
                resolvedProfileName = *profileByNozzle;
            }
            else {
                throw std::runtime_error(
                    "Unknown DSD profile selector '" + selectedProfile +
                    "'.\nUse a profile name (label) or nozzle number. Available profiles: " + join_profile_names(available));
            }
        }
    }

    const auto& profileNode = profiles.at(resolvedProfileName);
    if (!profileNode.is_object() || profileNode.count("dropletSizeDistribution") == 0 ||
        !profileNode.at("dropletSizeDistribution").is_array()) {
        throw std::runtime_error(
            "Invalid profile entry for '" + resolvedProfileName + "': expected object with dropletSizeDistribution array");
    }

    caseJson["dropletSizeDistribution"] = profileNode.at("dropletSizeDistribution");
}

} // namespace

cdm_error_handler_t cdm_set_error_handler(cdm_error_handler_t handler)
{
    cdm_error_handler_t previous_handler = cdm_error_handler;
    cdm_error_handler = handler;
    return previous_handler;
}

cdm_model_t * cdm_create_model(const char *config)
{
    return cdm_create_model_with_dsd_profile(config, nullptr, nullptr);
}

cdm_model_t * cdm_create_model_with_dsd_profile(const char *config, const char *dsdProfile, const char *dsdLibraryPath)
{
    cdm::Model *m = new cdm::Model;

    try {
        auto j = nlohmann::ordered_json::parse(config,
                                               /* callback */ nullptr,
                                               /* allow_exceptions */ true,
                                               /* ignore_comments */ true);
        apply_dsd_profile_if_needed(j, dsdProfile, dsdLibraryPath);
        
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

    if (m->dsdfit) {
        m->dsmodel = std::make_unique<cdm::DropletSizeModel>(m->dsd);
        try {
            m->dsmodel->fit();
        } catch (const std::exception& e) {
            cdm_error_handler("[DropletSizeModel] %s\n", e.what());
            return 1;
        }
    }

    m->rhoL = 1. / ((m->xs0 / m->rhoS) + ((1. - m->xs0) / m->rhoW));

    try {
        cdm::AtmosphericProperties ap(m->Tair, m->Patm, m->RH);
        m->rhoA = ap.wetAirDensity();
        m->muA = ap.wetAirDynamicViscosity();
        m->Tdp = ap.dewPointTemperature();
        m->Twb = ap.wetBulbTemperature();
        m->dTwb = ap.wetBulbTemperatureDepression();
    } catch (const std::exception& e) {
        cdm_error_handler("[AtmosphericProperties] %s\n", e.what());
        return 1;
    }

    cdm::NozzleVelocity nv(m->PN, m->thetaN, m->rhoL);
    m->nva = nv.angle;
    m->nvz = nv.z;
    m->nvx = nv.x;

    m->dp.resize(23, 0);
    for (size_t i = 0; i < m->dp.size(); ++i)
        m->dp[i] = m->dpmin * pow(m->dpmax/m->dpmin, i/22.);

    try {
        cdm::WindVelocityProfile wvp(m->wvu, m->wvT, m->pppMethod, m->hC);
        m->z0 = wvp.frictionHeight();
        m->Uf = wvp.frictionVelocity();
        if (m->pppMethod == cdm::PPPMethod::ENTERED)
            m->pppcalc = m->ppp.value_or(cdm::constants::default_psipsipsi);
        else
            m->pppcalc = wvp.psipsipsi();
    } catch (const std::exception& e) {
        cdm_error_handler("[WindVelocityProfile h=%g] %s\n", m->hC, e.what());
        return 1;
    }

    cdm::DropletTransport dt(*m);
    for (size_t j = 0; j < m->xdist.size(); ++j) {
        m->xdist[j].clear();
        m->xdist[j].reserve(m->dp.size());
    }
    for (size_t j = 0; j < m->xzByTimestep.size(); ++j) {
        m->xzByTimestep[j].clear();
        m->xzByTimestep[j].reserve(m->dp.size());
    }

    for (size_t i = 0; i < m->dp.size(); ++i) {
        for (size_t j = 0; j < m->xzByTimestep.size(); ++j) {
            try {
                cdm::DropletTransport::TrajectoryXZ trajectory;
                const double xdist = dt.trajectory(m->nvz[j], m->nvx[j], m->dp.at(i), trajectory);
                m->xdist[j].emplace_back(xdist);
                m->xzByTimestep[j].emplace_back(std::move(trajectory));
            } catch (const std::exception& e) {
                cdm_error_handler("[DropletTransport h=%g] %s\n", m->hC, e.what());
                return 1;
            }
        }
    }

    try {
        m->applume = cdm::Deposition(m->IAR, m->xactive, m->FD, m->PL, m->dN,
            m->pppcalc, m->rhoL, m->dp, m->xdist, m->dsd, m->dsmodel,
            m->dpmin, m->dpmax, m->Lmax, m->lambda, m->dx, m->sflags);
    } catch (const std::exception& e) {
        cdm_error_handler("[Deposition h=%g] %s\n", m->hC, e.what());
        return 1;
    }

    // optional: calculate vertical profiles
    m->vpResultsByDistanceCellCrossing = std::nullopt;
    m->vpResultsByDistanceCellCrossingSingleNozzle = std::nullopt;
    if (m->vpHeights.has_value() && !m->vpHeights->empty() &&
        m->vpDistances.has_value() && !m->vpDistances->empty()) {
        try {
            m->vpResultsByDistanceCellCrossing = cdm::VerticalProfileCellCrossing(
                m->IAR, m->xactive, m->FD, m->PL, m->dN, m->rhoL,
                m->dp, m->xzByTimestep, m->dsd, m->dsmodel,
                *m->vpHeights, *m->vpDistances, m->sflags);
            m->vpResultsByDistanceCellCrossingSingleNozzle = cdm::VerticalProfileCellCrossingSingleNozzle(
                m->IAR, m->xactive, m->FD, m->PL, m->dN, m->rhoL,
                m->dp, m->xzByTimestep, m->dsd, m->dsmodel,
                *m->vpHeights, *m->vpDistances, m->sflags);
        } catch (const std::exception& e) {
            cdm_error_handler("[VerticalProfile] %s\n", e.what());
            return 1;
        }
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

    if (m->dsmodel) {
        print_header("Droplet Size Distribution");
        fmt::print("{}\n", m->dsmodel->report());
        const auto dsparams = m->dsmodel->params();
        fmt::print("\nParameters\n");
        fmt::print("μ1 = {}\n", dsparams.a1);
        fmt::print("μ2 = {}\n", dsparams.a2);
        fmt::print("σ1 = {}\n", dsparams.d1);
        fmt::print("σ2 = {}\n", dsparams.d2);
        fmt::print("w1 = {}\n", dsparams.k1);
        fmt::print("\n{:<6} {:>6} {:>6}\n", "DD", "Obs.", "Pred.");
        for (const auto& xy : m->dsd)
            fmt::print("{:<6} {:>6.2f} {:>6.2f}\n", xy.first, xy.second*100, m->dsmodel->cdf(xy.first)*100);
    }

    print_header("Atmospheric Properties");
    fmt::print("ρA = {}\n", m->rhoA);
    fmt::print("μA = {}\n", m->muA);
    fmt::print("Tdp = {}\n", m->Tdp);
    fmt::print("Twb = {}\n", m->Twb);
    fmt::print("ΔTwb = {}\n", m->dTwb);

    print_header("Wind Velocity Profile");
    fmt::print("Uf = {}\n", m->Uf); 
    fmt::print("z0 = {}\n", m->z0);
    fmt::print("ψψψ = {} ", m->pppcalc);
    switch (m->pppMethod) {
    case cdm::PPPMethod::ENTERED:
        fmt::print("(ENTERED)\n"); break;
    case cdm::PPPMethod::INTERPOLATE:
        fmt::print("(INTERPOLATE)\n"); break;
    case cdm::PPPMethod::SDTF:
        fmt::print("(SDTF)\n"); break;
    default:
        fmt::print("\n"); break;
    }

    print_header("Droplet Transport");
    fmt::print("{:<8} {:>10} {:>10}\n", "Angle", "Vx", "Vz");
    for (size_t i = 0; i < m->nva.size(); ++i)
        fmt::print("{:<8.3f} {:>10.2f} {:>10.2f}\n", m->nva.at(i), m->nvx.at(i), m->nvz.at(i));
    fmt::print("\n");
    fmt::print("{:<8} {:>10}\n", "DD", "Distance");
    for (size_t i = 0; i < m->dp.size(); ++i) {
        fmt::print("{:<8.3f}", m->dp.at(i));
        for (size_t j = 0; j < m->xdist.size(); ++j)
            fmt::print(" {:>10.2f}", m->xdist[j].at(i));
        fmt::print("\n");
    }

    print_header("Deposition");
    fmt::print("{:<8} {:>9}\n", "Distance", "APPlume");
    for (size_t i = 0; i < m->applume.size(); ++i)
        fmt::print("{:<8.3f} {:>8.4f}%\n", m->applume.at(i).first, m->applume.at(i).second);

    if (m->vpResultsByDistanceCellCrossing.has_value() && !m->vpResultsByDistanceCellCrossing->empty()) {
        const auto& vpResults = *m->vpResultsByDistanceCellCrossing;

        // Volume conversion: cell mL/m² = (%IAR / 100) × (volumeSprayed / fieldArea) × 1000.
        // volumeSprayed is the total sprayed liquid volume [L]; fieldArea = FD × PL [m^2].
        const double volumeSprayed = cdm::ComputeVolumeSprayed(m->IAR, m->xactive, m->FD, m->PL, m->rhoL); // L
        const double fieldAreaM2 = m->FD * m->PL; // m²
        const double volPerArea = (fieldAreaM2 > 0.0) ? (volumeSprayed / fieldAreaM2) * 1000.0 : 0.0; // mL/m² per unit %IAR/100

        // Collect non-degenerate height bins (drop the zero-thickness ground bin).
        struct HeightBin { double upper; size_t index; };
        std::vector<HeightBin> heightBins;
        {
            const auto& firstBins = vpResults.front().bins;
            for (size_t i = 0; i < firstBins.size(); ++i) {
                if (firstBins[i].height > firstBins[i].previousHeight)
                    heightBins.push_back({firstBins[i].height, i});
            }
        }

        // Ground deposition (%IAR) interpolated to a downwind distance from applume.
        auto depAt = [&](double d) -> double {
            const auto& ap = m->applume;
            if (ap.empty())
                return 0.0;
            if (d <= ap.front().first)
                return ap.front().second;
            if (d >= ap.back().first)
                return ap.back().second;
            for (size_t i = 1; i < ap.size(); ++i) {
                if (ap[i].first >= d) {
                    const double x0 = ap[i - 1].first, y0 = ap[i - 1].second;
                    const double x1 = ap[i].first, y1 = ap[i].second;
                    const double t = (x1 > x0) ? (d - x0) / (x1 - x0) : 0.0;
                    return y0 + t * (y1 - y0);
                }
            }
            return ap.back().second;
        };

        auto print_grid = [&](const std::string& header, bool asVolume) {
            print_header(header);
            fmt::print("{:>8}", "H\\D");
            for (const auto& col : vpResults)
                fmt::print(" {:>8.2f}", col.distance);
            fmt::print("\n");
            for (auto it = heightBins.rbegin(); it != heightBins.rend(); ++it) {
                fmt::print("{:>8.2f}", it->upper);
                for (const auto& col : vpResults) {
                    double value = 0.0;
                    if (it->index < col.bins.size()) {
                        const double pct = col.bins[it->index].percentApplied;
                        value = asVolume ? (pct / 100.0) * volPerArea : pct;
                    }
                    fmt::print(" {:>8.4f}", value);
                }
                fmt::print("\n");
            }
            // Ground deposition row, aligned to the distance columns, beneath the lowest height.
            fmt::print("{:>8}", "Dep");
            for (const auto& col : vpResults) {
                const double depPct = depAt(col.distance);
                const double value = asVolume ? (depPct / 100.0) * volPerArea : depPct;
                fmt::print(" {:>8.4f}", value);
            }
            fmt::print("\n");

            // Total still airborne (column sum over height cells) for each distance.
            fmt::print("{:>8}", "Air");
            for (const auto& col : vpResults) {
                double airborne = 0.0;
                for (const auto& bin : col.bins) {
                    if (bin.height > bin.previousHeight)
                        airborne += bin.percentApplied;
                }
                const double value = asVolume ? (airborne / 100.0) * volPerArea : airborne;
                fmt::print(" {:>8.4f}", value);
            }
            fmt::print("\n");

            // Total deposited: in-field (field-edge) deposition plus cumulative drift deposition.
            const double inFieldDep = depAt(0.0);
            fmt::print("{:>8}", "TotDep");
            double depCum = inFieldDep;
            for (const auto& col : vpResults) {
                depCum += depAt(col.distance);
                const double value = asVolume ? (depCum / 100.0) * volPerArea : depCum;
                fmt::print(" {:>8.4f}", value);
            }
            fmt::print("\n");

            fmt::print("\nRows: height upper bound [m]; Columns: distance [m].\n");
            fmt::print("Dep = local ground deposition; Air = total still airborne (sum over heights);\n");
            fmt::print("TotDep = total deposited = in-field deposition ({:.4f}%) + cumulative drift deposition.\n", inFieldDep);
        };

        print_grid("Vertical Profile - Output Volume [mL/m^2]", true);
        print_grid("Vertical Profile - %IAR [percent of applied]", false);
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

const char * cdm_library_version()
{
    return CDM_VERSION_STRING;
}

unsigned char * cdm_get_trajectories_binary(cdm_model_t *model, size_t *size)
{
    cdm::Model *m = reinterpret_cast<cdm::Model *>(model);

    if (!m || !size)
        return nullptr;

    try {
        std::vector<unsigned char> bytes;
        bytes.reserve(1024);

        auto append_u32 = [&](std::uint32_t value) {
            bytes.push_back(static_cast<unsigned char>((value >> 0) & 0xFF));
            bytes.push_back(static_cast<unsigned char>((value >> 8) & 0xFF));
            bytes.push_back(static_cast<unsigned char>((value >> 16) & 0xFF));
            bytes.push_back(static_cast<unsigned char>((value >> 24) & 0xFF));
        };

        auto append_u64 = [&](std::uint64_t value) {
            for (int shift = 0; shift < 64; shift += 8)
                bytes.push_back(static_cast<unsigned char>((value >> shift) & 0xFF));
        };

        auto append_f64 = [&](double value) {
            std::uint64_t bits = 0;
            static_assert(sizeof(double) == sizeof(std::uint64_t), "Unexpected double size");
            std::memcpy(&bits, &value, sizeof(double));
            append_u64(bits);
        };

        auto append_string = [&](const std::string& value) {
            append_u32(static_cast<std::uint32_t>(value.size()));
            bytes.insert(bytes.end(), value.begin(), value.end());
        };

        const std::uint32_t version = 2;
        const std::uint32_t streamlineCount = static_cast<std::uint32_t>(cdm::constants::ns);
        const std::uint32_t dropletCount = static_cast<std::uint32_t>(m->dp.size());
        const std::uint32_t heightCount =
            (m->vpHeights.has_value() ? static_cast<std::uint32_t>(m->vpHeights->size()) : 0);

        const char magic[8] = {'C', 'D', 'M', 'T', 'R', 'J', 'B', '1'};
        bytes.insert(bytes.end(), magic, magic + 8);
        append_u32(version);
        append_u32(streamlineCount);
        append_u32(dropletCount);
        append_u32(heightCount);
        append_string(m->name);

        for (double d : m->dp)
            append_f64(d);

        if (m->vpHeights.has_value()) {
            for (double h : *m->vpHeights)
                append_f64(h);
        }

        for (const auto& streamline : m->xzByTimestep) {
            for (const auto& trajectory : streamline) {
                append_u32(static_cast<std::uint32_t>(trajectory.size()));
                for (const auto& point : trajectory) {
                    append_f64(point[0]);
                    append_f64(point[1]);
                    append_f64(point[2]);
                }
            }
        }

        *size = bytes.size();
        unsigned char *out = new unsigned char[*size];
        std::copy(bytes.begin(), bytes.end(), out);
        return out;
    } catch (const std::exception& e) {
        cdm_error_handler("%s\n", e.what());
        return nullptr;
    }
}

void cdm_free_buffer(unsigned char *buffer)
{
    if (buffer)
        delete[] buffer;
}