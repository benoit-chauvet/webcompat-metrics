-- Score distribution by source/origin (monthly averages)
-- Use case: Line chart showing monthly average score by origin

WITH bug_scores AS (
  SELECT
    DATE_TRUNC(DATE(s.creation_time), MONTH) AS month,
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
    s.webcompat_priority AS priority,
    CAST(s.score AS INT64) AS score
  FROM
    `moz-fx-dev-dschubert-wckb.webcompat_knowledge_base.scored_site_reports` s
  WHERE
    s.resolved_time IS NULL
)
SELECT
  month,
  origin,
  COUNT(*) AS bug_count,
  SUM(score) AS total_score,
  ROUND(AVG(score), 2) AS avg_score
FROM bug_scores
WHERE
  month BETWEEN "{{ start }}" AND "{{ end }}"
  AND metric IN ({{ Metric }})
  AND priority IN ({{ Priority }})
GROUP BY month, origin
ORDER BY month, origin;
