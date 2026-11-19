#!/usr/bin/env python3
"""Export a cdmcli run — deposition plus vertical profile — into shareable files.

Reads the JSON written by `cdmcli -o` and emits, next to it or in --outdir:

  <prefix>_vertical_profile.csv  tidy one-row-per-bin table (Excel friendly)
  <prefix>_deposition.csv        ground deposition curve
  <prefix>_export.json           compact self-describing JSON, matrices per method
  <prefix>_report.txt            human-readable summary

Usage:
    python scripts/export_vertical_profile.py runs/FR_1_018/output.json
    python scripts/export_vertical_profile.py out.json -o share --formats csv txt
"""

from __future__ import annotations

import argparse
import csv
import json
from datetime import datetime, timezone
from pathlib import Path

# cdmcli key -> label used in every export
METHODS = {
    "resultsByDistanceCellCrossing": "cellCrossingMultiNozzle",
    "resultsByDistanceCellCrossingSingleNozzle": "cellCrossingSingleNozzle",
    "resultsByDistancePlaneCrossing": "planeCrossingMultiNozzle",
    "resultsByDistancePlaneCrossingSingleNozzle": "planeCrossingSingleNozzle",
}

METHOD_NOTE = (
    "planeCrossingMultiNozzle is the regulatory %IAR metric: each trajectory is "
    "counted once, at the height where it crosses the measurement plane. The "
    "cellCrossing* variants attribute the full class weight to every height bin a "
    "trajectory passes through, so near-field values are inflated - keep them for "
    "diagnostics only. The SingleNozzle variants put the whole field volume on one "
    "nozzle and are likewise diagnostic, not a Case B answer."
)

STANDARD_DISTANCES_M = (0, 1, 3, 5, 10, 20, 30, 50)


def load_results(path: Path) -> tuple[str, dict]:
    """Return (case name, case body). cdmcli writes ["Case", {...}]."""
    with path.open(encoding="utf-8") as f:
        root = json.load(f)
    if isinstance(root, list) and len(root) == 2 and isinstance(root[1], dict):
        return str(root[0]), root[1]
    if isinstance(root, dict):
        if "output" in root:
            return path.stem, root
        if len(root) == 1:
            name, body = next(iter(root.items()))
            return name, body
    raise SystemExit(f"Unrecognized JSON structure in {path}")


def grid_from_columns(columns: list[dict]) -> dict:
    """Flatten one method into distances, height edges and [nHeight][nDistance] matrices."""
    if not columns:
        raise SystemExit("empty vertical profile column list")
    distances = [float(c["distance"]) for c in columns]
    bins0 = columns[0]["bins"]
    # Height grids usually start at 0.0 with a degenerate zero-thickness bin.
    keep = [i for i, b in enumerate(bins0) if b["height"] > b["previousHeight"]]
    lowers = [float(bins0[i]["previousHeight"]) for i in keep]
    uppers = [float(bins0[i]["height"]) for i in keep]

    pct = [[float(col["bins"][i]["percentApplied"]) for col in columns] for i in keep]
    hits = [[int(col["bins"][i].get("hitCount", 0)) for col in columns] for i in keep]
    column_sum = [sum(row[j] for row in pct) for j in range(len(distances))]
    return {
        "distances_m": distances,
        "heightLower_m": lowers,
        "heightUpper_m": uppers,
        "pctIAR": pct,
        "hitCount": hits,
        "columnAirborne_pctIAR": column_sum,
    }


def collect_conditions(case: dict) -> dict:
    transport = case.get("dropletTransport", {})
    dep_in = case.get("deposition", {})
    wind = case.get("windVelocityProfile", {})
    measurements = wind.get("velocityMeasurements") or [[None, None]]
    out = case.get("output", {})
    return {
        "dryAirTemperature_C": case.get("dryAirTemperature"),
        "relativeHumidity_pct": case.get("relativeHumidity"),
        "barometricPressure_Pa": case.get("barometricPressure"),
        "windMeasurementHeight_m": measurements[0][0],
        "windSpeed_m_s": measurements[0][1],
        "horizontalVariation_deg": wind.get("horizontalVariation"),
        "nozzleHeight_m": transport.get("nozzleHeight"),
        "canopyHeight_m": transport.get("canopyHeight"),
        "nozzlePressure_Pa": transport.get("nozzlePressure"),
        "nozzleSpacing_m": dep_in.get("nozzleSpacing"),
        "applicationRate": dep_in.get("applicationRate"),
        "downwindFieldDepth_m": dep_in.get("downwindFieldDepth"),
        "crosswindFieldDepth_m": dep_in.get("crosswindFieldDepth"),
        "maxDriftDistance_m": dep_in.get("maxDriftDistance"),
        "frictionVelocity_m_s": out.get("frictionVelocity"),
        "frictionHeight_m": out.get("frictionHeight"),
        "wetBulbTemperature_C": out.get("wetBulbTemperature"),
    }


def deposition_pairs(case: dict) -> list[tuple[float, float]]:
    dep = case.get("output", {}).get("deposition") or []
    return [(float(d), float(v)) for d, v in dep]


def nearest(pairs: list[tuple[float, float]], target: float) -> float | None:
    if not pairs:
        return None
    return min(pairs, key=lambda p: abs(p[0] - target))[1]


def write_vp_csv(path: Path, grids: dict[str, dict]) -> None:
    with path.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(
            ["method", "distance_m", "height_lower_m", "height_upper_m", "pct_iar", "hit_count"]
        )
        for method, g in grids.items():
            for i, (lo, hi) in enumerate(zip(g["heightLower_m"], g["heightUpper_m"])):
                for j, dist in enumerate(g["distances_m"]):
                    w.writerow(
                        [method, dist, lo, hi, f"{g['pctIAR'][i][j]:.6g}", g["hitCount"][i][j]]
                    )


def write_deposition_csv(path: Path, pairs: list[tuple[float, float]]) -> None:
    with path.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["distance_m", "deposition_pct_iar"])
        for dist, val in pairs:
            w.writerow([dist, f"{val:.6g}"])


def write_report(
    path: Path,
    case_name: str,
    source: Path,
    conditions: dict,
    pairs: list[tuple[float, float]],
    grids: dict[str, dict],
) -> None:
    lines: list[str] = []
    add = lines.append
    add(f"CDM run export - {case_name}")
    add(f"source:    {source}")
    add(f"generated: {datetime.now(timezone.utc):%Y-%m-%d %H:%M} UTC")
    add("")
    add("Run conditions")
    add("-" * 60)
    for key, value in conditions.items():
        if value is not None:
            shown = f"{value:.6g}" if isinstance(value, float) else value
            add(f"  {key:<28} {shown}")

    if pairs:
        add("")
        add("Ground deposition (% of intended application rate)")
        add("-" * 60)
        for target in STANDARD_DISTANCES_M:
            value = nearest(pairs, float(target))
            if value is not None:
                add(f"  {target:>4} m   {value:10.4f}")

    if grids:
        add("")
        add("Airborne vertical profile - column sum %IAR by distance")
        add("-" * 60)
        methods = list(grids)
        first = grids[methods[0]]
        header_span = first["heightUpper_m"][-1] if first["heightUpper_m"] else 0.0
        add(f"  (summed over height bins up to {header_span:g} m)")
        add("")
        width = max(len(m) for m in methods) + 3
        add("  dist_m" + "".join(f"{m:>{width}}" for m in methods))
        for j, dist in enumerate(first["distances_m"]):
            row = "".join(f"{grids[m]['columnAirborne_pctIAR'][j]:>{width}.4f}" for m in methods)
            add(f"  {dist:>6g}" + row)
        add("")
        add("Note")
        add("-" * 60)
        for chunk in METHOD_NOTE.split(". "):
            add(f"  {chunk.strip().rstrip('.')}.")

    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("json_path", type=Path, help="cdmcli output JSON")
    ap.add_argument("-o", "--outdir", type=Path, default=None, help="Output directory (default: alongside input)")
    ap.add_argument("--prefix", default=None, help="Base name for exported files (default: case name)")
    ap.add_argument(
        "--formats",
        nargs="+",
        choices=("json", "csv", "txt"),
        default=["json", "csv", "txt"],
        help="Which exports to write (default: all)",
    )
    args = ap.parse_args()

    case_name, case = load_results(args.json_path)
    outdir = args.outdir or args.json_path.parent
    outdir.mkdir(parents=True, exist_ok=True)
    prefix = args.prefix or case_name

    vp = case.get("output", {}).get("verticalProfile") or {}
    grids: dict[str, dict] = {}
    for key, label in METHODS.items():
        columns = vp.get(key)
        if columns:
            grids[label] = grid_from_columns(columns)
    if not grids:
        print("WARNING: no vertical profile in this run - exporting deposition only.")
        print("         Use an input that sets verticalProfile.heights / .distances,")
        print("         e.g. tests/Case_B_vertical_profile_distances.json")

    conditions = collect_conditions(case)
    pairs = deposition_pairs(case)
    written: list[Path] = []

    if "csv" in args.formats:
        if grids:
            path = outdir / f"{prefix}_vertical_profile.csv"
            write_vp_csv(path, grids)
            written.append(path)
        if pairs:
            path = outdir / f"{prefix}_deposition.csv"
            write_deposition_csv(path, pairs)
            written.append(path)

    if "json" in args.formats:
        payload = {
            "schema": "cdm-run-export/1",
            "case": case_name,
            "source": str(args.json_path),
            "generated_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
            "conditions": conditions,
            "deposition": {
                "distances_m": [d for d, _ in pairs],
                "pctIAR": [v for _, v in pairs],
            },
            "verticalProfile": {
                "note": METHOD_NOTE,
                "matrixLayout": "pctIAR[heightBin][distance]; heights ascending",
                "methods": grids,
            },
        }
        path = outdir / f"{prefix}_export.json"
        path.write_text(json.dumps(payload, indent=2), encoding="utf-8")
        written.append(path)

    if "txt" in args.formats:
        path = outdir / f"{prefix}_report.txt"
        write_report(path, case_name, args.json_path, conditions, pairs, grids)
        written.append(path)

    for path in written:
        print(f"wrote {path}  ({path.stat().st_size / 1024:.1f} KB)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
