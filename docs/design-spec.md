---
title: Design Specification
---

# Design Specification

**Document Version:** 1.0 | **Date:** October 30, 2025

> This page provides an overview. View the [full Design Specification on GitHub](https://github.com/SprayDriftModels/CDM/blob/main/docs/DesignSpecification.md).

## Purpose

The Design Specification provides technical implementation details for CDM developers and maintainers. It covers the software architecture, data structures, algorithms, and coding standards.

## System Architecture

```
┌─────────────────────────────────────────────────────┐
│              Client Applications                     │
│          (CLI, R Package, Custom)                    │
├─────────────────────────────────────────────────────┤
│                   C API Layer                        │
│              (CDM.h / CDM.cpp)                       │
├─────────────────────────────────────────────────────┤
│              Model Orchestration                     │
│                 (Model.hpp)                          │
├──────────┬──────────┬──────────┬────────────────────┤
│ Atmos.   │ Wind     │ Droplet  │ Transport /        │
│ Props    │ Profile  │ Size     │ Deposition         │
├──────────┴──────────┴──────────┴────────────────────┤
│           SUNDIALS / Ceres / Blaze                   │
└─────────────────────────────────────────────────────┘
```

## Model Component Diagram

The following diagram shows how inputs flow through the model processing pipeline to produce outputs, and how the different interfaces connect to the system.

```mermaid
flowchart TB
    subgraph Inputs["📥 Inputs"]
        DSD["Droplet Size<br/>Distribution<br/><i>diameter, cumulative<br/>volume fraction</i>"]
        ATM["Atmospheric<br/>Properties<br/><i>temperature, pressure,<br/>relative humidity</i>"]
        WIND["Wind Velocity<br/>Profile<br/><i>elevation/velocity<br/>measurements</i>"]
        APP["Application<br/>Parameters<br/><i>nozzle height, pressure,<br/>angle, application rate</i>"]
        FIELD["Field Geometry<br/><i>downwind depth,<br/>crosswind width,<br/>nozzle spacing</i>"]
        SOL["Solution<br/>Properties<br/><i>water density,<br/>solids fraction</i>"]
    end

    subgraph Processing["⚙️ Model Processing"]
        direction TB
        JSON["JSON Parser<br/>&amp; Validator"]

        subgraph Derived["Derived Properties"]
            ATMC["Atmospheric<br/>Calculations<br/><i>ρ_A, μ_A, T_wet,<br/>T_dew</i>"]
            WINDC["Wind Profile<br/>Characterization<br/><i>friction velocity U_f,<br/>roughness z₀</i>"]
            DSDC["DSD Processing<br/><i>curve fitting or<br/>finite difference</i>"]
            NOZZLE["Nozzle Velocity<br/><i>exit velocity,<br/>streamline angles<br/>−40° to −140°</i>"]
        end

        subgraph Transport["ODE Integration (CVODE)"]
            ODE["6-Component System<br/><i>Z, X, V_z, V_x, M_w, V_vwx</i>"]
            DRAG["Drag Forces"]
            EVAP["Evaporation"]
            GRAV["Gravitational<br/>Settling"]
            WINDINT["Wind<br/>Interaction"]
        end

        DEP["Deposition<br/>Calculation<br/><i>ground crossings,<br/>mass accumulation</i>"]
    end

    subgraph Outputs["📤 Outputs"]
        DEPO["Deposition Profile<br/><i>distance vs %IAR</i>"]
        VERT["Vertical Drift<br/>Profile<br/><i>concentration at<br/>downwind distances</i>"]
        REPORT["Summary Report<br/><i>atmospheric props,<br/>wind profile,<br/>mass balance</i>"]
        JSONOUT["JSON Results<br/><i>full input echo +<br/>all outputs</i>"]
    end

    subgraph Interfaces["🔗 Interfaces"]
        CAPI["C API<br/><i>libcdm shared library</i>"]
        CLI["CLI<br/><i>cdmcli executable</i>"]
        RPKG["R Package<br/><i>cdm</i>"]
    end

    DSD --> JSON
    ATM --> JSON
    WIND --> JSON
    APP --> JSON
    FIELD --> JSON
    SOL --> JSON

    JSON --> ATMC
    JSON --> WINDC
    JSON --> DSDC
    JSON --> NOZZLE

    ATMC --> ODE
    WINDC --> ODE
    DSDC --> ODE
    NOZZLE --> ODE

    DRAG --> ODE
    EVAP --> ODE
    GRAV --> ODE
    WINDINT --> ODE

    ODE --> DEP

    DEP --> DEPO
    DEP --> VERT
    DEP --> REPORT
    DEP --> JSONOUT

    CAPI --> Outputs
    CLI --> Outputs
    RPKG --> Outputs

    style Inputs fill:#e8f4fd,stroke:#0969da,color:#24292f
    style Processing fill:#f6f8fa,stroke:#57606a,color:#24292f
    style Derived fill:#fff8e1,stroke:#d4a017,color:#24292f
    style Transport fill:#fce4ec,stroke:#c62828,color:#24292f
    style Outputs fill:#e8f5e9,stroke:#2e7d32,color:#24292f
    style Interfaces fill:#f3e5f5,stroke:#7b1fa2,color:#24292f
```

## Module Design

### Source Files

| File | Purpose |
|------|---------|
| `CDM.cpp` | C API implementation |
| `CDMCLI.cpp` | Command-line interface |
| `Model.hpp` | Model orchestration and state |
| `AtmosphericProperties.cpp/hpp` | Atmospheric property calculations |
| `WindVelocityProfile.cpp/hpp` | Wind profile characterization |
| `DropletSizeModel.cpp/hpp` | Droplet size distribution processing |
| `DropletTransport.cpp/hpp` | ODE-based droplet transport |
| `NozzleVelocity.cpp/hpp` | Nozzle exit velocity calculations |
| `Deposition.cpp/hpp` | Deposition accumulation and reporting |
| `Serialization.cpp/hpp` | JSON input/output |
| `CVodeIntegrator.hpp` | CVODE wrapper with RAII |
| `Interpolate1D.hpp` | 1D interpolation utilities |
| `Constants.hpp` | Physical constants |
| `CVodeError.hpp` | CVODE error handling |

### Key Design Decisions

- **C API with C++ internals**: Public API uses C for maximum interoperability; implementation is modern C++17
- **RAII throughout**: All resources managed via smart pointers and RAII wrappers
- **Header-only templates**: `Model.hpp`, `CVodeIntegrator.hpp`, `Interpolate1D.hpp` are header-only
- **Opaque pointer pattern**: `cdm_model_t` hides C++ implementation from C clients

## Algorithm Design

### ODE Integration

- **Solver**: SUNDIALS CVODE with BDF method
- **Tolerances**: Relative 1×10⁻⁴; component-specific absolute tolerances
- **Root finding**: Used to detect ground-level crossings
- **Right-hand side**: Computes drag forces, gravitational settling, evaporation, and wind interaction

### Droplet Size Distribution

- **Curve fitting**: Ceres Solver performs non-linear least squares fit to CDF
- **Parameterization**: Log-normal or similar distribution models
- **Discretization**: Distribution divided into size classes for transport integration

### Wind Profile

- **Logarithmic law**: Wind velocity follows log-law profile above canopy
- **Parameter estimation**: Friction velocity and roughness length from measurements
- **Optimization**: Ceres Solver for parameter fitting

## Build System

### CMake Configuration

- **Minimum CMake version**: 3.21
- **C++ standard**: C++17
- **Package manager**: vcpkg (with manifest mode)
- **Presets**: CMakePresets.json for common configurations

### Directory Structure

| Directory | Contents |
|-----------|----------|
| `include/cdm/` | Public C API header |
| `src/` | C++ implementation files |
| `tests/` | Test case JSON files |
| `R/cdm/` | R package source |
| `cmake/` | CMake helper scripts |
| `docs/` | Documentation |

## Code Quality Standards

- Modern C++17 idioms
- Consistent naming: snake_case for C API, CamelCase for C++ classes
- RAII for all resource management
- No raw `new`/`delete` in application code
- Comprehensive error handling via custom error handler
