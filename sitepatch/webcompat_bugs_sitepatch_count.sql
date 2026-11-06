
WITH
sitepatch_enter AS (
SELECT h.number, h.change_time, ch.added
FROM moz-fx-dev-dschubert-wckb.webcompat_knowledge_base.bugs_history h,
UNNEST (h.changes) as ch
WHERE ch.field_name LIKE '%keywords%'
AND ch.added LIKE'%webcompat:needs_sitepatch%'
),
sitepatch_exit AS (
SELECT h.number, h.change_time, ch.removed
FROM moz-fx-dev-dschubert-wckb.webcompat_knowledge_base.bugs_history h,
UNNEST (h.changes) as ch
WHERE ch.field_name LIKE '%keywords%'
AND ch.removed LIKE'%webcompat:needs_sitepatch%'
)

SELECT
  r.webcompat_priority as priority,
  COUNT(*) as bug_count
FROM sitepatch_enter sp_in
JOIN sitepatch_exit sp_out on sp_in.number = sp_out.number
JOIN moz-fx-dev-dschubert-wckb.webcompat_knowledge_base.site_reports r ON r.number = sp_in.number
WHERE r.webcompat_priority IN ('P1', 'P2', 'P3')
AND DATE(r.creation_time) BETWEEN DATE('{{from}}') AND DATE('{{to}}')
GROUP BY r.webcompat_priority
ORDER BY priority
;
