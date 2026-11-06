-- Total score : https://sql.telemetry.mozilla.org/queries/114984/source?p_Metric=Core%20Countries

WITH new_bugs AS (
SELECT
    CASE
      WHEN s.is_core THEN "Core Countries"
      WHEN s.is_sightline THEN "Sightline"
      ELSE "other"
  END as metric,
  SUM(CAST(s.score AS int64)) AS Score,
  CASE
    WHEN s.whiteboard LIKE '%[webcompat-source:product]%'  THEN 'Fx user reports'
    WHEN s.whiteboard LIKE '%[webcompat-source:web-bugs]%'  THEN 'webcompat.com'
    ELSE 'other'
  END as origin,
  s.webcompat_priority AS priority,
  DATE(s.creation_time) as date
  FROM
  `moz-fx-dev-dschubert-wckb.webcompat_knowledge_base.scored_site_reports` s
GROUP BY metric, origin, priority, date
ORDER BY date desc, priority
),
resolved_bugs AS (
SELECT
    CASE
      WHEN s.is_core THEN "Core Countries"
      WHEN s.is_sightline THEN "Sightline"
      ELSE "other"
  END as metric,
  SUM(CAST(s.score AS int64)) AS Score,
  CASE
    WHEN s.whiteboard LIKE '%[webcompat-source:product]%'  THEN 'Fx user reports'
    WHEN s.whiteboard LIKE '%[webcompat-source:web-bugs]%'  THEN 'webcompat.com'
    ELSE 'other'
  END as origin,
  s.webcompat_priority AS priority,
  DATE(s.resolved_time) as date
  FROM `moz-fx-dev-dschubert-wckb.webcompat_knowledge_base.scored_site_reports` s
  WHERE s.resolved_time IS NOT NULL
GROUP BY metric, origin, priority, date
ORDER BY date desc, priority
),
details as (
SELECT
  date,
  metric,
  origin,
  priority,
  SUM(COALESCE(new_bugs.score,0)) as score_new,
  SUM(COALESCE(resolved_bugs.score, 0)) as score_resolved,
  SUM(COALESCE(new_bugs.score,0) - COALESCE(resolved_bugs.score, 0)) as diff
  FROM new_bugs
  FULL JOIN resolved_bugs USING(date,metric,origin,priority)
  GROUP BY metric, origin, priority, date
  ORDER BY date desc, priority
)
SELECT *
FROM details
WHERE date BETWEEN "{{ start }}" AND "{{ end }}"
;
