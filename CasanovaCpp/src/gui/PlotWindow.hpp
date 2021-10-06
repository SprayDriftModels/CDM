// Copyright (c) 2021 John Buonagurio <jbuonagurio@exponent.com>

#pragma once

#include <vector>
#include <utility>

namespace cdm {
namespace gui {

void ShowPlotWindow(const std::vector<std::pair<double, double>>& dsd0,
                    const std::vector<std::pair<double, double>>& dsd1);

} // namespace gui
} // namespace cdm