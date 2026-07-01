# Vertical Profile Specification

**Status:** Draft for implementation / post-processing  
**Scope:** Convert `DropletTransport` trajectory data into regulatory vertical profiles that reconcile with existing ground deposition output.

---

## 1. Purpose and definitions

### 1.1 What we are computing

For each downwind distance **d** (m from **field edge**) and height bin **[hₖ, hₖ₊₁)**:

> **pctIAR(d, k)** = percentage of intended application rate (kg/ha applied on the treated field) that is **airborne** in height bin *k* when crossing the vertical measurement plane at distance *d*.

Same normalization as ground deposition (`applume`): fraction of applied product, expressed as %.

### 1.2 What this is not

| Metric | Geometry | Do not confuse with |
|--------|----------|---------------------|
| **pctIAR vertical profile** | Flux through a vertical plane at fixed *d* | Occupancy heatmap (2D path visitation) |
| **applume (ground % IAR)** | Mass deposited on horizontal surface at *d* | Airborne mass at *d* |

---

## 2. Coordinate systems

CDM uses two distance origins; implementations must convert explicitly.

| System | Origin | Used in |
|--------|--------|---------|
| **Transport** | Nozzle, upwind back of field | `DropletTransport` state `X` |
| **Output / regulatory** | Downwind **field edge** | `applume`, vertical profile distances |

**Conversion:**

```
X_plane(d) = FD + d
```

where `FD` = `downwindFieldDepth` [m], `d` = target profile distance from field edge [m].

**Height:**

```
Z_m = Z_cm / 100          // ODE internal units are cm
h_release = hN − liquid_sheet_offset   // effective release height [m]
```

Bin edges: `[0, Δh, 2Δh, …, h_max]` (default Δh = 0.25 m, h_max = 5 m).

---

## 3. Inputs (must match Deposition exactly)

Reuse the same symbols and code paths as `Deposition.cpp`.

### 3.1 Model inputs (from JSON / `Model`)

| Symbol | Code | Notes |
|--------|------|-------|
| IAR | `applicationRate` | kg/ha |
| xactive | `concentrationAI` | wt fraction |
| FD, PL, dN, λ | deposition block | Field geometry |
| dpmin, dpmax | deposition block | Size range |
| dsd, dsdfit | DSD | Same curve fit as deposition |
| sflags | `enableStreamlines` | Same streamlines enabled |
| vpDistances | new config | e.g. `[3, 5, 10, 20, 30, 50]` |
| vpBinWidth | new config | default 0.25 m |
| vpMaxHeight | new config | default 5.0 m |

### 3.2 Derived quantities (identical to Deposition)

```
Nsa  = floor(FD / dN)
sprayedArea     = 0.0001 * FD * PL          // ha
volumeSprayed   = IAR * sprayedArea / (rhoL * xactive)   // L (tank mix)
volumeAppRate   = volumeSprayed / sprayedArea            // L/ha
Δdp  = 0.5   // μm  (must match Deposition.cpp)
dpavg[i] = dpmin + i * Δdp,  i = 0 … mm−1
```

### 3.3 Spray volume per size class — `SVP[i]`

Copy verbatim from `Deposition.cpp` (lines 88–105):

```
if dsdmodel:
    SVP[i] = pdf(dpavg[i]) * Δdp * volumeSprayed / Nsa     for i ≥ 1
else:
    SVP[i] = d(CDF)/d(dp)|dpavg[i] * Δdp * volumeSprayed / Nsa
```

Note: `i = 0` is unused in Deposition (loop starts at 1). Do the same.

**Physical meaning:** liters of tank mix in size bin *i*, allocated to **one** downwind spray segment (field divided into `Nsa` segments). Total over all bins and segments equals applied volume.

### 3.4 Per-trajectory weight (before crossing)

For streamline `n` and size index `i`:

```
w₀(n, i) = SVP[i] / NS     // NS = constants::ns = 11
```

Skip if `sflags[n] == false`.

This is the same allocation used in `DVM` / `CM` accumulation.

---

## 4. Trajectory recording requirements

### 4.1 Minimum recorded series

For each `(n, i)` pair on the **`dpavg` grid** (not the 23-point transport grid):

| Field | Units | Notes |
|-------|-------|-------|
| `X(t)` | m | Downwind from nozzle |
| `Z(t)` | m | Height above ground |
| `Mw(t)` | g | Water mass (evolving) |
| `Ms0`, `Mw0` | g | Initial masses at release for this `dp` |

**Size grid alignment:** Deposition uses `dpavg` at 0.5 μm steps; transport currently uses 23 geometric sizes for `xdist`. For vertical profiles, **integrate at each `dpavg[i]`** directly (or interpolate trajectories from the 23-point grid — direct integration is preferred for reconciliation).

### 4.2 Sampling density

**Production:** CVODE root function when `X(t) − X_plane(d) = 0` for each target `d` (accurate crossing height).

**Post-processing from stored trajectories:** linear interpolation of `(X, Z, Mw)` along the path; require at least one segment pair straddling each `X_plane(d)`.

Do **not** use point-in-cell occupancy (that produces white holes in heatmaps).

### 4.3 Termination / eligibility

A crossing at distance `d` counts only if:

```
1. First forward crossing:  X(t−) < X_plane(d)  AND  X(t+) ≥ X_plane(d)
2. Still airborne:          Z(t_cross) > z0 + hC     // same threshold as RhsFn freeze
3. Integration valid:       t_cross ≤ tmax
```

If the droplet reaches `Z ≤ z0 + hC` before `X_plane(d)`, it contributes to **ground deposition only**, not the vertical profile at `d`.

If `X(tmax) < X_plane(d)`, no crossing — zero contribution at that `(d, k)`.

---

## 5. Crossing event algorithm

For each target distance `d`, height bin width `Δh`:

```
accum[d][k] = 0   for all bins k

for n in 0 … NS−1:
  if not sflags[n]: continue
  for i in 1 … mm−1:
    integrate trajectory (n, i)
    find first t* where X(t*) = X_plane(d) and still airborne

    if no such t*: continue

    Z* = interpolate Z at X_plane(d)
    Mw* = interpolate Mw at X_plane(d)

    // Mass weight (see §6 for evaporation choice)
    f_res = (Mw* + Ms0(i)) / (Mw0(i) + Ms0(i))
    w = w₀(n, i) * f_res                    // liters tank mix

    k = floor(Z* / Δh)
    if 0 ≤ Z* < vpMaxHeight:
        accum[d][k] += w
```

**Sub-bin interpolation (optional, reduces bin discretization error):**

Split `w` between bins `k` and `k+1` by linear distance fraction across the bin boundary.

---

## 6. Normalization to % IAR

### 6.1 Primary normalization

```
pctIAR(d, k) = 100 * accum[d][k] / volumeSprayed
```

**Units check:** `accum` is liters of tank mix; `volumeSprayed` is total liters applied on the field → dimensionless fraction × 100.

This mirrors ground deposition, where:

```
applume(d) = 100 * propAppliedPlume(segment at d)
propAppliedPlume = CS / (volumeAppRate / 10000)
```

Both express **fraction of what was applied on the field.**

### 6.2 Evaporation: two modes

| Mode | Weight at crossing | Use |
|------|-------------------|-----|
| **Physical (default)** | `w₀ × f_res` | Correct airborne flux; water lost → less mass in air |
| **Deposition-consistent** | `w₀` (full SVP) | Bookkeeping match with `DVM` (which ignores evaporation) |

Deposition assigns full `SVP[i]/NS` to the ground segment where the droplet **ends**, without `f_res`. Document both; use **Physical** for regulatory output, **Deposition-consistent** only for reconciliation tests.

### 6.3 Derived outputs

```
totalAirborne(d)   = Σ_k pctIAR(d, k)
cumulative(d, k)   = Σ_{j=0}^{k} pctIAR(d, j)    // ground → height hₖ₊₁
```

---

## 7. Mass-balance reconciliation with Deposition

### 7.1 What should and should not match

| Quantity | Includes ψψψ? | Should match vertical profile? |
|----------|---------------|--------------------------------|
| `applume` (ground) | **Yes** (plume spreading in `CM`) | Lateral shape differs; **total drift mass** should |
| `propAppliedNoPlume` | **No** | Better for mass-balance tests |
| Vertical profile | **No** (transport only) | N/A |

**ψψψ widens ground concentration**; it does not add or remove mass. Do not apply ψψψ to vertical profiles.

### 7.2 Partition identity (approximate)

At any distance `d` downwind of the field edge, applied tank volume partitions as:

```
100% ≈ field_deposited
     + ground_drift_deposited(0 … d)
     + ground_drift_deposited(d … ∞)
     + still_airborne_at_tmax
     + evaporative_volume_loss
```

Vertical profile captures the **instantaneous airborne slice** at plane `d`, not cumulative deposition.

### 7.3 Reconciliation tests

Implement these as automated checks (tolerance ε ≈ 1–2% relative, account for discretization):

**Test A — Monotonicity of total airborne**

```
totalAirborne(d₁) ≥ totalAirborne(d₂)   for d₁ < d₂
```

Material leaves the airborne state as droplets deposit; nothing re-enters the air in CDM.

**Test B — Far-field limit**

```
totalAirborne(d) → 0   as d → Lmax
```

where `Lmax` exceeds max drift distance for all `(n, i)`.

**Test C — Near-field upper bound**

Just downwind of the field edge (`d ≈ 0⁺`):

```
totalAirborne(d) ≤ 100% − field_spray_fraction
```

Field spray fraction ≈ volume deposited on field segments / volumeSprayed (from `VPS` on sprayed segments, or `Σ_k pctIAR` at `d=0` if defined carefully).

**Test D — Drift mass split (no-plume mode)**

Using **Deposition-consistent** weights (`f_res = 1`):

```
Σ_d [ground_drift_increment(d)] + Σ_n,i [w₀ if still airborne at tmax]
  ≈ Σ_{drift segments} VPS  (from Deposition internals)
```

**Test E — Physical vs ground complement (soft check)**

For physical weights (`f_res` at crossing):

```
totalAirborne(d) + cumulative_ground_drift(d) + field_fraction + evap_loss ≈ 100%
```

Evaporation estimate:

```
evap_loss ≈ 100 * (1 − Σ_{n,i} f_res,final · w₀(n,i) / volumeSprayed)
```

where `f_res,final` is at trajectory end.

### 7.4 Comparison to `applume` at same distance

At distance `d`, **do not expect** `pctIAR(d, k)` summed over *k* to equal `applume(d)`:

- `applume(d)` = ground deposition rate at *d* (horizontal surface)
- `totalAirborne(d)` = mass still in air crossing the plane at *d*

They answer different questions. The link is through **Test E**, not equality at a single *d*.

### 7.5 Validation procedure

Use Case B (or G/I) as the reference scenario. A minimal ground-deposition reconciliation script lives at [`scripts/reconcile_case_b.py`](../scripts/reconcile_case_b.py); extend it when vertical profile JSON exists.

**Step 1 — Run CDM and capture ground deposition**

```bash
cdm -i tests/Case_B.json -o /tmp/case_b_out.json
python scripts/reconcile_case_b.py --output-json /tmp/case_b_out.json
```

Or pass `--cdm-cli` to run the model automatically.

**Step 2 — Ground drift summary from `applume`**

From `output.deposition` (array of `[distance_m, pctIAR]` pairs, distance from **field edge**):

| Quantity | How |
|----------|-----|
| Deposition at standard distances | Read `pctIAR` at 3, 5, 10, 20 m |
| Cumulative ground drift | Trapezoidal integral of `pctIAR` vs distance for downwind points (`distance > 0`) |
| Total drift deposited | Approximate `Σ pctIAR_i × Δx_i` (see script; not exact mass flux without segment geometry) |

**Step 3 — Vertical profile checks (when available)**

Once `verticalDriftProfile` exists (in-solver or post-processed):

1. Compute `totalAirborne(d) = Σ_k pctIAR(d, k)` at each target distance.
2. **Test A:** confirm `totalAirborne(d₁) ≥ totalAirborne(d₂)` for `d₁ < d₂`.
3. **Test B:** confirm `totalAirborne(d) → 0` beyond max drift distance.
4. **Do not** compare `totalAirborne(d)` to `applume(d)` at the same *d* (§7.4).

**Step 4 — Partition check (soft mass balance)**

Using Deposition-consistent weights (`f_res = 1` at crossings):

```
field_fraction + cumulative_ground_drift(Lmax) + still_airborne_at_tmax + evap_loss ≈ 100%
```

Estimate `still_airborne_at_tmax` and `evap_loss` from trajectory endpoints when trajectory export exists. Until then, ground-only checks in the script bound the vertical profile normalization target.

**Step 5 — Same inputs checklist**

| Must match Deposition | |
|-----------------------|---|
| `dsdCurveFitting: true` | Fitted PDF → `SVP[i]` |
| `dpavg` grid (0.5 μm) | Not the 23-point transport grid alone |
| Streamline flags | Same `enableStreamlines` |
| Plane location | `X = FD + d` (field-edge distances, like `applume`) |
| ψψψ | **Not** applied to vertical profile |

**Step 6 — Record results**

Document pass/fail, tolerance used, and any gap vs §14 open issues. Update §6 normalization if Case B proves the current formula wrong.

---

## 8. JSON output schema

```json
{
  "verticalDriftProfile": {
    "distanceOrigin": "fieldEdge",
    "distances_m": [3, 5, 10, 20, 30, 50],
    "heightBinEdges_m": [0, 0.25, 0.5, 0.75, 1.0],
    "massWeighting": "residual",
    "profiles": [
      {
        "distance_m": 3,
        "bins": [
          { "heightMin_m": 0.0, "heightMax_m": 0.25, "pctIAR": 0.012 },
          { "heightMin_m": 0.25, "heightMax_m": 0.5, "pctIAR": 0.008 }
        ],
        "totalAirborne_pctIAR": 0.045,
        "cumulativePctIAR": [0.012, 0.020]
      }
    ],
    "reconciliation": {
      "volumeSprayed_L": 123.4,
      "massWeightingMode": "residual",
      "checksPassed": ["monotonic_total", "far_field_zero"]
    }
  }
}
```

Optional diagnostic block (same structure, per size class and/or streamline).

---

## 9. Implementation placement

### Phase 1 — Post-processor (collaborator path)

```
TrajectoryRecorder → VerticalProfileAccumulator → JSON
```

Shared module `VerticalProfile.cpp` calling the same `SVP` helper extracted from `Deposition.cpp` (avoid duplication).

### Phase 2 — In-solver (production)

Extend `DropletTransport` / CVODE:

```
g0: Z − (z0 + hC) = 0          → mark deposited, stop or freeze
g1…gN: X − (FD + d_j) = 0      → record (Z, Mw), continue
```

One integration pass per `(n, i)` records all distance crossings.

---

## 10. Pseudocode reference implementation

```python
def compute_vertical_profile(model, trajectories):
    # --- shared with Deposition ---
    Nsa, NS = floor(model.FD / model.dN), 11
    sprayedArea = 1e-4 * model.FD * model.PL
    volumeSprayed = model.IAR * sprayedArea / (model.rhoL * model.xactive)
    dpavg, SVP = compute_svp(model)  # identical to Deposition.cpp

    z_stop = model.z0 + model.hC
    accum = {d: zeros(n_bins) for d in model.vpDistances}

    for n in range(NS):
        if not model.sflags[n]: continue
        for i in range(1, len(dpavg)):
            traj = trajectories[n][i]  # X, Z, Mw series in meters, grams
            Ms0, Mw0 = initial_masses(dpavg[i], model)

            for d in model.vpDistances:
                Xp = model.FD + d
                hit = first_crossing(traj.X, traj.Z, Xp, z_stop)
                if hit is None: continue

                Zc, Mwc = interpolate(traj, hit, Xp)
                f_res = (Mwc + Ms0) / (Mw0 + Ms0)
                w = (SVP[i] / NS) * f_res

                k = int(Zc / model.vpBinWidth)
                if 0 <= k < n_bins:
                    accum[d][k] += w

    profiles = []
    for d in model.vpDistances:
        pct = [100 * v / volumeSprayed for v in accum[d]]
        profiles.append({
            "distance_m": d,
            "pctIAR": pct,
            "totalAirborne_pctIAR": sum(pct),
            "cumulativePctIAR": cumsum(pct),
        })
    return profiles
```

---

## 11. Expected results for Case B (sanity)

With Case B inputs (nozzle ~0.7 m effective, DSD peak ~180 μm):

| Distance | Expected shape |
|----------|----------------|
| 0–1 m | Most mass in bins 0.5–0.7 m and below; narrow vertical curtain |
| 3–5 m | Mass shifts lower; small droplets remain in upper bins |
| 20–50 m | Very small `totalAirborne`; almost all mass in lowest bins or zero |

No upward bins above `h_release`. Bins with zero flux get `pctIAR = 0`, not masked (unlike occupancy heatmaps).

---

## 12. Open decisions (defaults recommended)

| Question | Recommendation |
|----------|----------------|
| Include streamlines with backward initial Vx? | Yes, same as Deposition; use first **downwind** crossing |
| Multiple crossings at same *d*? | Count first only (droplet cannot recross in CDM) |
| Crosswind (ψψψ) in vertical profile? | **No** — transport stage only |
| Per-size diagnostic output? | Optional flag; useful for SETAC validation |
| Distance `d = 0`? | Allow (field-edge plane); expect largest `totalAirborne` |

---

## 13. Summary

1. **Weight** each crossing with `SVP[i]/NS`, optionally × residual mass fraction.
2. **Normalize** with `100 / volumeSprayed` — same applied-volume basis as deposition (verify on Case B; see §14).
3. **Place planes** at `X = FD + d` to match `applume` distances.
4. **Do not** use occupancy rasterization or ψψψ plume spreading.
5. **Reconcile** via §7.5 and [`scripts/reconcile_case_b.py`](../scripts/reconcile_case_b.py), not by equating vertical bins to ground deposition at the same *d*.

---

## 14. Spec validation TODO / open issues

These items must be resolved (or explicitly accepted) before treating §6 normalization and §7 mass-balance tests as authoritative.

| ID | Issue | Status | Action |
|----|-------|--------|--------|
| V-1 | **`pctIAR = 100 × accum / volumeSprayed`** may not match Deposition’s `propAppliedPlume` path exactly (`CS / (volumeAppRate/10000)`). | Open | Run Case B; compare script totals to known SETAC drift; adjust formula if needed. |
| V-2 | **Dual size grid:** transport uses 23 geometric `dp` values; Deposition/`SVP` uses `dpavg` every 0.5 μm. | Open | Integrate vertical profiles at `dpavg`; do not weight 23-point trajectories with ad hoc DSD bins. |
| V-3 | **`SVP / Nsa` semantics:** sum of trajectory weights is O(`volumeSprayed/Nsa`); full-field % IAR normalization needs proof. | Open | Trace Deposition totals in `reconcile_case_b.py`; confirm vertical profile uses identical denominator. |
| V-4 | **Evaporation:** Deposition uses full `SVP` at landing; §6 default uses residual mass at crossing. | Open | Pick one for validation; document both in output JSON. |
| V-5 | **In-solver plane crossing** (§9 Phase 2) not implemented; `CVodeIntegrator::initRootFinding` unused. | Open | Phase 1 post-processing acceptable if crossing interpolation is correct. |
| V-6 | **Lagrangian snapshot vs collector exposure:** one crossing height per droplet ≠ time-integrated capture on a vertical pole. | Accepted limitation | Note in regulatory submissions; compare cautiously to field data. |
| V-7 | **Coordinate docs:** `parameter-reference.md` lists `X` from nozzle; `applume` distances from field edge. | Open | Always use `X_plane = FD + d`; audit plots and post-processors. |
| V-8 | **Occupancy heatmaps** vs vertical planes (§1.2, §4.2): different metrics; not interchangeable. | Documented | Use planes for deliverable; heatmaps diagnostic only. |

**Validation gate:** Case B reconciliation script passes ground-drift checks; vertical profile checks pending implementation. Do not instruct collaborators to treat §6 as frozen until V-1 and V-3 are closed.

---

## Related documents

- [vertical-profile-glossary.md](vertical-profile-glossary.md) — terminology (Lagrangian, lofting, collectors, SVP, etc.)
- [vertical-profile-design-notes.md](vertical-profile-design-notes.md) — design rationale and regulatory context
- [parameter-reference.md](parameter-reference.md) — ODE state variables and coordinate conventions
- [FunctionalSpecification.md](FunctionalSpecification.md) — Deposition algorithm (§4.6)
- [`scripts/reconcile_case_b.py`](../scripts/reconcile_case_b.py) — Case B ground-drift reconciliation (§7.5)
