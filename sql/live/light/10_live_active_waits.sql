-- name: live_active_waits
-- title: Active waits
-- description: Online view of user requests currently waiting.
BEGIN TRY
    SELECT TOP (100)
        CASE
            WHEN request.wait_time >= 300000 OR request.blocking_session_id <> 0 THEN 'High'
            WHEN request.wait_time >= 60000 THEN 'Medium'
            ELSE 'Low'
        END AS pressure_level,
        request.session_id,
        request.wait_type,
        request.wait_time / 1000 AS wait_seconds,
        DB_NAME(request.database_id) AS database_name,
        request.status,
        request.command,
        request.total_elapsed_time / 1000 AS elapsed_seconds,
        NULLIF(request.blocking_session_id, 0) AS blocking_session_id,
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
      AND request.wait_type IS NOT NULL
    ORDER BY request.wait_time DESC, request.total_elapsed_time DESC;
END TRY
BEGIN CATCH
    SELECT
        'Permission' AS pressure_level,
        ERROR_MESSAGE() AS session_id,
        CAST(NULL AS nvarchar(60)) AS wait_type,
        CAST(NULL AS int) AS wait_seconds,
        CAST(NULL AS sysname) AS database_name,
        CAST(NULL AS nvarchar(30)) AS status,
        CAST(NULL AS nvarchar(32)) AS command,
        CAST(NULL AS int) AS elapsed_seconds,
        CAST(NULL AS int) AS blocking_session_id,
        CAST(NULL AS nvarchar(128)) AS login_name,
        CAST(NULL AS nvarchar(128)) AS host_name,
        CAST(NULL AS nvarchar(128)) AS program_name,
        CAST(NULL AS nvarchar(max)) AS current_statement;
END CATCH;
