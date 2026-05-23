-- name: live_dashboard
-- title: Live dashboard
-- description: Online KPI summary for current database activity, blocking, waits, TempDB usage, and transaction log pressure.
BEGIN TRY
    DECLARE @active_requests int = 0;
    DECLARE @long_running_requests int = 0;
    DECLARE @active_waits int = 0;
    DECLARE @blocked_sessions int = 0;
    DECLARE @root_blockers int = 0;
    DECLARE @tempdb_sessions int = 0;
    DECLARE @max_tempdb_mb decimal(19,2) = 0;
    DECLARE @log_used_percent decimal(9,2) = NULL;

    SELECT
        @active_requests = COUNT(*),
        @long_running_requests = ISNULL(SUM(CASE WHEN request.total_elapsed_time >= 300000 THEN 1 ELSE 0 END), 0),
        @active_waits = ISNULL(SUM(CASE WHEN request.wait_type IS NOT NULL THEN 1 ELSE 0 END), 0),
        @blocked_sessions = ISNULL(SUM(CASE WHEN request.blocking_session_id <> 0 THEN 1 ELSE 0 END), 0),
        @root_blockers = COUNT(DISTINCT NULLIF(request.blocking_session_id, 0))
    FROM sys.dm_exec_requests AS request
    INNER JOIN sys.dm_exec_sessions AS session_info
        ON session_info.session_id = request.session_id
    WHERE request.session_id <> @@SPID
      AND session_info.is_user_process = 1;

    SELECT
        @tempdb_sessions = COUNT(*),
        @max_tempdb_mb = ISNULL(MAX(CONVERT(decimal(19,2), (
            usage_info.user_objects_alloc_page_count
            + usage_info.internal_objects_alloc_page_count
            - usage_info.user_objects_dealloc_page_count
            - usage_info.internal_objects_dealloc_page_count
        ) / 128.0)), 0)
    FROM sys.dm_db_session_space_usage AS usage_info
    INNER JOIN sys.dm_exec_sessions AS session_info
        ON session_info.session_id = usage_info.session_id
    WHERE usage_info.session_id <> @@SPID
      AND session_info.is_user_process = 1
      AND (
          usage_info.user_objects_alloc_page_count
          + usage_info.internal_objects_alloc_page_count
          - usage_info.user_objects_dealloc_page_count
          - usage_info.internal_objects_dealloc_page_count
      ) > 0;

    SELECT
        @log_used_percent = CONVERT(decimal(9,2), used_log_space_in_percent)
    FROM sys.dm_db_log_space_usage;

    SELECT
        CASE
            WHEN @blocked_sessions > 0
              OR @root_blockers > 0
              OR @long_running_requests >= 3
              OR @max_tempdb_mb >= 1024
              OR @log_used_percent >= 90 THEN 'Red'
            WHEN @active_waits > 0
              OR @long_running_requests > 0
              OR @max_tempdb_mb >= 256
              OR @log_used_percent >= 75 THEN 'Yellow'
            ELSE 'Green'
        END AS traffic_light,
        CASE
            WHEN @blocked_sessions > 0
              OR @root_blockers > 0
              OR @long_running_requests >= 3
              OR @max_tempdb_mb >= 1024
              OR @log_used_percent >= 90 THEN 'High'
            WHEN @active_waits > 0
              OR @long_running_requests > 0
              OR @max_tempdb_mb >= 256
              OR @log_used_percent >= 75 THEN 'Medium'
            ELSE 'Low'
        END AS pressure_level,
        CASE
            WHEN @blocked_sessions > 0 THEN CONCAT(@blocked_sessions, ' blocked session(s) detected.')
            WHEN @root_blockers > 0 THEN CONCAT(@root_blockers, ' root blocker(s) detected.')
            WHEN @long_running_requests >= 3 THEN CONCAT(@long_running_requests, ' long running request(s) detected.')
            WHEN @log_used_percent >= 90 THEN CONCAT('Transaction log is ', @log_used_percent, '% used.')
            WHEN @max_tempdb_mb >= 1024 THEN CONCAT('TempDB session usage reached ', @max_tempdb_mb, ' MB.')
            WHEN @active_waits > 0 THEN CONCAT(@active_waits, ' active wait(s) detected.')
            WHEN @long_running_requests > 0 THEN CONCAT(@long_running_requests, ' long running request(s) detected.')
            WHEN @log_used_percent >= 75 THEN CONCAT('Transaction log is ', @log_used_percent, '% used.')
            WHEN @max_tempdb_mb >= 256 THEN CONCAT('TempDB session usage reached ', @max_tempdb_mb, ' MB.')
            ELSE 'No obvious online pressure detected.'
        END AS status_summary,
        CONVERT(varchar(16), GETDATE(), 120) AS checked_at,
        @active_requests AS active_requests,
        @long_running_requests AS long_running_requests,
        @active_waits AS active_waits,
        @blocked_sessions AS blocked_sessions,
        @root_blockers AS root_blockers,
        @tempdb_sessions AS tempdb_sessions,
        @max_tempdb_mb AS max_tempdb_mb,
        @log_used_percent AS log_used_percent;
END TRY
BEGIN CATCH
    SELECT
        'Red' AS traffic_light,
        'Permission' AS pressure_level,
        ERROR_MESSAGE() AS status_summary,
        CONVERT(varchar(16), GETDATE(), 120) AS checked_at,
        CAST(NULL AS int) AS active_requests,
        CAST(NULL AS int) AS long_running_requests,
        CAST(NULL AS int) AS active_waits,
        CAST(NULL AS int) AS blocked_sessions,
        CAST(NULL AS int) AS root_blockers,
        CAST(NULL AS int) AS tempdb_sessions,
        CAST(NULL AS decimal(19,2)) AS max_tempdb_mb,
        CAST(NULL AS decimal(9,2)) AS log_used_percent;
END CATCH;
