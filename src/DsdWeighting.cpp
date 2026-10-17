// Copyright (c) 2026

#include <algorithm>
#include <optional>

#include <boost/math/differentiation/finite_difference.hpp>

#include "DsdWeighting.hpp"
#include "Interpolate1D.hpp"

namespace cdm {

double ComputeVolumeSprayed(double IAR, double xactive, double FD, double PL, double rhoL)
{
    const double sprayedArea = 0.0001 * FD * PL; // ha
    return IAR * sprayedArea / (rhoL * xactive); // L
}

std::vector<double> ComputeClassVolumesFromCdfBins(
    double volumeSprayed,
    size_t nSourceAreas,
    const std::vector<double>& classCenters,
    const std::vector<std::pair<double, double>>& dsd,
    const std::unique_ptr<DropletSizeModel>& dsdmodel)
{
    std::vector<double> classVolumes(classCenters.size(), 0.0);
    if (classCenters.empty() || nSourceAreas == 0) {
        return classVolumes;
    }

    std::vector<double> edges;
    edges.reserve(classCenters.size() + 1);
    edges.emplace_back(classCenters.front());
    for (size_t i = 1; i < classCenters.size(); ++i) {
        edges.emplace_back((classCenters[i - 1] + classCenters[i]) / 2.0);
    }
    edges.emplace_back(classCenters.back());

    std::optional<Interpolate1D<true>> dsdFunc;
    if (!dsdmodel) {
        dsdFunc.emplace(dsd, 0.0, 1.0);
    }

    auto cdf = [&](double diameter) {
        if (dsdmodel) {
            return dsdmodel->cdf(diameter);
        }
        return dsdFunc.value()(diameter);
    };

    for (size_t i = 0; i < classCenters.size(); ++i) {
        const double upper = cdf(edges[i + 1]);
        const double lower = cdf(edges[i]);
        const double fraction = std::max(0.0, upper - lower);
        classVolumes[i] = fraction * volumeSprayed / static_cast<double>(nSourceAreas);
    }

    return classVolumes;
}

std::vector<double> ComputePartialVolumesFromPdfSamples(
    double volumeSprayed,
    size_t nSourceAreas,
    const std::vector<double>& sampleDiameters,
    double sampleStep,
    const std::vector<std::pair<double, double>>& dsd,
    const std::unique_ptr<DropletSizeModel>& dsdmodel)
{
    using namespace boost::math::differentiation;

    std::vector<double> partialVolumes(sampleDiameters.size(), 0.0);
    if (sampleDiameters.empty() || nSourceAreas == 0) {
        return partialVolumes;
    }

    if (dsdmodel) {
        // Use non-linear least squares curve fit.
        for (size_t i = 1; i < partialVolumes.size(); ++i) {
            const double y = dsdmodel->pdf(sampleDiameters[i]);
            partialVolumes[i] = y * sampleStep * volumeSprayed / static_cast<double>(nSourceAreas);
        }
    }
    else {
        // Approximation using finite differences. Use extrapolation and clamp estimates to [0, 1].
        // Interpolate1D/derivative evaluation may throw std::domain_error.
        const auto dsdfunc = Interpolate1D<true>(dsd, 0, 1);
        for (size_t i = 1; i < partialVolumes.size(); ++i) {
            const double y = finite_difference_derivative<decltype(dsdfunc), double, 1>(dsdfunc, sampleDiameters[i]);
            partialVolumes[i] = y * sampleStep * volumeSprayed / static_cast<double>(nSourceAreas);
        }
    }

    return partialVolumes;
}

} // namespace cdm
