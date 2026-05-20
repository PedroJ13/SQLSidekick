-- name: process_recent_runs
-- title: Recent runs
-- description: Recent SQL Agent job executions summarized as process runs.
BEGIN TRY
    SELECT TOP (500)
        j.name AS process_name,
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
        h.message
    FROM msdb.dbo.sysjobhistory AS h
    INNER JOIN msdb.dbo.sysjobs AS j
        ON j.job_id = h.job_id
    WHERE h.step_id = 0
    ORDER BY h.run_date DESC, h.run_time DESC, h.instance_id DESC;
END TRY
BEGIN CATCH
    SELECT
        ERROR_MESSAGE() AS process_name,
        CAST(NULL AS varchar(12)) AS run_status,
        CAST(NULL AS varchar(16)) AS run_datetime,
        CAST(NULL AS int) AS run_duration,
        CAST(NULL AS nvarchar(4000)) AS message;
END CATCH;
