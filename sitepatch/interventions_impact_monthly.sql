SELECT
    DATE_TRUNC(DATE(changes.change_time), MONTH) AS month,
    COUNT(1) as count,
    SUM(changes.score_delta) AS score_delta,
    APPROX_QUANTILES(changes.score_delta, 100)[OFFSET(50)] AS median_impact,
    reports.webcompat_priority,
    STRING_AGG(DISTINCT(cast(changes.number AS STRING)), ', ') AS bugs,
    COUNT(DISTINCT changes.who) AS author_count
FROM `moz-fx-dev-dschubert-wckb.webcompat_knowledge_base.webcompat_topline_metric_changes` AS changes
LEFT OUTER JOIN `moz-fx-dev-dschubert-wckb.webcompat_knowledge_base.scored_site_reports` AS reports ON reports.number = changes.number
WHERE
    "intervention-added" in UNNEST(changes.reasons)
    AND changes.score_delta < 0
GROUP BY DATE_TRUNC(DATE(changes.change_time), MONTH), webcompat_priority
ORDER BY month DESC, webcompat_priority
