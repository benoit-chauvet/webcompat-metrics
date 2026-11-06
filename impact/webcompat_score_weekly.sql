-- Weekly aggregation of score changes (new vs resolved)
-- Use case: Bar chart with weekly comparison of score evolution

WITH new_bugs AS (
  SELECT
    DATE_TRUNC(DATE(s.creation_time), WEEK(MONDAY)) AS week,
    CASE
      WHEN s.is_core THEN "Core Countries"
      WHEN s.is_sightline THEN "Sightline"
      ELSE "other"
    END AS metric,
    s.webcompat_priority AS priority,
    SUM(CAST(s.score AS INT64)) AS score_new,
    COUNT(*) AS bugs_new
  FROM
    `moz-fx-dev-dschubert-wckb.webcompat_knowledge_base.scored_site_reports` s
  GROUP BY week, metric, priority
),
resolved_bugs AS (
  SELECT
    DATE_TRUNC(DATE(s.resolved_time), WEEK(MONDAY)) AS week,
    CASE
      WHEN s.is_core THEN "Core Countries"
      WHEN s.is_sightline THEN "Sightline"
      ELSE "other"
    END AS metric,
    s.webcompat_priority AS priority,
    SUM(CAST(s.score AS INT64)) AS score_resolved,
    COUNT(*) AS bugs_resolved
  FROM
    `moz-fx-dev-dschubert-wckb.webcompat_knowledge_base.scored_site_reports` s
  WHERE
    s.resolved_time IS NOT NULL
  GROUP BY week, metric, priority
),
combined AS (
  SELECT
    COALESCE(n.week, r.week) AS week,
    COALESCE(n.metric, r.metric) AS metric,
    COALESCE(n.priority, r.priority) AS priority,
    COALESCE(n.score_new, 0) AS score_new,
    COALESCE(n.bugs_new, 0) AS bugs_new,
    COALESCE(r.score_resolved, 0) AS score_resolved,
    COALESCE(r.bugs_resolved, 0) AS bugs_resolved,
    COALESCE(n.score_new, 0) - COALESCE(r.score_resolved, 0) AS net_score_change
  FROM new_bugs n
  FULL OUTER JOIN resolved_bugs r
    ON n.week = r.week AND n.metric = r.metric AND n.priority = r.priority
)
SELECT
  week,
  metric,
  priority,
  SUM(score_new) AS score_new,
  SUM(bugs_new) AS bugs_new,
  SUM(score_resolved) AS score_resolved,
  SUM(bugs_resolved) AS bugs_resolved,
  SUM(net_score_change) AS net_score_change
FROM combined
WHERE
  week BETWEEN "{{ start }}" AND "{{ end }}"
  AND metric IN ({{ Metric }})
  AND priority IN ({{ Priority }})
GROUP BY week, metric, priority
ORDER BY week DESC, metric, priority;
