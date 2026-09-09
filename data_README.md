# Source Data

This project uses **Synthea** synthetic patient data. No data files are
committed to this repository — only these instructions.

## Why no data in git

Even though Synthea data is synthetic and carries no real privacy restrictions,
keeping data out of version control is standard practice — and for a project
about PHI governance, keeping even synthetic-PHI-shaped files out of the repo is
the correct instinct to demonstrate. Data belongs in object storage / a volume,
not in git.

## How to obtain the data

1. Go to <https://synthetichealth.github.io/synthea/>.
2. Download the **CSV** sample (~1,000 patients).
3. Unzip. You will get files including:
   `patients.csv`, `encounters.csv`, `conditions.csv`, `medications.csv`,
   `procedures.csv`, `payers.csv`, and others.
4. Upload them into the Unity Catalog volume created in
   `00_setup/02_create_volumes.py`:
   `/Volumes/meridian_dev/bronze/raw_files/`
   (Catalog → `meridian_dev` → `bronze` → `raw_files` → Upload).

The ingestion notebooks in `01_ingestion/` read from that volume path.

## Core tables used

Of Synthea's ~16 exported tables, this project uses a focused core:

| File | Role in model | Approx rows (1k patients) |
|------|---------------|---------------------------|
| `patients.csv` | Dimension (PHI) | ~1,000 |
| `payers.csv` | Dimension | ~10 |
| `encounters.csv` | Fact (visits) | ~53,000 |
| `medications.csv` | Fact | ~43,000 |
| `procedures.csv` | Fact | ~35,000 |
| `conditions.csv` | Fact (diagnoses) | ~8,000 |

Row counts vary with the sample you download.
