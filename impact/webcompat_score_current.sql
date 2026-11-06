-- Current total webcompat score for open bugs
-- Use case: Dashboard header / KPI cards

SELECT
  CASE
    WHEN s.is_core THEN "Core Countries"
    WHEN s.is_sightline THEN "Sightline"
    ELSE "other"
  END AS metric,
  s.webcompat_priority AS priority,
  COUNT(*) AS bug_count,
  SUM(CAST(s.score AS INT64)) AS total_score
FROM
  `moz-fx-dev-dschubert-wckb.webcompat_knowledge_base.scored_site_reports` s
WHERE
  s.resolved_time IS NULL
  AND CASE
    WHEN s.is_core THEN "Core Countries"
    WHEN s.is_sightline THEN "Sightline"
    ELSE "other"
  END IN ({{ Metric }})
  AND s.webcompat_priority IN ({{ Priority }})
GROUP BY
  metric, priority
ORDER BY
  CASE metric
    WHEN "Core Countries" THEN 1
    WHEN "Sightline" THEN 2
    ELSE 3
  END,
  priority;
