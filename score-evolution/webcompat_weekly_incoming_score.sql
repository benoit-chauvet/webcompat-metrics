-- Weekly incoming vs resolved score for Core Countries bugs
-- Incoming: bugs grouped by creation week; resolved: bugs grouped by resolution week
-- current_score: total score of open bugs at the end of each week (running total of net_score)
-- Use case: Bar chart comparing incoming and resolved score per week, line for current score

WITH incoming AS (
  SELECT
    DATE_TRUNC(DATE(s.creation_time), WEEK(MONDAY)) AS week,
    SUM(CAST(s.score AS INT64)) AS incoming_score,
    COUNT(*) AS incoming_bugs
  FROM `moz-fx-dev-dschubert-wckb.webcompat_knowledge_base.scored_site_reports` s
  WHERE s.is_core
  GROUP BY week
),
resolved AS (
  SELECT
    DATE_TRUNC(DATE(s.resolved_time), WEEK(MONDAY)) AS week,
    SUM(CAST(s.score AS INT64)) AS resolved_score,
    COUNT(*) AS resolved_bugs
  FROM `moz-fx-dev-dschubert-wckb.webcompat_knowledge_base.scored_site_reports` s
  WHERE s.is_core
    AND s.resolved_time IS NOT NULL
  GROUP BY week
),
weekly AS (
  SELECT
    week,
    COALESCE(i.incoming_score, 0) AS incoming_score,
    COALESCE(i.incoming_bugs, 0) AS incoming_bugs,
    COALESCE(r.resolved_score, 0) AS resolved_score,
    COALESCE(r.resolved_bugs, 0) AS resolved_bugs,
    COALESCE(i.incoming_score, 0) - COALESCE(r.resolved_score, 0) AS net_score
  FROM incoming i
  FULL OUTER JOIN resolved r USING (week)
),
-- Running total over all history (computed before the date filter)
with_current AS (
  SELECT
    *,
    SUM(net_score) OVER (ORDER BY week ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS current_score
  FROM weekly
)
SELECT *
FROM with_current
WHERE week BETWEEN DATE_TRUNC(DATE "{{ start }}", WEEK(MONDAY)) AND "{{ end }}"
ORDER BY week DESC;
