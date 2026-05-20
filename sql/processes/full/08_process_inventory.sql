-- name: process_inventory
-- title: Inventory
-- description: Full process inventory based on SQL Agent jobs, schedules, ownership, steps, and recent outcomes.
BEGIN TRY
    WITH last_runs AS (
        SELECT
            h.job_id,
            h.run_status,
            h.run_date,
            h.run_time,
            h.run_duration,
            h.message,
            ROW_NUMBER() OVER (PARTITION BY h.job_id ORDER BY h.run_date DESC, h.run_time DESC, h.instance_id DESC) AS rn
        FROM msdb.dbo.sysjobhistory AS h
        WHERE h.step_id = 0
    ),
    step_summary AS (
        SELECT
            js.job_id,
            COUNT(*) AS step_count,
            SUM(CASE WHEN js.subsystem = 'TSQL' THEN 1 ELSE 0 END) AS tsql_step_count,
            SUM(CASE WHEN js.subsystem <> 'TSQL' THEN 1 ELSE 0 END) AS external_step_count,
            SUM(CASE WHEN js.subsystem = 'TSQL' AND (LOWER(js.command) LIKE '%exec %' OR LOWER(js.command) LIKE '%execute %') THEN 1 ELSE 0 END) AS detected_procedure_count
        FROM msdb.dbo.sysjobsteps AS js
        GROUP BY js.job_id
    ),
    schedule_summary AS (
        SELECT
            jsch.job_id,
            COUNT(*) AS schedule_count,
            MIN(CASE
                WHEN jsch.next_run_date > 0 THEN
                    STUFF(STUFF(CONVERT(char(8), jsch.next_run_date), 5, 0, '-'), 8, 0, '-')
                    + ' '
                    + STUFF(LEFT(RIGHT('000000' + CONVERT(varchar(6), jsch.next_run_time), 6), 4), 3, 0, ':')
                ELSE NULL
            END) AS next_run_datetime
        FROM msdb.dbo.sysjobschedules AS jsch
        GROUP BY jsch.job_id
    )
    SELECT
        j.name AS process_name,
        j.job_id,
        CASE WHEN j.enabled = 1 THEN 'Enabled' ELSE 'Disabled' END AS process_status,
        SUSER_SNAME(j.owner_sid) AS owner_name,
        c.name AS category_name,
        j.description,
        COALESCE(ss.schedule_count, 0) AS schedule_count,
        ss.next_run_datetime,
        COALESCE(st.step_count, 0) AS step_count,
        COALESCE(st.tsql_step_count, 0) AS tsql_step_count,
        COALESCE(st.external_step_count, 0) AS external_step_count,
        CASE lr.run_status
            WHEN 0 THEN 'Failed'
            WHEN 1 THEN 'Succeeded'
            WHEN 2 THEN 'Retry'
            WHEN 3 THEN 'Canceled'
            WHEN 4 THEN 'In Progress'
            ELSE 'Unknown'
        END AS last_run_status,
        CASE
            WHEN lr.run_date > 0 THEN
                STUFF(STUFF(CONVERT(char(8), lr.run_date), 5, 0, '-'), 8, 0, '-')
                + ' '
                + STUFF(LEFT(RIGHT('000000' + CONVERT(varchar(6), lr.run_time), 6), 4), 3, 0, ':')
            ELSE NULL
        END AS last_run_datetime,
        lr.run_duration AS last_run_duration,
        LEFT(lr.message, 500) AS last_run_message,
        COALESCE(st.detected_procedure_count, 0) AS detected_procedure_count,
        CASE
            WHEN COALESCE(st.detected_procedure_count, 0) > 0 THEN 'Medium'
            WHEN COALESCE(st.step_count, 0) > 0 THEN 'Low'
            ELSE 'Unknown'
        END AS confidence,
        CONVERT(varchar(16), j.date_created, 120) AS create_date,
        CONVERT(varchar(16), j.date_modified, 120) AS modify_date
    FROM msdb.dbo.sysjobs AS j
    LEFT JOIN msdb.dbo.syscategories AS c
        ON c.category_id = j.category_id
    LEFT JOIN step_summary AS st
        ON st.job_id = j.job_id
    LEFT JOIN schedule_summary AS ss
        ON ss.job_id = j.job_id
    LEFT JOIN last_runs AS lr
        ON lr.job_id = j.job_id
       AND lr.rn = 1
    ORDER BY j.enabled DESC, j.name;
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
            job_id uniqueidentifier,
            subsystem nvarchar(40),
            command nvarchar(max)
        );

        CREATE TABLE #schedule_raw (
            schedule_id int,
            schedule_name sysname,
            enabled int,
            freq_type int,
            freq_interval int,
            freq_subday_type int,
            freq_subday_interval int,
            freq_relative_interval int,
            freq_recurrence_factor int,
            active_start_date int,
            active_end_date int,
            active_start_time int,
            active_end_time int,
            date_created datetime,
            schedule_description nvarchar(4000),
            next_run_date int,
            next_run_time int,
            schedule_uid uniqueidentifier,
            job_count int
        );

        CREATE TABLE #process_schedules (
            job_id uniqueidentifier,
            schedule_id int,
            next_run_date int,
            next_run_time int
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

                INSERT INTO #process_steps (job_id, subsystem, command)
                SELECT @job_id, subsystem, command
                FROM #step_raw;

                DELETE FROM #schedule_raw;
                INSERT INTO #schedule_raw
                EXEC msdb.dbo.sp_help_jobschedule @job_id = @job_id, @include_description = 0;

                INSERT INTO #process_schedules (job_id, schedule_id, next_run_date, next_run_time)
                SELECT @job_id, schedule_id, next_run_date, next_run_time
                FROM #schedule_raw;
            END TRY
            BEGIN CATCH
                SET @job_name = @job_name;
            END CATCH;

            FETCH NEXT FROM job_cursor INTO @job_id, @job_name;
        END;

        CLOSE job_cursor;
        DEALLOCATE job_cursor;

        WITH last_runs AS (
            SELECT
                h.job_id,
                h.run_status,
                h.run_date,
                h.run_time,
                h.run_duration,
                h.message,
                ROW_NUMBER() OVER (PARTITION BY h.job_id ORDER BY h.run_date DESC, h.run_time DESC, h.instance_id DESC) AS rn
            FROM msdb.dbo.sysjobhistory AS h
            WHERE h.step_id = 0
        ),
        step_summary AS (
            SELECT
                job_id,
                COUNT(*) AS step_count,
                SUM(CASE WHEN subsystem = 'TSQL' THEN 1 ELSE 0 END) AS tsql_step_count,
                SUM(CASE WHEN subsystem <> 'TSQL' THEN 1 ELSE 0 END) AS external_step_count,
                SUM(CASE WHEN subsystem = 'TSQL' AND (LOWER(command) LIKE '%exec %' OR LOWER(command) LIKE '%execute %') THEN 1 ELSE 0 END) AS detected_procedure_count
            FROM #process_steps
            GROUP BY job_id
        ),
        schedule_summary AS (
            SELECT
                ps.job_id,
                COUNT(*) AS schedule_count,
                MIN(CASE
                    WHEN ps.next_run_date > 0 THEN
                        STUFF(STUFF(CONVERT(char(8), ps.next_run_date), 5, 0, '-'), 8, 0, '-')
                        + ' '
                        + STUFF(LEFT(RIGHT('000000' + CONVERT(varchar(6), ps.next_run_time), 6), 4), 3, 0, ':')
                    ELSE NULL
                END) AS next_run_datetime
            FROM #process_schedules AS ps
            GROUP BY ps.job_id
        )
        SELECT
            j.name AS process_name,
            j.job_id,
            CASE WHEN j.enabled = 1 THEN 'Enabled' ELSE 'Disabled' END AS process_status,
            SUSER_SNAME(j.owner_sid) AS owner_name,
            c.name AS category_name,
            j.description,
            COALESCE(ss.schedule_count, 0) AS schedule_count,
            ss.next_run_datetime,
            COALESCE(st.step_count, 0) AS step_count,
            COALESCE(st.tsql_step_count, 0) AS tsql_step_count,
            COALESCE(st.external_step_count, 0) AS external_step_count,
            CASE lr.run_status
                WHEN 0 THEN 'Failed'
                WHEN 1 THEN 'Succeeded'
                WHEN 2 THEN 'Retry'
                WHEN 3 THEN 'Canceled'
                WHEN 4 THEN 'In Progress'
                ELSE 'Unknown'
            END AS last_run_status,
            CASE
                WHEN lr.run_date > 0 THEN
                    STUFF(STUFF(CONVERT(char(8), lr.run_date), 5, 0, '-'), 8, 0, '-')
                    + ' '
                    + STUFF(LEFT(RIGHT('000000' + CONVERT(varchar(6), lr.run_time), 6), 4), 3, 0, ':')
                ELSE NULL
            END AS last_run_datetime,
            lr.run_duration AS last_run_duration,
            LEFT(lr.message, 500) AS last_run_message,
            COALESCE(st.detected_procedure_count, 0) AS detected_procedure_count,
            CASE
                WHEN COALESCE(st.detected_procedure_count, 0) > 0 THEN 'Medium'
                WHEN COALESCE(st.step_count, 0) > 0 THEN 'Low'
                ELSE 'Unknown'
            END AS confidence,
            CONVERT(varchar(16), j.date_created, 120) AS create_date,
            CONVERT(varchar(16), j.date_modified, 120) AS modify_date
        FROM msdb.dbo.sysjobs AS j
        LEFT JOIN msdb.dbo.syscategories AS c
            ON c.category_id = j.category_id
        LEFT JOIN step_summary AS st
            ON st.job_id = j.job_id
        LEFT JOIN schedule_summary AS ss
            ON ss.job_id = j.job_id
        LEFT JOIN last_runs AS lr
            ON lr.job_id = j.job_id
           AND lr.rn = 1
        ORDER BY j.enabled DESC, j.name;
    END TRY
    BEGIN CATCH
        SELECT
            ERROR_MESSAGE() AS process_name,
            CAST(NULL AS uniqueidentifier) AS job_id,
            CAST(NULL AS varchar(8)) AS process_status,
            CAST(NULL AS sysname) AS owner_name,
            CAST(NULL AS sysname) AS category_name,
            CAST(NULL AS nvarchar(512)) AS description,
            CAST(NULL AS int) AS schedule_count,
            CAST(NULL AS varchar(16)) AS next_run_datetime,
            CAST(NULL AS int) AS step_count,
            CAST(NULL AS int) AS tsql_step_count,
            CAST(NULL AS int) AS external_step_count,
            CAST(NULL AS varchar(12)) AS last_run_status,
            CAST(NULL AS varchar(16)) AS last_run_datetime,
            CAST(NULL AS int) AS last_run_duration,
            CAST(NULL AS nvarchar(500)) AS last_run_message,
            CAST(NULL AS int) AS detected_procedure_count,
            CAST(NULL AS varchar(10)) AS confidence,
            CAST(NULL AS varchar(16)) AS create_date,
            CAST(NULL AS varchar(16)) AS modify_date;
    END CATCH;
END CATCH;
