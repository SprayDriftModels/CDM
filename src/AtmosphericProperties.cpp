// Copyright (c) 2023 John Buonagurio <jbuonagurio@exponent.com>
// Copyright (c) 2021 Ed Casanova <eduardo.casanova@bayer.com>

#include <cmath>
#include <limits>
#include <utility>

#include <boost/math/tools/roots.hpp>

#include "AtmosphericProperties.hpp"
#include "Constants.hpp"

namespace cdm {

/**
 * Calculates the wet bulb temperature for air from rigorous equations.
 * \param[in] T Dry air temperature [°C]
 * \param[in] Tdp Dew point temperature [°C]
 * \param[in] P Absolute barometric pressure [Pa]
 * \return Wet bulb temperature [°C]
 */
static double EstimateTwb(double T, double Tdp, double P)
{
    using constants::Aw;
    using constants::Bw;
    using constants::Cw;
    using constants::mwa;
    using constants::mww;

    using boost::math::tools::eps_tolerance;
    using boost::math::tools::toms748_solve;
    
    // Convert barometric pressure from Pa to mmHg.
    // 101325 Pa = 760 torr (mmHg) = 1 atm
    P *= 760. / 101325.;

    // Antoine vapor pressure for water, mmHg
    constexpr auto Psw = [](double T)
        { return exp(Aw + Bw / (T + 273.15 + Cw)); };
    
    // Wet bulb temperature function.
    auto EqnTwb = [=](double Twb) {
        // Air heat capacity equation, cal/g air-°C
        constexpr auto Cpa = [](double T) {
            constexpr double A = 6.917;
            constexpr double B = 9.911e-4;
            constexpr double C = 7.627e-7;
            constexpr double D = -4.696e-10;
            return (A + B*T + C*pow(T,2.) + D*pow(T,3.)) / mwa;
        };
        // Heat of vaporization for water, cal/g water
        constexpr auto Dhv = [](double T) {
            constexpr double Dh0 = 717.2184;
            constexpr double N = 0.33246;
            return Dh0 * pow(1-(T+273.15)/647.3, N);
        };
        return Psw(Tdp) - Psw(Twb) - P * mwa/mww * Cpa(Twb) * (Twb-T) / Dhv(Twb);
    };

    // Find root using TOMS 748.
    double guess = T - (T - Tdp) / 3.; // Initial guess (1/3 rule).
    double lower = guess / 2; // Lower bound for the initial bracket of the root.
    double upper = guess * 2; // Upper bound for the initial bracket of the root.
    uintmax_t max_iter = 50;  // Iteration limit.

    // Termination condition functor for specified number of bits.
    // Maximum value is std::numeric_limits<double>::digits - 1.
    eps_tolerance<double> tol(std::numeric_limits<double>::digits - 6);

    // May throw boost::math::evaluation_error.
    std::pair<double, double> r = toms748_solve(EqnTwb, lower, upper, tol, max_iter);
    return r.first + (r.second - r.first) / 2.;
}

AtmosphericProperties::AtmosphericProperties(double T, double P, double RH)
{
    using constants::Aw;
    using constants::Bw;
    using constants::Cw;
    using constants::mwa;
    using constants::mww;

    // Antoine vapor pressure for water, atm
    // 101325 Pa = 760 torr (mmHg) = 1 atm
    constexpr auto Psw = [](double T, double RH)
        { return exp(Aw + log(RH/100.) + Bw / (T + 273.15 + Cw)) / 760.; };

    // Density of wet air (ρA), g/cm³
    rhoA = (mww * Psw(T,RH) + mwa * (1.-Psw(T,RH))) / (82.061 * (T + 273.15));

    // Dynamic viscosity of wet air at film (μA), g·cm⁻¹s⁻¹
    constexpr double K0 = 1.765e-4;
    constexpr double K1 = 4.752e-7;
    constexpr double K2 = -1.478e-4;
    muA = K0 + K1*T + K2*Psw(T,RH);

    // Dew point temperature, °C
    Tdp = Bw / (log(Psw(T,RH) * 760.) - Aw) - 273.15 - Cw;
    
    // Wet bulb temperature, °C
    Twb = EstimateTwb(T, Tdp, P);

    // Wet bulb temperature depression, °C
    dTwb = T - Twb;
}

} // namespace cdm