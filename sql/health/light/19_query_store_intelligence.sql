-- name: query_store_overview
-- title: Query Store overview
-- description: Query Store status, storage usage, and captured workload summary.
BEGIN TRY
    SELECT
        CASE actual_state
            WHEN 0 THEN 'Off'
            WHEN 1 THEN 'Read Only'
            WHEN 2 THEN 'Read Write'
            WHEN 3 THEN 'Error'
            ELSE CONCAT('Unknown ', actual_state)
        END AS query_store_state,
        desired_state_desc AS desired_state,
        actual_state_desc AS actual_state,
        readonly_reason,
        query_capture_mode_desc AS capture_mode,
        CONVERT(decimal(19,2), current_storage_size_mb) AS current_storage_mb,
        CONVERT(decimal(19,2), max_storage_size_mb) AS max_storage_mb,
        CONVERT(decimal(9,2), CASE WHEN max_storage_size_mb > 0 THEN current_storage_size_mb * 100.0 / max_storage_size_mb END) AS storage_used_percent,
        stale_query_threshold_days,
        (SELECT COUNT(*) FROM sys.query_store_query) AS tracked_queries,
        (SELECT COUNT(*) FROM sys.query_store_plan) AS tracked_plans,
        (SELECT CONVERT(varchar(16), MAX(start_time), 120) FROM sys.query_store_runtime_stats_interval) AS last_interval_start,
        (SELECT CONVERT(varchar(16), MAX(end_time), 120) FROM sys.query_store_runtime_stats_interval) AS last_interval_end
    FROM sys.database_query_store_options;
END TRY
BEGIN CATCH
    SELECT
        'Unavailable' AS query_store_state,
        CAST(NULL AS nvarchar(60)) AS desired_state,
        CAST(NULL AS nvarchar(60)) AS actual_state,
        CAST(NULL AS bigint) AS readonly_reason,
        CAST(NULL AS nvarchar(60)) AS capture_mode,
        CAST(NULL AS decimal(19,2)) AS current_storage_mb,
        CAST(NULL AS decimal(19,2)) AS max_storage_mb,
        CAST(NULL AS decimal(9,2)) AS storage_used_percent,
        CAST(NULL AS int) AS stale_query_threshold_days,
        CAST(NULL AS int) AS tracked_queries,
        CAST(NULL AS int) AS tracked_plans,
        CAST(NULL AS varchar(16)) AS last_interval_start,
        CAST(NULL AS varchar(16)) AS last_interval_end;
END CATCH;

-- name: query_store_top_queries
-- title: Query Store top queries
-- description: Top Query Store statements by total duration, CPU, reads, and execution count.
BEGIN TRY
    WITH latest_intervals AS (
        SELECT TOP (12) runtime_stats_interval_id
        FROM sys.query_store_runtime_stats_interval
        ORDER BY end_time DESC
    ),
    qs AS (
        SELECT
            q.query_id,
            p.plan_id,
            LEFT(REPLACE(REPLACE(qt.query_sql_text, CHAR(13), ' '), CHAR(10), ' '), 500) AS query_text_preview,
            SUM(rs.count_executions) AS execution_count,
            CONVERT(decimal(19,2), SUM(rs.avg_duration * rs.count_executions) / 1000.0) AS total_duration_ms,
            CONVERT(decimal(19,2), SUM(rs.avg_cpu_time * rs.count_executions) / 1000.0) AS total_cpu_ms,
            CONVERT(decimal(19,2), SUM(rs.avg_logical_io_reads * rs.count_executions)) AS total_logical_reads,
            CONVERT(decimal(19,2), SUM(rs.avg_physical_io_reads * rs.count_executions)) AS total_physical_reads,
            CONVERT(decimal(19,2), SUM(rs.avg_duration * rs.count_executions) / NULLIF(SUM(rs.count_executions), 0) / 1000.0) AS avg_duration_ms,
            CONVERT(decimal(19,2), SUM(rs.avg_cpu_time * rs.count_executions) / NULLIF(SUM(rs.count_executions), 0) / 1000.0) AS avg_cpu_ms,
            CONVERT(varchar(16), MAX(rsi.end_time), 120) AS last_seen
        FROM sys.query_store_runtime_stats AS rs
        INNER JOIN latest_intervals AS li
            ON li.runtime_stats_interval_id = rs.runtime_stats_interval_id
        INNER JOIN sys.query_store_runtime_stats_interval AS rsi
            ON rsi.runtime_stats_interval_id = rs.runtime_stats_interval_id
        INNER JOIN sys.query_store_plan AS p
            ON p.plan_id = rs.plan_id
        INNER JOIN sys.query_store_query AS q
            ON q.query_id = p.query_id
        INNER JOIN sys.query_store_query_text AS qt
            ON qt.query_text_id = q.query_text_id
        GROUP BY q.query_id, p.plan_id, qt.query_sql_text
    )
    SELECT TOP (50)
        query_id,
        plan_id,
        query_text_preview,
        execution_count,
        total_duration_ms,
        total_cpu_ms,
        total_logical_reads,
        total_physical_reads,
        avg_duration_ms,
        avg_cpu_ms,
        last_seen
    FROM qs
    ORDER BY total_duration_ms DESC;
END TRY
BEGIN CATCH
    SELECT
        CAST(NULL AS bigint) AS query_id,
        CAST(NULL AS bigint) AS plan_id,
        ERROR_MESSAGE() AS query_text_preview,
        CAST(NULL AS bigint) AS execution_count,
        CAST(NULL AS decimal(19,2)) AS total_duration_ms,
        CAST(NULL AS decimal(19,2)) AS total_cpu_ms,
        CAST(NULL AS decimal(19,2)) AS total_logical_reads,
        CAST(NULL AS decimal(19,2)) AS total_physical_reads,
        CAST(NULL AS decimal(19,2)) AS avg_duration_ms,
        CAST(NULL AS decimal(19,2)) AS avg_cpu_ms,
        CAST(NULL AS varchar(16)) AS last_seen;
END CATCH;

-- name: query_store_regressions
-- title: Query Store regressions
-- description: Queries whose recent average duration is materially worse than the previous baseline.
BEGIN TRY
    WITH numbered_intervals AS (
        SELECT
            runtime_stats_interval_id,
            ROW_NUMBER() OVER (ORDER BY end_time DESC) AS rn
        FROM sys.query_store_runtime_stats_interval
    ),
    windows AS (
        SELECT
            q.query_id,
            LEFT(REPLACE(REPLACE(qt.query_sql_text, CHAR(13), ' '), CHAR(10), ' '), 500) AS query_text_preview,
            CASE WHEN ni.rn = 1 THEN 'recent' ELSE 'baseline' END AS window_name,
            SUM(rs.count_executions) AS execution_count,
            SUM(rs.avg_duration * rs.count_executions) AS weighted_duration
        FROM sys.query_store_runtime_stats AS rs
        INNER JOIN numbered_intervals AS ni
            ON ni.runtime_stats_interval_id = rs.runtime_stats_interval_id
        INNER JOIN sys.query_store_plan AS p
            ON p.plan_id = rs.plan_id
        INNER JOIN sys.query_store_query AS q
            ON q.query_id = p.query_id
        INNER JOIN sys.query_store_query_text AS qt
            ON qt.query_text_id = q.query_text_id
        WHERE ni.rn <= 8
        GROUP BY
            q.query_id,
            LEFT(REPLACE(REPLACE(qt.query_sql_text, CHAR(13), ' '), CHAR(10), ' '), 500),
            CASE WHEN ni.rn = 1 THEN 'recent' ELSE 'baseline' END
    ),
    pivoted AS (
        SELECT
            query_id,
            query_text_preview,
            SUM(CASE WHEN window_name = 'recent' THEN execution_count ELSE 0 END) AS recent_executions,
            SUM(CASE WHEN window_name = 'baseline' THEN execution_count ELSE 0 END) AS baseline_executions,
            SUM(CASE WHEN window_name = 'recent' THEN weighted_duration ELSE 0 END) AS recent_duration,
            SUM(CASE WHEN window_name = 'baseline' THEN weighted_duration ELSE 0 END) AS baseline_duration
        FROM windows
        GROUP BY query_id, query_text_preview
    )
    SELECT TOP (50)
        query_id,
        query_text_preview,
        recent_executions,
        baseline_executions,
        CONVERT(decimal(19,2), recent_duration / NULLIF(recent_executions, 0) / 1000.0) AS recent_avg_duration_ms,
        CONVERT(decimal(19,2), baseline_duration / NULLIF(baseline_executions, 0) / 1000.0) AS baseline_avg_duration_ms,
        CONVERT(decimal(19,2), (recent_duration / NULLIF(recent_executions, 0)) / NULLIF((baseline_duration / NULLIF(baseline_executions, 0)), 0)) AS regression_ratio,
        CASE
            WHEN (recent_duration / NULLIF(recent_executions, 0)) / NULLIF((baseline_duration / NULLIF(baseline_executions, 0)), 0) >= 5 THEN 'High'
            WHEN (recent_duration / NULLIF(recent_executions, 0)) / NULLIF((baseline_duration / NULLIF(baseline_executions, 0)), 0) >= 2 THEN 'Medium'
            ELSE 'Low'
        END AS severity
    FROM pivoted
    WHERE recent_executions >= 1
      AND baseline_executions >= 3
      AND (recent_duration / NULLIF(recent_executions, 0)) >= 2 * NULLIF((baseline_duration / NULLIF(baseline_executions, 0)), 0)
    ORDER BY regression_ratio DESC;
END TRY
BEGIN CATCH
    SELECT
        CAST(NULL AS bigint) AS query_id,
        ERROR_MESSAGE() AS query_text_preview,
        CAST(NULL AS bigint) AS recent_executions,
        CAST(NULL AS bigint) AS baseline_executions,
        CAST(NULL AS decimal(19,2)) AS recent_avg_duration_ms,
        CAST(NULL AS decimal(19,2)) AS baseline_avg_duration_ms,
        CAST(NULL AS decimal(19,2)) AS regression_ratio,
        'Unknown' AS severity;
END CATCH;

-- name: query_store_waits
-- title: Query Store waits
-- description: Query Store wait categories by query for the recent workload window.
BEGIN TRY
    WITH latest_intervals AS (
        SELECT TOP (12) runtime_stats_interval_id
        FROM sys.query_store_runtime_stats_interval
        ORDER BY end_time DESC
    )
    SELECT TOP (50)
        q.query_id,
        LEFT(REPLACE(REPLACE(qt.query_sql_text, CHAR(13), ' '), CHAR(10), ' '), 500) AS query_text_preview,
        ws.wait_category_desc AS wait_category,
        CONVERT(decimal(19,2), SUM(ws.total_query_wait_time_ms)) AS total_wait_ms,
        CONVERT(decimal(19,2), AVG(ws.avg_query_wait_time_ms)) AS avg_wait_ms,
        CAST(NULL AS bigint) AS execution_count,
        CONVERT(varchar(16), MAX(rsi.end_time), 120) AS last_seen
    FROM sys.query_store_wait_stats AS ws
    INNER JOIN latest_intervals AS li
        ON li.runtime_stats_interval_id = ws.runtime_stats_interval_id
    INNER JOIN sys.query_store_runtime_stats_interval AS rsi
        ON rsi.runtime_stats_interval_id = ws.runtime_stats_interval_id
    INNER JOIN sys.query_store_plan AS p
        ON p.plan_id = ws.plan_id
    INNER JOIN sys.query_store_query AS q
        ON q.query_id = p.query_id
    INNER JOIN sys.query_store_query_text AS qt
        ON qt.query_text_id = q.query_text_id
    GROUP BY q.query_id, qt.query_sql_text, ws.wait_category_desc
    ORDER BY total_wait_ms DESC;
END TRY
BEGIN CATCH
    SELECT
        CAST(NULL AS bigint) AS query_id,
        ERROR_MESSAGE() AS query_text_preview,
        CAST(NULL AS nvarchar(60)) AS wait_category,
        CAST(NULL AS decimal(19,2)) AS total_wait_ms,
        CAST(NULL AS decimal(19,2)) AS avg_wait_ms,
        CAST(NULL AS bigint) AS execution_count,
        CAST(NULL AS varchar(16)) AS last_seen;
END CATCH;

-- name: query_store_plans
-- title: Query Store plans
-- description: Query Store plan diversity, forced plans, and plan forcing state.
BEGIN TRY
    WITH recent_plans AS (
        SELECT TOP (5000)
            p.plan_id,
            p.query_id,
            p.is_forced_plan,
            p.force_failure_count,
            p.last_force_failure_reason_desc,
            p.last_execution_time
        FROM sys.query_store_plan AS p
        ORDER BY p.last_execution_time DESC
    )
    SELECT TOP (50)
        q.query_id,
        LEFT(REPLACE(REPLACE(qt.query_sql_text, CHAR(13), ' '), CHAR(10), ' '), 500) AS query_text_preview,
        COUNT(*) AS plan_count,
        SUM(CASE WHEN p.is_forced_plan = 1 THEN 1 ELSE 0 END) AS forced_plan_count,
        SUM(CASE WHEN p.force_failure_count > 0 THEN 1 ELSE 0 END) AS force_failure_plan_count,
        MAX(p.last_force_failure_reason_desc) AS last_force_failure_reason,
        MAX(CONVERT(varchar(16), p.last_execution_time, 120)) AS last_execution_time,
        CASE
            WHEN SUM(CASE WHEN p.force_failure_count > 0 THEN 1 ELSE 0 END) > 0 THEN 'High'
            WHEN COUNT(*) >= 5 THEN 'Medium'
            ELSE 'Low'
        END AS severity
    FROM recent_plans AS p
    INNER JOIN sys.query_store_query AS q
        ON q.query_id = p.query_id
    INNER JOIN sys.query_store_query_text AS qt
        ON qt.query_text_id = q.query_text_id
    GROUP BY q.query_id, qt.query_sql_text
    HAVING COUNT(*) > 1
        OR SUM(CASE WHEN p.is_forced_plan = 1 THEN 1 ELSE 0 END) > 0
        OR SUM(CASE WHEN p.force_failure_count > 0 THEN 1 ELSE 0 END) > 0
    ORDER BY
        SUM(CASE WHEN p.force_failure_count > 0 THEN 1 ELSE 0 END) DESC,
        COUNT(*) DESC;
END TRY
BEGIN CATCH
    SELECT
        CAST(NULL AS bigint) AS query_id,
        ERROR_MESSAGE() AS query_text_preview,
        CAST(NULL AS int) AS plan_count,
        CAST(NULL AS int) AS forced_plan_count,
        CAST(NULL AS int) AS force_failure_plan_count,
        CAST(NULL AS nvarchar(120)) AS last_force_failure_reason,
        CAST(NULL AS varchar(16)) AS last_execution_time,
        'Unknown' AS severity;
END CATCH;
