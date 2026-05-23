-- name: live_tempdb_usage
-- title: TempDB usage by session
-- description: Online view of current user sessions consuming TempDB space.
BEGIN TRY
    SELECT TOP (100)
        CASE
            WHEN CONVERT(decimal(19,2), (
                usage.user_objects_alloc_page_count
                + usage.internal_objects_alloc_page_count
                - usage.user_objects_dealloc_page_count
                - usage.internal_objects_dealloc_page_count
            ) / 128.0) >= 1024 THEN 'High'
            WHEN CONVERT(decimal(19,2), (
                usage.user_objects_alloc_page_count
                + usage.internal_objects_alloc_page_count
                - usage.user_objects_dealloc_page_count
                - usage.internal_objects_dealloc_page_count
            ) / 128.0) >= 256 THEN 'Medium'
            ELSE 'Low'
        END AS pressure_level,
        usage.session_id,
        CONVERT(decimal(19,2), (
            usage.user_objects_alloc_page_count
            + usage.internal_objects_alloc_page_count
            - usage.user_objects_dealloc_page_count
            - usage.internal_objects_dealloc_page_count
        ) / 128.0) AS total_net_mb,
        CONVERT(decimal(19,2), (usage.user_objects_alloc_page_count - usage.user_objects_dealloc_page_count) / 128.0) AS user_objects_net_mb,
        CONVERT(decimal(19,2), (usage.internal_objects_alloc_page_count - usage.internal_objects_dealloc_page_count) / 128.0) AS internal_objects_net_mb,
        DB_NAME(request.database_id) AS database_name,
        session.login_name,
        session.host_name,
        session.program_name,
        request.status,
        request.command,
        request.total_elapsed_time / 1000 AS elapsed_seconds,
        LEFT(REPLACE(REPLACE(sql_text.text, CHAR(13), ' '), CHAR(10), ' '), 1000) AS sql_text
    FROM sys.dm_db_session_space_usage AS usage
    INNER JOIN sys.dm_exec_sessions AS session
        ON session.session_id = usage.session_id
    LEFT JOIN sys.dm_exec_requests AS request
        ON request.session_id = usage.session_id
    OUTER APPLY sys.dm_exec_sql_text(request.sql_handle) AS sql_text
    WHERE usage.session_id <> @@SPID
      AND session.is_user_process = 1
      AND (
          usage.user_objects_alloc_page_count
          + usage.internal_objects_alloc_page_count
          - usage.user_objects_dealloc_page_count
          - usage.internal_objects_dealloc_page_count
      ) > 0
    ORDER BY total_net_mb DESC;
END TRY
BEGIN CATCH
    SELECT
        'Permission' AS pressure_level,
        ERROR_MESSAGE() AS session_id,
        CAST(NULL AS decimal(19,2)) AS total_net_mb,
        CAST(NULL AS decimal(19,2)) AS user_objects_net_mb,
        CAST(NULL AS decimal(19,2)) AS internal_objects_net_mb,
        CAST(NULL AS sysname) AS database_name,
        CAST(NULL AS nvarchar(128)) AS login_name,
        CAST(NULL AS nvarchar(128)) AS host_name,
        CAST(NULL AS nvarchar(128)) AS program_name,
        CAST(NULL AS nvarchar(30)) AS status,
        CAST(NULL AS nvarchar(32)) AS command,
        CAST(NULL AS int) AS elapsed_seconds,
        CAST(NULL AS nvarchar(max)) AS sql_text;
END CATCH;
