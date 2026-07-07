#!/usr/bin/env python3
"""
Batch CDM runner for parameter sweeps (CSV-driven).

Reads a samplespace CSV (from lhs_sample.py, run_analysis.py lhs, or hand-authored),
applies parameter overrides, runs cdmcli in parallel, and aggregates deposition
metrics aligned with sensitivity/run_sensitivity.py.

Usage:
    python scripts/batch_sweep/batch_run.py \\
        --samplespace scripts/batch_sweep/samplespace.csv \\
        --output-dir scripts/batch_sweep/results

Uses pre-built cdmcli.exe by default (see cdm_common.DEFAULT_CDM_CLI).
"""

from __future__ import annotations

import argparse
import csv
import json
import sys
from concurrent.futures import ProcessPoolExecutor, as_completed
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from cdm_common import (
    EVAL_DISTANCES_M,
    PARAMETERS,
    apply_overrides,
    deposition_summary,
    extract_deposition,
    load_base_config,
    resolve_cdm_cli,
    run_cdm,
)

REPO_ROOT = Path(__file__).resolve().parents[2]


def read_samplespace(path: Path) -> tuple[list[str], list[dict]]:
    with path.open(newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        if reader.fieldnames is None:
            raise ValueError(f"Empty CSV: {path}")
        meta_cols = {"run_id", "base_case", "run_label", "level"}
        param_cols = [c for c in reader.fieldnames if c not in meta_cols]
        rows = list(reader)
    return param_cols, rows


def _run_single_file(
    run_id: str,
    config_path: Path,
    output_path: Path,
    cdm_cli: Path,
) -> tuple[str, int, str]:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    import subprocess

    result = subprocess.run(
        [str(cdm_cli), "-i", str(config_path), "-o", str(output_path)],
        capture_output=True,
        text=True,
        timeout=120,
        encoding="utf-8",
        errors="replace",
    )
    msg = result.stderr or result.stdout or ""
    return run_id, result.returncode, msg


def run_batch_from_rows(
    rows: list[dict],
    param_cols: list[str],
    base_case: Path,
    output_dir: Path,
    *,
    cdm_cli: Path | None = None,
    jobs: int = 4,
    dry_run: bool = False,
    compute_baseline: bool = True,
) -> int:
    """Core batch runner; also used by run_analysis.py lhs mode."""
    configs_dir = output_dir / "configs"
    outputs_dir = output_dir / "outputs"
    configs_dir.mkdir(parents=True, exist_ok=True)
    outputs_dir.mkdir(parents=True, exist_ok=True)

    case_name, base_config = load_base_config(base_case)
    baseline_dep: dict | None = None
    if compute_baseline and cdm_cli is not None and not dry_run:
        out = run_cdm(base_config, cdm_cli, output_dir=outputs_dir)
        if out is not None:
            baseline_dep = extract_deposition(out)
            baseline_dep["off_field"] = deposition_summary(out)["off_field_total"]

    jobs_list: list[tuple[str, Path, Path, dict]] = []
    for row in rows:
        run_id = str(row["run_id"])
        overrides = {
            col: float(row[col])
            for col in param_cols
            if row.get(col, "") not in ("", None)
        }
        cfg = apply_overrides(base_config, case_name, overrides)
        config_path = configs_dir / f"run_{run_id}.json"
        config_path.write_text(json.dumps(cfg, indent=2), encoding="utf-8")
        output_path = outputs_dir / f"run_{run_id}_out.json"
        jobs_list.append((run_id, config_path, output_path, row))

    if dry_run:
        print(f"Dry run: wrote {len(jobs_list)} configs to {configs_dir}")
        return 0

    if cdm_cli is None:
        try:
            cdm_cli = resolve_cdm_cli()
        except FileNotFoundError as e:
            print(e, file=sys.stderr)
            return 1

    failures: list[str] = []
    with ProcessPoolExecutor(max_workers=jobs) as pool:
        futures = {
            pool.submit(_run_single_file, run_id, cfg, out, cdm_cli): run_id
            for run_id, cfg, out, _ in jobs_list
        }
        for fut in as_completed(futures):
            run_id, rc, msg = fut.result()
            if rc != 0:
                failures.append(f"run_{run_id}: exit {rc}\n{msg[:500]}")

    dist_cols = [f"dep_{d:.0f}m" for d in EVAL_DISTANCES_M]
    pct_cols = [f"pct_change_{d:.0f}m" for d in EVAL_DISTANCES_M]
    fieldnames = (
        ["run_id", "base_case", "config", "output", "status"]
        + param_cols
        + dist_cols
        + pct_cols
        + ["off_field_total", "pct_change_off_field"]
    )

    summary_path = output_dir / "summary.csv"
    with summary_path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames, extrasaction="ignore")
        writer.writeheader()
        for run_id, cfg, out, row in jobs_list:
            record: dict = {
                "run_id": run_id,
                "base_case": str(base_case.relative_to(REPO_ROOT)),
                "config": str(cfg.relative_to(REPO_ROOT)),
                "output": str(out.relative_to(REPO_ROOT)),
                "status": "ok" if out.exists() else "failed",
            }
            for col in param_cols:
                record[col] = row.get(col, "")
            if out.exists():
                try:
                    raw = out.read_text(encoding="utf-8")
                    from cdm_common import strip_json_comments

                    data = json.loads(strip_json_comments(raw))
                    record.update(
                        deposition_summary(data, baseline_dep=baseline_dep)
                    )
                except (json.JSONDecodeError, KeyError) as e:
                    record["status"] = f"parse_error: {e}"
            writer.writerow(record)

    print(f"Wrote summary to {summary_path}")
    if failures:
        print(f"{len(failures)} run(s) failed:", file=sys.stderr)
        for msg in failures[:5]:
            print(msg, file=sys.stderr)
        return 1
    print(f"All {len(jobs_list)} runs completed successfully")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Batch CDM parameter sweep runner")
    parser.add_argument("--samplespace", type=Path, required=True)
    parser.add_argument(
        "--base-case",
        type=Path,
        default=None,
        help="Override base case (default: from CSV base_case column or Case_B)",
    )
    parser.add_argument(
        "--cdm-cli",
        type=Path,
        help="Path to cdmcli (default: pre-built CDM 1.2.0 release, see cdm_common.DEFAULT_CDM_CLI)",
    )
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--jobs", type=int, default=4)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument(
        "--no-baseline",
        action="store_true",
        help="Skip baseline run (no pct_change columns)",
    )
    args = parser.parse_args()

    param_cols, rows = read_samplespace(args.samplespace)
    if args.base_case:
        base_case = args.base_case
    elif rows and rows[0].get("base_case"):
        rel = rows[0]["base_case"]
        base_case = REPO_ROOT / rel if not Path(rel).is_absolute() else Path(rel)
    else:
        base_case = REPO_ROOT / "tests" / "Case_B.json"

    unknown = set(param_cols) - set(PARAMETERS)
    if unknown:
        print(
            f"Warning: CSV columns not in PARAMETERS: {sorted(unknown)}",
            file=sys.stderr,
        )

    return run_batch_from_rows(
        rows,
        param_cols,
        base_case,
        args.output_dir,
        cdm_cli=args.cdm_cli,
        jobs=args.jobs,
        dry_run=args.dry_run,
        compute_baseline=not args.no_baseline,
    )


if __name__ == "__main__":
    sys.exit(main())
