SELECT
    DATE(changes.change_time) AS date,
    COUNT(1) as count,
    SUM(changes.score_delta) AS score_delta,
    reports.webcompat_priority,
    STRING_AGG(DISTINCT(cast(changes.number AS STRING)), ', ') AS bugs,
    STRING_AGG(DISTINCT(changes.who), ', ') AS authors
FROM `moz-fx-dev-dschubert-wckb.webcompat_knowledge_base.webcompat_topline_metric_changes` AS changes
LEFT OUTER JOIN `moz-fx-dev-dschubert-wckb.webcompat_knowledge_base.scored_site_reports` AS reports ON reports.number = changes.number
WHERE
    "intervention-added" in UNNEST(changes.reasons)
    AND changes.score_delta < 0
GROUP BY DATE(changes.change_time), webcompat_priority
ORDER BY DATE(changes.change_time) DESC,webcompat_priority
