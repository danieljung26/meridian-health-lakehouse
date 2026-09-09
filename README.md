# Meridian Health — HIPAA-Aware Healthcare Lakehouse

A synthetic health-system data platform built on Databricks, demonstrating
medallion-architecture data engineering with **PHI governance as the centerpiece**.

The goal of this project is to show, end to end, how a healthcare data platform
protects Protected Health Information (PHI) while still enabling analytics —
using column masking, row-level security, role-based access control, and audit,
implemented to HIPAA minimum-necessary principles.

---

## What this demonstrates

- **Medallion architecture** (bronze → silver → gold) on Unity Catalog
- **PHI governance** — column masking, row-level security, a three-tier
  role model, and access auditing
- **Star-schema clinical modeling** — `patients` and `payers` dimensions;
  `encounters`, `conditions`, `medications`, `procedures` facts
- **Synthetic data only** — built on Synthea; no real patient data, by design

---

## Data

This project uses [Synthea](https://synthetichealth.github.io/synthea/)
synthetic patient data (~1,000 patients, CSV export). Synthea generates
realistic-but-not-real health records that are free of privacy restrictions,
which is precisely why PHI-handling can be practiced on them safely.

**No patient data is committed to this repository.** See
[`data/README.md`](data/README.md) for how to obtain the source files.

---

## Repository layout

| Path | Contents |
|------|----------|
| `00_setup/` | Catalog, schema, and volume creation |
| `01_ingestion/` | Bronze layer — loading Synthea CSVs to Delta |
| `02_silver/` | Cleaned, typed, joined clinical tables |
| `03_gold/` | Business-ready aggregates |
| `04_governance/` | **Column masks, row-level security, role model, audit** |
| `05_pipeline_sdp/` | Declarative (SDP) rebuild of the pipeline |
| `docs/` | PHI inventory, architecture notes |
| `data/` | Instructions for obtaining source data (not the data itself) |

---

## Governance model

Access is designed around three tiers, mirroring how real health systems apply
the HIPAA "minimum necessary" standard:

| Tier | Who | Sees |
|------|-----|------|
| **Full PHI** | Treating clinicians, select admins | All columns, all rows |
| **Billing** | Claims / billing operations | Names + address (to bill), **not** SSN/passport |
| **Research** | Analysts, data scientists | No direct identifiers; generalized quasi-identifiers only |

Full design and rationale: [`04_governance/03_role_model.md`](04_governance/03_role_model.md)

---

## Environment note

Built on **Databricks Free Edition** (serverless, single-metastore).

Group-based access control is authored to production standard using
`is_account_group_member(...)`. Because Free Edition does not provide
account-level groups or SCIM provisioning, the *mechanisms* (masks, row
filters) are additionally validated using session-based checks
(`current_user()`), so the enforcement can be demonstrated end to end in a
group-less environment. The production-correct SQL is retained alongside the
runnable version in each governance file.

---

## Tech

Databricks · Unity Catalog · Delta Lake · PySpark · Spark SQL · Spark Declarative Pipelines
