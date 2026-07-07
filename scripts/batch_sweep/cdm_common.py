"""
Shared utilities for CDM batch sensitivity / parameter sweeps.

Aligned with sensitivity/run_sensitivity.py conventions:
  - 8 Case B parameters with list-based JSON paths
  - Evaluation distances 3, 10, 30 m
  - Off-field deposition integral beyond field edge
  - integrationOptions.maxSteps bump for stiff ODE regimes
"""

from __future__ import annotations

import copy
import json
import os
import re
import subprocess
import tempfile
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_BASE_CASE = REPO_ROOT / "tests" / "Case_B.json"
DEFAULT_FIELD_DEPTH_M = 24.0
EVAL_DISTANCES_M = (3.0, 10.0, 30.0)
INTEGRATION_MAX_STEPS = 20000
DEFAULT_RUN_TIMEOUT_S = 120

# Pre-built CDM 1.2.0 Windows binary — same path as sensitivity/run_sensitivity.py.
# Sensitivity work uses this release build; building from source is optional for dev.
# Override: CDM_CLI environment variable, or --cdm-cli on the command line.
DEFAULT_CDM_CLI = Path(
    r"c:\Users\gbbfx\OneDrive - Bayer\Projects\Casanova\Versions\windows-latest\cdm-1.2.0-win64\bin\cdmcli.exe"
)

_LOCAL_CDM_CANDIDATES = (
    REPO_ROOT / "build" / "Release" / "cdmcli.exe",
    REPO_ROOT / "build" / "Release" / "cdm.exe",
    REPO_ROOT / "build" / "Debug" / "cdmcli.exe",
    REPO_ROOT / "build" / "Debug" / "cdm.exe",
)

# Canonical parameter set — matches sensitivity/run_sensitivity.py and
# sensitivity-analysis.qmd (SETAC Case B, eight physically relevant inputs).
PARAMETERS: dict[str, dict[str, Any]] = {
    "wind_speed": {
        "path": ["windVelocityProfile", "velocityMeasurements", 0, 1],
        "baseline": 2.436272531,
        "low": 1.22,
        "high": 3.65,
        "label": "Wind Speed",
        "unit": "m/s",
    },
    "nozzle_height": {
        "path": ["dropletTransport", "nozzleHeight"],
        "baseline": 0.8016,
        "low": 0.60,
        "high": 1.00,
        "label": "Nozzle Height",
        "unit": "m",
    },
    "nozzle_pressure": {
        "path": ["dropletTransport", "nozzlePressure"],
        "baseline": 250000.0,
        "low": 150000.0,
        "high": 350000.0,
        "label": "Nozzle Pressure",
        "unit": "Pa",
    },
    "nozzle_angle": {
        "path": ["dropletTransport", "nozzleAngle"],
        "baseline": 110.0,
        "low": 90.0,
        "high": 130.0,
        "label": "Nozzle Angle",
        "unit": "deg",
    },
    "temperature": {
        "path": ["dryAirTemperature"],
        "baseline": 16.6,
        "low": 6.6,
        "high": 26.6,
        "label": "Temperature",
        "unit": "degC",
    },
    "relative_humidity": {
        "path": ["relativeHumidity"],
        "baseline": 67.1,
        "low": 30.0,
        "high": 95.0,
        "label": "Relative Humidity",
        "unit": "%",
    },
    "canopy_height": {
        "path": ["dropletTransport", "canopyHeight"],
        "baseline": 0.15,
        "low": 0.0,
        "high": 0.50,
        "label": "Canopy Height",
        "unit": "m",
    },
    "horizontal_variation": {
        "path": ["windVelocityProfile", "horizontalVariation"],
        "baseline": 10.7,
        "low": 0.0,
        "high": 25.0,
        "label": "Wind Direction Variation",
        "unit": "deg",
    },
}


def strip_json_comments(text: str) -> str:
    lines = []
    for line in text.splitlines():
        idx = line.find("//")
        if idx >= 0:
            line = line[:idx]
        lines.append(line)
    return "\n".join(lines)


def parse_path(path: str | list) -> list:
    """Convert dot path ('a.b.0.c') or list path to nested keys."""
    if isinstance(path, list):
        return path
    parts: list = []
    for segment in str(path).split("."):
        parts.append(int(segment) if segment.isdigit() else segment)
    return parts


def get_nested(obj: dict, keys: list) -> Any:
    cur: Any = obj
    for k in keys:
        cur = cur[k]
    return cur


def set_nested(obj: dict, keys: list, value: Any) -> None:
    cur = obj
    for k in keys[:-1]:
        cur = cur[k]
    cur[keys[-1]] = value


def load_base_config(
    base_case: Path | None = None,
    *,
    bump_max_steps: bool = True,
) -> tuple[str, dict]:
    """Load Case JSON; return (case_name, full_config_dict)."""
    path = base_case or DEFAULT_BASE_CASE
    raw = strip_json_comments(path.read_text(encoding="utf-8"))
    config = json.loads(raw)
    case_name = next(iter(config))
    if bump_max_steps:
        case = config[case_name]
        case.setdefault("integrationOptions", {})
        case["integrationOptions"]["maxSteps"] = INTEGRATION_MAX_STEPS
    return case_name, config


def apply_overrides(
    config: dict,
    case_name: str,
    overrides: dict[str, float],
    *,
    param_keys: dict[str, str] | None = None,
) -> dict:
    """Return a deep copy of config with parameter overrides applied."""
    cfg = copy.deepcopy(config)
    for name, value in overrides.items():
        if name in PARAMETERS:
            set_nested(cfg[case_name], PARAMETERS[name]["path"], value)
        elif param_keys and name in param_keys:
            set_nested(cfg[case_name], parse_path(param_keys[name]), value)
        else:
            set_nested(cfg[case_name], parse_path(name), value)
    return cfg


def run_cdm(
    config: dict,
    cdm_cli: Path,
    *,
    output_dir: Path | None = None,
    timeout_s: int = DEFAULT_RUN_TIMEOUT_S,
    keep_files: bool = False,
) -> dict | None:
    """Run cdmcli on config dict; return parsed output JSON or None on failure."""
    out_parent = output_dir or Path(tempfile.gettempdir())
    out_parent.mkdir(parents=True, exist_ok=True)

    with tempfile.NamedTemporaryFile(
        mode="w", suffix=".json", delete=False, dir=out_parent, encoding="utf-8"
    ) as f:
        json.dump(config, f)
        tmp_input = Path(f.name)

    tmp_output = tmp_input.with_name(tmp_input.stem + "_out.json")

    try:
        result = subprocess.run(
            [str(cdm_cli), "-i", str(tmp_input), "-o", str(tmp_output)],
            capture_output=True,
            text=True,
            timeout=timeout_s,
            encoding="utf-8",
            errors="replace",
        )
        if result.returncode != 0:
            return None
        raw = strip_json_comments(tmp_output.read_text(encoding="utf-8"))
        return json.loads(raw)
    except (subprocess.TimeoutExpired, OSError, json.JSONDecodeError):
        return None
    finally:
        if not keep_files:
            for p in (tmp_input, tmp_output):
                if p.exists():
                    os.remove(p)


def normalize_output(output: dict | list) -> dict:
    if isinstance(output, list) and len(output) == 2:
        return output[1]
    case_name = next(iter(output))
    return output[case_name]


def extract_deposition(
    output: dict | list,
    distances: tuple[float, ...] = EVAL_DISTANCES_M,
) -> dict[float, float]:
    """Nearest-neighbour deposition (% IAR) at evaluation distances."""
    data = normalize_output(output)
    dep_data = data.get("output", {}).get("deposition", [])
    if not dep_data:
        return {d: float("nan") for d in distances}

    dist_arr = [float(row[0]) for row in dep_data]
    dep_arr = [float(row[1]) for row in dep_data]

    results: dict[float, float] = {}
    for d in distances:
        idx = min(range(len(dist_arr)), key=lambda i: abs(dist_arr[i] - d))
        results[d] = dep_arr[idx]
    return results


def compute_total_off_field(
    output: dict | list,
    field_depth_m: float = DEFAULT_FIELD_DEPTH_M,
) -> float:
    """Trapezoidal integral of deposition beyond field edge (sensitivity metric)."""
    data = normalize_output(output)
    dep_data = data.get("output", {}).get("deposition", [])
    if not dep_data:
        return float("nan")

    dist_arr = [float(row[0]) for row in dep_data]
    dep_arr = [float(row[1]) for row in dep_data]

    total = 0.0
    for i in range(len(dist_arr) - 1):
        if dist_arr[i + 1] <= field_depth_m:
            continue
        x0 = max(dist_arr[i], field_depth_m)
        x1 = dist_arr[i + 1]
        if x1 <= x0:
            continue
        y0 = dep_arr[i] if dist_arr[i] >= field_depth_m else dep_arr[i + 1]
        y1 = dep_arr[i + 1]
        total += 0.5 * (y0 + y1) * (x1 - x0)
    return total


def deposition_summary(
    output: dict | list,
    *,
    distances: tuple[float, ...] = EVAL_DISTANCES_M,
    field_depth_m: float = DEFAULT_FIELD_DEPTH_M,
    baseline_dep: dict[float, float] | None = None,
) -> dict[str, float]:
    """Build summary row: dep at distances, off-field total, optional pct change."""
    dep = extract_deposition(output, distances)
    off_field = compute_total_off_field(output, field_depth_m)

    summary: dict[str, float] = {
        "off_field_total": off_field,
    }
    for d in distances:
        key = f"dep_{d:.0f}m"
        summary[key] = dep[d]
        if baseline_dep is not None and d in baseline_dep:
            base = baseline_dep[d]
            summary[f"pct_change_{d:.0f}m"] = (
                (dep[d] - base) / base * 100.0 if base != 0 else float("nan")
            )
    if baseline_dep is not None and "off_field" in baseline_dep:
        base_off = baseline_dep["off_field"]
        summary["pct_change_off_field"] = (
            (off_field - base_off) / base_off * 100.0
            if base_off != 0
            else float("nan")
        )
    return summary


def label_to_param_key() -> dict[str, str]:
    return {v["label"]: k for k, v in PARAMETERS.items()}


def param_names_subset(names: list[str] | None = None) -> list[str]:
    if names:
        unknown = set(names) - set(PARAMETERS)
        if unknown:
            raise ValueError(f"Unknown parameters: {sorted(unknown)}")
        return names
    return list(PARAMETERS.keys())


def resolve_cdm_cli(explicit: Path | str | None = None) -> Path:
    """
    Resolve path to cdmcli.

    Priority: --cdm-cli argument > CDM_CLI env var > pre-built release binary
    > local CMake build artifacts.
    """
    if explicit is not None:
        path = Path(explicit)
        if not path.exists():
            raise FileNotFoundError(f"cdm-cli not found: {path}")
        return path

    env = os.environ.get("CDM_CLI")
    if env:
        path = Path(env)
        if path.exists():
            return path
        raise FileNotFoundError(f"CDM_CLI not found: {path}")

    if DEFAULT_CDM_CLI.exists():
        return DEFAULT_CDM_CLI

    for candidate in _LOCAL_CDM_CANDIDATES:
        if candidate.exists():
            return candidate

    searched = [str(DEFAULT_CDM_CLI), *map(str, _LOCAL_CDM_CANDIDATES)]
    raise FileNotFoundError(
        "No cdmcli executable found. Sensitivity analysis uses the pre-built "
        "CDM 1.2.0 Windows release (not a local build). Set CDM_CLI or pass "
        "--cdm-cli, or build from source.\n"
        "Searched:\n  " + "\n  ".join(searched)
    )
