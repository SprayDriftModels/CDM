// Copyright (c) 2021 John Buonagurio <jbuonagurio@exponent.com>
// Copyright (c) 2021 Ed Casanova <eduardo.casanova@bayer.com>

#pragma once

namespace cdm {

struct WVProfileParams {
    double z0; // Friction height [m]
    double Uf; // Friction velocity [m/s]
};

/**
 * Calculates wind velocity profile parameters using two measurements.
 * \param[in] z1 Elevation at measurement 1 [m]
 * \param[in] z2 Elevation at measurement 2 [m]
 * \param[in] ux1 Velocity at measurement 1 [m/s]
 * \param[in] ux2 Velocity at measurement 2 [m/s]
 */
WVProfileParams WVProfile(double z1, double z2, double ux1, double ux2);

} // namespace cdm