// Copyright (c) 2021 John Buonagurio <jbuonagurio@exponent.com>
// Copyright (c) 2021 Ed Casanova <eduardo.casanova@bayer.com>

#pragma once

#include <optional>

#include "Model.hpp"
#include "Constants.hpp"

namespace cdm {

/**
 * Calculates wind velocity profile parameters. Calculation of ppp
 * requires air temperature and velocity measurements at a minimum of 2 elevations.
 * The elevations need not be the same for wind speed and air temperature.
 * \param[in] wvu Elevation [m], Velocity [m/s]
 * \param[in] wvT Elevation [m], Temperature [°C]
 * \param[in] method 1=Interpolate, 2=SDTF
 * \param[in] hC Canopy height [m]
 */
struct WindVelocityProfile
{
    WindVelocityProfile(const std::vector<std::pair<double, double>>& wvu,
                        const std::vector<std::pair<double, double>>& wvT,
                        PPPMethod pppMethod, double hC);

    double frictionHeight() const
        { return z0_; }
    
    double frictionVelocity() const
        { return Uf_; }
    
    double psipsipsi() const
        { return psipsipsi_; }

private:
    double z0_; // Friction height [m]
    double Uf_; // Friction velocity [m/s]
    double psipsipsi_ = constants::default_psipsipsi;
};

} // namespace cdm