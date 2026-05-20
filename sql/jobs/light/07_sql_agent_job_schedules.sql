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
        SELECT
            j.name AS job_name,
            CONCAT('Schedule ', CONVERT(varchar(20), jsch.schedule_id)) AS schedule_name,
            CAST(NULL AS varchar(8)) AS schedule_status,
            CAST(NULL AS int) AS freq_type,
            CAST(NULL AS int) AS freq_interval,
            CAST(NULL AS varchar(5)) AS active_start_time,
            CASE
                WHEN jsch.next_run_date > 0 THEN
                    STUFF(STUFF(CONVERT(char(8), jsch.next_run_date), 5, 0, '-'), 8, 0, '-')
                    + ' '
                    + STUFF(LEFT(RIGHT('000000' + CONVERT(varchar(6), jsch.next_run_time), 6), 4), 3, 0, ':')
                ELSE NULL
            END AS next_run_datetime,
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
            CAST(NULL AS varchar(8)) AS schedule_status,
            CAST(NULL AS int) AS freq_type,
            CAST(NULL AS int) AS freq_interval,
            CAST(NULL AS varchar(5)) AS active_start_time,
            CAST(NULL AS varchar(16)) AS next_run_datetime,
            CAST('Limited msdb access: SQL Agent schedules cannot be read for this login.' AS nvarchar(4000)) AS access_note;
    END CATCH;
END CATCH;
