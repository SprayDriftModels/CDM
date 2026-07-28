// Copyright (c) 2026

#pragma once

#include <cstddef>
#include <memory>
#include <utility>
#include <vector>

#include "DropletSizeModel.hpp"

namespace cdm {

// Total spray volume [L] derived from application parameters.
double ComputeVolumeSprayed(double IAR, double xactive, double FD, double PL, double rhoL);

// Per-class spray volumes [L] for class centers using CDF edge differences.
std::vector<double> ComputeClassVolumesFromCdfBins(
    double volumeSprayed,
    size_t nSourceAreas,
    const std::vector<double>& classCenters,
    const std::vector<std::pair<double, double>>& dsd,
    const std::unique_ptr<DropletSizeModel>& dsdmodel);

// Per-size partial volumes [L] for sampled diameters using PDF/finite-difference derivative.
std::vector<double> ComputePartialVolumesFromPdfSamples(
    double volumeSprayed,
    size_t nSourceAreas,
    const std::vector<double>& sampleDiameters,
    double sampleStep,
    const std::vector<std::pair<double, double>>& dsd,
    const std::unique_ptr<DropletSizeModel>& dsdmodel);

} // namespace cdm
