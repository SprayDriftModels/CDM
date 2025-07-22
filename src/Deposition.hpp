// Copyright (c) 2021 John Buonagurio <jbuonagurio@exponent.com>
// Copyright (c) 2021 Ed Casanova <eduardo.casanova@bayer.com>

#pragma once

#include <memory>
#include <optional>
#include <utility>
#include <vector>

#include "Constants.hpp"
#include "DropletSizeModel.hpp"

namespace cdm {

/**
 * Calculates deposition.
 * \param[in] IAR Intended application rate [kg/ha]
 * \param[in] xactive Concentration in tank solution [wt. fraction]
 * \param[in] FD Downwind field depth [m]
 * \param[in] PL Crosswind field width [m]
 * \param[in] dN Space between nozzles on boom [m]
 * \param[in] ppp Horizontal variation in wind direction around mean (ψψψ) [degrees]
 * \param[in] rhoL Mixture density [g/cm³]
 * \param[in] dp Output droplet sizes [μm]
 * \param[in] xdist Transport distances [m]
 * \param[in] dsd Measured droplet size distribution
 * \param[in] dsmodel Non-linear least squares model for droplet size
 * \param[in] dpmin Minimum droplet size for deposition [μm]
 * \param[in] dpmax Maximum droplet size for deposition [μm]
 * \param[in] Lmax Maximum drift distance for deposition [m]
 * \param[in] lambda Scale factor for number of drift segments (λ), ≥1
 * \param[in] dx Distance interval for deposition output [m]
 * \param[in] sflags Enabled streamlines for deposition
 * \return Drift distance [m] and percent of applied.
 */
std::vector<std::pair<double, double>> Deposition(double IAR, double xactive, double FD, double PL, double dN, double ppp, double rhoL,
                                                  const std::vector<double>& dp,
                                                  const std::array<std::vector<double>, constants::ns>& xdist,
                                                  const std::vector<std::pair<double, double>>& dsd,
                                                  const std::unique_ptr<DropletSizeModel>& dsmodel,
                                                  double dpmin, double dpmax, std::optional<double> Lmax, double lambda, double dx,
                                                  const std::array<bool, constants::ns>& sflags);

} // namespace cdm