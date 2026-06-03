from __future__ import annotations

import csv
from pathlib import Path

import matplotlib.pyplot as plt


ROOT = Path(__file__).resolve().parent
INPUT_CSV = ROOT / "results" / "oat_results.csv"
OUTPUT_PNG = ROOT / "results" / "slide_oat_10m_diverging.png"


def load_oat_rows(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f))


def build_plot_data(rows: list[dict[str, str]], distance_m: float) -> list[tuple[str, float, float]]:
    data: dict[str, dict[str, float]] = {}
    for row in rows:
        if abs(float(row["distance_m"]) - distance_m) > 1e-9:
            continue
        parameter = row["parameter"]
        level = row["level"]
        pct_change = float(row["pct_change"])
        if parameter not in data:
            data[parameter] = {"low": 0.0, "high": 0.0}
        data[parameter][level] = pct_change

    # Sort by effect size so the strongest drivers are easiest to read on slides.
    items = [
        (param, vals["low"], vals["high"])
        for param, vals in data.items()
    ]
    items.sort(key=lambda x: max(abs(x[1]), abs(x[2])), reverse=True)
    return items


def plot_diverging(data: list[tuple[str, float, float]], output_path: Path) -> None:
    fig, ax = plt.subplots(figsize=(13, 8), constrained_layout=True)

    y_positions = list(range(len(data)))
    labels = [d[0] for d in data]
    low_vals = [d[1] for d in data]
    high_vals = [d[2] for d in data]

    ax.axvline(0.0, color="#222222", linewidth=1.2)
    ax.grid(axis="x", color="#E2E6EA", linewidth=0.8)
    ax.set_axisbelow(True)

    # Draw connecting line to emphasize asymmetry between low and high perturbations.
    for y, lo, hi in zip(y_positions, low_vals, high_vals):
        ax.plot([lo, hi], [y, y], color="#B0B8C0", linewidth=2.2, zorder=1)

    ax.scatter(low_vals, y_positions, s=95, color="#2B8CBE", label="Low setting", zorder=3)
    ax.scatter(high_vals, y_positions, s=95, color="#D95F0E", label="High setting", zorder=3)

    for y, lo, hi in zip(y_positions, low_vals, high_vals):
        ax.text(lo, y + 0.16, f"{lo:+.1f}%", fontsize=9, color="#2B8CBE", ha="center")
        ax.text(hi, y - 0.22, f"{hi:+.1f}%", fontsize=9, color="#D95F0E", ha="center")

    ax.set_yticks(y_positions)
    ax.set_yticklabels(labels, fontsize=11)
    ax.invert_yaxis()

    max_abs = max(max(abs(v) for v in low_vals), max(abs(v) for v in high_vals))
    x_lim = max(20, int(max_abs / 10 + 2) * 10)
    ax.set_xlim(-x_lim, x_lim)

    ax.set_xlabel("Percent change in deposition at 10 m (%IAR)", fontsize=12)
    ax.set_title(
        "CDM Sensitivity at 10 m: Effect of Low vs High Parameter Settings",
        fontsize=16,
        fontweight="bold",
        pad=12,
    )
    ax.legend(loc="lower right", frameon=False, fontsize=11)

    fig.savefig(output_path, dpi=320)


def main() -> None:
    rows = load_oat_rows(INPUT_CSV)
    data = build_plot_data(rows, distance_m=10.0)
    if not data:
        raise RuntimeError("No OAT rows found for distance 10 m.")
    plot_diverging(data, OUTPUT_PNG)
    print(f"Wrote {OUTPUT_PNG}")


if __name__ == "__main__":
    main()
