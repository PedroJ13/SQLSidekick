-- name: process_sql_objects
-- title: Process SQL objects
-- description: SQL objects detected from process step commands with detection confidence.
BEGIN TRY
    WITH step_commands AS (
        SELECT
            j.name AS process_name,
            j.job_id,
            js.step_id,
            js.step_name,
            js.database_name,
            js.subsystem,
            js.command,
            CASE
                WHEN PATINDEX('%execute %', LOWER(js.command)) > 0 THEN PATINDEX('%execute %', LOWER(js.command)) + 8
                WHEN PATINDEX('%exec %', LOWER(js.command)) > 0 THEN PATINDEX('%exec %', LOWER(js.command)) + 5
                ELSE 0
            END AS object_start
        FROM msdb.dbo.sysjobsteps AS js
        INNER JOIN msdb.dbo.sysjobs AS j
            ON j.job_id = js.job_id
        WHERE js.subsystem = 'TSQL'
    ),
    detected AS (
        SELECT
            process_name,
            job_id,
            step_id,
            step_name,
            database_name,
            LTRIM(RTRIM(
                REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                    LEFT(SUBSTRING(command, object_start, 4000), CHARINDEX(' ', SUBSTRING(command, object_start, 4000) + ' ') - 1),
                    '[', ''), ']', ''), ';', ''), CHAR(9), ''), CHAR(10), '')
            )) AS detected_object,
            LEFT(REPLACE(REPLACE(command, CHAR(13), ' '), CHAR(10), ' '), 500) AS command_preview
        FROM step_commands
        WHERE object_start > 0
    )
    SELECT
        process_name,
        job_id,
        step_id AS step_order,
        step_name,
        database_name,
        'Procedure' AS object_type,
        PARSENAME(detected_object, 3) AS referenced_database,
        PARSENAME(detected_object, 2) AS schema_name,
        PARSENAME(detected_object, 1) AS object_name,
        detected_object AS detected_object_text,
        'EXEC keyword' AS detection_method,
        CASE WHEN PARSENAME(detected_object, 2) IS NOT NULL THEN 'High' ELSE 'Medium' END AS confidence,
        command_preview
    FROM detected
    WHERE detected_object IS NOT NULL
      AND detected_object <> ''
      AND detected_object NOT LIKE '@%'
    ORDER BY process_name, step_id, detected_object;
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
            database_name sysname NULL,
            subsystem nvarchar(40),
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

                INSERT INTO #process_steps (process_name, job_id, step_id, step_name, database_name, subsystem, command)
                SELECT @job_name, @job_id, step_id, step_name, database_name, subsystem, command
                FROM #step_raw;
            END TRY
            BEGIN CATCH
                SET @job_name = @job_name;
            END CATCH;

            FETCH NEXT FROM job_cursor INTO @job_id, @job_name;
        END;

        CLOSE job_cursor;
        DEALLOCATE job_cursor;

        WITH step_commands AS (
            SELECT
                process_name,
                job_id,
                step_id,
                step_name,
                database_name,
                command,
                CASE
                    WHEN PATINDEX('%execute %', LOWER(command)) > 0 THEN PATINDEX('%execute %', LOWER(command)) + 8
                    WHEN PATINDEX('%exec %', LOWER(command)) > 0 THEN PATINDEX('%exec %', LOWER(command)) + 5
                    ELSE 0
                END AS object_start
            FROM #process_steps
            WHERE subsystem = 'TSQL'
        ),
        detected AS (
            SELECT
                process_name,
                job_id,
                step_id,
                step_name,
                database_name,
                LTRIM(RTRIM(
                    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                        LEFT(SUBSTRING(command, object_start, 4000), CHARINDEX(' ', SUBSTRING(command, object_start, 4000) + ' ') - 1),
                        '[', ''), ']', ''), ';', ''), CHAR(9), ''), CHAR(10), '')
                )) AS detected_object,
                LEFT(REPLACE(REPLACE(command, CHAR(13), ' '), CHAR(10), ' '), 500) AS command_preview
            FROM step_commands
            WHERE object_start > 0
        )
        SELECT
            process_name,
            job_id,
            step_id AS step_order,
            step_name,
            database_name,
            'Procedure' AS object_type,
            PARSENAME(detected_object, 3) AS referenced_database,
            PARSENAME(detected_object, 2) AS schema_name,
            PARSENAME(detected_object, 1) AS object_name,
            detected_object AS detected_object_text,
            'sp_help_jobstep + EXEC keyword' AS detection_method,
            CASE WHEN PARSENAME(detected_object, 2) IS NOT NULL THEN 'High' ELSE 'Medium' END AS confidence,
            command_preview
        FROM detected
        WHERE detected_object IS NOT NULL
          AND detected_object <> ''
          AND detected_object NOT LIKE '@%'
        ORDER BY process_name, step_id, detected_object;
    END TRY
    BEGIN CATCH
        SELECT
            ERROR_MESSAGE() AS process_name,
            CAST(NULL AS uniqueidentifier) AS job_id,
            CAST(NULL AS int) AS step_order,
            CAST(NULL AS sysname) AS step_name,
            CAST(NULL AS sysname) AS database_name,
            CAST(NULL AS varchar(20)) AS object_type,
            CAST(NULL AS sysname) AS referenced_database,
            CAST(NULL AS sysname) AS schema_name,
            CAST(NULL AS sysname) AS object_name,
            CAST(NULL AS nvarchar(512)) AS detected_object_text,
            CAST(NULL AS varchar(30)) AS detection_method,
            CAST(NULL AS varchar(10)) AS confidence,
            CAST(NULL AS nvarchar(500)) AS command_preview;
    END CATCH;
END CATCH;
