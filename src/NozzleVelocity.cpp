// Copyright (c) 2021 John Buonagurio <jbuonagurio@exponent.com>
// Copyright (c) 2021 Ed Casanova <eduardo.casanova@bayer.com>

#include <cmath>

#include <boost/math/constants/constants.hpp>

#include "NozzleVelocity.hpp"
#include "Constants.hpp"

namespace cdm {

NozzleVelocity::NozzleVelocity(double PN, double theta, double rhoL)
{
    using boost::math::double_constants::half;
    using boost::math::double_constants::degree;
    using constants::ns;

    // Spray velocity [m/s]
    // PN: 1 Pa = 1 kg·m⁻¹·s⁻²
    // ρL: 1 g·cm⁻³ = 1000 kg·m⁻³
    // vi: √[(kg·m⁻¹·s⁻²)(kg⁻¹·m³)] = m·s⁻¹
    const double vi = sqrt(2. * 0.001 * PN/rhoL);

    // Angle between each streamline segment (Δθ) [degrees]
    // Δθ = θ / NS
    const double dtheta = theta / (double)ns;

    // Angle between X-axis and edge of spray cone (α) [degrees]
    // α = (180 - θ) / 2
    const double alpha = half * (180. - theta);

    // Angle defining the midpoint of each streamline segment (Δβ) [degrees]
    // Δβ = Δθ / 2
    const double dbeta = half * dtheta;

    // Nozzle velocity components for each streamline segment [m/s]
    // vz = vi·sin(-α - Δβ - i·Δθ)
    // vx = vi·cos(-α - Δβ - i·Δθ)
    for (size_t i = 0; i < ns; ++i) {
        angle.at(i) = -alpha - dbeta - i * dtheta;
        z.at(i) = vi * sin(angle.at(i) * degree);
        x.at(i) = vi * cos(angle.at(i) * degree);
    }
}

} // namespace cdm