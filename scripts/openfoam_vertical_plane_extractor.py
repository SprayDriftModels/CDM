#!/usr/bin/env python3
"""
OpenFOAM vertical-plane airborne mass extractor (reference design for CDM).

Extracts airborne spray mass in height bins at specified downwind distances from
OpenFOAM MPPICFoam Lagrangian particle positions. Output format aligns with
docs/vertical-profile-spec.md for comparison against CDM verticalDriftProfile.

This script is a **reference implementation** for assessment Option C. It does not
run inside CDM CI (requires OpenFOAM case output on disk). driftml's CaseProcessor
only extracts ground deposition; this fills the vertical-profile gap.

Usage:
    # After an OpenFOAM run (positions written per time directory):
    python scripts/openfoam_vertical_plane_extractor.py \\
        --case-dir /path/to/driftml/CFDPipeline_Nextflow/casedir \\
        --distances 3 5 10 20 30 50 \\
        --field-edge-offset 24.0 \\
        --application-rate 0.83886 \\
        --sprayed-area-ha 0.1728 \\
        --concentration-ai 0.0079761 \\
        --rho-l 1.0 \\
        --output vertical_profile_openfoam.json

Input data sources (in order of preference):
  1. lagrangian/kinematicCloud/*/positions  (OpenFOAM cloud write)
  2. postProcessing/sampledTracks/          (if track sampling enabled)

See docs/vertical-profile-spec.md §1–3 for CDM definitions and normalization.

Coordinate conventions:
  - OpenFOAM case: x = downwind, y = vertical, z = crosswind (driftml layout)
  - CDM regulatory distance d: meters from field edge (downwind)
  - Plane location: x_plane = field_edge_offset + d  (maps to spec X_plane = FD + d)
"""

from __future__ import annotations

import argparse
import json
import math
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]


@dataclass
class ExtractorConfig:
    case_dir: Path
    distances_m: list[float]
    field_edge_offset_m: float  # FD in CDM spec
    bin_width_m: float = 0.25
    max_height_m: float = 5.0
    plane_thickness_m: float = 0.05
    application_rate_kg_ha: float = 0.83886
    sprayed_area_ha: float = 0.1728
    concentration_ai: float = 0.0079761
    rho_l_g_cm3: float = 1.0
    active_fraction: float = 1.0  # AI mass fraction in droplet (xactive)


@dataclass
class ParticleSnapshot:
    time: float
    x: float  # downwind [m]
    y: float  # vertical [m]
    z: float  # crosswind [m]
    mass: float  # kg (or consistent mass unit)


@dataclass
class VerticalProfileResult:
    distance_m: float
    bin_edges_m: list[float]
    pct_iar_per_bin: list[float]
    total_airborne_pct_iar: float
    particle_count: int
    notes: list[str] = field(default_factory=list)


def volume_sprayed_liters(cfg: ExtractorConfig) -> float:
    """Match CDM Deposition volumeSprayed = IAR * sprayedArea / (rhoL * xactive)."""
    rho_kg_m3 = cfg.rho_l_g_cm3 * 1000.0
    return (
        cfg.application_rate_kg_ha
        * cfg.sprayed_area_ha
        / (rho_kg_m3 * cfg.concentration_ai)
    )


def mass_to_pct_iar(mass_kg: float, cfg: ExtractorConfig) -> float:
    """Convert airborne mass at plane to % IAR (spec §1.1)."""
    total_applied_kg = cfg.application_rate_kg_ha * cfg.sprayed_area_ha
    if total_applied_kg <= 0:
        return 0.0
    ai_mass = mass_kg * cfg.active_fraction
    return 100.0 * ai_mass / total_applied_kg


def make_bin_edges(bin_width: float, max_height: float) -> list[float]:
    n_bins = int(math.ceil(max_height / bin_width))
    return [i * bin_width for i in range(n_bins + 1)]


def bin_index(height_m: float, edges: list[float]) -> int | None:
    if height_m < edges[0] or height_m >= edges[-1]:
        return None
    for k in range(len(edges) - 1):
        if edges[k] <= height_m < edges[k + 1]:
            return k
    return None


def parse_openfoam_vector_line(line: str) -> tuple[float, float, float] | None:
    """Parse OpenFOAM vector format: (x y z) or x y z."""
    m = re.search(r"\(([^)]+)\)", line)
    if m:
        parts = m.group(1).split()
    else:
        parts = line.split()
    if len(parts) < 3:
        return None
    try:
        return float(parts[0]), float(parts[1]), float(parts[2])
    except ValueError:
        return None


def find_lagrangian_position_files(case_dir: Path) -> list[Path]:
    """Locate kinematicCloud position files under lagrangian/."""
    lagrangian = case_dir / "lagrangian"
    if not lagrangian.exists():
        return []
    files: list[Path] = []
    for cloud_dir in lagrangian.iterdir():
        if not cloud_dir.is_dir():
            continue
        for time_dir in sorted(cloud_dir.iterdir()):
            pos = time_dir / "positions"
            if pos.exists():
                files.append(pos)
    return files


def parse_positions_file(path: Path, default_mass: float) -> list[ParticleSnapshot]:
    """
    Parse OpenFOAM lagrangian positions file (simplified).

    Real OpenFOAM IO uses block structure; this parser handles common ASCII
  layouts with coordinate tuples. Extend for binary or cloudProperties coupling.
    """
    particles: list[ParticleSnapshot] = []
    time = float(path.parent.name) if path.parent.name.replace(".", "").isdigit() else 0.0

    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError as e:
        raise RuntimeError(f"Cannot read {path}: {e}") from e

  # Skip header until data block
    lines = text.splitlines()
    in_data = False
    for line in lines:
        stripped = line.strip()
        if stripped.startswith("(") and not in_data:
            in_data = True
        if not in_data:
            continue
        if stripped in ("(", ")"):
            continue
        vec = parse_openfoam_vector_line(stripped)
        if vec:
            x, y, z = vec
            particles.append(ParticleSnapshot(time=time, x=x, y=y, z=z, mass=default_mass))

    return particles


def extract_profile_at_distance(
    particles: list[ParticleSnapshot],
    cfg: ExtractorConfig,
    distance_m: float,
) -> VerticalProfileResult:
    """
    Bin airborne particles crossing vertical plane at regulatory distance d.

    Plane at x = FD + d (spec §2). Count particles with |x - x_plane| < half thickness.
    """
    x_plane = cfg.field_edge_offset_m + distance_m
    half = cfg.plane_thickness_m / 2.0
    edges = make_bin_edges(cfg.bin_width_m, cfg.max_height_m)
    n_bins = len(edges) - 1
    bin_masses = [0.0] * n_bins
    count = 0
    notes: list[str] = []

    for p in particles:
        if abs(p.x - x_plane) > half:
            continue
        if p.y < 0:
            continue  # below ground
        k = bin_index(p.y, edges)
        if k is None:
            continue
        bin_masses[k] += p.mass
        count += 1

    pct_bins = [mass_to_pct_iar(m, cfg) for m in bin_masses]
    total = sum(pct_bins)

    if count == 0:
        notes.append(f"No particles within plane thickness at x={x_plane:.3f} m")

    return VerticalProfileResult(
        distance_m=distance_m,
        bin_edges_m=edges,
        pct_iar_per_bin=pct_bins,
        total_airborne_pct_iar=total,
        particle_count=count,
        notes=notes,
    )


def compare_with_cdm_spec(results: list[VerticalProfileResult]) -> list[str]:
    """Sanity checks aligned with vertical-profile-spec.md §7 and reconcile_case_b.py."""
    warnings: list[str] = []
    totals = [(r.distance_m, r.total_airborne_pct_iar) for r in results]
    for i in range(len(totals) - 1):
        d1, t1 = totals[i]
        d2, t2 = totals[i + 1]
        if t1 + 1e-9 < t2:
            warnings.append(
                f"Monotonicity: totalAirborne at d={d1}m ({t1:.4g}%) "
                f"< d={d2}m ({t2:.4g}%) — check plane thickness / transients"
            )
    if totals and totals[-1][0] >= 30 and totals[-1][1] > 5.0:
        d_far, t_far = totals[-1]
        warnings.append(
            f"Far-field totalAirborne {t_far:.4g}% at d={d_far}m still high "
            "(spec expects near-zero beyond max drift for deposited fraction)"
        )
    warnings.append(
        "Do not compare totalAirborne to ground applume integral (spec section 1.2, 7.4)"
    )
    return warnings


def results_to_json(
    results: list[VerticalProfileResult],
    cfg: ExtractorConfig,
    source: str,
) -> dict:
    return {
        "source": source,
        "coordinateSystem": {
            "x": "downwind [m], origin at nozzle unless field_edge_offset applied",
            "y": "vertical [m] AGL",
            "z": "crosswind [m]",
            "regulatoryDistance": "m from field edge (spec §2)",
            "x_plane": "field_edge_offset_m + distance_m",
        },
        "normalization": {
            "metric": "pctIAR",
            "definition": "percent of intended application rate airborne in height bin",
            "applicationRate_kg_ha": cfg.application_rate_kg_ha,
            "sprayedArea_ha": cfg.sprayed_area_ha,
            "volumeSprayed_L": volume_sprayed_liters(cfg),
        },
        "binWidth_m": cfg.bin_width_m,
        "maxHeight_m": cfg.max_height_m,
        "profiles": [
            {
                "distance_m": r.distance_m,
                "binEdges_m": r.bin_edges_m,
                "bins": [
                    {"height_lo_m": r.bin_edges_m[k], "height_hi_m": r.bin_edges_m[k + 1], "pctIAR": r.pct_iar_per_bin[k]}
                    for k in range(len(r.pct_iar_per_bin))
                ],
                "totalAirborne_pctIAR": r.total_airborne_pct_iar,
                "particleCount": r.particle_count,
                "notes": r.notes,
            }
            for r in results
        ],
        "specAlignment": {
            "cdmDoc": "docs/vertical-profile-spec.md",
            "reconcileScript": "scripts/reconcile_case_b.py",
            "differences": [
                "OpenFOAM: full 3D turbulent two-phase CFD with MPPIC collisions",
                "CDM: trajectory ODEs with log-law wind and ψψψ plume spreading",
                "Mass per particle may be uniform default unless coupled to cloud diameters",
            ],
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Extract vertical airborne profiles from OpenFOAM Lagrangian data"
    )
    parser.add_argument("--case-dir", type=Path, required=True, help="OpenFOAM case directory")
    parser.add_argument(
        "--distances",
        type=float,
        nargs="+",
        default=[3, 5, 10, 20, 30, 50],
        help="Regulatory downwind distances from field edge [m]",
    )
    parser.add_argument(
        "--field-edge-offset",
        type=float,
        default=24.0,
        help="FD: downwind field depth / transport-to-output offset [m] (Case B = 24)",
    )
    parser.add_argument("--bin-width", type=float, default=0.25)
    parser.add_argument("--max-height", type=float, default=5.0)
    parser.add_argument("--plane-thickness", type=float, default=0.05)
    parser.add_argument("--application-rate", type=float, default=0.83886, help="IAR [kg/ha]")
    parser.add_argument("--sprayed-area-ha", type=float, default=0.1728, help="FD*PL in ha")
    parser.add_argument("--concentration-ai", type=float, default=0.0079761)
    parser.add_argument("--rho-l", type=float, default=1.0, help="Tank mix density [g/cm³]")
    parser.add_argument(
        "--default-particle-mass",
        type=float,
        default=1e-9,
        help="Mass per Lagrangian parcel if not read from diameters [kg]",
    )
    parser.add_argument("--output", type=Path, help="Write JSON results")
    parser.add_argument("--demo", action="store_true", help="Run with synthetic particles (no OpenFOAM data)")
    args = parser.parse_args()

    cfg = ExtractorConfig(
        case_dir=args.case_dir,
        distances_m=list(args.distances),
        field_edge_offset_m=args.field_edge_offset,
        bin_width_m=args.bin_width,
        max_height_m=args.max_height,
        plane_thickness_m=args.plane_thickness,
        application_rate_kg_ha=args.application_rate,
        sprayed_area_ha=args.sprayed_area_ha,
        concentration_ai=args.concentration_ai,
        rho_l_g_cm3=args.rho_l,
    )

    particles: list[ParticleSnapshot] = []
    source = "openfoam_lagrangian"

    if args.demo:
        source = "synthetic_demo"
        fd = cfg.field_edge_offset_m
        for d in cfg.distances_m:
            x_plane = fd + d
            for h in [0.5, 1.0, 1.5, 2.0]:
                particles.append(
                    ParticleSnapshot(
                        time=19.0, x=x_plane, y=h, z=0.0, mass=1e-7 / len(cfg.distances_m)
                    )
                )
    else:
        pos_files = find_lagrangian_position_files(args.case_dir)
        if not pos_files:
            print(
                f"No lagrangian position files under {args.case_dir}/lagrangian/\n"
                "Use --demo for synthetic output, or run OpenFOAM with cloud write enabled.",
                file=sys.stderr,
            )
            return 1
        for pf in pos_files:
            particles.extend(parse_positions_file(pf, args.default_particle_mass))
        source = f"openfoam:{pos_files[-1].parent}"

    results = [extract_profile_at_distance(particles, cfg, d) for d in cfg.distances_m]
    warnings = compare_with_cdm_spec(results)
    payload = results_to_json(results, cfg, source)

    print("Vertical profile extraction (OpenFOAM reference)")
    print(f"  particles: {len(particles)}")
    print(f"  distances: {cfg.distances_m}")
    print(f"  volumeSprayed: {volume_sprayed_liters(cfg):.6g} L (CDM normalization)")
    print()
    for r in results:
        print(
            f"  d={r.distance_m:5.1f} m : totalAirborne={r.total_airborne_pct_iar:.6g} % IAR "
            f"({r.particle_count} parcels in plane)"
        )
    print()
    print("Spec alignment checks:")
    for w in warnings:
        print(f"  NOTE: {w}")

    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(payload, indent=2), encoding="utf-8")
        print(f"\nWrote {args.output}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
