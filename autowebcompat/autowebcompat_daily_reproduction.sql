WITH
    hackbot_repro AS (
        SELECT
            PARSE_NUMERIC(scheduled.run_key) as number,
            DATE(completed.completed_at) as completion_date,
            DATETIME_DIFF(completed.completed_at, completed.created_at, SECOND) as execution_time
        FROM moz-fx-dev-dschubert-wckb.autowebcompat.hackbot_scheduled scheduled
        JOIN moz-fx-dev-dschubert-wckb.autowebcompat.hackbot_completed completed USING (run_id)
        WHERE scheduled.task_name = 'repro'
    ),
processed_stats AS (
    SELECT
        hackbot_repro.completion_date AS date,
        COUNTIF(reports.whiteboard LIKE '%autowebcompat:repro-success%') AS reproduced,
        COUNTIF(reports.whiteboard LIKE '%autowebcompat:repro-failed%') AS unreproduced,
        0 AS unprocessed
    FROM moz-fx-dev-dschubert-wckb.webcompat_knowledge_base.site_reports reports
    JOIN hackbot_repro USING (number)
    WHERE reports.whiteboard LIKE '%autowebcompat:processed%'
    AND hackbot_repro.completion_date BETWEEN DATE('{{start_date}}') AND DATE('{{end_date}}')
    GROUP BY hackbot_repro.completion_date
),
unprocessed_stats AS (
    SELECT
        DATE(reports.creation_time) AS date,
        0 AS reproduced,
        0 AS unreproduced,
        COUNT(*) AS unprocessed
    FROM moz-fx-dev-dschubert-wckb.webcompat_knowledge_base.site_reports reports
    WHERE reports.whiteboard NOT LIKE '%autowebcompat:processed%'
    AND DATE(reports.creation_time) BETWEEN DATE('{{start_date}}') AND DATE('{{end_date}}')
    GROUP BY DATE(reports.creation_time)
),
daily_stats AS (
    SELECT date, SUM(reproduced) AS reproduced, SUM(unreproduced) AS unreproduced, SUM(unprocessed) AS unprocessed
    FROM (
        SELECT * FROM processed_stats
        UNION ALL
        SELECT * FROM unprocessed_stats
    )
    GROUP BY date
)
SELECT
    date,
    reproduced,
    unreproduced,
    unprocessed,
    reproduced + unreproduced as processed,
    reproduced + unreproduced + unprocessed AS total,
    ROUND(100.0 * reproduced / NULLIF(reproduced + unreproduced + unprocessed, 0), 1) AS reproduced_pct,
    ROUND(100.0 * unreproduced / NULLIF(reproduced + unreproduced + unprocessed, 0), 1) AS unreproduced_pct,
    ROUND(100.0 * unprocessed / NULLIF(reproduced + unreproduced + unprocessed, 0), 1) AS unprocessed_pct
FROM daily_stats
ORDER BY date DESC;
