// Copyright (c) 2021 John Buonagurio <jbuonagurio@exponent.com>
// Copyright (c) 2021 Ed Casanova <eduardo.casanova@bayer.com>

#include <cmath>

#include <boost/math/constants/constants.hpp>

#include "NozzleVelocity.hpp"

namespace cdm {

using boost::math::double_constants::pi;

// 1 Pa = 1 kg·m⁻¹·s⁻²
// 1 g·cm⁻³ = 1000 kg·m⁻³
// √(kg·m⁻¹·s⁻²)(kg⁻¹·m³) = m·s⁻¹
NozzleVelocity::NozzleVelocity(double PN, double thetaN, double rhoL)
    : NozzleVelocity(PN, thetaN, rhoL, sqrt(2. * 0.001 * PN/rhoL))
{}

NozzleVelocity::NozzleVelocity(double PN, double thetaN, double rhoL, double vi)
    : z({ -vi, -vi * cos(thetaN/3. * pi/180.), -vi * cos(thetaN/3. * pi/180.) }),
      x({   0,  vi * sin(thetaN/3. * pi/180.), -vi * sin(thetaN/3. * pi/180.) })
{}

} // namespace cdm