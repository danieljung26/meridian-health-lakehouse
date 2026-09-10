-- ============================================================
-- Meridian Health — Declarative Pipeline (SDP)
-- Rebuilds the bronze -> silver -> gold slice declaratively.
-- SDP reads dependencies from the FROM clauses and builds the
-- DAG automatically — order below is for readability only.
-- ============================================================

-- ---------- BRONZE: patients (PHI dimension) ----------
-- FAIL: a null patient Id is catastrophic — it's the join key for the whole model.
CREATE OR REFRESH MATERIALIZED VIEW patients_bronze (
    CONSTRAINT valid_patient_id EXPECT (Id IS NOT NULL) ON VIOLATION FAIL UPDATE
)
AS SELECT *, _metadata.file_name AS source_file, current_timestamp() AS ingested_at
FROM read_files(
  '/Volumes/meridian_dev/bronze/raw_files/patients.csv',
  format => 'csv', header => true, inferColumnTypes => true);

-- ---------- BRONZE: encounters (central fact) ----------
-- DROP: encounters missing a patient link, or with negative cost, are unusable
-- for analysis — drop the bad rows but keep the pipeline running.
CREATE OR REFRESH MATERIALIZED VIEW encounters_bronze (
    CONSTRAINT valid_patient_fk EXPECT (PATIENT IS NOT NULL) ON VIOLATION DROP ROW,
    CONSTRAINT non_negative_cost EXPECT (TOTAL_CLAIM_COST >= 0) ON VIOLATION DROP ROW
)
AS SELECT *, _metadata.file_name AS source_file, current_timestamp() AS ingested_at
FROM read_files(
  '/Volumes/meridian_dev/bronze/raw_files/encounters.csv',
  format => 'csv', header => true, inferColumnTypes => true);

-- ---------- SILVER: encounter fact ----------
-- WARN: implausible age / missing class are quality signals worth monitoring,
-- but the row's cost & clinical data may still be valid — keep and flag.
CREATE OR REFRESH MATERIALIZED VIEW encounters_silver (
    CONSTRAINT plausible_age EXPECT (age_at_encounter BETWEEN 0 AND 120),
    CONSTRAINT has_encounter_class EXPECT (encounter_class IS NOT NULL)
)
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