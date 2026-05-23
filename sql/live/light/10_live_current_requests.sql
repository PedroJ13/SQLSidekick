-- name: live_current_requests
-- title: Current requests
-- description: Online view of currently running user requests, sorted by elapsed time and resource usage.
BEGIN TRY
    SELECT TOP (100)
        CASE
            WHEN request.blocking_session_id <> 0 THEN 'High'
            WHEN request.total_elapsed_time >= 300000 OR request.wait_time >= 60000 THEN 'Medium'
            ELSE 'Low'
        END AS pressure_level,
        request.session_id,
        DB_NAME(request.database_id) AS database_name,
        request.status AS request_status,
        request.command,
        request.total_elapsed_time / 1000 AS elapsed_seconds,
        CONVERT(decimal(19,2), request.cpu_time / 1000.0) AS cpu_seconds,
        request.logical_reads,
        request.reads,
        request.writes,
        request.wait_type,
        request.wait_time / 1000 AS wait_seconds,
        NULLIF(request.blocking_session_id, 0) AS blocking_session_id,
        CONVERT(decimal(9,2), request.percent_complete) AS percent_complete,
        session.login_name,
        session.host_name,
        session.program_name,
        LEFT(REPLACE(REPLACE(
            SUBSTRING(
                sql_text.text,
                (request.statement_start_offset / 2) + 1,
                CASE request.statement_end_offset
                    WHEN -1 THEN LEN(CONVERT(nvarchar(max), sql_text.text))
                    ELSE (request.statement_end_offset - request.statement_start_offset) / 2 + 1
                END
            ),
            CHAR(13), ' '), CHAR(10), ' '), 1000) AS current_statement
    FROM sys.dm_exec_requests AS request
    INNER JOIN sys.dm_exec_sessions AS session
        ON session.session_id = request.session_id
    OUTER APPLY sys.dm_exec_sql_text(request.sql_handle) AS sql_text
    WHERE request.session_id <> @@SPID
      AND session.is_user_process = 1
    ORDER BY
        request.total_elapsed_time DESC,
        request.cpu_time DESC,
        request.logical_reads DESC;
END TRY
BEGIN CATCH
    SELECT
        'Permission' AS pressure_level,
        ERROR_MESSAGE() AS session_id,
        CAST(NULL AS sysname) AS database_name,
        CAST(NULL AS nvarchar(30)) AS request_status,
        CAST(NULL AS nvarchar(32)) AS command,
        CAST(NULL AS int) AS elapsed_seconds,
        CAST(NULL AS decimal(19,2)) AS cpu_seconds,
        CAST(NULL AS bigint) AS logical_reads,
        CAST(NULL AS bigint) AS reads,
        CAST(NULL AS bigint) AS writes,
        CAST(NULL AS nvarchar(60)) AS wait_type,
        CAST(NULL AS int) AS wait_seconds,
        CAST(NULL AS int) AS blocking_session_id,
        CAST(NULL AS decimal(9,2)) AS percent_complete,
        CAST(NULL AS nvarchar(128)) AS login_name,
        CAST(NULL AS nvarchar(128)) AS host_name,
        CAST(NULL AS nvarchar(128)) AS program_name,
        CAST(NULL AS nvarchar(max)) AS current_statement;
END CATCH;
