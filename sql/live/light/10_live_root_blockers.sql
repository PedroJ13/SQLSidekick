-- name: live_root_blockers
-- title: Root blockers
-- description: Online summary of sessions currently blocking other sessions.
BEGIN TRY
    SELECT TOP (50)
        CASE
            WHEN COUNT_BIG(*) >= 5 OR MAX(blocked.wait_time) >= 300000 THEN 'High'
            WHEN COUNT_BIG(*) >= 2 OR MAX(blocked.wait_time) >= 60000 THEN 'Medium'
            ELSE 'Low'
        END AS pressure_level,
        blocked.blocking_session_id,
        COUNT_BIG(*) AS blocked_session_count,
        MAX(blocked.wait_time / 1000) AS max_wait_seconds,
        MIN(blocked.wait_time / 1000) AS min_wait_seconds,
        blocker_session.login_name,
        blocker_session.host_name,
        blocker_session.program_name,
        blocker_request.status AS blocker_status,
        blocker_request.command AS blocker_command,
        DB_NAME(blocker_request.database_id) AS blocker_database_name,
        LEFT(REPLACE(REPLACE(blocker_sql.text, CHAR(13), ' '), CHAR(10), ' '), 1000) AS blocker_sql_text
    FROM sys.dm_exec_requests AS blocked
    LEFT JOIN sys.dm_exec_sessions AS blocker_session
        ON blocker_session.session_id = blocked.blocking_session_id
    LEFT JOIN sys.dm_exec_requests AS blocker_request
        ON blocker_request.session_id = blocked.blocking_session_id
    OUTER APPLY sys.dm_exec_sql_text(blocker_request.sql_handle) AS blocker_sql
    WHERE blocked.blocking_session_id <> 0
    GROUP BY
        blocked.blocking_session_id,
        blocker_session.login_name,
        blocker_session.host_name,
        blocker_session.program_name,
        blocker_request.status,
        blocker_request.command,
        blocker_request.database_id,
        blocker_sql.text
    ORDER BY blocked_session_count DESC, max_wait_seconds DESC;
END TRY
BEGIN CATCH
    SELECT
        'Permission' AS pressure_level,
        ERROR_MESSAGE() AS blocking_session_id,
        CAST(NULL AS bigint) AS blocked_session_count,
        CAST(NULL AS int) AS max_wait_seconds,
        CAST(NULL AS int) AS min_wait_seconds,
        CAST(NULL AS nvarchar(128)) AS login_name,
        CAST(NULL AS nvarchar(128)) AS host_name,
        CAST(NULL AS nvarchar(128)) AS program_name,
        CAST(NULL AS nvarchar(30)) AS blocker_status,
        CAST(NULL AS nvarchar(32)) AS blocker_command,
        CAST(NULL AS sysname) AS blocker_database_name,
        CAST(NULL AS nvarchar(max)) AS blocker_sql_text;
END CATCH;
