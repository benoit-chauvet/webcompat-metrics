WITH
    hackbot_repro AS (
        SELECT
            PARSE_NUMERIC(scheduled.run_key) as number,
            DATETIME_DIFF(completed.completed_at, completed.created_at, SECOND) as execution_time
        FROM moz-fx-dev-dschubert-wckb.autowebcompat.hackbot_scheduled scheduled
        JOIN moz-fx-dev-dschubert-wckb.autowebcompat.hackbot_completed completed USING (run_id)
        WHERE scheduled.task_name = 'repro'
    ),
reports AS (
    SELECT
        reports.number AS number,
        DATE(reports.creation_time) AS creation_date,
        CASE
            WHEN reports.whiteboard LIKE '%[webcompat-source:product]%' THEN 'product'
            WHEN reports.whiteboard LIKE '%[webcompat-source:web-bugs]%' THEN 'web-bugs'
            ELSE 'other'
        END AS origin,
        CASE
            WHEN JSON_VALUE(reports.user_story, '$.impact') IS NULL THEN FALSE
            ELSE TRUE
        END AS triaged,
        scored.impact_score AS impact_score,
        scored.webcompat_priority AS webcompat_priority,
        CASE
            WHEN reports.whiteboard like '%autowebcompat:processed%' THEN TRUE
            ELSE FALSE
        END AS autowebcompat_processed,
        CASE
            WHEN reports.whiteboard like '%autowebcompat:repro-success%' THEN TRUE
            WHEN reports.whiteboard like '%autowebcompat:repro-failed%' THEN FALSE
            ELSE NULL
        END AS autowebcompat_reproduced,
        hackbot_repro.execution_time AS repro_time,
        CASE
            WHEN reports.whiteboard like '%autowebcompat:interv-ua-override-proposed%' THEN TRUE
            ELSE FALSE
        END AS interv_ua_override_proposed
    FROM moz-fx-dev-dschubert-wckb.webcompat_knowledge_base.site_reports reports
        LEFT JOIN moz-fx-dev-dschubert-wckb.webcompat_knowledge_base.scored_site_reports scored USING (number)
        LEFT JOIN hackbot_repro USING (number)
    WHERE DATE(reports.creation_time) BETWEEN DATE('{{start_date}}') AND DATE('{{end_date}}')
    ORDER BY reports.creation_time DESC
)

SELECT
    COUNT(1) as number_processed,
    COUNTIF(autowebcompat_reproduced) as number_reproduced,
    (COUNTIF(autowebcompat_reproduced) / COUNT(1)) *100 as reproduction_rate,
    COUNTIF(interv_ua_override_proposed) as ua_override_detected,
    AVG(repro_time) as avg_repro_time,
    APPROX_QUANTILES(repro_time, 2)[OFFSET(1)] as median_repro_time,
    MIN(repro_time) as min_repro_time,
    MAX(repro_time) as max_repro_time,
    SUM(repro_time) / 3600.0 as total_repro_time
FROM reports
WHERE autowebcompat_processed = true;
