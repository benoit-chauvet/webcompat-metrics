WITH
diagnosis_enter AS (
SELECT h.number, h.change_time, ch.added
FROM moz-fx-dev-dschubert-wckb.webcompat_knowledge_base.bugs_history h,
UNNEST (h.changes) as ch
WHERE ch.field_name LIKE '%keywords%'
AND ch.added LIKE'%webcompat:needs_diagnosis%'
ORDER BY h.number
),
diagnosis_exit AS (
SELECT h.number, h.change_time, ch.removed
FROM moz-fx-dev-dschubert-wckb.webcompat_knowledge_base.bugs_history h,
UNNEST (h.changes) as ch
WHERE ch.field_name LIKE '%keywords%'
AND ch.removed LIKE'%webcompat:needs_diagnosis%'
ORDER BY h.number
),
diagnosis_lifetimes AS (
SELECT
  r.webcompat_priority,
  DATE_DIFF(d_out.change_time, d_in.change_time, DAY) as lifetime_days
FROM diagnosis_enter d_in
JOIN diagnosis_exit d_out on d_in.number = d_out.number
JOIN moz-fx-dev-dschubert-wckb.webcompat_knowledge_base.site_reports r ON r.number = d_in.number
WHERE r.webcompat_priority IN ('P1', 'P2', 'P3')
AND DATE(r.creation_time) BETWEEN DATE('{{from}}') AND DATE('{{to}}')
),
stats AS (
SELECT
  webcompat_priority,
  COUNT(*) as total_bugs,
  AVG(lifetime_days) as avg_lifetime,
  APPROX_QUANTILES(lifetime_days, 100)[OFFSET(10)] as p10_days,
  APPROX_QUANTILES(lifetime_days, 100)[OFFSET(20)] as p20_days,
  APPROX_QUANTILES(lifetime_days, 100)[OFFSET(30)] as p30_days,
  APPROX_QUANTILES(lifetime_days, 100)[OFFSET(40)] as p40_days,
  APPROX_QUANTILES(lifetime_days, 100)[OFFSET(50)] as p50_days,
  APPROX_QUANTILES(lifetime_days, 100)[OFFSET(60)] as p60_days,
  APPROX_QUANTILES(lifetime_days, 100)[OFFSET(70)] as p70_days,
  APPROX_QUANTILES(lifetime_days, 100)[OFFSET(80)] as p80_days,
  APPROX_QUANTILES(lifetime_days, 100)[OFFSET(90)] as p90_days
FROM diagnosis_lifetimes
GROUP BY webcompat_priority
),
unpivoted AS (
SELECT
  webcompat_priority,
  percentile,
  resolved_in_days
FROM stats
CROSS JOIN UNNEST([
  STRUCT('p10' as percentile, p10_days as resolved_in_days),
  STRUCT('p20', p20_days),
  STRUCT('p30', p30_days),
  STRUCT('p40', p40_days),
  STRUCT('p50', p50_days),
  STRUCT('p60', p60_days),
  STRUCT('p70', p70_days),
  STRUCT('p80', p80_days),
  STRUCT('p90', p90_days)
])
)

SELECT
  percentile,
  MAX(CASE WHEN webcompat_priority = 'P1' THEN resolved_in_days END) as P1,
  MAX(CASE WHEN webcompat_priority = 'P2' THEN resolved_in_days END) as P2,
  MAX(CASE WHEN webcompat_priority = 'P3' THEN resolved_in_days END) as P3
FROM unpivoted
GROUP BY percentile
ORDER BY percentile
;
