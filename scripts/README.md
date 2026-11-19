# Scripts

Utility scripts for Case B validation, vertical-profile diagnostics, OpenFOAM
reference extraction, and CDM parameter sweeps.

Run all commands from the **repo root** unless noted.

```powershell
cd C:\Users\gbbfx\GitProjects\CDM-vp-dev
```

**Dependencies:** Python 3 with `numpy` / `matplotlib` for plotting scripts.
Batch sweeps also need a working `cdmcli.exe` (see [batch_sweep/README.md](batch_sweep/README.md)).

---

## Local CDM binary (`bin\`)

This worktree has a plane-crossing build at:

```
bin\cdmcli.exe      (~880 KB; companion: bin\libcdm.dll + .lib/.exp/manifest)
```

`libcdm.dll` holds the model logic; the CLI is a thin wrapper. Embedded strings in
the DLL include all four VP export keys the diagnostics script needs, so **no
rebuild is required** to generate fresh JSON for cell vs plane plots.

There is no other `cdmcli.exe` / `cdm.exe` in this or the public CDM worktree.
`build\` currently has only `CMakeFiles` / `vcpkg_installed` — not a configured
generator tree — so these `bin\` artifacts are from an earlier build. Changing VP
code means re-running the CMake preset first, then rebuilding; you cannot
incrementally rebuild from `build\` as-is.

Use this binary for VP work. **Important:** plain `tests\Case_B.json` does not
set `verticalProfile.heights` / `distances`, so the four result arrays stay
`null` and the plot script fails. Use the VP-enabled case instead:

```powershell
.\bin\cdmcli.exe -i tests\Case_B_vertical_profile_distances.json `
    -o sensitivity\vp_compare\case_b_vp.json
```

For sensitivity analysis / `batch_sweep`, the default exe is the packaged
CDM 1.2.0 Windows release (not this local `bin\` build):

```
c:\Users\gbbfx\OneDrive - Bayer\Projects\Casanova\Versions\windows-latest\cdm-1.2.0-win64\bin\cdmcli.exe
```

Override with `--cdm-cli bin\cdmcli.exe` when you want the plane-crossing build
instead. Details: [batch_sweep/README.md](batch_sweep/README.md).

---

## Layout

| Path | Purpose |
|------|---------|
| `reconcile_case_b.py` | Ground-deposition (and optional VP) checks vs Case B |
| `plot_vertical_profile_diagnostics.py` | Cell vs plane-crossing VP comparison plots |
| `export_vertical_profile.py` | Shareable CSV / JSON / TXT export of a run |
| `openfoam_vertical_plane_extractor.py` | OpenFOAM → vertical-profile JSON (reference) |
| `batch_sweep/` | OAT / sweep / interaction / LHS sensitivity analysis |

---

## Case B reconciliation

Checks deposition from a CDM run against Case B expectations. Vertical-profile
checks run if the output includes `verticalDriftProfile` (or you pass a separate
VP JSON).

```powershell
# Use an existing CDM output
python scripts\reconcile_case_b.py --output-json path\to\case_b_out.json

# Or run the local plane-crossing binary, then reconcile
python scripts\reconcile_case_b.py --cdm-cli bin\cdmcli.exe

# Optional: dedicated vertical-profile export
python scripts\reconcile_case_b.py `
    --output-json path\to\case_b_out.json `
    --vertical-profile-json path\to\vp.json
```

Defaults: `--input-json tests\Case_B.json`.

---

## Vertical-profile diagnostics (cell vs plane)

Compares cell-occupancy vs plane-crossing vertical profiles from a `cdmcli` JSON
export. Writes four PNGs + `summary.csv`.

**Requires** all four VP keys in the JSON (present in `bin\libcdm.dll`):

- `resultsByDistanceCellCrossing`
- `resultsByDistanceCellCrossingSingleNozzle`
- `resultsByDistancePlaneCrossing`
- `resultsByDistancePlaneCrossingSingleNozzle`

If any are missing, the script exits and asks for a plane-crossing build.
Optional companion file `<stem>.trajectories.bin` adds a trajectory overlay.

```powershell
# Fresh JSON from the local plane-crossing build, then plot
# (must use the VP-enabled case — plain Case_B.json leaves results null)
mkdir sensitivity\vp_compare\figures -Force
.\bin\cdmcli.exe -i tests\Case_B_vertical_profile_distances.json `
    -o sensitivity\vp_compare\case_b_vp.json
python scripts\plot_vertical_profile_diagnostics.py `
    sensitivity\vp_compare\case_b_vp.json `
    -o sensitivity\vp_compare\figures

# Or replot from an existing JSON only
python scripts\plot_vertical_profile_diagnostics.py `
    sensitivity\vp_compare\case_b_vp.json `
    -o sensitivity\vp_compare\figures

# Optional: finer grid (0.05 m height × 0.5 m distance) for heatmap comparison.
# Coarse outputs stay untouched under figures\ / case_b_vp.json.
.\bin\cdmcli.exe -i tests\Case_B_vertical_profile_distances_fine.json `
    -o sensitivity\vp_compare\case_b_vp_fine.json
python scripts\plot_vertical_profile_diagnostics.py `
    sensitivity\vp_compare\case_b_vp_fine.json `
    -o sensitivity\vp_compare\figures_fine
```

Figures: single-nozzle heatmaps, multi-nozzle heatmaps, column-sum airborne %IAR,
and hit-count comparison.

| Grid | Input | Output JSON | Figures |
|------|-------|-------------|---------|
| Coarse (0.1 m × 1 m) | `tests\Case_B_vertical_profile_distances.json` | `case_b_vp.json` | `figures\` |
| Fine (0.05 m × 0.5 m) | `tests\Case_B_vertical_profile_distances_fine.json` | `case_b_vp_fine.json` | `figures_fine\` |

> `sensitivity/` is gitignored — inputs/figures there are local-only. The script
> itself is tracked.

---

## Share a run with colleagues

`cdmcli` output JSON is verbose and mixes inputs with results. This turns one run
into files a colleague can open without CDM:

```powershell
python scripts\export_vertical_profile.py runs\FR_1_018\output.json -o runs\FR_1_018\share
```

| File | Contents |
|------|----------|
| `<case>_vertical_profile.csv` | one row per method × distance × height bin: `pct_iar`, `hit_count` |
| `<case>_deposition.csv` | ground deposition curve |
| `<case>_export.json` | conditions + deposition + `pctIAR[heightBin][distance]` per method |
| `<case>_report.txt` | readable summary: conditions, deposition, column-sum airborne %IAR |

Pick a subset with `--formats csv txt`, rename with `--prefix`. All four VP
methods are labelled explicitly (`planeCrossingMultiNozzle` etc.) and the export
carries a note stating that plane crossing is the regulatory metric and the
cell-crossing / single-nozzle arrays are diagnostics.

Runs without `verticalProfile.heights` / `.distances` still export deposition,
with a warning. **Do not send `output.trajectories.bin`** — it is ~58 MB and
gitignored; the CSV/JSON exports are ~130 KB.

---

## OpenFOAM vertical-plane extractor

Reference extractor: airborne mass in height bins at downwind distances from
OpenFOAM MPPICFoam Lagrangian positions. Output aligns with
`docs/vertical-profile-spec.md` for comparison to CDM.

Needs an OpenFOAM case on disk (not run in CDM CI).

```powershell
# Demo with synthetic particles (no OpenFOAM data)
python scripts\openfoam_vertical_plane_extractor.py --demo --output vp_demo.json

# Real case
python scripts\openfoam_vertical_plane_extractor.py `
    --case-dir path\to\OpenFOAM\casedir `
    --distances 3 5 10 20 30 50 `
    --field-edge-offset 24.0 `
    --output vertical_profile_openfoam.json
```

Looks for `lagrangian/kinematicCloud/*/positions` under `--case-dir`.

---

## Batch sensitivity (`batch_sweep/`)

Parameter sweeps for SETAC Case B (OAT, 1D sweeps, interactions, LHS). No local
CDM build required — defaults to the packaged release:

```
c:\Users\gbbfx\OneDrive - Bayer\Projects\Casanova\Versions\windows-latest\cdm-1.2.0-win64\bin\cdmcli.exe
```

```powershell
# One-at-a-time sensitivity + tornado plot
python scripts\batch_sweep\run_analysis.py oat `
    --output-dir scripts\batch_sweep\results `
    --plot

# 1D response curves
python scripts\batch_sweep\run_analysis.py sweep --points 15 --plot

# Two-factor interaction
python scripts\batch_sweep\run_analysis.py interaction `
    --param-a wind_speed --param-b relative_humidity --grid 8 --plot

# Latin Hypercube sample + parallel runs
python scripts\batch_sweep\run_analysis.py lhs --samples 20 --jobs 4
```

Point at a different binary if needed (e.g. this worktree's plane-crossing build):

```powershell
$env:CDM_CLI = "C:\Users\gbbfx\GitProjects\CDM-vp-dev\bin\cdmcli.exe"
# or
python scripts\batch_sweep\run_analysis.py oat --cdm-cli bin\cdmcli.exe
```

Full parameter table, modes, and module map:
**[batch_sweep/README.md](batch_sweep/README.md)**.

---

## See also

- [docs/vertical-profile-spec.md](../docs/vertical-profile-spec.md) — VP definitions and normalization
- [docs/driftml_assessment.md](../docs/driftml_assessment.md) — DriftML / OpenFOAM assessment notes
