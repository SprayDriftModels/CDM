"""Regenerate docs/assets/images/physical-processes.png to match v1.2.0 capabilities."""
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch

OUT = Path(__file__).resolve().parent / "assets" / "images" / "physical-processes.png"

fig, ax = plt.subplots(figsize=(12.5, 5.2))
ax.set_xlim(0, 12.5)
ax.set_ylim(0, 5.2)
ax.axis("off")
fig.patch.set_facecolor("white")


def panel(x, y, w, h, title, facecolor, edgecolor):
    box = FancyBboxPatch(
        (x, y), w, h,
        boxstyle="round,pad=0.02,rounding_size=0.08",
        linewidth=1.6,
        edgecolor=edgecolor,
        facecolor=facecolor,
    )
    ax.add_patch(box)
    ax.text(x + 0.12, y + h - 0.28, title, fontsize=11, fontweight="bold",
            color=edgecolor, va="top")


def card(x, y, w, h, title, subtitle, facecolor="#ffffff", edge="#555555",
         title_color="#222222", dashed=False):
    box = FancyBboxPatch(
        (x, y), w, h,
        boxstyle="round,pad=0.015,rounding_size=0.06",
        linewidth=1.2,
        edgecolor=edge,
        facecolor=facecolor,
        linestyle=(0, (3, 2)) if dashed else "solid",
    )
    ax.add_patch(box)
    ax.text(x + w / 2, y + h - 0.22, title, ha="center", va="top",
            fontsize=8.5, fontweight="bold", color=title_color)
    ax.text(x + w / 2, y + 0.12, subtitle, ha="center", va="bottom",
            fontsize=7, color="#555555", linespacing=1.15)


def arrow(x1, y1, x2, y2, style="-|>", color="#444444", lw=1.1, connectionstyle="arc3,rad=0"):
    ax.add_patch(FancyArrowPatch(
        (x1, y1), (x2, y2),
        arrowstyle=style,
        mutation_scale=10,
        linewidth=lw,
        color=color,
        connectionstyle=connectionstyle,
        linestyle="-" if style == "-|>" else "--",
    ))


# Panels
panel(0.15, 0.25, 2.55, 4.7, "Inputs", "#e8f4fd", "#0969da")
panel(3.0, 0.25, 6.35, 4.7, "Physical Processes", "#fff8e1", "#b8860b")
panel(9.6, 0.25, 2.7, 4.7, "Outputs", "#e8f5e9", "#2e7d32")

# Inputs
card(0.35, 3.55, 2.15, 0.95, "Spray", "droplet sizes,\nnozzle config")
card(0.35, 2.45, 2.15, 0.95, "Weather", "temperature,\nhumidity, pressure")
card(0.35, 1.35, 2.15, 0.95, "Wind", "speed at\nmultiple heights")
card(0.35, 0.4, 2.15, 0.8, "Field", "dimensions,\ncanopy height")

# Processes
card(3.25, 3.55, 2.35, 0.95, "Droplet Release", "spray fan breakup\ninto size classes", facecolor="#fffde7")
card(5.85, 3.85, 1.6, 0.7, "Aerodynamic Drag", "air resistance\non moving droplets")
card(7.55, 3.85, 1.6, 0.7, "Gravity", "settling velocity\ndepends on size")
card(5.85, 2.85, 1.6, 0.7, "Evaporation", "water loss driven by\nhumidity & temperature")
card(7.55, 2.85, 1.6, 0.7, "Wind Transport", "horizontal carry\nby wind profile")
card(5.85, 1.15, 3.3, 1.0, "Droplet Trajectories", "ODE integration → drift\ndistance vs size / streamline",
     facecolor="#fff3c4")

# Outputs
card(9.8, 3.35, 2.3, 1.1, "Ground Deposition", "spray deposit vs\ndownwind distance",
     facecolor="#c8e6c9", edge="#2e7d32")
card(9.8, 1.95, 2.3, 1.15, "Airborne Drift (planned)", "vertical concentration\nat distance",
     facecolor="#eeeeee", edge="#888888", title_color="#666666", dashed=True)
card(9.8, 0.55, 2.3, 1.15, "Mass Balance (planned)", "on-field vs off-field\nspray fate",
     facecolor="#eeeeee", edge="#888888", title_color="#666666", dashed=True)

# Input → process arrows
arrow(2.5, 4.0, 3.25, 4.0)
arrow(2.5, 2.9, 5.85, 3.2)
arrow(2.5, 1.8, 7.55, 3.2)
arrow(2.5, 0.8, 5.85, 1.4)

# Release → subprocesses
arrow(5.6, 4.2, 5.85, 4.2)
arrow(4.4, 3.55, 5.85, 3.55, connectionstyle="arc3,rad=-0.15")
arrow(4.4, 3.55, 6.65, 3.55, connectionstyle="arc3,rad=0.2")
arrow(5.6, 4.0, 7.55, 4.2, connectionstyle="arc3,rad=-0.25")

# Subprocesses → trajectories
arrow(6.65, 3.85, 6.65, 2.15)
arrow(8.35, 3.85, 7.8, 2.15)
arrow(6.65, 2.85, 6.9, 2.15)
arrow(8.35, 2.85, 8.0, 2.15)

# Trajectories → outputs
arrow(9.15, 1.9, 9.8, 3.7)
arrow(9.15, 1.55, 9.8, 2.5, style="->", color="#888888", lw=1.0)
arrow(9.15, 1.3, 9.8, 1.15, style="->", color="#888888", lw=1.0)

ax.text(9.8, 0.35, "dashed = not in v1.2.0", fontsize=7, color="#777777", style="italic")

fig.tight_layout(pad=0.2)
OUT.parent.mkdir(parents=True, exist_ok=True)
fig.savefig(OUT, dpi=160, bbox_inches="tight", facecolor="white")
plt.close()
print(f"Wrote {OUT}")
