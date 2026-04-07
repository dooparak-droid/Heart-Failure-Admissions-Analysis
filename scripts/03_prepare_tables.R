# ============================================================================
# 03_prepare_tables.R
#
# Purpose:
#   Transform raw data into publication-ready summary tables.
#   Creates four RDS objects consumed by the Quarto report.
#
# Dependencies:
#   - Must run 00_load_and_configure.R first
#   - Uses objects: hf_patients, non_hf_patients
#   - Consumes: q3 (prescription data)
#
# Output:
#   Saves four .rds files (must be in same directory as .qmd file):
#   - q1_hf_outcomes_summary.rds       (HF demographics by diabetes status)
#   - q1_non_hf_outcomes_summary.rds   (Non-HF demographics by diabetes status)
#   - q2_outcomes_summary.rds          (Clinical outcomes stratified)
#   - q3_prescriptions_summary.rds     (Top 5 drugs with dosages)
#
# Author: Emmanuel Oparaku
# Date: January 2026
# ============================================================================

cat("\n============= Preparing Summary Tables =============\n\n")

# ============================================================================
# TABLE 1: Heart Failure Demographics
# ============================================================================

cat("Creating Table 1: HF Demographics by Diabetes Status...\n")

tbl_q1_hf <-
  hf_patients %>%
  select(
    age_group,
    gender,
    ethnicity_group,
    admission_type,
    diabetes_status
  ) %>%
  tbl_summary(
    by = diabetes_status,
    statistic = all_categorical() ~ "{n} ({p}%)",
    missing = "no",
    label = list(
      age_group ~ "Age group",
      gender ~ "Gender",
      ethnicity_group ~ "Ethnicity",
      admission_type ~ "Admission type"
    )
  ) %>%
  modify_header(
    all_stat_cols() ~ "**{level}** (N={n})"
  ) %>%
  as_gt()

# Remove commas from headers (gtsummary formatting quirk)
col_labels <- tbl_q1_hf$`_boxhead`$column_label
col_labels_fixed <- lapply(col_labels, function(x) {
  if (is.character(x)) gsub(",", "", x) else x
})
tbl_q1_hf$`_boxhead`$column_label <- col_labels_fixed

# Apply final formatting
tbl_q1_hf <- tbl_q1_hf %>%
  tab_header(
    title = "Table 1. Demographic characteristics of heart failure admissions by diabetes status"
  ) %>%
  tab_options(
    table.width = pct(100),
    table.font.size = px(9),
    data_row.padding = px(2),
    column_labels.padding = px(4),
    heading.padding = px(4),
    heading.title.font.size = px(10),
    table.border.top.style = "solid",
    table.border.bottom.style = "solid",
    column_labels.border.bottom.style = "solid",
    heading.border.bottom.style = "solid"
  ) %>%
  cols_align(align = "left", columns = 1) %>%
  cols_align(align = "center", columns = 2:3) %>%
  tab_style(
    style = cell_text(size = px(9)),
    locations = list(cells_body(), cells_column_labels(), cells_stub())
  ) %>%
  cols_width(
    label ~ px(140),
    everything() ~ px(150)
  )

saveRDS(tbl_q1_hf, "q1_hf_outcomes_summary.rds")
cat("✓ Saved: q1_hf_outcomes_summary.rds\n")

# ============================================================================
# TABLE 2: Non-Heart Failure Demographics
# ============================================================================

cat("Creating Table 2: Non-HF Demographics by Diabetes Status...\n")

tbl_q1_nonhf <-
  non_hf_patients %>%
  select(
    age_group,
    gender,
    ethnicity_group,
    admission_type,
    diabetes_status
  ) %>%
  tbl_summary(
    by = diabetes_status,
    statistic = all_categorical() ~ "{n} ({p}%)",
    missing = "no",
    label = list(
      age_group ~ "Age group",
      gender ~ "Gender",
      ethnicity_group ~ "Ethnicity",
      admission_type ~ "Admission type"
    )
  ) %>%
  modify_header(
    all_stat_cols() ~ "**{level}** (N={n})"
  ) %>%
  as_gt()

# Remove commas from headers
col_labels_nonhf <- tbl_q1_nonhf$`_boxhead`$column_label
col_labels_nonhf_fixed <- lapply(col_labels_nonhf, function(x) {
  if (is.character(x)) gsub(",", "", x) else x
})
tbl_q1_nonhf$`_boxhead`$column_label <- col_labels_nonhf_fixed

# Apply final formatting
tbl_q1_nonhf <- tbl_q1_nonhf %>%
  tab_header(
    title = "Table 2. Demographic characteristics of non-heart failure admissions by diabetes status"
  ) %>%
  tab_options(
    table.width = pct(100),
    table.font.size = px(9),
    data_row.padding = px(2),
    column_labels.padding = px(4),
    heading.padding = px(4),
    heading.title.font.size = px(10),
    table.border.top.style = "solid",
    table.border.bottom.style = "solid",
    column_labels.border.bottom.style = "solid",
    heading.border.bottom.style = "solid"
  ) %>%
  cols_align(align = "left", columns = 1) %>%
  cols_align(align = "center", columns = 2:3) %>%
  tab_style(
    style = cell_text(size = px(9)),
    locations = list(cells_body(), cells_column_labels(), cells_stub())
  ) %>%
  cols_width(
    label ~ px(140),
    everything() ~ px(150)
  )

saveRDS(tbl_q1_nonhf, "q1_non_hf_outcomes_summary.rds")
cat("✓ Saved: q1_non_hf_outcomes_summary.rds\n")

# ============================================================================
# TABLE 3: Clinical Outcomes (Stratified)
# ============================================================================

cat("Creating Table 3: Clinical Outcomes by Stratification...\n")

# Helper function: format median (IQR) as string
median_iqr <- function(x) {
  if (all(is.na(x))) return(NA_character_)
  q <- quantile(x, probs = c(0.25, 0.5, 0.75), na.rm = TRUE)
  sprintf("%.1f (%.1f–%.1f)", q[2], q[1], q[3])
}

# Stratify by age group
age_summary <- hf_patients %>%
  group_by(age_group) %>%
  summarise(
    hospital_los = median_iqr(hospital_los_days),
    icu_los = median_iqr(icu_los_days),
    mortality = round(mean(hospital_expire_flag, na.rm = TRUE) * 100, 1),
    .groups = "drop"
  ) %>%
  mutate(
    stratifier = "Age",
    stratum = age_group
  )

# Stratify by gender
gender_summary <- hf_patients %>%
  group_by(gender) %>%
  summarise(
    hospital_los = median_iqr(hospital_los_days),
    icu_los = median_iqr(icu_los_days),
    mortality = round(mean(hospital_expire_flag, na.rm = TRUE) * 100, 1),
    .groups = "drop"
  ) %>%
  mutate(
    stratifier = "Gender",
    stratum = gender
  )

# Stratify by diabetes status
diabetes_summary <- hf_patients %>%
  group_by(diabetes_status) %>%
  summarise(
    hospital_los = median_iqr(hospital_los_days),
    icu_los = median_iqr(icu_los_days),
    mortality = round(mean(hospital_expire_flag, na.rm = TRUE) * 100, 1),
    .groups = "drop"
  ) %>%
  mutate(
    stratifier = "Diabetes status",
    stratum = diabetes_status
  )

# Stratify by ethnicity
ethnicity_summary <- hf_patients %>%
  group_by(ethnicity_group) %>%
  summarise(
    hospital_los = median_iqr(hospital_los_days),
    icu_los = median_iqr(icu_los_days),
    mortality = round(mean(hospital_expire_flag, na.rm = TRUE) * 100, 1),
    .groups = "drop"
  ) %>%
  mutate(
    stratifier = "Ethnicity",
    stratum = ethnicity_group
  )

# Combine all strata
tbl_q2 <- bind_rows(
  age_summary,
  gender_summary,
  diabetes_summary,
  ethnicity_summary
) %>%
  select(
    stratifier,
    stratum,
    hospital_los,
    icu_los,
    mortality
  ) %>%
  filter(!is.na(stratifier), !is.na(stratum))

# Create gt table
tbl_q2 <- tbl_q2 %>%
  gt(groupname_col = "stratifier") %>%
  cols_label(
    stratum = "Group",
    hospital_los = "Hospital LOS, days (median [IQR])",
    icu_los = "ICU LOS, days (median [IQR])",
    mortality = "In-hospital mortality (%)"
  ) %>%
  fmt_number(
    columns = mortality,
    decimals = 1
  ) %>%
  cols_align(
    align = "left",
    columns = everything()
  ) %>%
  tab_style(
    style = cell_text(weight = "bold"),
    locations = list(cells_column_labels(), cells_row_groups())
  ) %>%
  tab_options(
    table.font.size = px(9),
    row_group.padding = px(2),
    data_row.padding = px(2)
  ) %>%
  tab_header(
    title = "Table 3. Clinical outcomes of heart failure admissions by patient characteristics"
  ) %>%
  tab_options(
    table.font.size = px(9),
    heading.title.font.size = px(10),
    heading.padding = px(4),
    table.border.top.style = "solid",
    table.border.bottom.style = "solid",
    column_labels.border.bottom.style = "solid",
    heading.border.bottom.style = "solid"
  )

saveRDS(tbl_q2, "q2_outcomes_summary.rds")
cat("✓ Saved: q2_outcomes_summary.rds\n")

# ============================================================================
# TABLE 4: Medication Prescribing Patterns
# ============================================================================

cat("Creating Table 4: Top 5 Medications...\n")

# Calculate summary statistics for each drug
drug_summary <- q3 %>%
  group_by(drug) %>%
  summarise(
    total_prescriptions = n(),
    n_admissions = n_distinct(hadm_id),
    mean_dose = mean(dose_val_rx, na.rm = TRUE),
    percent_given_in_icu = 100 * mean(in_icu, na.rm = TRUE),
    mean_prescriptions_per_admission = n() / n_distinct(hadm_id),
    .groups = "drop"
  ) %>%
  arrange(desc(total_prescriptions)) %>%
  slice(1:5)

# Find dominant dose unit for each drug
dominant_units <- q3 %>%
  filter(drug %in% drug_summary$drug) %>%
  group_by(drug, dose_unit_rx) %>%
  summarise(n = n(), .groups = "drop") %>%
  arrange(drug, desc(n)) %>%
  group_by(drug) %>%
  slice(1) %>%
  select(drug, dominant_unit = dose_unit_rx)

# Format table for presentation
final_q3_table <- drug_summary %>%
  left_join(dominant_units, by = "drug") %>%
  mutate(
    drug = str_to_title(drug),
    dominant_unit = toupper(dominant_unit),
    mean_dose = round(mean_dose, 2),
    percent_given_in_icu = round(percent_given_in_icu, 1),
    mean_prescriptions_per_admission = round(mean_prescriptions_per_admission, 2)
  ) %>%
  select(
    drug,
    total_prescriptions,
    mean_dose,
    percent_given_in_icu,
    mean_prescriptions_per_admission,
    dominant_unit
  )

# Create gt table
gt_q3 <- final_q3_table %>%
  gt() %>%
  cols_label(
    drug = "Medication",
    total_prescriptions = "Total prescriptions, n",
    mean_dose = "Mean dose",
    percent_given_in_icu = "% prescribed in ICU",
    mean_prescriptions_per_admission = "Mean prescriptions per admission",
    dominant_unit = "Dose unit"
  ) %>%
  cols_width(
    drug ~ px(110),
    total_prescriptions ~ px(90),
    mean_dose ~ px(80),
    percent_given_in_icu ~ px(90),
    mean_prescriptions_per_admission ~ px(110),
    dominant_unit ~ px(70)
  ) %>%
  fmt_number(
    columns = c(mean_dose, mean_prescriptions_per_admission),
    decimals = 2
  ) %>%
  fmt_number(
    columns = percent_given_in_icu,
    decimals = 1
  ) %>%
  tab_source_note(
    source_note = md(
      "*Dose summaries were calculated using the most frequently recorded dose unit per medication.*"
    )
  ) %>%
  tab_header(
    title = "Table 4. Most commonly prescribed medications in heart failure admissions"
  ) %>%
  tab_options(
    table.width = pct(100),
    table.font.size = px(9),
    heading.title.font.size = px(10),
    heading.padding = px(4),
    table.border.top.style = "solid",
    table.border.bottom.style = "solid",
    column_labels.border.bottom.style = "solid",
    heading.border.bottom.style = "solid"
  )

saveRDS(gt_q3, "q3_prescriptions_summary.rds")
cat("✓ Saved: q3_prescriptions_summary.rds\n")

cat("\n✓ All tables prepared and saved.\n")
cat("Next: Render reports/heart_failure_report.qmd with Quarto\n")
