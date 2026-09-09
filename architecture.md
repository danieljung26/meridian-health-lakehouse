# Architecture

## Medallion flow

```
Synthea CSVs (volume)
        │  Auto Loader / batch read
        ▼
   BRONZE  ── raw, as-ingested, + source_file / ingested_at provenance
        │  clean, type-cast, join
        ▼
   SILVER  ── conformed clinical tables; patient-encounter fact,
        │     dimensions resolved, codes retained (ICD-10/SNOMED/RxNorm/CPT)
        │  aggregate
        ▼
    GOLD   ── business-ready: cost per condition, encounters by payer,
                readmission metrics, etc.
```

Governance (masks + row filters) is applied so that PHI is protected at every
layer a non-privileged role can reach.

## Star schema

```
        ┌──────────────┐          ┌──────────────┐
        │  patients    │          │   payers     │
        │ (dimension)  │          │ (dimension)  │
        │  PHI lives   │          │              │
        │   here       │          │              │
        └──────┬───────┘          └──────┬───────┘
               │ Id                       │ Id
               │                          │
        ┌──────▼──────────────────────────▼───────┐
        │              encounters                  │
        │           (central fact)                 │
        │   PATIENT → patients.Id                  │
        │   PAYER   → payers.Id                     │
        └──────┬───────────────────────────────────┘
               │ ENCOUNTER
    ┌──────────┼───────────────┬──────────────────┐
    ▼          ▼               ▼                  ▼
conditions  medications   procedures        (observations…)
 (fact)      (fact)         (fact)
```

- **Dimensions** (`patients`, `payers`) are small, descriptive, one row per entity.
- **Facts** (`encounters`, `conditions`, `medications`, `procedures`) are large,
  event-level, many rows per patient.
- Joins use surrogate `Id`s (random UUIDs), never identifying fields like `SSN`.

## Key design decisions

- **Batch read for static Synthea files.** The Synthea export is a fixed
  one-time load, so bronze uses `spark.read` rather than Auto Loader. Auto
  Loader (streaming, checkpointed, incremental) is the right tool for files that
  *arrive over time*; using batch for static files is a deliberate
  right-tool-for-the-job choice.
- **Govern the dimension.** PHI concentrates in `patients` (~1,000 rows) but is
  referenced by 130,000+ fact rows. Masking the dimension once protects every
  downstream join.
