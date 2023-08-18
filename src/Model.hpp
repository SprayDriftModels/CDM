// Copyright (c) 2021 John Buonagurio <jbuonagurio@exponent.com>
// Copyright (c) 2021 Ed Casanova <eduardo.casanova@bayer.com>

#pragma once

#include <array>
#include <memory>
#include <optional>
#include <utility>
#include <vector>

#include "Constants.hpp"

namespace cdm {

struct DropletSizeModel;
struct NozzleVelocity;

struct Model
{
    std::string name;
    
    struct Input
    {
        // Droplet Size Distribution
        std::vector<std::pair<double, double>> dsd;             // [INPUT] μm, cumulative volume fraction
        double dpmin;                                           // [INPUT] Minimum droplet size for deposition [μm]
        double dpmax;                                           // [INPUT] Maximum droplet size for deposition [μm]
        bool dsdfit;                                            // [INPUT] Enable curve fitting for DSD

        // Atmospheric Properties
        double Tair;                                            // [INPUT] Dry air temperature, [°C]
        double Patm;                                            // [INPUT] Absolute arometric pressure [Pa]
        double RH;                                              // [INPUT] Relative humidity [percent]

        // Wind Velocity Profile
        enum class PPPMethod {
            ENTERED = 0,
            INTERPOLATE = 1,
            SDTF = 2
        };
        double hC;                                              // [INPUT] Canopy height [m]
        std::vector<std::pair<double, double>> wvu;             // [INPUT] Elevation [m], Velocity [m/s]
        std::vector<std::pair<double, double>> wvT;             // [INPUT] Elevation [m], Temperature [°C]
        std::optional<double> ppp;                              // [INPUT] Horizontal variation in wind direction around mean (ψψψ) [degrees]
        PPPMethod pppMethod = PPPMethod::ENTERED;               // [INPUT] Calculation method for ψψψ

        // Solution Properties
        double rhoW;                                            // [INPUT] Density of pure water in droplet [g/cm³]
        double rhoS;                                            // [INPUT] Density of dissolved solids in droplet [g/cm³]
        double xs0;                                             // [INPUT] Mass fraction total dissolved solids in droplet, unitless

        // Droplet Transport
        double hN;                                              // [INPUT] Height of nozzle above ground [m]
        double PN;                                              // [INPUT] Nozzle pressure [Pa]
        double thetaN;                                          // [INPUT] Nozzle angle [degrees]
        double ddd = 60;                                        // [INPUT] Scale factor for maximum deposition time (δδδ)

        // Deposition
        double iar;                                             // [INPUT] Intended application rate [kg/ha]
        double xactive;                                         // [INPUT] Concentration in tank solution [wt. fraction]
        double FD;                                              // [INPUT] Downwind field depth [m]
        double PL;                                              // [INPUT] Crosswind field width [m]
        double dN;                                              // [INPUT] Space between nozzles on boom [m]
        std::optional<double> Lmax;                             // [INPUT] Maximum drift distance for deposition [m]
        double lambda = 1;                                      // [INPUT] Scale factor for number of drift segments (λ), ≥1
        double dx = 0.5;                                        // [INPUT] Distance interval for deposition output [m]

        // CVODE Integration Options
        double cvreltol = 1e-6;                                 // [INPUT] Relative error tolerance
        std::array<double, 6> cvabstol =
            {1e-8, 1e-8, 1e-8, 1e-8, 1e-10, 1e-8};              // [INPUT] Absolute error tolerances for solution vector components: Z, X, Vz, Vx, Mw, Vvwx
        int cvmaxord = 5;                                       // [INPUT] Maximum order for BDF method, ≥1, default 5
        int cvmxsteps = 2000;                                   // [INPUT] Maximum number of internal steps per output step, ≥1, default 500
        bool cvstldet = false;                                  // [INPUT] Enable BDF stability limit detection algorithm, default false
        int cvmaxnef = 10;                                      // [INPUT] Maximum number of error test failures permitted per output step, ≥1, default 7
        int cvmaxcor = 3;                                       // [INPUT] Maximum number of nonlinear solver iterations per output step, ≥1, default 3
        int cvmaxncf = 20;                                      // [INPUT] Maximum number of nonlinear solver convergence failures per output step, ≥1, default 10
        double cvnlscoef = 0.1;                                 // [INPUT] Safety factor for nonlinear solver convergence test, >0, default 0.1
    };

    struct Output
    {
        // Droplet Size Distribution
        std::vector<double> dp;                                 // [DERIVED] Calculated droplet sizes [μm]
        std::unique_ptr<DropletSizeModel> dsmodel;              // [DERIVED] Non-linear least squares model
        
        // Solution Properties
        double rhoL;                                            // [DERIVED] Mixture density [g/cm³]

        // Atmospheric Properties
        double rhoA;                                            // [DERIVED] Density of wet air (ρA) [g/cm³]
        double muA;                                             // [DERIVED] Dynamic viscosity of wet air at film (μA) [g·cm⁻¹s⁻¹]
        double Tdp;                                             // [DERIVED] Dew point temperature [°C]
        double Twb;                                             // [DERIVED] Wet bulb temperature [°C]
        double dTwb;                                            // [DERIVED] Wet bulb temperature depression [°C]

        // Wind Velocity Profile
        double ppp;                                             // [DERIVED] Horizontal variation in wind direction around mean (ψψψ) [degrees]
        double z0;                                              // [DERIVED] Friction height [m]
        double Uf;                                              // [DERIVED] Friction velocity [m/s]

        // Droplet Transport
        std::array<double, constants::ns> nva;                  // [DERIVED] Streamline vector angles [degrees]
        std::array<double, constants::ns> nvz;                  // [DERIVED] Nozzle velocity, vertical components [m/s]
        std::array<double, constants::ns> nvx;                  // [DERIVED] Nozzle velocity, horizontal components [m/s]
        std::array<std::vector<double>, constants::ns> xdist;   // [DERIVED] Transport distances [m]

        // Deposition
        std::vector<std::pair<double, double>> applume;         // [DERIVED] Deposition output
    };

    Input in;
    Output out;
};


} // namespace cdm