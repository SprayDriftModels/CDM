---
title: Functional Specification
---

# Functional Specification

**Document Version:** 1.0 | **Date:** October 30, 2025

> This page provides an overview. View the [full Functional Specification on GitHub](https://github.com/SprayDriftModels/CDM/blob/main/docs/FunctionalSpecification.md).

## Purpose

The Functional Specification describes how the CDM system implements the user requirements defined in the URS. It provides detailed specifications of the system's behavior, interfaces, and algorithms.

## System Architecture

The CDM system consists of the following major components:

| Component | Description |
|-----------|-------------|
| **Input Parser** | Reads and validates JSON configuration |
| **Atmospheric Module** | Calculates derived atmospheric properties |
| **Wind Profile Module** | Characterizes the wind velocity profile |
| **Droplet Size Module** | Processes droplet size distributions |
| **Transport Module** | Integrates droplet transport ODEs using CVODE |
| **Deposition Module** | Calculates ground deposition profiles |
| **Output Module** | Generates JSON output and console reports |

## Input Specification

The model accepts JSON-formatted input containing:

- **Droplet Size Distribution** — Tabular diameter/cumulative volume data
- **Atmospheric Properties** — Temperature, pressure, humidity
- **Wind Velocity Profile** — Elevation/velocity measurement pairs
- **Application Parameters** — Nozzle configuration and application rate
- **Field Geometry** — Field dimensions and nozzle spacing
- **Solution Properties** — Spray solution physical properties

## Processing Specification

### Atmospheric Property Calculations

Derived properties calculated from input conditions:
- Wet air density (ρ_A)
- Dynamic viscosity of wet air (μ_A)
- Dew point temperature
- Wet bulb temperature (iterative calculation)

### Droplet Transport ODE System

The model solves a 6-component ODE system for each droplet size class:

| Component | Symbol | Description |
|-----------|--------|-------------|
| Vertical position | Z | Height above ground (m) |
| Horizontal position | X | Downwind distance (m) |
| Vertical velocity | V_z | Vertical speed (m/s) |
| Horizontal velocity | V_x | Horizontal speed (m/s) |
| Water mass | M_w | Droplet water mass (kg) |
| Wind velocity | V_vwx | Local wind speed (m/s) |

Integration uses CVODE (BDF method) with specified error tolerances.

### Deposition Calculation

Deposition is computed by:
1. Integrating transport for each size class and streamline
2. Tracking ground-level crossings
3. Accumulating mass at downwind distance intervals
4. Expressing results as percentage of intended application rate (%IAR)

## Output Specification

### JSON Output

Structured JSON containing:
- Input echo (all configuration parameters)
- Derived properties (atmospheric, wind profile)
- Deposition results (distance–%IAR pairs)
- Summary statistics (mass balance, on/off-field totals)

### Console Report

Human-readable summary including:
- Atmospheric properties
- Wind profile characteristics
- Integration statistics
- Deposition summary

## API Specification

See the [API Reference](api-reference) for the complete C API documentation.

## Integration Interfaces

### Command-Line Interface

```
cdmcli <input.json> [-o output.json] [-q]
```

| Option | Description |
|--------|-------------|
| `<input.json>` | Path to JSON configuration file |
| `-o output.json` | Write JSON results to file |
| `-q` | Quiet mode (suppress console output) |

### R Package

The R package provides a wrapper around the C API. See [Getting Started](getting-started#install-the-r-package) for installation instructions.
