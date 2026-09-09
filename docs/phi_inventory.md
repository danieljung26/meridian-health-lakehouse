# PHI Inventory & Classification

This document classifies every column in the `patients` dimension by sensitivity.
It is the design basis for the governance layer (`04_governance/`). Each masking
and row-filtering decision traces back to a classification here.

Classification follows HIPAA identifiers and the "minimum necessary" principle:
protect what identifies a person; expose what a role legitimately needs.

---

## Tier 1 — Direct identifiers

Uniquely identify an individual on their own. Almost no analytical or clinical
workflow needs the raw value. **Masked from everyone except the full-PHI tier.**

| Column | Notes |
|--------|-------|
| `SSN` | Social Security Number. Highest-sensitivity identifier. |
| `DRIVERS` | Driver's license number. |
| `PASSPORT` | Passport number. |

**Treatment:** show only last 4 (or fully redact) to non-full-PHI roles.

---

## Tier 2 — Identifying PHI

Directly identifying, but some operational roles have a legitimate need
(e.g. a biller needs a name; a researcher never does).

| Column | Notes |
|--------|-------|
| `FIRST`, `LAST`, `MAIDEN` | Names. Needed by billing/clinical, not research. |
| `BIRTHDATE`, `DEATHDATE` | Full dates are HIPAA identifiers (year alone is lower-risk). |
| `ADDRESS` | Street address. |
| `LAT`, `LON` | Precise geolocation — identifies a household. |

**Treatment:** masked from the research tier; visible to billing + full-PHI.

---

## Tier 3 — Quasi-identifiers

Individually harmless, but in combination can re-identify (the classic
ZIP + DOB + gender problem). HIPAA Safe Harbor calls for generalization
rather than full suppression.

| Column | Generalization approach |
|--------|-------------------------|
| `ZIP` | Truncate to first 3 digits. |
| `CITY`, `COUNTY` | Generalize to county/region level. |
| `BIRTHDATE` | Generalize to birth year (when used analytically). |
| `RACE`, `ETHNICITY`, `GENDER` | Retain for legitimate population analysis; watch in combination. |

**Treatment:** generalize (not fully mask) for the research tier.

---

## Tier 4 — Analytical / non-identifying

Safe to expose; these power the analytics.

| Column | Notes |
|--------|-------|
| `Id` | Random UUID surrogate key. **The safe join key** — links to fact tables without exposing identity. This is why joins use `Id`, never `SSN`. |
| `HEALTHCARE_EXPENSES`, `HEALTHCARE_COVERAGE`, `INCOME` | Financial; not identifying alone. |
| `STATE` | Coarse geography, generally safe. |

---

## Key principle

PHI lives in the small `patients` **dimension** (~1,000 rows), but is referenced
by 130,000+ rows across the clinical **fact** tables (encounters, conditions,
medications, procedures). Governing at the dimension — masking `patients` once
at the source — means every downstream join inherits the protection. Govern the
dimension, protect the whole model.
