-- name: live_session_resource_usage
-- title: Top active sessions
-- description: Online view of active user sessions ordered by CPU, logical reads, writes, and elapsed time.
BEGIN TRY
    SELECT TOP (100)
        CASE
            WHEN request.cpu_time >= 300000
              OR request.logical_reads >= 1000000
              OR request.writes >= 100000
              OR request.total_elapsed_time >= 600000 THEN 'High'
            WHEN request.cpu_time >= 60000
              OR request.logical_reads >= 100000
              OR request.writes >= 10000
              OR request.total_elapsed_time >= 120000 THEN 'Medium'
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
        session.memory_usage * 8 AS memory_kb,
        request.open_transaction_count,
        request.wait_type,
        request.wait_time / 1000 AS wait_seconds,
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
    ORDER BY
        request.cpu_time DESC,
        request.logical_reads DESC,
        request.writes DESC,
        request.total_elapsed_time DESC;
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
        CAST(NULL AS int) AS memory_kb,
        CAST(NULL AS int) AS open_transaction_count,
        CAST(NULL AS nvarchar(60)) AS wait_type,
        CAST(NULL AS int) AS wait_seconds,
        CAST(NULL AS int) AS blocking_session_id,
        CAST(NULL AS nvarchar(128)) AS login_name,
        CAST(NULL AS nvarchar(128)) AS host_name,
        CAST(NULL AS nvarchar(128)) AS program_name,
        CAST(NULL AS nvarchar(max)) AS current_statement;
END CATCH;
