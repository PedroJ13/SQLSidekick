-- name: sql_agent_jobs
-- title: SQL Agent jobs
-- description: Light inventory of SQL Server Agent jobs through msdb stored procedures for RDS/limited-permission compatibility.
BEGIN TRY
    EXEC msdb.dbo.sp_help_job;
END TRY
BEGIN CATCH
    SELECT
        ERROR_MESSAGE() AS name,
        CAST(NULL AS bit) AS enabled,
        CAST(NULL AS sysname) AS owner,
        CAST(NULL AS sysname) AS category,
        CAST(NULL AS int) AS has_step,
        CAST(NULL AS int) AS has_schedule,
        CAST(NULL AS int) AS last_run_outcome;
END CATCH;
