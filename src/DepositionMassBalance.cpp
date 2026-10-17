// Copyright (c) 2026

#include <algorithm>
#include <array>
#include <cmath>
#include <vector>

#include "DepositionMassBalance.hpp"
#include "DsdWeighting.hpp"

namespace cdm {

DepositionMassBalance ComputeDepositionMassBalance(
    double IAR, double xactive, double FD, double PL, double dN, double rhoL,
    double xs0, double rhoW, double rhoS,
    double depositHeight, double maxDrift,
    const std::vector<double>& dp,
    const std::array<std::vector<std::vector<std::array<double, 3>>>, constants::ns>& xzByTimestep,
    const std::vector<std::pair<double, double>>& dsd,
    const std::unique_ptr<DropletSizeModel>& dsdmodel,
    const std::array<bool, constants::ns>& sflags)
{
    DepositionMassBalance mb;
    if (dp.empty() || dN <= 0.0) {
        return mb;
    }

    const size_t nSourceAreas = static_cast<size_t>(FD / dN);
    if (nSourceAreas == 0) {
        return mb;
    }

    const double volumeSprayed = ComputeVolumeSprayed(IAR, xactive, FD, PL, rhoL);
    if (volumeSprayed <= 0.0) {
        return mb;
    }

    const double sourceWidth = FD / static_cast<double>(nSourceAreas);
    const auto classVolumes = ComputeClassVolumesFromCdfBins(volumeSprayed, nSourceAreas, dp, dsd, dsdmodel);

    double inField = 0.0;
    double offField = 0.0;
    double beyond = 0.0;
    double airborne = 0.0;
    double evaporated = 0.0;
    double counted = 0.0;

    // Pre-evaporation (initial-volume ~ active-ingredient) fate split.
    double inFieldInit = 0.0;
    double offFieldInit = 0.0;
    double beyondInit = 0.0;
    double airborneInit = 0.0;

    for (size_t source = 0; source < nSourceAreas; ++source) {
        const double sourceMidpoint = sourceWidth * (0.5 + static_cast<double>(source));
        // Trajectory x is measured from the release point; the field edge lies this
        // far downwind of the source, so distance past the edge = xf - fieldEdgeFromSource.
        const double fieldEdgeFromSource = FD - sourceMidpoint;

        for (size_t streamline = 0; streamline < constants::ns; ++streamline) {
            if (!sflags[streamline]) {
                continue;
            }

            const auto& trajectories = xzByTimestep[streamline];
            const size_t count = std::min(trajectories.size(), classVolumes.size());
            for (size_t droplet = 0; droplet < count; ++droplet) {
                const auto& traj = trajectories[droplet];
                if (traj.empty()) {
                    continue;
                }

                const double w = classVolumes[droplet] / static_cast<double>(constants::ns);
                if (w <= 0.0) {
                    continue;
                }

                const double mi = traj.front()[2]; // initial droplet mass [g]
                const double mf = traj.back()[2];  // final droplet mass [g]
                if (mi <= 0.0) {
                    continue;
                }

                // Split mass into (conserved) solids and (evaporating) water using
                // the solids mass fraction; recover solution volumes via densities.
                const double solidsMass = mi * xs0;
                const double waterMass0 = mi - solidsMass;
                const double waterMassF = std::max(0.0, mf - solidsMass);

                const double volume0 = solidsMass / rhoS + waterMass0 / rhoW;
                const double volumeF = solidsMass / rhoS + waterMassF / rhoW;
                const double evapVolFrac = (volume0 > 0.0) ? std::max(0.0, (volume0 - volumeF) / volume0) : 0.0;
                const double remVolFrac = std::max(0.0, 1.0 - evapVolFrac);

                counted += w;
                evaporated += w * evapVolFrac;

                const double remVol = w * remVolFrac;
                const double xf = traj.back()[0];
                const double zf = traj.back()[1];
                const double downwindDist = xf - fieldEdgeFromSource;
                const bool deposited = zf <= depositHeight;

                if (deposited) {
                    if (downwindDist <= 0.0) {
                        inField += remVol;
                        inFieldInit += w;
                    }
                    else if (downwindDist <= maxDrift) {
                        offField += remVol;
                        offFieldInit += w;
                    }
                    else {
                        beyond += remVol;
                        beyondInit += w;
                    }
                }
                else {
                    airborne += remVol;
                    airborneInit += w;
                }
            }
        }
    }

    const double toPct = 100.0 / volumeSprayed;
    mb.inFieldDepositedPercent = inField * toPct;
    mb.offFieldDepositedPercent = offField * toPct;
    mb.beyondDomainPercent = beyond * toPct;
    mb.airbornePercent = airborne * toPct;
    mb.evaporatedPercent = evaporated * toPct;
    mb.resolvedVolumePercent = counted * toPct;
    mb.inFieldDepositedInitialPercent = inFieldInit * toPct;
    mb.offFieldDepositedInitialPercent = offFieldInit * toPct;
    mb.beyondDomainInitialPercent = beyondInit * toPct;
    mb.airborneInitialPercent = airborneInit * toPct;

    // Whatever is not represented by resolved DSD classes / active streamlines is
    // reported explicitly so the ledger closes to exactly 100%.
    const double accounted = mb.inFieldDepositedPercent + mb.offFieldDepositedPercent +
                             mb.beyondDomainPercent + mb.airbornePercent + mb.evaporatedPercent;
    mb.unresolvedPercent = std::max(0.0, 100.0 - accounted);

    return mb;
}

} // namespace cdm
