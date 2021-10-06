// Copyright (c) 2021 John Buonagurio <jbuonagurio@exponent.com>
// Copyright (c) 2021 Ed Casanova <eduardo.casanova@bayer.com>

#ifndef _USE_MATH_DEFINES
#define _USE_MATH_DEFINES
#endif

#include <algorithm>
#include <array>
#include <cmath>
#include <iterator>
#include <numeric>
#include <vector>

#include <blaze/Math.h>

#include <fmt/core.h> // DEBUG

#include "Deposition.hpp"
#include "Interpolate1D.hpp"

namespace cdm {

void Deposition(double iar, double xactive, double fd, double pl, double dN, double psipsipsi, double rhoL,
                const std::array<std::vector<std::pair<double, double>>, 3>& xdist,
                const std::vector<std::pair<double, double>>& dsd,
                double dpmin, double dpmax, double lambda)
{
    // nsa = number of segments in sprayed area along field depth.
    // nda = number of segments in drift field.
    size_t nsa = static_cast<size_t>(fd / dN);
    size_t nda = static_cast<size_t>(nsa * lambda);

    // Multiplier for one sigma variation in wind direction, degrees.
    const double zeta = 2.5;

    // Droplet sizes to evaluate.
    const double ddp = 0.5;
    size_t mm = static_cast<size_t>((dpmax-dpmin)/ddp);
    blaze::DynamicVector<double> dpavg = blaze::generate(mm, [=](size_t i)
        { return dpmin + i * ddp; });
    
    // Generate drift distance vectors from xdist.
    // xdist[0]: // Centerline
    // xdist[1]: // Downwind
    // xdist[2]: // Upwind
    std::array<std::vector<double>, 3> driftdist;
    for (size_t n = 0; n < driftdist.size(); ++n) {
        auto ff = Interpolate1D(xdist.at(n));
        driftdist[n].resize(mm, 0.);
        for (size_t i = 1; i < driftdist[n].size(); ++i) {
            double dpavg = dpmin+i*ddp;
            driftdist[n].at(i) = ff(dpavg);
        }
    }

    //const double lmax = 200;
    const double lmax = std::max({*std::max_element(driftdist[0].begin(), driftdist[0].end()),
                                  *std::max_element(driftdist[1].begin(), driftdist[1].end()),
                                  *std::max_element(driftdist[2].begin(), driftdist[2].end())});
    
    // dwsa = width of spray segments, meters.
    // dwda = width of drift segments, meters.
    const double dwsa = fd / nsa;
    const double dwda = lmax / nda; 

    // 1 ha = 10000 m²
    // 1 g/cm³ = 1000 kg/m³
    const double sprayedArea = 0.0001 * fd * pl; // ha
    const double volumeSprayed = iar * sprayedArea / (rhoL * xactive); // L
    const double volumeAppRate = volumeSprayed / sprayedArea;

    // Calculate partial volume for each droplet size.
    // Approximation using numeric derivative with central differences.
    blaze::DynamicVector<double> svp(dpavg.size(), 0);
    const auto dsdfunc = Interpolate1D(dsd);
    for (size_t i = 1; i < svp.size(); ++i) {
        const double h = 0.001; // 0.5/mmm, mmm=500
        double grad = (dsdfunc(dpavg[i] + h*dpavg[i]) -
                       dsdfunc(dpavg[i] - h*dpavg[i])) / (2*h);
        svp[i] = grad/dpavg[i] * ddp * volumeSprayed / nsa;
    }
    
    // Width of each segment.
    blaze::DynamicVector<double> dwx = blaze::generate(nsa+nda, [=](size_t i)
        { return i < nsa ? dwsa : dwda; });
    
    // Distance from the back of the field (i.e., upwind) to the midpoint of each segment.
    blaze::DynamicVector<double> x = blaze::generate(nsa+nda, [=](size_t i)
        { return i < nsa ? dwsa*(0.5+i) : dwda*(0.5+i-nsa)+fd; });

    // Iterators to spray segment distances.
    const auto itsa0 = x.begin();
    const auto itsa1 = std::next(x.begin(), nsa);

    // Iterators to drift segment distances.
    const auto itda0 = std::next(x.begin(), nsa);
    const auto itda1 = std::next(x.begin(), nsa+nda);

    // Create DVM and CM matrices.
    // Upper and lower bound reversed for driftdist vectors in descending order. 
    blaze::DynamicMatrix<double> dvm(mm, nsa+nda, 0);
    blaze::DynamicMatrix<double> cm(mm, nsa+nda, 0);
    for (size_t n = 0; n < driftdist.size(); ++n) {
        for (size_t i = 1; i < mm; ++i) {
            // driftdist[i] >= (x[1:nsa]-dwsa) && driftdist[i] < x[1:nsa]
            const auto saupper = std::distance(itsa0, std::lower_bound(itsa0, itsa1, driftdist[n].at(i) + dwsa));
            const auto salower = std::distance(itsa0, std::upper_bound(itsa0, itsa1, driftdist[n].at(i)));
            for (ptrdiff_t j = salower; j < saupper; ++j) {
                auto dvms = blaze::submatrix(dvm, i, j, 1UL, nsa-j); // dvm[i,j:Nsa]
                auto cms = blaze::submatrix(cm, i, j, 1UL, nsa-j); // cm[i,j:Nsa]
                dvms += svp[i]/3;
                cms += (svp[i]/3) / (dwsa*(pl+2*(x[j]-0.5*dwsa)*tan(psipsipsi*M_PI*zeta/180.)));
            }

            for (size_t j = nsa; j < nsa+nda; ++j) {
                // driftdist[i] >= (x[1:nsa]+(j-nsa)*dwda) && driftdist[i] < (x[1:nsa]+(j+1-nsa)*dwda)
                const auto daupper = std::distance(itsa0, std::lower_bound(itsa0, itsa1, driftdist[n].at(i) - (j-nsa)*dwda));
                const auto dalower = std::distance(itsa0, std::upper_bound(itsa0, itsa1, driftdist[n].at(i) - (j+1-nsa)*dwda));
                if (dalower == 0 && daupper == 0) {
                    // Distances will continue to decrease above the current droplet size; exit loop.
                    break;
                }
                for (ptrdiff_t k = dalower; k < daupper; ++k) {
                    dvm(i,j) += svp[i]/3;
                    cm(i,j) += (svp[i]/3) / (dwda*(pl+2*(x[j]-x[nsa-k])*tan(psipsipsi*M_PI*zeta/180.)));
                }
            }
        }
    }

    blaze::DynamicVector<double, blaze::rowVector> vps = blaze::sum<blaze::columnwise>(dvm);
    blaze::DynamicVector<double, blaze::rowVector> cs = blaze::sum<blaze::columnwise>(cm);
    auto npdr = vps / (blaze::trans(dwx) * pl);
    double tv = blaze::sum(blaze::subvector(vps, 0UL, nsa));
    auto propAppliedPlume = cs / (volumeAppRate / 10000.);
    auto propAppliedNoPlume = npdr / (volumeAppRate / 10000.);

    fmt::print("Nsa = {}\n", nsa);
    fmt::print("Nda = {}\n", nda);
    fmt::print("DWsa = {}\n", dwsa);
    fmt::print("DWda = {}\n", dwda);
    fmt::print("SprayedArea = {}\n", sprayedArea);
    fmt::print("VolumeSprayed = {}\n", volumeSprayed);
    fmt::print("sum(SVP) * Nsa = {}\n", blaze::sum(svp) * nsa);
    fmt::print("sum(VPS) = {}\n", blaze::sum(vps));
    fmt::print("sum(CS) = {}\n", blaze::sum(cs));
    fmt::print("TV = {}\n", tv);
    fmt::print("VolumeSprayed - TV = {}\n", volumeSprayed - tv);

    std::vector<std::pair<double, double>> propAppliedPlumeXY;
    propAppliedPlumeXY.reserve(nsa+nda);
    for (size_t i = 0; i < nsa+nda; ++i) {
        propAppliedPlumeXY.emplace_back(std::make_pair(x.at(i) - fd, propAppliedPlume.at(i)));
    }

    const auto apfunc = Interpolate1D(propAppliedPlumeXY);
    std::vector<double> applume(100, 0);
    for (size_t i = 0; i < applume.size(); ++i) {
        applume.at(i) = apfunc(i*lmax/applume.size()) * 100.;
    }
    fmt::print("\n{:<8} {:>9}\n", "Distance", "Plume");
    for (size_t i = 0; i < applume.size(); ++i) {
        fmt::print("{:<8.3f} {:>8.4f}%\n", i*lmax/applume.size(), applume.at(i));
    }
}

} // namespace cdm