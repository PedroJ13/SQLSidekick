-- name: sql_agent_job_steps
-- title: SQL Agent job steps
-- description: Light inventory of SQL Server Agent job steps without full command text.
BEGIN TRY
    SELECT
        j.name AS job_name,
        js.step_id,
        js.step_name,
        js.subsystem,
        js.database_name,
        js.on_success_action,
        js.on_fail_action,
        LEN(js.command) AS command_length
    FROM msdb.dbo.sysjobsteps AS js
    INNER JOIN msdb.dbo.sysjobs AS j
        ON j.job_id = js.job_id
    ORDER BY j.name, js.step_id;
END TRY
BEGIN CATCH
    SELECT
        ERROR_MESSAGE() AS job_name,
        CAST(NULL AS int) AS step_id,
        CAST(NULL AS sysname) AS step_name,
        CAST(NULL AS nvarchar(40)) AS subsystem,
        CAST(NULL AS sysname) AS database_name,
        CAST(NULL AS int) AS on_success_action,
        CAST(NULL AS int) AS on_fail_action,
        CAST(NULL AS int) AS command_length;
END CATCH;
