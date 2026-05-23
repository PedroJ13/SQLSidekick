-- name: sql_agent_jobs
-- title: SQL Agent jobs
-- description: Full inventory of SQL Server Agent jobs through msdb stored procedures for RDS/limited-permission compatibility.
BEGIN TRY
    EXEC msdb.dbo.sp_help_job;
END TRY
BEGIN CATCH
    SELECT
        ERROR_MESSAGE() AS name,
        CAST(NULL AS uniqueidentifier) AS job_id,
        CAST(NULL AS sysname) AS originating_server,
        CAST(NULL AS bit) AS enabled,
        CAST(NULL AS nvarchar(512)) AS description,
        CAST(NULL AS int) AS start_step_id,
        CAST(NULL AS sysname) AS category,
        CAST(NULL AS sysname) AS owner,
        CAST(NULL AS int) AS last_run_outcome,
        CAST(NULL AS int) AS current_execution_status,
        CAST(NULL AS int) AS has_step,
        CAST(NULL AS int) AS has_schedule;
END CATCH;
