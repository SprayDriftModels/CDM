// Copyright (c) 2021 John Buonagurio <jbuonagurio@exponent.com>
// Copyright (c) 2021 Ed Casanova <eduardo.casanova@bayer.com>

#pragma once

#include <utility>
#include <vector>

namespace cdm {

/**
 * Calculates droplet transport distance.
 * \param[in] Tair Dry air temperature [°C]
 * \param[in] RH Relative humidity [percent]
 * \param[in] dTwb Wet bulb temperature depression [°C]
 * \param[in] z0 Friction height [m]
 * \param[in] Uf Friction velocity [m/s]
 * \param[in] rhoW Density of pure water in droplet [g/cm³]
 * \param[in] rhoS Density of dissolved solids in droplet, [g/cm³]
 * \param[in] xs0 Mass fraction total dissolved solids in solution [fraction]
 * \param[in] hN Height of nozzle above ground [m]
 * \param[in] hC Canopy height [m]
 * \param[in] vz Nozzle velocity, vertical [m/s]
 * \param[in] vx Nozzle velocity, horizontal [m/s]
 * \param[in] dp Droplet diameter [μm]
 * \return Distance [m]
 */
double DropletTransport(double Tair, double RH, double dTwb, double z0, double Uf, double rhoW, double rhoS, double xs0, double hN, double hC, double vz, double vx, double dp, double ddd);

} // namespace cdm