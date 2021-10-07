// Copyright (c) 2021 John Buonagurio <jbuonagurio@exponent.com>
// Copyright (c) 2021 Ed Casanova <eduardo.casanova@bayer.com>

#pragma once

#include <optional>

#include "InputParameters.hpp"

namespace cdm {

struct WVProfileResult {
    double z0; // Friction height [m]
    double Uf; // Friction velocity [m/s]
    std::optional<double> psipsipsi;
};

/**
 * Calculates wind velocity profile parameters. Calculation of psipsipsi
 * requires air temperature and velocity measurements at a minimum of 2 elevations.
 * The elevations need not be the same for wind speed and air temperature.
 * \param[in] wvu Elevation [m], Velocity [m/s]
 * \param[in] wvT Elevation [m], Temperature [°C]
 * \param[in] method 1=Interpolate, 2=SDTF
 * \param[in] hC Canopy height [m]
 * \return Friction height [m] and friction velocity [m/s]
 */
WVProfileResult WVProfile(const std::vector<std::pair<double, double>>& wvu,
                          const std::vector<std::pair<double, double>>& wvT,
                          PsiPsiPsiMethod pppMethod, double hC);

/**
 * Calculates wind velocity profile parameters using two measurements.
 * \param[in] z1 Elevation at measurement 1 [m]
 * \param[in] z2 Elevation at measurement 2 [m]
 * \param[in] ux1 Velocity at measurement 1 [m/s]
 * \param[in] ux2 Velocity at measurement 2 [m/s]
 * \return Friction height [m] and friction velocity [m/s]
 */
//WVProfileResult WVProfile(double z1, double z2, double ux1, double ux2);

/**
 * Calculates wind velocity profile parameters using one measurement.
 * \param[in] z1 Elevation at measurement 1 [m]
 * \param[in] ux1 Velocity at measurement 1 [m/s]
 * \param[in] hC Canopy height [m]
 * \return Friction height [m] and friction velocity [m/s]
 */
//WVProfileResult WVProfile(double z1, double ux1, double hC);

} // namespace cdm