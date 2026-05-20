-- name: sql_agent_job_history
-- title: SQL Agent job history
-- description: Recent SQL Server Agent job and step history.
BEGIN TRY
    SELECT TOP (1000)
        j.name AS job_name,
        h.step_id,
        h.step_name,
        CASE h.run_status
            WHEN 0 THEN 'Failed'
            WHEN 1 THEN 'Succeeded'
            WHEN 2 THEN 'Retry'
            WHEN 3 THEN 'Canceled'
            WHEN 4 THEN 'In Progress'
            ELSE 'Unknown'
        END AS run_status,
        STUFF(STUFF(CONVERT(char(8), h.run_date), 5, 0, '-'), 8, 0, '-')
            + ' '
            + STUFF(LEFT(RIGHT('000000' + CONVERT(varchar(6), h.run_time), 6), 4), 3, 0, ':') AS run_datetime,
        h.run_duration,
        h.sql_severity,
        h.sql_message_id,
        h.retries_attempted,
        h.server,
        h.message
    FROM msdb.dbo.sysjobhistory AS h
    INNER JOIN msdb.dbo.sysjobs AS j
        ON j.job_id = h.job_id
    ORDER BY h.run_date DESC, h.run_time DESC, j.name, h.step_id;
END TRY
BEGIN CATCH
    SELECT
        ERROR_MESSAGE() AS job_name,
        CAST(NULL AS int) AS step_id,
        CAST(NULL AS sysname) AS step_name,
        CAST(NULL AS varchar(12)) AS run_status,
        CAST(NULL AS varchar(16)) AS run_datetime,
        CAST(NULL AS int) AS run_duration,
        CAST(NULL AS int) AS sql_severity,
        CAST(NULL AS int) AS sql_message_id,
        CAST(NULL AS int) AS retries_attempted,
        CAST(NULL AS sysname) AS server,
        CAST(NULL AS nvarchar(4000)) AS message;
END CATCH;
