// Copyright (c) 2021 John Buonagurio <jbuonagurio@exponent.com>
// Copyright (c) 2021 Ed Casanova <eduardo.casanova@bayer.com>

#include <algorithm>
#include <cmath>
#include <cstddef>
#include <numeric>
#include <utility>
#include <vector>

#include <fmt/core.h>

#include <boost/math/constants/constants.hpp>
#include <boost/math/distributions/normal.hpp>
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
        //using boost::math::double_constants::root_two_pi;
        //using namespace boost::math::quadrature;
        //auto f1 = [=](double x) { return exp(-pow(x-a1[0],2.) / (2.*pow(d1[0],2.))) / (d1[0]*root_two_pi); };
        //auto f2 = [=](double x) { return exp(-pow(x-a2[0],2.) / (2.*pow(d2[0],2.))) / (d2[0]*root_two_pi); };
        //double q1 = gauss_kronrod<double, 15>::integrate(f1, dpmin_, dp_);
        //double q2 = gauss_kronrod<double, 15>::integrate(f2, dpmin_, dp_);
        //residual[0] = y_ - 1 * (k1[0] * q1 + (1-k1[0]) * q2);
        //return true;

        namespace bm = boost::math;
        
        if (d1[0] < 0 || d2[0] < 0)
            return false;
        
        const bm::normal N1(a1[0], d1[0]);
        const bm::normal N2(a2[0], d2[0]);
        const double q1 = (bm::cdf(N1, dp_) - bm::cdf(N1, dpmin_)) * k1[0];
        const double q2 = (bm::cdf(N2, dp_) - bm::cdf(N2, dpmin_)) * (1 - k1[0]);
        residual[0] = y_ - (q1 + q2);
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

    // Autodifferentiation is not supported for boost::math::quadrature. Use finite difference.
    for (size_t i = 0; i < dsd.size(); ++i) {
        problem.AddResidualBlock(
            new ceres::NumericDiffCostFunction<DSDCostFunctor, ceres::FORWARD, 1, 1, 1, 1, 1, 1>(
                new DSDCostFunctor(dsd[i].first, dsd[i].second, dpmin_)),
            nullptr, &params_.a1, &params_.a2, &params_.d1, &params_.d2, &params_.k1);
    }

    problem.SetParameterLowerBound(&params_.d1, 0, 0.);
    problem.SetParameterLowerBound(&params_.d2, 0, 0.);
    problem.SetParameterLowerBound(&params_.k1, 0, 0.);
    problem.SetParameterUpperBound(&params_.k1, 0, 1.);

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

    // Return success condition if the parameter block was updated.
    switch (summary.termination_type) {
    case ceres::TerminationType::CONVERGENCE:
    case ceres::TerminationType::NO_CONVERGENCE:
    case ceres::TerminationType::USER_SUCCESS:
        return true;
    case ceres::TerminationType::FAILURE:
    case ceres::TerminationType::USER_FAILURE:
        return false;
    }
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
    // Normal PDF:
    // f(x) = [1/(σ√(2π))] * exp[-0.5 * ((x-μ)/σ)²]
    // f(x) = (1/σ) * φ[(x-μ)/σ]

    //using boost::math::double_constants::root_two_pi;
    //double p1 = (1/params_.d1) * exp(-0.5*pow((x-params_.a1)/params_.d1, 2.)) / root_two_pi;
    //double p2 = (1/params_.d2) * exp(-0.5*pow((x-params_.a2)/params_.d2, 2.)) / root_two_pi;
    //return params_.k1 * p1 + (1 - params_.k1) * p2;

    namespace bm = boost::math;
    const bm::normal N1(params_.a1, params_.d1);
    const bm::normal N2(params_.a2, params_.d2);
    const double p1 = bm::pdf(N1, x) * params_.k1;
    const double p2 = bm::pdf(N2, x) * (1 - params_.k1);
    return p1 + p2;
}

double DropletSizeModel::cdf(double x) const
{
    // Normal CDF:
    // F(x) = 0.5 * [1 + erf((x-μ)/σ√2)]
    // F(x) = Φ[(x-μ)/σ]
    
    //using boost::math::double_constants::root_two_pi;
    //using namespace boost::math::quadrature;
    //auto f1 = [=](double x) { return exp(-pow(x-params_.a1,2.) / (2.*pow(params_.d1,2.))) / (params_.d1*root_two_pi); };
    //auto f2 = [=](double x) { return exp(-pow(x-params_.a2,2.) / (2.*pow(params_.d2,2.))) / (params_.d2*root_two_pi); };
    //double q1 = gauss_kronrod<double, 15>::integrate(f1, dpmin_, x);
    //double q2 = gauss_kronrod<double, 15>::integrate(f2, dpmin_, x);
    //return params_.k1 * q1 + (1 - params_.k1) * q2;

    namespace bm = boost::math;
    const bm::normal N1(params_.a1, params_.d1);
    const bm::normal N2(params_.a2, params_.d2);
    const double q1 = (bm::cdf(N1, x) - bm::cdf(N1, dpmin_)) * params_.k1;
    const double q2 = (bm::cdf(N2, x) - bm::cdf(N2, dpmin_)) * (1 - params_.k1);
    return q1 + q2;
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