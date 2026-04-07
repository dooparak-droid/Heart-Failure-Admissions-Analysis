-- ============================================================================
-- Heart Failure Admissions Report: Cohort and Prescription Data Extraction
--
-- Purpose:
--   Creates two SQL views for the heart failure analysis pipeline:
--   1. hf_cohort: All admissions with demographic/outcome variables
--   2. hf_drug_summary_view: Prescriptions for HF patients with ICU flags
--
-- Cohort Definition:
--   Heart failure: ICD-9 codes 428.x (heart failure, any sequence)
--   Secondary diabetes: ICD-9 249.xx OR 250.xx (with seq_num > 1 for 250.xx)
--
-- Key Processing Notes:
--   - Age capped at 89 per MIMIC-III de-identification convention
--   - Ethnicity collapsed into 5 categories for clarity
--   - ICU LOS set to NULL if negative (data quality issue)
--   - Hospital LOS set to NULL if discharge before admission
--
-- Dependencies:
--   - MIMIC-III base tables: admissions, patients, diagnoses_icd, icustays, prescriptions
--   - Dictionary tables: d_icd_diagnoses
--
-- Author: Emmanuel Oparaku
-- Date: January 2026
-- ============================================================================

-- ============================================================================
-- STEP 1: Create hf_cohort view
-- ============================================================================

CREATE OR REPLACE VIEW public.hf_cohort AS
WITH hf_admissions AS (
  /* Identify all admissions with heart failure diagnosis (ICD-9 428.x) */
  SELECT DISTINCT hadm_id
  FROM diagnoses_icd
  WHERE icd9_code LIKE '428%'
),

diabetes_admissions AS (
  /* 
     Identify secondary diabetes:
     - ICD-9 249.xx (secondary diabetes with complications/manifestations)
     - ICD-9 250.xx where seq_num > 1 (diabetes as secondary diagnosis)
  */
  SELECT DISTINCT hadm_id
  FROM diagnoses_icd
  WHERE icd9_code LIKE '249%'
     OR (icd9_code LIKE '250%' AND seq_num > 1)
),

icu_los AS (
  /* 
     Calculate total ICU length of stay per admission (in days).
     Set to NULL if negative (indicates data quality issue).
  */
  SELECT
    hadm_id,
    CASE
      WHEN SUM(EXTRACT(EPOCH FROM (outtime - intime))) >= 0
      THEN SUM(EXTRACT(EPOCH FROM (outtime - intime))) / 86400
      ELSE NULL
    END AS icu_los_days
  FROM icustays
  GROUP BY hadm_id
)

SELECT
  a.subject_id,
  a.hadm_id,

  /* Cohort flags */
  CASE WHEN hf.hadm_id IS NOT NULL THEN 1 ELSE 0 END AS heart_failure,
  CASE WHEN dm.hadm_id IS NOT NULL THEN 1 ELSE 0 END AS secondary_diabetes,

  /* Demographics */
  p.gender,

  /* Age at admission, capped at 89 per MIMIC convention */
  CASE
    WHEN EXTRACT(YEAR FROM age(a.admittime, p.dob)) > 89 THEN 89
    ELSE EXTRACT(YEAR FROM age(a.admittime, p.dob))
  END AS age,

  /* Ethnicity collapsed into 5 categories */
  CASE
    WHEN a.ethnicity ILIKE '%WHITE%' THEN 'White'
    WHEN a.ethnicity ILIKE '%BLACK%' THEN 'Black'
    WHEN a.ethnicity ILIKE '%ASIAN%' THEN 'Asian'
    WHEN a.ethnicity ILIKE '%HISPANIC%' THEN 'Hispanic'
    ELSE 'Other/Unknown'
  END AS ethnicity_group,

  /* Admission characteristics */
  a.admission_type,

  /* Outcomes: set to NULL if discharge before admission (data quality) */
  CASE
    WHEN a.dischtime >= a.admittime
    THEN EXTRACT(EPOCH FROM (a.dischtime - a.admittime)) / 86400
    ELSE NULL
  END AS hospital_los_days,

  /* ICU length of stay (NULL if negative or no ICU stay) */
  i.icu_los_days,

  /* Mortality flag */
  a.hospital_expire_flag

FROM admissions a
JOIN patients p
  ON a.subject_id = p.subject_id

LEFT JOIN hf_admissions hf
  ON a.hadm_id = hf.hadm_id

LEFT JOIN diabetes_admissions dm
  ON a.hadm_id = dm.hadm_id

LEFT JOIN icu_los i
  ON a.hadm_id = i.hadm_id;


-- ============================================================================
-- STEP 2: Create hf_drug_summary_view
-- ============================================================================

CREATE OR REPLACE VIEW public.hf_drug_summary_view AS
WITH hf_admissions AS (
  /* Extract admissions where patient has heart failure diagnosis */
  SELECT DISTINCT hadm_id
  FROM public.hf_cohort
  WHERE heart_failure = 1
),

hf_prescriptions AS (
  /* Get prescriptions for HF patients; extract only needed columns */
  SELECT
    p.hadm_id,
    p.drug,
    p.dose_val_rx,
    p.dose_unit_rx,
    p.startdate
  FROM prescriptions p
  JOIN hf_admissions hf
    ON p.hadm_id = hf.hadm_id
),

icu_flag AS (
  /* 
     Flag prescriptions that occurred during ICU stay.
     Checks if prescription start date falls between ICU intime and outtime.
  */
  SELECT
    hp.hadm_id,
    hp.drug,
    hp.dose_val_rx,
    hp.dose_unit_rx,
    CASE
      WHEN EXISTS (
        SELECT 1
        FROM icustays i
        WHERE i.hadm_id = hp.hadm_id
          AND hp.startdate BETWEEN i.intime AND i.outtime
      )
      THEN 1 ELSE 0
    END AS in_icu
  FROM hf_prescriptions hp
)

SELECT * FROM icu_flag;


-- ============================================================================
-- SANITY CHECKS (run these after creating views)
-- ============================================================================

-- Check 1: Total admissions in cohort
-- Expected: ~59,000 total admissions from MIMIC-III
SELECT COUNT(*) AS total_admissions FROM public.hf_cohort;

-- Check 2: Breakdown of HF vs non-HF
-- Expected: HF ~13,600 (23%), non-HF ~45,400 (77%)
SELECT 
  heart_failure,
  COUNT(*) AS n_admissions,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct
FROM public.hf_cohort
GROUP BY heart_failure;

-- Check 3: Hospital LOS distribution
-- Should be positive integers; check for extreme values
SELECT
  MIN(hospital_los_days) AS min_los,
  MAX(hospital_los_days) AS max_los,
  ROUND(AVG(hospital_los_days), 1) AS mean_los,
  COUNT(*) FILTER (WHERE hospital_los_days < 0) AS negative_count
FROM public.hf_cohort;

-- Check 4: ICU stays distribution
-- Most admissions have no ICU stay
SELECT
  COUNT(*) FILTER (WHERE icu_los_days > 0) AS with_icu,
  COUNT(*) FILTER (WHERE icu_los_days IS NULL OR icu_los_days = 0) AS no_icu
FROM public.hf_cohort;

-- Check 5: Prescription counts
-- Verify the view is pulling data correctly
SELECT
  COUNT(*) AS total_prescriptions,
  COUNT(DISTINCT hadm_id) AS n_admissions,
  COUNT(DISTINCT drug) AS n_unique_drugs
FROM public.hf_drug_summary_view;
