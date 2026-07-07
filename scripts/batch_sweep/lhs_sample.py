#!/usr/bin/env python3
"""
Generate Latin Hypercube sample space for CDM parameter sweeps.

Uses the canonical 8-parameter set from cdm_common.py (aligned with
sensitivity/run_sensitivity.py). For full analysis workflows, prefer:

    python scripts/batch_sweep/run_analysis.py lhs --samples 20 --cdm-cli ...

Usage:
    python scripts/batch_sweep/lhs_sample.py \\
        --samples 20 \\
        --output scripts/batch_sweep/samplespace.csv \\
        --seed 42

    python scripts/batch_sweep/lhs_sample.py \\
        --params wind_speed relative_humidity temperature \\
        --samples 30 --output samplespace_subset.csv
"""

from __future__ import annotations

import argparse
import csv
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from cdm_common import PARAMETERS, param_names_subset

DEFAULT_BASE_CASE = "tests/Case_B.json"


def lhs_unit(n_dim: int, n_samples: int, rng: random.Random) -> list[list[float]]:
    samples = [[0.0] * n_dim for _ in range(n_samples)]
    for j in range(n_dim):
        cuts = [i / n_samples for i in range(n_samples + 1)]
        points = [rng.uniform(cuts[i], cuts[i + 1]) for i in range(n_samples)]
        rng.shuffle(points)
        for i in range(n_samples):
            samples[i][j] = points[i]
    return samples


def main() -> int:
    parser = argparse.ArgumentParser(description="LHS sampling for CDM parameter sweeps")
    parser.add_argument("--samples", type=int, default=20)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument(
        "--params",
        nargs="+",
        help=f"Parameter keys (default: all {len(PARAMETERS)})",
    )
    parser.add_argument("--base-case", default=DEFAULT_BASE_CASE)
    args = parser.parse_args()

    if args.samples < 1:
        print("--samples must be >= 1", file=sys.stderr)
        return 1

    keys = param_names_subset(args.params)
    rng = random.Random(args.seed)
    unit = lhs_unit(len(keys), args.samples, rng)

    rows: list[dict] = []
    for i, unit_row in enumerate(unit, start=1):
        row: dict = {"run_id": i, "base_case": args.base_case}
        for j, key in enumerate(keys):
            info = PARAMETERS[key]
            row[key] = info["low"] + unit_row[j] * (info["high"] - info["low"])
        rows.append(row)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = ["run_id", "base_case"] + keys
    with args.output.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    print(f"Wrote {len(rows)} LHS samples to {args.output}")
    print(f"  parameters ({len(keys)}): {', '.join(keys)}")
    print(f"  base_case: {args.base_case}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
