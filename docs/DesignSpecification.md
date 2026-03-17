# Design Specification
## Casanova Drift Model (CDM)

**Document Version:** 1.0  
**Date:** October 30, 2025  
**Project:** Casanova Drift Model (CDM)  
**Copyright:** Bayer

---

## 1. Introduction

### 1.1 Purpose
This Design Specification document describes the detailed software design and implementation of the Casanova Drift Model (CDM). It provides technical information about the architecture, data structures, algorithms, and implementation details needed for development and maintenance.

### 1.2 Scope
This document covers:
- Software architecture and component design
- Data structures and class hierarchies
- Algorithm implementations
- Build system and dependencies
- File organization and naming conventions
- Coding standards and practices

### 1.3 Related Documents
- User Requirements Specification (URS)
- Functional Specification
- API Reference
- Build and Installation Guide

### 1.4 Definitions and Acronyms

| Term | Definition |
|------|------------|
| CDM | Casanova Drift Model |
| ODE | Ordinary Differential Equation |
| BDF | Backward Differentiation Formula |
| CVODE | C-language Variable-coefficient ODE solver |
| RAII | Resource Acquisition Is Initialization |
| STL | Standard Template Library |
| ABI | Application Binary Interface |

---

## 2. System Architecture

### 2.1 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Client Applications                    │
│  (Command-Line Tool, R Package, Custom C/C++ Applications)  │
└───────────────────────────┬─────────────────────────────────┘
                            │
┌───────────────────────────┴─────────────────────────────────┐
│                        C API Layer                          │
│  (CDM.h - C-compatible interface with error handling)       │
└───────────────────────────┬─────────────────────────────────┘
                            │
┌───────────────────────────┴─────────────────────────────────┐
│                    C++ Implementation Core                  │
├─────────────────────────────────────────────────────────────┤
│  Serialization Module     │  Model Data Structure           │
│  (JSON I/O)               │  (Input/Output/Derived)         │
├───────────────────────────┼─────────────────────────────────┤
│  Atmospheric Properties   │  Wind Velocity Profile          │
│  (Psychrometrics)         │  (Logarithmic Law)              │
├───────────────────────────┼─────────────────────────────────┤
│  Droplet Size Model       │  Nozzle Velocity                │
│  (Curve Fitting)          │  (Initial Conditions)           │
├───────────────────────────┼─────────────────────────────────┤
│  Droplet Transport        │  Deposition                     │
│  (ODE Integration)        │  (Spatial Distribution)         │
└───────────────────────────┴─────────────────────────────────┘
                            │
┌───────────────────────────┴─────────────────────────────────┐
│                    External Dependencies                    │
│  SUNDIALS │ Ceres │ Blaze │ Boost │ nlohmann_json │ fmt     │
└─────────────────────────────────────────────────────────────┘
```

The following diagram (mermaid chart code) shows how inputs flow through the model processing pipeline to produce outputs, and how the different interfaces connect to the system.

```
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

### 2.2 Layer Responsibilities

#### Client Layer
- Provides user-facing interfaces (CLI, R bindings)
- Handles file I/O and argument parsing
- Formats output for display

#### C API Layer
- Provides stable ABI for cross-language integration
- Manages resource lifetime (creation/destruction)
- Translates between C and C++ error handling

#### C++ Core Layer
- Implements mathematical algorithms
- Manages internal data structures
- Performs numerical computations

#### Dependencies Layer
- ODE integration (SUNDIALS/CVODE)
- Non-linear optimization (Ceres Solver)
- Linear algebra (Blaze)
- Mathematical functions (Boost.Math)
- JSON parsing (nlohmann_json)
- String formatting (fmt)

---

## 3. Module Design

### 3.1 CDM Module (CDM.cpp, CDM.h)

**Purpose:** C API implementation and entry points

**Key Components:**
```cpp
// Opaque model structure (pImpl idiom)
struct cdm_model_s {
    cdm::Model model;           // Internal C++ model
    std::string output;         // Cached JSON output
    int status;                 // Execution status
};

// API functions
cdm_model_t* cdm_create_model(const char *config);
void cdm_free_model(cdm_model_t *model);
int cdm_run_model(cdm_model_t *model);
void cdm_print_report(cdm_model_t *model);
char* cdm_get_output_string(cdm_model_t *model);
void cdm_free_string(char *s);
const char* cdm_library_version(void);
cdm_error_handler_t cdm_set_error_handler(cdm_error_handler_t handler);
```

**Design Patterns:**
- **Opaque Pointer (pImpl):** Hides C++ implementation details from C clients
- **Resource Management:** RAII for C++ objects, manual management for C API
- **Error Handling:** Global error handler with customization support

**Thread Safety:** Not thread-safe (single-threaded use only)

### 3.2 Model Module (Model.hpp)

**Purpose:** Central data structure containing all model parameters and results

**Structure:**
```cpp
namespace cdm {

enum class PPPMethod {
    ENTERED = 0,        // User-provided value
    INTERPOLATE = 1,    // Interpolate from table
    SDTF = 2           // Spray Drift Task Force formula
};

struct Model {
    // Identification
    std::string name;
    
    // Input: Droplet Size Distribution
    std::vector<std::pair<double, double>> dsd;  // [diameter μm, cumulative fraction]
    double dpmin;                                  // Min droplet size [μm]
    double dpmax;                                  // Max droplet size [μm]
    bool dsdfit;                                   // Enable curve fitting
    
    // Derived: Droplet sizes and model
    std::vector<double> dp;                        // Calculated sizes [μm]
    std::unique_ptr<DropletSizeModel> dsmodel;     // Fitted model
    
    // Input: Atmospheric Properties
    double Tair;        // Temperature [°C]
    double Patm;        // Pressure [Pa]
    double RH;          // Relative humidity [%]
    
    // Derived: Atmospheric Properties
    double rhoA;        // Wet air density [g/cm³]
    double muA;         // Dynamic viscosity [g·cm⁻¹·s⁻¹]
    double Tdp;         // Dew point [°C]
    double Twb;         // Wet bulb [°C]
    double dTwb;        // Wet bulb depression [°C]
    
    // Input: Solution Properties
    double rhoW;        // Water density [g/cm³]
    double rhoS;        // Solids density [g/cm³]
    double xs0;         // Initial solids fraction
    
    // Derived: Solution Properties
    double rhoL;        // Mixture density [g/cm³]
    
    // Input: Wind Profile
    double hC;                                     // Canopy height [m]
    std::vector<std::pair<double, double>> wvu;    // Wind velocity measurements
    std::vector<std::pair<double, double>> wvT;    // Temperature measurements
    std::optional<double> ppp;                     // Horizontal variation [deg]
    PPPMethod pppMethod;                           // Calculation method
    
    // Derived: Wind Profile
    double pppcalc;     // Calculated horizontal variation [deg]
    double z0;          // Friction height [m]
    double Uf;          // Friction velocity [m/s]
    
    // Input: Droplet Transport
    double hN;          // Nozzle height [m]
    double PN;          // Nozzle pressure [Pa]
    double thetaN;      // Nozzle angle [deg]
    double ddd;         // Time scale factor (δδδ)
    
    // Derived: Nozzle Velocities
    std::array<double, constants::ns> nva;         // Streamline angles [deg]
    std::array<double, constants::ns> nvz;         // Vertical velocities [m/s]
    std::array<double, constants::ns> nvx;         // Horizontal velocities [m/s]
    
    // Derived: Transport Results
    std::array<std::vector<double>, constants::ns> xdist;  // Drift distances [m]
    
    // Input: Deposition
    double IAR;         // Application rate [kg/ha]
    double xactive;     // Active ingredient concentration
    double FD;          // Field depth [m]
    double PL;          // Field width [m]
    double dN;          // Nozzle spacing [m]
    std::optional<double> Lmax;  // Max drift distance [m]
    double lambda;      // Segment scale factor
    double dx;          // Output interval [m]
    
    // Results: Deposition
    std::vector<std::pair<double, double>> applume;  // [distance m, %IAR]
    
    // CVODE Integration Options
    double cvreltol;
    std::array<double, 6> cvabstol;
    int cvmaxord;
    int cvmxsteps;
    bool cvstldet;
    int cvmaxnef;
    int cvmaxcor;
    int cvmaxncf;
    double cvnlscoef;
    
    // Experimental Options
    std::array<bool, constants::ns> sflags;        // Streamline enable flags
};

} // namespace cdm
```

**Design Considerations:**
- **Data Locality:** Groups related parameters together
- **Optional Values:** Uses `std::optional<>` for truly optional parameters
- **Smart Pointers:** Uses `std::unique_ptr<>` for owned objects
- **Value Semantics:** Most members are value types for simplicity

### 3.3 Serialization Module (Serialization.cpp/hpp)

**Purpose:** JSON input/output handling

**Key Functions:**
```cpp
namespace cdm {

// Parse JSON string into Model structure
Model parseJSON(const std::string& json);

// Serialize Model to JSON string
std::string toJSON(const Model& model);

} // namespace cdm
```

**Implementation Details:**
- Uses `nlohmann::json` library for parsing/serialization
- Validates all required fields during parsing
- Provides detailed error messages with field names
- Handles optional fields with sensible defaults
- Preserves precision for floating-point values

**Error Handling:**
- Throws `std::runtime_error` for invalid JSON
- Throws `std::domain_error` for out-of-range values
- Throws `std::logic_error` for inconsistent parameters

### 3.4 Atmospheric Properties Module (AtmosphericProperties.cpp/hpp)

**Purpose:** Calculate derived atmospheric properties

**Interface:**
```cpp
namespace cdm {

class AtmosphericProperties {
public:
    // Calculate all properties and update model
    static void calculate(Model& model);
    
private:
    // Individual calculations
    static double dewPoint(double T, double RH);
    static double wetBulb(double T, double Tdp, double P);
    static double wetAirDensity(double T, double P, double RH);
    static double dynamicViscosity(double T, double RH);
};

} // namespace cdm
```

**Algorithms:**

**Dew Point Temperature:**
```
Magnus-Tetens approximation:
Tdp = (b * α) / (a - α)
where α = (a*T)/(b+T) + ln(RH/100)
Constants: a = 17.27, b = 237.7°C
```

**Wet Bulb Temperature:**
```
Iterative solution of psychrometric equation:
e(Twb) = e(T) - P * (T - Twb) * Cp / (λ * ε)
Solved using Newton-Raphson method
```

**Wet Air Density:**
```
ρ = (Pd * Md + Pv * Mv) / (R * T)
where Pd = P - Pv (partial pressure dry air)
      Pv = RH * Psat(T) / 100 (vapor pressure)
```

**Dynamic Viscosity:**
```
Sutherland's formula with moisture correction:
μ = μ0 * (T/T0)^(3/2) * (T0 + S)/(T + S)
Moisture correction factor applied
```

### 3.5 Wind Velocity Profile Module (WindVelocityProfile.cpp/hpp)

**Purpose:** Characterize wind profile using logarithmic law

**Interface:**
```cpp
namespace cdm {

class WindVelocityProfile {
public:
    // Fit profile to measurements and update model
    static void fit(Model& model);
    
private:
    // Calculate friction parameters
    static std::pair<double, double> fitLogProfile(
        const std::vector<std::pair<double, double>>& measurements,
        double hC);
    
    // Calculate horizontal variation
    static double calculatePPP(const Model& model);
};

} // namespace cdm
```

**Algorithm:**

**Logarithmic Profile Fitting:**
```
u(z) = (Uf/κ) * ln((z-hC)/z0)

Linearize: u = (Uf/κ) * ln(z-hC) - (Uf/κ) * ln(z0)
Let y = u, x = ln(z-hC)
Then: y = a*x + b
where a = Uf/κ, b = -(Uf/κ)*ln(z0)

Solve: Uf = a * κ
       z0 = exp(-b/a)
```

Uses least-squares regression on linearized form.

### 3.6 Droplet Size Model Module (DropletSizeModel.cpp/hpp)

**Purpose:** Fit analytical model to droplet size distribution

**Interface:**
```cpp
namespace cdm {

class DropletSizeModel {
public:
    // Fit model to DSD data
    DropletSizeModel(const std::vector<std::pair<double, double>>& dsd);
    
    // Evaluate cumulative distribution
    double cdf(double dp) const;
    
    // Evaluate probability density
    double pdf(double dp) const;
    
private:
    std::vector<double> params_;  // Model parameters
    
    // Residual function for fitting
    struct Residual {
        template <typename T>
        bool operator()(const T* params, T* residual) const;
    };
};

} // namespace cdm
```

**Model Form:**
```
Three-parameter log-normal CDF:
F(dp) = Φ((ln(dp) - μ) / σ)

Parameters:
- μ: location (mean of ln(dp))
- σ: scale (std dev of ln(dp))

PDF (derivative):
f(dp) = (1/(dp*σ*√(2π))) * exp(-((ln(dp)-μ)²)/(2σ²))
```

**Fitting:**
- Uses Ceres Solver for non-linear least squares
- Minimizes sum of squared residuals between model and data
- Levenberg-Marquardt algorithm for optimization
- Automatic differentiation for Jacobian

### 3.7 Nozzle Velocity Module (NozzleVelocity.cpp/hpp)

**Purpose:** Calculate initial droplet velocities

**Interface:**
```cpp
namespace cdm {

class NozzleVelocity {
public:
    // Calculate velocities for all streamlines
    static void calculate(Model& model);
    
private:
    // Exit velocity from Bernoulli equation
    static double exitVelocity(double P, double rho);
    
    // Velocity components for angle
    static std::pair<double, double> components(double V, double theta);
};

} // namespace cdm
```

**Algorithm:**

**Exit Velocity (Bernoulli Equation):**
```
V = √(2 * ΔP / ρ)

where ΔP = gauge pressure
      ρ = liquid density
```

**Velocity Components:**
```
For streamline angle θ (from vertical):
Vz = V * cos(θ)
Vx = V * sin(θ)

Streamline angles (NS = 11):
[-40°, -50°, -60°, -70°, -80°, -90°, -100°, -110°, -120°, -130°, -140°]
```

### 3.8 Droplet Transport Module (DropletTransport.cpp/hpp)

**Purpose:** Simulate droplet trajectories using ODE integration

**Interface:**
```cpp
namespace cdm {

class DropletTransport {
public:
    struct Params {
        double z0, Uf, hN, hC, dTwb;
        double rhoW, rhoS, rhoL, rhoA, muA;
        double xs0, ddd;
        double Ms0, Mw0;
        double Vvwx0;
    };
    
    DropletTransport(const Model& m);
    
    // Simulate single droplet trajectory
    // Returns final horizontal position [m]
    double operator()(double Vz0, double Vx0, double dp);
    
private:
    Params params;
    CVodeIntegrator cvi;
    
    // ODE right-hand side function
    friend int RhsFn(double t, N_Vector y, N_Vector ydot, void *user_data);
};

} // namespace cdm
```

**ODE System:**
```
State vector: [Z, X, Vz, Vx, Mw, Vvwx]

dZ/dt = Vz
dX/dt = Vx
dVz/dt = (FD_z + Vz*W + V*g*(ρA - ρP))/(Mw+Ms)
dVx/dt = (FD_x + Vx*W)/(Mw+Ms)
dMw/dt = -W
dVvwx/dt = Vz * Uf/(κ*(Z-hC))  if Z > z0, else 0

where:
FD_z = drag force (vertical)
FD_x = drag force (horizontal)
W = evaporation rate
V = droplet volume
ρP = particle density = (Mw+Ms)/V
```

**Implementation Details:**
- Uses CVODE from SUNDIALS library
- BDF method for stiff ODEs
- Adaptive time stepping
- Configurable error tolerances
- Stops integration when droplet reaches ground

### 3.9 Deposition Module (Deposition.cpp/hpp)

**Purpose:** Calculate spatial deposition distribution

**Interface:**
```cpp
namespace cdm {

// Calculate deposition profile
std::vector<std::pair<double, double>> Deposition(
    double IAR,           // Application rate [kg/ha]
    double xactive,       // Concentration
    double FD,            // Field depth [m]
    double PL,            // Field width [m]
    double dN,            // Nozzle spacing [m]
    double ppp,           // Horizontal variation [deg]
    double rhoL,          // Liquid density [g/cm³]
    const std::vector<double>& dp,                           // Droplet sizes
    const std::array<std::vector<double>, constants::ns>& xdist,  // Drift distances
    const std::vector<std::pair<double, double>>& dsd,       // DSD data
    const std::unique_ptr<DropletSizeModel>& dsdmodel,       // DSD model
    double dpmin,         // Min droplet size [μm]
    double dpmax,         // Max droplet size [μm]
    std::optional<double> Lmax,  // Max drift distance [m]
    double lambda,        // Segment scale factor
    double dx,            // Output interval [m]
    const std::array<bool, constants::ns>& sflags);  // Streamline flags

} // namespace cdm
```

**Algorithm:**

1. **Generate drift distance matrix:** Interpolate transport results to uniform droplet sizes
2. **Discretize domain:** Create spray and drift segments
3. **Calculate spray volumes:** Distribute total spray volume by droplet size using DSD
4. **Build deposition matrices:** Track which droplets reach which segments
5. **Apply plume spreading:** Account for horizontal wind variation
6. **Calculate concentrations:** Convert volumes to deposition rates
7. **Generate output profile:** Interpolate to desired output spacing

**Data Structures:**
```cpp
// Blaze matrix library for efficient linear algebra
blaze::DynamicMatrix<double> driftdist;  // [streamline, droplet size]
blaze::DynamicMatrix<double> DVM;         // Deposition volume matrix
blaze::DynamicMatrix<double> CM;          // Concentration matrix
blaze::DynamicVector<double> SVP;         // Spray volume by droplet size
```

### 3.10 CVODE Integrator Wrapper (CVodeIntegrator.hpp)

**Purpose:** C++ wrapper for SUNDIALS CVODE solver

**Interface:**
```cpp
namespace cdm {

class CVodeIntegrator {
public:
    using RhsFunc = int (*)(double t, N_Vector y, N_Vector ydot, void* user_data);
    
    CVodeIntegrator();
    ~CVodeIntegrator();
    
    // Initialize solver
    void init(RhsFunc f, double t0, std::initializer_list<double> y0);
    
    // Reinitialize with new initial conditions
    void reinit(double t0, std::initializer_list<double> y0);
    
    // Set parameters
    void setUserData(void* user_data);
    void setTolerances(double reltol, const std::array<double, 6>& abstol);
    void setMaxOrd(int maxord);
    void setMaxNumSteps(int mxsteps);
    void setStabLimDet(bool stldet);
    void setMaxErrTestFails(int maxnef);
    void setMaxNonlinIters(int maxcor);
    void setMaxConvFails(int maxncf);
    void setNonlinConvCoef(double nlscoef);
    
    // Integration
    void step(double tout);
    
    // Access solution
    std::vector<double> solution() const;
    
    // Statistics
    int getNumSteps() const;
    int getNumRhsEvals() const;
    // ... other statistics
    
private:
    void* cvode_mem_;
    N_Vector y_;
    SUNMatrix A_;
    SUNLinearSolver LS_;
};

} // namespace cdm
```

**Design Considerations:**
- RAII wrapper manages CVODE resources
- Throws `cvode::system_error` on integration failure
- Provides convenient C++ interface to C library
- Exception-safe (cleans up on errors)

### 3.11 Constants (Constants.hpp)

**Purpose:** Define physical and numerical constants

```cpp
namespace cdm {
namespace constants {

constexpr double karman = 0.41;              // von Kármán constant
constexpr double liquid_sheet_offset = 0.068; // Nozzle sheet offset [m]
constexpr double zeta = 1.0;                  // Plume spreading factor
constexpr int ns = 11;                        // Number of streamlines
constexpr int nout = 1000;                    // ODE output points

} // namespace constants
} // namespace cdm
```

---

## 4. Build System Design

### 4.1 Build System Overview

**Build Tool:** CMake 3.15+

**Package Manager:** vcpkg

**Supported Platforms:**
- Windows (MSVC, MinGW)
- Linux (GCC, Clang)
- macOS (Clang, Apple Silicon)

### 4.2 Directory Structure

```
CDM/
├── CMakeLists.txt              # Main build configuration
├── CMakePresets.json           # Build presets
├── vcpkg.json                  # Dependency manifest
├── vcpkg-configuration.json    # vcpkg configuration
├── README.md                   # User documentation
├── .clang-format              # Code formatting rules
├── .gitignore                 # Git ignore patterns
│
├── cmake/                      # CMake modules
│   ├── JoinPaths.cmake
│   ├── cdm-config.cmake.in
│   └── cdm.pc.in
│
├── include/                    # Public headers
│   └── cdm/
│       └── CDM.h               # C API header
│
├── src/                        # Implementation sources
│   ├── CDM.cpp                 # C API implementation
│   ├── Model.hpp               # Model data structure
│   ├── Serialization.cpp/hpp  # JSON I/O
│   ├── AtmosphericProperties.cpp/hpp
│   ├── WindVelocityProfile.cpp/hpp
│   ├── DropletSizeModel.cpp/hpp
│   ├── NozzleVelocity.cpp/hpp
│   ├── DropletTransport.cpp/hpp
│   ├── Deposition.cpp/hpp
│   ├── CVodeIntegrator.hpp     # CVODE wrapper
│   ├── CVodeError.hpp          # CVODE error handling
│   ├── Interpolate1D.hpp       # Interpolation utilities
│   ├── Constants.hpp           # Physical constants
│   ├── CLI11.hpp               # Command-line parser
│   └── CDMCLI.cpp              # CLI application
│
├── tests/                      # Test cases
│   ├── Case_B.json
│   ├── Case_G.json
│   └── Case_I.json
│
├── docs/                       # Documentation
│   ├── URS.md
│   ├── FunctionalSpecification.md
│   └── DesignSpecification.md
│
├── R/                          # R package
│   └── cdm/
│       ├── DESCRIPTION
│       ├── NAMESPACE
│       ├── R/
│       ├── src/
│       ├── inst/
│       └── demo/
│
└── ports/                      # vcpkg custom ports
    ├── blaze/
    └── sundials/
```

### 4.3 Build Configuration

**CMakeLists.txt Structure:**
```cmake
cmake_minimum_required(VERSION 3.15)

# Version extraction from header
file(READ include/cdm/CDM.h CDM_H)
# Parse CDM_VERSION

project(cdm VERSION ${CDM_VERSION} LANGUAGES CXX)

# Options
option(BUILD_SHARED_LIBS "Build shared libraries" OFF)

# Dependencies
find_package(Boost REQUIRED)
find_package(blaze CONFIG REQUIRED)
find_package(Ceres CONFIG REQUIRED)
find_package(fmt CONFIG REQUIRED)
find_package(SUNDIALS CONFIG REQUIRED)
find_package(nlohmann_json CONFIG REQUIRED)

# Library target
add_library(cdm ${SOURCES})
target_link_libraries(cdm PRIVATE ${DEPENDENCIES})
target_include_directories(cdm PUBLIC ...)

# CLI target
add_executable(cdmcli src/CDMCLI.cpp)
target_link_libraries(cdmcli PRIVATE cdm::cdm fmt::fmt)

# Install rules
install(TARGETS cdm cdmcli ...)
```

**vcpkg.json Dependencies:**
```json
{
  "name": "cdm",
  "version": "1.2.0",
  "dependencies": [
    "boost-math",
    "blaze",
    "ceres",
    "fmt",
    "sundials",
    "nlohmann-json"
  ]
}
```

### 4.4 Compiler Requirements

**C++ Standard:** C++17

**Required Features:**
- Structured bindings
- std::optional
- std::unique_ptr
- Lambda expressions
- Range-based for loops
- Variadic templates

**Compiler Versions:**
- GCC 7.0+
- Clang 5.0+
- MSVC 19.14+ (Visual Studio 2017 15.7+)
- AppleClang 10.0+

---

## 5. Data Structure Design

### 5.1 Memory Management

**Principles:**
- **RAII:** All resources managed by scope-based lifetime
- **Smart Pointers:** Use `std::unique_ptr` for owned objects
- **Value Semantics:** Prefer value types over pointers when possible
- **No Raw new/delete:** Use standard containers and smart pointers

**Example:**
```cpp
struct Model {
    // Value types
    double Tair;
    std::vector<double> dp;
    
    // Smart pointer for polymorphic object
    std::unique_ptr<DropletSizeModel> dsmodel;
    
    // Optional for truly optional data
    std::optional<double> Lmax;
};
```

### 5.2 Container Selection

| Use Case | Container | Rationale |
|----------|-----------|-----------|
| Droplet sizes | `std::vector<double>` | Sequential access, dynamic size |
| DSD data | `std::vector<std::pair<double, double>>` | Ordered pairs |
| Drift distances | `std::array<std::vector<double>, NS>` | Fixed outer size, variable inner |
| Deposition output | `std::vector<std::pair<double, double>>` | Sequential results |
| Streamline flags | `std::array<bool, NS>` | Fixed size, efficient |
| Matrices | `blaze::DynamicMatrix<double>` | Linear algebra operations |

### 5.3 Numerical Types

**Floating Point:** `double` (64-bit IEEE 754)

**Rationale:**
- Required precision for scientific computation
- Standard in numerical libraries (CVODE, Ceres, Blaze)
- Adequate range for physical quantities

**Integer Types:**
- `int`: General purpose integer
- `size_t`: Array indices and sizes
- `ptrdiff_t`: Pointer differences

### 5.4 String Handling

**Internal:** `std::string` for all string operations

**API Boundary:**
- Input: `const char*` (C string)
- Output: `char*` (allocated by library, freed by caller)

**Rationale:**
- `std::string` provides safety and convenience internally
- C strings provide ABI stability for API

---

## 6. Algorithm Design

### 6.1 ODE Integration Strategy

**Solver Selection:**
- **CVODE** from SUNDIALS library
- **Method:** BDF (Backward Differentiation Formula) for stiff equations
- **Order:** Adaptive, max order 5 (default)

**Stiffness Handling:**
- Droplet dynamics can be stiff due to:
  - Rapid evaporation for small droplets
  - Large drag forces for low velocities
  - Multiple time scales
- BDF method handles stiffness efficiently

**Error Control:**
- Relative tolerance: 1×10⁻⁴
- Absolute tolerances: Component-specific
  - Position: 1×10⁻⁸ cm
  - Velocity: 1×10⁻⁸ cm/s
  - Mass: 1×10⁻¹⁰ g

### 6.2 Interpolation Strategy

**1D Interpolation:**
- **Method:** Linear interpolation with optional extrapolation
- **Implementation:** Custom `Interpolate1D` template class
- **Features:**
  - Clamps extrapolated values to bounds (optional)
  - Throws exception for invalid domains
  - Efficient binary search for lookup

**Log-space Interpolation:**
- Used for drift distances at small angles (streamlines 0-5)
- Improves accuracy for exponential-like behavior
- Formula: `exp(interpolate(log(x), log(y)))`

### 6.3 Optimization Strategy

**Non-linear Least Squares:**
- **Library:** Ceres Solver
- **Method:** Levenberg-Marquardt
- **Automatic Differentiation:** Jet types for Jacobian
- **Termination:** Function tolerance or parameter tolerance

**DSD Curve Fitting:**
```cpp
struct Residual {
    Residual(double dp_obs, double f_obs) 
        : dp_obs_(dp_obs), f_obs_(f_obs) {}
    
    template <typename T>
    bool operator()(const T* const params, T* residual) const {
        T dp = T(dp_obs_);
        T f_model = CDF(dp, params);  // Model CDF
        residual[0] = f_model - T(f_obs_);
        return true;
    }
    
    double dp_obs_;
    double f_obs_;
};
```

### 6.4 Linear Algebra Strategy

**Library:** Blaze

**Operations:**
- Matrix-vector multiplication
- Element-wise operations
- Reductions (sum, max)
- Submatrix views

**Performance:**
- Expression templates for optimization
- SIMD vectorization
- Cache-friendly access patterns

---

## 7. Error Handling Design

### 7.1 Error Handling Strategy

**C++ Layer:**
- **Exceptions** for error conditions
- **std::runtime_error** for runtime failures
- **std::domain_error** for invalid arguments
- **std::logic_error** for programming errors
- **cvode::system_error** for CVODE failures

**C API Layer:**
- **Return codes** (0 = success, non-zero = error)
- **Error handler callback** for messages
- **No exceptions across C boundary**

### 7.2 Error Handler

**Global Error Handler:**
```cpp
static cdm_error_handler_t error_handler = default_error_handler;

cdm_error_handler_t cdm_set_error_handler(cdm_error_handler_t handler) {
    cdm_error_handler_t old = error_handler;
    error_handler = handler ? handler : default_error_handler;
    return old;
}

void cdm_error(const char *format, ...) {
    va_list args;
    va_start(args, format);
    error_handler(format, args);
    va_end(args);
}
```

**Default Handler:**
```cpp
void default_error_handler(const char *format, ...) {
    va_list args;
    va_start(args, format);
    vfprintf(stderr, format, args);
    va_end(args);
}
```

### 7.3 Exception Safety

**Guarantees:**
- **Basic:** No resource leaks, objects in valid state
- **Strong:** Operation succeeds or has no effect (where feasible)
- **No-throw:** Destructors and move operations

**Techniques:**
- RAII for all resources
- Smart pointers prevent leaks
- Standard containers provide strong guarantee
- Careful exception boundaries at API

---

## 8. Testing Design

### 8.1 Test Strategy

**Test Levels:**
1. **Unit Tests:** Individual component testing
2. **Integration Tests:** Component interaction testing
3. **System Tests:** End-to-end testing with SETAC cases
4. **Validation Tests:** Comparison with reference data

### 8.2 Test Cases

**SETAC DRAW Test Cases:**
- Case B: AXI 11002, 250 kPa, no surfactant
- Case G: XR 11004, 300 kPa, Agral surfactant
- Case I: XR 11004, 250 kPa, no surfactant

**Validation Criteria:**
- Model runs without errors
- Results are physically reasonable
- Mass balance is conserved
- Output format is correct

### 8.3 Test Infrastructure

**Command-Line Testing:**
```bash
# Run test case
./cdmcli tests/Case_B.json

# Verify exit code
echo $?  # Should be 0

# Check output exists
ls -l output.json
```

**R Package Testing:**
```r
# Run demo
demo("caseB", package="cdm")

# Verify results
result <- cdm_run("tests/Case_B.json")
stopifnot(result$statistics$totalMass > 0.99)
stopifnot(result$statistics$totalMass < 1.01)
```

---

## 9. Performance Optimization

### 9.1 Optimization Priorities

1. **Correctness:** Accuracy over speed
2. **Maintainability:** Clarity over micro-optimization
3. **Scalability:** Efficient algorithms over constant factors

### 9.2 Optimization Techniques

**Algorithmic:**
- Efficient ODE solver (CVODE)
- Adaptive time stepping
- Sparse matrix operations where applicable
- Vectorized operations (Blaze)

**Data Structure:**
- Cache-friendly memory layout
- Minimize allocations in hot loops
- Use stack allocation where possible
- Preallocate containers

**Compiler:**
- Enable optimization flags (-O3, /O2)
- Link-time optimization (LTO)
- Profile-guided optimization (PGO) for production

### 9.3 Performance Metrics

**Expected Performance:**
- Case B: ~15 seconds
- Case G: ~20 seconds
- Case I: ~25 seconds

**Bottlenecks:**
- ODE integration: 80-90% of runtime
- Deposition calculation: 5-10% of runtime
- I/O and initialization: <5% of runtime

---

## 10. Code Quality Standards

### 10.1 Coding Style

**Formatter:** clang-format

**Configuration:**
```yaml
BasedOnStyle: LLVM
IndentWidth: 4
ColumnLimit: 100
PointerAlignment: Left
```

**Naming Conventions:**
- Types: PascalCase (`Model`, `DropletTransport`)
- Functions: camelCase (`calculateDewPoint`, `parseJSON`)
- Variables: camelCase (`dewPoint`, `frictionVelocity`)
- Constants: lowercase with underscores (`liquid_sheet_offset`)
- Macros: UPPER_CASE (`CDM_VERSION`)

### 10.2 Documentation

**Header Comments:**
```cpp
// Copyright (c) 2021 John Buonagurio <jbuonagurio@exponent.com>
```

**Function Comments:**
```cpp
/**
 * Calculate dew point temperature from dry bulb temperature and RH.
 * \param[in] T Dry bulb temperature [°C]
 * \param[in] RH Relative humidity [%]
 * \return Dew point temperature [°C]
 */
double dewPoint(double T, double RH);
```

**Inline Comments:**
- Explain "why" not "what"
- Document assumptions and limitations
- Reference equations or papers where appropriate

### 10.3 Code Review Checklist

- [ ] Follows coding style
- [ ] Includes appropriate comments
- [ ] No memory leaks (checked with sanitizers)
- [ ] Exception-safe (RAII, no raw pointers)
- [ ] Const-correct
- [ ] Input validation
- [ ] Error handling
- [ ] Unit tests (if applicable)
- [ ] Documentation updated

---

## 11. Deployment Design

### 11.1 Library Distribution

**Formats:**
- **Source:** GitHub repository
- **Binary:** vcpkg package
- **R Package:** Source tarball

**Installation Methods:**
1. Build from source using CMake
2. Install via vcpkg
3. Install R package from source

### 11.2 Versioning

**Scheme:** Semantic Versioning (MAJOR.MINOR.PATCH)

**Version Definition:**
```cpp
#define CDM_VERSION 10200  // 1.2.0
#define CDM_VERSION_STRING "1.2.0"
```

**Version Access:**
```cpp
const char* version = cdm_library_version();  // Returns "1.2.0"
```

### 11.3 Compatibility

**ABI Compatibility:**
- C API provides stable ABI
- C++ internals can change between versions
- Semantic versioning guides compatibility

**Platform Compatibility:**
- Windows x64 (static and shared libraries)
- Linux x64 (shared libraries)
- macOS x64 and ARM64 (shared libraries)

---

## 12. Security Considerations

### 12.1 Input Validation

**JSON Parsing:**
- Use trusted JSON library (nlohmann_json)
- Validate schema before processing
- Reject malformed JSON
- Limit nesting depth
- Limit array/string sizes

**Parameter Validation:**
- Range checks on all numerical inputs
- Consistency checks on related parameters
- Reject NaN and infinity values
- Prevent integer overflow

### 12.2 Memory Safety

**Techniques:**
- RAII for all resources
- Smart pointers prevent leaks
- Bounds checking on array access
- Standard containers prevent buffer overflows
- No manual memory management in user code

**Tools:**
- AddressSanitizer for memory errors
- LeakSanitizer for memory leaks
- UndefinedBehaviorSanitizer for UB
- Static analysis (clang-tidy)

### 12.3 Denial of Service Prevention

**Resource Limits:**
- Maximum ODE steps (cvmxsteps)
- Maximum integration time
- Reasonable parameter ranges
- Early termination conditions

---

## 13. Maintenance Plan

### 13.1 Dependency Updates

**Update Frequency:**
- Security patches: Immediate
- Bug fixes: As needed
- Feature updates: Quarterly review

**Update Process:**
1. Review changelog
2. Update vcpkg manifest
3. Test build and run
4. Update documentation if needed
5. Commit changes

### 13.2 Code Maintenance

**Regular Tasks:**
- Update dependencies
- Review and merge pull requests
- Address bug reports
- Update documentation
- Performance profiling

**Tools:**
- GitHub for version control
- GitHub Actions for CI/CD
- GitHub Issues for bug tracking
- GitHub Projects for planning

---

## 14. Revision History

| Version | Date | Author | Description |
|---------|------|--------|-------------|
| 1.0 | 2025-10-30 | CDM Team | Initial Design Specification |

---

**End of Design Specification**
