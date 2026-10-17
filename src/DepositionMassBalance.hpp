// Copyright (c) 2026

#pragma once

#include <array>
#include <memory>
#include <utility>
#include <vector>

#include "Constants.hpp"

namespace cdm {

struct DropletSizeModel;

// Closed volume ledger for the sprayed solution. All fields are expressed as a
// percentage of the total sprayed volume (%IAR basis) and, together with
// unresolvedPercent, sum to 100%. Evaporation is derived from the per-timestep
// droplet mass carried in each trajectory (initial vs. final water mass).
struct DepositionMassBalance {
    double inFieldDepositedPercent = 0.0;   // deposited on ground within the field
    double offFieldDepositedPercent = 0.0;  // deposited off-field within the max drift distance
    double beyondDomainPercent = 0.0;       // deposited beyond the max drift distance
    double airbornePercent = 0.0;           // still aloft at end of integration
    double evaporatedPercent = 0.0;         // water lost to evaporation
    double unresolvedPercent = 0.0;         // DSD tail / inactive streamlines not represented
    double resolvedVolumePercent = 0.0;     // fraction of sprayed volume covered by resolved classes
    // Same fate split on each droplet's INITIAL (pre-evaporation) volume ~ active-ingredient basis:
    // evaporation is not a loss (the AI lands as residue). These + unresolvedPercent close to 100%.
    double inFieldDepositedInitialPercent = 0.0;
    double offFieldDepositedInitialPercent = 0.0;
    double beyondDomainInitialPercent = 0.0;
    double airborneInitialPercent = 0.0;
};

// Computes a closed volume balance of the sprayed solution by classifying the
// final fate of every droplet trajectory (deposited/airborne/beyond-domain) and
// accounting for evaporated water along the way.
DepositionMassBalance ComputeDepositionMassBalance(
    double IAR, double xactive, double FD, double PL, double dN, double rhoL,
    double xs0, double rhoW, double rhoS,
    double depositHeight, double maxDrift,
    const std::vector<double>& dp,
    const std::array<std::vector<std::vector<std::array<double, 3>>>, constants::ns>& xzByTimestep,
    const std::vector<std::pair<double, double>>& dsd,
    const std::unique_ptr<DropletSizeModel>& dsdmodel,
    const std::array<bool, constants::ns>& sflags);

} // namespace cdm
