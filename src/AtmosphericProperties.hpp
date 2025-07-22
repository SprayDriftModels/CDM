// Copyright (c) 2023 John Buonagurio <jbuonagurio@exponent.com>
// Copyright (c) 2021 Ed Casanova <eduardo.casanova@bayer.com>

#pragma once

namespace cdm {

struct AtmosphericProperties
{
    /**
     * Derives thermodynamic properties for wet air under ambient conditions.
     * \param[in] T Dry air temperature [°C]
     * \param[in] P Absolute barometric pressure [Pa]
     * \param[in] RH Relative humidity [percent]
     */
    AtmosphericProperties(double T, double P, double RH);

    double wetAirDensity() const
        { return rhoA; }
    
    double wetAirDynamicViscosity() const
        { return muA; }
    
    double dewPointTemperature() const
        { return Tdp; }

    double wetBulbTemperature() const
        { return Twb; }

    double wetBulbTemperatureDepression() const
        { return dTwb; }

private:
    double rhoA; /**< Density of wet air (ρA) [g/cm³] */
    double muA;  /**< Dynamic viscosity of wet air at film (μA) [g·cm⁻¹s⁻¹] */
    double Tdp;  /**< Dew point temperature [°C] */
    double Twb;  /**< Wet bulb temperature [°C] */
    double dTwb; /**< Wet bulb temperature depression[°C] */
};

} // namespace cdm