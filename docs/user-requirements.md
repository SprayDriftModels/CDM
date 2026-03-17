---
title: User Requirements Specification
---

# User Requirements Specification (URS)

**Document Version:** 1.0 | **Date:** October 30, 2025

> This page provides an overview. View the [full URS document on GitHub](https://github.com/SprayDriftModels/CDM/blob/main/docs/URS.md).

## Purpose

This User Requirements Specification defines the user requirements for the Casanova Drift Model (CDM), a mathematical model designed to simulate pesticide spray drift during agricultural applications.

## Intended Users

- Agricultural researchers
- Regulatory scientists
- Environmental risk assessors
- Pesticide application specialists
- Software developers integrating drift modeling capabilities

## Functional Requirements Summary

### Input Requirements

| ID | Requirement | Description |
|----|-------------|-------------|
| FR-1.1 | Droplet Size Distribution | Pairs of droplet diameter (μm) and cumulative volume fraction |
| FR-1.2 | Atmospheric Properties | Dry air temperature, barometric pressure, relative humidity |
| FR-1.3 | Wind Velocity Profile | Wind velocity measurements at specified elevations |
| FR-1.4 | Application Parameters | Nozzle height, canopy height, pressure, angle, application rate |
| FR-1.5 | Field Geometry | Downwind depth, crosswind width, nozzle spacing |
| FR-1.6 | Solution Properties | Water density, dissolved solids density, mass fraction |

### Processing Requirements

| ID | Requirement | Description |
|----|-------------|-------------|
| FR-2.1 | Atmospheric Property Calculations | Wet air density, dynamic viscosity, dew point, wet bulb temperature |
| FR-2.2 | Wind Profile Characterization | Friction height (z₀), friction velocity (Uf) |
| FR-2.3 | Droplet Transport Simulation | ODE integration for Z, X, Vz, Vx, Mw, Vvwx |
| FR-2.4 | Droplet Size Distribution Processing | Curve fitting or finite difference approximation |
| FR-2.5 | Deposition Calculation | On-field and off-field deposition as %IAR |

### Output Requirements

| ID | Requirement | Description |
|----|-------------|-------------|
| FR-3.1 | Deposition Output | Distance–deposition pairs (%IAR) |
| FR-3.2 | Summary Report | Input parameters, derived properties, statistics |
| FR-3.3 | JSON Output | Machine-readable results in JSON format |

### Integration Requirements

| ID | Requirement | Description |
|----|-------------|-------------|
| FR-4.1 | C API | C-compatible shared library API |
| FR-4.2 | CLI | Command-line executable with JSON I/O |
| FR-4.3 | R Package | R wrapper for model execution |

## Non-Functional Requirements Summary

- **Performance**: Typical model run completes within 60 seconds; memory usage under 1 GB
- **Numerical Accuracy**: Relative tolerance 1×10⁻⁴; component-specific absolute tolerances
- **Platform Support**: Windows (x64), Linux (x64), macOS (x64, ARM64)
- **Compiler Support**: C++17 with MSVC, GCC, and Clang
- **Error Handling**: Clear error messages with customizable error handler

## Validation Requirements

The system is validated against SETAC DRAW test cases:

| Case | Trial ID | Nozzle Type | Nozzle Pressure | Surfactant |
|------|----------|-------------|-----------------|------------|
| B | FR_1_017 | AXI 11002 | 250 kPa | None |
| G | NL_1_660 | XR 11004 | 300 kPa | Agral |
| I | DE_4_006 | XR 11004 | 250 kPa | None |
