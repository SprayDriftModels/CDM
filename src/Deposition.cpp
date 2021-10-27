// Copyright (c) 2021 John Buonagurio <jbuonagurio@exponent.com>
// Copyright (c) 2021 Ed Casanova <eduardo.casanova@bayer.com>

#include <algorithm>
#include <array>
#include <cmath>
#include <iterator>
#include <numeric>
#include <vector>

#include <boost/math/constants/constants.hpp>
#include <boost/math/differentiation/finite_difference.hpp>

#include <blaze/Math.h>

#include <fmt/core.h> // DEBUG

#include "Deposition.hpp"
#include "Interpolate1D.hpp"

namespace cdm {

void Deposition(double IAR, double xactive, double FD, double PL, double dN, double ppp, double rhoL,
                const std::vector<double>& dp,
                const std::array<std::vector<double>, 3>& xdist,
                const std::vector<std::pair<double, double>>& dsd,
                const DropletSizeModel *dsdmodel,
                double dpmin, double dpmax, std::optional<double> Lmax, double lambda)
{
    using namespace boost::math::differentiation;
    using boost::math::double_constants::pi;

    // Multiplier for one sigma variation in wind direction (ζ), degrees.
    const double zeta = 2.5;

    // Droplet sizes to evaluate.
    const double ddp = 0.5;
    size_t mm = static_cast<size_t>((dpmax - dpmin) / ddp);
    blaze::DynamicVector<double> dpavg = blaze::generate(mm, [=](size_t i)
        { return dpmin + i * ddp; });
    
    // Generate drift distance vectors from xdist. May throw std::domain_error.
    std::array<std::vector<double>, 3> driftdist;
    for (size_t n = 0; n < driftdist.size(); ++n) {
        auto ff = Interpolate1D(dp, xdist.at(n));
        driftdist[n].resize(mm, 0.);
        for (size_t i = 1; i < driftdist[n].size(); ++i) {
            driftdist[n].at(i) = ff(dpavg[i]);
        }
    }

    // Use maximum drift distance for Lmax if not specified.
    if (!Lmax.has_value()) {
        Lmax = std::max({*std::max_element(driftdist[0].begin(), driftdist[0].end()),
                         *std::max_element(driftdist[1].begin(), driftdist[1].end()),
                         *std::max_element(driftdist[2].begin(), driftdist[2].end())});
    }
    
    // Nsa = number of segments in sprayed area along field depth.
    // Nda = number of segments in drift field.
    size_t Nsa = static_cast<size_t>(FD / dN);
    size_t Nda = static_cast<size_t>(Nsa * lambda);

    // dwsa = width of spray segments, meters.
    // dwda = width of drift segments, meters.
    const double dwsa = FD / Nsa;
    const double dwda = Lmax.value() / Nda;

    // 1 ha = 10000 m²
    // 1 g/cm³ = 1000 kg/m³
    const double sprayedArea = 0.0001 * FD * PL; // ha
    const double volumeSprayed = IAR * sprayedArea / (rhoL * xactive); // L
    const double volumeAppRate = volumeSprayed / sprayedArea; // L/ha

    // Calculate partial volume for each droplet size.
    blaze::DynamicVector<double> SVP(dpavg.size(), 0);
    if (dsdmodel != nullptr) {
        // Use non-linear least squares curve fit.
        for (size_t i = 1; i < SVP.size(); ++i) {
            double y = dsdmodel->pdf(dpavg[i]);
            SVP[i] = y * ddp * volumeSprayed / Nsa;
        }
    }
    else {
        // Approximation using finite differences. Use extrapolation, and clamp estimates to [0, 1].
        // May throw std::domain_error.
        const auto dsdfunc = Interpolate1D<true>(dsd, 0, 1);
        for (size_t i = 1; i < SVP.size(); ++i) {
            double y = finite_difference_derivative<decltype(dsdfunc), double, 1>(dsdfunc, dpavg[i]);
            SVP[i] = y * ddp * volumeSprayed / Nsa;
        }
    }
    
    // Width of each segment.
    blaze::DynamicVector<double> dwx = blaze::generate(Nsa+Nda, [=](size_t i)
        { return i < Nsa ? dwsa : dwda; });
    
    // Distance from the back of the field (i.e., upwind) to the midpoint of each segment.
    blaze::DynamicVector<double> x = blaze::generate(Nsa+Nda, [=](size_t i)
        { return i < Nsa ? dwsa*(0.5+i) : dwda*(0.5+i-Nsa)+FD; });

    // Iterators to spray segment distances.
    const auto itsa0 = x.begin();
    const auto itsa1 = std::next(x.begin(), Nsa);

    // Iterators to drift segment distances.
    const auto itda0 = std::next(x.begin(), Nsa);
    const auto itda1 = std::next(x.begin(), Nsa+Nda);

    // Create DVM and CM matrices.
    // Upper and lower bound reversed for driftdist vectors in descending order. 
    blaze::DynamicMatrix<double> DVM(mm, Nsa+Nda, 0);
    blaze::DynamicMatrix<double> CM(mm, Nsa+Nda, 0);
    for (size_t n = 0; n < driftdist.size(); ++n) {
        for (size_t i = 1; i < mm; ++i) {
            // driftdist[i] >= (x[1:nsa]-dwsa) && driftdist[i] < x[1:nsa]
            const auto saupper = std::distance(itsa0, std::lower_bound(itsa0, itsa1, driftdist[n].at(i) + dwsa));
            const auto salower = std::distance(itsa0, std::upper_bound(itsa0, itsa1, driftdist[n].at(i)));
            for (ptrdiff_t j = salower; j < saupper; ++j) {
                auto DVMsa = blaze::submatrix(DVM, i, j, 1UL, Nsa-j); // DVM[i,j:Nsa]
                auto CMsa = blaze::submatrix(CM, i, j, 1UL, Nsa-j); // CM[i,j:Nsa]
                DVMsa += SVP[i]/3;
                CMsa += (SVP[i]/3) / (dwsa*(PL+2*(x[j]-0.5*dwsa)*tan(ppp*pi*zeta/180.)));
            }

            for (size_t j = Nsa; j < Nsa+Nda; ++j) {
                // driftdist[i] >= (x[1:Nsa]+(j-Nsa)*dwda) && driftdist[i] < (x[1:Nsa]+(j+1-Nsa)*dwda)
                const auto daupper = std::distance(itsa0, std::lower_bound(itsa0, itsa1, driftdist[n].at(i) - (j-Nsa)*dwda));
                const auto dalower = std::distance(itsa0, std::upper_bound(itsa0, itsa1, driftdist[n].at(i) - (j+1-Nsa)*dwda));
                if (dalower == 0 && daupper == 0) {
                    // Distances will continue to decrease above the current droplet size; exit loop.
                    break;
                }
                for (ptrdiff_t k = dalower; k < daupper; ++k) {
                    DVM(i,j) += SVP[i]/3;
                    CM(i,j) += (SVP[i]/3) / (dwda*(PL+2*(x[j]-x[Nsa-k])*tan(ppp*pi*zeta/180.)));
                }
            }
        }
    }

    blaze::DynamicVector<double, blaze::rowVector> VPS = blaze::sum<blaze::columnwise>(DVM);
    blaze::DynamicVector<double, blaze::rowVector> CS = blaze::sum<blaze::columnwise>(CM);
    auto NPDR = VPS / (blaze::trans(dwx) * PL);
    auto propAppliedPlume = CS / (volumeAppRate / 10000.);
    auto propAppliedNoPlume = NPDR / (volumeAppRate / 10000.);

    fmt::print("Spray Segment Count (Nsa)  = {}\n", Nsa);
    fmt::print("Drift Segment Count (Nda)  = {}\n", Nda);
    fmt::print("Spray Segment Width (ΔWsa) = {}\n", dwsa);
    fmt::print("Drift Segment Width (ΔWda) = {}\n", dwda);
    fmt::print("Max. Drift Distance (Lmax) = {}\n", *Lmax);
    fmt::print("Sprayed Area               = {}\n", sprayedArea);
    fmt::print("Volume Sprayed             = {}\n", volumeSprayed);
    fmt::print("Σ(SVP) × Nsa               = {}\n", blaze::sum(SVP) * Nsa);
    fmt::print("Σ(VPS[0…Nsa+Nda])          = {}\n", blaze::sum(VPS));
    fmt::print("Σ(VPS[0…Nsa])              = {}\n", blaze::sum(blaze::subvector(VPS, 0UL, Nsa)));
    fmt::print("Σ(CS)                      = {}\n", blaze::sum(CS));

    std::vector<std::pair<double, double>> propAppliedPlumeXY;
    propAppliedPlumeXY.reserve(Nsa+Nda);
    for (size_t i = 0; i < Nsa+Nda; ++i) {
        propAppliedPlumeXY.emplace_back(std::make_pair(x.at(i) - FD, propAppliedPlume.at(i)));
    }

    // May throw std::domain_error.
    const auto apfunc = Interpolate1D(propAppliedPlumeXY);
    std::vector<std::pair<double, double>> applume(100);
    for (size_t i = 0; i < applume.size(); ++i) {
        double x = static_cast<double>(i) * Lmax.value() / applume.size();
        double y = apfunc(x) * 100.;
        applume.at(i) = std::make_pair(x, y);
    }

    fmt::print("\n{:<8} {:>9}\n", "Distance", "APPlume");
    for (size_t i = 0; i < applume.size(); ++i) {
        fmt::print("{:<8.3f} {:>8.4f}%\n", applume.at(i).first, applume.at(i).second);
    }
}

} // namespace cdm