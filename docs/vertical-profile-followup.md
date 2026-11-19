# Vertical-profile follow-up to Alex's patch

This change applies after `feature_vertical_crossings_from_5311727.patch`,
which itself applies to commit `5311727`. It preserves the DSD selection,
trajectory recording, ground-deposition calculation, and final-fate mass-balance
ledger from that patch.

## Shared collaboration baseline

`collab/alex-vertical-profile` combines Alex's DSD-selection and final-fate
accounting work with Zhenglei's separate occupancy and plane-crossing outputs.
It is prepared from the public `publication` baseline using selected code,
tests and documentation, without merging private development history.

This branch already contains both contributions: do not apply Alex's original
patch or the follow-up patch to it again. The patch application order above is
only for reconstructing the integration from the older shared base.

Before exchanging further changes, record the agreed baseline with
`git rev-parse HEAD` and share that exact commit ID. Start individual feature
branches from that commit and keep manuscript drafts, research notes, local
configuration and generated distributions out of collaboration commits.
The prepared branch is local until explicitly published or exchanged.

## Output migration

All four arrays are under `output.verticalProfile`:

| Key | Meaning |
|---|---|
| `resultsByDistanceCellCrossing` | Multi-source interval occupancy diagnostic |
| `resultsByDistanceCellCrossingSingleNozzle` | Single-nozzle interval occupancy diagnostic |
| `resultsByDistancePlaneCrossing` | Multi-source vertical-plane crossings |
| `resultsByDistancePlaneCrossingSingleNozzle` | Single-nozzle vertical-plane crossings |

**Plotting scripts using Alex's `resultsByDistanceCellCrossing` for plane
crossings must change to `resultsByDistancePlaneCrossing`**, and likewise for
the single-nozzle key. There are no duplicate aliases. Both methods are computed
when profile heights and distances are configured; no runtime method switch is
introduced.

Occupancy assigns a full source/streamline/droplet-class weight to every height
bin intersected by the chord between successive distance samples. It deliberately
retains the earlier diagnostic behavior, including repeated-bin counting.

Plane crossing evaluates one height per source/streamline/droplet-class at each
plane and adds its weight to one bin only. Multi-source planes are at `FD + d`
with trajectory coordinates relative to each source midpoint; single-nozzle
planes use nozzle-relative distance `d`. Plane bins are half-open, except the
uppermost edge is included; zero-thickness bins are skipped. Relative to Alex's
patch, an exact internal height boundary belongs to the upper bin rather than
the lower bin. Only configured height coverage contributes to the sums.

## Units and conservation

Plane percentages are fractions of total applied **initial volume**. With uniform
initial composition and a conserved active ingredient they also represent
fractions of total applied active ingredient. They are not remaining liquid
volume after evaporation. These are raw 2D trajectories without the lateral
plume-spreading step of ground deposition, not a collector-loading prediction.

`APPlume` and the aligned `Dep` row remain local ground-deposition percentages
relative to intended application rate. They are not fractions of total applied
material and cannot be added directly across sampling distances or to the plane
sum. Such a cumulative fraction requires spatial integration, appropriate area
weighting, and consistent normalization.

The `TotDep` row is removed: it substituted local field-edge deposition for total
in-field deposition, then summed local percentages. Its value depended on the
distance sampling grid. This does not alter the ground-deposition model.

The verbose report prints separate multi-source occupancy and plane tables.
`OccSum` is a diagnostic, not airborne mass. `Air` is the initial-volume-weighted
plane sum within the reported heights, not the final airborne fate. Volume tables
are normalized by sprayed field area, not by vertical-plane area.

Alex's `massBalance` output remains unchanged. Its initial-volume fate fields and
its remaining-liquid/evaporation fields describe final trajectory fates, not
cumulative deposition before a particular plane. The unresolved remainder
includes unrepresented DSD tails and inactive or missing contributions; closure
with that remainder is bookkeeping, not independent validation of the deposition
curve. A droplet crossing 20 m may deposit later.

## DSD library

Runtime DSD selectors from Alex's patch are retained. Neither that patch nor this
follow-up includes a calibrated default library. Supply Alex's library separately
with `--dsd-library`, `CDM_DSD_LIBRARY`, or his default lookup paths. Do not treat
the test case's DSD as a newly validated default.

## Display and smoothing policy

Plane crossings are discrete representative-trajectory results, not a continuous
concentration field. In Case B, 23 droplet classes and 11 fan streamlines each
contribute whole class weights to one height bin at a plane. Empty bins mean no
represented crossing, not proof of physically zero spray concentration.

`scripts/plot_vertical_profile_diagnostics.py` preserves raw cell/plane and
multi/single-nozzle diagnostics and adds
`03_plane_crossing_presentation_multi.png`. This is display-only log-space
interpolation with a trajectory-support opacity fade. It changes neither model
JSON nor accounting, adds no trajectories, and is not turbulent dispersion.
The image explicitly labels this distinction. Its log scale is independent of
the raw heatmaps' `--color-scale` setting.

Three levels must remain separate:

1. Presentation rendering: colors only; raw JSON remains authoritative.
2. Refined numerical profiles: potential future interpolation between diameter
   trajectories, requiring convergence, aggregation and accounting tests.
3. Physical dispersion: future model-science work requiring specification and
   independent validation. A smooth image alone is not this physics.

The plotting helper is currently a Case B diagnostic (including its plot limits
and titles), not a general collector-loading predictor. It requires Python 3.10+
with NumPy and Matplotlib. For a CLI export containing all four profile arrays:

```text
python scripts/plot_vertical_profile_diagnostics.py case_b_vp.json -o figures
```

It writes five PNGs and `summary.csv`. CSV column names containing `airborne`
are retained for compatibility: cell rows are occupancy sums, while plane rows
are initial-volume crossing sums over the reported height range, not final
airborne fate. Optional trajectory overlays need the companion binary export.

## Validation

`tests/Case_B_vertical_profile_distances.json` enables the four outputs.
The CTest test `vertical_profile_followup` checks output shapes, plane sums,
occupancy distinction, zero-thickness ground bins, plane-grid independence,
unchanged ground deposition and ledger across profile configurations, and the
two ledger sums. Ledger closure assertions test accounting consistency, not
physical validation.

The same test checks custom DSDs, JSON profile selection, explicit overrides,
label/nozzle aliases, and rejection of unknown selectors. The separate CTest
test `vertical_profile_report` checks report labels, removal of `TotDep`, and
CLI profile listing. `tests/dsd_profiles_test.json` is a synthetic test fixture,
not a calibrated nozzle distribution.

The original two JSON keys intentionally change back to occupancy semantics;
use the new plane keys for comparisons with Alex's plane output.

Windows x64 Release validation with MSVC 19.29 passed both CTests. Matched
runs of Case B, G, I and the coarse/fine Case B profile fixtures gave zero
differences in all shared numeric outputs against Alex's original patch and
Zhenglei's pre-integration branch (mapping Alex's cell keys to the plane keys).
Fine height bins aggregate to the same plane weights and hit counts at shared
distances. This is regression evidence, not experimental calibration; the exact
height-boundary convention change described above still applies.
