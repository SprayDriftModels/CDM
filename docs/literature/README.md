# Spray drift literature for CDM development and validation

An annotated reading list for developing the Casanova Drift Model (CDM) and
validating it against measured field data, such as the SETAC DRAW database. The
citation keys refer to [`references.bib`](references.bib), which you can use
directly from Quarto (`bibliography: docs/literature/references.bib`).

## Verification

All DOIs and their metadata were checked against Crossref (November 2026).
Entries without a DOI (ISO standards, BBA Mitteilungen, conference proceedings)
were checked against the publisher or a citing source. Any field that could not
be confirmed is left out and named in the entry's `note`; nothing is filled in
from memory.

Open points:

- `ganzelmeier1995`: Rautmann et al. (2001) cite Heft 305. Some sources give 304
  for the German edition.
- `casanova2022cdm`, `woodward2008agdisp`: page ranges not confirmed.
- `adriaanse2022efsa`: the report number is EN-7662, but the registered DOI ends
  in EN-7661.
- `iso22369`: a multi-part series; cite the specific part and year when used.

## 1. CDM itself

| Key | Why it matters |
|---|---|
| `casanova2022cdm` | The only peer-reviewed CDM paper so far. |
| `casanova2026zenodo` | Collected CDM presentations, conference papers (2020–2022) and the draft user manual. |

EFSA EN-9506 (`holterman2025efsa`) reviews CDM alongside other models and points
out how little peer-reviewed CDM documentation exists. A published validation
against DRAW data would close that gap most directly.

## 2. Regulatory context, reference drift values, SETAC DRAW

| Key | Why it matters |
|---|---|
| `ganzelmeier1995`, `rautmann2001` | German basic drift values (90th percentile). These are the regulatory benchmark that CDM outputs are compared with. |
| `focus2001sw` | FOCUS surface water scenarios. Defines how drift enters the EU aquatic exposure assessment. |
| `efsa2014exposure` | EFSA guidance on operator, worker, resident and bystander exposure. Resident and bystander exposure to spray drift is where the vertical profile output could be used. |
| `mackay2018draw` | Aims and design of the SETAC DRAW workshops and database. **This is the main context for the validation workflow.** |
| `lewis2017efsa` | EFSA review of published drift and exposure data. A source of trials outside DRAW. |
| `adriaanse2022efsa` | Off-field spray drift deposition for non-target terrestrial organisms. Identifies the lack of deposition data on 3-D plant structures as a data gap. |
| `holterman2025efsa` | **The template for validation.** It sets data selection criteria (its Table 9), simulates each replicate separately, and compares graphically, by RMSE, and by the simulated/measured ratio per distance (acceptable range 0.4–2.5). |

## 3. Measurement standards and spray classification

| Key | Why it matters |
|---|---|
| `iso22866` | Field drift measurement. Sets the acceptance limits for trials (wind direction within 30° of perpendicular to the spray line, mean wind speed ≤ 5 m/s), which the validation dataset is filtered by. |
| `iso22856` | Wind tunnel drift measurement. Gives controlled data for checking settling and evaporation. |
| `iso22369` | Drift reduction classes of spray equipment. |
| `iso25358`, `asabeS572`, `southcombe1997bcpc` | Droplet spectrum measurement and nozzle classification. Background for the CDM DSD library and its nozzle selectors. |

## 4. Mechanistic and other spray drift models

These are the main comparators and sources of design ideas.

| Key | Why it matters |
|---|---|
| `bilanin1989agdisp` | Original AGDISP. CDM's model description cites it as a physics source. |
| `teske2002agdrift`, `bird2002agdrift` | AgDRIFT, the US regulatory aerial model, and its evaluation against field trials. A worked example of large-scale model validation. |
| `teske2009ground` | AGDISP extended to ground boom sprayers. The closest mechanistic analogue to CDM. |
| `woodward2008agdisp` | Independent field evaluation of AGDISP ground boom. |
| `miller1989simulation` | Early random-walk simulation of drift from hydraulic nozzles. |
| `holterman1997idefics` | IDEFICS, the Dutch regulatory model. Comparator in the validation. |
| `butlerellis2010silsoe`, `kennedy2012bream` | Silsoe model and BREAM, a probabilistic bystander exposure model. Relevant to airborne and vertical exposure. |
| `baetens2007cfd`, `baetens2009diffusion` | 3-D CFD model and a reduced 2-D model, validated on 38 field trials up to 20 m. Shows that the volume fraction of droplets below 191 µm is a single predictor of deposition. |
| `lofstrom2013oml` | OML-SprayDrift, a Gaussian-type model built for ground booms. |
| `teske2011review` | Review of deposition models. A good entry point. |

## 5. Droplet physics: drag and evaporation

| Key | Why it matters |
|---|---|
| `clift1970motion` | Smooth-sphere drag correlation, cited in CDM's model description. |
| `haider1989drag` | Alternative drag correlation, for sensitivity checks. |
| `ranz1952evaporation1`, `ranz1952evaporation2` | Ranz–Marshall evaporation and ventilation. The basis of most drift-model evaporation terms. |
| `goering1972droplet`, `williamson1974evaporating` | Early agricultural droplet deceleration and evaporation models. |
| `teske1998evaporation` | Measured evaporation rates of spray mixtures. Can check CDM's evaporation and non-volatile fraction settings. |

## 6. Droplet size, spray liquid and operating factors

| Key | Why it matters |
|---|---|
| `nuyttens2007nozzle` | Droplet size and velocity measured by nozzle type, size and pressure. A source of DSD-library inputs. |
| `nuyttens2007operator`, `nuyttens2011fiveyear` | Field effects of boom height, speed, pressure and nozzle on drift. Gives the expected direction and size of CDM parameter sensitivities. |
| `deschampheleire2009liquid` | Effects of spray liquid properties on DSD and drift. |
| `hilz2013formulation` | How much formulation can reduce drift. |
| `balsari2017testbench` | Test-bench drift potential versus boom height and nozzle. |

## 7. Field measurements, airborne and vertical drift, sampling

| Key | Why it matters |
|---|---|
| `wolters2008field` | Deposition and airborne drift measured together over winter wheat. A candidate test case for the vertical profile. |
| `butlerellis2010bystander` | Airborne drift at bystander positions, collected for model validation. |
| `arvidsson2011collectors` | Collection efficiency of airborne drift samplers. Must be accounted for when comparing CDM plane-crossing output with measured vertical profiles. |
| `donkersley2011meta` | Meta-analysis of drift sampling methods. Explains part of the variability between trials. |
| `vandezande2008techniques` | Overview of drift-reducing spray techniques. |

## 8. Model evaluation statistics

| Key | Why it matters |
|---|---|
| `chang2004evaluation` | Standard dispersion-model metrics: fractional bias (FB), geometric mean bias (MG), normalised mean square error (NMSE), geometric variance (VG), correlation (R) and fraction within a factor of two (FAC2). Used in the validation alongside the EN-9506 ratio and RMSE criteria. |

## Gaps to fill

These topics have no verified reference in the collection yet:

- Atmospheric surface layer: wind profile, stability and turbulence
  parameterisation used for transport (for example Monin–Obukhov similarity).
- Canopy interception and in-crop deposition, which matter for the plant
  interception data mentioned in `adriaanse2022efsa`.
- Field data on vertical profiles at several downwind distances, beyond
  `wolters2008field`.
- Global sensitivity analysis methods (Morris, Sobol) for the `sensitivity/`
  work.
