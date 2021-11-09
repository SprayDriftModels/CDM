// Copyright (c) 2021 John Buonagurio <jbuonagurio@exponent.com>
// Copyright (c) 2021 Ed Casanova <eduardo.casanova@bayer.com>

#pragma once

namespace cdm {

struct NozzleVelocity
{
    /**
     * Calculates nozzle straight down, downwind and upwind velocity components.
     * \param[in] PN Nozzle pressure [Pa]
     * \param[in] thetaN Nozzle angle [degrees]
     * \param[in] rhoL Mixture density [g/cm³]
     */
    NozzleVelocity(double PN, double thetaN, double rhoL);

    /**
     * Vertical components of nozzle velocity (centerline, downwind, upwind) [m/s]
     */
    const std::array<double, 3> z;

    /**
     * Horizontal components of nozzle velocity (centerline, downwind, upwind) [m/s]
     */
    const std::array<double, 3> x;

private:
    NozzleVelocity(double PN, double thetaN, double rhoL, double zi);
};

} // namespace cdm