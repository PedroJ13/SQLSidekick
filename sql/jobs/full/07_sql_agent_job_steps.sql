-- name: sql_agent_job_steps
-- title: SQL Agent job steps
-- description: Full inventory of SQL Server Agent job steps without full command text.
BEGIN TRY
    SELECT
        j.name AS job_name,
        js.step_id,
        js.step_name,
        js.subsystem,
        js.database_name,
        js.database_user_name,
        js.proxy_id,
        js.cmdexec_success_code,
        js.on_success_action,
        js.on_success_step_id,
        js.on_fail_action,
        js.on_fail_step_id,
        js.retry_attempts,
        js.retry_interval,
        js.os_run_priority,
        js.output_file_name,
        LEN(js.command) AS command_length,
        LEFT(REPLACE(REPLACE(js.command, CHAR(13), ' '), CHAR(10), ' '), 300) AS command_preview
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
        CAST(NULL AS sysname) AS database_user_name,
        CAST(NULL AS int) AS proxy_id,
        CAST(NULL AS int) AS cmdexec_success_code,
        CAST(NULL AS int) AS on_success_action,
        CAST(NULL AS int) AS on_success_step_id,
        CAST(NULL AS int) AS on_fail_action,
        CAST(NULL AS int) AS on_fail_step_id,
        CAST(NULL AS int) AS retry_attempts,
        CAST(NULL AS int) AS retry_interval,
        CAST(NULL AS int) AS os_run_priority,
        CAST(NULL AS nvarchar(200)) AS output_file_name,
        CAST(NULL AS int) AS command_length,
        CAST(NULL AS nvarchar(300)) AS command_preview;
END CATCH;
