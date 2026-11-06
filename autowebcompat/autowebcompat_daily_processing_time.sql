WITH
    hackbot_repro AS (
        SELECT
            PARSE_NUMERIC(scheduled.run_key) as number,
            DATE(completed.completed_at) as completion_date,
            DATETIME_DIFF(completed.completed_at, completed.created_at, SECOND) as execution_time
        FROM moz-fx-dev-dschubert-wckb.autowebcompat.hackbot_scheduled scheduled
        JOIN moz-fx-dev-dschubert-wckb.autowebcompat.hackbot_completed completed USING (run_id)
        WHERE scheduled.task_name = 'repro'
    )
SELECT
    completion_date AS date,
    COUNT(*) AS count,
    ROUND(AVG(execution_time), 0) AS avg_time,
    APPROX_QUANTILES(execution_time, 2)[OFFSET(1)] AS median_time,
    MIN(execution_time) AS min_time,
    MAX(execution_time) AS max_time,
    ROUND(SUM(execution_time) / 3600.0, 2) AS total_hours
FROM hackbot_repro
WHERE completion_date BETWEEN DATE('{{start_date}}') AND DATE('{{end_date}}')
GROUP BY completion_date
ORDER BY completion_date;
