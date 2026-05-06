WITH 
-- sitepatch
sitepatch_enter AS (
SELECT h.number, h.change_time, ch.added 
FROM moz-fx-dev-dschubert-wckb.webcompat_knowledge_base.bugs_history h,
UNNEST (h.changes) as ch
WHERE ch.field_name LIKE '%keywords%'
AND ch.added LIKE'%webcompat:needs_sitepatch%'
ORDER BY h.number
),
sitepatch_exit AS (
SELECT h.number, h.change_time, ch.removed 
FROM moz-fx-dev-dschubert-wckb.webcompat_knowledge_base.bugs_history h,
UNNEST (h.changes) as ch
WHERE ch.field_name LIKE '%keywords%'
AND ch.removed LIKE'%webcompat:needs_sitepatch%'
ORDER BY h.number
),
sitepatch AS (
SELECT r.webcompat_priority, AVG(DATE_DIFF(sp_out.change_time, sp_in.change_time, DAY)) as lifetime
FROM sitepatch_enter sp_in
JOIN sitepatch_exit sp_out on sp_in.number = sp_out.number
JOIN moz-fx-dev-dschubert-wckb.webcompat_knowledge_base.site_reports r ON r.number = sp_in.number
WHERE r.webcompat_priority IN ('P1', 'P2', 'P3')
AND DATE(r.creation_time) BETWEEN  DATE('{{from}}') AND DATE('{{to}}')
GROUP BY r.webcompat_priority
),
-- diagnosis
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
diagnosis AS (
SELECT r.webcompat_priority, AVG(DATE_DIFF(d_out.change_time, d_in.change_time, DAY)) as lifetime
FROM diagnosis_enter d_in
JOIN diagnosis_exit d_out on d_in.number = d_out.number
JOIN moz-fx-dev-dschubert-wckb.webcompat_knowledge_base.site_reports r ON r.number = d_in.number
WHERE r.webcompat_priority IN ('P1', 'P2', 'P3')
AND DATE(r.creation_time) BETWEEN  DATE('{{from}}') AND DATE('{{to}}')
GROUP BY r.webcompat_priority
)

SELECT d.webcompat_priority, sp.lifetime as sitepatch_lifetime, d.lifetime as diagnosis_lifetime 
FROM diagnosis d
FULL JOIN sitepatch sp on d.webcompat_priority = sp.webcompat_priority
ORDER BY webcompat_priority
;
