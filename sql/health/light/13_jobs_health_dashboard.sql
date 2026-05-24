-- name: jobs_health_dashboard
-- title: Jobs health
-- description: Actionable SQL Agent job health findings for failures, schedules, stale runs, owners, retries, and disabled jobs.
BEGIN TRY
    WITH last_runs AS (
        SELECT
            h.job_id,
            h.run_status,
            h.run_date,
            h.run_time,
            h.message,
            ROW_NUMBER() OVER (PARTITION BY h.job_id ORDER BY h.run_date DESC, h.run_time DESC, h.instance_id DESC) AS rn
        FROM msdb.dbo.sysjobhistory AS h
        WHERE h.step_id = 0
    ),
    schedule_summary AS (
        SELECT
            js.job_id,
            COUNT(*) AS schedule_count,
            SUM(CASE WHEN js.next_run_date > 0 THEN 1 ELSE 0 END) AS future_schedule_count,
            MIN(CASE
                WHEN js.next_run_date > 0 THEN
                    STUFF(STUFF(CONVERT(char(8), js.next_run_date), 5, 0, '-'), 8, 0, '-')
                    + ' '
                    + STUFF(LEFT(RIGHT('000000' + CONVERT(varchar(6), js.next_run_time), 6), 4), 3, 0, ':')
                ELSE NULL
            END) AS next_run_datetime
        FROM msdb.dbo.sysjobschedules AS js
        GROUP BY js.job_id
    ),
    step_summary AS (
        SELECT
            js.job_id,
            COUNT(*) AS step_count
        FROM msdb.dbo.sysjobsteps AS js
        GROUP BY js.job_id
    ),
    job_base AS (
        SELECT
            j.job_id,
            j.name AS job_name,
            CASE WHEN j.enabled = 1 THEN 'Enabled' ELSE 'Disabled' END AS job_status,
            SUSER_SNAME(j.owner_sid) AS owner_name,
            sl.is_disabled AS owner_is_disabled,
            ss.schedule_count,
            ss.future_schedule_count,
            ss.next_run_datetime,
            st.step_count,
            lr.run_status,
            CASE lr.run_status
                WHEN 0 THEN 'Failed'
                WHEN 1 THEN 'Succeeded'
                WHEN 2 THEN 'Retry'
                WHEN 3 THEN 'Canceled'
                WHEN 4 THEN 'In Progress'
                ELSE 'Unknown'
            END AS last_run_status,
            CASE
                WHEN lr.run_date IS NOT NULL THEN
                    STUFF(STUFF(CONVERT(char(8), lr.run_date), 5, 0, '-'), 8, 0, '-')
                    + ' '
                    + STUFF(LEFT(RIGHT('000000' + CONVERT(varchar(6), lr.run_time), 6), 4), 3, 0, ':')
                ELSE NULL
            END AS last_run_datetime,
            TRY_CONVERT(date, CONVERT(char(8), lr.run_date), 112) AS last_run_date,
            lr.message AS last_run_message
        FROM msdb.dbo.sysjobs AS j
        LEFT JOIN sys.sql_logins AS sl
            ON sl.sid = j.owner_sid
        LEFT JOIN schedule_summary AS ss
            ON ss.job_id = j.job_id
        LEFT JOIN step_summary AS st
            ON st.job_id = j.job_id
        LEFT JOIN last_runs AS lr
            ON lr.job_id = j.job_id
           AND lr.rn = 1
    ),
    all_findings AS (
    SELECT
        'HIGH' AS severity,
        'Recent failures' AS health_area,
        'Last run failed or was canceled' AS check_name,
        job_name,
        job_id,
        job_status,
        owner_name,
        last_run_status,
        last_run_datetime,
        next_run_datetime,
        CAST(NULL AS int) AS step_id,
        CAST(NULL AS sysname) AS step_name,
        CAST(NULL AS int) AS retry_attempts,
        LEFT(last_run_message, 1000) AS detail,
        'Review the job history and fix the failing step before the next scheduled run.' AS recommendation
    FROM job_base
    WHERE job_status = 'Enabled'
      AND run_status IN (0, 3)
      AND (last_run_date IS NULL OR last_run_date >= DATEADD(day, -7, CONVERT(date, GETDATE())))

    UNION ALL

    SELECT
        'MEDIUM',
        'Stale execution',
        'Enabled job has not run in the last 30 days',
        job_name,
        job_id,
        job_status,
        owner_name,
        last_run_status,
        last_run_datetime,
        next_run_datetime,
        CAST(NULL AS int),
        CAST(NULL AS sysname),
        CAST(NULL AS int),
        CASE WHEN last_run_datetime IS NULL THEN 'No job-level run history was found.' ELSE 'Last job-level run is older than 30 days.' END,
        'Confirm the job is still needed, scheduled correctly, or intentionally idle.'
    FROM job_base
    WHERE job_status = 'Enabled'
      AND (last_run_date IS NULL OR last_run_date < DATEADD(day, -30, CONVERT(date, GETDATE())))

    UNION ALL

    SELECT
        'MEDIUM',
        'Scheduling',
        'Enabled job has no active future schedule',
        job_name,
        job_id,
        job_status,
        owner_name,
        last_run_status,
        last_run_datetime,
        next_run_datetime,
        CAST(NULL AS int),
        CAST(NULL AS sysname),
        CAST(NULL AS int),
        'No future schedule was detected for this enabled job.',
        'Add or enable a schedule, or disable the job if it should only run manually.'
    FROM job_base
    WHERE job_status = 'Enabled'
      AND ISNULL(future_schedule_count, 0) = 0

    UNION ALL

    SELECT
        'HIGH',
        'Ownership',
        'Job owner is unresolved',
        job_name,
        job_id,
        job_status,
        owner_name,
        last_run_status,
        last_run_datetime,
        next_run_datetime,
        CAST(NULL AS int),
        CAST(NULL AS sysname),
        CAST(NULL AS int),
        'SQL Server could not resolve the job owner SID.',
        'Change the job owner to a valid service login or controlled DBA login.'
    FROM job_base
    WHERE owner_name IS NULL

    UNION ALL

    SELECT
        'MEDIUM',
        'Ownership',
        'Job owner login is disabled',
        job_name,
        job_id,
        job_status,
        owner_name,
        last_run_status,
        last_run_datetime,
        next_run_datetime,
        CAST(NULL AS int),
        CAST(NULL AS sysname),
        CAST(NULL AS int),
        'The login that owns this job is disabled.',
        'Change ownership to an enabled controlled login.'
    FROM job_base
    WHERE owner_is_disabled = 1

    UNION ALL

    SELECT
        'LOW',
        'Ownership',
        'Job owner should be reviewed',
        job_name,
        job_id,
        job_status,
        owner_name,
        last_run_status,
        last_run_datetime,
        next_run_datetime,
        CAST(NULL AS int),
        CAST(NULL AS sysname),
        CAST(NULL AS int),
        'The job is owned by a broad or personal-looking account.',
        'Prefer a dedicated service login or controlled DBA login for recurring jobs.'
    FROM job_base
    WHERE owner_name IN ('sa')
       OR owner_name LIKE '%admin%'
       OR owner_name LIKE '%\\%'

    UNION ALL

    SELECT
        'LOW',
        'Retries',
        'Step has high retry attempts configured',
        j.name,
        j.job_id,
        CASE WHEN j.enabled = 1 THEN 'Enabled' ELSE 'Disabled' END,
        SUSER_SNAME(j.owner_sid),
        CAST(NULL AS varchar(12)),
        CAST(NULL AS varchar(16)),
        CAST(NULL AS varchar(16)),
        js.step_id,
        js.step_name,
        js.retry_attempts,
        CONCAT('Retry interval: ', js.retry_interval, ' minute(s).'),
        'Review whether retries hide recurring failures or should be handled explicitly.'
    FROM msdb.dbo.sysjobsteps AS js
    INNER JOIN msdb.dbo.sysjobs AS j
        ON j.job_id = js.job_id
    WHERE js.retry_attempts >= 3

    UNION ALL

    SELECT
        'LOW',
        'Status',
        'Job is disabled',
        job_name,
        job_id,
        job_status,
        owner_name,
        last_run_status,
        last_run_datetime,
        next_run_datetime,
        CAST(NULL AS int),
        CAST(NULL AS sysname),
        CAST(NULL AS int),
        'This job is disabled.',
        'Confirm whether the job is intentionally disabled or should be re-enabled.'
    FROM job_base
    WHERE job_status = 'Disabled'
    )
    SELECT
        severity,
        health_area,
        check_name,
        job_name,
        job_id,
        job_status,
        owner_name,
        last_run_status,
        last_run_datetime,
        next_run_datetime,
        step_id,
        step_name,
        retry_attempts,
        detail,
        recommendation
    FROM all_findings
    ORDER BY
        CASE severity
            WHEN 'HIGH' THEN 1
            WHEN 'MEDIUM' THEN 2
            WHEN 'LOW' THEN 3
            ELSE 4
        END,
        health_area,
        job_name,
        step_id;
END TRY
BEGIN CATCH
    SELECT
        'HIGH' AS severity,
        'Access' AS health_area,
        'Jobs health could not be evaluated' AS check_name,
        ERROR_MESSAGE() AS job_name,
        CAST(NULL AS uniqueidentifier) AS job_id,
        CAST(NULL AS varchar(12)) AS job_status,
        CAST(NULL AS sysname) AS owner_name,
        CAST(NULL AS varchar(12)) AS last_run_status,
        CAST(NULL AS varchar(16)) AS last_run_datetime,
        CAST(NULL AS varchar(16)) AS next_run_datetime,
        CAST(NULL AS int) AS step_id,
        CAST(NULL AS sysname) AS step_name,
        CAST(NULL AS int) AS retry_attempts,
        'The current login could not read all required SQL Agent metadata.' AS detail,
        'Configure the dedicated SQL Agent login in Settings and retry this health check.' AS recommendation;
END CATCH;
