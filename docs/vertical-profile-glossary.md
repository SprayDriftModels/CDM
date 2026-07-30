# Vertical Profile & Spray Drift — Glossary

Plain-language definitions for terms used in [vertical-profile-spec.md](vertical-profile-spec.md), collaborator discussions, and comparisons with field collectors and SIMOD.

---

## Frames and ways of measuring

| Term | Plain meaning | In CDM / this project |
|------|----------------|------------------------|
| **Lagrangian** | Follow **individual droplets** (or representative paths) as they move. | `DropletTransport`: each size × streamline is one path; mass recorded when it crosses a plane. |
| **Eulerian** | Fix a **point or plane in space** and ask what passes through over time. | Field collector on a pole at 5 m downwind; measures what arrives **at that spot** while the spray event lasts. |
| **Lagrangian snapshot** | One moment on a particle path: where is it and how much mass when it crosses this plane? | Vertical profile target: one height + one weight per trajectory at `X = FD + d`. Not averaged over time at a fixed point. |
| **Exposure over time / integrated catch** | Sampler stays in place; **adds up** everything it collects during the trial or boom pass. | Collector catch; often **larger aloft near the nozzle** than a CDM snapshot because real spray keeps passing for seconds. |

---

## Geometry: what you measure

| Term | Plain meaning | In CDM / this project |
|------|----------------|------------------------|
| **Vertical plane** | An imaginary upright sheet at one **downwind distance** *d*. | Spec target: count airborne mass crossing `X = FD + d`, binned by height. |
| **Vertical profile** | How much spray is in the air at each **height**, at a given downwind distance. | Output: `pctIAR(d, k)` per height bin *k*. |
| **Ground deposition** | Mass that **lands on the soil** at distance *d*. | CDM `applume`; horizontal surface, not airborne. |
| **Occupancy / grid heatmap** | 2D map: did trajectories **visit** this (distance, height) cell? | Exploratory diagnostic; **not** the same as a vertical profile at one plane. |
| **Field edge** | Downwind boundary of treated field; regulatory distances start here. | `d = 0` for output; transport coordinate `X = FD + d`. |
| **Nozzle / release height** | Where spray leaves the fan (CDM: `hN − liquid_sheet_offset`, ≈ 0.7 m in Case B). | All CDM paths start here or below; no paths above release in current transport physics. |

---

## Mass, weighting, and outputs

| Term | Plain meaning | In CDM / this project |
|------|----------------|------------------------|
| **% IAR / pctIAR** | **Percent of intended application rate** — fraction of what was applied on the field (kg/ha). | Same normalization for ground deposition and (target) vertical profile. |
| **IAR** | Intended application rate (e.g. kg product / ha). | Case B: 0.83886 kg/ha in config. |
| **SVP[i]** | **Spray volume partial** — liters of **tank mix** assigned to droplet size bin *i* (from DSD). | From fitted PDF in Deposition; each streamline gets `SVP[i] / 11`. |
| **DSD** | **Droplet size distribution** — how spray volume is split across droplet diameters. | Case B peak ~180 µm → most mass falls quickly near nozzle. |
| **applume** | CDM ground deposition curve: `% IAR` vs downwind distance. | Used for validation; **not** equal to vertical profile at same *d*. |
| **totalAirborne(d)** | Sum of vertical profile bins at distance *d* — all mass still **in air** at that plane. | Should **decrease** as *d* increases. |
| **Tank mix** | Spray liquid in the tank (water + product); CDM tracks water evaporation via `Mw`. | `volumeSprayed` in liters from IAR and field area. |

---

## Physics CDM has vs does not have

| Term | Plain meaning | In CDM / this project |
|------|----------------|------------------------|
| **Lofting / upward drift** | Droplets move **up** after leaving the nozzle before falling. | **Not in** transport ODEs; common near-field in reality and in SIMOD-like models. |
| **Wake / entrained air / nozzle wake** | Fan and liquid sheet **pull air** with them; creates upward and outward flow near nozzle. | Main real-world cause of lofting; **not modeled** in CDM. |
| **Near-field** | First few metres downwind / height; dominated by nozzle, fan, wake. | Where lofting matters most; may be out of scope for current phase. |
| **Far-field** | Tens of metres downwind; wind and droplet inertia dominate. | CDM ground deposition validated here (SETAC DRAW). |
| **Terminal velocity** | Speed at which gravity and drag balance for a droplet. | Large drops fall fast; small drops stay aloft longer and travel farther. |
| **Wind shear** | Wind speed **changes with height** (log profile). | **In CDM**: `dVvwx/dt` as droplet falls; deterministic, not random. |
| **Turbulence** | Random gusts and eddies spreading droplets in space. | **Not in** CDM transport; SIMOD far-field uses random-walk-style spread. |
| **ψψψ (horizontal variation)** | Parameter for **crosswind plume widening** on the ground. | **Deposition only**; not applied to airborne trajectories. |
| **Streamline (CDM)** | One of **11 fixed spray-fan angles** (−40° to −140°). | Nozzle geometry; **not** a wind streamline or turbulence realization. |

---

## Field equipment and model comparison

| Term | Plain meaning | CDM comparison |
|------|----------------|----------------|
| **Vertical collector / pole sampler** | Sticky rod, line, or similar at fixed distance; samples at several **heights**. | Used in drift trials (e.g. SETAC DRAW); protocol defines what is measured. |
| **Collector catch** | **Mass collected** on the device over the exposure period. | Often **deposition on surface**, not pure air passing through a plane. |
| **Collection / impaction efficiency** | Fraction of airborne droplets that **stick** on the collector. | Airborne flux (CDM target) ≥ catch if efficiency &lt; 1. |
| **Air sampling / flux through plane** | Measure material **passing through** an area (closer to CDM spec). | Better match to `pctIAR` vertical profile than sticky-rod deposition alone. |
| **Boom pass** | Sprayer drives along field; cloud moves past fixed collectors. | Explains **time integration** on collectors vs one **crossing** per CDM trajectory. |

---

## Regulatory and related models

| Term | Plain meaning |
|------|----------------|
| **NTA** | Non-target **arthropods** (often low height, ~0.5 m exposure). |
| **NTTP** | Non-target **terrestrial plants** (canopy / hedgerow heights, e.g. ~2 m). |
| **SETAC DRAW** | Standard drift test cases and workshop context for model validation. |
| **SIMOD** | Silsoe spray drift model; near-nozzle wake + turbulence; often **more spread and lofting** than CDM. |

---

## Why collector catch is often larger aloft (near the nozzle)

```
Height
  0.9 m │     ··· collector keeps catching while cloud passes ···
  0.7 m │──── nozzle ────  CDM: paths start here, none go higher
  0.5 m │     ╲  wake lifts real droplets briefly (not in CDM)
        └────────────────→ downwind
```

- **CDM aloft:** essentially no mass **above** release height.
- **Real collector aloft:** can still catch spray **lifted by wake** during the pass → often **larger** than CDM in upper bins near the nozzle.

This is an expected model-scope difference, not necessarily a post-processing bug.

---

## Related documents

- [vertical-profile-spec.md](vertical-profile-spec.md) — calculation spec and validation
- Design notes: `docs/private/` (private remote only)
- [parameter-reference.md](parameter-reference.md) — ODE state variables and coordinates
