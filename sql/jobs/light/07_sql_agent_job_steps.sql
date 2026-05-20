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

        CREATE TABLE #job_steps (
            job_name sysname,
            step_id int,
            step_name sysname,
            subsystem nvarchar(40),
            database_name sysname NULL,
            on_success_action tinyint,
            on_fail_action tinyint,
            command nvarchar(max)
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

                INSERT INTO #job_steps (job_name, step_id, step_name, subsystem, database_name, on_success_action, on_fail_action, command)
                SELECT @job_name, step_id, step_name, subsystem, database_name, on_success_action, on_fail_action, command
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
            job_name,
            step_id,
            step_name,
            subsystem,
            database_name,
            on_success_action,
            on_fail_action,
            LEN(command) AS command_length
        FROM #job_steps
        ORDER BY job_name, step_id;
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
END CATCH;
