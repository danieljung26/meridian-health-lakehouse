# Access Role Model

Meridian implements three access tiers, mirroring how real health systems apply
the HIPAA **minimum-necessary** standard: each role sees only what its job
function requires. Access is enforced through two composable Unity Catalog
mechanisms — **column masks** (redact values) and **row filters** (hide rows) —
attached at the table level so they apply to every query path (notebooks,
dashboards, BI tools, Genie) with no way to bypass.

---

## The three tiers

### `meridian_phi_full` — Full PHI
- **Who:** treating clinicians, a small set of data administrators
- **Columns:** all, unmasked (real SSN, names, dates, address)
- **Rows:** all patients
- **Rationale:** direct care and system administration require complete records.

### `meridian_billing` — Billing / Claims
- **Who:** billing and claims-operations staff
- **Columns:** names and address visible (needed to bill and correspond);
  SSN / passport / driver's-license **masked**
- **Rows:** all patients (billing spans the population)
- **Rationale:** billing needs to identify and contact patients, but does not
  need government-ID numbers.

### `meridian_research` — Research / Analytics (de-identified)
- **Who:** analysts, data scientists, population-health researchers
- **Columns:** no Tier-1 or Tier-2 identifiers; quasi-identifiers generalized
  (ZIP→3 digits, DOB→birth year)
- **Rows:** may be restricted to a de-identified cohort or a region, depending
  on the analysis
- **Rationale:** analytics rarely needs to know *who* — only patterns across the
  population. This is the tier most day-to-day analytics runs against.

---

## Mechanism mapping

| Requirement | Mechanism | File |
|-------------|-----------|------|
| Hide SSN / IDs from non-clinical roles | Column mask | `01_column_masks.sql` |
| Hide names/address from research | Column mask | `01_column_masks.sql` |
| Restrict rows by region / cohort | Row filter | `02_row_level_security.sql` |
| Track who accessed PHI | Audit (system tables) | `04_audit.sql` |

---

## Production vs. this environment

The production-correct check is `is_account_group_member('meridian_phi_full')`
etc., which requires account-level groups. Databricks Free Edition has no
account console / SCIM, so groups cannot be provisioned here. Each governance
file therefore contains:

1. the **production-correct** statement (group-based), and
2. a **runnable** variant keyed on `current_user()` that demonstrates the same
   mechanism executably in a group-less environment.

The group-based version is the artifact of record; the session-based version
proves the mechanism works.
