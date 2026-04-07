# ============================================================================
# 01_heart_failure_eda.R
#
# Purpose:
#   Exploratory data analysis for heart failure cohort.
#   Examines distributions, identifies patterns, and checks assumptions.
#
# Dependencies:
#   - Must run 00_load_and_configure.R first
#   - Uses objects: hf_patients, non_hf_patients, hf_cohort_raw
#
# Output:
#   - Console output and plots for visual inspection
#   - No saved objects (this is exploration only)
#
# Author: Emmanuel Oparaku
# Date: January 2026
# ============================================================================

cat("\n============= Heart Failure EDA =============\n\n")

# ============================================================================
# 1. Cohort composition
# ============================================================================

cat("COHORT COMPOSITION\n")
cat("-" %&% paste0(rep("=", 50)) %&% "\n")

hf_cohort_raw %>%
  group_by(heart_failure) %>%
  summarise(
    n = n(),
    pct = round(100 * n / nrow(hf_cohort_raw), 1)
  ) %>%
  mutate(cohort = if_else(heart_failure == 1, "Heart Failure", "Non-HF")) %>%
  select(cohort, n, pct) %>%
  print()

# ============================================================================
# 2. Demographic distributions in HF cohort
# ============================================================================

cat("\n\nDEMOGRAPHICS: Heart Failure Patients\n")
cat("-" %&% paste0(rep("=", 50)) %&% "\n")

# Age distribution
cat("\nAge Group Distribution:\n")
hf_patients %>%
  group_by(age_group) %>%
  summarise(n = n(), pct = round(100 * n / nrow(hf_patients), 1)) %>%
  print()

# Gender distribution
cat("\nGender Distribution:\n")
hf_patients %>%
  group_by(gender) %>%
  summarise(n = n(), pct = round(100 * n / nrow(hf_patients), 1)) %>%
  print()

# Ethnicity distribution
cat("\nEthnicity Distribution:\n")
hf_patients %>%
  group_by(ethnicity_group) %>%
  summarise(n = n(), pct = round(100 * n / nrow(hf_patients), 1)) %>%
  arrange(desc(n)) %>%
  print()

# Admission type distribution
cat("\nAdmission Type Distribution:\n")
hf_patients %>%
  group_by(admission_type) %>%
  summarise(n = n(), pct = round(100 * n / nrow(hf_patients), 1)) %>%
  arrange(desc(n)) %>%
  print()

# Diabetes status
cat("\nDiabetes Status:\n")
hf_patients %>%
  group_by(diabetes_status) %>%
  summarise(n = n(), pct = round(100 * n / nrow(hf_patients), 1)) %>%
  print()

# ============================================================================
# 3. Outcome variables: distributions and summary stats
# ============================================================================

cat("\n\nOUTCOMES: Heart Failure Patients\n")
cat("-" %&% paste0(rep("=", 50)) %&% "\n")

# Hospital LOS
cat("\nHospital Length of Stay (days):\n")
hf_patients %>%
  summarise(
    min = min(hospital_los_days, na.rm = TRUE),
    q25 = quantile(hospital_los_days, 0.25, na.rm = TRUE),
    median = median(hospital_los_days, na.rm = TRUE),
    q75 = quantile(hospital_los_days, 0.75, na.rm = TRUE),
    max = max(hospital_los_days, na.rm = TRUE),
    mean = round(mean(hospital_los_days, na.rm = TRUE), 2),
    sd = round(sd(hospital_los_days, na.rm = TRUE), 2),
    n_missing = sum(is.na(hospital_los_days))
  ) %>%
  print()

# ICU LOS
cat("\nICU Length of Stay (days):\n")
hf_patients %>%
  filter(!is.na(icu_los_days)) %>%
  summarise(
    min = min(icu_los_days, na.rm = TRUE),
    q25 = quantile(icu_los_days, 0.25, na.rm = TRUE),
    median = median(icu_los_days, na.rm = TRUE),
    q75 = quantile(icu_los_days, 0.75, na.rm = TRUE),
    max = max(icu_los_days, na.rm = TRUE),
    mean = round(mean(icu_los_days, na.rm = TRUE), 2),
    n_with_icu = n()
  ) %>%
  print()

# Mortality
cat("\nMortality:\n")
hf_patients %>%
  summarise(
    n_deaths = sum(hospital_expire_flag, na.rm = TRUE),
    n_total = n(),
    mortality_pct = round(100 * mean(hospital_expire_flag, na.rm = TRUE), 2)
  ) %>%
  print()

# ============================================================================
# 4. Outcome stratification by age
# ============================================================================

cat("\n\nOUTCOMES BY AGE GROUP\n")
cat("-" %&% paste0(rep("=", 50)) %&% "\n")

hf_patients %>%
  group_by(age_group) %>%
  summarise(
    n = n(),
    median_los = round(median(hospital_los_days, na.rm = TRUE), 1),
    median_icu = round(median(icu_los_days, na.rm = TRUE), 1),
    mortality_pct = round(100 * mean(hospital_expire_flag, na.rm = TRUE), 1)
  ) %>%
  print()

# ============================================================================
# 5. Check for data quality issues
# ============================================================================

cat("\n\nDATA QUALITY CHECKS\n")
cat("-" %&% paste0(rep("=", 50)) %&% "\n")

# Negative LOS values (should be none, but check)
neg_los <- hf_patients %>%
  filter(hospital_los_days < 0, !is.na(hospital_los_days)) %>%
  nrow()

cat(sprintf("Negative hospital LOS: %d\n", neg_los))

# Negative ICU LOS (should be none due to SQL CASE statement)
neg_icu <- hf_patients %>%
  filter(icu_los_days < 0, !is.na(icu_los_days)) %>%
  nrow()

cat(sprintf("Negative ICU LOS: %d\n", neg_icu))

# Extreme age values
cat("\nAge distribution:\n")
hf_patients %>%
  summarise(
    min = min(age, na.rm = TRUE),
    max = max(age, na.rm = TRUE),
    n_age_89 = sum(age == 89, na.rm = TRUE)
  ) %>%
  print()

cat("\n✓ EDA complete.\n")
cat("Next: Run r/02_prescription_eda.R\n")
