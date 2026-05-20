-- name: process_steps
-- title: Steps
-- description: Light process step inventory based on SQL Agent job steps.
BEGIN TRY
    SELECT
        j.name AS process_name,
        js.step_id AS step_order,
        js.step_name,
        js.subsystem,
        js.database_name AS database_name,
        CASE
            WHEN js.subsystem = 'TSQL' AND (LOWER(js.command) LIKE '%exec %' OR LOWER(js.command) LIKE '%execute %') THEN 'Procedure call'
            WHEN js.subsystem = 'TSQL' THEN 'T-SQL batch'
            ELSE js.subsystem
        END AS command_type,
        CASE js.on_success_action
            WHEN 1 THEN 'Quit with success'
            WHEN 2 THEN 'Quit with failure'
            WHEN 3 THEN 'Go to next step'
            WHEN 4 THEN 'Go to step'
            ELSE 'Unknown'
        END AS on_success_action,
        CASE js.on_fail_action
            WHEN 1 THEN 'Quit with success'
            WHEN 2 THEN 'Quit with failure'
            WHEN 3 THEN 'Go to next step'
            WHEN 4 THEN 'Go to step'
            ELSE 'Unknown'
        END AS on_fail_action,
        js.retry_attempts,
        LEFT(REPLACE(REPLACE(js.command, CHAR(13), ' '), CHAR(10), ' '), 180) AS command_preview
    FROM msdb.dbo.sysjobsteps AS js
    INNER JOIN msdb.dbo.sysjobs AS j
        ON j.job_id = js.job_id
    ORDER BY j.name, js.step_id;
END TRY
BEGIN CATCH
    BEGIN TRY
        CREATE TABLE #step_raw (
            step_id int,
            step_name sysname,
            subsystem nvarchar(40),
            command nvarchar(max),
            flags int,
            cmdexec_success_code int,
            on_success_action tinyint,
            on_success_step_id int,
            on_fail_action tinyint,
            on_fail_step_id int,
            server sysname NULL,
            database_name sysname NULL,
            database_user_name sysname NULL,
            retry_attempts int,
            retry_interval int,
            os_run_priority int,
            output_file_name nvarchar(200) NULL,
            last_run_outcome int,
            last_run_duration int,
            last_run_retries int,
            last_run_date int,
            last_run_time int,
            proxy_id int NULL
        );

        CREATE TABLE #process_steps (
            process_name sysname,
            job_id uniqueidentifier,
            step_id int,
            step_name sysname,
            subsystem nvarchar(40),
            command nvarchar(max),
            on_success_action tinyint,
            on_fail_action tinyint,
            database_name sysname NULL,
            retry_attempts int
        );

        DECLARE @job_id uniqueidentifier;
        DECLARE @job_name sysname;

        DECLARE job_cursor CURSOR LOCAL FAST_FORWARD FOR
            SELECT job_id, name
            FROM msdb.dbo.sysjobs
            ORDER BY name;

        OPEN job_cursor;
        FETCH NEXT FROM job_cursor INTO @job_id, @job_name;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            BEGIN TRY
                DELETE FROM #step_raw;
                INSERT INTO #step_raw
                EXEC msdb.dbo.sp_help_jobstep @job_id = @job_id;

                INSERT INTO #process_steps (
                    process_name,
                    job_id,
                    step_id,
                    step_name,
                    subsystem,
                    command,
                    on_success_action,
                    on_fail_action,
                    database_name,
                    retry_attempts
                )
                SELECT
                    @job_name,
                    @job_id,
                    step_id,
                    step_name,
                    subsystem,
                    command,
                    on_success_action,
                    on_fail_action,
                    database_name,
                    retry_attempts
                FROM #step_raw;
            END TRY
            BEGIN CATCH
                SET @job_name = @job_name;
            END CATCH;

            FETCH NEXT FROM job_cursor INTO @job_id, @job_name;
        END;

        CLOSE job_cursor;
        DEALLOCATE job_cursor;

        SELECT
            process_name,
            step_id AS step_order,
            step_name,
            subsystem,
            database_name,
            CASE
                WHEN subsystem = 'TSQL' AND (LOWER(command) LIKE '%exec %' OR LOWER(command) LIKE '%execute %') THEN 'Procedure call'
                WHEN subsystem = 'TSQL' THEN 'T-SQL batch'
                ELSE subsystem
            END AS command_type,
            CASE on_success_action
                WHEN 1 THEN 'Quit with success'
                WHEN 2 THEN 'Quit with failure'
                WHEN 3 THEN 'Go to next step'
                WHEN 4 THEN 'Go to step'
                ELSE 'Unknown'
            END AS on_success_action,
            CASE on_fail_action
                WHEN 1 THEN 'Quit with success'
                WHEN 2 THEN 'Quit with failure'
                WHEN 3 THEN 'Go to next step'
                WHEN 4 THEN 'Go to step'
                ELSE 'Unknown'
            END AS on_fail_action,
            retry_attempts,
            LEFT(REPLACE(REPLACE(command, CHAR(13), ' '), CHAR(10), ' '), 180) AS command_preview
        FROM #process_steps
        ORDER BY process_name, step_id;
    END TRY
    BEGIN CATCH
        SELECT
            ERROR_MESSAGE() AS process_name,
            CAST(NULL AS int) AS step_order,
            CAST(NULL AS sysname) AS step_name,
            CAST(NULL AS nvarchar(40)) AS subsystem,
            CAST(NULL AS sysname) AS database_name,
            CAST(NULL AS varchar(20)) AS command_type,
            CAST(NULL AS varchar(20)) AS on_success_action,
            CAST(NULL AS varchar(20)) AS on_fail_action,
            CAST(NULL AS int) AS retry_attempts,
            CAST(NULL AS nvarchar(180)) AS command_preview;
    END CATCH;
END CATCH;
