---
editor_options: 
  markdown: 
    wrap: 72
---

# Technical Architecture & Handover Notes

## Overview

This document explains the end-to-end system design and key decisions
behind the Heart Failure Admissions Report pipeline. It is intended for
technical collaborators who will maintain or extend this work.

## System Architecture

### Frozen Data Pattern

The pipeline follows a "frozen data" architecture:

```         
Database (MIMIC-III)
    ↓
SQL Views (public.hf_cohort, public.hf_drug_summary_view)
    ↓
R Data Extraction (dbGetQuery)
    ↓
R Transformation (filtering, grouping, calculations)
    ↓
RDS Serialization (frozen .rds objects)
    ↓
Quarto Rendering (readRDS → report output)
```

**Rationale:** - Separates data processing (which requires DB access)
from reporting (which doesn't) - Allows report re-rendering without
re-querying the database - Provides clear checkpoint for auditing
intermediate results - Reduces report generation time on subsequent runs

### Script Execution Order

**Critical: Scripts must run in this order.**

1.  **sql/01_build_cohort.sql**
    -   Creates two SQL views: `hf_cohort` and `hf_drug_summary_view`
    -   Defines cohort inclusion/exclusion rules
    -   Handles data quality transformations (e.g., NULL for negative
        LOS)
2.  **r/00_load_and_configure.R**
    -   Establishes PostgreSQL connection to MIMIC-III
    -   Loads packages and sets options
    -   Extracts raw data into R objects: `hf_cohort_raw`, `q3`
    -   Creates derived objects: `hf_patients`, `non_hf_patients`
    -   Performs basic data quality checks
3.  **r/01_heart_failure_eda.R** (optional but recommended)
    -   Exploratory analysis of HF cohort
    -   Checks distributions, missing values, outliers
    -   Validates assumptions before creating report tables
4.  **r/02_prescription_eda.R** (optional but recommended)
    -   Exploratory analysis of prescription data
    -   Identifies top drugs, dosage patterns, ICU usage
    -   Validates medication data quality
5.  **r/03_prepare_tables.R**
    -   Transforms raw data into publication-ready tables
    -   Creates four .rds objects:
        -   `q1_hf_outcomes_summary.rds` (Table 1)
        -   `q1_non_hf_outcomes_summary.rds` (Table 2)
        -   `q2_outcomes_summary.rds` (Table 3)
        -   `q3_prescriptions_summary.rds` (Table 4)
    -   **Note:** Must save .rds files in same directory as .qmd file
6.  **reports/heart_failure_report.qmd**
    -   Quarto template that renders the final PDF
    -   Loads .rds files and inserts them into the document
    -   Does NOT query the database

## Key Technical Decisions

### Cohort Definition

**Heart Failure Identification** - Method: ICD-9 code matching (428.x) -
Rationale: MIMIC-III uses ICD-9; this is the standard HF diagnosis
code - Alternatives considered: Text search on diagnosis table
(rejected: noise from unstructured data)

**Secondary Diabetes Handling** - Method: Separate flags for 249.x
(secondary diabetes with manifestations) and 250.x (with seq_num \> 1) -
Rationale: Distinguishes diabetes as primary diagnosis vs. comorbidity -
SQL logic:
`sql   WHERE icd9_code LIKE '249%'      OR (icd9_code LIKE '250%' AND seq_num > 1)`

**Age Capping at 89** - Reason: MIMIC-III de-identification protocol
caps all ages ≥ 90 at 89 - Implication: Cannot distinguish centenarians;
affects only \~2% of cohort

**Ethnicity Collapsing** - Method: Pattern matching on
`admission.ethnicity` field - Categories: White, Black, Asian, Hispanic,
Other/Unknown - Rationale: MIMIC ethnicity data is messy (inconsistent
spelling, abbreviations); collapsing reduces miscoding - Example
mappings: - '%WHITE%' → 'White' (matches 'WHITE', 'White', 'Caucasian',
etc.) - '%BLACK%' → 'Black' (matches 'BLACK', 'Black', 'African
American', etc.)

### Data Quality Transformations

**Negative Hospital LOS** - Occurs when:
`discharge_time < admission_time` (data entry errors) - Action: Set to
NULL in SQL with CASE statement - Frequency: \~0.5% of records -
Implication: Excluded from LOS calculations (median, IQR)

**Negative ICU LOS** - Occurs when: `ICU_outtime < ICU_intime` (rare,
but possible) - Action: Set to NULL in SQL - Implication: Patients with
negative LOS treated as having no ICU stay

**Missing Age Values** - Occurs when: `date_of_birth` is NULL - Action:
Excluded from age-stratified analyses - Frequency: \<1% of records

### Table Construction

**Table 1 & 2: Demographics** - Method: `gtsummary::tbl_summary()` with
`by = diabetes_status` - Format: Categorical counts and percentages -
Stratification: HF vs. non-HF shown separately - Note: Required
`as_gt()` conversion to apply `gt` styling

**Table 3: Clinical Outcomes** - Method: `median_iqr()` helper function
for median (IQR) formatting - Format: Stratified by age, gender,
diabetes, ethnicity (separate rows, grouped display) - Mortality:
Percentage of admissions with `hospital_expire_flag == 1` - Note: Row
groups created using `gt(groupname_col = "stratifier")`

**Table 4: Medications** - Method: Top 5 drugs by prescriptions, with
aggregation across admissions - Dose calculation: Mean of most
frequently used dose unit per drug - ICU % calculated: `MEAN(in_icu)`
over all prescriptions for that drug - Per-admission frequency: Total
prescriptions ÷ unique admissions

### Formatting Notes (Critical for Page Limits)

To keep the report within 3 pages:

1.  **Font sizes:** 9pt for tables, 10pt for titles (see
    `tab_options()`)
2.  **Row padding:** `px(2)` for data rows (very tight)
3.  **Column widths:** Fixed widths using `cols_width()` to prevent text
    wrapping
4.  **LaTeX settings:** Reduced spacing (`\textfloatsep`, `\floatsep`,
    `\intextsep`) in Quarto YAML
5.  **Table header conversion:** Required `as_gt()` after
    `tbl_summary()` before applying gt styling

Removing any of these will likely cause tables to spill to a 4th page.

## Database Connection Security

### getPass() Function

``` r
pswd <- getPass::getPass("Enter MIMIC database password: ")
```

**Why:** Prevents password from appearing in R history or logs
**Alternative:** Could use `.Renviron` file, but `getPass()` is more
interactive and less risky

### Credential Storage

-   **Never:** Hard-code passwords in scripts
-   **Never:** Commit `.Renviron` files to version control
-   **Always:** Use `getPass()` or similar prompt-based method

## Reproducibility & Auditability

### Code Review Checklist

When reproducing or auditing this pipeline, verify:

-   [ ] SQL queries extract minimal columns (privacy)
-   [ ] No hard-coded credentials in any script
-   [ ] `00_load_and_configure.R` runs without errors
-   [ ] Data objects (`hf_patients`, `non_hf_patients`) have expected
    row counts:
    -   `hf_patients`: \~13,600
    -   `non_hf_patients`: \~45,400
-   [ ] Table 1 & 2: Total N matches HF/non-HF splits
-   [ ] Table 3: Mortality % is in range 9–20% (known from clinical
    literature)
-   [ ] Table 4: Top 5 medications are diuretics/electrolytes (expected
    for HF)
-   [ ] Quarto renders without LaTeX errors
-   [ ] PDF is exactly 3 pages

### Expected Output Summaries

**HF Cohort (Table 1)** - N = 13,608 (or within ±5% if data updated) -
Age 60+: \~82% - Male: \~52% - White ethnicity: \~75% - Emergency
admission: \~87% - Secondary diabetes: \~39%

**Clinical Outcomes (Table 3)** - Hospital LOS median: 7.6–9.1 days
(across strata) - Age 0–17: 24.1 days (small N; likely newborns with
complications) - Mortality: 14.2–14.8% (overall), higher in 60+, lower
in Black/Hispanic - ICU LOS median: 2.5–3.7 days

**Top 5 Medications (Table 4)** 1. Furosemide (diuretic) 2. Potassium
Chloride (electrolyte) 3. D5W (IV fluid) 4. Insulin 5. NS (IV normal
saline)

If results deviate significantly, check: - SQL views are created
correctly - Cohort definitions haven't changed - Database hasn't been
updated with new MIMIC data

## Future Extensions

### Recommended Additions

1.  **Additional stratifications:**
    -   Comorbidity index (Elixhauser, Charlson)
    -   NYHA functional class (if added to future data collection)
    -   HF phenotype (HFrEF, HFpEF; inferred from EF if available)
2.  **New data sources:**
    -   Patient-reported smoking history (ODK form)
    -   Medication adherence at admission
    -   Social determinants (housing, employment)
3.  **Enhanced visualizations:**
    -   Forest plots for mortality odds ratios
    -   Kaplan-Meier curves (if mortality data is time-indexed)
    -   Sankey diagrams (admission type → ICU admission → discharge)
4.  **Temporal analysis:**
    -   Admission trends by season
    -   Readmission within 30 days

### Implementation Approach

1.  Create new SQL view for additional variables (don't modify existing
    views)
2.  Load new data in `00_load_and_configure.R`
3.  Add exploration in `01_heart_failure_eda.R` or
    `02_prescription_eda.R`
4.  Create new tables in `03_prepare_tables.R` (don't modify existing
    tables)
5.  Insert new tables into Quarto template as needed
6.  Adjust Quarto YAML spacing if going beyond 3 pages

## Maintenance & Refresh Cycles

### Annual Report Regeneration

1.  Confirm SQL views still exist:
    `SELECT * FROM public.hf_cohort LIMIT 1;`
2.  Run `r/00_load_and_configure.R` to extract fresh data
3.  Review EDA outputs; check for new/unexpected patterns
4.  Run `r/03_prepare_tables.R`
5.  Render Quarto
6.  Spot-check against previous year's report (numbers should be stable)
7.  Commit new PDF with version tag: `git tag v2026-01-09`

### Troubleshooting Common Issues

| Issue | Cause | Fix |
|----|----|----|
| "relation hf_cohort does not exist" | SQL views not created | Run `sql/01_build_cohort.sql` in database first |
| RStudio won't find conn object | Script not run in order | Restart R, run `00_load_and_configure.R` first |
| "Cannot coerce function to data.frame" | Missing .rds file | Ensure `03_prepare_tables.R` saved .rds files in reports/ |
| Quarto PDF font too small | Already formatted | Don't reduce font sizes further; remove content instead |
| Report is 4+ pages | Tables too wide | See formatting notes above; reduce column widths |

## References

-   MIMIC-III documentation: <https://mimic.mit.edu/>
-   Quarto documentation: <https://quarto.org/>
-   gtsummary vignettes: <https://www.danieldsjoberg.com/gtsummary/>
-   ICD-9 diagnosis codes: <https://icd.who.int/>

------------------------------------------------------------------------

**Document version:** 1.0\
**Last updated:** January 2026\
**Maintainer:** Emmanuel Oparaku
