// Copyright (c) 2021 John Buonagurio <jbuonagurio@exponent.com>
// Copyright (c) 2021 Ed Casanova <eduardo.casanova@bayer.com>

#include <cmath>
#include <limits>
#include <utility>

#include <boost/math/tools/roots.hpp>

#include "WetBulbTemperature.hpp"
#include "Constants.hpp"

namespace cdm {

double WetBulbTemperature(double Tair, double Patm, double RH)
{
    using boost::math::tools::eps_tolerance;
    using boost::math::tools::toms748_solve;
    using constants::mol_wt_air;
    using constants::mol_wt_water;

    // Antoine vapor pressure constants. Regressed for high accuracy between -10 and 50°C.
    constexpr double Aw = 18.92676;
    constexpr double Bw = -4169.627;
    constexpr double Cw = -33.568;

    // Convert input pressure from Pa to mmHg
    // 101325 Pa = 760 torr (mmHg) = 1 atm
    Patm = Patm * (760./101325.);

    // Antoine vapor pressure for water in mmHg. 
    constexpr auto Psw = [=](double T) {
        return exp(Aw + Bw / (T + 273.15 + Cw));
    };

    // Air heat capacity equation .vs. T, in cal/g air-°C
    constexpr auto Cpair = [=](double T) {
        double Aair = 6.917;
        double Bair = 9.911e-4;
        double Cair = 7.627e-7;
        double Dair = -4.696e-10;
        return (Aair + Bair*T + Cair*pow(T,2.) + Dair*pow(T,3.)) / mol_wt_air;
    };
    
    // Heat of vaporization for water .vs. T, in cal/g water
    constexpr auto Dhv = [=](double T) {
        double Dh0 = 717.2184;
        double N = 0.33246;
        return Dh0 * pow(1-(T+273.15)/647.3, N);
    };

    // Dew point temperature, °C.
    double Tdp = Bw / (log(Psw(Tair) * (RH/100.)) - Aw) - 273.15 - Cw;

    // Wet bulb temperature function.
    auto EqnTwb = [=](double Twb) {
        return Psw(Tdp) - Psw(Twb) - Patm * mol_wt_air/mol_wt_water * Cpair(Twb) * (Twb-Tair) / Dhv(Twb);
    };

    // Find root using TOMS 748.
    double guess = Tair - (Tair - Tdp) / 3.; // Initial guess (1/3 rule).
    double lower = guess / 2; // Lower bound for the initial bracket of the root.
    double upper = guess * 2; // Upper bound for the initial bracket of the root.
    uintmax_t max_iter = 20;  // Iteration limit.

    // Termination condition functor for specified number of bits.
    // Maximum value is std::numeric_limits<double>::digits - 1.
    eps_tolerance<double> tol(std::numeric_limits<double>::digits - 6);

    std::pair<double, double> r = toms748_solve(EqnTwb, lower, upper, tol, max_iter);
    return r.first + (r.second - r.first) / 2.;
}

} // namespace cdm