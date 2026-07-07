# CDM Model Description — Revised Manuscript Text

## Proposed Structure

The original manuscript order (DSD → evaporation → wind → transport → deposition) mixes input processing with physics. The revised order follows the actual computation flow: inputs are processed first, then the physics is described as one integrated system, and finally the deposition accounting.

```
2.1  Inputs and derived atmospheric properties
2.2  Wind velocity profile
2.3  Droplet size distribution
2.4  Nozzle geometry and initial conditions
2.5  Droplet transport equations
2.6  Deposition calculation
```

---

## 2.1 Inputs and Derived Atmospheric Properties

The CDM requires three categories of measured input: atmospheric conditions, wind measurements, and application equipment parameters. From the atmospheric inputs, the model derives several physical properties needed by the transport equations.

**Measured inputs.** The user supplies dry air temperature $T$ (°C), barometric pressure $P$ (Pa), and relative humidity $RH$ (%). From these, the model computes:

**Wet air density.** The density of moist air is calculated from the ideal gas law, treating moist air as a mixture weighted by the vapour mole fraction:

$$\rho_A = \frac{M_w \, x_v + M_a \, (1 - x_v)}{R \, (T + 273.15)}$$

where $M_w$ = 18.015 g/mol (water), $M_a$ = 28.851 g/mol (air), $R$ = 82.06 cm³·atm·mol⁻¹·K⁻¹ (universal gas constant), and $x_v$ is the mole fraction of water vapour obtained from relative humidity and the Antoine equation for saturation vapour pressure.

**Dynamic viscosity.** The viscosity of moist air is approximated by a linear correlation:

$$\mu_A = K_0 + K_1 T + K_2 P_v$$

with empirically determined constants ($K_0 = 1.765 \times 10^{-4}$, $K_1 = 4.752 \times 10^{-7}$, $K_2 = -1.478 \times 10^{-4}$) [g cm⁻¹ s⁻¹].

**Wet bulb temperature.** The wet bulb temperature $T_{wb}$ is found by iteratively solving the psychrometric equation that balances heat transfer to the droplet surface against latent heat of evaporation. The CDM uses the TOMS 748 root-finding algorithm for this calculation. The wet bulb temperature depression, which drives evaporation, is then:

$$\Delta T_{wb} = T - T_{wb}$$

This quantity represents the maximum cooling a water surface can achieve by evaporation under the given atmospheric conditions. A larger depression means drier air and faster evaporation.

---

## 2.2 Wind Velocity Profile

The horizontal wind velocity above a crop canopy follows a logarithmic profile. The CDM characterizes this profile from wind speed measurements at one or more heights above the field.

**Roughness length.** The aerodynamic roughness length is estimated from canopy height:

$$z_0 = 0.00341 + 0.1245 \, h_C$$

**Friction velocity.** For a single wind measurement at height $z_1$:

$$U_f = \frac{u(z_1) \, \kappa}{\ln\left(\frac{z_1 - h_C}{z_0}\right)}$$

where $\kappa = 0.40$ is the von Kármán constant. When multiple measurements are available, friction velocity is computed from the collective fit.

**Coupling to droplet motion.** Rather than evaluating the wind profile at fixed heights, the CDM tracks the local wind velocity as a state variable within the transport equations (Section 2.5). This ensures each droplet experiences the correct wind speed at every point along its trajectory.

**Horizontal wind direction variation (ψψψ).** The variability of wind direction during a spray application determines how much the drift plume spreads crosswind. The CDM provides three options:

1. User enters the value directly from field measurements.
2. Interpolation from a lookup table relating wind direction variability to the Richardson number (atmospheric stability).
3. SDTF empirical formula based on canopy height and stability: $\psi\psi\psi = 0.524 \, h_C + 69.398 \, |Ri|$

The Richardson number characterizes atmospheric stability from the ratio of thermal buoyancy to wind shear, computed from temperature and wind speed at two or more heights.

---

## 2.3 Droplet Size Distribution

The droplet size distribution (DSD) describes the range of droplet sizes produced by a given nozzle, pressure, and tank-mix combination. The CDM accepts this as measured cumulative volume fractions at discrete droplet diameters.

The model provides two methods to convert the measured CDF into the probability density function (PDF) required for deposition calculations:

1. **Bi-modal normal curve fitting** (recommended): The cumulative distribution is fitted to a mixture of two normal distributions with five parameters — two means (μ₁, μ₂), two standard deviations (σ₁, σ₂), and a mixing weight (w₁). The fit uses non-linear least squares optimization (Levenberg–Marquardt algorithm). This produces a smooth PDF that interpolates well across the full size range.

2. **Finite-difference approximation**: The measured CDF is interpolated directly and the PDF is obtained by numerical differentiation. This preserves the raw data without parametric assumptions but is sensitive to noise and gaps in measurements.

From the fitted or interpolated DSD, the model evaluates 23 representative droplet diameters in geometric progression from the minimum to maximum size:

$$d_{p,i} = d_{p,\min} \cdot \left(\frac{d_{p,\max}}{d_{p,\min}}\right)^{i/22}, \quad i = 0, 1, \ldots, 22$$

These 23 sizes are used as starting diameters for the transport simulations.

---

## 2.4 Nozzle Geometry and Initial Conditions

**Spray exit velocity.** The velocity of liquid leaving the nozzle is computed from the nozzle pressure using Bernoulli's equation:

$$v_i = \sqrt{\frac{2 P_N}{\rho_L}}$$

where $P_N$ is nozzle gauge pressure and $\rho_L$ is the density of the spray solution.

**Streamline discretization.** The flat-fan spray sheet (total spray angle $\theta$) is divided into 11 equally-spaced streamlines. Each streamline represents a different ejection angle within the spray fan, ranging from the leading edge to the trailing edge. For streamline $n$:

$$\theta_n = -\frac{180° - \theta}{2} - \frac{\theta}{22} - n \cdot \frac{\theta}{11}$$

$$V_{z,0} = v_i \sin\theta_n, \qquad V_{x,0} = v_i \cos\theta_n$$

**Liquid sheet offset.** Droplets do not form immediately at the nozzle orifice — they break away from the liquid sheet approximately 0.10 m below the nozzle tip. The effective release height is therefore:

$$Z(0) = h_N - 0.1016$$

**Droplet mass.** The initial water and solids mass in a droplet of diameter $d_p$ are:

$$M_w(0) = \frac{\pi}{6} d_p^3 \, \frac{1 - x_s}{x_s/\rho_S + (1 - x_s)/\rho_W}$$

$$M_s = \frac{\pi}{6} d_p^3 \, \frac{x_s}{x_s/\rho_S + (1 - x_s)/\rho_W}$$

where $x_s$ is the mass fraction of dissolved solids in the tank solution. The solids mass remains constant throughout transport; only water evaporates.

**Initial wind velocity.** The local horizontal wind speed at the release height is:

$$V_{vwx}(0) = \frac{U_f}{\kappa} \ln\frac{Z(0) - h_C}{z_0}$$

---

## 2.5 Droplet Transport Equations

The trajectory of each droplet is governed by a system of six coupled ordinary differential equations (ODEs) solved in time. The state vector tracks position, velocity, water mass, and local wind:

$$\mathbf{y} = [Z, \; X, \; V_z, \; V_x, \; M_w, \; V_{vwx}]^\top$$

**Position:**

$$\frac{dZ}{dt} = V_z \qquad \frac{dX}{dt} = V_x$$

**Vertical acceleration** (gravity, buoyancy, drag, and evaporation coupling):

$$\frac{dV_z}{dt} = \frac{1}{M_w + M_s}\left[\frac{\pi}{8} C_D(Re_z) \, \rho_A \, D^2 \, (-V_z)|V_z| \;+\; V_z \cdot W \;+\; V_D \, g \left(\rho_A - \frac{M_w + M_s}{V_D}\right)\right]$$

The first term is aerodynamic drag opposing vertical motion. The second term ($V_z \cdot W$) arises from the product rule when differentiating momentum of a mass-losing droplet. The third term is the net gravitational force (weight minus buoyancy).

**Horizontal acceleration** (wind drag and evaporation coupling):

$$\frac{dV_x}{dt} = \frac{1}{M_w + M_s}\left[\frac{\pi}{8} C_D(Re_x) \, \rho_A \, D^2 \, (V_{vwx} - V_x)|V_{vwx} - V_x| \;+\; V_x \cdot W\right]$$

Wind drag accelerates the droplet toward the local wind speed. This term is set to zero if $V_{vwx} \leq 0$ (no wind or reverse wind).

**Evaporation** (Ranz–Marshall mass transfer):

$$\frac{dM_w}{dt} = -\frac{3\pi^{2/3}}{2 \cdot 6^{2/3}} \, \lambda_w \, \Delta T_{wb} \, \rho_W \left(\frac{M_s}{\rho_S} + \frac{M_w}{\rho_W}\right)^{1/3} \left(1 + 0.276 \sqrt{Re}\right) \frac{M_w}{M_s + M_w}$$

where $\lambda_w = 76.4 \times 10^{-8}$ cm²/(s·°C). Evaporation shrinks the droplet, reducing its terminal velocity and allowing wind to carry it further. The mass fraction term causes evaporation to slow as the droplet concentrates.

**Wind velocity tracking:**

$$\frac{dV_{vwx}}{dt} = \begin{cases} V_z \cdot \dfrac{U_f}{\kappa(Z - h_C)} & \text{if } Z > z_0 \\ 0 & \text{otherwise} \end{cases}$$

As the droplet descends ($V_z < 0$), the local wind velocity it experiences decreases because wind speed decreases closer to the ground. This coupling captures the continuous change in wind forcing along the droplet's actual path.

**Auxiliary quantities:**

$$V_D = \frac{M_w}{\rho_W} + \frac{M_s}{\rho_S} \qquad D = \left(\frac{6 V_D}{\pi}\right)^{1/3} \qquad Re_z = \frac{\rho_A D |V_z|}{\mu_A} \qquad Re_x = \frac{\rho_A D |V_x - V_{vwx}|}{\mu_A}$$

**Drag coefficient** (Clift and Gauvin, 1970):

$$C_D(Re) = \frac{24}{Re}\left(1 + 0.197 \, Re^{0.63} + 2.6 \times 10^{-4} \, Re^{1.38}\right)$$

Note that drag is evaluated independently in each direction using the velocity component in that direction, rather than using the combined velocity magnitude.

**Terminal velocity.** Before integration begins, the terminal settling velocity of each droplet is estimated by iteratively solving:

$$V_t = \sqrt{\frac{4 \, d_p \, g \, (\rho_L - \rho_A)}{3 \, \rho_A \, C_D(Re_t)}}$$

This is used to set the maximum integration time: $t_{\max} = 60 \cdot h_N / V_t$, providing ample time for even the smallest droplets to reach the ground.

**Numerical solution.** The ODE system is integrated using CVODE from the SUNDIALS library, with a backward differentiation formula (BDF) method suitable for stiff systems. Relative tolerance is $10^{-4}$ and absolute tolerances are set individually for each state component. Integration terminates when the droplet reaches the canopy surface ($Z \leq z_0 + h_C$).

**Drift distance matrix.** The transport simulation is repeated for each of the 23 droplet sizes across all 11 streamlines. The final horizontal position of each droplet forms an 11×23 drift distance matrix — the fundamental intermediate result connecting the transport physics to the deposition calculation.

**Assumptions.** The model assumes all droplets eventually reach the ground or canopy surface. No in-canopy interception or filtering is modeled. This represents a conservative (worst-case) assumption for drift prediction, since in practice some droplets deposit on crop leaves within the field.

---

## 2.6 Deposition Calculation

The deposition module converts the drift distance matrix into a spatial profile of ground-level spray deposition, expressed as a percentage of the intended application rate (% IAR) at each downwind distance.

**Field segmentation.** The sprayed field (depth $F_D$, width $P_L$) is divided into segments perpendicular to the wind direction. The number of spray segments equals the number of nozzle positions:

$$N_{sa} = F_D / d_N$$

where $d_N$ is nozzle spacing. Each spray segment has width $\Delta W = F_D / N_{sa}$. Beyond the field edge, drift segments of the same width extend downwind:

$$N_{da} = \lambda \cdot N_{sa}$$

where $\lambda$ is a user-specified scale factor ($\lambda \geq 1$; typically 4) controlling the resolution and extent of drift-field coverage.

**Volume distribution.** For each spray segment, the total sprayed volume is partitioned across droplet size classes according to the DSD probability density:

$$SVP_i = f(d_{p,i}) \cdot \Delta d_p \cdot \frac{V_{sprayed}}{N_{sa}}$$

where $\Delta d_p = 0.5$ μm and $V_{sprayed}$ is the total volume sprayed. Using the drift distance matrix (interpolated to fine 0.5-μm resolution), the model determines which segment each droplet from each spray position lands in, building a deposited volume matrix (DVM).

**Plume spreading.** Turbulent variation in wind direction causes the drift plume to spread crosswind. The effective width of the plume at downwind distance $x$ is:

$$W(x) = P_L + 2 \, x \cdot \tan(\psi\psi\psi \cdot \zeta)$$

where $\zeta = 2.5$ is a one-sigma multiplier. This converts the deposited volumes to concentrations by distributing them over the widened plume at each distance.

**Output.** The concentration matrix is summed over all droplet sizes and normalized to the intended application rate. The result is a deposition profile — percent of applied spray deposited per unit ground area as a function of downwind distance — reported at user-specified distance intervals (default 0.5 m). The maximum drift distance is either user-specified or defaults to the furthest distance reached by any modeled droplet.

---

## Symbol Table

| Symbol | Definition | Unit |
|--------|-----------|------|
| $T$ | Dry air temperature | °C |
| $P$ | Barometric pressure | Pa |
| $RH$ | Relative humidity | % |
| $\rho_A$ | Wet air density | g/cm³ |
| $\mu_A$ | Dynamic viscosity of wet air | g cm⁻¹ s⁻¹ |
| $\Delta T_{wb}$ | Wet bulb temperature depression | °C |
| $U_f$ | Friction velocity | m/s |
| $z_0$ | Roughness length | m |
| $h_C$ | Canopy height | m |
| $h_N$ | Nozzle height above ground | m |
| $\kappa$ | von Kármán constant (0.40) | — |
| $P_N$ | Nozzle pressure | Pa |
| $\theta$ | Nozzle spray angle | degrees |
| $\rho_L$ | Spray solution density | g/cm³ |
| $\rho_W$ | Pure water density | g/cm³ |
| $\rho_S$ | Dissolved solids density | g/cm³ |
| $x_s$ | Mass fraction of solids in solution | — |
| $M_w$ | Mass of water in droplet | g |
| $M_s$ | Mass of solids in droplet (constant) | g |
| $D$ | Instantaneous droplet diameter | cm |
| $V_D$ | Droplet volume | cm³ |
| $\lambda_w$ | Evaporation coefficient (76.4 × 10⁻⁸) | cm²/(s·°C) |
| $g$ | Gravitational acceleration (980.7) | cm/s² |
| $\psi\psi\psi$ | Horizontal wind direction variation | degrees |
| $\zeta$ | Spreading multiplier (2.5) | — |
| $\lambda$ | Drift segment scale factor | — |
| $F_D$ | Downwind field depth | m |
| $P_L$ | Crosswind field width | m |
| $d_N$ | Nozzle spacing | m |
| $IAR$ | Intended application rate | kg/ha |
