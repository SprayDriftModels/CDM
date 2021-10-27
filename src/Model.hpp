// Copyright (c) 2021 John Buonagurio <jbuonagurio@exponent.com>
// Copyright (c) 2021 Ed Casanova <eduardo.casanova@bayer.com>

#pragma once

#include <array>
#include <memory>
#include <optional>
#include <utility>
#include <vector>

namespace cdm {

struct DropletSizeModel;
struct NozzleVelocity;

struct Model
{
    struct Input
    {
        // Droplet Size Distribution
        std::vector<std::pair<double, double>> dsd;     // [INPUT] μm, cumulative volume fraction
        double dpmin;                                   // [INPUT] Minimum droplet size for deposition [μm]
        double dpmax;                                   // [INPUT] Maximum droplet size for deposition [μm]
        bool dsdfit;                                    // [INPUT] Enable curve fitting for DSD

        // Ambient Conditions
        double Tair;                                    // [INPUT] Dry air temperature, [°C]
        double Patm;                                    // [INPUT] Barometric pressure [Pa]
        double RH;                                      // [INPUT] Relative humidity [percent]

        // Wind Velocity Profile
        enum class PPPMethod {
            ENTERED = 0,
            INTERPOLATE = 1,
            SDTF = 2
        };
        double hC;                                      // [INPUT] Canopy height [m]
        std::vector<std::pair<double, double>> wvu;     // [INPUT] Elevation [m], Velocity [m/s]
        std::vector<std::pair<double, double>> wvT;     // [INPUT] Elevation [m], Temperature [°C]
        std::optional<double> ppp;                      // [INPUT/DERIVED] Horizontal variation in wind direction around mean (ψψψ) [degrees]
        PPPMethod pppMethod = PPPMethod::ENTERED;       // [INPUT] Calculation method for ψψψ

        // Solution Properties
        double rhoW;                                    // [INPUT] Density of pure water in droplet [g/cm³]
        double rhoS;                                    // [INPUT] Density of dissolved solids in droplet [g/cm³]
        double xs0;                                     // [INPUT] Mass fraction total dissolved solids in droplet, unitless

        // Droplet Transport
        double hN;                                      // [INPUT] Height of nozzle above ground [m]
        double PN;                                      // [INPUT] Nozzle pressure [Pa]
        double thetaN;                                  // [INPUT] Nozzle angle [degrees]
        double ddd = 60;                                // [INPUT] Scale factor for maximum deposition time (δδδ)

        // Deposition
        double iar;                                     // [INPUT] Intended application rate [kg/ha]
        double xactive;                                 // [INPUT] Concentration in tank solution [wt. fraction]
        double FD;                                      // [INPUT] Downwind field depth [m]
        double PL;                                      // [INPUT] Crosswind field width [m]
        double dN;                                      // [INPUT] Space between nozzles on boom [m]
        std::optional<double> Lmax;                     // [INPUT/DERIVED] Maximum drift distance for deposition [m]
        double lambda = 1;                              // [INPUT] scale factor for number of drift segments (λ), ≥1
    };

    struct Output
    {
        // Droplet Size Distribution
        std::vector<double> dp;                         // [DERIVED] Calculated droplet sizes [μm]
        std::unique_ptr<DropletSizeModel> dsdmodel;     // [DERIVED] Non-linear least squares model
        
        // Ambient Conditions
        double Twb;                                     // [DERIVED] Wet bulb temperature [°C]
        double dTwb;                                    // [DERIVED] Wet bulb temperature depression [°C]

        // Wind Velocity Profile
        double ppp;                                     // [DERIVED] Horizontal variation in wind direction around mean (ψψψ) [degrees]
        double z0;                                      // [DERIVED] Friction height [m]
        double Uf;                                      // [DERIVED] Friction velocity [m/s]

        // Solution Properties
        double rhoL;                                    // [DERIVED] Mixture density [g/cm³]

        // Droplet Transport
        std::unique_ptr<NozzleVelocity> nv;             // [DERIVED] Nozzle velocity
        std::array<std::vector<double>, 3> xdist;       // [DERIVED] Transport distance [m]

        // Deposition
        double Lmax;                                    // [DERIVED] Maximum drift distance for deposition [m]
        std::vector<std::pair<double, double>> applume; // [DERIVED] Deposition output
    };

    Input in;
    Output out;
};


} // namespace cdm