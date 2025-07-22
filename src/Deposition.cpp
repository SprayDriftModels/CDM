// Copyright (c) 2021 John Buonagurio <jbuonagurio@exponent.com>
// Copyright (c) 2021 Ed Casanova <eduardo.casanova@bayer.com>

#include <algorithm>
#include <array>
#include <cmath>
#include <iterator>
#include <memory>
#include <numeric>
#include <vector>

#include <boost/math/constants/constants.hpp>
#include <boost/math/differentiation/finite_difference.hpp>

#include <blaze/Math.h>

#include "Deposition.hpp"
#include "Interpolate1D.hpp"

namespace cdm {

std::vector<std::pair<double, double>> Deposition(double IAR, double xactive, double FD, double PL, double dN, double ppp, double rhoL,
                                                  const std::vector<double>& dp,
                                                  const std::array<std::vector<double>, constants::ns>& xdist,
                                                  const std::vector<std::pair<double, double>>& dsd,
                                                  const std::unique_ptr<DropletSizeModel>& dsdmodel,
                                                  double dpmin, double dpmax, std::optional<double> Lmax, double lambda, double dx,
                                                  const std::array<bool, constants::ns>& sflags)
{
    using namespace boost::math::differentiation;
    using boost::math::double_constants::degree;
    using constants::zeta;

    // Droplet sizes to evaluate.
    const double ddp = 0.5;
    size_t mm = static_cast<size_t>((dpmax - dpmin) / ddp);
    blaze::DynamicVector<double> dpavg = blaze::generate(mm, [=](size_t i)
        { return dpmin + i * ddp; });
    
    // Log transformation function for numeric vectors.
    auto vlog = [](const std::vector<double>& v) {
        std::vector<double> result = v;
        for (auto&& element : result)
            element = log(element);
        return result;
    };

    // Generate drift distance matrix from xdist. May throw std::domain_error.
    // Use log transformation for the first (Ns+1)/2 streamline vectors.
    // Otherwise, take the absolute value of the result.
    blaze::DynamicMatrix<double> driftdist(constants::ns, dpavg.size(), 0);
    for (size_t n = 0; n < constants::ns; ++n) {
        if (n < (constants::ns + 1) / 2) {
            auto ff = Interpolate1D(vlog(dp), vlog(xdist.at(n)));
            for (size_t i = 0; i < dpavg.size() - 1; ++i) {
                driftdist(n,i) = std::exp(ff(std::log(dpavg.at(i))));
            }
        }
        else {
            auto ff = Interpolate1D(dp, xdist.at(n));
            for (size_t i = 0; i < dpavg.size() - 1; ++i) {
                driftdist(n,i) = std::abs(ff(dpavg.at(i)));
            }
        }
    }
    
    // Use maximum drift distance for Lmax if not specified.
    if (!Lmax.has_value()) {
        Lmax = blaze::max(driftdist);
    }
    
    // Nsa = number of segments in sprayed area along field depth.
    // Nda = number of segments in drift field.
    size_t Nsa = static_cast<size_t>(FD / dN);
    size_t Nda = static_cast<size_t>(Nsa * lambda);

    // dwsa = width of spray segments, meters.
    // dwda = width of drift segments, meters.
    const double dwsa = FD / Nsa;
    const double dwda = dwsa; // previously Lmax / Nda

    // 1 ha = 10000 m²
    // 1 g/cm³ = 1000 kg/m³
    const double sprayedArea = 0.0001 * FD * PL; // ha
    const double volumeSprayed = IAR * sprayedArea / (rhoL * xactive); // L
    const double volumeAppRate = volumeSprayed / sprayedArea; // L/ha

    // Calculate partial volume for each droplet size.
    blaze::DynamicVector<double> SVP(dpavg.size(), 0);
    if (dsdmodel) {
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
        { return i < Nsa ? dwsa*(0.5+i) : FD+dwda*(0.5+i-Nsa); });

    // Iterators to spray and drift segment distances.
    const auto itsa = x.begin();
    const auto itda = std::next(x.begin(), Nsa);

    // Create DVM and CM matrices.
    // Upper and lower bound reversed for drift distances in descending order. 
    blaze::DynamicMatrix<double> DVM(dpavg.size(), Nsa+Nda, 0);
    blaze::DynamicMatrix<double> CM(dpavg.size(), Nsa+Nda, 0);
    for (size_t n = 0; n < constants::ns; ++n) {
        if (!sflags.at(n)) {
            continue; // Skip calculations for selected streamline if disabled.
        }
        for (size_t i = 1; i < dpavg.size(); ++i) {
            // driftdist[n,i] >= (x[1:nsa]-dwsa) && driftdist[n,i] < x[1:nsa]
            const auto saupper = std::distance(itsa, std::lower_bound(itsa, itda, driftdist(n,i) + dwsa));
            const auto salower = std::distance(itsa, std::upper_bound(itsa, itda, driftdist(n,i)));
            for (ptrdiff_t j = salower; j < saupper; ++j) {
                auto DVMsa = blaze::submatrix(DVM, i, j, 1UL, Nsa-j); // DVM[i,j:Nsa]
                auto CMsa = blaze::submatrix(CM, i, j, 1UL, Nsa-j); // CM[i,j:Nsa]
                DVMsa += SVP[i]/constants::ns;
                CMsa += (SVP[i]/constants::ns) / (dwsa*(PL+2*(x[j]-0.5*dwsa)*tan(ppp*zeta*degree)));
            }

            for (size_t j = Nsa; j < Nsa+Nda; ++j) {
                // driftdist[n,i] >= (x[1:Nsa]+(j-Nsa)*dwda) && driftdist[n,i] < (x[1:Nsa]+(j+1-Nsa)*dwda)
                const auto daupper = std::distance(itsa, std::lower_bound(itsa, itda, driftdist(n,i) - (j-Nsa)*dwda));
                const auto dalower = std::distance(itsa, std::upper_bound(itsa, itda, driftdist(n,i) - (j+1-Nsa)*dwda));
                if (dalower == 0 && daupper == 0) {
                    // Distances will continue to decrease above the current droplet size; exit loop.
                    break;
                }
                for (ptrdiff_t k = dalower; k < daupper; ++k) {
                    DVM(i,j) += SVP[i]/constants::ns;
                    CM(i,j) += (SVP[i]/constants::ns) / (dwda*(PL+2*(x[j]-x[Nsa-k])*tan(ppp*zeta*degree)));
                }
            }
        }
    }

    blaze::DynamicVector<double, blaze::rowVector> VPS = blaze::sum<blaze::columnwise>(DVM);
    blaze::DynamicVector<double, blaze::rowVector> CS = blaze::sum<blaze::columnwise>(CM);
    auto NPDR = VPS / (blaze::trans(dwx) * PL);
    auto propAppliedPlume = CS / (volumeAppRate / 10000.);
    auto propAppliedNoPlume = NPDR / (volumeAppRate / 10000.);

    //fmt::print("Spray Segment Count (Nsa)  = {}\n", Nsa);
    //fmt::print("Drift Segment Count (Nda)  = {}\n", Nda);
    //fmt::print("Spray Segment Width (ΔWsa) = {}\n", dwsa);
    //fmt::print("Drift Segment Width (ΔWda) = {}\n", dwda);
    //fmt::print("Max. Drift Distance (Lmax) = {}\n", *Lmax);
    //fmt::print("Sprayed Area               = {}\n", sprayedArea);
    //fmt::print("Volume Sprayed             = {}\n", volumeSprayed);
    //fmt::print("Σ(SVP) × Nsa               = {}\n", blaze::sum(SVP) * Nsa);
    //fmt::print("Σ(VPS[0…Nsa+Nda])          = {}\n", blaze::sum(VPS));
    //fmt::print("Σ(VPS[0…Nsa])              = {}\n", blaze::sum(blaze::subvector(VPS, 0UL, Nsa)));

    std::vector<std::pair<double, double>> propAppliedPlumeXY;
    propAppliedPlumeXY.reserve(Nsa+Nda);
    for (size_t i = 0; i < Nsa+Nda; ++i) {
        propAppliedPlumeXY.emplace_back(std::make_pair(x.at(i) - FD, propAppliedPlume.at(i)));
    }

    // Interpolate1D may throw std::domain_error.
    const auto apfunc = Interpolate1D(propAppliedPlumeXY);

    // Generate output at specified interval.
    size_t Nx = static_cast<size_t>(Lmax.value() / dx) + 1;
    std::vector<std::pair<double, double>> applume;
    applume.reserve(Nx);
    for (size_t i = 0; i < Nx; ++i) {
        double x = static_cast<double>(i) * dx;
        double y = apfunc(x) * 100.;
        applume.emplace_back(std::make_pair(x, y));
    }

    return applume;
}

} // namespace cdm