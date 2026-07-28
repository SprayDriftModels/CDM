// Copyright (c) 2026

#pragma once

#include <array>
#include <memory>
#include <utility>
#include <vector>

#include "Constants.hpp"
#include "DropletSizeModel.hpp"
#include "DropletTransport.hpp"
#include "Model.hpp"

namespace cdm {

std::vector<VerticalProfileByDistanceCellCrossing> VerticalProfileCellCrossingSingleNozzle(
    double IAR, double xactive, double FD, double PL,
    double dN, double rhoL,
    const std::vector<double>& dp,
    const std::array<std::vector<std::vector<std::array<double, 3>>>, constants::ns>& xzByTimestep,
    const std::vector<std::pair<double, double>>& dsd,
    const std::unique_ptr<DropletSizeModel>& dsdmodel,
    const std::vector<double>& heights,
    const std::vector<double>& distances,
    const std::array<bool, constants::ns>& sflags);

} // namespace cdm