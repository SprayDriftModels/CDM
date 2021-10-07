// Copyright (c) 2021 John Buonagurio <jbuonagurio@exponent.com>
// Copyright (c) 2021 Ed Casanova <eduardo.casanova@bayer.com>

#include <algorithm>
#include <cmath>
#include <numeric>
#include <utility>
#include <vector>

#include <boost/math/statistics/linear_regression.hpp>

#include "WVProfile.hpp"
#include "Constants.hpp"
#include "Interpolate1D.hpp"

namespace cdm {

WVProfileResult WVProfile(const std::vector<std::pair<double, double>>& wvu,
                          const std::vector<std::pair<double, double>>& wvT,
                          PsiPsiPsiMethod pppMethod, double hC)
{
    WVProfileResult result{};

    // Calculate friction height.
    result.z0 = 0.00340738473 + 0.1244537 * hC;

    // Handle case where only one measurement is available.
    if (wvu.size() == 1) {
        auto [z1, ux1] = wvu[0];
        result.Uf = ux1 * constants::karman / log(z1 / result.z0);
        return result;
    }

    // Populate vectors with log-transformed elevations and wind speeds.
    std::vector<double> zzu, u, zzT, T;
    double zzusum = 0; // sum(log(zu/z0))
    double usum = 0; // sum(u)
    for (const auto& x : wvu) {
        u.push_back(x.second);
        zzu.push_back(log(x.first/result.z0));
        usum += u.back();
        zzusum += zzu.back();
    }

    // Calculate friction velocity.
    result.Uf = constants::karman * usum / zzusum;

    // Return now if ψψψ calculation is disabled or fewer than two temperature
    // measurements are available.
    if (pppMethod == PsiPsiPsiMethod::ENTERED || wvT.size() < 2) {
        return result;
    }

    // Populate vectors with log-transformed elevations and temperatures.
    for (const auto& x : wvT) {
        zzT.push_back(log(x.first/result.z0));
        T.push_back(x.second);
    }

    // Calculate richardson number (Ri).
    // Ri = gc/[(T(z1)+T(z2))/2+273.15]*(ΔT/Δz)/(ΔU/Δz)²
    #pragma warning(suppress:4244)
    const auto Tmodel = boost::math::statistics::simple_ordinary_least_squares(zzT, T);
    const auto Tfunc = [=](double z) { return 100. * (Tmodel.first + Tmodel.second * log(z/result.z0)); };
    const auto ufunc = [=](double z) { return 100. * (z * usum / zzusum); };
    const double Ri = (1. / 10000.) * 9.81 / ((Tfunc(0.3048) + Tfunc(9.144)) / 2. + 273.15) * ((Tfunc(0.3048) - Tfunc(9.144)) / (0.3048 - 9.144)) / pow((ufunc(0.3048) - ufunc(9.144)) / (0.3048 - 9.144), 2);
    
    // Richardson number (Ri) vs. ψψψ
    static const std::vector<std::pair<double, double>> pppdata = {
        {-0.860, 22.50},
        {-0.615, 20.00},
        {-0.235, 15.00},
        {-0.024, 10.00},
        { 0.094,  5.63},
        { 0.236,  2.88},
        { 0.339,  2.00}};

    // Calculate ψψψ.
    if (pppMethod == PsiPsiPsiMethod::INTERPOLATE) {
        const Interpolate1D pppfunc(pppdata);
        result.psipsipsi = pppfunc(Ri);
    }
    else if (pppMethod == PsiPsiPsiMethod::SDTF) {
        if (Ri > 0)
            result.psipsipsi = 0.524 * hC + 69.398 * Ri;
        else
            result.psipsipsi = 0.524 * hC - 69.398 * Ri;
    }

    return result;
}

//WVProfileResult WVProfile(double z1, double z2, double ux1, double ux2)
//{
//    double slope = (ux1 - ux2) / (log(z1) - log(z2));
//    double intercept = ux1 - slope * log(z1);
//
//    WVProfileResult result;
//    result.Uf = slope * constants::karman; 
//    result.z0 = exp(-intercept * constants::karman / result.Uf);
//    return result;
//}

//WVProfileResult WVProfile(double z1, double ux1, double hC)
//{
//    WVProfileResult result;
//    result.z0 = 0.00340738473 + 0.1244537 * hC;
//    result.Uf = ux1 * constants::karman / log(z1 / result.z0);
//    return result;
//}

} // namespace cdm