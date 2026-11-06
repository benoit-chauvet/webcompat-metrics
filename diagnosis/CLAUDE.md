# Diagnosis Queries

SQL queries for analyzing the **webcompat:needs_diagnosis** keyword lifecycle in Bugzilla.

## Context

The "needs_diagnosis" phase tracks bugs that require investigation to understand the root cause of a web compatibility issue. This is typically the first phase a bug enters after being triaged.

## Keyword Tracking

- **Enter:** Bug gets `webcompat:needs_diagnosis` keyword added
- **Exit:** Bug gets `webcompat:needs_diagnosis` keyword removed (diagnosis complete)

## Queries

| File | STMO ID | Description |
|------|---------|-------------|
| `webcompat_bugs_diagnosis_count.sql` | 119315 | Bug counts by priority (P1/P2/P3) |
| `webcompat_bugs_diagnosis_lifetime.sql` | 119310 | Percentile distribution of time spent in diagnosis |
| `webcompat_bugs_diagnosis_survival.sql` | 119317 | Survival rate analysis |

## Data Source

- **BigQuery dataset:** `moz-fx-dev-dschubert-wckb.webcompat_knowledge_base`
- **Tables:** `bugs_history`, `site_reports`

## Parameters

All queries accept date range parameters:
- `from`: Start date for bug creation
- `to`: End date for bug creation
