-- ============================================================
-- Meridian Health — Declarative Pipeline (SDP)
-- Rebuilds the bronze -> silver -> gold slice declaratively.
-- SDP reads dependencies from the FROM clauses and builds the
-- DAG automatically — order below is for readability only.
-- ============================================================

-- ---------- BRONZE: batch ingestion from static CSVs ----------
-- Batch materialized views (not streaming) — correct tool for static files.
-- read_files supports batch semantics and reads a single file directly.

CREATE OR REFRESH MATERIALIZED VIEW patients_bronze
AS SELECT *, _metadata.file_name AS source_file, current_timestamp() AS ingested_at
FROM read_files(
  '/Volumes/meridian_dev/bronze/raw_files/patients.csv',
  format => 'csv', header => true, inferColumnTypes => true);

CREATE OR REFRESH MATERIALIZED VIEW encounters_bronze
AS SELECT *, _metadata.file_name AS source_file, current_timestamp() AS ingested_at
FROM read_files(
  '/Volumes/meridian_dev/bronze/raw_files/encounters.csv',
  format => 'csv', header => true, inferColumnTypes => true);

CREATE OR REFRESH MATERIALIZED VIEW medications_bronze
AS SELECT * FROM read_files(
  '/Volumes/meridian_dev/bronze/raw_files/medications.csv',
  format => 'csv', header => true, inferColumnTypes => true);

CREATE OR REFRESH MATERIALIZED VIEW procedures_bronze
AS SELECT * FROM read_files(
  '/Volumes/meridian_dev/bronze/raw_files/procedures.csv',
  format => 'csv', header => true, inferColumnTypes => true);

CREATE OR REFRESH MATERIALIZED VIEW conditions_bronze
AS SELECT * FROM read_files(
  '/Volumes/meridian_dev/bronze/raw_files/conditions.csv',
  format => 'csv', header => true, inferColumnTypes => true);

-- ---------- SILVER: governance-aware encounter fact ----------
-- Materialized view: a transform over bronze. Joins only the SAFE
-- patient attributes (gender, age, region) — NO PHI in the analytical path.

CREATE OR REFRESH MATERIALIZED VIEW encounters_silver
AS SELECT
    e.Id                                          AS encounter_id,
    e.PATIENT                                     AS patient_id,
    e.START                                       AS encounter_start,
    e.STOP                                        AS encounter_stop,
    e.ENCOUNTERCLASS                              AS encounter_class,
    e.DESCRIPTION                                 AS encounter_desc,
    e.PAYER                                       AS payer_id,
    e.TOTAL_CLAIM_COST                            AS total_cost,
    e.PAYER_COVERAGE                              AS payer_coverage,
    p.GENDER                                      AS gender,
    floor(months_between(e.START, p.BIRTHDATE)/12) AS age_at_encounter,
    p.STATE                                       AS state
FROM encounters_bronze e
LEFT JOIN patients_bronze p ON e.PATIENT = p.Id;

-- ---------- GOLD: cost per condition ----------
-- Materialized view aggregating rolled-up med + procedure costs by diagnosis.

CREATE OR REFRESH MATERIALIZED VIEW cost_by_condition_gold
AS
WITH med_cost AS (
    SELECT ENCOUNTER, sum(TOTALCOST) AS med_cost
    FROM medications_bronze GROUP BY ENCOUNTER
),
proc_cost AS (
    SELECT ENCOUNTER, sum(BASE_COST) AS proc_cost
    FROM procedures_bronze GROUP BY ENCOUNTER
)
SELECT
    c.CODE                                        AS condition_code,
    c.DESCRIPTION                                 AS condition_desc,
    count(*)                                      AS num_diagnoses,
    count(DISTINCT c.PATIENT)                     AS num_patients,
    round(sum(coalesce(m.med_cost,0) + coalesce(pr.proc_cost,0)), 2) AS total_cost
FROM conditions_bronze c
LEFT JOIN med_cost  m  ON c.ENCOUNTER = m.ENCOUNTER
LEFT JOIN proc_cost pr ON c.ENCOUNTER = pr.ENCOUNTER
GROUP BY c.CODE, c.DESCRIPTION;