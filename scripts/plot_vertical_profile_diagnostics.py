#!/usr/bin/env python3
"""Reproduce Alex-style vertical-profile diagnostics and compare cell vs plane crossing.

Expects cdmcli JSON output that includes:
  output.verticalProfile.resultsByDistanceCellCrossing
  output.verticalProfile.resultsByDistanceCellCrossingSingleNozzle
  output.verticalProfile.resultsByDistancePlaneCrossing
  output.verticalProfile.resultsByDistancePlaneCrossingSingleNozzle

Optional companion file written by cdmcli:
  <stem>.trajectories.bin  — for single-nozzle trajectory overlay
"""

from __future__ import annotations

import argparse
import json
import struct
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
from matplotlib.colors import LogNorm, Normalize


def load_results(path: Path) -> dict:
    with path.open(encoding="utf-8") as f:
        root = json.load(f)
    # cdmcli often writes ["Case_B", {...}] via ordered_json{name, obj}.
    if isinstance(root, list) and len(root) == 2 and isinstance(root[1], dict):
        return root[1]
    if isinstance(root, dict):
        if "output" in root:
            return root
        if len(root) == 1:
            return next(iter(root.values()))
    raise ValueError(f"Unrecognized JSON structure in {path}")


def grid_from_vp(columns: list[dict]) -> tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    """Return distances, height_uppers, pct grid [nH, nD], hit grid [nH, nD]."""
    if not columns:
        raise ValueError("empty vertical profile columns")
    distances = np.array([c["distance"] for c in columns], dtype=float)
    bins0 = columns[0]["bins"]
    # Drop degenerate zero-thickness bins (heights often start with 0.0).
    keep = [i for i, b in enumerate(bins0) if b["height"] > b["previousHeight"]]
    height_uppers = np.array([bins0[i]["height"] for i in keep], dtype=float)
    pct = np.zeros((len(keep), len(columns)), dtype=float)
    hits = np.zeros((len(keep), len(columns)), dtype=float)
    for j, col in enumerate(columns):
        for row, i in enumerate(keep):
            b = col["bins"][i]
            pct[row, j] = b["percentApplied"]
            hits[row, j] = b.get("hitCount", 0)
    return distances, height_uppers, pct, hits


def column_airborne(pct: np.ndarray) -> np.ndarray:
    return pct.sum(axis=0)


def read_trajectories_bin(path: Path) -> dict:
    """Parse CDMTRJB1 binary trajectory dump from cdm_get_trajectories_binary."""
    data = path.read_bytes()
    off = 0

    def u32() -> int:
        nonlocal off
        (v,) = struct.unpack_from("<I", data, off)
        off += 4
        return v

    def u64() -> int:
        nonlocal off
        (v,) = struct.unpack_from("<Q", data, off)
        off += 8
        return v

    def f64() -> float:
        nonlocal off
        (v,) = struct.unpack_from("<d", data, off)
        off += 8
        return v

    def string() -> str:
        n = u32()
        nonlocal off
        s = data[off : off + n].decode("utf-8")
        off += n
        return s

    magic = data[off : off + 8]
    off += 8
    if magic != b"CDMTRJB1":
        raise ValueError(f"bad magic {magic!r} in {path}")

    version = u32()
    streamline_count = u32()
    droplet_count = u32()
    height_count = u32()
    name = string()
    dp = [f64() for _ in range(droplet_count)]
    heights = [f64() for _ in range(height_count)]

    trajectories: list[list[list[tuple[float, float, float]]]] = []
    for _s in range(streamline_count):
        stream: list[list[tuple[float, float, float]]] = []
        for _d in range(droplet_count):
            npts = u32()
            pts = [(f64(), f64(), f64()) for _ in range(npts)]
            stream.append(pts)
        trajectories.append(stream)

    return {
        "version": version,
        "name": name,
        "dp": dp,
        "heights": heights,
        "trajectories": trajectories,  # [streamline][droplet][(x,z,mass), ...]
    }


def gaussian_blur(values: np.ndarray, sigma: float) -> np.ndarray:
    """Return a small dependency-free Gaussian blur for presentation rendering."""
    if sigma <= 0:
        return values.copy()
    radius = max(1, int(np.ceil(3.0 * sigma)))
    offsets = np.arange(-radius, radius + 1, dtype=float)
    kernel = np.exp(-0.5 * (offsets / sigma) ** 2)
    kernel /= kernel.sum()

    def blur_axis(array: np.ndarray, axis: int) -> np.ndarray:
        padded = np.pad(
            array,
            [(radius, radius) if i == axis else (0, 0) for i in range(array.ndim)],
            mode="constant",
        )
        result = np.zeros_like(array, dtype=float)
        for index, weight in enumerate(kernel):
            start = index
            stop = start + array.shape[axis]
            slices = [slice(None)] * array.ndim
            slices[axis] = slice(start, stop)
            result += weight * padded[tuple(slices)]
        return result

    return blur_axis(blur_axis(values, axis=0), axis=1)


def presentation_field(
    pct: np.ndarray, sigma_cells: float = 0.8
) -> tuple[np.ndarray, np.ndarray]:
    """Build a display-only interpolated field and a confidence fade.

    Positive cells are smoothed in log space. The second return value is not
    data: it is an opacity map based on proximity to a represented crossing.
    This avoids turning an unsupported region into a hard-edged "no data" block
    while still making it visibly recede from the calculated support.
    """
    observed = pct > 0.0
    log_values = np.zeros_like(pct, dtype=float)
    log_values[observed] = np.log10(pct[observed])
    support = gaussian_blur(observed.astype(float), sigma_cells)
    weighted_log_values = gaussian_blur(log_values, sigma_cells)

    # A tiny denominator is only for a display field; its opacity becomes zero.
    field = np.power(10.0, weighted_log_values / np.maximum(support, 1e-12))
    alpha = np.clip((support - 0.015) / 0.72, 0.0, 1.0)
    alpha = alpha * alpha

    # Do not let a two-dimensional display blur imply material above or below
    # the raw crossing envelope at a given distance. Each boundary gets only a
    # one-height-bin fade, which removes sharp holes without inventing a plume.
    row = np.arange(pct.shape[0], dtype=float)[:, None]
    lowest = np.zeros(pct.shape[1], dtype=float)
    highest = np.zeros(pct.shape[1], dtype=float)
    for column in range(pct.shape[1]):
        present = np.flatnonzero(observed[:, column])
        if present.size:
            lowest[column] = present[0]
            highest[column] = present[-1]
        else:
            lowest[column] = pct.shape[0]
            highest[column] = -1.0
    envelope = np.clip(row - (lowest[None, :] - 0.5), 0.0, 1.0)
    envelope *= np.clip((highest[None, :] + 0.5) - row, 0.0, 1.0)
    alpha *= envelope
    return field, alpha


def presentation_heatmap(
    ax,
    distances: np.ndarray,
    height_uppers: np.ndarray,
    pct: np.ndarray,
    title: str,
    vmin: float,
    vmax: float,
):
    """Render an explicitly display-only continuous view of raw plane crossings."""
    field, alpha = presentation_field(pct)
    cmap = plt.get_cmap("inferno")
    image = ax.imshow(
        field,
        origin="lower",
        aspect="auto",
        extent=(0.0, float(distances[-1]), 0.0, float(height_uppers[-1])),
        interpolation="bicubic",
        norm=LogNorm(vmin=vmin, vmax=vmax),
        cmap=cmap,
        alpha=alpha,
    )
    ax.set_facecolor("#f7f8f8")
    ax.set_title(title, fontsize=11)
    ax.set_xlabel("Downwind distance from field edge (m)")
    ax.set_ylabel("Height (m)")
    ax.set_xlim(0, 20)
    ax.set_ylim(0, 1.5)
    ax.text(
        0.99,
        0.98,
        "display-only interpolation\nnot a turbulence simulation\nfaded colors = weaker trajectory support",
        transform=ax.transAxes,
        ha="right",
        va="top",
        fontsize=8,
        color="#263238",
        bbox={"facecolor": "white", "edgecolor": "none", "alpha": 0.85, "pad": 3},
    )
    return image


def heatmap(
    ax,
    distances: np.ndarray,
    height_uppers: np.ndarray,
    pct: np.ndarray,
    title: str,
    color_scale: str = "log",
    vmin: float | None = None,
    vmax: float | None = None,
    overlay_traj: list[list[tuple[float, float, float]]] | None = None,
    xlim: tuple[float, float] | None = (0, 20),
    ylim: tuple[float, float] | None = (0, 1.5),
):
    # Build edges for pcolormesh: distance lower edge = previous (0 for first).
    d_edges = np.concatenate([[0.0], distances])
    h_lowers = np.concatenate([[0.0], height_uppers[:-1]])
    h_edges = np.concatenate([h_lowers[:1], height_uppers])

    if vmax is None:
        vmax = max(float(np.nanmax(pct)), 1e-3)
    if color_scale == "log":
        # Guard zeros for log scale.
        plot = np.maximum(pct, 1e-6)
        if vmin is None:
            vmin = max(vmax / 1e4, 1e-4)
        norm = LogNorm(vmin=vmin, vmax=vmax)
    else:
        plot = pct
        if vmin is None:
            vmin = 0.0
        norm = Normalize(vmin=vmin, vmax=vmax)

    mesh = ax.pcolormesh(
        d_edges,
        h_edges,
        plot,
        shading="flat",
        norm=norm,
        cmap="inferno",
    )
    if overlay_traj is not None:
        for traj in overlay_traj:
            if len(traj) < 2:
                continue
            xs = [p[0] for p in traj]
            zs = [p[1] for p in traj]
            ax.plot(xs, zs, color="cyan", alpha=0.35, linewidth=0.6)
    ax.set_title(title, fontsize=11)
    ax.set_xlabel("Downwind distance (m)")
    ax.set_ylabel("Height (m)")
    if xlim:
        ax.set_xlim(*xlim)
    if ylim:
        ax.set_ylim(*ylim)
    return mesh


def pick_overlay_trajectories(trj: dict, max_per_stream: int = 6) -> list[list[tuple[float, float, float]]]:
    """Subsample trajectories for readable overlay (all streamlines, few sizes)."""
    out: list[list[tuple[float, float, float]]] = []
    dps = trj["dp"]
    # Prefer mid/small droplets that travel farther.
    idxs = list(range(len(dps)))
    if len(idxs) > max_per_stream:
        step = max(1, len(idxs) // max_per_stream)
        idxs = idxs[::step][:max_per_stream]
    for stream in trj["trajectories"]:
        for i in idxs:
            if i < len(stream) and stream[i]:
                out.append(stream[i])
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("json_path", type=Path, help="cdmcli -o results JSON")
    ap.add_argument(
        "-o",
        "--outdir",
        type=Path,
        default=None,
        help="Output directory for PNGs (default: next to JSON)",
    )
    ap.add_argument(
        "--trajectories",
        type=Path,
        default=None,
        help="Optional .trajectories.bin (default: sibling of JSON)",
    )
    ap.add_argument(
        "--color-scale",
        choices=("log", "linear"),
        default="log",
        help="Heatmap colour scale (default: log)",
    )
    args = ap.parse_args()

    case = load_results(args.json_path)
    out = case["output"]
    vp = out["verticalProfile"]
    outdir = args.outdir or args.json_path.parent / "vp_diagnostics"
    outdir.mkdir(parents=True, exist_ok=True)

    keys = {
        "cell_multi": "resultsByDistanceCellCrossing",
        "cell_single": "resultsByDistanceCellCrossingSingleNozzle",
        "plane_multi": "resultsByDistancePlaneCrossing",
        "plane_single": "resultsByDistancePlaneCrossingSingleNozzle",
    }
    grids = {}
    for label, key in keys.items():
        if key not in vp or vp[key] is None:
            raise SystemExit(f"Missing {key} in JSON — rebuild/run plane-crossing build")
        grids[label] = grid_from_vp(vp[key])

    traj_path = args.trajectories
    if traj_path is None:
        stem = args.json_path.with_suffix("")
        candidate = Path(str(stem) + ".trajectories.bin")
        if candidate.exists():
            traj_path = candidate
    overlay = None
    if traj_path and traj_path.exists():
        overlay = pick_overlay_trajectories(read_trajectories_bin(traj_path))

    # Shared color scale across before/after panels of the same nozzle mode.
    def vmax_of(*labels: str) -> float:
        return max(float(np.nanmax(grids[l][2])) for l in labels)

    # --- Figure 1: single-nozzle before/after (Alex diagnostic style) ---
    vmax_s = vmax_of("cell_single", "plane_single")
    fig, axes = plt.subplots(1, 2, figsize=(12, 4.8), constrained_layout=True)
    m0 = heatmap(
        axes[0],
        *grids["cell_single"][:3],
        title="BEFORE: cell occupancy (single nozzle)",
        color_scale=args.color_scale,
        vmax=vmax_s,
        overlay_traj=overlay,
    )
    heatmap(
        axes[1],
        *grids["plane_single"][:3],
        title="AFTER: plane crossing (single nozzle)",
        color_scale=args.color_scale,
        vmax=vmax_s,
        overlay_traj=overlay,
        vmin=m0.norm.vmin,
    )
    fig.colorbar(
        m0,
        ax=axes.ravel().tolist(),
        label=f"Initial-volume weight per bin (%) ({args.color_scale})",
        fraction=0.046,
    )
    fig.suptitle("Case B vertical profile — single-nozzle diagnostic", fontsize=13)
    fig.savefig(outdir / "01_single_nozzle_cell_vs_plane.png", dpi=160)
    plt.close(fig)

    # --- Figure 2: multi-nozzle before/after (product path) ---
    vmax_m = vmax_of("cell_multi", "plane_multi")
    fig, axes = plt.subplots(1, 2, figsize=(12, 4.8), constrained_layout=True)
    m0 = heatmap(
        axes[0],
        *grids["cell_multi"][:3],
        title="BEFORE: cell occupancy (multi-nozzle)",
        color_scale=args.color_scale,
        vmax=vmax_m,
    )
    heatmap(
        axes[1],
        *grids["plane_multi"][:3],
        title="AFTER: plane crossing (multi-nozzle)",
        color_scale=args.color_scale,
        vmax=vmax_m,
        vmin=m0.norm.vmin,
    )
    fig.colorbar(
        m0,
        ax=axes.ravel().tolist(),
        label=f"Initial-volume weight per bin (%) ({args.color_scale})",
        fraction=0.046,
    )
    fig.suptitle("Case B vertical profile — multi-nozzle (product path)", fontsize=13)
    fig.savefig(outdir / "02_multi_nozzle_cell_vs_plane.png", dpi=160)
    plt.close(fig)

    # --- Figure 3: presentation-only view of the multi-nozzle plane profile ---
    # The raw grid remains Figure 2 and the JSON remains unchanged. This figure
    # softens the discrete representative-class display without claiming added physics.
    _, _, plane_multi_pct, _ = grids["plane_multi"]
    plane_positive = plane_multi_pct[plane_multi_pct > 0.0]
    presentation_vmin = max(float(plane_positive.min()), vmax_m / 1e4)
    fig, ax = plt.subplots(figsize=(8, 4.8), constrained_layout=True)
    image = presentation_heatmap(
        ax,
        *grids["plane_multi"][:3],
        title="Plane crossing — presentation rendering (multi-nozzle)",
        vmin=presentation_vmin,
        vmax=vmax_m,
    )
    fig.colorbar(image, ax=ax, label="Initial-volume weight per bin (%) (log)", fraction=0.046)
    fig.suptitle(
        "Case B vertical profile — interpolated display of raw plane crossings",
        fontsize=13,
    )
    fig.savefig(outdir / "03_plane_crossing_presentation_multi.png", dpi=160)
    plt.close(fig)

    # --- Figure 4: column totals (airborne sum) vs distance ---
    fig, ax = plt.subplots(figsize=(8, 4.5), constrained_layout=True)
    for label, style in [
        ("cell_single", dict(color="#d62728", ls="--", label="cell single")),
        ("plane_single", dict(color="#d62728", ls="-", label="plane single")),
        ("cell_multi", dict(color="#1f77b4", ls="--", label="cell multi")),
        ("plane_multi", dict(color="#1f77b4", ls="-", label="plane multi")),
    ]:
        d, _, pct, _ = grids[label]
        ax.plot(d, column_airborne(pct), **style)
    ax.set_xlabel("Downwind distance from field edge (m)")
    ax.set_ylabel("Column sum of initial-volume weights (%)")
    ax.set_title("Occupancy sums (diagnostic) vs plane-crossing fractions")
    ax.legend(frameon=False)
    ax.set_xlim(0, 20)
    ax.grid(True, alpha=0.3)
    fig.savefig(outdir / "04_airborne_column_sum.png", dpi=160)
    plt.close(fig)

    # --- Figure 5: hit-count inflation (cell vs plane), single nozzle ---
    d, h, _, hits_cell = grids["cell_single"]
    _, _, _, hits_plane = grids["plane_single"]
    fig, axes = plt.subplots(1, 2, figsize=(12, 4.8), constrained_layout=True)
    vmax_h = max(float(hits_cell.max()), 1.0)
    for ax, hits, title in [
        (axes[0], hits_cell, "Hit counts — cell occupancy"),
        (axes[1], hits_plane, "Hit counts — plane crossing"),
    ]:
        d_edges = np.concatenate([[0.0], d])
        h_edges = np.concatenate([[0.0], h])
        mesh = ax.pcolormesh(
            d_edges,
            h_edges,
            np.maximum(hits, 0.5),
            shading="flat",
            norm=LogNorm(vmin=0.5, vmax=vmax_h),
            cmap="viridis",
        )
        ax.set_title(title)
        ax.set_xlabel("Distance (m)")
        ax.set_ylabel("Height (m)")
        ax.set_xlim(0, 20)
        ax.set_ylim(0, 1.5)
    fig.colorbar(mesh, ax=axes.ravel().tolist(), label="hitCount", fraction=0.046)
    fig.suptitle("Same mass, many bins (cell) vs one bin (plane)", fontsize=13)
    fig.savefig(outdir / "05_hitcount_cell_vs_plane_single.png", dpi=160)
    plt.close(fig)

    # --- Summary table ---
    lines = ["method,dist_1m_airborne,dist_5m_airborne,dist_20m_airborne,max_cell_pct"]
    for label in keys:
        d, _, pct, _ = grids[label]
        air = column_airborne(pct)

        def at(x: float) -> float:
            return float(air[int(np.argmin(np.abs(d - x)))])

        lines.append(
            f"{label},{at(1):.4f},{at(5):.4f},{at(20):.4f},{float(pct.max()):.4f}"
        )
    summary = outdir / "summary.csv"
    summary.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Wrote figures to {outdir}")
    print(summary.read_text(encoding="utf-8"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
