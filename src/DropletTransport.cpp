// Copyright (c) 2023 John Buonagurio <jbuonagurio@exponent.com>
// Copyright (c) 2021 Ed Casanova <eduardo.casanova@bayer.com>

#include <array>
#include <chrono>
#include <cmath>
#include <memory>
#include <utility>
#include <vector>

#include <boost/math/constants/constants.hpp>
#include <boost/math/tools/roots.hpp>

#include "CVodeIntegrator.hpp"
#include "DropletTransport.hpp"
#include "Constants.hpp"

namespace cdm {

static int RhsFn(double t, N_Vector nvx, N_Vector nvdxdt, void *userdata)
{
    using boost::math::double_constants::pi;

    double *x = N_VGetArrayPointer(nvx);
    double *dxdt = N_VGetArrayPointer(nvdxdt);
    DropletTransport::Params *p = static_cast<DropletTransport::Params *>(userdata);

    // Named elements of state vector. 
    const double& Z = x[0];
    const double& X = x[1];
    const double& Vz = x[2];
    const double& Vx = x[3];
    const double& Mw = x[4];
    const double& Vvwx = x[5];

    // Additional parameters from caller.
    const double& z0 = p->z0;
    const double& Uf = p->Uf;
    const double& hC = p->hC;
    const double& dTwb = p->dTwb;
    const double& rhoW = p->rhoW;
    const double& rhoS = p->rhoS;
    const double& rhoA0 = p->rhoA0;
    const double& muA0 = p->muA0;
    const double& Ms = p->Ms0;

    // Drag coefficient function, unitless
    auto CD = [](double Re)
        { return 24. / Re * (1. + 0.197 * pow(Re, 0.63) + 0.00026 * pow(Re, 1.38)); };

    // Water evaporation function, g/sec
    auto W = [dTwb, Ms, rhoW, rhoS](double Mw, double Re) {
        const double lw = 76.4e-8; // Evaporation rate (λw), cm²/(s·°C)
        return (3. * pow(pi, 2./3.) / 2. / pow(6., 2./3.)) * (lw * dTwb) * rhoW * pow(Ms/rhoS + Mw/rhoW, 1./3.) * (1. + 0.276 * sqrt(Re)) * Mw / (Ms + Mw);
    };

    if (Z <= z0 + hC) {
        std::fill_n(dxdt, 6, 0.);
    }
    else {
        const double gc = 980.665;                                // Standard gravity
        const double VD = Mw/rhoW + Ms/rhoS;                      // Droplet volume
        const double DD = cbrt(6./pi * VD);                       // Droplet diameter
        const double Re = rhoA0 * DD * hypot(Vz,Vvwx-Vx) / muA0;  // Reynolds number
        
        /* dZ    */ dxdt[0] = Vz;
        /* dX    */ dxdt[1] = Vx;
        /* dVz   */ dxdt[2] = ( pi * CD((rhoA0 * DD * abs(Vz)) / muA0) * rhoA0 * pow(DD,2.) * (-Vz) * abs(-Vz) / 8.
                                + Vz * W(Mw,Re) + VD * gc * (rhoA0-(Mw+Ms)/VD) ) / (Mw+Ms);
        /* dVx   */ dxdt[3] = ( pi * CD((rhoA0 * DD * abs(Vx-Vvwx)) / muA0) * rhoA0 * pow(DD,2.) * (-Vx+Vvwx) * abs(-Vx+Vvwx) / 8.
                                + Vx * W(Mw,Re) ) / (Mw+Ms) * (Vvwx <= 0. ? 0. : 1.);
        /* dMw   */ dxdt[4] = -W(Mw,Re);
        /* dVvwx */ dxdt[5] = Z <= z0 ? 0. : Vz * (Uf/0.4) / (Z-hC);
    }

    return 0;
}

static double EstimateVt(double dp, double rhoL0, double rhoA0, double muA0)
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
        const double Re = (rhoA0 * Vt * dp) / muA0;
        const double CD = 24. / Re * (1. + 0.197 * pow(Re, 0.63) + 0.00026 * pow(Re, 1.38));
        return Vt - sqrt(4. * dp * 980.1 * (rhoL0 - rhoA0) / (3. * rhoA0 * CD));
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

DropletTransport::DropletTransport(const cdm::Model &m)
{
    params.z0 = m.out.z0 * 100.; // m to cm
    params.Uf = m.out.Uf * 100.; // m/s to cm/s
    params.hN = m.in.hN * 100.;  // m to cm
    params.hC = m.in.hC * 100.;  // m to cm
    params.dTwb = m.out.dTwb;
    params.rhoW = m.in.rhoW;
    params.rhoS = m.in.rhoS;
    params.xs0 = m.in.xs0;
    params.ddd = m.in.ddd;
    params.Ms0 = 0;
    params.Mw0 = 0;

    // Adjust nozzle height for distance to liquid sheet.
    params.hN = params.hN - constants::liquid_sheet_offset * 100.;
    
    // Density of sprayed solution (ρL0), g/cm³
    params.rhoL0 = [](double xs, double rhoS, double rhoW)
        { return 1. / (xs/rhoS + (1.-xs)/rhoW); }
        (params.xs0, params.rhoS, params.rhoW);

    // Antoine vapor pressure for water, atm
    // 101325 Pa = 760 torr (mmHg) = 1 atm
    auto Psw = [](double T, double RH) {
        const double Aw = 18.92676;
        const double Bw = -4169.627;
        const double Cw = -33.568;
        return exp(Aw + log(RH/100.) + Bw / (T + 273.15 + Cw)) / 760.; };

    // Density of wet air (ρA0), g/cm³
    params.rhoA0 = [Psw](double Tair, double RH) {
        using constants::mwa;
        using constants::mww;
        return (mww * Psw(Tair,RH) + mwa * (1.-Psw(Tair,RH))) / (82.061 * (Tair + 273.15)); }
        (m.in.Tair, m.in.RH);

    // Dynamic viscosity of wet air at film (μA0), g/cm-sec
    params.muA0 = [Psw](double Tair, double RH) {
        const double K0 = 1.765e-4;
        const double K1 = 4.752e-7;
        const double K2 = -1.478e-4;
        return K0 + K1*Tair + K2*Psw(Tair,RH); }
        (m.in.Tair, m.in.RH);

    // Horizontal wind velocity profile function, cm/sec
    params.vwx0 = [](double hN, double z0, double Uf, double hC)
        { return hN > z0 ? (Uf/0.4)*log((hN-hC)/z0) : 0.; }
        (params.hN, params.z0, params.Uf, params.hC);
    
    // Initialize CVODE with default state.
    cvi.init(RhsFn, 0, {});
    cvi.setUserData(&params);
    cvi.setTolerances(m.in.cvreltol, m.in.cvabstol);
    cvi.setMaxOrd(m.in.cvmaxord);
    cvi.setMaxNumSteps(m.in.cvmxsteps);
    cvi.setStabLimDet(m.in.cvstldet);
    cvi.setMaxErrTestFails(m.in.cvmaxnef);
    cvi.setMaxNonlinIters(m.in.cvmaxcor); 
    cvi.setMaxConvFails(m.in.cvmaxncf);
    cvi.setNonlinConvCoef(m.in.cvnlscoef);
}

double DropletTransport::operator()(double vz, double vx, double dp)
{
    vz = vz * 100.; // m/s to cm/s
    vx = vx * 100.; // m/s to cm/s
    dp = dp / 10000.; // μm to cm

    // Calculate mass of water and solution phases in droplet.
    using boost::math::double_constants::sixth_pi;
    const double& xs0 = params.xs0;
    const double& rhoS = params.rhoS;
    const double& rhoW = params.rhoW;
    params.Ms0 = (sixth_pi) * pow(dp,3.) * xs0      / (xs0/rhoS + (1.-xs0)/rhoW);
    params.Mw0 = (sixth_pi) * pow(dp,3.) * (1.-xs0) / (xs0/rhoS + (1.-xs0)/rhoW);

    // Calculate terminal velocity of particle, cm/sec
    double Vt = EstimateVt(dp, params.rhoL0, params.rhoA0, params.muA0);

    // Reinitialize CVODE with state vector:
    // Z, X, Vz, Vx, Mw, Vvwx
    cvi.reinit(0, {params.hN, 0, vz, vx, params.Mw0, params.vwx0});

    double t = 0;
    double tmax = params.ddd * params.hN / Vt; // Time for deposition, sec
    size_t nout = 10000; // Number of output steps
    double step = tmax / nout;
    double tout = step;
    
    // Solve ODE. May throw cvode::system_error.
    for (size_t istep = 0; istep < nout; ++istep) {
        cvi.step(tout);
        tout += step;
    }
    
    //cvi.printAllStats(stderr, SUN_OUTPUTFORMAT_CSV);
    //int nsteps = cvi.getNumSteps();
    //int nfevals = cvi.getNumRhsEvals();
    //int nlinsetups = cvi.getNumLinSolvSetups();
    //int netfails = cvi.getNumErrTestFails();
    //int nncfails = cvi.getNumStepSolveFails();
    //int nslred = cvi.getNumStabLimOrderReds();
    //auto eweight = cvi.getErrWeights();
    //auto ele = cvi.getEstLocalErrors();
    //int njevals = cvi.getNumJacEvals();
    //int nfevalsLS = cvi.getNumLinRhsEvals();
    //int nliters = cvi.getNumLinIters();
    //int nlcfails = cvi.getNumLinConvFails();
    //int nniters = cvi.getNumNonlinSolvIters();
    //int nnfails = cvi.getNumNonlinSolvConvFails();

    auto y = cvi.solution();
    double xdist = y[1] / 100.; // cm to m
    return xdist;
}

} // namespace cdm