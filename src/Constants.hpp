// Copyright (c) 2021 John Buonagurio <jbuonagurio@exponent.com>
// Copyright (c) 2021 Ed Casanova <eduardo.casanova@bayer.com>

#pragma once

#include <cstddef>

namespace cdm {
namespace constants {

// von Kármán constant (κ)
constexpr double karman = 0.40;

// Molecular weight of water [g/mol]
constexpr double mol_wt_water = 1.00794 * 2. + 15.9994;

// Molecular weight of air [g/mol]
constexpr double mol_wt_air = 0.209 * 2. * 15.9994 + (1. - 0.209) * 2. * 14.007;

// Distance between nozzle and liquid sheet [m]
constexpr double liquid_sheet_offset = 0.1016;

// Default horizontal variation in wind direction around mean (ψψψ) [degrees]
constexpr double default_psipsipsi = 15.0;

// Number of flow segment streamlines for droplet transport calculations (Ns)
constexpr size_t ns = 11;

} // namespace constants
} // namespace cdm