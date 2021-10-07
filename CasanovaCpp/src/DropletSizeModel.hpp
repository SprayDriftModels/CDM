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
    DropletSizeModel();

    /**
     * Fit a non-linear least squares model to a droplet size vs. cumulative volume fraction distribution.
     */
    void fit(const std::vector<std::pair<double, double>>& dsd);

    /**
     * Returns the Ceres version string.
     */
    const char* ceresVersion() const;

    /**
     * Returns the minimum droplet size from the input distribution.
     */
    double dpmin() const;

    /**
     * Returns the maximum droplet size from the input distribution.
     */
    double dpmax() const;

    /**
     * Returns the parameter estimates for the non-linear least squares model.
     */
    DropletSizeModelParams params() const;

    /**
     * Returns the Ceres solver report.
     */
    std::string report() const;

    /**
     * Density function for the non-linear least squares model.
     */
    double pdf(double x) const;

    /**
     * Cumulative distribution function for the non-linear least squares model.
     */
    double cdf(double x) const;

    /**
     * Returns the predicted cdf values between dpmin and dpmax calculated at 1 μm increments.
     * This implementation integrates the PDF using simple trapezoidal quadrature.
     */
    std::vector<std::pair<double, double>> calibration() const;

private:
    DropletSizeModelParams params_;
    double dpmin_ = 0;
    double dpmax_ = 0;
    std::string report_;
};

} // namespace cdm