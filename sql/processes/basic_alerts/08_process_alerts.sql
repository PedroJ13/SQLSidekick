-- name: process_alerts
-- title: Job alerts
-- description: SQL Agent job alert flags grouped by impact. Returns only alerts that are currently on, without object-level details.
CREATE TABLE #process_alerts (
    severity varchar(10) NOT NULL,
    alert_category varchar(40) NOT NULL,
    alert_name varchar(160) NOT NULL,
    active_count int NULL
);

BEGIN TRY
    INSERT INTO #process_alerts (severity, alert_category, alert_name, active_count)
    SELECT
        'LOW',
        'STATUS',
        'Jobs are disabled',
        COUNT(*)
    FROM msdb.dbo.sysjobs
    WHERE enabled = 0
    HAVING COUNT(*) > 0;
END TRY
BEGIN CATCH
    INSERT INTO #process_alerts (severity, alert_category, alert_name, active_count)
    VALUES ('LOW', 'ACCESS', 'Disabled jobs could not be evaluated', NULL);
END CATCH;

BEGIN TRY
    WITH last_runs AS (
        SELECT
            h.job_id,
            h.run_status,
            ROW_NUMBER() OVER (PARTITION BY h.job_id ORDER BY h.run_date DESC, h.run_time DESC, h.instance_id DESC) AS rn
        FROM msdb.dbo.sysjobhistory AS h
        WHERE h.step_id = 0
    )
    INSERT INTO #process_alerts (severity, alert_category, alert_name, active_count)
    SELECT
        'HIGH',
        'EXECUTION',
        'Last job run failed or was canceled',
        COUNT(*)
    FROM msdb.dbo.sysjobs AS j
    INNER JOIN last_runs AS lr
        ON lr.job_id = j.job_id
       AND lr.rn = 1
    WHERE j.enabled = 1
      AND lr.run_status IN (0, 3)
    HAVING COUNT(*) > 0;
END TRY
BEGIN CATCH
    INSERT INTO #process_alerts (severity, alert_category, alert_name, active_count)
    VALUES ('HIGH', 'ACCESS', 'Last job run status could not be evaluated', NULL);
END CATCH;

BEGIN TRY
    INSERT INTO #process_alerts (severity, alert_category, alert_name, active_count)
    SELECT
        'MEDIUM',
        'SCHEDULE',
        'Enabled jobs do not have an active future schedule',
        COUNT(*)
    FROM msdb.dbo.sysjobs AS j
    WHERE j.enabled = 1
      AND NOT EXISTS (
          SELECT 1
          FROM msdb.dbo.sysjobschedules AS js
          WHERE js.job_id = j.job_id
            AND js.next_run_date > 0
      )
    HAVING COUNT(*) > 0;
END TRY
BEGIN CATCH
    INSERT INTO #process_alerts (severity, alert_category, alert_name, active_count)
    VALUES ('MEDIUM', 'ACCESS', 'Job schedules could not be evaluated', NULL);
END CATCH;

BEGIN TRY
    WITH last_runs AS (
        SELECT
            h.job_id,
            h.run_date,
            h.run_time,
            ROW_NUMBER() OVER (PARTITION BY h.job_id ORDER BY h.run_date DESC, h.run_time DESC, h.instance_id DESC) AS rn
        FROM msdb.dbo.sysjobhistory AS h
        WHERE h.step_id = 0
    )
    INSERT INTO #process_alerts (severity, alert_category, alert_name, active_count)
    SELECT
        'MEDIUM',
        'EXECUTION',
        'Enabled jobs have not run in the last 30 days',
        COUNT(*)
    FROM msdb.dbo.sysjobs AS j
    LEFT JOIN last_runs AS lr
        ON lr.job_id = j.job_id
       AND lr.rn = 1
    WHERE j.enabled = 1
      AND (
          lr.job_id IS NULL
          OR TRY_CONVERT(date, CONVERT(char(8), lr.run_date), 112) < DATEADD(day, -30, CONVERT(date, GETDATE()))
      )
    HAVING COUNT(*) > 0;
END TRY
BEGIN CATCH
    INSERT INTO #process_alerts (severity, alert_category, alert_name, active_count)
    VALUES ('MEDIUM', 'ACCESS', 'Job run recency could not be evaluated', NULL);
END CATCH;

BEGIN TRY
    INSERT INTO #process_alerts (severity, alert_category, alert_name, active_count)
    SELECT
        'LOW',
        'RETRY',
        'Job steps have high retry attempts configured',
        COUNT(*)
    FROM msdb.dbo.sysjobsteps
    WHERE retry_attempts >= 3
    HAVING COUNT(*) > 0;
END TRY
BEGIN CATCH
    INSERT INTO #process_alerts (severity, alert_category, alert_name, active_count)
    VALUES ('LOW', 'ACCESS', 'Job step retry settings could not be evaluated', NULL);
END CATCH;

BEGIN TRY
    INSERT INTO #process_alerts (severity, alert_category, alert_name, active_count)
    SELECT
        'HIGH',
        'OWNERSHIP',
        'Jobs have orphaned or unresolved owners',
        COUNT(*)
    FROM msdb.dbo.sysjobs
    WHERE SUSER_SNAME(owner_sid) IS NULL
    HAVING COUNT(*) > 0;
END TRY
BEGIN CATCH
    INSERT INTO #process_alerts (severity, alert_category, alert_name, active_count)
    VALUES ('HIGH', 'ACCESS', 'Job owner resolution could not be evaluated', NULL);
END CATCH;

BEGIN TRY
    INSERT INTO #process_alerts (severity, alert_category, alert_name, active_count)
    SELECT
        'MEDIUM',
        'OWNERSHIP',
        'Jobs are owned by disabled logins',
        COUNT(*)
    FROM msdb.dbo.sysjobs AS j
    INNER JOIN sys.sql_logins AS sl
        ON sl.sid = j.owner_sid
    WHERE sl.is_disabled = 1
    HAVING COUNT(*) > 0;
END TRY
BEGIN CATCH
    INSERT INTO #process_alerts (severity, alert_category, alert_name, active_count)
    VALUES ('LOW', 'ACCESS', 'Disabled job owners could not be evaluated', NULL);
END CATCH;

BEGIN TRY
    INSERT INTO #process_alerts (severity, alert_category, alert_name, active_count)
    SELECT
        'MEDIUM',
        'STRUCTURE',
        'Enabled jobs have no steps',
        COUNT(*)
    FROM msdb.dbo.sysjobs AS j
    WHERE j.enabled = 1
      AND NOT EXISTS (
          SELECT 1
          FROM msdb.dbo.sysjobsteps AS js
          WHERE js.job_id = j.job_id
      )
    HAVING COUNT(*) > 0;
END TRY
BEGIN CATCH
    INSERT INTO #process_alerts (severity, alert_category, alert_name, active_count)
    VALUES ('MEDIUM', 'ACCESS', 'Job step existence could not be evaluated', NULL);
END CATCH;

WITH ranked_alerts AS (
    SELECT
        severity,
        alert_category,
        alert_name,
        active_count,
        MIN(CASE severity
            WHEN 'HIGH' THEN 1
            WHEN 'MEDIUM' THEN 2
            WHEN 'LOW' THEN 3
            ELSE 4
        END) OVER () AS highest_detected_severity_rank
    FROM #process_alerts
)
SELECT
    CASE highest_detected_severity_rank
        WHEN 1 THEN 'HIGH'
        WHEN 2 THEN 'MEDIUM'
        WHEN 3 THEN 'LOW'
        ELSE 'UNKNOWN'
    END AS highest_detected_severity,
    severity,
    alert_category,
    alert_name,
    active_count
FROM ranked_alerts
ORDER BY
    CASE severity
        WHEN 'HIGH' THEN 1
        WHEN 'MEDIUM' THEN 2
        WHEN 'LOW' THEN 3
        ELSE 4
    END,
    alert_category,
    alert_name;

DROP TABLE #process_alerts;
