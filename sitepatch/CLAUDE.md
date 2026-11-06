# Sitepatch Queries

SQL queries for analyzing the **webcompat:needs_sitepatch** keyword lifecycle in Bugzilla.

## Context

The "needs_sitepatch" phase tracks bugs that require a site-specific intervention (sitepatch) to fix a web compatibility issue. A sitepatch is a browser-side workaround that fixes compatibility problems on specific websites without requiring changes from the website itself.

## Keyword Tracking

- **Enter:** Bug gets `webcompat:needs_sitepatch` keyword added
- **Exit:** Bug gets `webcompat:needs_sitepatch` keyword removed (sitepatch deployed or resolved otherwise)

## Queries

### Lifecycle Queries

| File | STMO ID | Description |
|------|---------|-------------|
| `webcompat_bugs_sitepatch_count.sql` | 119314 | Bug counts by priority (P1/P2/P3) |
| `webcompat_bugs_sitepatch_lifetime.sql` | 119309 | Percentile distribution of time spent awaiting sitepatch |
| `webcompat_bugs_sitepatch_survival.sql` | 119316 | Survival rate analysis |

### Impact Queries

| File | STMO ID | Description |
|------|---------|-------------|
| `interventions_impact_metrics.sql` | 119912 | Tracks intervention deployments and their score impact (daily) |
| `interventions_impact_monthly.sql` | 119913 | Monthly aggregation of intervention impact |

## Data Source

- **BigQuery dataset:** `moz-fx-dev-dschubert-wckb.webcompat_knowledge_base`
- **Tables:** `bugs_history`, `site_reports`, `scored_site_reports`, `webcompat_topline_metric_changes`

## Parameters

All queries accept date range parameters:
- `from`: Start date for bug creation
- `to`: End date for bug creation
