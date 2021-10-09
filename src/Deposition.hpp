// Copyright (c) 2021 John Buonagurio <jbuonagurio@exponent.com>
// Copyright (c) 2021 Ed Casanova <eduardo.casanova@bayer.com>

#pragma once

#include <optional>
#include <utility>
#include <vector>

#include "DropletSizeModel.hpp"

namespace cdm {

//struct DepositionResult {
//    std::vector<std::pair<double, double>> applume;
//};

void Deposition(double IAR, double xactive, double FD, double PL, double dN, double psipsipsi, double rhoL,
                const std::array<std::vector<std::pair<double, double>>, 3>& xdist,
                const std::vector<std::pair<double, double>>& dsd,
                const DropletSizeModel *dsdmodel,
                double dpmin, double dpmax, std::optional<double> Lmax, double lambda);

} // namespace cdm