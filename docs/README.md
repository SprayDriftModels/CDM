# CDM Documentation

This directory contains comprehensive documentation for the Casanova Drift Model (CDM).

## Documentation Overview

The CDM documentation is organized into three main specification documents that cover different aspects of the system, along with research documentation on model enhancements:

### 1. User Requirements Specification (URS)
**File:** [URS.md](URS.md)

The URS defines **what** the system must do from a user's perspective. It contains:

- **Purpose and Scope**: Overview of the CDM model and its intended use
- **Intended Users**: Target audience for the software
- **Functional Requirements**: Detailed requirements for inputs, processing, and outputs
- **Non-Functional Requirements**: Performance, portability, usability, security requirements
- **Validation Requirements**: Test cases and verification criteria
- **Compliance Requirements**: Regulatory and scientific validity requirements

**Key Sections:**
- FR-1.x: Input Requirements (DSD, atmospheric properties, wind profile, etc.)
- FR-2.x: Processing Requirements (calculations, simulations, deposition)
- FR-3.x: Output Requirements (deposition data, reports, JSON)
- NFR-1.x: Performance Requirements
- NFR-2.x: Portability Requirements
- VR-1.x: Validation with SETAC DRAW test cases

### 2. Functional Specification
**File:** [FunctionalSpecification.md](FunctionalSpecification.md)

The Functional Specification describes **how** the system implements the user requirements. It contains:

- **System Architecture**: High-level component organization and data flow
- **Input Specifications**: Detailed JSON format specifications with examples
- **Processing Specifications**: Mathematical algorithms and calculation methods
- **Output Specifications**: JSON and console report formats
- **API Specifications**: Complete C API reference
- **Integration Specifications**: CLI and R package interfaces
- **Performance Specifications**: Computational complexity and resource usage

**Key Sections:**
- Section 3: Input Specifications (JSON format, validation)
- Section 4: Processing Specifications (atmospheric calculations, ODE integration, deposition)
- Section 5: Output Specifications (JSON output, console reports)
- Section 6: API Specifications (C API function reference)
- Section 7: Integration Specifications (CLI, R package)

### 3. Design Specification
**File:** [DesignSpecification.md](DesignSpecification.md)

The Design Specification provides **technical implementation details** for developers. It contains:

- **Software Architecture**: Detailed layer design and responsibilities
- **Module Design**: Class structures and interfaces for each component
- **Algorithm Design**: ODE integration, interpolation, optimization strategies
- **Build System Design**: CMake configuration, dependencies, directory structure
- **Data Structure Design**: Memory management, container selection, type choices
- **Error Handling Design**: Exception strategy, error handler implementation
- **Code Quality Standards**: Coding style, documentation, review checklist

**Key Sections:**
- Section 2: System Architecture (layers and data flow)
- Section 3: Module Design (detailed C++ class designs)
- Section 4: Build System Design (CMake, vcpkg, directory structure)
- Section 6: Algorithm Design (ODE integration, interpolation, optimization)
- Section 7: Error Handling Design (exceptions and error handlers)
- Section 10: Code Quality Standards (style, documentation)

## Document Relationships

```
┌─────────────────────────────────────────────────────────────┐
│                User Requirements Specification               │
│                      (WHAT - User View)                      │
│  • What users need                                          │
│  • Functional requirements                                  │
│  • Performance requirements                                 │
└──────────────────────┬──────────────────────────────────────┘
                       │ implements
┌──────────────────────┴──────────────────────────────────────┐
│                  Functional Specification                    │
│                     (HOW - System View)                      │
│  • How requirements are met                                 │
│  • System behavior                                          │
│  • Interfaces and formats                                   │
└──────────────────────┬──────────────────────────────────────┘
                       │ detailed by
┌──────────────────────┴──────────────────────────────────────┐
│                   Design Specification                       │
│                (IMPLEMENTATION - Developer View)             │
│  • Technical implementation                                 │
│  • Data structures                                          │
│  • Algorithms and code                                      │
└─────────────────────────────────────────────────────────────┘
```

### 4. Research Documentation
**File:** [VerticalDriftDistribution_Abstract.md](VerticalDriftDistribution_Abstract.md)

This document presents research on enhancing the Casanova Drift Model with vertical drift distribution extraction capabilities. It addresses:

- **Background**: Importance of spray drift modeling for regulatory assessment of non-target organisms (NTAs and NTTPs)
- **Current Limitations**: Existing models primarily generate deposition curves without vertical distribution data
- **Enhancement Approach**: Integration of vertical drift profiles to improve risk assessment
- **Key Factors**: Analysis of droplet size, wind speed, and application technique influences
- **Preliminary Results**: Short-range aerial drift pattern representation
- **Regulatory Impact**: Improved risk analysis and regulatory compliance for crop protection management

**Target Audience:**
- Agricultural researchers studying spray drift dynamics
- Regulatory scientists assessing environmental risks
- Environmental risk assessors evaluating non-target organism exposure
- Pesticide application specialists optimizing drift mitigation strategies

## Reading Guide

### For Users and Stakeholders
Start with the **User Requirements Specification (URS)** to understand:
- What the CDM model does
- What inputs are required
- What outputs are produced
- Performance expectations
- Validation approach

For research context and future enhancements, see the **Vertical Drift Distribution Abstract** to understand ongoing work on vertical drift profile extraction for improved non-target organism risk assessment.

### For Integrators and Application Developers
Read the **Functional Specification** to understand:
- How to format input JSON files
- What the API functions do
- How to interpret outputs
- How to integrate with C/C++ or R

### For CDM Developers and Maintainers
Study the **Design Specification** to understand:
- How the code is organized
- How algorithms are implemented
- How to build and test
- Coding standards and practices
- How to extend functionality

## Quick Reference

### Key Model Parameters
- **Droplet Size Distribution**: Droplet diameters and cumulative volume fractions
- **Atmospheric Conditions**: Temperature, pressure, relative humidity
- **Wind Profile**: Velocity measurements at different elevations
- **Application Settings**: Nozzle height, pressure, angle, application rate
- **Field Geometry**: Field dimensions and nozzle spacing

### Key Outputs
- **Deposition Profile**: Distance vs. deposition (%IAR) pairs
- **Derived Properties**: Calculated atmospheric and wind properties
- **Summary Statistics**: Mass balance, on-field vs. off-field deposition

### API Quick Start
```c
// Create model from JSON configuration
cdm_model_t* model = cdm_create_model(json_config);

// Run the simulation
int status = cdm_run_model(model);

// Print results
cdm_print_report(model);

// Get JSON output
char* output = cdm_get_output_string(model);
cdm_free_string(output);

// Clean up
cdm_free_model(model);
```

### CLI Quick Start
```bash
# Run model with test case
cdmcli tests/Case_B.json

# Save JSON output
cdmcli tests/Case_B.json -o results.json

# Quiet mode
cdmcli tests/Case_B.json -o results.json -q
```

### R Package Quick Start
```r
# Load package
library(cdm)

# Run model
result <- cdm_run("tests/Case_B.json")

# Access results
plot(result$results$deposition)

# Run demo
demo("caseB", package="cdm")
```

## Additional Resources

### Source Code
- **GitHub Repository**: https://github.com/bayer-int/cdmcpp
- **Main Branch**: Latest stable release
- **Include Directory**: Public C API header (include/cdm/CDM.h)
- **Source Directory**: Implementation files (src/)
- **Test Cases**: SETAC DRAW test cases (tests/)

### Test Cases
The repository includes three SETAC DRAW test cases for validation:

1. **Case B** (FR_1_017): AXI 11002 nozzle, 250 kPa, no surfactant
2. **Case G** (NL_1_660): XR 11004 nozzle, 300 kPa, Agral surfactant
3. **Case I** (DE_4_006): XR 11004 nozzle, 250 kPa, no surfactant

These test cases are located in the `tests/` directory as JSON files.

### Dependencies
The CDM model relies on several high-quality scientific computing libraries:

- **SUNDIALS**: ODE solver (CVODE)
- **Ceres Solver**: Non-linear least squares optimization
- **Blaze**: Linear algebra and matrix operations
- **Boost.Math**: Mathematical functions
- **nlohmann_json**: JSON parsing and serialization
- **fmt**: String formatting

All dependencies are managed through vcpkg for easy installation.

### Building the Code
See the main [README.md](../README.md) in the repository root for build instructions for:
- Windows (Visual Studio)
- Linux (GCC/Clang)
- macOS (Clang/Apple Silicon)

## Version Information

**Current Version**: 1.2.0

**Document Version**: 1.0

**Last Updated**: October 30, 2025

---

## Document Maintenance

These specification documents should be updated whenever:
- New features are added
- Requirements change
- Implementation details change significantly
- Bug fixes affect documented behavior

Updates should maintain consistency across all three documents:
- URS ← defines the requirement
- Functional Spec ← describes the implementation approach
- Design Spec ← provides technical details

---

For questions or clarifications about this documentation, please refer to the repository's issue tracker or contact the development team.
