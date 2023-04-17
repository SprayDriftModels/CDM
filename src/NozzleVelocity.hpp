// Copyright (c) 2021 John Buonagurio <jbuonagurio@exponent.com>
// Copyright (c) 2021 Ed Casanova <eduardo.casanova@bayer.com>

#pragma once

#include <array>

#include "Constants.hpp"

namespace cdm {

struct NozzleVelocity
{
    /**
     * Calculates nozzle velocity components.
     * \param[in] PN Nozzle pressure [Pa]
     * \param[in] theta Nozzle angle [degrees]
     * \param[in] rhoL Mixture density [g/cm³]
     */
    NozzleVelocity(double PN, double theta, double rhoL);

    /**
     * Streamline vector angles [degrees]
     */
    std::array<double, constants::ns> angle;

    /**
     * Vertical components of nozzle velocity [m/s]
     */
    std::array<double, constants::ns> z;

    /**
     * Horizontal components of nozzle velocity [m/s]
     */
    std::array<double, constants::ns> x;
};

} // namespace cdm