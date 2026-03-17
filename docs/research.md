---
title: Research
---

# Research: Vertical Drift Distribution

## Enhancing Spray Drift Assessment

Integration of vertical drift distribution in the Casanova Drift Model for non-target organism risk evaluation.

## Background

Spray drift modeling has become increasingly important in the regulatory assessment of crop protection product applications, particularly as concerns grow over the potential impacts on non-target organisms, including:

- **Non-target arthropods (NTAs)** — insects and other arthropods in adjacent habitats
- **Non-target terrestrial plants (NTTPs)** — vegetation in off-crop areas

Regulatory frameworks demand accurate predictions of drift behavior to ensure the safety of ecosystems adjacent to agricultural fields.

## Current Limitations

Existing models primarily generate spray drift deposition curves without accounting for vertical distribution. This limits the ability to assess:

- Exposure of organisms at different canopy heights
- Short-range drift dynamics affecting off-crop capture
- Three-dimensional transport patterns

## CDM Enhancement Approach

The Casanova Drift Model provides enhanced simulation capabilities to estimate not only deposition curves but also **vertical drift profiles**.

### Mechanistic Approach

The model employs CVODE integration to track droplet trajectories using a six-component solution vector:

| Component | Symbol | Description |
|-----------|--------|-------------|
| Vertical position | Z | Height above ground |
| Horizontal position | X | Downwind distance |
| Vertical velocity | V_z | Vertical speed |
| Horizontal velocity | V_x | Horizontal speed |
| Water mass | M_w | Droplet water content |
| Wind velocity | V_vwx | Local horizontal wind speed |

By solving coupled ODEs that account for drag forces, evaporation, and wind profile interactions, the model captures the complete three-dimensional transport of droplets from nozzle release through deposition.

### Key Factors Analyzed

- **Droplet size distribution** — parameterized via non-linear least squares curve fitting
- **Wind velocity profiles** — characterized by friction velocity and friction height
- **Application technique parameters** — nozzle height, pressure, and angle
- **Spray fan geometry** — multiple streamline vectors (typically 11) spanning ejection angles from −40° to −140°

## Preliminary (Expected) Results

- Expected: *The Casanova model effectively represents short-range in-flight drift patterns*
- Validation against SETAC DRAW test data and xxxx trial data 
  - demonstrates adequate prediction of both horizontal deposition and vertical concentration profiles
- The model successfully captures:
  - Droplet evaporation effects (via wet bulb temperature depression)
  - Atmospheric stability (through wind profile parameterization)
  - Size-dependent transport on spatial distribution of drift

## Impact

This advancement is expected to:

- Improve risk analysis for non-target organisms
- Foster regulatory compliance
- Enable better-informed decisions in crop protection management
- Contribute to sustainable agricultural practices

---

**Keywords:** spray drift modeling, vertical drift distribution, non-target arthropods, non-target terrestrial plants, regulatory assessment, environmental risk assessment


> View the [full abstract on GitHub](https://github.com/SprayDriftModels/CDM/blob/main/docs/VerticalDriftDistribution_Abstract.md).