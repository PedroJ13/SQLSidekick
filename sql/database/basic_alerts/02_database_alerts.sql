-- name: database_alerts
-- title: Database alerts
-- description: Database-level alert flags grouped by impact. Returns only alerts that are currently on, without object-level details.
CREATE TABLE #database_alerts (
    severity varchar(10) NOT NULL,
    alert_category varchar(40) NOT NULL,
    alert_name varchar(160) NOT NULL,
    active_count int NULL
);

BEGIN TRY
    INSERT INTO #database_alerts (severity, alert_category, alert_name, active_count)
    SELECT
        'HIGH',
        'STATE',
        'Database state is not ONLINE',
        COUNT(*)
    FROM sys.databases
    WHERE name = DB_NAME()
      AND state_desc <> 'ONLINE'
    HAVING COUNT(*) > 0;

    INSERT INTO #database_alerts (severity, alert_category, alert_name, active_count)
    SELECT
        'HIGH',
        'ACCESS',
        'Database access is not MULTI_USER',
        COUNT(*)
    FROM sys.databases
    WHERE name = DB_NAME()
      AND user_access_desc <> 'MULTI_USER'
    HAVING COUNT(*) > 0;

    INSERT INTO #database_alerts (severity, alert_category, alert_name, active_count)
    SELECT
        'HIGH',
        'CONFIGURATION',
        'AUTO_SHRINK is enabled',
        COUNT(*)
    FROM sys.databases
    WHERE name = DB_NAME()
      AND is_auto_shrink_on = 1
    HAVING COUNT(*) > 0;

    INSERT INTO #database_alerts (severity, alert_category, alert_name, active_count)
    SELECT
        'HIGH',
        'SECURITY',
        'TRUSTWORTHY is enabled',
        COUNT(*)
    FROM sys.databases
    WHERE name = DB_NAME()
      AND is_trustworthy_on = 1
    HAVING COUNT(*) > 0;

    INSERT INTO #database_alerts (severity, alert_category, alert_name, active_count)
    SELECT
        'HIGH',
        'SECURITY',
        'Database ownership chaining is enabled',
        COUNT(*)
    FROM sys.databases
    WHERE name = DB_NAME()
      AND is_db_chaining_on = 1
    HAVING COUNT(*) > 0;

    INSERT INTO #database_alerts (severity, alert_category, alert_name, active_count)
    SELECT
        'MEDIUM',
        'CONFIGURATION',
        'Page verify is not CHECKSUM',
        COUNT(*)
    FROM sys.databases
    WHERE name = DB_NAME()
      AND page_verify_option_desc <> 'CHECKSUM'
    HAVING COUNT(*) > 0;

    INSERT INTO #database_alerts (severity, alert_category, alert_name, active_count)
    SELECT
        'MEDIUM',
        'CONFIGURATION',
        'AUTO_CLOSE is enabled',
        COUNT(*)
    FROM sys.databases
    WHERE name = DB_NAME()
      AND is_auto_close_on = 1
    HAVING COUNT(*) > 0;

    INSERT INTO #database_alerts (severity, alert_category, alert_name, active_count)
    SELECT
        'MEDIUM',
        'STATISTICS',
        'AUTO_CREATE_STATISTICS is disabled',
        COUNT(*)
    FROM sys.databases
    WHERE name = DB_NAME()
      AND is_auto_create_stats_on = 0
    HAVING COUNT(*) > 0;

    INSERT INTO #database_alerts (severity, alert_category, alert_name, active_count)
    SELECT
        'MEDIUM',
        'STATISTICS',
        'AUTO_UPDATE_STATISTICS is disabled',
        COUNT(*)
    FROM sys.databases
    WHERE name = DB_NAME()
      AND is_auto_update_stats_on = 0
    HAVING COUNT(*) > 0;

    INSERT INTO #database_alerts (severity, alert_category, alert_name, active_count)
    SELECT
        'MEDIUM',
        'LOG',
        'Log reuse wait is active',
        COUNT(*)
    FROM sys.databases
    WHERE name = DB_NAME()
      AND log_reuse_wait_desc NOT IN ('NOTHING', 'CHECKPOINT')
    HAVING COUNT(*) > 0;

    INSERT INTO #database_alerts (severity, alert_category, alert_name, active_count)
    SELECT
        'LOW',
        'STATE',
        'Database is read-only',
        COUNT(*)
    FROM sys.databases
    WHERE name = DB_NAME()
      AND is_read_only = 1
    HAVING COUNT(*) > 0;

    INSERT INTO #database_alerts (severity, alert_category, alert_name, active_count)
    SELECT
        'LOW',
        'RECOVERY',
        'Recovery model is SIMPLE',
        COUNT(*)
    FROM sys.databases
    WHERE name = DB_NAME()
      AND recovery_model_desc = 'SIMPLE'
    HAVING COUNT(*) > 0;

    INSERT INTO #database_alerts (severity, alert_category, alert_name, active_count)
    SELECT
        'LOW',
        'STATISTICS',
        'AUTO_UPDATE_STATISTICS_ASYNC is enabled',
        COUNT(*)
    FROM sys.databases
    WHERE name = DB_NAME()
      AND is_auto_update_stats_async_on = 1
    HAVING COUNT(*) > 0;
END TRY
BEGIN CATCH
    INSERT INTO #database_alerts (severity, alert_category, alert_name, active_count)
    VALUES ('MEDIUM', 'ACCESS', 'Some database alerts could not be evaluated', NULL);
END CATCH;

BEGIN TRY
    IF COL_LENGTH('sys.databases', 'is_query_store_on') IS NOT NULL
    BEGIN
        INSERT INTO #database_alerts (severity, alert_category, alert_name, active_count)
        EXEC(N'
SELECT
    ''LOW'' AS severity,
    ''FEATURE'' AS alert_category,
    ''Query Store is disabled'' AS alert_name,
    COUNT(*) AS active_count
FROM sys.databases
WHERE name = DB_NAME()
  AND is_query_store_on = 0
HAVING COUNT(*) > 0;');
    END;
END TRY
BEGIN CATCH
    INSERT INTO #database_alerts (severity, alert_category, alert_name, active_count)
    VALUES ('LOW', 'ACCESS', 'Query Store state could not be evaluated', NULL);
END CATCH;

BEGIN TRY
    IF COL_LENGTH('sys.databases', 'is_encrypted') IS NOT NULL
    BEGIN
        INSERT INTO #database_alerts (severity, alert_category, alert_name, active_count)
        EXEC(N'
SELECT
    ''LOW'' AS severity,
    ''SECURITY'' AS alert_category,
    ''Database encryption is disabled'' AS alert_name,
    COUNT(*) AS active_count
FROM sys.databases
WHERE name = DB_NAME()
  AND is_encrypted = 0
HAVING COUNT(*) > 0;');
    END;
END TRY
BEGIN CATCH
    INSERT INTO #database_alerts (severity, alert_category, alert_name, active_count)
    VALUES ('LOW', 'ACCESS', 'Database encryption state could not be evaluated', NULL);
END CATCH;

BEGIN TRY
    IF OBJECT_ID('sys.database_scoped_configurations') IS NOT NULL
       AND COL_LENGTH('sys.database_scoped_configurations', 'is_value_default') IS NOT NULL
    BEGIN
        INSERT INTO #database_alerts (severity, alert_category, alert_name, active_count)
        EXEC(N'
SELECT
    ''LOW'' AS severity,
    ''CONFIGURATION'' AS alert_category,
    ''Database scoped configurations with non-default values'' AS alert_name,
    COUNT(*) AS active_count
FROM sys.database_scoped_configurations
WHERE is_value_default = 0
HAVING COUNT(*) > 0;');
    END;
END TRY
BEGIN CATCH
    INSERT INTO #database_alerts (severity, alert_category, alert_name, active_count)
    VALUES ('LOW', 'ACCESS', 'Database scoped configurations could not be evaluated', NULL);
END CATCH;

WITH ranked_alerts AS (
    SELECT
        severity,
        alert_category,
        alert_name,
        active_count,
        MIN(CASE severity
            WHEN 'HIGH' THEN 1
            WHEN 'MEDIUM' THEN 2
            WHEN 'LOW' THEN 3
            ELSE 4
        END) OVER () AS highest_detected_severity_rank
    FROM #database_alerts
)
SELECT
    CASE highest_detected_severity_rank
        WHEN 1 THEN 'HIGH'
        WHEN 2 THEN 'MEDIUM'
        WHEN 3 THEN 'LOW'
        ELSE 'UNKNOWN'
    END AS highest_detected_severity,
    severity,
    alert_category,
    alert_name,
    active_count
FROM ranked_alerts
ORDER BY
    CASE severity
        WHEN 'HIGH' THEN 1
        WHEN 'MEDIUM' THEN 2
        WHEN 'LOW' THEN 3
        ELSE 4
    END,
    alert_category,
    alert_name;

DROP TABLE #database_alerts;
