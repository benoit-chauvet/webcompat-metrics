-- Sitepatch Survival Rate: fraction of bugs still in needs_sitepatch status over time
WITH
sitepatch_enter AS (
  SELECT h.number, MIN(h.change_time) as enter_time
  FROM `moz-fx-dev-dschubert-wckb.webcompat_knowledge_base.bugs_history` h,
  UNNEST (h.changes) as ch
  WHERE ch.field_name LIKE '%keywords%'
  AND ch.added LIKE '%webcompat:needs_sitepatch%'
  GROUP BY h.number
),
sitepatch_exit AS (
  SELECT h.number, MIN(h.change_time) as exit_time
  FROM `moz-fx-dev-dschubert-wckb.webcompat_knowledge_base.bugs_history` h,
  UNNEST (h.changes) as ch
  WHERE ch.field_name LIKE '%keywords%'
  AND ch.removed LIKE '%webcompat:needs_sitepatch%'
  GROUP BY h.number
),
sitepatch_durations AS (
  SELECT
    r.webcompat_priority,
    sp_in.number,
    sp_in.enter_time,
    sp_out.exit_time,
    TIMESTAMP_DIFF(sp_out.exit_time, sp_in.enter_time, SECOND)/(3600*24) as days_in_status
  FROM sitepatch_enter sp_in
  LEFT JOIN sitepatch_exit sp_out ON sp_in.number = sp_out.number
  JOIN `moz-fx-dev-dschubert-wckb.webcompat_knowledge_base.site_reports` r ON r.number = sp_in.number
  WHERE r.webcompat_priority IN ('P1', 'P2', 'P3')
  AND DATE(r.creation_time) BETWEEN DATE('{{from}}') AND DATE('{{to}}')
),
totals AS (
  SELECT webcompat_priority, COUNT(*) as total
  FROM sitepatch_durations
  GROUP BY webcompat_priority
),
counts AS (
  SELECT
    day,
    COUNTIF(d.webcompat_priority = 'P1' AND (d.days_in_status >= day OR d.days_in_status IS NULL)) as open_p1,
    COUNTIF(d.webcompat_priority = 'P2' AND (d.days_in_status >= day OR d.days_in_status IS NULL)) as open_p2,
    COUNTIF(d.webcompat_priority = 'P3' AND (d.days_in_status >= day OR d.days_in_status IS NULL)) as open_p3
  FROM UNNEST(GENERATE_ARRAY(0, 90)) as day
  LEFT JOIN sitepatch_durations d ON TRUE
  GROUP BY day
)

SELECT
  day,
  SAFE_DIVIDE(open_p1, (SELECT total FROM totals WHERE webcompat_priority = 'P1')) as P1,
  SAFE_DIVIDE(open_p2, (SELECT total FROM totals WHERE webcompat_priority = 'P2')) as P2,
  SAFE_DIVIDE(open_p3, (SELECT total FROM totals WHERE webcompat_priority = 'P3')) as P3
FROM counts
ORDER BY day
;
