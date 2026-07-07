#!/usr/bin/env python3
"""
CDM sensitivity and parameter-sweep orchestrator.

Implements the same analysis modes as sensitivity/run_sensitivity.py using
shared conventions in cdm_common.py:

  oat          — one-at-a-time low/high perturbation (+ tornado plots)
  sweep        — 1D response curves for selected parameters
  interaction  — two-factor grid (deposition at 10 m)
  lhs          — Latin Hypercube sample + batch run

Usage:
    python scripts/batch_sweep/run_analysis.py oat \\
        --output-dir scripts/batch_sweep/results

    python scripts/batch_sweep/run_analysis.py sweep --params wind_speed relative_humidity

    python scripts/batch_sweep/run_analysis.py interaction \\
        --param-a wind_speed --param-b relative_humidity

    python scripts/batch_sweep/run_analysis.py lhs --samples 20 --jobs 4

Uses pre-built cdmcli.exe by default (see cdm_common.DEFAULT_CDM_CLI).
Pass --cdm-cli only when using a local build or alternate install.
"""

from __future__ import annotations

import argparse
import csv
import random
import sys
from pathlib import Path

# Allow sibling imports when invoked as scripts/batch_sweep/run_analysis.py
sys.path.insert(0, str(Path(__file__).resolve().parent))

from cdm_common import (
    DEFAULT_FIELD_DEPTH_M,
    EVAL_DISTANCES_M,
    PARAMETERS,
    apply_overrides,
    deposition_summary,
    extract_deposition,
    label_to_param_key,
    load_base_config,
    param_names_subset,
    resolve_cdm_cli,
    run_cdm,
)

REPO_ROOT = Path(__file__).resolve().parents[2]


def _require_cdm_cli(path: Path | None) -> Path:
    try:
        resolved = resolve_cdm_cli(path)
        print(f"Using cdmcli: {resolved}")
        return resolved
    except FileNotFoundError as e:
        print(e, file=sys.stderr)
        sys.exit(1)


def _write_csv(path: Path, fieldnames: list[str], rows: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


def _baseline_dep(case_name: str, config: dict, cdm_cli: Path, output_dir: Path) -> dict:
    out = run_cdm(config, cdm_cli, output_dir=output_dir / "baseline")
    if out is None:
        raise RuntimeError("Baseline CDM run failed")
    dep = extract_deposition(out)
    dep["off_field"] = deposition_summary(out)["off_field_total"]
    return dep


def cmd_oat(args: argparse.Namespace) -> int:
    cdm_cli = _require_cdm_cli(args.cdm_cli)
    output_dir = args.output_dir
    output_dir.mkdir(parents=True, exist_ok=True)

    case_name, config = load_base_config(args.base_case)
    print("Running baseline...")
    base_dep = _baseline_dep(case_name, config, cdm_cli, output_dir)
    print(f"  Baseline @10m: {base_dep.get(10.0, float('nan')):.4f} % IAR")

    rows: list[dict] = []
    for key, info in PARAMETERS.items():
        for level, value in (("low", info["low"]), ("high", info["high"])):
            cfg = apply_overrides(config, case_name, {key: value})
            out = run_cdm(cfg, cdm_cli, output_dir=output_dir / "oat")
            if out is None:
                print(f"  FAILED {info['label']} {level}")
                continue
            summary = deposition_summary(out, baseline_dep=base_dep)
            row = {
                "parameter": info["label"],
                "param_key": key,
                "level": level,
                "value": value,
                "unit": info["unit"],
            }
            for d in EVAL_DISTANCES_M:
                row[f"dep_{d:.0f}m"] = summary[f"dep_{d:.0f}m"]
                row[f"pct_change_{d:.0f}m"] = summary.get(f"pct_change_{d:.0f}m")
            row["off_field_total"] = summary["off_field_total"]
            row["pct_change_off_field"] = summary.get("pct_change_off_field")
            rows.append(row)
            print(f"  {info['label']} {level}: dep@10m={row['dep_10m']:.4f}")

    fieldnames = (
        ["parameter", "param_key", "level", "value", "unit"]
        + [f"dep_{d:.0f}m" for d in EVAL_DISTANCES_M]
        + [f"pct_change_{d:.0f}m" for d in EVAL_DISTANCES_M]
        + ["off_field_total", "pct_change_off_field"]
    )
    _write_csv(output_dir / "oat_results.csv", fieldnames, rows)

    if args.plot:
        _plot_tornado(rows, output_dir)
    print(f"OAT complete → {output_dir / 'oat_results.csv'}")
    return 0


def cmd_sweep(args: argparse.Namespace) -> int:
    cdm_cli = _require_cdm_cli(args.cdm_cli)
    output_dir = args.output_dir
    output_dir.mkdir(parents=True, exist_ok=True)

    keys = param_names_subset(args.params)
    case_name, config = load_base_config(args.base_case)

    for key in keys:
        info = PARAMETERS[key]
        values = [
            info["low"] + (info["high"] - info["low"]) * i / (args.points - 1)
            for i in range(args.points)
        ]
        rows: list[dict] = []
        print(f"Sweeping {info['label']}...")
        for val in values:
            cfg = apply_overrides(config, case_name, {key: val})
            out = run_cdm(cfg, cdm_cli, output_dir=output_dir / "sweeps")
            if out is None:
                continue
            summary = deposition_summary(out)
            row = {
                "parameter": info["label"],
                "param_key": key,
                "value": val,
                "unit": info["unit"],
                "off_field_total": summary["off_field_total"],
            }
            for d in EVAL_DISTANCES_M:
                row[f"dep_{d:.0f}m"] = summary[f"dep_{d:.0f}m"]
            rows.append(row)

        fieldnames = ["parameter", "param_key", "value", "unit", "off_field_total"] + [
            f"dep_{d:.0f}m" for d in EVAL_DISTANCES_M
        ]
        _write_csv(output_dir / f"sweep_{key}.csv", fieldnames, rows)

    if args.plot:
        _plot_sweeps(output_dir, keys)
    print(f"Sweeps complete → {output_dir}")
    return 0


def cmd_interaction(args: argparse.Namespace) -> int:
    cdm_cli = _require_cdm_cli(args.cdm_cli)
    output_dir = args.output_dir
    output_dir.mkdir(parents=True, exist_ok=True)

    info_a = PARAMETERS[args.param_a]
    info_b = PARAMETERS[args.param_b]
    vals_a = [
        info_a["low"] + (info_a["high"] - info_a["low"]) * i / (args.grid - 1)
        for i in range(args.grid)
    ]
    vals_b = [
        info_b["low"] + (info_b["high"] - info_b["low"]) * i / (args.grid - 1)
        for i in range(args.grid)
    ]

    case_name, config = load_base_config(args.base_case)
    rows: list[dict] = []
    print(f"Interaction {info_a['label']} x {info_b['label']}...")
    for va in vals_a:
        for vb in vals_b:
            cfg = apply_overrides(
                config, case_name, {args.param_a: va, args.param_b: vb}
            )
            out = run_cdm(cfg, cdm_cli, output_dir=output_dir / "interactions")
            dep_10 = float("nan")
            if out is not None:
                dep_10 = extract_deposition(out, (10.0,))[10.0]
            rows.append({
                "param_a": info_a["label"],
                "param_b": info_b["label"],
                "value_a": va,
                "value_b": vb,
                "dep_10m": dep_10,
            })

    fname = f"interaction_{args.param_a}_{args.param_b}.csv"
    _write_csv(
        output_dir / fname,
        ["param_a", "param_b", "value_a", "value_b", "dep_10m"],
        rows,
    )

    if args.plot:
        _plot_interaction(rows, info_a["label"], info_b["label"], output_dir, fname)
    print(f"Interaction complete → {output_dir / fname}")
    return 0


def lhs_unit(n_dim: int, n_samples: int, seed: int) -> list[list[float]]:
    rng = random.Random(seed)
    samples = [[0.0] * n_dim for _ in range(n_samples)]
    for j in range(n_dim):
        cuts = [i / n_samples for i in range(n_samples + 1)]
        points = [rng.uniform(cuts[i], cuts[i + 1]) for i in range(n_samples)]
        rng.shuffle(points)
        for i in range(n_samples):
            samples[i][j] = points[i]
    return samples


def cmd_lhs(args: argparse.Namespace) -> int:
    from batch_run import run_batch_from_rows  # noqa: WPS433 — sibling import

    keys = param_names_subset(args.params)
    output_dir = args.output_dir
    samplespace = output_dir / "samplespace.csv"

    unit = lhs_unit(len(keys), args.samples, args.seed)
    rows: list[dict] = []
    for i, unit_row in enumerate(unit, start=1):
        row: dict = {"run_id": i, "base_case": str(args.base_case.relative_to(REPO_ROOT))}
        for j, key in enumerate(keys):
            info = PARAMETERS[key]
            row[key] = info["low"] + unit_row[j] * (info["high"] - info["low"])
        rows.append(row)

    fieldnames = ["run_id", "base_case"] + keys
    _write_csv(samplespace, fieldnames, rows)
    print(f"Wrote {len(rows)} LHS samples → {samplespace}")

    if args.dry_run:
        return run_batch_from_rows(
            rows, keys, args.base_case, output_dir, cdm_cli=None, dry_run=True
        )

    cdm_cli = _require_cdm_cli(args.cdm_cli)
    return run_batch_from_rows(
        rows, keys, args.base_case, output_dir, cdm_cli=cdm_cli, jobs=args.jobs
    )


def _plot_tornado(rows: list[dict], output_dir: Path) -> None:
    try:
        import matplotlib.pyplot as plt
    except ImportError:
        print("matplotlib not installed; skipping tornado plots")
        return

    params = sorted({r["parameter"] for r in rows})
    low_vals, high_vals = [], []
    for p in params:
        sub = [r for r in rows if r["parameter"] == p]
        low = next((r["pct_change_10m"] for r in sub if r["level"] == "low"), 0)
        high = next((r["pct_change_10m"] for r in sub if r["level"] == "high"), 0)
        low_vals.append(low)
        high_vals.append(high)

    order = sorted(range(len(params)), key=lambda i: max(abs(low_vals[i]), abs(high_vals[i])))
    params = [params[i] for i in order]
    low_vals = [low_vals[i] for i in order]
    high_vals = [high_vals[i] for i in order]

    fig, ax = plt.subplots(figsize=(10, 6))
    y_pos = range(len(params))
    ax.barh(list(y_pos), low_vals, height=0.4, color="#4393c3", label="Low")
    ax.barh(list(y_pos), high_vals, height=0.4, color="#d6604d", label="High")
    ax.set_yticks(list(y_pos))
    ax.set_yticklabels(params)
    ax.set_xlabel("Change in Deposition (%)")
    ax.set_title("Sensitivity of Deposition at 10 m (OAT)")
    ax.axvline(0, color="black", linewidth=0.5)
    ax.legend()
    plt.tight_layout()
    plt.savefig(output_dir / "tornado_10m.png", dpi=150)
    plt.close()
    print(f"  Saved {output_dir / 'tornado_10m.png'}")


def _plot_sweeps(output_dir: Path, keys: list[str]) -> None:
    try:
        import matplotlib.pyplot as plt
    except ImportError:
        return

    fig, axes = plt.subplots(2, 2, figsize=(12, 10))
    axes_flat = axes.flatten()
    for i, key in enumerate(keys[:4]):
        path = output_dir / f"sweep_{key}.csv"
        if not path.exists():
            continue
        with path.open(encoding="utf-8") as f:
            rows = list(csv.DictReader(f))
        if not rows:
            continue
        ax = axes_flat[i]
        x = [float(r["value"]) for r in rows]
        for d in EVAL_DISTANCES_M:
            col = f"dep_{d:.0f}m"
            y = [float(r[col]) for r in rows]
            ax.plot(x, y, "o-", label=f"{d:.0f} m", markersize=3)
        ax.set_xlabel(f"{rows[0]['parameter']} ({rows[0]['unit']})")
        ax.set_ylabel("Deposition (% IAR)")
        ax.legend(fontsize=8)
        ax.grid(True, alpha=0.3)
    plt.suptitle("Parameter Response Curves")
    plt.tight_layout()
    plt.savefig(output_dir / "response_curves.png", dpi=150)
    plt.close()


def _plot_interaction(
    rows: list[dict], label_a: str, label_b: str, output_dir: Path, fname: str
) -> None:
    try:
        import matplotlib.pyplot as plt
        import seaborn as sns
    except ImportError:
        return

    vals_a = sorted({round(float(r["value_a"]), 4) for r in rows})
    vals_b = sorted({round(float(r["value_b"]), 4) for r in rows})
    grid = { (round(float(r["value_a"]), 4), round(float(r["value_b"]), 4)): float(r["dep_10m"]) for r in rows }
    import numpy as np
    matrix = np.array([[grid.get((a, b), float("nan")) for a in vals_a] for b in vals_b])

    fig, ax = plt.subplots(figsize=(9, 7))
    sns.heatmap(matrix, annot=True, fmt=".2f", cmap="RdYlBu_r", ax=ax,
                xticklabels=[f"{v:.2g}" for v in vals_a],
                yticklabels=[f"{v:.2g}" for v in vals_b])
    ax.set_title(f"Interaction: {label_a} x {label_b}")
    ax.set_xlabel(label_a)
    ax.set_ylabel(label_b)
    plt.tight_layout()
    out = output_dir / fname.replace(".csv", ".png")
    plt.savefig(out, dpi=150)
    plt.close()


def main() -> int:
    parser = argparse.ArgumentParser(description="CDM sensitivity analysis runner")
    parser.add_argument(
        "--base-case",
        type=Path,
        default=REPO_ROOT / "tests" / "Case_B.json",
    )
    parser.add_argument(
        "--cdm-cli",
        type=Path,
        help="Path to cdmcli (default: pre-built CDM 1.2.0 release, see cdm_common.DEFAULT_CDM_CLI)",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=REPO_ROOT / "scripts" / "batch_sweep" / "results",
    )
    parser.add_argument("--plot", action="store_true", help="Write PNG plots (needs matplotlib)")

    sub = parser.add_subparsers(dest="mode", required=True)

    sub.add_parser("oat", help="One-at-a-time sensitivity")

    p_sweep = sub.add_parser("sweep", help="1D parameter response curves")
    p_sweep.add_argument("--params", nargs="+", help="Parameter keys (default: top 4 from OAT if omitted)")
    p_sweep.add_argument("--points", type=int, default=15)

    p_int = sub.add_parser("interaction", help="Two-factor interaction grid")
    p_int.add_argument("--param-a", default="wind_speed")
    p_int.add_argument("--param-b", default="relative_humidity")
    p_int.add_argument("--grid", type=int, default=8)

    p_lhs = sub.add_parser("lhs", help="Latin Hypercube sampling + batch run")
    p_lhs.add_argument("--samples", type=int, default=20)
    p_lhs.add_argument("--seed", type=int, default=42)
    p_lhs.add_argument("--params", nargs="+", help="Parameter keys (default: all 8)")
    p_lhs.add_argument("--jobs", type=int, default=4)
    p_lhs.add_argument("--dry-run", action="store_true")

    args = parser.parse_args()

    if args.mode == "oat":
        return cmd_oat(args)
    if args.mode == "sweep":
        if not args.params:
            args.params = [
                "relative_humidity", "canopy_height", "wind_speed", "nozzle_height"
            ]
        return cmd_sweep(args)
    if args.mode == "interaction":
        return cmd_interaction(args)
    if args.mode == "lhs":
        return cmd_lhs(args)
    return 1


if __name__ == "__main__":
    sys.exit(main())
