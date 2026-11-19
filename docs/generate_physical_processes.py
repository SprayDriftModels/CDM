"""Regenerate docs/assets/images/physical-processes.png to match v1.2.0 capabilities.

Layout principle: a strict left-to-right pipeline with no crossing edges.
The four per-droplet forces live in ONE box as labelled rows rather than four
separate cards, which removes six arrows and all of the crossings.
"""
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch

OUT = Path(__file__).resolve().parent / "assets" / "images" / "physical-processes.png"

W, H = 12.5, 4.6
fig, ax = plt.subplots(figsize=(W, H))
ax.set_xlim(0, W)
ax.set_ylim(0, H)
ax.axis("off")
fig.patch.set_facecolor("white")

INK = "#222222"
MUTED = "#555555"
EDGE = "#444444"
MID = 2.25          # shared centre line — every pipeline arrow is horizontal


def panel(x, y, w, h, title, facecolor, edgecolor):
    ax.add_patch(FancyBboxPatch(
        (x, y), w, h,
        boxstyle="round,pad=0.02,rounding_size=0.08",
        linewidth=1.6, edgecolor=edgecolor, facecolor=facecolor,
    ))
    ax.text(x + 0.12, y + h - 0.24, title, fontsize=11, fontweight="bold",
            color=edgecolor, va="top")


def card(x, y, w, h, title, subtitle, facecolor="#ffffff", edge="#555555",
         title_color=INK, dashed=False):
    ax.add_patch(FancyBboxPatch(
        (x, y), w, h,
        boxstyle="round,pad=0.015,rounding_size=0.06",
        linewidth=1.2, edgecolor=edge, facecolor=facecolor,
        linestyle=(0, (3, 2)) if dashed else "solid",
    ))
    ax.text(x + w / 2, y + h - 0.2, title, ha="center", va="top",
            fontsize=8.5, fontweight="bold", color=title_color)
    ax.text(x + w / 2, y + 0.1, subtitle, ha="center", va="bottom",
            fontsize=7, color=MUTED, linespacing=1.2)


def forces_card(x, y, w, h, rows, facecolor="#ffffff", edge="#555555"):
    """One box holding the per-droplet forces as rows — replaces four cards."""
    ax.add_patch(FancyBboxPatch(
        (x, y), w, h,
        boxstyle="round,pad=0.015,rounding_size=0.06",
        linewidth=1.2, edgecolor=edge, facecolor=facecolor,
    ))
    ax.text(x + w / 2, y + h - 0.2, "Forces on each droplet", ha="center", va="top",
            fontsize=8.5, fontweight="bold", color=INK)
    top = y + h - 0.62
    # leaves ~0.16 below the final driver line, so the box has no dead space
    step = (h - 0.99) / (len(rows) - 1)
    for i, (name, driver) in enumerate(rows):
        ry = top - i * step
        ax.plot([x + 0.16], [ry + 0.015], marker="o", markersize=3.1,
                color="#b8860b", zorder=5)
        ax.text(x + 0.30, ry, name, ha="left", va="center",
                fontsize=7.6, fontweight="bold", color=INK)
        ax.text(x + 0.30, ry - 0.21, driver, ha="left", va="center",
                fontsize=6.6, color=MUTED)


def arrow(x1, y1, x2, y2, color=EDGE, lw=1.2, dashed=False):
    ax.add_patch(FancyArrowPatch(
        (x1, y1), (x2, y2),
        arrowstyle="-|>", mutation_scale=11, linewidth=lw, color=color,
        connectionstyle="arc3,rad=0",
        linestyle=(0, (3, 2)) if dashed else "solid",
        shrinkA=0, shrinkB=0,
    ))


# ---------------------------------------------------------------- panels
panel(0.15, 0.20, 2.60, 4.20, "Inputs", "#e8f4fd", "#0969da")
panel(3.10, 0.20, 6.20, 4.20, "Physical Processes", "#fff8e1", "#b8860b")
panel(9.65, 0.20, 2.70, 4.20, "Outputs", "#e8f5e9", "#2e7d32")

# ---------------------------------------------------------------- inputs
# cards top out at 3.90 so they clear the panel title, which sits at ~3.97
card(0.35, 3.05, 2.20, 0.85, "Spray", "droplet sizes,\nnozzle config")
card(0.35, 2.10, 2.20, 0.85, "Weather", "temperature,\nhumidity, pressure")
card(0.35, 1.15, 2.20, 0.85, "Wind", "speed at\nmultiple heights")
card(0.35, 0.28, 2.20, 0.80, "Field", "dimensions,\ncanopy height")

# ------------------------------------------------------------- processes
card(3.35, MID - 0.55, 1.70, 1.10, "Droplet Release",
     "spray fan breakup\ninto size classes", facecolor="#fffde7")

forces_card(5.30, MID - 1.10, 1.95, 2.20, [
    ("Aerodynamic drag", "air resistance"),
    ("Gravity", "size-dependent settling"),
    ("Evaporation", "humidity & temperature"),
    ("Wind transport", "horizontal carry"),
], facecolor="#ffffff")

card(7.50, MID - 0.62, 1.65, 1.24, "Droplet Trajectories",
     "ODE integration\n→ drift distance\nvs size / streamline", facecolor="#fff3c4")

# --------------------------------------------------------------- outputs
# same rule as the inputs column: nothing above 3.90, or it hits the panel title
card(9.85, 2.92, 2.30, 0.98, "Ground Deposition",
     "spray deposit vs\ndownwind distance", facecolor="#c8e6c9", edge="#2e7d32")
card(9.85, 1.70, 2.30, 0.98, "Airborne Drift (planned)",
     "vertical concentration\nat distance",
     facecolor="#eeeeee", edge="#888888", title_color="#666666", dashed=True)
card(9.85, 0.48, 2.30, 0.98, "Mass Balance (planned)",
     "on-field vs off-field\nspray fate",
     facecolor="#eeeeee", edge="#888888", title_color="#666666", dashed=True)

# ----------------------------------------------------------------- edges
# Pipeline: four straight, horizontal, non-crossing arrows along y = MID.
arrow(2.75, MID, 3.35, MID)      # inputs  -> release
arrow(5.05, MID, 5.30, MID)      # release -> forces
arrow(7.25, MID, 7.50, MID)      # forces  -> trajectories

# Trajectories -> outputs: a short fan, nothing crosses.
arrow(9.15, MID + 0.30, 9.85, 3.41)
arrow(9.15, MID, 9.85, 2.19, color="#888888", lw=1.0, dashed=True)
arrow(9.15, MID - 0.30, 9.85, 0.97, color="#888888", lw=1.0, dashed=True)

ax.text(9.85, 0.26, "dashed = not in v1.2.0", fontsize=7, color="#777777",
        style="italic")

fig.tight_layout(pad=0.2)
OUT.parent.mkdir(parents=True, exist_ok=True)
fig.savefig(OUT, dpi=160, bbox_inches="tight", facecolor="white")
plt.close()
print(f"Wrote {OUT}")
