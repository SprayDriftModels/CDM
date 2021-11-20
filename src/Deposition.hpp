// Copyright (c) 2021 John Buonagurio <jbuonagurio@exponent.com>
// Copyright (c) 2021 Ed Casanova <eduardo.casanova@bayer.com>

#pragma once

#include <memory>
#include <optional>
#include <utility>
#include <vector>

#include "DropletSizeModel.hpp"

namespace cdm {

std::vector<std::pair<double, double>> Deposition(double IAR, double xactive, double FD, double PL, double dN, double ppp, double rhoL,
                                                  const std::vector<double>& dp,
                                                  const std::array<std::vector<double>, 3>& xdist,
                                                  const std::vector<std::pair<double, double>>& dsd,
                                                  const std::unique_ptr<DropletSizeModel>& dsmodel,
                                                  double dpmin, double dpmax, std::optional<double> Lmax, double lambda, double dx);

} // namespace cdm