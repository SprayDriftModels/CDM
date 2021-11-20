// Copyright (c) 2021 John Buonagurio <jbuonagurio@exponent.com>
// Copyright (c) 2021 Ed Casanova <eduardo.casanova@bayer.com>

#pragma once

#include <string>
#include <utility>
#include <vector>

#include <ceres/types.h>

namespace cdm {

struct DropletSizeModel
{
    struct Params {
        double a1;
        double a2;
        double d1;
        double d2;
        double k1;
    };

    DropletSizeModel(const std::vector<std::pair<double, double>>& dsd);

    /**
     * Returns the Ceres version string.
     */
    static const char* ceresVersion();

    /**
     * Fit a non-linear least squares model to a droplet size vs. cumulative volume fraction distribution.
     * Returns true if the solution is usable and parameter blocks were updated.
     */
    bool fit();

    /**
     * Returns the minimum droplet size from the input distribution, or zero if empty.
     */
    double dpmin() const;

    /**
     * Returns the maximum droplet size from the input distribution, or zero if empty.
     */
    double dpmax() const;

    /**
     * Returns the parameter estimates for the non-linear least squares model.
     */
    Params params() const;

    /**
     * Returns the Ceres solver report.
     */
    std::string report() const;

    /**
     * Returns the termination status of the minimizer.
     */
    ceres::TerminationType status() const;

    /**
     * Returns true if the solution is usable and parameter blocks were updated.
     */
    bool valid() const;

    /**
     * Returns the fitted values for each droplet size.
     */
    std::vector<double> predicted() const;

    /**
     * Returns the residuals for fitted values (observed minus predicted).
     */
    std::vector<double> residuals() const;

    /**
     * Density function for the non-linear least squares model.
     */
    double pdf(double x) const;

    /**
     * Cumulative distribution function for the non-linear least squares model.
     */
    double cdf(double x) const;

private:
    std::vector<std::pair<double, double>> dsd_;
    std::pair<std::vector<std::pair<double, double>>::const_iterator,
              std::vector<std::pair<double, double>>::const_iterator> minmax_;
    Params params_ = {};
    std::string report_;
    ceres::TerminationType status_ = ceres::TerminationType::FAILURE;
    bool valid_ = false;
};

} // namespace cdm