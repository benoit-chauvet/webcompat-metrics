# Impact Queries

SQL queries for analyzing webcompat score impact and trends.

## Context

The webcompat score measures the cumulative impact of open web compatibility bugs. Higher scores indicate greater impact on Firefox users. The primary segment is **Core Countries** which tracks bugs affecting top-priority geographic regions.

## Metrics

- **Core Countries:** Bugs affecting high-priority geographic regions (`is_core = TRUE`)
- **Sightline:** Bugs in the sightline metric (`is_sightline = TRUE`)
- **Other:** Bugs not in either category

## Queries

| File | STMO ID | Description |
|------|---------|-------------|
| `webcompat_score_variations_analysis.sql` | 121085 | Daily score changes by metric/origin/priority |
| `webcompat_score_current.sql` | 121159 | Current total score snapshot (open bugs) |
| `webcompat_score_cumulative.sql` | 121160 | Running total score over time |
| `webcompat_score_monthly.sql` | 121161 | Monthly aggregation of score changes |
| `webcompat_score_weekly.sql` | 121713 | Weekly aggregation of score changes (new vs resolved) |
| `webcompat_score_by_priority.sql` | 121162 | Score distribution by priority (P1/P2/P3) |
| `webcompat_score_by_origin.sql` | 121163 | Score distribution by source |
| `webcompat_top_bugs.sql` | 121164 | Top 50 highest-scoring open bugs |

## Data Source

- **BigQuery dataset:** `moz-fx-dev-dschubert-wckb.webcompat_knowledge_base`
- **Table:** `scored_site_reports`

### Key Columns

| Column | Description |
|--------|-------------|
| `score` | Impact score for the bug |
| `is_core` | Boolean for Core Countries metric |
| `is_sightline` | Boolean for Sightline metric |
| `webcompat_priority` | Priority level (P1/P2/P3) |
| `creation_time` | Bug creation timestamp |
| `resolved_time` | Bug resolution timestamp (NULL if open) |
| `whiteboard` | Contains source tags like `[webcompat-source:product]` |

## Origin Detection

Bug sources are identified from whiteboard tags:
- `[webcompat-source:product]` → Fx user reports
- `[webcompat-source:web-bugs]` → webcompat.com
- Otherwise → other

## Parameters

Queries with date ranges use:
- `{{ start }}`: Start date
- `{{ end }}`: End date

## Dashboard

**Webcompat Score Impact:** https://sql.telemetry.mozilla.org/dashboards/2900-webcompat-score-impact

**Webcompat Bugs Lifecycle:** https://sql.telemetry.mozilla.org/dashboards/webcompat-bugs-lifecycle_1
