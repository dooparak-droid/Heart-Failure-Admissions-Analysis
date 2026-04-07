# ============================================================================
# 02_prescription_eda.R
#
# Purpose:
#   Exploratory data analysis for prescription data in HF cohort.
#   Identifies top drugs, dosage patterns, and ICU prescribing rates.
#
# Dependencies:
#   - Must run 00_load_and_configure.R first
#   - Uses object: q3 (prescription data)
#
# Output:
#   - Console output for visual inspection
#   - No saved objects (this is exploration only)
#
# Author: Emmanuel Oparaku
# Date: January 2026
# ============================================================================

cat("\n============= Prescription EDA =============\n\n")

# ============================================================================
# 1. Prescription volume overview
# ============================================================================

cat("PRESCRIPTION OVERVIEW\n")
cat("-" %&% paste0(rep("=", 50)) %&% "\n")

cat(sprintf("Total prescriptions: %d\n", nrow(q3)))
cat(sprintf("Unique admissions: %d\n", n_distinct(q3$hadm_id)))
cat(sprintf("Unique drugs: %d\n", n_distinct(q3$drug)))

# ============================================================================
# 2. Top 10 most frequently prescribed drugs
# ============================================================================

cat("\n\nTOP 10 MOST FREQUENTLY PRESCRIBED DRUGS\n")
cat("-" %&% paste0(rep("=", 50)) %&% "\n")

top_10_drugs <- q3 %>%
  group_by(drug) %>%
  summarise(
    n_prescriptions = n(),
    n_admissions = n_distinct(hadm_id),
    pct_of_total = round(100 * n() / nrow(q3), 1),
    .groups = "drop"
  ) %>%
  arrange(desc(n_prescriptions)) %>%
  slice(1:10)

print(top_10_drugs)

# ============================================================================
# 3. Detailed analysis of top 5 drugs
# ============================================================================

cat("\n\nTOP 5 DRUGS: DETAILED ANALYSIS\n")
cat("-" %&% paste0(rep("=", 50)) %&% "\n")

top_5 <- top_10_drugs %>%
  slice(1:5) %>%
  pull(drug)

for (drug in top_5) {
  cat("\n" %&% drug %&% "\n")
  cat(paste0(rep("-", 40)) %&% "\n")

  drug_data <- q3 %>%
    filter(drug == !! drug)

  # Prescriptions overview
  cat(sprintf("Total prescriptions: %d\n", nrow(drug_data)))
  cat(sprintf("Admissions receiving drug: %d\n", n_distinct(drug_data$hadm_id)))

  # Dosage analysis
  if (!all(is.na(drug_data$dose_val_rx))) {
    cat("Dose units used:\n")
    dose_units <- drug_data %>%
      group_by(dose_unit_rx) %>%
      summarise(
        n = n(),
        mean_dose = round(mean(dose_val_rx, na.rm = TRUE), 2),
        .groups = "drop"
      ) %>%
      arrange(desc(n))
    print(dose_units)
  }

  # ICU prescribing
  icu_pct <- 100 * mean(drug_data$in_icu, na.rm = TRUE)
  cat(sprintf("Prescribed in ICU: %.1f%%\n", icu_pct))

  # Per-admission frequency
  per_adm <- nrow(drug_data) / n_distinct(drug_data$hadm_id)
  cat(sprintf("Mean prescriptions per admission: %.2f\n", per_adm))
}

# ============================================================================
# 4. ICU prescribing patterns
# ============================================================================

cat("\n\nICU PRESCRIBING PATTERNS\n")
cat("-" %&% paste0(rep("=", 50)) %&% "\n")

q3 %>%
  group_by(in_icu) %>%
  summarise(
    n = n(),
    pct = round(100 * n / nrow(q3), 1),
    .groups = "drop"
  ) %>%
  mutate(location = if_else(in_icu == 1, "In ICU", "Not in ICU")) %>%
  select(location, n, pct) %>%
  print()

# Top drugs in ICU vs non-ICU
cat("\n\nTop 5 drugs: ICU vs Non-ICU\n")

q3 %>%
  filter(drug %in% top_5) %>%
  group_by(drug, in_icu) %>%
  summarise(n = n(), .groups = "drop") %>%
  pivot_wider(names_from = in_icu, values_from = n, values_fill = 0) %>%
  mutate(
    in_icu_pct = round(100 * `1` / (`0` + `1`), 1),
    .keep = "unused"
  ) %>%
  rename(
    "In ICU" = "1",
    "Not in ICU" = "0",
    "ICU %" = "in_icu_pct"
  ) %>%
  print()

# ============================================================================
# 5. Dosage distribution analysis for top 5 drugs
# ============================================================================

cat("\n\nDOSAGE DISTRIBUTION: TOP 5 DRUGS\n")
cat("-" %&% paste0(rep("=", 50)) %&% "\n")

q3 %>%
  filter(drug %in% top_5, !is.na(dose_val_rx)) %>%
  group_by(drug, dose_unit_rx) %>%
  summarise(
    n = n(),
    mean_dose = round(mean(dose_val_rx, na.rm = TRUE), 2),
    median_dose = round(median(dose_val_rx, na.rm = TRUE), 2),
    .groups = "drop"
  ) %>%
  arrange(drug, desc(n)) %>%
  print()

# ============================================================================
# 6. Data quality checks
# ============================================================================

cat("\n\nDATA QUALITY CHECKS\n")
cat("-" %&% paste0(rep("=", 50)) %&% "\n")

# Missing dose values
missing_dose <- sum(is.na(q3$dose_val_rx))
cat(sprintf("Missing dose values: %d (%.1f%%)\n",
            missing_dose, 100 * missing_dose / nrow(q3)))

# Missing dose units
missing_units <- sum(is.na(q3$dose_unit_rx))
cat(sprintf("Missing dose units: %d (%.1f%%)\n",
            missing_units, 100 * missing_units / nrow(q3)))

# Missing start dates
missing_dates <- sum(is.na(q3$startdate))
cat(sprintf("Missing start dates: %d (%.1f%%)\n",
            missing_dates, 100 * missing_dates / nrow(q3)))

cat("\n✓ Prescription EDA complete.\n")
cat("Next: Run r/03_prepare_tables.R\n")
