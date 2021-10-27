// Copyright (c) 2021 John Buonagurio <jbuonagurio@exponent.com>
// Copyright (c) 2021 Ed Casanova <eduardo.casanova@bayer.com>

#pragma once

#include <optional>

#include "InputParameters.hpp"

namespace cdm {

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
struct WindVelocityProfile
{
    WindVelocityProfile(const std::vector<std::pair<double, double>>& wvu,
                        const std::vector<std::pair<double, double>>& wvT,
                        InputParameters::PsiPsiPsiMethod pppMethod, double hC);

    double frictionHeight() const
        { return z0_; }
    
    double frictionVelocity() const
        { return Uf_; }
    
    std::optional<double> psipsipsi() const
        { return psipsipsi_; }

private:
    double z0_; // Friction height [m]
    double Uf_; // Friction velocity [m/s]
    std::optional<double> psipsipsi_;
};

} // namespace cdm