// Copyright (c) 2021 John Buonagurio <jbuonagurio@exponent.com>
// Copyright (c) 2021 Ed Casanova <eduardo.casanova@bayer.com>

#pragma once

#include <cstddef>

namespace cdm {
namespace constants {

// Antoine vapor pressure constants; regressed for high accuracy between -10 and 50°C.
static constexpr double Aw = 18.92676;
static constexpr double Bw = -4169.627;
static constexpr double Cw = -33.568;

// von Kármán constant (κ)
static constexpr double karman = 0.40;

// Molecular weight of water [g/mol]
static constexpr double mww = 1.00794 * 2. + 15.9994;

// Molecular weight of air [g/mol]
static constexpr double mwa = 0.209 * 2. * 15.9994 + (1. - 0.209) * 2. * 14.007;

// Distance between nozzle and liquid sheet [m]
static constexpr double liquid_sheet_offset = 0.1016;

// Default horizontal variation in wind direction around mean (ψψψ) [degrees]
static constexpr double default_psipsipsi = 15.0;

// Multiplier for one sigma variation in wind direction (ζ) [degrees]
static constexpr double zeta = 2.5;

// Number of flow segment streamlines for droplet transport calculations.
static constexpr size_t ns = 11;

// Number of output steps for droplet transport calculations.
static constexpr size_t nout = 10000;

} // namespace constants
} // namespace cdm