// Copyright (c) 2021 John Buonagurio <jbuonagurio@exponent.com>
// Copyright (c) 2021 Ed Casanova <eduardo.casanova@bayer.com>

#pragma once

namespace cdm {

/**
 * Calculates the dry and wet bulb temperatures for air from rigorous equations.
 * \param[in] Tair Dry air temperature [°C]
 * \param[in] Patm Absolute barometric pressure [Pa]
 * \param[in] RH Relative humidity [percent]
 * \return Wet bulb temperature [°C]
 */
double WetBulbTemperature(double Tair, double Patm, double RH);

} // namespace cdm