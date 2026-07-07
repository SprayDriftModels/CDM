# CDM Batch Sensitivity Analysis

Parameter sweeps and sensitivity analysis for SETAC Case B, aligned with
`sensitivity/run_sensitivity.py` and `sensitivity/sensitivity-analysis.qmd`.

## CDM executable (pre-built release)

Sensitivity analysis does **not** build CDM from source. It uses the packaged
**CDM 1.2.0 Windows release**:

```
c:\Users\gbbfx\OneDrive - Bayer\Projects\Casanova\Versions\windows-latest\cdm-1.2.0-win64\bin\cdmcli.exe
```

`scripts/batch_sweep/` resolves this automatically (`cdm_common.DEFAULT_CDM_CLI`).
You do **not** need `--cdm-cli` if that path exists.

**Overrides** (in priority order):

1. `--cdm-cli path\to\cdmcli.exe`
2. `CDM_CLI` environment variable
3. Pre-built release path above
4. Local CMake build (`build/Release/cdmcli.exe`, etc.) — only if developing CDM

```powershell
# Optional: point at a different install
$env:CDM_CLI = "C:\path\to\cdmcli.exe"
```

## Analysis modes

| Mode | Command | Output |
|------|---------|--------|
| **OAT** | `run_analysis.py oat` | `oat_results.csv`, optional `tornado_10m.png` |
| **Sweep** | `run_analysis.py sweep --params wind_speed` | `sweep_<key>.csv`, optional `response_curves.png` |
| **Interaction** | `run_analysis.py interaction --param-a wind_speed --param-b relative_humidity` | `interaction_*.csv`, optional heatmap PNG |
| **LHS batch** | `run_analysis.py lhs --samples 20` | `samplespace.csv`, `summary.csv` |
| **CSV batch** | `batch_run.py --samplespace ...` | `summary.csv` from existing sample space |

### Evaluation metrics (match sensitivity analysis)

- Deposition (% IAR) at **3, 10, and 30 m** downwind
- **Off-field total** — trapezoidal integral beyond 24 m field edge
- **pct_change** columns relative to baseline (when baseline run succeeds)

### Eight parameters (cdm_common.PARAMETERS)

| Key | Label | Low | High |
|-----|-------|-----|------|
| `wind_speed` | Wind Speed | 1.22 m/s | 3.65 m/s |
| `nozzle_height` | Nozzle Height | 0.60 m | 1.00 m |
| `nozzle_pressure` | Nozzle Pressure | 150 kPa | 350 kPa |
| `nozzle_angle` | Nozzle Angle | 90 deg | 130 deg |
| `temperature` | Temperature | 6.6 degC | 26.6 degC |
| `relative_humidity` | Relative Humidity | 30% | 95% |
| `canopy_height` | Canopy Height | 0.0 m | 0.50 m |
| `horizontal_variation` | Wind Direction Variation | 0 deg | 25 deg |

## Quick start

```powershell
# OAT sensitivity — no build step; uses pre-built cdmcli.exe by default
python scripts/batch_sweep/run_analysis.py oat `
    --output-dir scripts/batch_sweep/results `
    --plot

# Parameter sweeps for top-4 parameters (default)
python scripts/batch_sweep/run_analysis.py sweep --points 15 --plot

# Two-factor interaction
python scripts/batch_sweep/run_analysis.py interaction `
    --param-a wind_speed --param-b relative_humidity --grid 8 --plot

# LHS uncertainty sample + parallel batch
python scripts/batch_sweep/run_analysis.py lhs --samples 20 --jobs 4

# Or: generate CSV then batch separately
python scripts/batch_sweep/lhs_sample.py --samples 20 --output scripts/batch_sweep/samplespace.csv
python scripts/batch_sweep/batch_run.py `
    --samplespace scripts/batch_sweep/samplespace.csv `
    --output-dir scripts/batch_sweep/results
```

To use a **local build** instead of the release binary:

```powershell
python scripts/batch_sweep/run_analysis.py oat --cdm-cli build/Release/cdmcli.exe
```

## Module layout

```
scripts/batch_sweep/
  cdm_common.py           Shared params, DEFAULT_CDM_CLI, run_cdm, deposition metrics
  run_analysis.py         OAT / sweep / interaction / lhs orchestrator
  lhs_sample.py           LHS CSV generator
  batch_run.py            Parallel CSV-driven batch runner
  parameters_case_b.yaml  Documented bounds (source of truth: cdm_common.py)
```

## Best practices (from sensitivity/)

- **Pre-built cdmcli.exe** for analysis runs (same as `sensitivity/run_sensitivity.py`)
- **integrationOptions.maxSteps = 20000** for stiff evaporation cases
- **Explicit `-i` / `-o`** flags to cdmcli (120 s timeout per run)
- **List-based JSON paths** for nested Case_B fields
- **Optional matplotlib/seaborn** for tornado, response curves, interaction heatmaps (`--plot`)

## Relationship to sensitivity/

The gitignored `sensitivity/run_sensitivity.py` was the original implementation.
`scripts/batch_sweep/` is the committed version with the same parameter definitions,
metrics, and default cdmcli path.

## See also

- [docs/driftml_assessment.md](../../docs/driftml_assessment.md)
- [sensitivity/sensitivity-analysis.qmd](../../sensitivity/sensitivity-analysis.qmd) (local, gitignored)
