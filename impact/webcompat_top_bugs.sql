-- Top scoring open bugs
-- Use case: Table widget

SELECT
  s.number AS bug_number,
  CAST(s.score AS INT64) AS score,
  s.webcompat_priority AS priority,
  CASE
    WHEN s.is_core THEN "Core Countries"
    WHEN s.is_sightline THEN "Sightline"
    ELSE "other"
  END AS metric,
  CASE
    WHEN s.whiteboard LIKE '%[webcompat-source:product]%' THEN 'Fx user reports'
    WHEN s.whiteboard LIKE '%[webcompat-source:web-bugs]%' THEN 'webcompat.com'
    ELSE 'other'
  END AS origin,
  DATE(s.creation_time) AS creation_date
FROM
  `moz-fx-dev-dschubert-wckb.webcompat_knowledge_base.scored_site_reports` s
WHERE
  s.resolved_time IS NULL
ORDER BY
  score DESC
LIMIT 50;
