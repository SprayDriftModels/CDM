// Copyright (c) 2021 John Buonagurio <jbuonagurio@exponent.com>
// Copyright (c) 2021 Ed Casanova <eduardo.casanova@bayer.com>

#pragma once

namespace cdm {

struct NozzleVelocityResult {
    double vx1; // Centerline velocity, horizontal [m/s]
    double vz1; // Centerline velocity, vertical [m/s]
    double vx2; // Downwind velocity, horizontal [m/s]
    double vz2; // Downwind velocity, vertical [m/s]
    double vx3; // Upwind velocity, horizontal [m/s]
    double vz3; // Upwind velocity, vertical [m/s]
};

/**
 * Calculates nozzle straight down, downwind and upwind velocity components.
 * \param[in] PN Nozzle pressure [Pa]
 * \param[in] thetaN Nozzle angle [degrees]
 * \param[in] rhoL Mixture density [g/cm³]
 * \return Nozzle velocity components [m/s]
 */
NozzleVelocityResult NozzleVelocity(double P, double angle, double rhoL);

} // namespace cdm