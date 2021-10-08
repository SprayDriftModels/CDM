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

void Deposition(double iar, double xactive, double fd, double pl, double dN, double psipsipsi, double rhoL,
                const std::array<std::vector<std::pair<double, double>>, 3>& xdist,
                const std::vector<std::pair<double, double>>& dsd,
                const DropletSizeModel *dsdmodel,
                double dpmin, double dpmax, std::optional<double> lmax, double lambda);

} // namespace cdm