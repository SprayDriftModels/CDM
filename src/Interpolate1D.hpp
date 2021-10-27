// Copyright (c) 2021 John Buonagurio <jbuonagurio@exponent.com>

#pragma once

#include <algorithm>
#include <optional>
#include <type_traits>
#include <utility>
#include <vector>

namespace cdm {

/**
 * Functor which uses linear interpolation to find the value of new points
 * given a vector of points which approximate some function y = f(x).
 */
template<bool Extrapolate=false>
struct Interpolate1D
{
    explicit Interpolate1D(const std::vector<std::pair<double, double>>& points)
        : points_(points)
    {
        std::sort(points_.begin(), points_.end());

        // Ensure each X value is associated with one Y value.
        points_.erase(std::unique(points_.begin(), points_.end(),
            [](const auto& a, const auto& b) {
                return a.first == b.first;
            }), points_.end());

        if (points_.size() < 2) {
            throw std::domain_error("At least 2 samples are required for linear interpolation.");
        }
    }

    Interpolate1D(const std::vector<std::pair<double, double>>& points, double lo, double hi)
        : Interpolate1D(points)
    {
        lo_ = lo;
        hi_ = hi;
    }
    
    Interpolate1D(const std::vector<double>& x, const std::vector<double>& y)
        : Interpolate1D(hstack(x, y))
    {}

    Interpolate1D(const std::vector<double>& x, const std::vector<double>& y, double lo, double hi)
        : Interpolate1D(hstack(x, y), lo, hi)
    {}

    void setLowerBound(double lo) { lo_ = lo; }
    
    void setUpperBound(double hi) { hi_ = hi; }

    double operator()(double x) const
    {
        using Tag = typename std::integral_constant<bool, Extrapolate>::type;

        auto it = std::lower_bound(points_.cbegin(), points_.cend(), x,
            [](const std::pair<double, double>& point, double x)
            { return point.first < x; });
        
        double result;
        if (it == points_.cend()) {
            result = fillvalue(points_.crbegin(), x, Tag{});
        }
        else if (it == points_.cbegin()) {
            result = fillvalue(points_.cbegin(), x, Tag{});
        }
        else {
            const auto [x0, y0] = *std::prev(it);
            const auto [x1, y1] = *it;
            result = y0 + ((x - x0) / (x1 - x0)) * (y1 - y0);
        }

        // Clamp to bounds.
        if (lo_.has_value() && result < *lo_)
            result = *lo_;
        if (hi_.has_value() && result > *hi_)
            result = *hi_;

        return result;
    }

private:
    inline std::vector<std::pair<double, double>> hstack(const std::vector<double>& x, const std::vector<double>& y) const
    {
        if (x.size() != y.size())
            throw std::domain_error("The same number of samples must be in the independent and dependent variable.");
        
        std::vector<std::pair<double, double>> result;
        result.reserve(x.size());
        std::transform(x.begin(), x.end(), y.begin(), std::back_inserter(result),
            [](double a, double b) { return std::make_pair(a, b); });

        return result;
    }

    template<class Iterator>
    inline double fillvalue(Iterator it, double x, std::true_type) const
    {
        // Use extrapolation.
        const auto [x0, y0] = *it;
        const auto [x1, y1] = *std::next(it);
        return y0 + ((x - x0) / (x1 - x0)) * (y1 - y0);
    }

    template<class Iterator>
    inline double fillvalue(Iterator it, double x, std::false_type) const
    {
        // Clamp to endpoint.
        return it->second;
    }

    std::vector<std::pair<double, double>> points_;
    std::optional<double> lo_;
    std::optional<double> hi_;
};

} // namespace cdm