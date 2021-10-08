// Copyright (c) 2021 John Buonagurio <jbuonagurio@exponent.com>
// Copyright (c) 2021 Ed Casanova <eduardo.casanova@bayer.com>

#include <cmath>

#include <boost/math/constants/constants.hpp>

#include "NozzleVelocity.hpp"

namespace cdm {

NozzleVelocityResult NozzleVelocity(double PN, double thetaN, double rhoL)
{
    using boost::math::double_constants::pi;
    NozzleVelocityResult result;
    // 1 Pa = 1 kg·m⁻¹·s⁻²
    // 1 g·cm⁻³ = 1000 kg·m⁻³
    // √(kg·m⁻¹·s⁻²)(kg⁻¹·m³) = m·s⁻¹
    double vi = sqrt(2. * 0.001 * PN/rhoL);
    result.vz1 = -vi;
    result.vx1 = 0;
    result.vz2 = -vi * cos(thetaN/3. * pi/180.);
    result.vx2 =  vi * sin(thetaN/3. * pi/180.);
    result.vz3 = -vi * cos(thetaN/3. * pi/180.);
    result.vx3 = -vi * sin(thetaN/3. * pi/180.);
    return result;
}

} // namespace cdm