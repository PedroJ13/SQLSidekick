-- name: waits_tempdb_review
-- title: Waits / TempDB review
-- description: Online operational review for blocking, active waits, long-running requests, TempDB usage, and log pressure.
BEGIN TRY
    WITH request_base AS (
        SELECT
            r.session_id,
            DB_NAME(r.database_id) AS database_name,
            r.status,
            r.command,
            r.total_elapsed_time / 1000 AS elapsed_seconds,
            r.wait_type,
            r.wait_time / 1000 AS wait_seconds,
            NULLIF(r.blocking_session_id, 0) AS blocking_session_id,
            s.login_name,
            s.host_name,
            s.program_name
        FROM sys.dm_exec_requests AS r
        INNER JOIN sys.dm_exec_sessions AS s
            ON s.session_id = r.session_id
        WHERE r.session_id <> @@SPID
          AND s.is_user_process = 1
    ),
    tempdb_usage AS (
        SELECT
            u.session_id,
            CONVERT(decimal(19,2), (
                u.user_objects_alloc_page_count
                + u.internal_objects_alloc_page_count
                - u.user_objects_dealloc_page_count
                - u.internal_objects_dealloc_page_count
            ) / 128.0) AS total_net_mb
        FROM sys.dm_db_session_space_usage AS u
    ),
    log_usage AS (
        SELECT
            CONVERT(decimal(9,2), used_log_space_in_percent) AS used_log_space_percent
        FROM sys.dm_db_log_space_usage
    ),
    findings AS (
        SELECT
            CASE WHEN wait_seconds >= 300 THEN 'HIGH' ELSE 'MEDIUM' END AS severity,
            'Blocking' AS health_area,
            'Session is blocked' AS check_name,
            CONCAT('Session ', request_base.session_id) AS subject_name,
            request_base.session_id,
            database_name,
            wait_type,
            wait_seconds,
            elapsed_seconds,
            total_net_mb,
            CONCAT('Blocked by session ', blocking_session_id, '. Login: ', login_name, '. Program: ', program_name) AS detail,
            'Open Live > Blocking now to identify the blocker and review the active statement.' AS recommendation
        FROM request_base
        LEFT JOIN tempdb_usage
            ON tempdb_usage.session_id = request_base.session_id
        WHERE blocking_session_id IS NOT NULL

        UNION ALL

        SELECT
            CASE WHEN wait_seconds >= 300 THEN 'HIGH' WHEN wait_seconds >= 60 THEN 'MEDIUM' ELSE 'LOW' END,
            'Active waits',
            'Request is waiting',
            CONCAT('Session ', request_base.session_id),
            request_base.session_id,
            database_name,
            wait_type,
            wait_seconds,
            elapsed_seconds,
            total_net_mb,
            CONCAT('Login: ', login_name, '. Program: ', program_name),
            'Review wait type, blocking, and the current request in Live > Active waits.'
        FROM request_base
        LEFT JOIN tempdb_usage
            ON tempdb_usage.session_id = request_base.session_id
        WHERE wait_type IS NOT NULL
          AND blocking_session_id IS NULL

        UNION ALL

        SELECT
            CASE WHEN elapsed_seconds >= 900 THEN 'HIGH' ELSE 'MEDIUM' END,
            'Long running',
            'Request has been running for a long time',
            CONCAT('Session ', request_base.session_id),
            request_base.session_id,
            database_name,
            wait_type,
            wait_seconds,
            elapsed_seconds,
            total_net_mb,
            CONCAT('Command: ', command, '. Login: ', login_name, '. Program: ', program_name),
            'Review request text and plan impact in Live > Current requests.'
        FROM request_base
        LEFT JOIN tempdb_usage
            ON tempdb_usage.session_id = request_base.session_id
        WHERE elapsed_seconds >= 300

        UNION ALL

        SELECT
            CASE WHEN total_net_mb >= 1024 THEN 'HIGH' WHEN total_net_mb >= 256 THEN 'MEDIUM' ELSE 'LOW' END,
            'TempDB',
            'Session is using TempDB space',
            CONCAT('Session ', request_base.session_id),
            request_base.session_id,
            database_name,
            wait_type,
            wait_seconds,
            elapsed_seconds,
            total_net_mb,
            CONCAT('TempDB net MB: ', total_net_mb, '. Login: ', login_name, '. Program: ', program_name),
            'Review TempDB consumers in Live > TempDB usage by session.'
        FROM tempdb_usage
        INNER JOIN request_base
            ON request_base.session_id = tempdb_usage.session_id
        WHERE total_net_mb >= 64

        UNION ALL

        SELECT
            CASE WHEN used_log_space_percent >= 90 THEN 'HIGH' ELSE 'MEDIUM' END,
            'Log usage',
            'Transaction log usage is elevated',
            DB_NAME(),
            CAST(NULL AS int),
            DB_NAME(),
            CAST(NULL AS nvarchar(60)),
            CAST(NULL AS int),
            CAST(NULL AS int),
            CAST(NULL AS decimal(19,2)),
            CONCAT('Log used: ', used_log_space_percent, '%.'),
            'Review Live > Transaction log usage and database log reuse wait.'
        FROM log_usage
        WHERE used_log_space_percent >= 75
    )
    SELECT
        severity,
        health_area,
        check_name,
        subject_name,
        session_id,
        database_name,
        wait_type,
        wait_seconds,
        elapsed_seconds,
        total_net_mb,
        detail,
        recommendation
    FROM findings
    ORDER BY
        CASE severity WHEN 'HIGH' THEN 1 WHEN 'MEDIUM' THEN 2 WHEN 'LOW' THEN 3 ELSE 4 END,
        health_area,
        subject_name;
END TRY
BEGIN CATCH
    SELECT
        'HIGH' AS severity,
        'Access' AS health_area,
        'Waits / TempDB review could not be evaluated' AS check_name,
        ERROR_MESSAGE() AS subject_name,
        CAST(NULL AS int) AS session_id,
        CAST(NULL AS sysname) AS database_name,
        CAST(NULL AS nvarchar(60)) AS wait_type,
        CAST(NULL AS int) AS wait_seconds,
        CAST(NULL AS int) AS elapsed_seconds,
        CAST(NULL AS decimal(19,2)) AS total_net_mb,
        'The current login could not read all required activity DMVs.' AS detail,
        'Grant appropriate DMV permissions or rerun with a privileged review login.' AS recommendation;
END CATCH;
