// Copyright (c) 2021 John Buonagurio <jbuonagurio@exponent.com>
// Copyright (c) 2021 Ed Casanova <eduardo.casanova@bayer.com>

#ifndef _USE_MATH_DEFINES
#define _USE_MATH_DEFINES
#endif

#include <algorithm>
#include <cmath>
#include <cstddef>
#include <numeric>
#include <utility>
#include <vector>

#include <fmt/core.h>
#include <boost/math/quadrature/gauss_kronrod.hpp>
#include <ceres/ceres.h>

#include "DropletSizeModel.hpp"

namespace cdm {

struct DSDCostFunctor
{
    DSDCostFunctor(double dp, double y, double dpmin)
        :  dp_(dp), y_(y), dpmin_(dpmin) {}
    
    template <typename T>
    bool operator()(const T* const a1, const T* const a2,
                    const T* const d1, const T* const d2,
                    const T* const k1, T* residual) const
    {
        using namespace boost::math::quadrature;
        auto f1 = [=](double x) { return exp(-pow(x-a1[0],2.) / (2.*pow(d1[0],2.))) / (d1[0]*sqrt(2.*M_PI)); };
        auto f2 = [=](double x) { return exp(-pow(x-a2[0],2.) / (2.*pow(d2[0],2.))) / (d2[0]*sqrt(2.*M_PI)); };
        double q1 = gauss_kronrod<double, 15>::integrate(f1, dpmin_, dp_);
        double q2 = gauss_kronrod<double, 15>::integrate(f2, dpmin_, dp_);
        residual[0] = y_ - 1 * (k1[0] * q1 + (1-k1[0]) * q2);
        return true;
    }

private:
    const double dp_;
    const double y_;
    const double dpmin_;
};

DropletSizeModel::DropletSizeModel()
{}

void DropletSizeModel::fit(const std::vector<std::pair<double, double>>& dsd)
{
    // Initial estimates.
    params_.a1 = 300;
    params_.a2 = 800;
    params_.d1 = 100;
    params_.d2 = 200;
    params_.k1 = 0.2;

    dpmin_ = std::min_element(dsd.begin(), dsd.end())->first;
    dpmax_ = std::max_element(dsd.begin(), dsd.end())->first;

    // Autodifferentiation is not supported for boost::math::quadrature.
    // Use numeric derivatives with central differences.
    ceres::Problem problem;
    for (size_t i = 0; i < dsd.size(); ++i) {
        problem.AddResidualBlock(
            new ceres::NumericDiffCostFunction<DSDCostFunctor, ceres::CENTRAL, 1, 1, 1, 1, 1, 1>(
                new DSDCostFunctor(dsd[i].first, dsd[i].second, dpmin_)),
            nullptr, &params_.a1, &params_.a2, &params_.d1, &params_.d2, &params_.k1);
    }

    ceres::Solver::Options options;
    options.minimizer_type = ceres::TRUST_REGION;
    options.trust_region_strategy_type = ceres::LEVENBERG_MARQUARDT;
    options.max_num_iterations = 200;
    options.linear_solver_type = ceres::DENSE_QR;
    options.dense_linear_algebra_library_type = ceres::EIGEN; // LAPACK
    options.logging_type = ceres::PER_MINIMIZER_ITERATION; // SILENT
    options.minimizer_progress_to_stdout = true;

    ceres::Solver::Summary summary;
    ceres::Solve(options, &problem, &summary);

    report_ = summary.BriefReport(); // FullReport
}

const char* DropletSizeModel::ceresVersion() const
{
    return CERES_VERSION_STRING;
}

double DropletSizeModel::dpmin() const
{
    return dpmin_;
}

double DropletSizeModel::dpmax() const
{
    return dpmax_;
}

DropletSizeModelParams DropletSizeModel::params() const
{
    return params_;
}

std::string DropletSizeModel::report() const
{
    return report_;
}

double DropletSizeModel::pdf(double x) const
{
    double y1 = params_.k1      / params_.d1 * exp(-pow(x-params_.a1,2.) / 2. / pow(params_.d1,2.));
    double y2 = (1.-params_.k1) / params_.d2 * exp(-pow(x-params_.a2,2.) / 2. / pow(params_.d2,2.));
    return (1./sqrt(2.*M_PI)) * (y1 + y2);
}

double DropletSizeModel::cdf(double x) const
{
    using namespace boost::math::quadrature;
    auto f1 = [=](double x) { return exp(-pow(x-params_.a1,2.) / (2.*pow(params_.d1,2.))) / (params_.d1*sqrt(2.*M_PI)); };
    auto f2 = [=](double x) { return exp(-pow(x-params_.a2,2.) / (2.*pow(params_.d2,2.))) / (params_.d2*sqrt(2.*M_PI)); };
    double q1 = gauss_kronrod<double, 15>::integrate(f1, dpmin_, x);
    double q2 = gauss_kronrod<double, 15>::integrate(f2, dpmin_, x);
    return params_.k1 * q1 + (1 - params_.k1) * q2;
}

std::vector<std::pair<double, double>> DropletSizeModel::calibration() const
{
    size_t n = (size_t)(dpmax_ - dpmin_);
    std::vector<std::pair<double, double>> result;
    result.reserve(n);
    result.push_back({0., 0.});
    for (size_t i = 0; i < n; ++i) {
        double x0 = i > 1 ? result[i-1].first : 0.;
        double y0 = i > 1 ? result[i-1].second : 0.;
        double x1 = dpmin_ + (double)i;
        double y1 = y0 + (pdf(x0) + pdf(x1)) / 2 * (x1 - x0);
        result.push_back({x1, y1});
    }
    return result;
}

} // namespace cdm