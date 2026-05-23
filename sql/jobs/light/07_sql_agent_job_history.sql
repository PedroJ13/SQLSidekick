-- name: sql_agent_job_history
-- title: SQL Agent job history
-- description: Recent SQL Server Agent job outcomes through msdb stored procedures for RDS/limited-permission compatibility.
BEGIN TRY
    EXEC msdb.dbo.sp_help_jobhistory @mode = N'SUMMARY';
END TRY
BEGIN CATCH
    SELECT
        ERROR_MESSAGE() AS job_name,
        CAST(NULL AS int) AS run_status,
        CAST(NULL AS int) AS run_date,
        CAST(NULL AS int) AS run_time,
        CAST(NULL AS int) AS run_duration,
        CAST(NULL AS int) AS retries_attempted,
        CAST(NULL AS sysname) AS server;
END CATCH;
