# Webcompat Metrics

SQL queries for analyzing web compatibility bug metrics in Mozilla's STMO (sql.telemetry.mozilla.org).

## Project Structure

```
├── diagnosis/     # Queries for webcompat:needs_diagnosis keyword lifecycle
├── sitepatch/     # Queries for webcompat:needs_sitepatch (interventions) lifecycle
└── .stmocli.conf  # Query ID mappings for STMO
```

## STMO / Redash API

The Redash API key is stored in `.env` file:
```
REDASH_API_KEY=<key>
```

### Fetching a Query

To fetch a query by ID from STMO:

```bash
source .env
curl -s -H "Authorization: Key $REDASH_API_KEY" \
  "https://sql.telemetry.mozilla.org/api/queries/<QUERY_ID>" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('query',''))"
```

To get full metadata:
```bash
curl -s -H "Authorization: Key $REDASH_API_KEY" \
  "https://sql.telemetry.mozilla.org/api/queries/<QUERY_ID>" \
  | python3 -m json.tool
```

### Pushing a Query Update

To update a query on STMO:

```bash
source .env
QUERY_ID=<id>
SQL_CONTENT=$(cat path/to/query.sql)
curl -s -X POST -H "Authorization: Key $REDASH_API_KEY" \
  -H "Content-Type: application/json" \
  "https://sql.telemetry.mozilla.org/api/queries/$QUERY_ID" \
  -d "{\"query\": $(echo "$SQL_CONTENT" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))')}"
```

### Running a Query

To execute a query and get results:

```bash
source .env
QUERY_ID=<id>
# Trigger execution
curl -s -X POST -H "Authorization: Key $REDASH_API_KEY" \
  "https://sql.telemetry.mozilla.org/api/queries/$QUERY_ID/results"
```

### Query ID Mapping

Query IDs are tracked in `.stmocli.conf`. To find the STMO ID for a local file:

```bash
python3 -c "import json; c=json.load(open('.stmocli.conf')); print(c.get('<path/to/file.sql>', {}).get('id', 'Not found'))"
```

## Data Source

- **BigQuery dataset:** `moz-fx-dev-dschubert-wckb.webcompat_knowledge_base`
- **Data source ID:** 63 (BigQuery)

### Key Tables

| Table | Description |
|-------|-------------|
| `bugs_history` | Bug change history with keyword additions/removals |
| `site_reports` | Bug metadata including priority |
| `scored_site_reports` | Bug reports with impact scores |
| `webcompat_topline_metric_changes` | Metric change events (interventions, etc.) |

## Dashboard

**URL:** https://sql.telemetry.mozilla.org/dashboards/webcompat-bugs-lifecycle_1
