// Copyright (c) 2021 John Buonagurio <jbuonagurio@exponent.com>
// Copyright (c) 2021 Ed Casanova <eduardo.casanova@bayer.com>

#pragma once

#include <utility>
#include <vector>

namespace cdm {

void Deposition(double iar, double xactive, double fd, double pl, double dN, double psipsipsi, double rhoL,
                const std::array<std::vector<std::pair<double, double>>, 3>& xdist,
                const std::vector<std::pair<double, double>>& dsd,
                double dpmin, double dpmax, double lambda);

} // namespace cdm