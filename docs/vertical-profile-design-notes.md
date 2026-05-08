**% IAR = Percent of Initial Application Rate**

It represents the fraction of the originally applied spray (mass per unit area) that passes through a given vertical cross-section at a downwind distance, expressed per height bin. For example:

> "At 10 m downwind, 0.8% IAR passes between 0–0.25 m height"

This means 0.8% of the mass applied per unit area on the field is drifting through that specific height band at that distance. It's the standard metric used in spray drift risk assessment because it:

- Is **normalised** to application rate (comparable across scenarios)
- Can be **summed** across height bins to get total airborne drift at a distance
- Directly feeds into **exposure models** (e.g., multiply by application rate to get deposition on non-target plants/organisms)

---

Let me create a documentation file for the design suggestions: 

Created [](file:///c%3A/Users/gbbfx/GitProjects/CDM/docs/vertical-profile-design-notes.md)
Completed with input: {
  "filePath": "c:\\Users\\gbbfx\\GitProjects\\CDM\\docs\\vertical-profile-design-notes.md",
  "content": "# Vertical Drift Profile — Design Notes & Suggestions\n\n**Date:** 2025-05-07\n**Context:** Post-Friday discussion on extending Casanova drift model with vertical profile output\n\n---\n\n## Key Metric: % IAR (Percent of Initial Application Rate)\n\n**Definition:** The fraction of the originally applied spray mass (per unit ground area) that passes through a vertical plane at a given downwind distance, resolved by height bin.\n\n**Units:** Dimensionless (expressed as percentage of applied rate per height interval)\n\n**Example interpretation:**\n- \"At 10 m downwind, 0.8% IAR in the 0–0.25 m bin\" means 0.8% of what was applied per m² on the field is passing through that height band at that distance.\n\n**Why % IAR:**\n- Normalised → comparable across application rates, nozzle types, and scenarios\n- Directly usable in NTA (Non-Target Arthropod) and NTTP (Non-Target Terrestrial Plant) exposure assessments\n- Summable across height bins → total airborne fraction at a distance\n- Regulatory standard metric (SETAC DRAW, EFSA guidance)\n\n---\n\n## Design Decisions\n\n### 1. Vertical profile is optional (opt-in)\n\n**Rationale:** Most users only need ground deposition. Registering additional root-finding events in the ODE solver adds computational cost. When disabled, zero overhead.\n\n**Implementation:** A flag (`verticalProfile = TRUE/FALSE`) in the input configuration. When `FALSE`, no distance-crossing root functions are registered.\n\n### 2. % IAR is the primary (headline) output\n\n**Rationale:** This is what regulators and risk assessors consume directly. Other outputs are diagnostic or informational.\n\n**Output structure:**\n```json\n{\n  \"verticalDriftProfile\": {\n    \"distances_m\": [5, 10, 20],\n    \"heightBins_m\": [0, 0.25, 0.5, ..., 5.0],\n    \"pctIAR\": [[...], [...], [...]]\n  }\n}\n```\n\n### 3. Report cumulative % IAR (ground to height h)\n\n**Rationale:** The regulatory question is often \"what fraction of drift passes below canopy height h?\" — e.g., below 0.5 m for ground-dwelling arthropods, below 3 m for hedgerow vegetation. A cumulative profile directly answers this without post-processing.\n\n**Suggestion:** Include `cumulativePctIAR` as a companion array (same shape), where each value is the sum from ground up to that bin's upper edge.\n\n### 4. Default distances aligned with regulatory standards\n\n**Suggestion:** Default target distances of 3, 5, 10, 20, 30, 50 m (matching SETAC DRAW field trial distances and standard buffer zone widths).\n\n**User override:** Allow user to specify custom distance vector.\n\n### 5. Height bin resolution\n\n**Default:** 0.25 m bins from 0 to 5 m (21 bin edges, 20 bins).\n\n**Rationale:** 25 cm is sufficient for regulatory use (NTA/NTTP). Finer resolution (10 cm) could be offered as an option for research/validation but increases output size.\n\n### 6. Intermediate/diagnostic outputs (optional)\n\nAvailable when a verbosity or diagnostic flag is set:\n\n| Output | Purpose |\n|--------|---------|\n| Per-size-class % IAR profiles | Understand which droplet sizes dominate at each height |\n| Cumulative mass-weighted size distribution at distance | Characterise the drifting spray cloud |\n| Evaporation state (residual mass fraction) at crossing | Understand volatile vs. non-volatile fate |\n| Individual droplet trajectories (subset) | Visualisation / debugging |\n\n**Rationale:** These are valuable for model understanding and validation against field data (e.g., SETAC DRAW vertical collectors) but should not clutter the standard output.\n\n### 7. Validation strategy\n\n- Compare against SETEC DRAW vertical collector datasets\n- Benchmark against published Ganzelmeier vertical profiles\n- Cross-check: integral of vertical profile should equal total airborne drift from deposition-based estimate\n\n---\n\n## Implementation Steps (Summary)\n\n| Step | Task | Complexity |\n|------|------|-----------|\n| 1 | Add vertical profile configuration to input schema | Low |\n| 2 | Register distance-crossing root functions (`g1..gN`) in CVODE | Medium |\n| 3 | Record (z, mw, droplet_class, streamline) at each crossing event | Low |\n| 4 | Bin crossings by height, weight by mass fraction | Low |\n| 5 | Normalise to % IAR | Low |\n| 6 | Add `verticalDriftProfile` section to output JSON | Low |\n| 7 | Add cumulative profile computation | Low |\n| 8 | Validation against reference data | Medium–High |\n\n---\n\n## Open Questions\n\n1. Should height bins be fixed or user-configurable? (Suggestion: configurable with sensible default)\n2. Maximum height to track? (5 m covers most NTA/NTTP scenarios; could extend to 10 m for tall crops/orchards)\n3. Should we also output a \"total airborne drift at distance\" scalar (= sum of all height bins)? Useful as a quick summary.\n4. Integration with existing post-processing tools — what format do downstream exposure models expect?\n"
}

Here's the document:

---

## % IAR — Definition

**% IAR = Percent of Initial Application Rate**

It is the fraction of the originally applied spray mass (per unit ground area) that passes through a vertical plane at a given downwind distance, resolved by height bin.

- **Units:** dimensionless, expressed as a percentage
- **Example:** "At 10 m downwind, 0.8% IAR in the 0–0.25 m bin" → 0.8% of what was applied per m² on the field is passing through that height band at 10 m distance
- **Why normalised:** directly comparable across application rates, nozzle types, scenarios; summable across bins; regulatory standard metric (SETAC DRAW, EFSA guidance)

---

## Design Notes & Suggestions

### 1. Vertical profile is opt-in

No overhead when disabled — distance-crossing root functions are only registered when `verticalProfile = TRUE`.

### 2. % IAR is the primary output

This is what regulators and risk assessors consume. Other outputs (ground deposition, diagnostics) are secondary or always-on.

### 3. Also report cumulative % IAR (ground → height h)

Directly answers: "what fraction of drift passes below canopy height h?" — the core NTA/NTTP question. No post-processing needed.

### 4. Default distances: 3, 5, 10, 20, 30, 50 m

Aligned with SETAC DRAW field trial distances and standard buffer zone widths. User-overridable.

### 5. Height bin resolution: 0.25 m default (0–5 m)

Sufficient for regulation; offer 10 cm option for research/validation.

### 6. Intermediate outputs (diagnostic flag)

| Output | Purpose |
|--------|---------|
| Per-size-class % IAR | Which droplet sizes dominate at each height |
| Evaporation state at crossing | Volatile vs. non-volatile fate |
| Cumulative size distribution at distance | Cloud characterisation |

### 7. Validation

- Compare against SETAC DRAW vertical collector data
- Cross-check: integral of vertical profile ≈ total airborne drift from ground deposition method

### Open questions

1. Max height? 5 m covers most NTA/NTTP; 10 m for orchards?
2. Output "total airborne at distance" scalar (sum of all bins) as quick summary?
3. What format do downstream exposure models expect?

