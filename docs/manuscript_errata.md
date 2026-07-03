# CDM Manuscript Draft — Errata Report

Compiled by comparing manuscript claims against CDM source code (v1.2.0).

---

## 1. Droplet Size Distribution

### Claim: Three options (extrapolation, normal, bimodal)

**Manuscript states:**
> "Users are provided with three options to incorporate drop size distribution into the model: (1) extrapolation, (2) normal, and (3) bimodal."

**Actual implementation:**
There are exactly **two** options, controlled by a single boolean `dsdCurveFitting` (Deposition.cpp):
1. **Bi-modal normal curve fitting** — non-linear least squares (Levenberg–Marquardt) with 5 parameters (μ₁, σ₁, μ₂, σ₂, w₁)
2. **Finite-difference approximation** — numerical derivative of interpolated CDF

There is no single-normal option anywhere in the code (DropletSizeModel.cpp only implements the bi-modal model).

### Claim: "Extrapolation" is the default and preferred method

**Manuscript states:**
> "The extrapolation method is the default and preferred method since it uses the actual data supplied by user."

**Actual implementation:**
- All three SETAC DRAW test cases set `"dsdCurveFitting": true` (bi-modal)
- The functional spec lists limitations of the finite-difference method: "Less smooth than curve fitting. Sensitive to noise in input data."
- The method is interpolation + finite differences, not "extrapolation" in the user-facing sense

---

## 2. Evaporation Equation

### Claim: Mole-fraction formulation with molecular weights

**Manuscript states:**
> `mw(t)/MWH2O / [mw(t)/MWH2O + mS/MWS]`

This is a mole fraction formulation (Raoult's law style).

**Actual implementation (DropletTransport.cpp line 64):**
```cpp
Mw / (Ms + Mw)
```
This is a **mass fraction** — no molecular weights (`MWH2O`, `MWS`) appear anywhere in CDM.

### Claim: Prefactor is π/4

**Manuscript states:**
> `dmw(t)/dt = -π/4 * λw * ...`

**Actual implementation:**
```cpp
(3. * pow(pi, 2./3.) / 2. / pow(6., 2./3.))
```
This equals 3π^(2/3) / (2·6^(2/3)) ≈ 1.209, not π/4 ≈ 0.785.

### Claim: λ_w = 76.80 mm²/(s·°C)

**Actual implementation (DropletTransport.cpp line 61):**
```cpp
const double lw = 76.4e-8; // Evaporation rate (λw), cm²/(s·°C)
```
- Wrong value: 76.80 vs 76.4
- Wrong unit: mm²/(s·°C) vs cm²/(s·°C) — these differ by a factor of 100

### Claim: Uses ρ_Soln (solution density)

**Actual implementation:**
The code uses `rhoW` (pure water density), not solution density.

### Claim: Equation is proportional to D(t) (diameter)

**Actual implementation:**
The diameter-equivalent term is `(Ms/rhoS + Mw/rhoW)^(1/3)` — the cube root of droplet volume, expressed through mass and density. The manuscript's formulation differs structurally.

---

## 3. Horizontal Wind Profile

### Claim: Raupach (1994) method

**Manuscript states:**
> "The CDM model uses a method described by Raupach (1994) to determine the horizontal wind velocity (Ux) v. elevation (Z) profile."

**Actual implementation:**
No reference to Raupach anywhere in code. CDM uses a simple log-law profile with empirical roughness length: `z₀ = 0.00341 + 0.1245*hC`.

### Claim: Cionco (1965) in-canopy profile

**Manuscript states:**
> "The profile shape is taken from Cionco (1965) dealing with a mature corn canopy."

**Actual implementation:**
No in-canopy wind model exists. No exponential decay profile, no canopy flow index (`aavg`), no `Uh` parameter. Grepping for "Cionco", "Raupach", "aavg", "displacement" returns zero relevant hits.

### Claim: Dual-zone wind profile (above/within canopy)

**Manuscript states:**
> `dUx/dZ = Uf/{0.40*(Z(t)-d)}` for Z ≥ z1, with a separate exponential form for Z < z1

**Actual implementation (DropletTransport.cpp line 83):**
```cpp
dVvwx = Z <= z0 ? 0. : Vz * (Uf/constants::karman) / (Z-hC);
```
Single-zone only. No transition elevation `z1`, no zero-plane displacement `d` (uses `hC` directly), no in-canopy equation.

### Claim: Parameters d, aavg, Uh, z1, κ-within-canopy

**Actual implementation:**
None of these parameters exist in Model.hpp or anywhere in the source. The only wind profile parameters are: `Uf`, `z₀`, `hC`, `κ = 0.40`.

### Claim: "Measurements at two to five heights"

**Actual implementation:**
CDM accepts ≥1 wind measurement. With one measurement it solves directly for Uf; with multiple it uses a simple summation ratio.

### Claim: Integration stops "just above z₀"

**Actual implementation (DropletTransport.cpp line 67):**
```cpp
if (Z <= z0 + hC) {
    std::fill_n(dxdt, 6, 0.);
}
```
Integration terminates at `z₀ + hC` (above canopy top), not "just above z₀."

---

## 4. Droplet Transport Equations

### Claim: Three initial vector velocities spanning nozzle spray shape

**Manuscript states:**
> "These calculations are done for three initial vector velocities of the droplet, spanning the nozzle spray shape. [...] This produces three vectors of downwind distance traveled to deposition vs initial droplet size."

**Actual implementation (Constants.hpp line 35, NozzleVelocity.cpp):**
```cpp
static constexpr size_t ns = 11;
```
CDM uses **11 streamlines** (at angles -40° to -140° in 10° increments), not three. The nozzle spray fan is discretized into `ns = 11` streamline segments. This produces an 11×23 drift distance matrix.

### Claim: Uz(z) — vertical wind velocity component

**Manuscript states:**
> `Uz(z)` appears throughout the momentum equations as a vertical wind component

**Actual implementation:**
CDM has **no vertical wind velocity**. The wind is purely horizontal (`Vvwx`). The relative velocity in the vertical direction is simply `-Vz` (droplet velocity only). In the code (line 78):
```cpp
dVz = ( pi * CD((rhoA * DD * abs(Vz)) / muA) * rhoA * pow(DD,2.) * (-Vz) * abs(-Vz) / 8.
      + Vz * W(Mw,Re) + VD * gc * (rhoA-(Mw+Ms)/VD) ) / (Mw+Ms);
```
The vertical drag uses `|Vz|` alone — no `Uz(z)` term.

### Claim: Drag coefficient from Bilanin et al. (1989)

**Manuscript states:**
> "where Cd is the drag coefficient (see Bilanin et al, 1989)"

**Actual implementation (DropletTransport.cpp line 56-57):**
```cpp
auto CD = [](double Re)
    { return 24. / Re * (1. + 0.197 * pow(Re, 0.63) + 0.00026 * pow(Re, 1.38)); };
```
This is the **Clift and Gauvin (1970)** correlation, not Bilanin et al. The specific coefficients (0.197, 0.63, 0.00026, 1.38) identify it uniquely.

### Claim: Momentum equations use d(md·V)/dt product rule form

**Manuscript states:**
> `d(md(t)*Vx(t))/dt = Σ Forces` and `d(md(t)*Vz(t))/dt = Σ Forces`

This implies expanding via product rule: `md·dV/dt + V·dmd/dt = ΣF`, where the `V·dmd/dt` term (evaporation thrust) must be handled explicitly.

**Actual implementation:**
The code does include an evaporation-thrust coupling term (`Vz * W` and `Vx * W` in lines 78-81), which is correct. However, the manuscript's simplified Equations 3-4:
```
dVz/dt = gc*(ρAir/ρLiq – 1) + 3/4*ρAir/ρLiq*{Cd/D}*[Uz-Vz]*|DV|
dVx/dt = 3/4*ρAir/ρLiq*{Cd/D}*[Ux-Vx]*|DV|
```
**omit the evaporation-thrust term entirely**, despite it being present in the code. The manuscript Equations 3-4 are inconsistent with the force balance stated just above them.

### Claim: Equations 3-4 use ρ_Air/ρ_Liq ratio form

**Manuscript states:**
> `dVz/dt = gc*(ρAir/ρLiq – 1) + 3/4*ρAir/ρLiq*{Cd(Red)/D(t)}*...`

**Actual implementation:**
The code divides by total mass `(Mw+Ms)`, not by `ρLiq*Volume`. While mathematically equivalent for a rigid sphere, the CDM formulation explicitly tracks changing mass due to evaporation:
```cpp
dVz = (...) / (Mw+Ms);
```
The manuscript's `ρAir/ρLiq` form implicitly assumes constant density, which contradicts the evaporating droplet model.

### Claim: Drag uses |DV| = √[(Ux-Vx)² + (Uz-Vz)²] for both components

**Manuscript states:**
> Both dVz and dVx use the full relative velocity magnitude for drag calculation.

**Actual implementation:**
The code computes drag for each direction using **separate Reynolds numbers**:
```cpp
// Vertical: uses Re based on |Vz| alone
CD((rhoA * DD * abs(Vz)) / muA) * ... * (-Vz) * abs(-Vz)

// Horizontal: uses Re based on |Vx - Vvwx| alone
CD((rhoA * DD * abs(Vx-Vvwx)) / muA) * ... * (-Vx+Vvwx) * abs(-Vx+Vvwx)
```
Each direction uses its own velocity component for both `CD(Re)` and the drag force magnitude — not the combined magnitude `|DV|`.

### Claim: Equations solved for "geometric progression of droplet sizes"

**Manuscript states:**
> "solved in time for a geometric progression of droplet sizes spanning the droplet size distribution"

**Actual implementation (CDM.cpp line 118):**
```cpp
m->dp[i] = m->dpmin * pow(m->dpmax/m->dpmin, i/22.);
```
This is correct — CDM does use 23 geometrically-spaced droplet sizes from dpmin to dpmax.

---

## 5. Deposition Calculation

### Claim: Drift segments equal to spray segments

**Manuscript states:**
> "The current model sets the number of segments in the drift part of the field equal to those in the sprayed field"

**Actual implementation (Deposition.cpp line 75):**
```cpp
size_t Nda = static_cast<size_t>(Nsa * lambda);
```
The number of drift segments is `Nsa × λ`, where λ is a user-controlled scale factor (default 1, but set to 4 in the SETAC test cases). So drift segments are typically **more** than spray segments, not equal to them.

### Claim: Drift segment width determined by "another algorithm which is user-changeable"

**Manuscript states:**
> "the width of the segments is chosen by another algorithm which is user-changeable"

**Actual implementation (Deposition.cpp lines 79-80):**
```cpp
const double dwsa = FD / Nsa;
const double dwda = dwsa; // previously Lmax / Nda
```
Drift segment width simply **equals** spray segment width. There is no separate algorithm. The comment "previously Lmax / Nda" suggests an older version had different logic, but current code uses `ΔWda = ΔWsa`.

### Claim: ψψψ equals "one sigma variation in wind direction"

**Manuscript states:**
> "The variation in horizontal wind direction (ΨΨΨ) is equal to one sigma variation in wind direction (degrees) around the average wind speed"

**Actual implementation (Constants.hpp line 32, Deposition.cpp):**
```cpp
static constexpr double zeta = 2.5;
```
The plume spreading formula uses `ψψψ × ζ` where ζ = 2.5. So the effective spreading angle is **2.5 times ψψψ**, not ψψψ directly. If ψψψ were one sigma, then the spreading uses 2.5σ. The manuscript conflates ψψψ with the actual spreading multiplier.

### Claim: "User can specify the drift distance of interest before calculations"

**Actual implementation:**
The `maxDriftDistance` (Lmax) parameter is optional. If not provided (Deposition.cpp line 68-69):
```cpp
if (!Lmax.has_value()) {
    Lmax = blaze::max(driftdist);
}
```
It defaults to the maximum distance from the drift distance matrix. The user can optionally constrain it but doesn't have to specify it "before."

---

## 6. Deposition Time as Output

### Claim (in original diagram): "Deposition time (seconds)" is a model output

**Actual implementation:**
`tmax = δ × hN / Vt` exists only as an internal integration time bound. `DropletTransport::operator()` returns only the final horizontal distance. The serialized JSON output (Serialization.cpp lines 109–125) contains no time values. CDM outputs are:
- Drift distance matrix (per streamline × droplet size)
- Ground deposition curve (% IAR vs distance)
- Derived properties (atmospheric, wind, nozzle velocities)

---

## Summary Table

| # | Section | Claim | Reality | Severity |
|---|---------|-------|---------|----------|
| 1 | DSD | Three options (extrapolation, normal, bimodal) | Two options (finite-diff, bi-modal) | Major |
| 2 | DSD | "Extrapolation" is default/preferred | Bi-modal is used in all test cases | Minor |
| 3 | DSD | "Normal" as separate option | Does not exist | Major |
| 4 | Evaporation | Mole fraction with MW_H2O, MW_S | Mass fraction Mw/(Ms+Mw) | Major |
| 5 | Evaporation | Prefactor π/4 | 3π^(2/3) / (2·6^(2/3)) | Major |
| 6 | Evaporation | λw = 76.80 mm²/(s·°C) | 76.4 × 10⁻⁸ cm²/(s·°C) | Major |
| 7 | Evaporation | Uses ρ_Soln | Uses ρ_W (pure water) | Moderate |
| 8 | Evaporation | Proportional to D(t) directly | Volume^(1/3) formulation | Moderate |
| 9 | Wind | Raupach (1994) method | Not used | Major |
| 10 | Wind | Cionco (1965) in-canopy profile | Does not exist in code | Major |
| 11 | Wind | Dual-zone (above/within canopy) | Single zone only | Major |
| 12 | Wind | Parameters d, aavg, Uh, z1 | None exist | Major |
| 13 | Wind | "Two to five heights" required | ≥1 accepted | Minor |
| 14 | Wind | Stops "just above z₀" | Stops at z₀ + hC | Moderate |
| 15 | Output | Deposition time is output | Not exported; internal variable only | Moderate |

---

## 7. Suggested Revised Text

### 7.1 Droplet Size Distribution (replaces Section 2.1)

> Droplet size distribution is a key input to the CDM and typically includes measurement of the cumulative volume of the spray for each droplet size. CDM requires this as an input for the tank mix, nozzle, and pressure combination for which spray drift needs to be simulated. Users are provided with two options to incorporate droplet size distribution into the model:
>
> 1. **Bi-modal normal curve fitting** (recommended): The cumulative volume fraction data is fitted to a mixture of two normal distributions using non-linear least squares optimization (Levenberg–Marquardt algorithm). The fitted model has five parameters: two location parameters (μ₁, μ₂), two scale parameters (σ₁, σ₂), and one mixing weight (w₁). This produces a smooth, differentiable probability density function with robust interpolation behaviour across the full droplet size range.
>
> 2. **Finite-difference approximation**: The input cumulative distribution data is interpolated directly using piecewise interpolation (with extrapolation at boundaries clamped to [0, 1]), and the probability density function is obtained by numerical differentiation. This method preserves the raw data without parametric assumptions but is more sensitive to noise and measurement gaps in the input distribution.
>
> The choice is controlled by the `dsdCurveFitting` boolean parameter in the input configuration.

### 7.2 Evaporation (replaces Section 2.2)

> Droplets generated by an agricultural spray nozzle are small, so they have enormous surface areas per unit volume and are thus subject to significant evaporation. The evaporation rate of water from the droplet is dictated by the rate of heat transfer from the surrounding air to the droplet surface. The primary driving force is the wet bulb temperature depression (ΔT_wb), the difference between the ambient dry air temperature and the wet bulb temperature. Turbulence around the droplet, characterized by the Reynolds number, enhances heat and mass transfer to a secondary extent.
>
> As droplets leave the spray nozzle, they cool by evaporation until reaching a quasi-steady wet bulb temperature, then continue to shrink under this driving force. Evaporation proceeds until the droplet contains only non-volatile solids or until it deposits on a surface. The size reduction decreases terminal velocity, so the horizontal wind carries smaller droplets further before deposition.
>
> The model tracks the mass of water in the droplet using the Ranz–Marshall mass transfer correlation (Holterman, 2003):
>
> $$\frac{dM_w}{dt} = -\frac{3\pi^{2/3}}{2 \cdot 6^{2/3}} \, \lambda_w \, \Delta T_{wb} \, \rho_W \left(\frac{M_s}{\rho_S} + \frac{M_w}{\rho_W}\right)^{1/3} \left(1 + 0.276 \sqrt{Re}\right) \frac{M_w}{M_s + M_w} \quad \text{(Eqn 1)}$$
>
> where:
> - $M_w$ = mass of water in the droplet [g]
> - $M_s$ = mass of dissolved solids in the droplet [g] (constant)
> - $\rho_W$ = density of pure water [g/cm³]
> - $\rho_S$ = density of dissolved solids [g/cm³]
> - $\lambda_w$ = 76.4 × 10⁻⁸ cm²/(s·°C), evaporation coefficient
> - $\Delta T_{wb}$ = wet bulb temperature depression [°C]
> - $Re$ = droplet Reynolds number
>
> The term $(M_s/\rho_S + M_w/\rho_W)^{1/3}$ is proportional to the instantaneous droplet diameter via the volume–diameter relationship. The mass fraction $M_w/(M_s + M_w)$ accounts for the reduced water activity as the droplet concentrates during evaporation.

### 7.3 Horizontal Wind Profile (replaces Section 2.3)

> The average horizontal wind velocity is a logarithmic function of height above the canopy. The CDM characterizes this profile from wind speed measurements at one or more heights above the sprayed field.
>
> The roughness length is computed empirically from canopy height:
>
> $$z_0 = 0.00341 + 0.1245 \, h_C$$
>
> The friction velocity $U_f$ is determined from measured wind speeds. For a single measurement at height $z_1$:
>
> $$U_f = \frac{u(z_1) \, \kappa}{\ln\left(\frac{z_1 - h_C}{z_0}\right)}$$
>
> For multiple measurements, friction velocity is computed as:
>
> $$U_f = \frac{\kappa \sum_{i} u_i}{\sum_{i} \ln(z_i / z_0)}$$
>
> Rather than evaluating the log-law profile at a fixed height, the CDM couples the wind velocity directly into the droplet transport ODE system as a state variable ($V_{vwx}$). Its rate of change with time is:
>
> $$\frac{dV_{vwx}}{dt} = \begin{cases} V_z \cdot \dfrac{U_f}{\kappa(Z - h_C)} & \text{if } Z > z_0 \\[6pt] 0 & \text{otherwise} \end{cases} \quad \text{(Eqn 2)}$$
>
> where $V_z$ is the droplet's vertical velocity and $Z$ is its instantaneous height. This formulation tracks the local wind velocity experienced by the droplet along its actual trajectory, accounting for the increasing wind speed encountered as the droplet moves through different heights during its descent.
>
> Integration terminates when the droplet reaches the canopy surface ($Z \leq z_0 + h_C$). The model assumes all spray droplets eventually deposit on a surface below; no in-canopy wind profile or canopy interception is modeled. From a drift standpoint this represents a conservative (worst-case) assumption, since in practice some droplets deposit on crop leaves before reaching downwind positions.

### 7.4 Droplet Transport (replaces Section 2.4)

> The CDM simulates the Lagrangian transport of spray droplets through the atmosphere by solving a system of six coupled ordinary differential equations (ODEs) for each combination of droplet size and streamline angle.
>
> **Nozzle exit velocity.** The initial droplet speed is computed from the nozzle pressure using Bernoulli's equation:
>
> $$v_i = \sqrt{\frac{2 P_N}{\rho_L}}$$
>
> where $P_N$ is nozzle pressure [Pa] and $\rho_L$ is solution density [kg/m³]. The spray fan (total angle $\theta$) is discretized into 11 streamline segments at angles from $-\alpha - \Delta\theta/2$ to $-\alpha - 10.5\Delta\theta$, where $\alpha = (180° - \theta)/2$ and $\Delta\theta = \theta/11$. For each streamline $i$:
>
> $$V_{z,0}^{(i)} = v_i \sin\theta_i, \qquad V_{x,0}^{(i)} = v_i \cos\theta_i$$
>
> **State vector.** Each droplet trajectory is described by the state vector $\mathbf{y} = [Z, X, V_z, V_x, M_w, V_{vwx}]^\top$ representing vertical position, horizontal position, vertical velocity, horizontal velocity, water mass, and local horizontal wind velocity.
>
> **Governing equations:**
>
> $$\frac{dZ}{dt} = V_z \quad \text{(Eqn 5)}$$
>
> $$\frac{dX}{dt} = V_x \quad \text{(Eqn 6)}$$
>
> $$\frac{dV_z}{dt} = \frac{1}{M_w + M_s}\left[\frac{\pi}{8} C_D(Re_z) \, \rho_A \, D^2 \, (-V_z)|V_z| \;+\; V_z \cdot W \;+\; V_D \, g \left(\rho_A - \frac{M_w + M_s}{V_D}\right)\right] \quad \text{(Eqn 3)}$$
>
> $$\frac{dV_x}{dt} = \frac{1}{M_w + M_s}\left[\frac{\pi}{8} C_D(Re_x) \, \rho_A \, D^2 \, (V_{vwx} - V_x)|V_{vwx} - V_x| \;+\; V_x \cdot W\right] \quad \text{(Eqn 4)}$$
>
> where:
> - $D = (6V_D/\pi)^{1/3}$ is instantaneous droplet diameter
> - $V_D = M_w/\rho_W + M_s/\rho_S$ is droplet volume
> - $W$ is the evaporation rate (Eqn 1)
> - $Re_z = \rho_A D |V_z| / \mu_A$ and $Re_x = \rho_A D |V_x - V_{vwx}| / \mu_A$
> - The term $V_z \cdot W$ (and $V_x \cdot W$) is the evaporation-thrust coupling arising from the product rule expansion of $d(m \cdot V)/dt$
>
> **Drag coefficient** (Clift and Gauvin, 1970):
>
> $$C_D(Re) = \frac{24}{Re}\left(1 + 0.197 \, Re^{0.63} + 2.6 \times 10^{-4} \, Re^{1.38}\right)$$
>
> Note that the CDM evaluates drag in each direction using separate Reynolds numbers based on the velocity component in that direction, rather than using the full velocity magnitude for both.
>
> **Wind coupling** (Eqn 2) and **evaporation** (Eqn 1) complete the six-equation system, which is integrated using the CVODE solver (SUNDIALS, BDF method up to order 5) with 10,000 output time steps per trajectory. Integration proceeds until the droplet reaches the canopy surface ($Z \leq z_0 + h_C$).
>
> The transport is computed for 23 geometrically-spaced droplet sizes spanning the DSD range ($d_{p,\min}$ to $d_{p,\max}$) across all 11 streamlines, producing an 11×23 drift distance matrix.

### 7.5 Deposition Calculation (replaces Section 2.5)

> The deposition calculation converts the drift distance matrix into a spatial profile of spray deposition expressed as percentage of the intended application rate (% IAR).
>
> **Segment discretization.** The sprayed field is divided into horizontal segments perpendicular to the mean wind direction. The number of spray segments equals the number of nozzle positions along the field depth:
>
> $$N_{sa} = F_D / d_N$$
>
> where $F_D$ is downwind field depth and $d_N$ is nozzle spacing. Spray segment width is $\Delta W_{sa} = F_D / N_{sa}$. Beyond the field edge, drift segments are created with the same width ($\Delta W_{da} = \Delta W_{sa}$) and their count is controlled by a scale factor:
>
> $$N_{da} = \lambda \cdot N_{sa}$$
>
> where $\lambda \geq 1$ (default 1; typically set to 4 in practice to provide adequate downwind resolution). The maximum drift distance ($L_{\max}$) may be specified by the user or defaults to the maximum distance from the drift distance matrix.
>
> **Volume distribution.** For each spray segment, the sprayed volume is distributed across droplet size classes using the probability density function from the DSD model. The partial volume for size class $i$ is:
>
> $$SVP_i = f(d_{p,i}) \cdot \Delta d_p \cdot V_{sprayed} / N_{sa}$$
>
> where $\Delta d_p = 0.5$ μm and $V_{sprayed} = IAR \cdot A / (\rho_L \cdot x_{active})$.
>
> **Plume spreading.** The deposited volumes are converted to concentrations by accounting for crosswind plume spreading due to turbulence. The effective crosswind width at distance $x$ is:
>
> $$W(x) = P_L + 2 \, x \cdot \tan(\psi\psi\psi \cdot \zeta)$$
>
> where $P_L$ is the physical crosswind field width, $\psi\psi\psi$ is the horizontal variation in wind direction (degrees), and $\zeta = 2.5$ is the spreading multiplier. The concentration in each segment is:
>
> $$CM_{i,j} = \sum_{n=0}^{N_s - 1} \frac{SVP_i / N_s}{\Delta W_j \cdot W(x_j)}$$
>
> The final deposition profile is obtained by summing over all droplet sizes and normalizing to the intended application rate, expressed as % IAR at each distance interval.
>
> The deposition calculation does not model canopy interception or filtering of droplets by downwind vegetation. From a drift perspective, this provides a conservative estimate since some fraction of the spray would in practice be captured by crop canopy before reaching downwind positions.

---

## Summary Table

| # | Section | Claim | Reality | Severity |
|---|---------|-------|---------|----------|
| 1 | DSD | Three options (extrapolation, normal, bimodal) | Two options (finite-diff, bi-modal) | Major |
| 2 | DSD | "Extrapolation" is default/preferred | Bi-modal is used in all test cases | Minor |
| 3 | DSD | "Normal" as separate option | Does not exist | Major |
| 4 | Evaporation | Mole fraction with MW_H2O, MW_S | Mass fraction Mw/(Ms+Mw) | Major |
| 5 | Evaporation | Prefactor π/4 | 3π^(2/3) / (2·6^(2/3)) | Major |
| 6 | Evaporation | λw = 76.80 mm²/(s·°C) | 76.4 × 10⁻⁸ cm²/(s·°C) | Major |
| 7 | Evaporation | Uses ρ_Soln | Uses ρ_W (pure water) | Moderate |
| 8 | Evaporation | Proportional to D(t) directly | Volume^(1/3) formulation | Moderate |
| 9 | Wind | Raupach (1994) method | Not used | Major |
| 10 | Wind | Cionco (1965) in-canopy profile | Does not exist in code | Major |
| 11 | Wind | Dual-zone (above/within canopy) | Single zone only | Major |
| 12 | Wind | Parameters d, aavg, Uh, z1 | None exist | Major |
| 13 | Wind | "Two to five heights" required | ≥1 accepted | Minor |
| 14 | Wind | Stops "just above z₀" | Stops at z₀ + hC | Moderate |
| 15 | Output | Deposition time is output | Not exported; internal variable only | Moderate |
| 16 | Transport | Three streamline velocities | 11 streamlines | Major |
| 17 | Transport | Uz(z) vertical wind component | No vertical wind in CDM | Major |
| 18 | Transport | Drag from Bilanin et al. (1989) | Clift & Gauvin (1970) | Major |
| 19 | Transport | Eqns 3-4 omit evaporation thrust | Code includes V·W term | Major |
| 20 | Transport | ρ_Air/ρ_Liq ratio form | Divides by (Mw+Ms) | Moderate |
| 21 | Transport | Drag uses combined |DV| for both axes | Separate Re per axis | Major |
| 22 | Deposition | Drift segments = spray segments | Nda = Nsa × λ (typically 4×) | Moderate |
| 23 | Deposition | Drift width from "another algorithm" | Equals spray segment width | Minor |
| 24 | Deposition | ψψψ = one sigma | Spreading = ψψψ × 2.5 | Moderate |
| 25 | Deposition | Must specify drift distance first | Optional; auto-defaults | Minor |

---

## Notes

- Source verified against: CDM v1.2.0, commit 3241cec
- Files examined: DropletTransport.cpp, Deposition.cpp, DropletSizeModel.cpp, WindVelocityProfile.cpp, AtmosphericProperties.cpp, CDM.cpp, Serialization.cpp, Model.hpp, Constants.hpp
- It is possible the manuscript describes a prior or planned version of CDM that differs from the current implementation. The errata above reflect the code as it exists.
