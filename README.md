# Webcompat Bugs Lifetime Analysis

SQL queries for analyzing webcompat bug resolution times in STMO (sql.telemetry.mozilla.org).

## Setup

### Prerequisites
- Python 3.x
- pip

### Installation

1. Install stmo-cli:
```bash
pip3 install git+https://github.com/mozilla/stmocli.git
```

2. Get your Redash API key:
   - Go to https://sql.telemetry.mozilla.org
   - Click profile icon → Profile → Settings
   - Copy your API Key

3. Create `.env` file:
```bash
echo "REDASH_API_KEY=your_api_key_here" > .env
```

## Queries

### 1. Sitepatch Lifetime Percentiles
**File:** `webcompat_bugs_sitepatch_lifetime.sql`
**STMO:** https://sql.telemetry.mozilla.org/queries/119309

Shows how long bugs spend in `needs_sitepatch` status, broken down by percentiles and priority.

### 2. Diagnosis Lifetime Percentiles
**File:** `webcompat_bugs_diagnosis_lifetime.sql`
**STMO:** https://sql.telemetry.mozilla.org/queries/119310

Shows how long bugs spend in `needs_diagnosis` status, broken down by percentiles and priority.

### 3. Original Combined Query
**File:** `webcompat_bugs_lifetime_per_status.sql`
**STMO:** https://sql.telemetry.mozilla.org/queries/116893

Original query showing average lifetime for both statuses.

## Understanding the Output

```
percentile     P1     P2     P3
p10             0      0      0    ← 10% of bugs resolved in X days
p50             6      8      8    ← 50% of bugs resolved in X days (median)
p90            42     42     72    ← 90% of bugs resolved in X days
```

**How to read:**
- `p50/P2 = 8` → "50% of P2 bugs were resolved in ≤8 days"
- `p90/P3 = 72` → "90% of P3 bugs were resolved in ≤72 days"

## Usage

### Run queries locally
```bash
source .env && python3 run_queries.py
source .env && python3 run_queries.py --from 2025-01-01 --to 2025-12-31
```

### Push changes to STMO
```bash
source .env
stmocli push webcompat_bugs_sitepatch_lifetime.sql
stmocli push webcompat_bugs_diagnosis_lifetime.sql
```

### Pull latest from STMO
```bash
source .env
stmocli pull
```

## Chart Configuration

Both queries have bar chart visualizations with:
- **X-axis:** Percentiles (p10-p90) representing "% of bugs"
- **Y-axis:** Days to resolve
- **Stacked bars:** P1 (red), P2 (orange), P3 (blue)
- **Data labels:** Enabled

## Data Source

- **BigQuery dataset:** `moz-fx-dev-dschubert-wckb.webcompat_knowledge_base`
- **Tables used:**
  - `bugs_history` - Bug change history
  - `site_reports` - Bug metadata including priority

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `from` | date | 2026-01-01 | Start date for bug creation_time |
| `to` | date | 2026-04-17 | End date for bug creation_time |

## Files

| File | Description |
|------|-------------|
| `.env` | API key (not committed) |
| `.stmocli.conf` | Query tracking configuration |
| `*.sql` | SQL query files |
| `run_queries.py` | Script to run queries locally |

## stmo-cli Commands Reference

```bash
stmocli init              # Initialize repository
stmocli track <query_id>  # Track an existing STMO query
stmocli push <file.sql>   # Push local changes to STMO
stmocli pull              # Pull latest from STMO
stmocli view <file.sql>   # Open query in browser
stmocli fork <query_id>   # Copy and track a query
```

## Notes

- The `stmocli` binary is installed at: `/Users/bchauvet/Library/Python/3.9/bin/stmocli`
- Add to PATH if needed: `export PATH="$PATH:/Users/bchauvet/Library/Python/3.9/bin"`
- stmo-cli project is archived but still functional
