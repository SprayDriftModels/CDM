// Copyright (c) 2026

#include <algorithm>
#include <cmath>
#include <limits>
#include <optional>
#include <vector>

#include "DsdWeighting.hpp"
#include "VerticalProfileCellCrossing.hpp"

namespace cdm {

namespace {

std::optional<double> ZAtDistance(const DropletTransport::TrajectoryXZ& trajectory, double targetDistance)
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

bool IntersectsHeightCell(double z0, double z1, double lowerHeight, double upperHeight)
{
    const double zMin = std::min(z0, z1);
    const double zMax = std::max(z0, z1);
    return !(zMax < lowerHeight || zMin > upperHeight);
}

} // namespace

std::vector<VerticalProfileByDistanceCellCrossing> VerticalProfileCellCrossing(
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
    std::vector<VerticalProfileByDistanceCellCrossing> results;
    if (heights.empty() || distances.empty() || dp.empty()) {
        return results;
    }

    const size_t nSourceAreas = static_cast<size_t>(FD / dN);
    if (nSourceAreas == 0) {
        return results;
    }

    const double volumeSprayed = ComputeVolumeSprayed(IAR, xactive, FD, PL, rhoL);
    const double sourceWidth = FD / static_cast<double>(nSourceAreas);
    const auto classVolumes = ComputeClassVolumesFromCdfBins(volumeSprayed, nSourceAreas, dp, dsd, dsdmodel);

    results.reserve(distances.size());
    for (size_t distanceIdx = 0; distanceIdx < distances.size(); ++distanceIdx) {
        const double currentDistance = distances[distanceIdx];
        const double previousDistance = distanceIdx == 0 ? 0.0 : distances[distanceIdx - 1];
        const double sampleLowerX = FD + previousDistance;
        const double sampleUpperX = FD + currentDistance;

        std::vector<double> cellVolumes(heights.size(), 0.0);
        std::vector<uint64_t> hitCounts(heights.size(), 0);

        for (size_t source = 0; source < nSourceAreas; ++source) {
            const double sourceMidpoint = sourceWidth * (0.5 + static_cast<double>(source));
            double lowerRelativeDistance = sampleLowerX - sourceMidpoint;
            const double upperRelativeDistance = sampleUpperX - sourceMidpoint;
            if (upperRelativeDistance < 0.0) {
                continue;
            }
            lowerRelativeDistance = std::max(0.0, lowerRelativeDistance);

            for (size_t streamline = 0; streamline < constants::ns; ++streamline) {
                if (!sflags[streamline]) {
                    continue;
                }

                const auto& trajectories = xzByTimestep[streamline];
                const size_t count = std::min(trajectories.size(), classVolumes.size());
                for (size_t droplet = 0; droplet < count; ++droplet) {
                    const auto z0 = ZAtDistance(trajectories[droplet], lowerRelativeDistance);
                    const auto z1 = ZAtDistance(trajectories[droplet], upperRelativeDistance);
                    if (!z0.has_value() || !z1.has_value()) {
                        continue;
                    }

                    const double contribution = classVolumes[droplet] / static_cast<double>(constants::ns);
                    for (size_t heightIdx = 0; heightIdx < heights.size(); ++heightIdx) {
                        const double upperHeight = heights[heightIdx];
                        const double lowerHeight = heightIdx == 0 ? 0.0 : heights[heightIdx - 1];
                        if (!IntersectsHeightCell(*z0, *z1, lowerHeight, upperHeight)) {
                            continue;
                        }
                        cellVolumes[heightIdx] += contribution;
                        hitCounts[heightIdx] += 1;
                    }
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

} // namespace cdm
