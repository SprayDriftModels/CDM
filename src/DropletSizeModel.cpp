// Copyright (c) 2021 John Buonagurio <jbuonagurio@exponent.com>
// Copyright (c) 2021 Ed Casanova <eduardo.casanova@bayer.com>

#include <algorithm>
#include <cmath>
#include <cstddef>
#include <limits>
#include <numeric>
#include <utility>
#include <vector>

#include <fmt/core.h>

#include <boost/math/constants/constants.hpp>
#include <boost/math/distributions/normal.hpp>

#include <ceres/ceres.h>

#include "DropletSizeModel.hpp"

namespace cdm {

struct DSDCostFunctor
{
    DSDCostFunctor(double dp, double y, double dpmin)
        :  dp_(dp), y_(y), dpmin_(dpmin) {}
    
    template<typename T>
    bool operator()(const T* const a1, const T* const a2,
                    const T* const d1, const T* const d2,
                    const T* const k1, T* residual) const
    {
        namespace bm = boost::math;
        const bm::normal N1(*a1, *d1);
        const bm::normal N2(*a2, *d2);
        const double Fx1 = (bm::cdf(N1, dp_) - bm::cdf(N1, dpmin_)) * (*k1);
        const double Fx2 = (bm::cdf(N2, dp_) - bm::cdf(N2, dpmin_)) * (1 - *k1);
        residual[0] = y_ - (Fx1 + Fx2);
        return true;
    }

private:
    const double dp_;
    const double y_;
    const double dpmin_;
};

DropletSizeModel::DropletSizeModel()
{}

bool DropletSizeModel::fit(const std::vector<std::pair<double, double>>& dsd)
{
    // Initial estimates.
    params_.a1 = 300; // μ1, DV50
    params_.a2 = 800; // μ2, DV90
    params_.d1 = 100; // σ1
    params_.d2 = 200; // σ2
    params_.k1 = 0.5; // w1

    dpmin_ = std::min_element(dsd.begin(), dsd.end())->first;
    dpmax_ = std::max_element(dsd.begin(), dsd.end())->first;

    ceres::Problem problem;
    
    // ceres::Problem takes ownership of the cost function.
    // Boost.Math functions may throw std::domain_error.
    for (size_t i = 0; i < dsd.size(); ++i) {
        problem.AddResidualBlock(
            new ceres::NumericDiffCostFunction<DSDCostFunctor, ceres::FORWARD, 1, 1, 1, 1, 1, 1>(
                new DSDCostFunctor(dsd[i].first, dsd[i].second, dpmin_)),
            nullptr, &params_.a1, &params_.a2, &params_.d1, &params_.d2, &params_.k1);
    }

    problem.SetParameterLowerBound(&params_.d1, 0, std::numeric_limits<double>::min());
    problem.SetParameterLowerBound(&params_.d2, 0, std::numeric_limits<double>::min());
    problem.SetParameterLowerBound(&params_.k1, 0, 0.);
    problem.SetParameterUpperBound(&params_.k1, 0, 1.);

    ceres::Solver::Options options;
    options.minimizer_type = ceres::TRUST_REGION;
    options.trust_region_strategy_type = ceres::LEVENBERG_MARQUARDT;
    options.max_num_iterations = 200;
    options.linear_solver_type = ceres::DENSE_QR;
    options.dense_linear_algebra_library_type = ceres::EIGEN; // LAPACK
    options.logging_type = ceres::SILENT; // PER_MINIMIZER_ITERATION
    options.minimizer_progress_to_stdout = true;

    ceres::Solver::Summary summary;
    ceres::Solve(options, &problem, &summary);
    report_ = summary.BriefReport(); // FullReport

    return summary.IsSolutionUsable();
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

DropletSizeModel::Params DropletSizeModel::params() const
{
    return params_;
}

std::string DropletSizeModel::report() const
{
    return report_;
}

double DropletSizeModel::pdf(double x) const
{
    // Normal PDF:
    // f(x) = [1/(σ√(2π))] * exp[-0.5 * ((x-μ)/σ)²]
    // f(x) = (1/σ) * φ[(x-μ)/σ]
    // Boost.Math functions may throw std::domain_error.

    namespace bm = boost::math;
    const bm::normal N1(params_.a1, params_.d1);
    const bm::normal N2(params_.a2, params_.d2);
    const double fx1 = bm::pdf(N1, x) * params_.k1;
    const double fx2 = bm::pdf(N2, x) * (1 - params_.k1);
    return fx1 + fx2;
}

double DropletSizeModel::cdf(double x) const
{
    // Normal CDF:
    // F(x) = 0.5 * [1 + erf((x-μ)/σ√2)]
    // F(x) = Φ[(x-μ)/σ]
    // Boost.Math functions may throw std::domain_error.

    namespace bm = boost::math;
    const bm::normal N1(params_.a1, params_.d1);
    const bm::normal N2(params_.a2, params_.d2);
    const double Fx1 = (bm::cdf(N1, x) - bm::cdf(N1, dpmin_)) * params_.k1;
    const double Fx2 = (bm::cdf(N2, x) - bm::cdf(N2, dpmin_)) * (1 - params_.k1);
    return Fx1 + Fx2;
}

} // namespace cdm