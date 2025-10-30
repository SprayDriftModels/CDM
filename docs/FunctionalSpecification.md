# Functional Specification
## Casanova Drift Model (CDM)

**Document Version:** 1.0  
**Date:** October 30, 2025  
**Project:** Casanova Drift Model (CDM)  
**Copyright:** Bayer

---

## 1. Introduction

### 1.1 Purpose
This Functional Specification document describes how the Casanova Drift Model (CDM) implements the user requirements defined in the User Requirements Specification (URS). It provides detailed specifications of the system's behavior, interfaces, and algorithms.

### 1.2 Scope
This document covers:
- Detailed functional behavior of system components
- Input/output data structures and formats
- Mathematical algorithms and equations
- API specifications
- Processing workflows
- Integration interfaces

### 1.3 Related Documents
- User Requirements Specification (URS)
- Design Specification
- API Reference Documentation
- User Guide

### 1.4 Definitions and Acronyms

| Term | Definition |
|------|------------|
| CDM | Casanova Drift Model |
| DSD | Droplet Size Distribution |
| IAR | Intended Application Rate |
| ODE | Ordinary Differential Equation |
| CVODE | C-language Variable-coefficient ODE solver (from SUNDIALS) |
| JSON | JavaScript Object Notation |
| API | Application Programming Interface |
| CLI | Command-Line Interface |
| SETAC | Society of Environmental Toxicology and Chemistry |
| DRAW | DRift Analysis Workshop |

---

## 2. System Overview

### 2.1 System Architecture
The CDM system consists of the following major components:

1. **Input Module**: Parses and validates JSON configuration
2. **Atmospheric Properties Module**: Calculates derived atmospheric conditions
3. **Wind Profile Module**: Characterizes wind velocity profile
4. **Droplet Size Model**: Processes droplet size distribution
5. **Nozzle Velocity Module**: Calculates initial droplet velocities
6. **Transport Module**: Simulates droplet trajectories using ODE integration
7. **Deposition Module**: Calculates spatial distribution of deposited spray
8. **Output Module**: Formats and exports results
9. **C API**: Provides library interface for external integration

### 2.2 Data Flow
The typical data flow through the system is:

```
JSON Input → Input Validation → Atmospheric Properties Calculation
                ↓
         Wind Profile Analysis
                ↓
    Droplet Size Distribution Processing
                ↓
      Nozzle Velocity Calculation
                ↓
         Transport Simulation (ODE)
                ↓
        Deposition Calculation
                ↓
     Output Generation (JSON/Report)
```

---

## 3. Input Specifications

### 3.1 JSON Input Format

#### 3.1.1 Overall Structure
The input is a JSON object with a single top-level key representing the case name. The value is an object containing all model parameters.

```json
{
  "CaseName": {
    "dropletSizeDistribution": [...],
    "dryAirTemperature": 16.6,
    "barometricPressure": 101325,
    "relativeHumidity": 67.1,
    "windVelocityProfile": {...},
    "dropletTransport": {...},
    "deposition": {...},
    "integrationOptions": {...},
    "experimentalOptions": {...}
  }
}
```

#### 3.1.2 Droplet Size Distribution
Array of [diameter (μm), cumulative volume fraction] pairs.

**Format:**
```json
"dropletSizeDistribution": [
  [18, 4.772e-05],
  [22, 1.185e-03],
  ...
]
```

**Constraints:**
- Minimum 2 data points
- Diameters in ascending order
- Diameters > 0
- Volume fractions in range [0, 1]
- Last volume fraction should be 1.0 or very close

#### 3.1.3 Atmospheric Properties
**Format:**
```json
"dryAirTemperature": 16.6,      // °C
"barometricPressure": 101325,   // Pa
"relativeHumidity": 67.1        // %
```

**Constraints:**
- Temperature: [-50, 50] °C
- Pressure: [80000, 110000] Pa
- Humidity: [0, 100] %

#### 3.1.4 Wind Velocity Profile
**Format:**
```json
"windVelocityProfile": {
  "velocityMeasurements": [
    [2.0, 2.436272531]  // [elevation (m), velocity (m/s)]
  ],
  "temperatureMeasurements": [],  // Optional: [elevation (m), temperature (°C)]
  "horizontalVariation": 10.7,    // ψψψ (degrees)
  "horizontalVariationMethod": 0  // 0=Entered, 1=Interpolate, 2=SDTF
}
```

**Constraints:**
- At least one velocity measurement required
- Elevations > 0
- Velocities ≥ 0
- horizontalVariationMethod: {0, 1, 2}
- If method = 0 (Entered), horizontalVariation must be provided

#### 3.1.5 Droplet Transport Parameters
**Format:**
```json
"dropletTransport": {
  "nozzleHeight": 0.8016,         // m
  "canopyHeight": 0.15,           // m
  "nozzlePressure": 250000.0,     // Pa
  "nozzleAngle": 110.0,           // degrees
  "waterDensity": 1.0,            // g/cm³
  "solidsDensity": 1.6,           // g/cm³
  "solidsFraction": 0.0079761,    // unitless
  "ddd": 60                       // δδδ scale factor, optional
}
```

**Constraints:**
- nozzleHeight > canopyHeight
- All heights ≥ 0
- nozzlePressure > 0
- nozzleAngle: [0, 180] degrees
- Densities > 0
- solidsFraction: [0, 1]
- ddd ≥ 1

#### 3.1.6 Deposition Parameters
**Format:**
```json
"deposition": {
  "dsdCurveFitting": true,        // Enable non-linear least squares
  "applicationRate": 0.83886,     // kg/ha
  "concentrationAI": 0.0079761,   // wt. fraction
  "downwindFieldDepth": 24.0,     // m
  "crosswindFieldDepth": 72.0,    // m (labeled as width in code)
  "nozzleSpacing": 0.5,           // m
  "minDropletSize": 17.831,       // μm
  "maxDropletSize": 600.0,        // μm
  "maxDriftDistance": 60.96,      // m, optional (null = auto)
  "lambda": 4,                    // Drift segment scale factor, optional
  "outputInterval": 0.6096        // m, optional
}
```

**Constraints:**
- applicationRate > 0
- concentrationAI: (0, 1]
- All dimensions > 0
- minDropletSize < maxDropletSize
- lambda ≥ 1
- outputInterval > 0

#### 3.1.7 Integration Options (Optional, Advanced)
**Format:**
```json
"integrationOptions": {
  "relativeTolerance": 1e-5,
  "absoluteTolerances": [1e-8, 1e-8, 1e-8, 1e-8, 1e-10, 1e-8],
  "maxOrder": 5,
  "maxSteps": 2000,
  "stabilityLimitDetection": false,
  "maxErrorTestFailures": 10,
  "maxNonlinearIterations": 3,
  "maxConvergenceFailures": 20,
  "convergenceCoefficient": 0.1
}
```

**Constraints:**
- relativeTolerance ≥ 1e-3 (recommended)
- absoluteTolerances array must have 6 elements
- maxOrder ≥ 1
- maxSteps ≥ 1
- maxErrorTestFailures ≥ 1
- maxNonlinearIterations ≥ 1
- maxConvergenceFailures ≥ 1
- convergenceCoefficient > 0

#### 3.1.8 Experimental Options (Optional, Advanced)
**Format:**
```json
"experimentalOptions": {
  "enableStreamlines": [
    true,  // -40°
    true,  // -50°
    true,  // -60°
    true,  // -70°
    true,  // -80°
    true,  // -90°
    true,  // -100°
    true,  // -110°
    true,  // -120°
    true,  // -130°
    true   // -140°
  ]
}
```

**Constraints:**
- Array must have exactly 11 boolean elements (NS = 11)

### 3.2 Input Validation

The system performs the following validation steps:

1. **JSON Syntax Validation**: Verify valid JSON format
2. **Schema Validation**: Verify all required fields are present
3. **Type Validation**: Verify data types match specifications
4. **Range Validation**: Verify values are within acceptable ranges
5. **Consistency Validation**: Verify related parameters are consistent
6. **Physical Validation**: Verify parameters are physically meaningful

Validation errors are reported with:
- Field name
- Expected type/range
- Actual value
- Description of the problem

---

## 4. Processing Specifications

### 4.1 Atmospheric Properties Calculations

#### 4.1.1 Wet Air Density (ρA)
The density of wet air is calculated from the ideal gas law and the moisture content.

**Algorithm:**
1. Calculate saturation vapor pressure using August-Roche-Magnus equation
2. Calculate actual vapor pressure from relative humidity
3. Calculate density using ideal gas law for mixture of dry air and water vapor

**References:**
- Standard psychrometric equations
- ASHRAE Handbook

#### 4.1.2 Dynamic Viscosity (μA)
Dynamic viscosity of air is calculated using Sutherland's formula with corrections for moisture.

**Algorithm:**
1. Calculate viscosity of dry air at temperature
2. Apply moisture correction factor
3. Return viscosity in g·cm⁻¹·s⁻¹

#### 4.1.3 Dew Point Temperature
Calculated using the August-Roche-Magnus approximation.

**Algorithm:**
1. Calculate vapor pressure from RH and temperature
2. Apply inverse Magnus formula to get dew point

#### 4.1.4 Wet Bulb Temperature
Calculated using an iterative psychrometric equation.

**Algorithm:**
1. Initialize with dew point temperature
2. Iteratively solve psychrometric equation
3. Converge to wet bulb temperature within tolerance

### 4.2 Wind Velocity Profile

#### 4.2.1 Logarithmic Profile Parameters
The wind velocity profile above the canopy is characterized by:

```
u(z) = (Uf / κ) * ln((z - hC) / z₀)
```

Where:
- u(z) = wind velocity at height z
- Uf = friction velocity
- κ = von Kármán constant (0.41)
- hC = canopy height
- z₀ = friction height (roughness length)

**Algorithm:**
1. Fit logarithmic profile to velocity measurements
2. Extract Uf and z₀ parameters using least squares
3. Validate that z₀ > 0 and Uf > 0

#### 4.2.2 Horizontal Variation (ψψψ)
Depending on the method specified:

**Method 0 (Entered)**: Use the value provided in input

**Method 1 (Interpolate)**: Interpolate from lookup table based on wind speed and atmospheric stability

**Method 2 (SDTF)**: Calculate using spray drift task force empirical relationship

### 4.3 Droplet Size Distribution Processing

#### 4.3.1 Curve Fitting Method
When `dsdCurveFitting` is enabled:

**Algorithm:**
1. Define cumulative distribution function model (e.g., log-normal, Rosin-Rammler)
2. Use Ceres Solver for non-linear least squares optimization
3. Fit model parameters to input DSD data
4. Generate probability density function (PDF) from fitted CDF

**Benefits:**
- Smooth, differentiable distribution
- Better interpolation/extrapolation
- Physically realistic PDF

#### 4.3.2 Finite Difference Method
When curve fitting is disabled:

**Algorithm:**
1. Create interpolation function from input DSD
2. Calculate PDF using finite difference approximation of derivative
3. Clamp PDF values to [0, infinity)

**Limitations:**
- Less smooth than curve fitting
- Sensitive to noise in input data
- May require denser DSD measurements

### 4.4 Nozzle Velocity Calculation

#### 4.4.1 Initial Droplet Velocities
For each streamline angle, calculate initial vertical and horizontal velocity components.

**Algorithm:**
1. Calculate nozzle exit velocity from pressure using Bernoulli equation:
   ```
   V = √(2 * ΔP / ρ)
   ```
2. For each streamline angle θ (relative to vertical):
   - Vz₀ = V * cos(θ)
   - Vx₀ = V * sin(θ)

**Streamline Angles:**
The model uses NS = 11 streamlines at angles:
-40°, -50°, -60°, -70°, -80°, -90°, -100°, -110°, -120°, -130°, -140°

(measured from vertical, negative indicates forward spray direction)

### 4.5 Droplet Transport Simulation

#### 4.5.1 Governing Equations
The transport of each droplet is modeled by a system of 6 ODEs:

**State Vector:**
- Z: Vertical position (cm)
- X: Horizontal position (cm)
- Vz: Vertical velocity (cm/s)
- Vx: Horizontal velocity (cm/s)
- Mw: Water mass (g)
- Vvwx: Local wind velocity (cm/s)

**Differential Equations:**

```
dZ/dt = Vz

dX/dt = Vx

dVz/dt = [π * CD(Re_z) * ρA * D² * (-Vz) * |Vz| / 8 
          + Vz * W(Mw, Re) + V * gc * (ρA - (Mw+Ms)/V)] / (Mw+Ms)

dVx/dt = [π * CD(Re_x) * ρA * D² * (Vvwx-Vx) * |Vvwx-Vx| / 8 
          + Vx * W(Mw, Re)] / (Mw+Ms)

dMw/dt = -W(Mw, Re)

dVvwx/dt = Vz * (Uf/κ) / (Z - hC)  if Z > z₀, else 0
```

**Where:**
- CD(Re) = Drag coefficient (Clift & Gauvin correlation)
- W(Mw, Re) = Evaporation rate (Ranz-Marshall correlation)
- V = Droplet volume
- D = Droplet diameter
- gc = Gravitational acceleration
- Ms = Solids mass (constant)
- Re = Reynolds number

#### 4.5.2 Drag Coefficient
```
CD(Re) = 24/Re * (1 + 0.197 * Re^0.63 + 0.00026 * Re^1.38)
```

Valid for Re < 2×10⁵ (Clift & Gauvin, 1970)

#### 4.5.3 Evaporation Rate
```
W(Mw, Re) = (3π^(2/3) / 2·6^(2/3)) * λw * ΔTwb * ρW * 
            (Ms/ρS + Mw/ρW)^(1/3) * (1 + 0.276√Re) * Mw/(Ms+Mw)
```

Where:
- λw = 76.4×10⁻⁸ cm²/(s·°C) (evaporation coefficient)
- ΔTwb = Wet bulb temperature depression

Based on Ranz-Marshall correlation for mass transfer.

#### 4.5.4 Initial Conditions
For droplet diameter dp and streamline n:

```
Z(0) = hN - δ          // Nozzle height minus liquid sheet offset
X(0) = 0
Vz(0) = V * cos(θₙ)   // From nozzle velocity calculation
Vx(0) = V * sin(θₙ)
Mw(0) = π/6 * dp³ * (1-xs₀) / (xs₀/ρS + (1-xs₀)/ρW)
Vvwx(0) = (Uf/κ) * ln((hN-hC)/z₀)  if hN > z₀, else 0
```

Where:
- δ = 0.068 m (liquid sheet offset constant)
- xs₀ = Initial mass fraction of solids

#### 4.5.5 Integration Parameters
**Method:** CVODE (Adams-Moulton for non-stiff, BDF for stiff ODEs)

**Time Domain:**
- t₀ = 0
- tmax = δδδ * hN / Vt
  - δδδ = 60 (default scale factor)
  - Vt = Terminal velocity of droplet

**Output Points:** nout = 1000 equally spaced points

**Termination Conditions:**
1. Droplet reaches ground level: Z ≤ z₀ + hC
2. Time reaches tmax
3. Integration error exceeds tolerances

#### 4.5.6 Terminal Velocity Estimation
Terminal velocity Vt is estimated by solving:

```
Vt = √[4 * dp * g * (ρL - ρA) / (3 * ρA * CD(Re))]
```

Using iterative root-finding (Boost bracket_and_solve_root).

### 4.6 Deposition Calculation

#### 4.6.1 Drift Distance Matrix
For each streamline n and droplet size class i:
- Run transport simulation to get final horizontal position X(tmax)
- Store in drift distance matrix: driftdist[n, i] = X(tmax)

**Interpolation:**
- For streamlines with θ < -90°: Use log-transformed interpolation
- For streamlines with θ ≥ -90°: Use linear interpolation

#### 4.6.2 Segment Discretization
The calculation domain is divided into segments:

**Sprayed Area:**
- Number of segments: Nsa = FD / dN
- Segment width: ΔWsa = FD / Nsa
- Midpoint positions: x[i] = ΔWsa * (0.5 + i) for i = 0..Nsa-1

**Drift Area:**
- Number of segments: Nda = Nsa * λ
- Segment width: ΔWda = ΔWsa
- Midpoint positions: x[j] = FD + ΔWda * (0.5 + j - Nsa) for j = Nsa..Nsa+Nda-1

#### 4.6.3 Spray Volume Distribution
Calculate partial volume for each droplet size:

**With Curve Fitting:**
```
SVP[i] = pdf(dp[i]) * Δdp * Vsprayed / Nsa
```

**Without Curve Fitting:**
```
SVP[i] = d(CDF)/d(dp)|dp[i] * Δdp * Vsprayed / Nsa
```

Where:
- Δdp = 0.5 μm (droplet size increment)
- Vsprayed = IAR * Area / (ρL * xactive)

#### 4.6.4 Deposition Volume Matrix (DVM)
For each droplet size i and segment j:

```
DVM[i,j] = Σ(n=0 to NS-1) SVP[i] / NS   if droplet reaches segment j
```

The algorithm identifies which segments receive spray from each droplet size and streamline.

#### 4.6.5 Concentration Matrix (CM)
Accounts for plume spreading due to horizontal wind variation:

```
CM[i,j] = Σ(n=0 to NS-1) (SVP[i]/NS) / (ΔW[j] * W[j])
```

Where:
- W[j] = PL + 2 * x[j] * tan(ψψψ * ζ)
- ζ = π/180 (degree to radian conversion)
- ψψψ = Horizontal wind variation

#### 4.6.6 Deposition Profile
Calculate deposition at each distance x:

```
Deposition(x) = Σ(i) CM[i, segment(x)] / (IAR/10000) * 100
```

Expressed as percentage of intended application rate (%IAR).

**Output:** Array of [distance (m), deposition (%IAR)] pairs at specified intervals.

---

## 5. Output Specifications

### 5.1 JSON Output Format

The output JSON contains all input parameters plus calculated results:

```json
{
  "CaseName": {
    "input": {
      // All input parameters echoed back
    },
    "derived": {
      "wetAirDensity": 0.001234,        // g/cm³
      "dynamicViscosity": 0.0001789,    // g/(cm·s)
      "dewPointTemperature": 10.5,      // °C
      "wetBulbTemperature": 12.3,       // °C
      "frictionHeight": 0.012,          // m
      "frictionVelocity": 0.234,        // m/s
      "horizontalVariation": 10.7,      // degrees (calculated if method ≠ 0)
      "dropletSizes": [17.831, ...],    // μm
      "nozzleVelocities": {
        "angles": [-40, -50, ...],      // degrees
        "verticalComponents": [...],    // m/s
        "horizontalComponents": [...]   // m/s
      }
    },
    "results": {
      "deposition": [
        [0.0, 95.234],      // [distance (m), %IAR]
        [0.5, 82.456],
        ...
      ]
    },
    "statistics": {
      "totalMass": 1.0,             // Conservation check
      "onFieldFraction": 0.85,      // Fraction deposited on field
      "offFieldFraction": 0.15,     // Fraction drifted off field
      "maxDriftDistance": 60.96     // m
    }
  }
}
```

### 5.2 Console Report Format

The console report provides a human-readable summary:

```
================================================================================
Casanova Drift Model (CDM) v1.2.0
================================================================================

Case: CaseName

INPUT PARAMETERS
--------------------------------------------------------------------------------
Atmospheric Conditions:
  Dry Air Temperature:      16.6 °C
  Barometric Pressure:      101325 Pa
  Relative Humidity:        67.1 %

Derived Atmospheric Properties:
  Wet Air Density:          0.001234 g/cm³
  Dynamic Viscosity:        0.0001789 g/(cm·s)
  Dew Point Temperature:    10.5 °C
  Wet Bulb Temperature:     12.3 °C

Wind Profile:
  Friction Height:          0.012 m
  Friction Velocity:        0.234 m/s
  Horizontal Variation:     10.7 degrees

Application Parameters:
  Nozzle Height:            0.8016 m
  Canopy Height:            0.15 m
  Nozzle Pressure:          250000 Pa
  Nozzle Angle:             110 degrees
  Application Rate:         0.83886 kg/ha

Field Geometry:
  Downwind Field Depth:     24.0 m
  Crosswind Field Width:    72.0 m
  Nozzle Spacing:           0.5 m

Deposition Parameters:
  Min Droplet Size:         17.831 μm
  Max Droplet Size:         600.0 μm
  Max Drift Distance:       60.96 m
  DSD Curve Fitting:        Enabled

RESULTS
--------------------------------------------------------------------------------
Total Segments:             192 (96 spray + 96 drift)
Volume Sprayed:             105.2 L
Volume Application Rate:    521.7 L/ha

Deposition Summary:
  On-Field Deposition:      85.2% of IAR
  Off-Field Drift:          14.8% of IAR
  Maximum Drift Distance:   60.96 m

Mass Balance:
  Total Recovered:          100.0%
  Error:                    0.0%

Integration Statistics:
  Average Steps/Droplet:    234
  Average Evaluations:      456
  Total Compute Time:       12.3 s

================================================================================
```

---

## 6. API Specifications

### 6.1 C API Functions

#### 6.1.1 cdm_create_model
```c
cdm_model_t* cdm_create_model(const char *config);
```

**Purpose:** Initialize a new CDM model from JSON configuration.

**Parameters:**
- `config`: Null-terminated JSON string containing model configuration

**Returns:**
- Pointer to opaque model structure on success
- NULL on failure (error reported through error handler)

**Errors:**
- Invalid JSON syntax
- Missing required parameters
- Parameter values out of range
- Memory allocation failure

#### 6.1.2 cdm_free_model
```c
void cdm_free_model(cdm_model_t *model);
```

**Purpose:** Free memory associated with a model.

**Parameters:**
- `model`: Model pointer returned by cdm_create_model

**Returns:** None

**Notes:**
- Safe to call with NULL pointer
- Model pointer is invalid after this call

#### 6.1.3 cdm_run_model
```c
int cdm_run_model(cdm_model_t *model);
```

**Purpose:** Execute the drift model simulation.

**Parameters:**
- `model`: Valid model pointer

**Returns:**
- 0 on success
- Non-zero error code on failure

**Errors:**
- Invalid model pointer
- Numerical integration failure
- Physical constraint violation

**Processing Steps:**
1. Calculate atmospheric properties
2. Characterize wind profile
3. Process droplet size distribution
4. Calculate nozzle velocities
5. For each streamline and droplet size:
   - Run transport simulation
   - Record drift distance
6. Calculate deposition profile
7. Generate output

#### 6.1.4 cdm_print_report
```c
void cdm_print_report(cdm_model_t *model);
```

**Purpose:** Print formatted report to stdout.

**Parameters:**
- `model`: Valid model pointer after successful run

**Returns:** None

**Notes:**
- Model must have been successfully executed
- Output format described in Section 5.2

#### 6.1.5 cdm_get_output_string
```c
char* cdm_get_output_string(cdm_model_t *model);
```

**Purpose:** Get JSON-formatted model results.

**Parameters:**
- `model`: Valid model pointer after successful run

**Returns:**
- Allocated string containing JSON output
- NULL on failure

**Notes:**
- Caller must free returned string using cdm_free_string
- Output format described in Section 5.1

#### 6.1.6 cdm_free_string
```c
void cdm_free_string(char *s);
```

**Purpose:** Free string allocated by CDM library.

**Parameters:**
- `s`: String pointer returned by CDM library function

**Returns:** None

#### 6.1.7 cdm_library_version
```c
const char* cdm_library_version(void);
```

**Purpose:** Get library version string.

**Parameters:** None

**Returns:** Static string containing version (e.g., "1.2.0")

#### 6.1.8 cdm_set_error_handler
```c
cdm_error_handler_t cdm_set_error_handler(cdm_error_handler_t handler);
```

**Purpose:** Set custom error handler function.

**Parameters:**
- `handler`: Function pointer with signature: `void (*)(const char *format, ...)`

**Returns:** Previous error handler

**Notes:**
- Default handler prints to stderr
- NULL handler disables error reporting
- Handler receives printf-style format string and arguments

### 6.2 C++ Internal API

The C++ implementation provides additional classes and functions not exposed in the C API:

- `cdm::Model`: Main model data structure
- `cdm::DropletTransport`: ODE integration for droplet trajectories
- `cdm::Deposition`: Deposition calculation algorithms
- `cdm::DropletSizeModel`: DSD curve fitting
- `cdm::AtmosphericProperties`: Psychrometric calculations
- `cdm::WindVelocityProfile`: Wind profile characterization
- `cdm::NozzleVelocity`: Initial velocity calculations

---

## 7. Integration Specifications

### 7.1 Command-Line Interface

**Executable:** `cdmcli` (Windows: `cdmcli.exe`)

**Usage:**
```bash
cdmcli [OPTIONS] input_file.json
```

**Options:**
- `-h, --help`: Show help message
- `-v, --version`: Show version information
- `-o, --output FILE`: Write JSON output to file
- `-q, --quiet`: Suppress console report
- `--report-only`: Print report without JSON output

**Exit Codes:**
- 0: Success
- 1: Invalid arguments
- 2: File I/O error
- 3: JSON parsing error
- 4: Model execution error

**Example:**
```bash
# Run model and display report
cdmcli tests/Case_B.json

# Run model and save JSON output
cdmcli tests/Case_B.json -o results.json

# Quiet mode with output file
cdmcli tests/Case_B.json -o results.json -q
```

### 7.2 R Package Interface

**Package Name:** `cdm`

**Installation:**
```r
install.packages("~/cdm/R/cdm", repos=NULL, type="source")
```

**Functions:**

#### cdm_run
```r
cdm_run(config_file)
```

**Parameters:**
- `config_file`: Path to JSON configuration file

**Returns:** List containing:
- `input`: Input parameters
- `derived`: Derived properties
- `results`: Deposition results
- `statistics`: Summary statistics

**Example:**
```r
library(cdm)
result <- cdm_run("tests/Case_B.json")
plot(result$results$deposition)
```

#### Demo Cases
```r
demo("caseB", package="cdm")
demo("caseG", package="cdm")
demo("caseI", package="cdm")
```

---

## 8. Performance Specifications

### 8.1 Computational Complexity

**Droplet Transport:**
- Per droplet-streamline: O(nsteps * neval)
- Total: O(NS * Ndp * nsteps * neval)
  - NS = 11 (streamlines)
  - Ndp ~ (dpmax - dpmin) / 0.5 (droplet size classes)
  - nsteps ~ 2000 (ODE steps)
  - neval ~ 5-10 (function evaluations per step)

**Deposition Calculation:**
- O(NS * Ndp * (Nsa + Nda))
- Typically: O(11 * 1000 * 200) = O(2.2M) operations

**Expected Runtime:**
- Typical case: 10-30 seconds on modern CPU
- Large cases: 30-60 seconds
- Parallel execution: Not currently implemented

### 8.2 Memory Requirements

**Static Allocation:**
- Model structure: ~10 KB
- DSD data: ~10 KB
- Wind profile: ~1 KB

**Dynamic Allocation:**
- Drift distance matrix: NS × Ndp × 8 bytes = ~88 KB
- Deposition matrices: 2 × Ndp × (Nsa+Nda) × 8 bytes = ~3.2 MB
- CVODE work arrays: ~100 KB per thread

**Total:** < 10 MB for typical simulation

### 8.3 Numerical Accuracy

**ODE Integration:**
- Relative tolerance: 1×10⁻⁴ (default)
- Absolute tolerances: 1×10⁻⁸ to 1×10⁻¹⁰
- Mass balance error: < 0.1%

**Interpolation:**
- Linear: Machine precision for in-range values
- Extrapolation: Warning issued, reduced accuracy

**Curve Fitting:**
- RMS error typically < 1% of cumulative volume

---

## 9. Error Handling

### 9.1 Error Categories

1. **Input Errors:** Invalid or missing parameters
2. **Numerical Errors:** Integration or optimization failures
3. **Physical Errors:** Constraint violations or unrealistic results
4. **System Errors:** Memory allocation or I/O failures

### 9.2 Error Reporting

Errors are reported through the error handler with messages including:
- Error category
- Location (function name, line number if available)
- Description of the problem
- Suggested corrective action (when applicable)

**Example Error Messages:**
```
ERROR: Invalid droplet size distribution
  Location: Serialization::parseJSON
  Problem: Diameters must be in ascending order
  Found: dp[5] = 100 μm, dp[6] = 90 μm
  Action: Check input file and correct droplet size order
```

---

## 10. Validation and Verification

### 10.1 Unit Testing
Individual components are tested with known inputs and expected outputs:
- Atmospheric property calculations against psychrometric charts
- Wind profile fitting against synthetic data
- ODE integration against analytical solutions
- Deposition calculation against mass balance

### 10.2 Integration Testing
Complete model runs are compared against:
- SETAC DRAW test cases
- Other validated drift models
- Field measurement data (when available)

### 10.3 Acceptance Criteria
A model run is considered successful when:
- All input validation passes
- No numerical errors occur during integration
- Mass balance is conserved within 1%
- Results satisfy physical constraints
- Output is generated in correct format

---

## 11. Revision History

| Version | Date | Author | Description |
|---------|------|--------|-------------|
| 1.0 | 2025-10-30 | CDM Team | Initial Functional Specification |

---

**End of Functional Specification**
