# driftml ↔ SETAC Case Harmonization Guide

**Purpose:** Define how to map CDM SETAC test inputs to driftml OpenFOAM parameters for a targeted CFD cross-check (assessment Option B).  
**Status:** Reference protocol — not validated end-to-end in CDM CI.  
**Primary example:** SETAC DRAW Case B ([tests/Case_B.json](../tests/Case_B.json))

---

## 1. Geometry mismatch (fundamental)

| Feature | CDM Case B | driftml wind tunnel |
|---------|------------|---------------------|
| Setting | Field application | ISO 22856-style wind tunnel |
| Ground | Crop canopy (hC = 0.15 m) | Flat floor, y = 0 |
| Nozzle height | 0.8016 m AGL | 0.6 m (hard-coded in `CaseMaker.py`) |
| Domain | FD = 24 m, PL = 72 m field | 7 × 2 m tunnel, 6 × 2 m collector |
| Wind | Log-profile from measurement at z = 2 m | Uniform inlet `Uwind` at angle `alpha` |
| Plume spreading | ψψψ = 10.7° crosswind | None (2D rotated domain) |
| Nozzle | AXI 11002, Bernoulli from 250 kPa | ALBUZ ATR80, cone injection, fixed `U0` |
| DSD | Measured 23-point CDF | Rosin–Rammler in `kinematicCloudProperties` |
| Mass accounting | % IAR (kg/ha applied) | % of injection mass (0.095 kg total) |

**Implication:** A quantitative match is not expected. Comparisons are **qualitative** (deposition peak location, downwind decay shape) after harmonizing what can be aligned.

---

## 2. Parameter mapping table (Case B → driftml)

### 2.1 Direct or approximate mappings

| CDM field (Case B) | Value | driftml parameter | Suggested harmonized value | Notes |
|--------------------|-------|-------------------|---------------------------|-------|
| `windVelocityProfile.velocityMeasurements[0][1]` | 2.436 m/s at z = 2 m | `Uwind` | **2.44** | driftml uses uniform inlet; CDM uses log-profile. Compare at nozzle height only as rough guide. |
| `windVelocityProfile` wind direction | Assumed aligned with downwind axis | `alpha` | **0** | driftml rotates domain; CDM has no crosswind inlet angle in Case B. |
| `dropletTransport.nozzleHeight` | 0.8016 m | nozzle height in `CaseMaker.py` | **0.80** | Edit `self.nozzle_height = 0.6` → `0.80` in `CaseMaker.py`. |
| `dropletTransport.nozzleAngle` | 110° (fan angle) | `theta`, `phi` | **theta = 90**, **phi = 90** | driftml: polar/azimuth of injection vector. CDM: fan half-angle from vertical via Bernoulli streamlines. See §2.3. |
| `dropletTransport.nozzlePressure` | 250000 Pa | `U0` | **~12–15 m/s** (estimate) | driftml sets exit speed directly; CDM: vi = √(2·PN/ρL) ≈ 22 m/s for ρL ≈ 1 g/cm³. Use CDM `NozzleVelocity` center streamline or reduce to match mass flux. |
| `dryAirTemperature` | 16.6 °C | `transportProperties` / `T` in OpenFOAM | **289.75 K** | driftml case may use defaults; set explicitly for evaporation parity. |
| `relativeHumidity` | 67.1 % | vapour mass fraction in `0/U.air` or `transportProperties` | Derive x_v from RH, T, P | Not wired in driftml pipeline; manual OpenFOAM edit. |
| `barometricPressure` | 101325 Pa | `p` boundary / thermo | **101325 Pa** | Standard unless altitude correction needed. |

### 2.2 No direct mapping (document divergence)

| CDM field | Case B value | driftml handling |
|-----------|--------------|------------------|
| `dropletSizeDistribution` | 23-point measured CDF | Rosin–Rammler (d ≈ 0.3 mm, spread n ≈ 2.4–3 in `kinematicCloudProperties`) |
| `deposition.applicationRate` | 0.839 kg/ha | `massTotal = 0.095` kg over 3 s injection |
| `deposition.downwindFieldDepth` | 24 m | Collector grid 6 m downwind |
| `deposition.lambda` | 4 | N/A |
| `windVelocityProfile.horizontalVariation` | 10.7° | N/A |
| `dropletTransport.canopyHeight` | 0.15 m | N/A (flat floor) |
| Nozzle type | AXI 11002 | ALBUZ ATR80 |

### 2.3 Nozzle angle convention

**CDM** (`NozzleVelocity.cpp`): fan angle θ = 110° defines spray cone; exit speed from Bernoulli at pressure PN; 11 streamlines from −40° to −140° from horizontal.

**driftml** (`CaseMaker.py`): injection direction from rotations of base vector `(0, 1, 0)` by polar `theta` and azimuth `phi` (degrees). Default test row: `theta=90, phi=90` → downward-ish spray in rotated frame.

**Harmonization approach:**

1. Run CDM Case B and record center streamline exit angle and speed from output (or compute: vi ≈ 22.4 m/s, center angle ≈ −90° from horizontal for θ = 110°).
2. Set driftml `U0` to center-streamline speed.
3. Set driftml `theta`/`phi` so `inj_dir` matches CDM center streamline in the tunnel coordinate system (requires checking `CaseMaker.py` rotation order).

---

## 3. Output normalization for comparison

### 3.1 driftml ground deposition

- Source: `particleCollector` → `bin_0` per grid cell (`CaseProcessor.py`)
- Units: mass fraction of total injection per cell per timestep
- Steady-state snapshot: t = 19 s (per driftml `dataprocessing.py` convention)

**Convert to 1D downwind curve:**

1. Sum deposition over crosswind (z) dimension at each downwind (x) index.
2. Integrate or sum to cumulative % of injected mass vs downwind distance.
3. Normalize to peak or total drift mass for shape comparison.

### 3.2 CDM ground deposition

- Source: `output.deposition` → `[distance_m, pctIAR]` from field edge (d = 0)
- Units: % of intended application rate

**Comparison metrics (qualitative):**

| Metric | CDM | driftml (post-processed) |
|--------|-----|---------------------------|
| Peak downwind deposition | `max(applume)` at distance d* | max of integrated 1D curve |
| Distance to peak | d* from field edge | x* from nozzle (offset by tunnel geometry) |
| Far-field decay | applume at d = 30, 50 m | integrated curve at collector extent (~6 m) |

**Do not** directly compare % IAR to % injection volume without mass-balance conversion.

### 3.3 Suggested comparison script workflow

```
1. Run CDM:  cdmcli -i tests/Case_B.json -o case_b_cdm.json
2. Harmonize driftml run_list.csv row (see §4)
3. Run driftml Nextflow pipeline (requires OpenFOAM)
4. Post-process .npy → 1D integrated curve (external)
5. Plot both curves with documented offsets and normalization
6. Attribute discrepancies using §1 geometry table
```

---

## 4. Example harmonized driftml `run_list.csv` row (Case B inspired)

Starting from driftml default; values marked with `*` need `CaseMaker.py` edits or OpenFOAM constant changes.

```csv
run,theta,U0,Uwind,xgrid,zgrid,note,write interval,duration,alpha,phi
case_b,90,22.4,2.44,60,20,SETAC_Case_B_harmonized,0.25,20,0,90
```

| Column | Value | Rationale |
|--------|-------|-----------|
| `U0` | 22.4 | Bernoulli estimate from 250 kPa, ρL ≈ 1 g/cm³ |
| `Uwind` | 2.44 | Case B wind at 2 m |
| `alpha` | 0 | Aligned flow |
| `duration` | 20 | Allow settling (driftml default 5 s may be short) |
| `xgrid` | 60 | Finer downwind resolution over 6 m collector |
| `zgrid` | 20 | Crosswind resolution |

**Additional manual steps:**

1. Set `nozzle_height = 0.80` in `CaseMaker.py`.
2. Replace Rosin–Rammler with Case B DSD (discretize to OpenFOAM parcel sizes) — substantial effort.
3. Set RH/T in OpenFOAM thermo boundary conditions.
4. Fix known driftml script bugs before batch use (`dataprocessing.py`, `FaceGenerator.py`).

---

## 5. Expected discrepancy sources

Ranked by likely impact on curve shape:

1. **Wind profile** — log-law vs uniform inlet
2. **DSD** — measured bi-modal CDF vs Rosin–Rammler
3. **Nozzle / spray fan** — 11 streamlines vs single cone injection
4. **Canopy / roughness** — z₀ in CDM vs smooth floor in CFD
5. **Turbulence** — k-ε in CFD vs no explicit turbulence in CDM ODE
6. **Evaporation** — Ranz–Marshall (CDM) vs OpenFOAM cloud evaporation models (verify parity in `kinematicCloudProperties`)
7. **Plume spreading** — ψψψ crosswind dispersion in CDM only

---

## 6. Acceptance criteria for a successful cross-check

A cross-check is **informative** (not pass/fail) if:

- [ ] Harmonization assumptions documented (this guide + run notes)
- [ ] Both models run without numerical failure
- [ ] Deposition curves plotted on same distance axis (with origin documented)
- [ ] Discrepancies classified using §5
- [ ] No claim of regulatory validation — exploratory physics sanity check only

---

## 7. References

| Resource | Path |
|----------|------|
| CDM Case B input | [tests/Case_B.json](../tests/Case_B.json) |
| CDM nozzle velocity | [src/NozzleVelocity.cpp](../src/NozzleVelocity.cpp) |
| CDM reconciliation script | [scripts/reconcile_case_b.py](../scripts/reconcile_case_b.py) |
| driftml CaseMaker | `driftml/CFDPipeline_Nextflow/CaseMaker.py` |
| driftml spray physics | `driftml/SprayModel_OpenFOAM/constant/kinematicCloudProperties` |
| Assessment overview | [driftml_assessment.md](driftml_assessment.md) |
