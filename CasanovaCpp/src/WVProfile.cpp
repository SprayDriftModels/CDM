// Copyright (c) 2021 John Buonagurio <jbuonagurio@exponent.com>
// Copyright (c) 2021 Ed Casanova <eduardo.casanova@bayer.com>

#include <cmath>

#include "WVProfile.hpp"

namespace cdm {

WVProfileParams WVProfile(double z1, double z2, double ux1, double ux2)
{
    double slope = (ux1 - ux2) / (log(z1) - log(z2));
    double intercept = ux1 - slope * log(z1);

    WVProfileParams result;
    result.Uf = slope * 0.4; 
    result.z0 = exp(-intercept * 0.4 / result.Uf); 
    return result;
}

} // namespace cdm