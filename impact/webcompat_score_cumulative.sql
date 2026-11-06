-- Cumulative webcompat score over time (running total, weekly aggregation)
-- Use case: Line chart showing score trend

WITH weekly_changes AS (
  -- New bugs added (positive score)
  SELECT
    DATE_TRUNC(DATE(s.creation_time), WEEK(MONDAY)) AS week,
    CASE
      WHEN s.is_core THEN "Core Countries"
      WHEN s.is_sightline THEN "Sightline"
      ELSE "other"
    END AS metric,
    s.webcompat_priority AS priority,
    SUM(CAST(s.score AS INT64)) AS score_change
  FROM
    `moz-fx-dev-dschubert-wckb.webcompat_knowledge_base.scored_site_reports` s
  GROUP BY week, metric, priority

  UNION ALL

  -- Resolved bugs (negative score)
  SELECT
    DATE_TRUNC(DATE(s.resolved_time), WEEK(MONDAY)) AS week,
    CASE
      WHEN s.is_core THEN "Core Countries"
      WHEN s.is_sightline THEN "Sightline"
      ELSE "other"
    END AS metric,
    s.webcompat_priority AS priority,
    -SUM(CAST(s.score AS INT64)) AS score_change
  FROM
    `moz-fx-dev-dschubert-wckb.webcompat_knowledge_base.scored_site_reports` s
  WHERE
    s.resolved_time IS NOT NULL
  GROUP BY week, metric, priority
),
aggregated AS (
  SELECT
    week,
    metric,
    priority,
    SUM(score_change) AS weekly_net_change
  FROM weekly_changes
  WHERE week IS NOT NULL
  GROUP BY week, metric, priority
),
with_cumulative AS (
  SELECT
    week,
    metric,
    priority,
    weekly_net_change,
    SUM(weekly_net_change) OVER (
      PARTITION BY metric, priority
      ORDER BY week
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_score
  FROM aggregated
),
filtered AS (
  SELECT
    week,
    metric,
    priority,
    weekly_net_change,
    cumulative_score
  FROM with_cumulative
  WHERE
    metric IN ({{ Metric }})
    AND priority IN ({{ Priority }})
),
-- Aggregated by priority
by_priority AS (
  SELECT
    week,
    priority AS series,
    SUM(cumulative_score) AS cumulative_score
  FROM filtered
  WHERE priority IN ('P1', 'P2', 'P3')
  GROUP BY week, priority
),
-- Total aggregated
total AS (
  SELECT
    week,
    'Total' AS series,
    SUM(cumulative_score) AS cumulative_score
  FROM filtered
  GROUP BY week
),
-- Combine both
combined AS (
  SELECT * FROM by_priority
  UNION ALL
  SELECT * FROM total
),
with_rolling_avg AS (
  SELECT
    week,
    series,
    cumulative_score,
    ROUND(AVG(cumulative_score) OVER (
      PARTITION BY series
      ORDER BY week
      ROWS BETWEEN 3 PRECEDING AND CURRENT ROW
    ), 0) AS cumulative_score_4w_avg
  FROM combined
)
SELECT
  week,
  series,
  cumulative_score,
  cumulative_score_4w_avg
FROM with_rolling_avg
WHERE
  week BETWEEN "{{ start }}" AND "{{ end }}"
ORDER BY week, series;
