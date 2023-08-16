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

    // Antoine vapor pressure constants. Regressed for high accuracy between -10 and 50°C.
    static constexpr double Aw = 18.92676;
    static constexpr double Bw = -4169.627;
    static constexpr double Cw = -33.568;

    // Convert input pressure from Pa to mmHg
    // 101325 Pa = 760 torr (mmHg) = 1 atm
    Patm *= 760. / 101325.;

    // Antoine vapor pressure for water in mmHg. 
    constexpr auto Psw = [](double T) {
        return exp(Aw + Bw / (T + 273.15 + Cw));
    };

    // Air heat capacity equation .vs. T, in cal/g air-°C
    constexpr auto Cpair = [](double T) {
        using constants::mwa;
        constexpr double Aair = 6.917;
        constexpr double Bair = 9.911e-4;
        constexpr double Cair = 7.627e-7;
        constexpr double Dair = -4.696e-10;
        return (Aair + Bair*T + Cair*pow(T,2.) + Dair*pow(T,3.)) / mwa;
    };
    
    // Heat of vaporization for water .vs. T, in cal/g water
    constexpr auto Dhv = [](double T) {
        constexpr double Dh0 = 717.2184;
        constexpr double N = 0.33246;
        return Dh0 * pow(1-(T+273.15)/647.3, N);
    };

    // Dew point temperature, °C.
    const double Tdp = Bw / (log(Psw(Tair) * (RH/100.)) - Aw) - 273.15 - Cw;

    // Wet bulb temperature function.
    auto EqnTwb = [=](double Twb) {
        using constants::mwa;
        using constants::mww;
        return Psw(Tdp) - Psw(Twb) - Patm * mwa/mww * Cpair(Twb) * (Twb-Tair) / Dhv(Twb);
    };

    // Find root using TOMS 748.
    double guess = Tair - (Tair - Tdp) / 3.; // Initial guess (1/3 rule).
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

} // namespace cdm