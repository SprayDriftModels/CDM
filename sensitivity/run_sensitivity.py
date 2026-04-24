"""
Sensitivity Analysis for the Casanova Drift Model (CDM)

Performs one-at-a-time (OAT) perturbation analysis, parameter sweeps,
and two-factor interaction analysis for key model parameters.

Outputs:
  - Tornado diagram (OAT sensitivity)
  - Response curves for top parameters
  - Interaction heatmaps
  - Summary CSV table
"""

import json
import subprocess
import copy
import tempfile
import os
from pathlib import Path

import numpy as np
import polars as pl
import matplotlib.pyplot as plt
import seaborn as sns

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

CDMCLI = r"c:\Users\gbbfx\OneDrive - Bayer\Projects\Casanova\Versions\windows-latest\cdm-1.2.0-win64\bin\cdmcli.exe"
BASE_CASE = Path(__file__).parent.parent / "tests" / "Case_B.json"
OUTPUT_DIR = Path(__file__).parent / "results"

# Downwind distances (m) at which to extract deposition
EVAL_DISTANCES = [3.0, 10.0, 30.0]

# Parameter definitions: (json_path, baseline, low, high, label, unit)
PARAMETERS = {
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
        "unit": "kPa",
    },
    "nozzle_angle": {
        "path": ["dropletTransport", "nozzleAngle"],
        "baseline": 110.0,
        "low": 90.0,
        "high": 130.0,
        "label": "Nozzle Angle",
        "unit": "°",
    },
    "temperature": {
        "path": ["dryAirTemperature"],
        "baseline": 16.6,
        "low": 6.6,
        "high": 26.6,
        "label": "Temperature",
        "unit": "°C",
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
        "label": "Wind Direction Variation (ψ)",
        "unit": "°",
    },
}

# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------


def load_base_config() -> dict:
    """Load the base Case_B JSON configuration."""
    with open(BASE_CASE, "r") as f:
        raw = f.read()
    # Strip comments (JSON with // comments)
    lines = []
    for line in raw.split("\n"):
        idx = line.find("//")
        if idx >= 0:
            line = line[:idx]
        lines.append(line)
    return json.loads("\n".join(lines))


def set_nested(d: dict, keys: list, value):
    """Set a value in a nested dict/list using a list of keys."""
    for k in keys[:-1]:
        d = d[k]
    d[keys[-1]] = value


def get_nested(d: dict, keys: list):
    """Get a value from a nested dict/list using a list of keys."""
    for k in keys:
        d = d[k]
    return d


def run_model(config: dict) -> dict | None:
    """Write config to a temp file, run cdmcli, parse JSON output."""
    with tempfile.NamedTemporaryFile(
        mode="w", suffix=".json", delete=False, dir=OUTPUT_DIR
    ) as f:
        json.dump(config, f)
        tmp_input = f.name

    tmp_output = tmp_input.replace(".json", "_out.json")

    try:
        result = subprocess.run(
            [CDMCLI, tmp_input, "-o", tmp_output],
            capture_output=True,
            text=True,
            timeout=120,
            encoding="utf-8",
            errors="replace",
        )
        if result.returncode != 0:
            print(f"  ERROR: {result.stderr.strip()}")
            return None

        with open(tmp_output, "r") as f:
            return json.load(f)
    except Exception as e:
        print(f"  EXCEPTION: {e}")
        return None
    finally:
        for p in [tmp_input, tmp_output]:
            if os.path.exists(p):
                os.remove(p)


def extract_deposition(output: dict | list, distances: list[float]) -> dict[float, float]:
    """Extract deposition (%IAR) at specified downwind distances from model output."""
    # Output format is [case_name, {config + output}]
    if isinstance(output, list) and len(output) == 2:
        data = output[1]
    else:
        data = output

    dep_data = data.get("output", {}).get("deposition", [])

    if not dep_data:
        return {d: np.nan for d in distances}

    dist_arr = np.array([row[0] for row in dep_data], dtype=float)
    dep_arr = np.array([row[1] for row in dep_data], dtype=float)

    results = {}
    for d in distances:
        idx = np.argmin(np.abs(dist_arr - d))
        results[d] = float(dep_arr[idx])
    return results


def compute_total_off_field(output: dict | list, field_depth: float = 24.0) -> float:
    """Compute total off-field deposition by summing deposition beyond field edge."""
    if isinstance(output, list) and len(output) == 2:
        data = output[1]
    else:
        data = output

    dep_data = data.get("output", {}).get("deposition", [])

    if not dep_data:
        return np.nan

    dist_arr = np.array([row[0] for row in dep_data])
    dep_arr = np.array([row[1] for row in dep_data])

    mask = dist_arr > field_depth
    if mask.any():
        return float(np.trapz(dep_arr[mask], dist_arr[mask]))
    return 0.0


# ---------------------------------------------------------------------------
# 1. One-at-a-Time (OAT) Analysis
# ---------------------------------------------------------------------------


def run_oat_analysis() -> pl.DataFrame:
    """Run OAT analysis: vary each parameter to low/high, record deposition changes."""
    print("=" * 60)
    print("OAT SENSITIVITY ANALYSIS")
    print("=" * 60)

    config = load_base_config()
    case_key = list(config.keys())[0]

    # Baseline run
    print("\nRunning baseline...")
    base_output = run_model(config)
    if base_output is None:
        raise RuntimeError("Baseline model run failed")

    base_dep = extract_deposition(base_output, EVAL_DISTANCES)
    base_off_field = compute_total_off_field(base_output)
    print(f"  Baseline deposition: {base_dep}")
    print(f"  Baseline off-field:  {base_off_field:.4f}")

    rows = []
    for param_name, param_info in PARAMETERS.items():
        print(f"\nParameter: {param_info['label']}")

        for level_name, level_value in [("low", param_info["low"]), ("high", param_info["high"])]:
            cfg = copy.deepcopy(config)
            set_nested(cfg[case_key], param_info["path"], level_value)

            print(f"  {level_name} = {level_value} {param_info['unit']}...", end=" ")
            output = run_model(cfg)

            if output is None:
                print("FAILED")
                continue

            dep = extract_deposition(output, EVAL_DISTANCES)
            off_field = compute_total_off_field(output)
            print(f"dep@10m = {dep.get(10.0, np.nan):.4f}")

            for dist in EVAL_DISTANCES:
                pct_change = (
                    (dep[dist] - base_dep[dist]) / base_dep[dist] * 100
                    if base_dep[dist] != 0
                    else np.nan
                )
                rows.append({
                    "parameter": param_info["label"],
                    "level": level_name,
                    "value": level_value,
                    "unit": param_info["unit"],
                    "distance_m": dist,
                    "deposition_pct_IAR": dep[dist],
                    "pct_change": pct_change,
                })

            # Off-field total
            pct_change_off = (
                (off_field - base_off_field) / base_off_field * 100
                if base_off_field != 0
                else np.nan
            )
            rows.append({
                "parameter": param_info["label"],
                "level": level_name,
                "value": level_value,
                "unit": param_info["unit"],
                "distance_m": -1,  # sentinel for total off-field
                "deposition_pct_IAR": off_field,
                "pct_change": pct_change_off,
            })

    return pl.DataFrame(rows)


# ---------------------------------------------------------------------------
# 2. Parameter Sweeps
# ---------------------------------------------------------------------------


def run_parameter_sweep(param_name: str, n_points: int = 15) -> pl.DataFrame:
    """Sweep a single parameter across its range and record deposition."""
    param_info = PARAMETERS[param_name]
    values = np.linspace(param_info["low"], param_info["high"], n_points)

    config = load_base_config()
    case_key = list(config.keys())[0]

    print(f"\nSweeping {param_info['label']} ({param_info['low']}–{param_info['high']} {param_info['unit']})...")

    rows = []
    for val in values:
        cfg = copy.deepcopy(config)
        set_nested(cfg[case_key], param_info["path"], float(val))

        output = run_model(cfg)
        if output is None:
            continue

        dep = extract_deposition(output, EVAL_DISTANCES)
        off_field = compute_total_off_field(output)

        row = {
            "parameter": param_info["label"],
            "value": float(val),
            "unit": param_info["unit"],
            "off_field_total": off_field,
        }
        for dist in EVAL_DISTANCES:
            row[f"dep_{dist:.0f}m"] = dep[dist]
        rows.append(row)

    return pl.DataFrame(rows)


# ---------------------------------------------------------------------------
# 3. Two-Factor Interaction Analysis
# ---------------------------------------------------------------------------


def run_interaction(
    param_a: str, param_b: str, n_points: int = 10
) -> pl.DataFrame:
    """Vary two parameters simultaneously and record deposition at 10 m."""
    info_a = PARAMETERS[param_a]
    info_b = PARAMETERS[param_b]
    vals_a = np.linspace(info_a["low"], info_a["high"], n_points)
    vals_b = np.linspace(info_b["low"], info_b["high"], n_points)

    config = load_base_config()
    case_key = list(config.keys())[0]

    print(f"\nInteraction: {info_a['label']} × {info_b['label']}...")

    rows = []
    for va in vals_a:
        for vb in vals_b:
            cfg = copy.deepcopy(config)
            set_nested(cfg[case_key], info_a["path"], float(va))
            set_nested(cfg[case_key], info_b["path"], float(vb))

            output = run_model(cfg)
            if output is None:
                rows.append({
                    info_a["label"]: float(va),
                    info_b["label"]: float(vb),
                    "dep_10m": np.nan,
                })
                continue

            dep = extract_deposition(output, [10.0])
            rows.append({
                info_a["label"]: float(va),
                info_b["label"]: float(vb),
                "dep_10m": dep[10.0],
            })

    return pl.DataFrame(rows)


# ---------------------------------------------------------------------------
# Plotting
# ---------------------------------------------------------------------------


def plot_tornado(df_oat: pl.DataFrame, eval_dist: float = 10.0):
    """Create a tornado diagram for OAT results at a given distance."""
    df = df_oat.filter(pl.col("distance_m") == eval_dist)

    # Pivot to get low/high pct_change per parameter
    params = df["parameter"].unique().sort().to_list()
    low_vals = []
    high_vals = []
    for p in params:
        sub = df.filter(pl.col("parameter") == p)
        low_row = sub.filter(pl.col("level") == "low")
        high_row = sub.filter(pl.col("level") == "high")
        low_vals.append(low_row["pct_change"][0] if len(low_row) > 0 else 0)
        high_vals.append(high_row["pct_change"][0] if len(high_row) > 0 else 0)

    # Sort by max absolute change
    max_abs = [max(abs(lo), abs(hi)) for lo, hi in zip(low_vals, high_vals)]
    order = np.argsort(max_abs)

    params = [params[i] for i in order]
    low_vals = [low_vals[i] for i in order]
    high_vals = [high_vals[i] for i in order]

    fig, ax = plt.subplots(figsize=(10, 6))
    y_pos = np.arange(len(params))

    ax.barh(y_pos, low_vals, height=0.4, align="center", color="#4393c3", label="Low")
    ax.barh(y_pos, high_vals, height=0.4, align="center", color="#d6604d", label="High")

    ax.set_yticks(y_pos)
    ax.set_yticklabels(params)
    ax.set_xlabel("Change in Deposition (%)")
    ax.set_title(f"Sensitivity of Deposition at {eval_dist:.0f} m (OAT)")
    ax.axvline(0, color="black", linewidth=0.5)
    ax.legend()
    plt.tight_layout()
    plt.savefig(OUTPUT_DIR / f"tornado_{eval_dist:.0f}m.png", dpi=150)
    plt.close()
    print(f"  Saved tornado_{eval_dist:.0f}m.png")


def plot_sweeps(sweep_dfs: list[pl.DataFrame]):
    """Plot response curves for parameter sweeps."""
    fig, axes = plt.subplots(2, 2, figsize=(12, 10))
    axes = axes.flatten()

    for i, df in enumerate(sweep_dfs):
        if i >= 4:
            break
        ax = axes[i]
        param_label = df["parameter"][0]
        unit = df["unit"][0]
        x = df["value"].to_numpy()

        for dist in EVAL_DISTANCES:
            col = f"dep_{dist:.0f}m"
            if col in df.columns:
                ax.plot(x, df[col].to_numpy(), "o-", label=f"{dist:.0f} m", markersize=3)

        ax.set_xlabel(f"{param_label} ({unit})")
        ax.set_ylabel("Deposition (% IAR)")
        ax.set_title(param_label)
        ax.legend(fontsize=8)
        ax.grid(True, alpha=0.3)

    plt.suptitle("Parameter Response Curves", fontsize=14)
    plt.tight_layout()
    plt.savefig(OUTPUT_DIR / "response_curves.png", dpi=150)
    plt.close()
    print("  Saved response_curves.png")


def plot_interaction(df_int: pl.DataFrame, label_a: str, label_b: str):
    """Plot a heatmap for two-factor interaction."""
    pdf = df_int.to_pandas()
    pivot = pdf.pivot_table(values="dep_10m", index=label_b, columns=label_a)

    fig, ax = plt.subplots(figsize=(9, 7))
    sns.heatmap(
        pivot,
        annot=True,
        fmt=".2f",
        cmap="RdYlBu_r",
        ax=ax,
        cbar_kws={"label": "Deposition at 10 m (% IAR)"},
    )
    ax.set_title(f"Interaction: {label_a} × {label_b}")
    ax.set_xlabel(label_a)
    ax.set_ylabel(label_b)
    plt.tight_layout()

    fname = f"interaction_{label_a.replace(' ', '_')}_{label_b.replace(' ', '_')}.png"
    plt.savefig(OUTPUT_DIR / fname, dpi=150)
    plt.close()
    print(f"  Saved {fname}")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------


def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    # 1. OAT Analysis
    df_oat = run_oat_analysis()
    df_oat.write_csv(OUTPUT_DIR / "oat_results.csv")
    print("\nOAT results saved to oat_results.csv")

    for dist in EVAL_DISTANCES:
        plot_tornado(df_oat, dist)

    # Also tornado for total off-field
    plot_tornado(
        df_oat.with_columns(pl.when(pl.col("distance_m") == -1).then(pl.lit(10.0)).otherwise(pl.col("distance_m")).alias("distance_m")),
        10.0,
    )

    # 2. Parameter sweeps for top 4 most sensitive parameters
    # Determine top 4 from OAT at 10 m
    oat_10m = df_oat.filter(pl.col("distance_m") == 10.0)
    param_sensitivity = (
        oat_10m.group_by("parameter")
        .agg(pl.col("pct_change").abs().max().alias("max_change"))
        .sort("max_change", descending=True)
    )
    print(f"\nParameter ranking by sensitivity at 10 m:\n{param_sensitivity}")

    top_params = param_sensitivity.head(4)["parameter"].to_list()
    # Map label back to param key
    label_to_key = {v["label"]: k for k, v in PARAMETERS.items()}
    sweep_dfs = []
    for label in top_params:
        key = label_to_key.get(label)
        if key:
            df_sweep = run_parameter_sweep(key)
            df_sweep.write_csv(OUTPUT_DIR / f"sweep_{key}.csv")
            sweep_dfs.append(df_sweep)

    if sweep_dfs:
        plot_sweeps(sweep_dfs)

    # 3. Two-factor interactions
    # Wind speed × Relative humidity
    df_int1 = run_interaction("wind_speed", "relative_humidity", n_points=8)
    df_int1.write_csv(OUTPUT_DIR / "interaction_wind_humidity.csv")
    plot_interaction(df_int1, "Wind Speed", "Relative Humidity")

    # Nozzle height × Wind speed
    df_int2 = run_interaction("nozzle_height", "wind_speed", n_points=8)
    df_int2.write_csv(OUTPUT_DIR / "interaction_height_wind.csv")
    plot_interaction(df_int2, "Nozzle Height", "Wind Speed")

    print("\n" + "=" * 60)
    print("SENSITIVITY ANALYSIS COMPLETE")
    print(f"Results saved to: {OUTPUT_DIR}")
    print("=" * 60)


if __name__ == "__main__":
    main()
