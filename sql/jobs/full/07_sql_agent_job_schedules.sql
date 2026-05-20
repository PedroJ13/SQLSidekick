-- name: sql_agent_job_schedules
-- title: SQL Agent job schedules
-- description: Full inventory of SQL Server Agent job schedules.
BEGIN TRY
    SELECT
        j.name AS job_name,
        s.name AS schedule_name,
        s.schedule_id,
        CASE WHEN s.enabled = 1 THEN 'Enabled' ELSE 'Disabled' END AS schedule_status,
        s.freq_type,
        s.freq_interval,
        s.freq_subday_type,
        s.freq_subday_interval,
        s.freq_relative_interval,
        s.freq_recurrence_factor,
        CASE WHEN s.active_start_date > 0 THEN STUFF(STUFF(CONVERT(char(8), s.active_start_date), 5, 0, '-'), 8, 0, '-') ELSE NULL END AS active_start_date,
        CASE WHEN s.active_end_date > 0 THEN STUFF(STUFF(CONVERT(char(8), s.active_end_date), 5, 0, '-'), 8, 0, '-') ELSE NULL END AS active_end_date,
        STUFF(LEFT(RIGHT('000000' + CONVERT(varchar(6), s.active_start_time), 6), 4), 3, 0, ':') AS active_start_time,
        STUFF(LEFT(RIGHT('000000' + CONVERT(varchar(6), s.active_end_time), 6), 4), 3, 0, ':') AS active_end_time,
        CASE
            WHEN jsch.next_run_date > 0 THEN
                STUFF(STUFF(CONVERT(char(8), jsch.next_run_date), 5, 0, '-'), 8, 0, '-')
                + ' '
                + STUFF(LEFT(RIGHT('000000' + CONVERT(varchar(6), jsch.next_run_time), 6), 4), 3, 0, ':')
            ELSE NULL
        END AS next_run_datetime,
        CONVERT(varchar(16), s.date_created, 120) AS create_date,
        CONVERT(varchar(16), s.date_modified, 120) AS modify_date,
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
        SELECT
            j.name AS job_name,
            CONCAT('Schedule ', CONVERT(varchar(20), jsch.schedule_id)) AS schedule_name,
            jsch.schedule_id,
            CAST(NULL AS varchar(8)) AS schedule_status,
            CAST(NULL AS int) AS freq_type,
            CAST(NULL AS int) AS freq_interval,
            CAST(NULL AS int) AS freq_subday_type,
            CAST(NULL AS int) AS freq_subday_interval,
            CAST(NULL AS int) AS freq_relative_interval,
            CAST(NULL AS int) AS freq_recurrence_factor,
            CAST(NULL AS varchar(10)) AS active_start_date,
            CAST(NULL AS varchar(10)) AS active_end_date,
            CAST(NULL AS varchar(5)) AS active_start_time,
            CAST(NULL AS varchar(5)) AS active_end_time,
            CASE
                WHEN jsch.next_run_date > 0 THEN
                    STUFF(STUFF(CONVERT(char(8), jsch.next_run_date), 5, 0, '-'), 8, 0, '-')
                    + ' '
                    + STUFF(LEFT(RIGHT('000000' + CONVERT(varchar(6), jsch.next_run_time), 6), 4), 3, 0, ':')
                ELSE NULL
            END AS next_run_datetime,
            CAST(NULL AS varchar(16)) AS create_date,
            CAST(NULL AS varchar(16)) AS modify_date,
            CAST('Limited msdb access: sysschedules is not available for this login.' AS nvarchar(4000)) AS access_note
        FROM msdb.dbo.sysjobs AS j
        INNER JOIN msdb.dbo.sysjobschedules AS jsch
            ON jsch.job_id = j.job_id
        ORDER BY j.name, jsch.schedule_id;
    END TRY
    BEGIN CATCH
        SELECT
            ERROR_MESSAGE() AS job_name,
            CAST(NULL AS sysname) AS schedule_name,
            CAST(NULL AS int) AS schedule_id,
            CAST(NULL AS varchar(8)) AS schedule_status,
            CAST(NULL AS int) AS freq_type,
            CAST(NULL AS int) AS freq_interval,
            CAST(NULL AS int) AS freq_subday_type,
            CAST(NULL AS int) AS freq_subday_interval,
            CAST(NULL AS int) AS freq_relative_interval,
            CAST(NULL AS int) AS freq_recurrence_factor,
            CAST(NULL AS varchar(10)) AS active_start_date,
            CAST(NULL AS varchar(10)) AS active_end_date,
            CAST(NULL AS varchar(5)) AS active_start_time,
            CAST(NULL AS varchar(5)) AS active_end_time,
            CAST(NULL AS varchar(16)) AS next_run_datetime,
            CAST(NULL AS varchar(16)) AS create_date,
            CAST(NULL AS varchar(16)) AS modify_date,
            CAST('Limited msdb access: SQL Agent schedules cannot be read for this login.' AS nvarchar(4000)) AS access_note;
    END CATCH;
END CATCH;
