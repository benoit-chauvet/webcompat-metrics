WITH
diagnosis_enter AS (
SELECT h.number, MIN(h.change_time) as change_time
FROM moz-fx-dev-dschubert-wckb.webcompat_knowledge_base.bugs_history h,
UNNEST (h.changes) as ch
WHERE ch.field_name LIKE '%keywords%'
AND ch.added LIKE'%webcompat:needs_diagnosis%'
GROUP BY h.number
),
diagnosis_exit AS (
SELECT h.number, MAX(h.change_time) as change_time
FROM moz-fx-dev-dschubert-wckb.webcompat_knowledge_base.bugs_history h,
UNNEST (h.changes) as ch
WHERE ch.field_name LIKE '%keywords%'
AND ch.removed LIKE'%webcompat:needs_diagnosis%'
GROUP BY h.number
),
lifetimes AS (
SELECT
  r.webcompat_priority as priority,
  COUNT(*) as bug_count,
  APPROX_QUANTILES(DATETIME_DIFF(d_out.change_time, d_in.change_time, HOUR)/24, 100)[OFFSET(50)] as median_lifetime,
  AVG(DATETIME_DIFF(d_out.change_time, d_in.change_time, HOUR)/24) as avg_lifetime,
  MIN(DATETIME_DIFF(d_out.change_time, d_in.change_time, HOUR)/24) as min_lifetime,
  MAX(DATETIME_DIFF(d_out.change_time, d_in.change_time, HOUR)/24) as max_lifetime,
FROM diagnosis_enter d_in
JOIN diagnosis_exit d_out on d_in.number = d_out.number
JOIN moz-fx-dev-dschubert-wckb.webcompat_knowledge_base.site_reports r ON r.number = d_in.number
WHERE r.webcompat_priority IN ('P1', 'P2', 'P3')
AND DATE(r.creation_time) BETWEEN DATE('{{from}}') AND DATE('{{to}}')
GROUP BY r.webcompat_priority
),
totals AS (
    select webcompat_priority as priority,
    COUNT(*) as total
    FROM moz-fx-dev-dschubert-wckb.webcompat_knowledge_base.site_reports r
    WHERE r.webcompat_priority IN ('P1', 'P2', 'P3')
    AND DATE(r.creation_time) BETWEEN DATE('{{from}}') AND DATE('{{to}}')
    GROUP BY priority
)

SELECT 
l.*, 
t.total,
l.bug_count/total * 100 as ratio
FROM lifetimes l
JOIN totals t ON l.priority = t.priority
ORDER BY priority
;
