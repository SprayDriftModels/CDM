#!/usr/bin/env python3
"""
Minimal Case B reconciliation for vertical-profile spec validation.

Ground deposition checks (applume) run today. Vertical profile checks activate
when --vertical-profile-json points to a verticalDriftProfile export.

Usage:
    cdm -i tests/Case_B.json -o /tmp/case_b_out.json
    python scripts/reconcile_case_b.py --output-json /tmp/case_b_out.json

    python scripts/reconcile_case_b.py --cdm-cli build/Release/cdm.exe
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
CASE_B = REPO_ROOT / "tests" / "Case_B.json"
STANDARD_DISTANCES_M = (3, 5, 10, 20, 30, 50)


def strip_json_comments(text: str) -> str:
    """Remove // line comments (CDM input JSON allows them; stdlib json does not)."""
    return re.sub(r"//.*?$", "", text, flags=re.MULTILINE)


def load_cdm_input(path: Path) -> tuple[str, dict]:
    raw = strip_json_comments(path.read_text(encoding="utf-8"))
    data = json.loads(raw)
    case_name = next(iter(data))
    return case_name, data[case_name]


def mixture_density(rho_w: float, rho_s: float, xs0: float) -> float:
    return 1.0 / (xs0 / rho_s + (1.0 - xs0) / rho_w)


def volume_sprayed_liters(case: dict) -> float:
    dep = case["deposition"]
    dt = case["dropletTransport"]
    iar = dep["applicationRate"]
    xactive = dep["concentrationAI"]
    fd = dep["downwindFieldDepth"]
    pl = dep["crosswindFieldDepth"]
    rho_l = mixture_density(dt["waterDensity"], dt["solidsDensity"], dt["solidsFraction"])
    sprayed_area_ha = 1e-4 * fd * pl
    return iar * sprayed_area_ha / (rho_l * xactive)


def run_cdm(cdm_cli: Path, input_json: Path, output_json: Path) -> None:
    output_json.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        [str(cdm_cli), "-i", str(input_json), "-o", str(output_json)],
        check=True,
    )


def parse_deposition_curve(output: dict) -> list[tuple[float, float]]:
    pairs = output["deposition"]
    return [(float(d), float(p)) for d, p in pairs]


def interp_at(distances: list[float], values: list[float], x: float) -> float:
    if x <= distances[0]:
        return values[0]
    if x >= distances[-1]:
        return values[-1]
    for i in range(len(distances) - 1):
        if distances[i] <= x <= distances[i + 1]:
            t = (x - distances[i]) / (distances[i + 1] - distances[i])
            return values[i] + t * (values[i + 1] - values[i])
    return values[-1]


def trapezoid_integral(xs: list[float], ys: list[float]) -> float:
    total = 0.0
    for i in range(len(xs) - 1):
        total += 0.5 * (ys[i] + ys[i + 1]) * (xs[i + 1] - xs[i])
    return total


def cumulative_trapezoid(xs: list[float], ys: list[float]) -> list[float]:
    out = [0.0]
    for i in range(len(xs) - 1):
        out.append(out[-1] + 0.5 * (ys[i] + ys[i + 1]) * (xs[i + 1] - xs[i]))
    return out


def check_vertical_profile(vp: dict) -> list[str]:
    """Return list of failure messages (empty if all checks pass)."""
    failures: list[str] = []
    profiles = vp.get("profiles", [])
    if not profiles:
        return ["verticalDriftProfile.profiles is empty"]

    totals = [(p["distance_m"], p.get("totalAirborne_pctIAR")) for p in profiles]
    totals = [(d, t) for d, t in totals if t is not None]
    if not totals:
        for p in profiles:
            bins = p.get("bins") or p.get("pctIAR")
            if bins is not None:
                if isinstance(bins[0], dict):
                    total = sum(b.get("pctIAR", 0) for b in bins)
                else:
                    total = sum(bins)
                totals.append((p["distance_m"], total))

    for i in range(len(totals) - 1):
        d1, t1 = totals[i]
        d2, t2 = totals[i + 1]
        if t1 + 1e-9 < t2:
            failures.append(
                f"monotonic totalAirborne failed: d={d1} ({t1:.6g}%) "
                f"> d={d2} ({t2:.6g}%)"
            )

    if totals and totals[-1][0] >= 30 and totals[-1][1] > 0.05:
        d_far, t_far = totals[-1]
        failures.append(
            f"far-field totalAirborne still {t_far:.4g}% at d={d_far} m "
            "(expect near zero beyond max drift; verify distance and normalization)"
        )

    return failures


def main() -> int:
    parser = argparse.ArgumentParser(description="Case B vertical-profile reconciliation")
    parser.add_argument("--input-json", type=Path, default=CASE_B)
    parser.add_argument("--output-json", type=Path, help="CDM run output JSON")
    parser.add_argument("--cdm-cli", type=Path, help="Path to cdm executable (runs model if no output)")
    parser.add_argument("--vertical-profile-json", type=Path, help="Optional verticalDriftProfile JSON")
    args = parser.parse_args()

    case_name, case = load_cdm_input(args.input_json)
    dep_cfg = case["deposition"]
    fd = dep_cfg["downwindFieldDepth"]
    dx = dep_cfg.get("outputInterval", 0.5)
    vol = volume_sprayed_liters(case)
    nsa = int(fd / dep_cfg["nozzleSpacing"])

    output_json = args.output_json
    if output_json is None:
        if args.cdm_cli is None:
            print("Provide --output-json or --cdm-cli", file=sys.stderr)
            return 1
        output_json = REPO_ROOT / "build" / "case_b_out.json"
        run_cdm(args.cdm_cli, args.input_json, output_json)

    out_data = json.loads(strip_json_comments(output_json.read_text(encoding="utf-8")))
    case_out = out_data[case_name]["output"]
    curve = parse_deposition_curve(case_out)
    dists = [d for d, _ in curve]
    pcts = [p for _, p in curve]

    drift_mask = [d > 0 for d in dists]
    drift_d = [d for d, m in zip(dists, drift_mask) if m]
    drift_p = [p for p, m in zip(pcts, drift_mask) if m]

    print(f"Case: {case_name}")
    print(f"  downwindFieldDepth (FD)     = {fd} m")
    print(f"  outputInterval (dx)         = {dx} m")
    print(f"  Nsa (FD / nozzleSpacing)    = {nsa}")
    print(f"  volumeSprayed (computed)    = {vol:.6g} L")
    print(f"  dsdCurveFitting (input)     = {dep_cfg.get('dsdCurveFitting')}")
    print(f"  plane at field edge: X = FD + d  (transport X = {fd} m + d)")
    print()

    print("Ground deposition (applume) at standard distances:")
    for sd in STANDARD_DISTANCES_M:
        if sd <= dists[-1]:
            print(f"  d = {sd:5.1f} m : {interp_at(dists, pcts, sd):.6g} % IAR")
    print()

    if drift_d:
        cum = cumulative_trapezoid(drift_d, drift_p)
        integral = cum[-1]
        print("Downwind ground drift (trapezoidal integral of applume, d > 0):")
        print(f"  approximate integral        = {integral:.6g} (%·m)")
        print(f"  max downwind deposition     = {max(drift_p):.6g} % IAR at d = {drift_d[drift_p.index(max(drift_p))]:.4g} m")
        print()
        print("  Note: applume(d) is ground deposition at d, not airborne mass.")
        print("  Do not compare to totalAirborne(d) from vertical profiles (spec §7.4).")
        print()

    print("Open spec issues to verify (see docs/vertical-profile-spec.md §14):")
    print("  V-1  pctIAR normalization vs propAppliedPlume")
    print("  V-2  23-point transport grid vs dpavg 0.5 µm SVP grid")
    print("  V-3  SVP/Nsa weight sum vs volumeSprayed denominator")
    print()

    vp_path = args.vertical_profile_json
    if vp_path is None and output_json:
        nested = out_data[case_name].get("verticalDriftProfile")
        if nested:
            vp_path = "inline"

    vp = None
    if vp_path == "inline":
        vp = out_data[case_name].get("verticalDriftProfile")
    elif vp_path is not None:
        vp = json.loads(vp_path.read_text(encoding="utf-8"))

    if vp:
        print("Vertical profile checks:")
        failures = check_vertical_profile(vp)
        if failures:
            for msg in failures:
                print(f"  FAIL: {msg}")
            return 1
        print("  PASS: monotonic totalAirborne (and far-field sanity)")
    else:
        print("Vertical profile: not present (implement §5–6, then re-run with export)")

    return 0


if __name__ == "__main__":
    sys.exit(main())
