# User Requirements Specification (URS)
## Casanova Drift Model (CDM)

**Document Version:** 1.0  
**Date:** October 30, 2025  
**Project:** Casanova Drift Model (CDM)  
**Copyright:** Bayer

---

## 1. Introduction

### 1.1 Purpose
This User Requirements Specification (URS) document defines the user requirements for the Casanova Drift Model (CDM), a mathematical model designed to simulate pesticide spray drift during agricultural applications. The CDM predicts the transport and deposition of spray droplets under various atmospheric and application conditions.

### 1.2 Scope
This document covers the functional and non-functional requirements for the CDM software library and command-line interface. The model simulates droplet transport from nozzle release through atmospheric drift to ground deposition.

### 1.3 Intended Users
- Agricultural researchers
- Regulatory scientists
- Environmental risk assessors
- Pesticide application specialists
- Software developers integrating drift modeling capabilities

### 1.4 Document Organization
This URS is organized into sections covering:
- System overview and context
- Functional requirements
- Non-functional requirements
- Input/output requirements
- Performance requirements
- Compliance and validation requirements

---

## 2. System Overview

### 2.1 Model Description
The Casanova Drift Model (CDM) is a mechanistic model that simulates the trajectory and fate of pesticide spray droplets released from agricultural spray equipment. The model accounts for:
- Droplet size distribution
- Atmospheric conditions (temperature, humidity, wind)
- Nozzle characteristics (height, pressure, angle)
- Droplet transport dynamics (velocity, evaporation)
- Ground and canopy deposition

### 2.2 Model Context
CDM is designed to support:
- Environmental risk assessment for pesticide registration
- Spray application optimization
- Drift mitigation strategy evaluation
- Regulatory compliance assessment (e.g., SETAC DRAW test cases)

---

## 3. Functional Requirements

### 3.1 Input Requirements

#### FR-1.1: Droplet Size Distribution Input
**Requirement:** The system SHALL accept droplet size distribution data as pairs of droplet diameter (μm) and cumulative volume fraction.

**Rationale:** Droplet size distribution is a critical determinant of drift potential.

**Acceptance Criteria:**
- System accepts tabular data with droplet diameter and cumulative volume fraction
- Minimum of 2 data points required
- Diameter values must be positive and in ascending order
- Volume fractions must be between 0 and 1

#### FR-1.2: Atmospheric Properties Input
**Requirement:** The system SHALL accept atmospheric condition parameters including:
- Dry air temperature (°C)
- Barometric pressure (Pa)
- Relative humidity (%)

**Rationale:** Atmospheric conditions affect droplet evaporation and transport.

**Acceptance Criteria:**
- Temperature range: -50°C to 50°C
- Pressure range: 80,000 Pa to 110,000 Pa
- Relative humidity range: 0% to 100%

#### FR-1.3: Wind Velocity Profile Input
**Requirement:** The system SHALL accept wind velocity measurements at specified elevations and optional temperature measurements.

**Rationale:** Wind profile determines horizontal transport of droplets.

**Acceptance Criteria:**
- At least one velocity measurement required
- Elevation and velocity pairs provided
- Optional temperature profile data
- Horizontal variation in wind direction (ψψψ) can be entered or calculated

#### FR-1.4: Application Parameters Input
**Requirement:** The system SHALL accept application configuration parameters including:
- Nozzle height above ground (m)
- Canopy height (m)
- Nozzle pressure (Pa)
- Nozzle angle (degrees)
- Intended application rate (kg/ha)
- Active ingredient concentration (weight fraction)

**Rationale:** Application parameters define the initial conditions for droplet release.

**Acceptance Criteria:**
- All parameters must be positive values
- Nozzle height must exceed canopy height
- Angle range: 0° to 180°

#### FR-1.5: Field Geometry Input
**Requirement:** The system SHALL accept field geometry parameters:
- Downwind field depth (m)
- Crosswind field width (m)
- Nozzle spacing on boom (m)

**Rationale:** Field geometry determines the deposition calculation domain.

**Acceptance Criteria:**
- All dimensions must be positive
- Field depth must be sufficient for the application area

#### FR-1.6: Solution Properties Input
**Requirement:** The system SHALL accept spray solution properties:
- Water density (g/cm³)
- Dissolved solids density (g/cm³)
- Mass fraction of dissolved solids

**Rationale:** Solution properties affect droplet evaporation and mass.

**Acceptance Criteria:**
- Density values must be positive
- Mass fraction must be between 0 and 1

### 3.2 Processing Requirements

#### FR-2.1: Atmospheric Property Calculations
**Requirement:** The system SHALL calculate derived atmospheric properties:
- Wet air density (ρA)
- Dynamic viscosity of wet air (μA)
- Dew point temperature
- Wet bulb temperature

**Rationale:** Derived properties are required for droplet transport calculations.

**Acceptance Criteria:**
- Calculations use validated thermodynamic relationships
- Results are physically meaningful

#### FR-2.2: Wind Profile Characterization
**Requirement:** The system SHALL characterize the wind velocity profile by calculating:
- Friction height (z₀)
- Friction velocity (Uf)

**Rationale:** Wind profile parameters are used in transport equations.

**Acceptance Criteria:**
- Friction height is positive
- Friction velocity is positive
- Profile fits logarithmic law above canopy

#### FR-2.3: Droplet Transport Simulation
**Requirement:** The system SHALL simulate droplet transport by solving ordinary differential equations for:
- Vertical position (Z)
- Horizontal position (X)
- Vertical velocity (Vz)
- Horizontal velocity (Vx)
- Water mass (Mw)
- Wind velocity (Vvwx)

**Rationale:** ODE integration provides time-resolved droplet trajectories.

**Acceptance Criteria:**
- CVODE solver is used for numerical integration
- Integration continues until droplet reaches ground or maximum time
- Solution meets specified error tolerances

#### FR-2.4: Droplet Size Distribution Processing
**Requirement:** The system SHALL process the input droplet size distribution using either:
- Non-linear least squares curve fitting (if enabled)
- Finite difference approximation (if curve fitting disabled)

**Rationale:** Distribution processing enables calculation of partial volumes for each size class.

**Acceptance Criteria:**
- Curve fitting produces smooth, monotonic cumulative distribution
- Finite difference approximation is numerically stable

#### FR-2.5: Deposition Calculation
**Requirement:** The system SHALL calculate spray deposition as a function of downwind distance including:
- On-field deposition
- Off-field drift deposition
- Deposition expressed as percentage of intended application rate

**Rationale:** Deposition results are the primary model output for risk assessment.

**Acceptance Criteria:**
- Deposition calculated for specified distance intervals
- Total deposition mass is conserved
- Results account for spray plume spreading

### 3.3 Output Requirements

#### FR-3.1: Deposition Output
**Requirement:** The system SHALL output deposition data as distance-deposition pairs:
- Distance from field edge (m)
- Deposition as percentage of intended application rate (%IAR)

**Rationale:** Deposition profile is the key model output for regulatory applications.

**Acceptance Criteria:**
- Output covers the entire drift distance range
- Data points are at user-specified intervals
- Format is suitable for plotting and further analysis

#### FR-3.2: Summary Report
**Requirement:** The system SHALL provide a summary report including:
- Input parameters
- Calculated atmospheric properties
- Wind profile characteristics
- Integration statistics
- Deposition summary statistics

**Rationale:** Summary report enables model verification and documentation.

**Acceptance Criteria:**
- Report includes all key input and derived parameters
- Report is human-readable
- Report can be printed to console or file

#### FR-3.3: JSON Output
**Requirement:** The system SHALL provide model results in JSON format for programmatic access.

**Rationale:** JSON format enables integration with other software systems.

**Acceptance Criteria:**
- Valid JSON syntax
- Includes all input and output data
- Structured for easy parsing

### 3.4 Integration Requirements

#### FR-4.1: C API
**Requirement:** The system SHALL provide a C-compatible API for library integration.

**Rationale:** C API enables use from multiple programming languages.

**Acceptance Criteria:**
- API uses C-compatible types and calling conventions
- Functions are properly exported from shared library
- Header file provides complete API documentation

#### FR-4.2: Command-Line Interface
**Requirement:** The system SHALL provide a command-line executable that:
- Accepts JSON input file
- Runs the model
- Outputs results to console or file

**Rationale:** CLI enables standalone model execution without programming.

**Acceptance Criteria:**
- Reads JSON configuration from file
- Displays progress and errors to console
- Outputs results in specified format

#### FR-4.3: R Package Interface
**Requirement:** The system SHALL support integration with R through a package wrapper.

**Rationale:** R is widely used in agricultural and environmental research.

**Acceptance Criteria:**
- R package can be installed from source
- Package provides R functions for model execution
- Demo cases are provided

---

## 4. Non-Functional Requirements

### 4.1 Performance Requirements

#### NFR-1.1: Execution Time
**Requirement:** The system SHALL complete a typical model run (single test case) within 60 seconds on standard hardware.

**Rationale:** Reasonable execution time enables interactive use and parameter exploration.

**Acceptance Criteria:**
- Test cases B, G, and I complete within specified time
- Performance is repeatable across runs

#### NFR-1.2: Memory Usage
**Requirement:** The system SHALL limit memory usage to less than 1 GB for typical simulations.

**Rationale:** Memory constraints should not limit model applicability.

**Acceptance Criteria:**
- Memory profiling confirms limit
- No memory leaks detected

#### NFR-1.3: Numerical Accuracy
**Requirement:** The system SHALL achieve numerical solutions meeting specified tolerances:
- Default relative tolerance: 1×10⁻⁴
- Default absolute tolerances: [1×10⁻⁸, 1×10⁻⁸, 1×10⁻⁸, 1×10⁻⁸, 1×10⁻¹⁰, 1×10⁻⁸]

**Rationale:** Accuracy ensures reliable predictions for regulatory decisions.

**Acceptance Criteria:**
- ODE solver meets error tolerances
- Results are reproducible
- Mass balance is conserved

### 4.2 Portability Requirements

#### NFR-2.1: Platform Support
**Requirement:** The system SHALL support compilation and execution on:
- Windows (x64)
- Linux (x64)
- macOS (x64, ARM64)

**Rationale:** Multi-platform support enables broad adoption.

**Acceptance Criteria:**
- Build system supports all platforms
- Test cases pass on all platforms
- Performance is comparable across platforms

#### NFR-2.2: Compiler Support
**Requirement:** The system SHALL compile with modern C++ compilers supporting C++17 standard.

**Rationale:** C++17 provides required language features.

**Acceptance Criteria:**
- Compiles with MSVC, GCC, and Clang
- No compiler-specific extensions required
- Standard library dependencies are portable

### 4.3 Usability Requirements

#### NFR-3.1: Input Format
**Requirement:** The system SHALL use JSON format for input configuration.

**Rationale:** JSON is human-readable and widely supported.

**Acceptance Criteria:**
- JSON syntax is validated
- Clear error messages for invalid input
- Example input files are provided

#### NFR-3.2: Documentation
**Requirement:** The system SHALL provide comprehensive documentation including:
- API reference
- User guide
- Example cases
- Build instructions

**Rationale:** Documentation enables effective use by target audience.

**Acceptance Criteria:**
- Documentation covers all features
- Examples are complete and working
- Build instructions are tested

#### NFR-3.3: Error Handling
**Requirement:** The system SHALL provide clear error messages for:
- Invalid input parameters
- Numerical integration failures
- File I/O errors

**Rationale:** Clear errors enable users to diagnose and resolve issues.

**Acceptance Criteria:**
- Error messages indicate the problem and location
- Errors do not crash the program
- Error handler can be customized

### 4.4 Maintainability Requirements

#### NFR-4.1: Code Quality
**Requirement:** The system SHALL maintain high code quality through:
- Consistent code formatting
- Clear variable and function naming
- Modular architecture

**Rationale:** Code quality supports long-term maintenance.

**Acceptance Criteria:**
- Code follows formatting standard (clang-format)
- Functions have single, clear responsibility
- Dependencies are minimized

#### NFR-4.2: Version Control
**Requirement:** The system SHALL use version control for source code management.

**Rationale:** Version control enables collaborative development and change tracking.

**Acceptance Criteria:**
- Git repository contains complete history
- Version tags mark releases
- Build system extracts version from header

### 4.5 Security Requirements

#### NFR-5.1: Input Validation
**Requirement:** The system SHALL validate all input parameters before use.

**Rationale:** Validation prevents undefined behavior from invalid input.

**Acceptance Criteria:**
- Range checks on all numerical inputs
- Consistency checks on related parameters
- Validation errors are reported clearly

#### NFR-5.2: Memory Safety
**Requirement:** The system SHALL prevent memory errors through:
- Bounds checking on array access
- Proper memory allocation and deallocation
- Use of smart pointers where appropriate

**Rationale:** Memory safety prevents crashes and security vulnerabilities.

**Acceptance Criteria:**
- No memory leaks detected by valgrind or similar tools
- No buffer overflows possible
- RAII principles applied consistently

---

## 5. Validation Requirements

### 5.1 Test Cases

#### VR-1.1: SETAC DRAW Test Cases
**Requirement:** The system SHALL be validated against SETAC DRAW test cases:
- Case B: FR_1_017 (AXI 11002, 250 kPa, no surfactant)
- Case G: NL_1_660 (XR 11004, 300 kPa, Agral surfactant)
- Case I: DE_4_006 (XR 11004, 250 kPa, no surfactant)

**Rationale:** SETAC DRAW provides standardized test cases for drift model validation.

**Acceptance Criteria:**
- Model runs successfully for all test cases
- Results are physically reasonable
- Comparison with field data or reference models is documented

### 5.2 Verification

#### VR-2.1: Mass Balance Verification
**Requirement:** The system SHALL verify that total deposited mass equals the applied mass within numerical tolerance.

**Rationale:** Mass conservation is a fundamental physical constraint.

**Acceptance Criteria:**
- Mass balance error is less than 1% for typical cases
- Error is reported in summary output

#### VR-2.2: Physical Constraints
**Requirement:** The system SHALL verify that results satisfy physical constraints:
- Droplet sizes remain positive
- Velocities are realistic
- Deposition is non-negative

**Rationale:** Physical constraints indicate correct model behavior.

**Acceptance Criteria:**
- Automated checks for constraint violations
- Warnings issued for suspicious results

---

## 6. Configuration Management

### 6.1 Version Identification
**Requirement:** The system SHALL embed version information in:
- Library binary
- Command-line executable
- API function

**Rationale:** Version tracking enables reproducibility and issue tracking.

**Acceptance Criteria:**
- Version follows semantic versioning (MAJOR.MINOR.PATCH)
- Version is automatically extracted from header file
- Version is reported by cdm_library_version() function

---

## 7. Compliance Requirements

### 7.1 Regulatory Framework
**Requirement:** The system SHALL support regulatory drift assessment workflows for pesticide registration.

**Rationale:** Model is intended for use in regulatory contexts.

**Acceptance Criteria:**
- Model accepts inputs in units used by regulatory agencies
- Output format is suitable for regulatory submissions
- Documentation meets regulatory standards

### 7.2 Scientific Validity
**Requirement:** The system SHALL implement scientifically validated algorithms for:
- Droplet transport physics
- Atmospheric property calculations
- Deposition mechanisms

**Rationale:** Scientific validity ensures reliable predictions.

**Acceptance Criteria:**
- Algorithms based on peer-reviewed literature
- Model assumptions are documented
- Limitations are clearly stated

---

## 8. Support Requirements

### 8.1 Dependencies
The system relies on the following external libraries:
- Boost (Math library for numerical algorithms)
- Blaze (Linear algebra library)
- Ceres Solver (Non-linear optimization)
- SUNDIALS (ODE solver suite)
- nlohmann_json (JSON parsing)
- fmt (String formatting)

**Requirement:** The system SHALL manage dependencies through vcpkg package manager.

**Acceptance Criteria:**
- Dependencies are automatically installed during build
- Compatible versions are specified
- Build system detects missing dependencies

---

## 9. Future Enhancements

The following enhancements may be considered for future versions:
- Support for additional nozzle types and spray configurations
- Three-dimensional drift modeling
- Time-varying meteorological conditions
- Sensitivity analysis tools
- Graphical user interface
- Cloud-based execution platform

---

## 10. Revision History

| Version | Date | Author | Description |
|---------|------|--------|-------------|
| 1.0 | 2025-10-30 | CDM Team | Initial URS document |

---

## 11. Approvals

| Role | Name | Signature | Date |
|------|------|-----------|------|
| Product Owner | | | |
| Technical Lead | | | |
| Quality Assurance | | | |

---

**End of User Requirements Specification**
