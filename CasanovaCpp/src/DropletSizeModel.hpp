// Copyright (c) 2021 John Buonagurio <jbuonagurio@exponent.com>
// Copyright (c) 2021 Ed Casanova <eduardo.casanova@bayer.com>

#pragma once

#include <string>
#include <utility>
#include <vector>

namespace cdm {

struct DropletSizeModelParams
{
    double a1 = 0;
    double a2 = 0;
    double d1 = 0;
    double d2 = 0;
    double k1 = 0;
};

struct DropletSizeModel
{
    /**
     * Fit a non-linear least squares model to a droplet size vs. cumulative volume fraction distribution.
     */
    explicit DropletSizeModel(const std::vector<std::pair<double, double>>& dsd);

    /**
     * Returns the Ceres version string.
     */
    const char* ceresVersion();

    /**
     * Returns the minimum droplet size from the input distribution.
     */
    double dpmin();

    /**
     * Returns the maximum droplet size from the input distribution.
     */
    double dpmax();

    /**
     * Returns the parameter estimates for the non-linear least squares model.
     */
    DropletSizeModelParams params();

    /**
     * Returns the Ceres solver report.
     */
    std::string report();

    /**
     * Density function for the non-linear least squares model.
     */
    double pdf(double x);

    /**
     * Cumulative distribution function for the non-linear least squares model.
     */
    double cdf(double x);

    /**
     * Returns the predicted cdf values between dpmin and dpmax calculated at 1 μm increments.
     * This implementation integrates the PDF using simple trapezoidal quadrature.
     */
    std::vector<std::pair<double, double>> calibration();

private:
    DropletSizeModelParams params_;
    double dpmin_;
    double dpmax_;
    std::string report_;
};

} // namespace cdm