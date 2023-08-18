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

    // Named elements of output vector.
    double& dZ = dxdt[0];
    double& dX = dxdt[1];
    double& dVz = dxdt[2];
    double& dVx = dxdt[3];
    double& dMw = dxdt[4];
    double& dVvwx = dxdt[5];

    // Additional parameters from caller.
    const double& z0 = p->z0;
    const double& Uf = p->Uf;
    const double& hC = p->hC;
    const double& dTwb = p->dTwb;
    const double& rhoW = p->rhoW;
    const double& rhoS = p->rhoS;
    const double& rhoA = p->rhoA;
    const double& muA = p->muA;
    const double& Ms = p->Ms0;

    // Drag coefficient function, unitless
    auto CD = [](double Re)
        { return 24. / Re * (1. + 0.197 * pow(Re, 0.63) + 0.00026 * pow(Re, 1.38)); };

    // Water evaporation function, g/s
    auto W = [dTwb, Ms, rhoW, rhoS](double Mw, double Re) {
        const double lw = 76.4e-8; // Evaporation rate (λw), cm²/(s·°C)
        return (3. * pow(pi, 2./3.) / 2. / pow(6., 2./3.)) *
               (lw * dTwb) * rhoW * pow(Ms/rhoS + Mw/rhoW, 1./3.) *
               (1. + 0.276 * sqrt(Re)) * Mw / (Ms + Mw);
    };

    if (Z <= z0 + hC) {
        std::fill_n(dxdt, 6, 0.);
    }
    else {
        const double gc = 980.665; // Standard gravity, cm/s²
        const double VD = Mw/rhoW + Ms/rhoS; // Droplet volume, cm³
        const double DD = cbrt(6./pi * VD); // Droplet diameter, cm
        const double Re = rhoA * DD * hypot(Vz,Vvwx-Vx) / muA; // Reynolds number

        dZ = Vz;
        dX = Vx;
        dVz = ( pi * CD((rhoA * DD * abs(Vz)) / muA) * rhoA * pow(DD,2.) * (-Vz) * abs(-Vz) / 8.
              + Vz * W(Mw,Re) + VD * gc * (rhoA-(Mw+Ms)/VD) ) / (Mw+Ms);
        dVx = ( pi * CD((rhoA * DD * abs(Vx-Vvwx)) / muA) * rhoA * pow(DD,2.) * (-Vx+Vvwx) * abs(-Vx+Vvwx) / 8.
              + Vx * W(Mw,Re) ) / (Mw+Ms) * (Vvwx <= 0. ? 0. : 1.);
        dMw = -W(Mw,Re);
        dVvwx = Z <= z0 ? 0. : Vz * (Uf/constants::karman) / (Z-hC);
    }

    return 0;
}

static double EstimateVt(double dp, double rhoL, double rhoA, double muA)
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
        const double Re = (rhoA * Vt * dp) / muA;
        const double CD = 24. / Re * (1. + 0.197 * pow(Re, 0.63) + 0.00026 * pow(Re, 1.38));
        return Vt - sqrt(4. * dp * 980.1 * (rhoL - rhoA) / (3. * rhoA * CD));
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
    params.rhoL = m.out.rhoL;
    params.rhoA = m.out.rhoA;
    params.muA = m.out.muA;
    params.xs0 = m.in.xs0;
    params.ddd = m.in.ddd;
    params.Ms0 = 0;
    params.Mw0 = 0;

    // Adjust nozzle height for distance to liquid sheet.
    params.hN = params.hN - constants::liquid_sheet_offset * 100.;
    
    // Horizontal wind velocity profile function, cm/s
    params.Vvwx0 = [](double hN, double z0, double Uf, double hC)
        { return hN <= z0 ? 0. : (Uf/constants::karman) * log((hN-hC)/z0); }
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

double DropletTransport::operator()(double Vz0, double Vx0, double dp)
{
    using boost::math::double_constants::sixth_pi;

    Vz0 = Vz0 * 100.; // m/s to cm/s
    Vx0 = Vx0 * 100.; // m/s to cm/s
    dp = dp / 10000.; // μm to cm

    // Calculate mass of water and solution phases in droplet.
    const double& xs0 = params.xs0;
    const double& rhoS = params.rhoS;
    const double& rhoW = params.rhoW;
    params.Ms0 = (sixth_pi) * pow(dp,3.) * xs0      / (xs0/rhoS + (1.-xs0)/rhoW);
    params.Mw0 = (sixth_pi) * pow(dp,3.) * (1.-xs0) / (xs0/rhoS + (1.-xs0)/rhoW);

    // Calculate terminal velocity of particle, cm/s
    double Vt = EstimateVt(dp, params.rhoL, params.rhoA, params.muA);

    // Reinitialize CVODE with state vector:
    // Z, X, Vz, Vx, Mw, Vvwx
    cvi.reinit(0, {params.hN, 0, Vz0, Vx0, params.Mw0, params.Vvwx0});

    double t = 0;
    double tmax = params.ddd * params.hN / Vt; // Time for deposition, s
    double step = tmax / constants::nout;
    double tout = step;
    
    // Solve ODE. May throw cvode::system_error.
    for (size_t i = 0; i < constants::nout; ++i) {
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