-- Score distribution across priorities
-- Use case: Pie chart or stacked bar

SELECT
  CASE
    WHEN s.is_core THEN "Core Countries"
    WHEN s.is_sightline THEN "Sightline"
    ELSE "other"
  END AS metric,
  s.webcompat_priority AS priority,
  COUNT(*) AS bug_count,
  SUM(CAST(s.score AS INT64)) AS total_score,
  ROUND(AVG(CAST(s.score AS FLOAT64)), 2) AS avg_score_per_bug
FROM
  `moz-fx-dev-dschubert-wckb.webcompat_knowledge_base.scored_site_reports` s
WHERE
  s.resolved_time IS NULL
  AND DATE(s.creation_time) BETWEEN "{{ start }}" AND "{{ end }}"
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
