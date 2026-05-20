-- name: sql_agent_job_schedules
-- title: SQL Agent job schedules
-- description: Light inventory of SQL Server Agent job schedules.
BEGIN TRY
    SELECT
        j.name AS job_name,
        s.name AS schedule_name,
        CASE WHEN s.enabled = 1 THEN 'Enabled' ELSE 'Disabled' END AS schedule_status,
        s.freq_type,
        s.freq_interval,
        STUFF(LEFT(RIGHT('000000' + CONVERT(varchar(6), s.active_start_time), 6), 4), 3, 0, ':') AS active_start_time,
        CASE
            WHEN jsch.next_run_date > 0 THEN
                STUFF(STUFF(CONVERT(char(8), jsch.next_run_date), 5, 0, '-'), 8, 0, '-')
                + ' '
                + STUFF(LEFT(RIGHT('000000' + CONVERT(varchar(6), jsch.next_run_time), 6), 4), 3, 0, ':')
            ELSE NULL
        END AS next_run_datetime,
        CAST(NULL AS nvarchar(4000)) AS access_note
    FROM msdb.dbo.sysjobs AS j
    INNER JOIN msdb.dbo.sysjobschedules AS jsch
        ON jsch.job_id = j.job_id
    INNER JOIN msdb.dbo.sysschedules AS s
        ON s.schedule_id = jsch.schedule_id
    ORDER BY j.name, s.name;
END TRY
BEGIN CATCH
    BEGIN TRY
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

        CREATE TABLE #job_schedules (
            job_name sysname,
            schedule_id int,
            schedule_name sysname,
            enabled int,
            freq_type int,
            freq_interval int,
            active_start_time int,
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
                DELETE FROM #schedule_raw;
                INSERT INTO #schedule_raw
                EXEC msdb.dbo.sp_help_jobschedule @job_id = @job_id, @include_description = 0;

                INSERT INTO #job_schedules (
                    job_name,
                    schedule_id,
                    schedule_name,
                    enabled,
                    freq_type,
                    freq_interval,
                    active_start_time,
                    next_run_date,
                    next_run_time
                )
                SELECT
                    @job_name,
                    schedule_id,
                    schedule_name,
                    enabled,
                    freq_type,
                    freq_interval,
                    active_start_time,
                    next_run_date,
                    next_run_time
                FROM #schedule_raw;
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
            schedule_name,
            CASE WHEN enabled = 1 THEN 'Enabled' ELSE 'Disabled' END AS schedule_status,
            freq_type,
            freq_interval,
            STUFF(LEFT(RIGHT('000000' + CONVERT(varchar(6), active_start_time), 6), 4), 3, 0, ':') AS active_start_time,
            CASE
                WHEN next_run_date > 0 THEN
                    STUFF(STUFF(CONVERT(char(8), next_run_date), 5, 0, '-'), 8, 0, '-')
                    + ' '
                    + STUFF(LEFT(RIGHT('000000' + CONVERT(varchar(6), next_run_time), 6), 4), 3, 0, ':')
                ELSE NULL
            END AS next_run_datetime,
            CAST('Loaded with msdb.dbo.sp_help_jobschedule because direct msdb schedule tables are not available.' AS nvarchar(4000)) AS access_note
        FROM #job_schedules
        ORDER BY job_name, schedule_name;
    END TRY
    BEGIN CATCH
        SELECT
            ERROR_MESSAGE() AS job_name,
            CAST(NULL AS sysname) AS schedule_name,
            CAST(NULL AS varchar(8)) AS schedule_status,
            CAST(NULL AS int) AS freq_type,
            CAST(NULL AS int) AS freq_interval,
            CAST(NULL AS varchar(5)) AS active_start_time,
            CAST(NULL AS varchar(16)) AS next_run_datetime,
            CAST('Limited msdb access: SQL Agent schedules cannot be read for this login.' AS nvarchar(4000)) AS access_note;
    END CATCH;
END CATCH;
