-- name: live_blocking
-- title: Blocking now
-- description: Online view of sessions currently blocked by another session.
BEGIN TRY
    SELECT TOP (100)
        CASE
            WHEN blocked.wait_time >= 300000 THEN 'High'
            WHEN blocked.wait_time >= 60000 THEN 'Medium'
            ELSE 'Low'
        END AS pressure_level,
        blocked.session_id,
        blocked.blocking_session_id,
        blocked.wait_type,
        blocked.wait_time / 1000 AS wait_seconds,
        blocked.status,
        blocked.command,
        DB_NAME(blocked.database_id) AS database_name,
        blocked_session.login_name,
        blocked_session.host_name,
        blocked_session.program_name,
        blocker_session.login_name AS blocker_login_name,
        blocker_session.host_name AS blocker_host_name,
        blocker_session.program_name AS blocker_program_name,
        LEFT(REPLACE(REPLACE(blocked_sql.text, CHAR(13), ' '), CHAR(10), ' '), 1000) AS blocked_sql_text,
        LEFT(REPLACE(REPLACE(blocker_sql.text, CHAR(13), ' '), CHAR(10), ' '), 1000) AS blocker_sql_text
    FROM sys.dm_exec_requests AS blocked
    INNER JOIN sys.dm_exec_sessions AS blocked_session
        ON blocked_session.session_id = blocked.session_id
    LEFT JOIN sys.dm_exec_sessions AS blocker_session
        ON blocker_session.session_id = blocked.blocking_session_id
    LEFT JOIN sys.dm_exec_requests AS blocker_request
        ON blocker_request.session_id = blocked.blocking_session_id
    OUTER APPLY sys.dm_exec_sql_text(blocked.sql_handle) AS blocked_sql
    OUTER APPLY sys.dm_exec_sql_text(blocker_request.sql_handle) AS blocker_sql
    WHERE blocked.blocking_session_id <> 0
    ORDER BY blocked.wait_time DESC, blocked.session_id;
END TRY
BEGIN CATCH
    SELECT
        'Permission' AS pressure_level,
        ERROR_MESSAGE() AS session_id,
        CAST(NULL AS int) AS blocking_session_id,
        CAST(NULL AS nvarchar(60)) AS wait_type,
        CAST(NULL AS int) AS wait_seconds,
        CAST(NULL AS nvarchar(30)) AS status,
        CAST(NULL AS nvarchar(32)) AS command,
        CAST(NULL AS sysname) AS database_name,
        CAST(NULL AS nvarchar(128)) AS login_name,
        CAST(NULL AS nvarchar(128)) AS host_name,
        CAST(NULL AS nvarchar(128)) AS program_name,
        CAST(NULL AS nvarchar(128)) AS blocker_login_name,
        CAST(NULL AS nvarchar(128)) AS blocker_host_name,
        CAST(NULL AS nvarchar(128)) AS blocker_program_name,
        CAST(NULL AS nvarchar(max)) AS blocked_sql_text,
        CAST(NULL AS nvarchar(max)) AS blocker_sql_text;
END CATCH;
