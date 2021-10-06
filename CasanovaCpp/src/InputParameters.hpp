// Copyright (c) 2021 John Buonagurio <jbuonagurio@exponent.com>

#pragma once

#include <vector>
#include <utility>

#include <nlohmann/json.hpp>

namespace cdm {

struct InputParameters
{
    // Droplet Size Distribution
    std::vector<std::pair<double, double>> dsd; // μm, cumulative volume fraction
    
    // Ambient Conditions
    double Tair;      // Dry air temperature, °C
    double Patm;      // Barometric pressure, Pa
    double RH;        // Relative humidity, percent

    // Wind Velocity Profile
    double z1;        // Elevation 1, m
    double z2;        // Elevation 2, m
    double ux1;       // Velocity 1, m/s
    double ux2;       // Velocity 2, m/s

    // Droplet Transport
    double hN;        // Height of nozzle above ground, m
    double hC;        // Canopy height, m
    double PN;        // Nozzle pressure, Pa
    double thetaN;    // Nozzle angle, degrees
    double rhoW;      // Density of pure water in droplet, g/cm³
    double rhoS;      // Density of dissolved solids in droplet, g/cm³
    double xs0;       // Mass fraction total dissolved solids in droplet, unitless
    double ddd;       // Scale factor for maximum deposition time

    // Deposition
    double iar;       // Intended application rate, kg/ha
    double xactive;   // Concentration in tank solution, wt. fraction
    double fd;        // Downwind field depth, m
    double pl;        // Crosswind field width, m
    double dN;        // Space between nozzles on boom, m
    double psipsipsi; // Horizontal variation in wind direction around mean direction, 1 stdev, degrees
    double dpmin;     // Minimum droplet size for deposition, μm
    double dpmax;     // Maximum droplet size for deposition, μm
    double lambda;    // Controls resolution of deposition calculations; higher numbers increase accuracy, ≥1
    //double lmax;    // Maximum drift distance for deposition, m
};

} // namespace cdm