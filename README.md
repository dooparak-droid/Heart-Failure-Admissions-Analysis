# Heart Failure Admissions Report

A reproducible, auditable pipeline for generating executive summaries of
heart failure admissions from the MIMIC-III clinical database.

## Overview

This project demonstrates a modern data analysis workflow combining SQL
data extraction, R transformation, and Quarto reporting. The pipeline is
designed for reproducibility and ease of re-generation in future
reporting cycles.

**Key features:** - **Separated concerns**: SQL queries → R
transformation → Quarto rendering - **Frozen data architecture**:
Intermediate results stored as RDS objects, enabling report re-rendering
without database queries - **Transparent logic**: Clear cohort
definitions, documented decisions, auditable code -
**Privacy-conscious**: Efficient queries, minimal data extraction, no
hard-coded credentials

## What's Inside

The report generates a 3-page executive summary with:

1.  **Demographics** — Characteristics of heart failure vs. non-HF
    admissions, stratified by secondary diabetes status
2.  **Clinical outcomes** — Hospital and ICU length of stay, in-hospital
    mortality, stratified by age, gender, diabetes, and ethnicity
3.  **Prescription patterns** — Top 5 medications, mean dosages, ICU
    prescribing rates, frequency per admission

## Project Structure

```         
heart-failure-admissions-report/
├── README.md                          # This file
├── LICENSE                            # MIT License
├── .gitignore                         # Version control exclusions
├── STRUCTURE.md                       # Technical architecture & decisions
│
├── sql/
│   └── 01_build_cohort.sql           # SQL views: hf_cohort, hf_drug_summary_view
│
├── r/
│   ├── 00_load_and_configure.R       # Database connection & setup (RUN FIRST)
│   ├── 01_heart_failure_eda.R        # Exploratory data analysis: HF cohort
│   ├── 02_prescription_eda.R         # Exploratory data analysis: prescriptions
│   └── 03_prepare_tables.R           # Generate .rds objects for report
│
├── reports/
│   ├── heart_failure_report.qmd      # Quarto template (renders .pdf)
│   └── outputs/                       # (generated locally; not in repo)
│
├── docs/
│   └── handover_notes.md              # Technical handover documentation
│
└── data/
    └── .gitkeep                       # Placeholder; data lives in MIMIC only
```

## Quick Start

### Prerequisites

1.  **MIMIC-III Access**

    -   Valid Data Use Agreement with PhysioNet
    -   Access to `healthdatascience.lshtm.ac.uk` PostgreSQL server
    -   See [PhysioNet
        MIMIC-III](https://physionet.org/content/mimiciii/) for details

2.  **Software**

    -   R ≥ 4.1 (check with `R --version`)
    -   RStudio (recommended) or command-line R
    -   Quarto CLI ≥ 1.3 (check with `quarto --version`)
    -   TinyTeX for PDF output

3.  **R Packages**

    ``` r
    install.packages(c(
      "DBI", "RPostgres", "tidyverse", "lubridate",
      "gtsummary", "gt", "getPass"
    ))
    ```

### Installation

1.  **Clone this repository**

    ``` bash
    git clone https://github.com/yourusername/heart-failure-admissions-report.git
    cd heart-failure-admissions-report
    ```

2.  **Install Quarto and TinyTeX** (if needed)

    ``` bash
    # macOS / Linux
    quarto install tinytex
    ```

### Generate the Report

Run scripts **in order**:

``` bash
# Step 1: Establish DB connection & load data
Rscript r/00_load_and_configure.R

# Step 2 & 3: Exploratory checks (optional, but recommended)
Rscript r/01_heart_failure_eda.R
Rscript r/02_prescription_eda.R

# Step 4: Prepare summary tables (generates .rds objects)
Rscript r/03_prepare_tables.R

# Step 5: Render PDF report
cd reports
quarto render heart_failure_report.qmd --to pdf
```

**Or in RStudio:**

1.  Open `r/00_load_and_configure.R`, run the script
2.  Open `r/03_prepare_tables.R`, run the script
3.  Open `reports/heart_failure_report.qmd`, click **Render**

The PDF will be saved as `reports/heart_failure_report.pdf`.

## Cohort Definition

### Heart Failure

-   **ICD-9 code(s):** `428.x` (all heart failure diagnoses, any
    sequence)
-   **Rationale:** Captures systolic HF, diastolic HF, and unspecified
    HF

### Secondary Diabetes

-   **ICD-9 codes:** `249.x` OR `250.x` (with `seq_num > 1` only)
-   **Rationale:**
    -   `249.x`: Secondary diabetes with complications/manifestations
        (specific to other conditions)
    -   `250.x` with `seq_num > 1`: Type I or II diabetes as *secondary*
        diagnosis
    -   Excludes `250.x` as primary diagnosis to focus on comorbid
        diabetes

### Data Quality Decisions

-   **Age:** Capped at 89 per MIMIC-III de-identification convention
-   **Hospital LOS:** Set to NULL if discharge time \< admission time
    (likely data entry errors)
-   **ICU LOS:** Set to NULL if calculated value \< 0 (negative
    durations indicate quality issues)
-   **Ethnicity:** Collapsed into 5 categories (White, Black, Asian,
    Hispanic, Other/Unknown) for interpretability

## Key Design Principles

### 1. Reproducibility

-   All logic is in code; nothing is manual
-   SQL views are immutable; can be re-run without side effects
-   Intermediate results (RDS objects) freeze data at a specific point
    in time
-   Report rendering depends only on RDS files, not on database

### 2. Auditability

-   Each script is self-contained and documented
-   Database connection is isolated (00_load_and_configure.R)
-   No hard-coded credentials; passwords entered at runtime
-   Comments explain *why* decisions were made, not just *what* code
    does

### 3. Minimal Data Extraction

-   SQL queries select only required columns
-   Views avoid redundant computations
-   R scripts process in-memory only

### 4. Extensibility

-   New stratifications can be added to `03_prepare_tables.R` without
    re-running SQL
-   Reporting decisions are separated from data processing
-   Easy to modify table formats, add figures, or adjust inclusion
    criteria

## Troubleshooting

### "Cannot coerce class 'function' to a data.frame"

-   **Cause:** Missing RDS file in `reports/` directory
-   **Fix:** Run `r/03_prepare_tables.R` first to generate `.rds` files

### Quarto PDF won't render

-   **Cause:** Missing TinyTeX or LaTeX packages
-   **Fix:** Run `quarto install tinytex` in terminal

### Database connection fails

-   **Cause:** Invalid credentials or no network access
-   **Fix:** Check VPN, verify username/password, confirm server address

### Tables overflow page width

-   **Cause:** Font sizes or column widths adjusted in
    `03_prepare_tables.R`
-   **Fix:** See "Critical Formatting Notes" in STRUCTURE.md

## Data Privacy & Confidentiality

-   **MIMIC-III:** De-identified, publicly available dataset from
    PhysioNet
-   **This repository:** Contains code only; no patient data
-   **Outputs:** Summary statistics only (no individual-level data
    exported)
-   **Credentials:** Never stored in version control; use `getPass()`
    for prompts

## Performance Notes

-   Initial data loading: \~30 seconds (depends on network)
-   R table preparation: \~10 seconds
-   Quarto rendering: \~5 seconds
-   Total time: \~1 minute

## Future Enhancements

Potential extensions discussed in handover notes:

1.  **Smoking history** — ODK form data collection (not in MIMIC-III)
2.  **Medication adherence** — Patient-reported outcomes
3.  **Social determinants** — Housing stability, employment status
4.  **Temporal analysis** — Trends across admission types and seasons

See `docs/handover_notes.md` for detailed discussion.

## Licensing

This code is provided as-is for educational and research purposes.

IMPORTANT: Any use of this code requires valid access to the MIMIC-III
database
and compliance with the MIMIC-III Data Use Agreement
([https://physionet.org/content/mimiciii/).](https://physionet.org/content/mimiciii/).)

The code structure and approach are intended as examples of reproducible
research
practices and can be adapted for other datasets. If you do so, please
acknowledge
the original source.

## Citation

If you use this code or methodology, please cite:

```         
Heart Failure Admissions Report Pipeline
Emmanuel Oparaku
2026
https://github.com/dooparak-droid/Heart-Failure-Admissions-Analysis
```

## Contact & Support

For questions or issues: - Check `docs/STRUCTURE.md` for technical
details - Review inline code comments - Submit issues or pull requests
on GitHub

## Acknowledgments

-   MIMIC-III database: Johnson et al., *Scientific Data* (2016)
-   Pipeline design inspired by modern data engineering best practices
-   Report template uses `gtsummary` and `gt` packages for professional
    tables

------------------------------------------------------------------------

**Last updated:** January 2026
