# ============================================================================
# 00_load_and_configure.R
#
# Purpose:
#   Establish database connection to MIMIC-III and load all required packages.
#   This is the first script to run; all subsequent scripts depend on 'conn'.
#
# Prerequisites:
#   - Valid MIMIC-III access via Data Use Agreement with PhysioNet
#   - Institutional access to healthdatascience.lshtm.ac.uk PostgreSQL server
#   - R packages installed (see install instructions in README)
#
# Output:
#   - Database connection object: conn
#   - Two primary data objects: hf_patients, non_hf_patients
#   - Prescription data: q3
#
# Author: Emmanuel Oparaku
# Date: January 2026
# ============================================================================

# ============================================================================
# Load required libraries
# ============================================================================

library(DBI)
library(RPostgres)
library(tidyverse)
library(dbplyr)
library(lubridate)
library(gtsummary)
library(gt)

# Set options for reproducibility and clarity
options(
  modelsummary_format_numeric_latex = "plain",  # Prevent LaTeX rendering issues
  dplyr.print_max = Inf                         # Show all rows when printing
)

# ============================================================================
# Establish PostgreSQL connection to MIMIC-III
# ============================================================================

# Use getPass for secure password entry (will not echo to console)
if (!require(getPass, quietly = TRUE)) {
  install.packages("getPass")
  library(getPass)
}

cat("Connecting to MIMIC-III database...\n")
cat("You will be prompted to enter your MIMIC database password.\n")
cat("(Password will not be echoed to the console)\n\n")

pswd <- getPass::getPass("Enter MIMIC database password: ")

conn <- dbConnect(
  RPostgres::Postgres(),
  dbname = "mimic",
  host = "healthdatascience.lshtm.ac.uk",
  port = 5432,
  user = "student",
  password = pswd
)

# Verify connection is active
if (dbIsValid(conn)) {
  cat("✓ Database connection established successfully.\n")
} else {
  stop("✗ Failed to connect to database. Check credentials and try again.")
}

# ============================================================================
# Load data from SQL views
# ============================================================================

cat("\nLoading cohort data from SQL views...\n")

# Load heart failure cohort (includes both HF and non-HF admissions)
# This table was created by sql/01_build_cohort.sql
hf_cohort_raw <- dbGetQuery(conn, "SELECT * FROM public.hf_cohort")

# Load prescription data for HF patients
# This table was created by sql/01_build_cohort.sql
q3 <- dbGetQuery(conn, "SELECT * FROM public.hf_drug_summary_view")

cat("✓ Data loaded successfully.\n\n")
cat(sprintf("  - hf_cohort_raw: %s admissions\n", nrow(hf_cohort_raw)))
cat(sprintf("  - q3 (prescriptions): %s records\n", nrow(q3)))

# ============================================================================
# Prepare data for analysis
# ============================================================================

cat("\nPreparing data for analysis...\n")

# Create age groups for stratification
hf_cohort_raw <- hf_cohort_raw %>%
  mutate(
    age_group = case_when(
      age < 18 ~ "0-17",
      age < 60 ~ "18-59",
      TRUE ~ "60+"
    ) %>% factor(levels = c("0-17", "18-59", "60+"))
  )

# Create diabetes status labels
hf_cohort_raw <- hf_cohort_raw %>%
  mutate(
    diabetes_status = case_when(
      secondary_diabetes == 0 ~ "No secondary diabetes",
      secondary_diabetes == 1 ~ "Secondary diabetes",
      TRUE ~ NA_character_
    ) %>% factor(levels = c("No secondary diabetes", "Secondary diabetes"))
  )

# Create gender labels (standardize)
hf_cohort_raw <- hf_cohort_raw %>%
  mutate(
    gender = factor(gender, levels = c("F", "M"))
  )

# Separate into HF and non-HF cohorts for easier analysis
hf_patients <- hf_cohort_raw %>%
  filter(heart_failure == 1)

non_hf_patients <- hf_cohort_raw %>%
  filter(heart_failure == 0)

cat("✓ Data prepared for analysis.\n\n")
cat(sprintf("  - HF patients: %s admissions\n", nrow(hf_patients)))
cat(sprintf("  - Non-HF patients: %s admissions\n", nrow(non_hf_patients)))

# ============================================================================
# Data quality checks
# ============================================================================

cat("\nPerforming data quality checks...\n")

# Check 1: Missing values in key variables
missing_check <- hf_cohort_raw %>%
  summarise(across(everything(), ~ sum(is.na(.)))) %>%
  pivot_longer(everything(), names_to = "variable", values_to = "n_missing") %>%
  filter(n_missing > 0)

if (nrow(missing_check) > 0) {
  cat("  ⚠ Variables with missing values:\n")
  print(missing_check)
} else {
  cat("  ✓ No missing values in key variables.\n")
}

# Check 2: Outcome variables distribution
cat("  ✓ Hospital LOS (days): ",
    sprintf("min=%.1f, max=%.1f, median=%.1f\n",
            min(hf_cohort_raw$hospital_los_days, na.rm = TRUE),
            max(hf_cohort_raw$hospital_los_days, na.rm = TRUE),
            median(hf_cohort_raw$hospital_los_days, na.rm = TRUE)))

cat("  ✓ Hospital mortality: ",
    sprintf("%d deaths (%.1f%%)\n",
            sum(hf_cohort_raw$hospital_expire_flag, na.rm = TRUE),
            100 * mean(hf_cohort_raw$hospital_expire_flag, na.rm = TRUE)))

cat("\n✓ Data quality checks complete.\n")
cat("\nSetup complete. Ready to proceed to analysis scripts.\n")
cat("Next: Run r/01_heart_failure_eda.R\n")
