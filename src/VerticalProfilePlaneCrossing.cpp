// Copyright (c) 2026

#include <algorithm>
#include <cmath>
#include <limits>
#include <optional>
#include <vector>

#include "DsdWeighting.hpp"
#include "VerticalProfilePlaneCrossing.hpp"

namespace cdm {

namespace {

std::optional<double> ZAtDistance(
    const DropletTransport::TrajectoryXZ& trajectory,
    double targetDistance)
{
    if (trajectory.empty()) {
        return std::nullopt;
    }

    if (targetDistance <= trajectory.front()[0]) {
        return trajectory.front()[1];
    }

    for (size_t i = 1; i < trajectory.size(); ++i) {
        const double x0 = trajectory[i - 1][0];
        const double z0 = trajectory[i - 1][1];
        const double x1 = trajectory[i][0];
        const double z1 = trajectory[i][1];

        const bool crossed = (x0 <= targetDistance && x1 >= targetDistance) ||
                             (x0 >= targetDistance && x1 <= targetDistance);
        if (!crossed) {
            continue;
        }

        const double dx = x1 - x0;
        if (std::abs(dx) <= std::numeric_limits<double>::epsilon()) {
            return z1;
        }

        const double t = (targetDistance - x0) / dx;
        return z0 + t * (z1 - z0);
    }

    return std::nullopt;
}

// heights[i] is the upper edge of bin i; lower edge is heights[i-1] (or 0).
// Skip zero-thickness bins (Case B includes a degenerate heights[0]=0 entry).
std::optional<size_t> HeightBinIndex(double z, const std::vector<double>& heights)
{
    for (size_t heightIdx = 0; heightIdx < heights.size(); ++heightIdx) {
        const double upperHeight = heights[heightIdx];
        const double lowerHeight = heightIdx == 0 ? 0.0 : heights[heightIdx - 1];
        if (!(upperHeight > lowerHeight)) {
            continue;
        }
        if (z >= lowerHeight && z < upperHeight) {
            return heightIdx;
        }
        // Include top edge of the uppermost bin.
        if (heightIdx + 1 == heights.size() && z >= lowerHeight && z <= upperHeight) {
            return heightIdx;
        }
    }
    return std::nullopt;
}

std::vector<VerticalProfileByDistanceCellCrossing> AccumulatePlaneCrossing(
    double IAR, double xactive, double FD, double PL,
    double dN, double rhoL,
    const std::vector<double>& dp,
    const std::array<std::vector<std::vector<std::array<double, 3>>>, constants::ns>& xzByTimestep,
    const std::vector<std::pair<double, double>>& dsd,
    const std::unique_ptr<DropletSizeModel>& dsdmodel,
    const std::vector<double>& heights,
    const std::vector<double>& distances,
    const std::array<bool, constants::ns>& sflags,
    bool singleNozzle)
{
    std::vector<VerticalProfileByDistanceCellCrossing> results;
    if (heights.empty() || distances.empty() || dp.empty()) {
        return results;
    }

    const size_t nSourceAreas = singleNozzle ? 1 : static_cast<size_t>(FD / dN);
    if (nSourceAreas == 0) {
        return results;
    }

    const double volumeSprayed = ComputeVolumeSprayed(IAR, xactive, FD, PL, rhoL);
    const auto classVolumes = ComputeClassVolumesFromCdfBins(
        volumeSprayed, nSourceAreas, dp, dsd, dsdmodel);

    const double sourceWidth = singleNozzle ? 0.0 : FD / static_cast<double>(nSourceAreas);

    results.reserve(distances.size());
    for (size_t distanceIdx = 0; distanceIdx < distances.size(); ++distanceIdx) {
        const double currentDistance = distances[distanceIdx];
        const double previousDistance = distanceIdx == 0 ? 0.0 : distances[distanceIdx - 1];

        // Spec: plane at field-edge distance d → X_plane = FD + d (multi-nozzle).
        // For each spray segment, convert to nozzle-relative transport X.
        const double samplePlaneX = FD + currentDistance;

        std::vector<double> cellVolumes(heights.size(), 0.0);
        std::vector<uint64_t> hitCounts(heights.size(), 0);

        for (size_t source = 0; source < nSourceAreas; ++source) {
            double relativeDistance = currentDistance;
            if (!singleNozzle) {
                const double sourceMidpoint = sourceWidth * (0.5 + static_cast<double>(source));
                relativeDistance = samplePlaneX - sourceMidpoint;
                if (relativeDistance < 0.0) {
                    continue;
                }
            }

            for (size_t streamline = 0; streamline < constants::ns; ++streamline) {
                if (!sflags[streamline]) {
                    continue;
                }

                const auto& trajectories = xzByTimestep[streamline];
                const size_t count = std::min(trajectories.size(), classVolumes.size());
                for (size_t droplet = 0; droplet < count; ++droplet) {
                    const auto zStar = ZAtDistance(trajectories[droplet], relativeDistance);
                    if (!zStar.has_value()) {
                        continue;
                    }

                    const auto heightIdxOpt = HeightBinIndex(*zStar, heights);
                    if (!heightIdxOpt.has_value()) {
                        continue;
                    }

                    const size_t heightIdx = *heightIdxOpt;
                    const double contribution = classVolumes[droplet] / static_cast<double>(constants::ns);
                    cellVolumes[heightIdx] += contribution;
                    hitCounts[heightIdx] += 1;
                }
            }
        }

        VerticalProfileByDistanceCellCrossing profile;
        profile.distance = currentDistance;
        profile.previousDistance = previousDistance;
        profile.bins.reserve(heights.size());
        for (size_t heightIdx = 0; heightIdx < heights.size(); ++heightIdx) {
            VerticalProfileCellCrossingBin bin;
            bin.height = heights[heightIdx];
            bin.previousHeight = heightIdx == 0 ? 0.0 : heights[heightIdx - 1];
            bin.percentApplied = volumeSprayed > 0.0
                ? (cellVolumes[heightIdx] / volumeSprayed) * 100.0
                : 0.0;
            bin.hitCount = hitCounts[heightIdx];
            profile.bins.emplace_back(std::move(bin));
        }

        results.emplace_back(std::move(profile));
    }

    return results;
}

} // namespace

std::vector<VerticalProfileByDistanceCellCrossing> VerticalProfilePlaneCrossing(
    double IAR, double xactive, double FD, double PL,
    double dN, double rhoL,
    const std::vector<double>& dp,
    const std::array<std::vector<std::vector<std::array<double, 3>>>, constants::ns>& xzByTimestep,
    const std::vector<std::pair<double, double>>& dsd,
    const std::unique_ptr<DropletSizeModel>& dsdmodel,
    const std::vector<double>& heights,
    const std::vector<double>& distances,
    const std::array<bool, constants::ns>& sflags)
{
    return AccumulatePlaneCrossing(
        IAR, xactive, FD, PL, dN, rhoL, dp, xzByTimestep, dsd, dsdmodel,
        heights, distances, sflags, false);
}

std::vector<VerticalProfileByDistanceCellCrossing> VerticalProfilePlaneCrossingSingleNozzle(
    double IAR, double xactive, double FD, double PL,
    double dN, double rhoL,
    const std::vector<double>& dp,
    const std::array<std::vector<std::vector<std::array<double, 3>>>, constants::ns>& xzByTimestep,
    const std::vector<std::pair<double, double>>& dsd,
    const std::unique_ptr<DropletSizeModel>& dsdmodel,
    const std::vector<double>& heights,
    const std::vector<double>& distances,
    const std::array<bool, constants::ns>& sflags)
{
    return AccumulatePlaneCrossing(
        IAR, xactive, FD, PL, dN, rhoL, dp, xzByTimestep, dsd, dsdmodel,
        heights, distances, sflags, true);
}

} // namespace cdm
