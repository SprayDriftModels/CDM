// Copyright (c) 2021 John Buonagurio <jbuonagurio@exponent.com>

#pragma once

#include <algorithm>
#include <vector>
#include <utility>

namespace cdm {

/**
 * Functor which uses linear interpolation to find the value of new points
 * given a vector of points which approximate some function y = f(x).
 */
struct Interpolate1D
{
    explicit Interpolate1D(const std::vector<std::pair<double, double>>& points) :
        points_(points)
    {
        std::sort(points_.begin(), points_.end());
    }

    double operator()(double x) const
    {
        auto it = std::lower_bound(points_.cbegin(), points_.cend(), x,
            [](const std::pair<double, double>& point, double x)
            { return point.first < x; });
        
        if (it == points_.cend()) {
            return std::prev(points_.cend())->second;
        }
    
        if (it == points_.cbegin()) {
            return points_.cbegin()->second;
        }

        const auto [x1, y1] = *it;
        const auto [x0, y0] = *std::prev(it);
        return y0 + ((x - x0) / (x1 - x0)) * (y1 - y0);
    }

private:
    std::vector<std::pair<double, double>> points_;
};

} // namespace cdm