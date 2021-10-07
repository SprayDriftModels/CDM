// Copyright (c) 2021 John Buonagurio <jbuonagurio@exponent.com>

#pragma once

#include <array>
#include <optional>
#include <vector>
#include <utility>

namespace cdm {

enum class PsiPsiPsiMethod {
    ENTERED = 0,
    INTERPOLATE = 1,
    SDTF = 2
};

struct InputParameters
{
    // Droplet Size Distribution
    std::vector<std::pair<double, double>> dsd; // μm, cumulative volume fraction
    
    // Ambient Conditions
    double Tair;      // Dry air temperature, °C
    double Patm;      // Barometric pressure, Pa
    double RH;        // Relative humidity, percent

    // Wind Velocity Profile
    std::vector<std::pair<double, double>> wvu; // Elevation [m], Velocity [m/s]
    std::vector<std::pair<double, double>> wvT; // Elevation [m], Temperature [°C]
    std::optional<double> psipsipsi; // Horizontal variation in wind direction around mean direction, 1 stdev, degrees
    PsiPsiPsiMethod psipsipsiMethod = PsiPsiPsiMethod::ENTERED;

    // Droplet Transport
    double hN;        // Height of nozzle above ground, m
    double hC;        // Canopy height, m
    double PN;        // Nozzle pressure, Pa
    double thetaN;    // Nozzle angle, degrees
    double rhoW;      // Density of pure water in droplet, g/cm³
    double rhoS;      // Density of dissolved solids in droplet, g/cm³
    double xs0;       // Mass fraction total dissolved solids in droplet, unitless
    double ddd = 60;  // Scale factor for maximum deposition time

    // Deposition
    bool dsdfit;                 // Enable curve fitting for DSD.
    double iar;                  // Intended application rate, kg/ha
    double xactive;              // Concentration in tank solution, wt. fraction
    double fd;                   // Downwind field depth, m
    double pl;                   // Crosswind field width, m
    double dN;                   // Space between nozzles on boom, m
    double dpmin;                // Minimum droplet size for deposition, μm
    double dpmax;                // Maximum droplet size for deposition, μm
    std::optional<double> lmax;  // Maximum drift distance for deposition, m
    double lambda = 1;           // Scale factor for number of drift segments; higher numbers increase accuracy, ≥1
};

} // namespace cdm