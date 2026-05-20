-- name: sql_agent_jobs
-- title: SQL Agent jobs
-- description: Light inventory of SQL Server Agent jobs with status, owner, category, and counts.
BEGIN TRY
    SELECT
        j.name AS job_name,
        CASE WHEN j.enabled = 1 THEN 'Enabled' ELSE 'Disabled' END AS job_status,
        SUSER_SNAME(j.owner_sid) AS owner_name,
        c.name AS category_name,
        CONVERT(varchar(16), j.date_created, 120) AS create_date,
        CONVERT(varchar(16), j.date_modified, 120) AS modify_date,
        COUNT(DISTINCT js.step_id) AS step_count,
        COUNT(DISTINCT jsch.schedule_id) AS schedule_count
    FROM msdb.dbo.sysjobs AS j
    LEFT JOIN msdb.dbo.syscategories AS c
        ON c.category_id = j.category_id
    LEFT JOIN msdb.dbo.sysjobsteps AS js
        ON js.job_id = j.job_id
    LEFT JOIN msdb.dbo.sysjobschedules AS jsch
        ON jsch.job_id = j.job_id
    GROUP BY
        j.name,
        j.enabled,
        j.owner_sid,
        c.name,
        j.date_created,
        j.date_modified
    ORDER BY j.enabled DESC, j.name;
END TRY
BEGIN CATCH
    SELECT
        ERROR_MESSAGE() AS job_name,
        CAST(NULL AS varchar(8)) AS job_status,
        CAST(NULL AS sysname) AS owner_name,
        CAST(NULL AS sysname) AS category_name,
        CAST(NULL AS varchar(16)) AS create_date,
        CAST(NULL AS varchar(16)) AS modify_date,
        CAST(NULL AS int) AS step_count,
        CAST(NULL AS int) AS schedule_count;
END CATCH;
