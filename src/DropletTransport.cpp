// Copyright (c) 2021 John Buonagurio <jbuonagurio@exponent.com>
// Copyright (c) 2021 Ed Casanova <eduardo.casanova@bayer.com>

#include <array>
#include <chrono>
#include <cmath>
#include <memory>
#include <utility>
#include <vector>

#include <fmt/core.h>

#include <boost/math/constants/constants.hpp>
#include <boost/math/tools/roots.hpp>

#include "CVodeIntegrator.hpp"
#include "DropletTransport.hpp"
#include "Constants.hpp"

namespace cdm {
namespace ode {

double dTwb;
double z0;
double Uf;
double rhoW;
double rhoS;
double hN;
double hC;
double vz;
double ma0;
double rhoa0;
double Ms;
double ttt;

// Drag coefficient, unitless
auto CD = [](double Re)
    { return 24. / Re * (1. + 0.197 * pow(Re, 0.63) + 0.00026 * pow(Re, 1.38)); };

// Water evaporation function, g/sec
auto W = [](double Mw, double Re) {
    using boost::math::double_constants::pi;
    const double lw = 76.4e-8; // Unknown Constant
    return (3. * pow(pi, 2./3.) / 2. / pow(6., 2./3.)) * (lw * dTwb) * rhoW * pow(Ms/rhoS + Mw/rhoW, 1./3.) * (1. + 0.276 * sqrt(Re)) * Mw / (Ms + Mw);
};

static int RhsFn(double t, N_Vector nvx, N_Vector nvdxdt, void *userdata)
{
    using boost::math::double_constants::pi;

    double *x = N_VGetArrayPointer(nvx);
    double *dxdt = N_VGetArrayPointer(nvdxdt);

    const double Z = x[0];
    const double X = x[1];
    const double Vz = x[2];
    const double Vx = x[3];
    const double Mw = x[4];
    const double Vvwx = x[5];

    if (Z <= z0 + hC) {
        std::fill_n(dxdt, 6, 0.);
    }
    else {
        const double gc = 980.665;                               // Standard Gravity
        const double VD = Mw/rhoW + Ms/rhoS;                     // Droplet volume
        const double DD = cbrt(6./pi * VD);                      // Droplet diameter
        const double Re = rhoa0 * DD * hypot(Vz,Vvwx-Vx) / ma0;  // Reynolds number

        /* dZ    */ dxdt[0] = Vz;
        /* dX    */ dxdt[1] = Vx;
        /* dVz   */ dxdt[2] = ( pi * CD((rhoa0 * DD * abs(Vz)) / ma0) * rhoa0 * pow(DD,2.) * (-Vz) * abs(-Vz) / 8.
                                + Vz * W(Mw,Re) + VD * gc * (rhoa0-(Mw+Ms)/VD) ) / (Mw+Ms);
        /* dVx   */ dxdt[3] = ( pi * CD((rhoa0 * DD * abs(Vx-Vvwx)) / ma0) * rhoa0 * pow(DD,2.) * (-Vx+Vvwx) * abs(-Vx+Vvwx) / 8.
                                + Vx * W(Mw,Re) ) / (Mw+Ms) * (Vvwx <= 0. ? 0. : 1.);
        /* dMw   */ dxdt[4] = -W(Mw,Re);
        /* dVvwx */ dxdt[5] = Z <= z0 ? 0. : Vz * (Uf/0.4) / (Z-hC);
    }

    return 0;
}

} // namespace ode 



static double EstimateVt(double dp, double rhoL0, double rhoa0, double ma0)
{
    using boost::math::tools::eps_tolerance;
    using boost::math::tools::bracket_and_solve_root;
    using namespace boost::math::policies;
    using c_policy = policy<
        domain_error<errno_on_error>,
        pole_error<errno_on_error>,
        overflow_error<errno_on_error>,
        evaluation_error<errno_on_error>>;

    auto EqnVt = [=](double Vt) {
        const double Re = (rhoa0 * Vt * dp) / ma0;
        const double CD = 24. / Re * (1. + 0.197 * pow(Re, 0.63) + 0.00026 * pow(Re, 1.38));
        return Vt - sqrt(4. * dp * 980.1 * (rhoL0 - rhoa0) / (3. * rhoa0 * CD));
    };

    // Termination condition functor for specified number of bits.
    // Maximum value is std::numeric_limits<double>::digits - 1.
    eps_tolerance<double> tol(std::numeric_limits<double>::digits - 6);
    uintmax_t max_iter = 200; // Iteration limit.
    
    // If unable to bracket the root, return the current lower bound.
    errno = 0;
    std::pair<double, double> r = bracket_and_solve_root(EqnVt, 0.015, 2., true, tol, max_iter, c_policy{});
    if (errno) {
        errno = 0;
        return r.first;
    }
    else {
        return r.first + (r.second - r.first) / 2.;
    }
}

double DropletTransport(double Tair, double RH, double dTwb, double z0, double Uf, double rhoW, double rhoS, double xs0, double hN, double hC, double vz, double vx, double dp, double ddd)
{
    using boost::math::double_constants::pi;

    z0 = z0 * 100.; // m to cm
    Uf = Uf * 100.; // m/s to cm/s
    hN = hN * 100.; // m to cm
    hC = hC * 100.; // m to cm
    vz = vz * 100.; // m/s to cm/s
    vx = vx * 100.; // m/s to cm/s

    // Adjust nozzle height for distance to liquid sheet.
    hN = hN - constants::liquid_sheet_offset * 100.;

    // Density of sprayed solution, g/cm³
    auto rhoL = [](double xs, double rhoS, double rhoW)
        { return 1. / ((xs / rhoS) + ((1. - xs) / rhoW)); };

    // Mass of sprayed solution in droplet, g
    auto Ms = [](double dp, double xs, double rhoS, double rhoW)
        { return pi / 6. * pow(dp, 3.) * xs / ((xs / rhoS) + ((1. - xs) / rhoW)); };

    // Mass of water in droplet, g
    auto Mw = [](double dp, double xs, double rhoS, double rhoW) 
        { return pi / 6. * pow(dp, 3.) * (1. - xs) / ((xs / rhoS) + ((1. - xs) / rhoW)); };

    // Ambient dewpoint temperature, °C
    auto Tdp = [](double Tair, double RH)
        { return 4169.627 / (4169.627 / (Tair + 239.582) - log(RH/100.)) - 239.582; };

    // Antoine vapor pressure for water, atm
    auto Psw = [](double T)
        { return exp(18.92676 + log(1. / 760.) - 4169.627 / (T + 239.582)); };

    // Dynamic viscosity of wet air at film, g/cm-sec
    // μa0 = mwa(Tair, Ywinf)
    auto mwa = [](double Tair, double ywinf) {
        const double K0 = 1.765e-4;
        const double K1 = 4.752e-7;
        const double K2 = -1.478e-4;
        return K0 + K1 * Tair + K2 * ywinf;
    };

    // Density of wet air, g/cm³
    // ρa0 = ρwa(Tair, Ywinf)
    auto rhoWa = [](double Tair, double ywinf) {
        using constants::mol_wt_air;
        using constants::mol_wt_water;
        return (mol_wt_water * ywinf + mol_wt_air * (1. - ywinf)) / (82.061 * (Tair + 273.15));
    };

    // Horizontal wind velocity profile function, cm/sec
    auto vwx = [](double hN, double z0, double Uf, double hC)
        { return hN > z0 ? Uf / 0.4 * log((hN - hC) / z0) : 0.; };

    double rhoL0 = rhoL(xs0, rhoS, rhoW);
    double ma0 = mwa(Tair, Psw(Tdp(Tair, RH)));
    double rhoa0 = rhoWa(Tair, Psw(Tdp(Tair, RH)));
    double vwx0 = vwx(hN, z0, Uf, hC);
    double dpi = dp / 10000.; // μm to cm
    double Msi = Ms(dpi, xs0, rhoS, rhoW);
    double Mwi = Mw(dpi, xs0, rhoS, rhoW);

    // Terminal velocity of particle, cm/sec
    double Vt = EstimateVt(dpi, rhoL0, rhoa0, ma0);

    // Initialize parameters used in ODE.
    ode::dTwb = dTwb;
    ode::z0 = z0;
    ode::Uf = Uf;
    ode::rhoW = rhoW;
    ode::rhoS = rhoS;
    ode::hN = hN;
    ode::hC = hC;
    ode::vz = vz;
    ode::ma0 = ma0;
    ode::rhoa0 = rhoa0;
    ode::Ms = Msi;

    // Initialize the solver with initial conditions:
    // Z, X, Vz, Vx, Mw, Vvwx
    cvode::Integrator<6> cvi;
    cvi.init(ode::RhsFn, 0, {hN, 0, vz, vx, Mwi, vwx0});
    cvi.setTolerances(1e-6, {1e-8, 1e-8, 1e-8, 1e-8, 1e-10, 1e-8});
    cvi.setMaxOrd(5);           // Default 5 (BDF)
    cvi.setStabLimDet(false);   // Default false
    cvi.setMaxNumSteps(2000);   // Default 500
    cvi.setMaxErrTestFails(10); // Default 7
    cvi.setMaxNonlinIters(3);   // Default 3
    cvi.setMaxConvFails(10);    // Default 10

    // Solve ODE. May throw cvode::system_error.
    double t = 0;
    double tmax = ddd * hN/Vt; // Time for deposition, sec
    size_t nout = 10000; // Number of output steps
    double step = tmax / nout;
    double tout = step;
    
    for (size_t istep = 0; istep < nout; ++istep) {
        cvi.step(tout);
        tout += step;
    }
    
    //int nsteps = cvi.getNumSteps();
    //int nfevals = cvi.getNumRhsEvals();
    //int nlinsetups = cvi.getNumLinSolvSetups();
    //int netfails = cvi.getNumErrTestFails();
    //int nniters = cvi.getNumNonlinSolvIters();
    //int nncfails = cvi.getNumNonlinSolvConvFails();
    //int njevals = cvi.getNumJacEvals();
    //int nfevalsLS = cvi.getNumLinRhsEvals();

    auto y = cvi.solution();
    double xdist = y[1] / 100.; // cm to m
    return xdist;
}

} // namespace cdm