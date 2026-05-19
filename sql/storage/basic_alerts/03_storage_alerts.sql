-- name: storage_alerts
-- title: Storage alerts
-- description: Storage-level alert flags grouped by impact. Returns only alerts that are currently on, without object-level details.
CREATE TABLE #storage_alerts (
    severity varchar(10) NOT NULL,
    alert_category varchar(40) NOT NULL,
    alert_name varchar(160) NOT NULL,
    active_count int NULL
);

BEGIN TRY
    INSERT INTO #storage_alerts (severity, alert_category, alert_name, active_count)
    SELECT
        'HIGH',
        'FILES',
        'Database files are not online',
        COUNT(*)
    FROM sys.database_files
    WHERE state_desc <> 'ONLINE'
    HAVING COUNT(*) > 0;

    INSERT INTO #storage_alerts (severity, alert_category, alert_name, active_count)
    SELECT
        'HIGH',
        'LOG',
        'Transaction log file has autogrowth disabled',
        COUNT(*)
    FROM sys.database_files
    WHERE type_desc = 'LOG'
      AND growth = 0
    HAVING COUNT(*) > 0;

    INSERT INTO #storage_alerts (severity, alert_category, alert_name, active_count)
    SELECT
        'MEDIUM',
        'FILES',
        'Database files have autogrowth disabled',
        COUNT(*)
    FROM sys.database_files
    WHERE growth = 0
    HAVING COUNT(*) > 0;

    INSERT INTO #storage_alerts (severity, alert_category, alert_name, active_count)
    SELECT
        'MEDIUM',
        'GROWTH',
        'Database files use percent growth',
        COUNT(*)
    FROM sys.database_files
    WHERE is_percent_growth = 1
    HAVING COUNT(*) > 0;

    INSERT INTO #storage_alerts (severity, alert_category, alert_name, active_count)
    SELECT
        'MEDIUM',
        'LOG',
        'Transaction log file has unrestricted growth',
        COUNT(*)
    FROM sys.database_files
    WHERE type_desc = 'LOG'
      AND max_size = -1
    HAVING COUNT(*) > 0;

    INSERT INTO #storage_alerts (severity, alert_category, alert_name, active_count)
    SELECT
        'LOW',
        'FILES',
        'Data files have unrestricted growth',
        COUNT(*)
    FROM sys.database_files
    WHERE type_desc = 'ROWS'
      AND max_size = -1
    HAVING COUNT(*) > 0;

    INSERT INTO #storage_alerts (severity, alert_category, alert_name, active_count)
    SELECT
        'LOW',
        'FILEGROUPS',
        'Multiple filegroups are configured',
        COUNT(*)
    FROM sys.filegroups
    HAVING COUNT(*) > 1;
END TRY
BEGIN CATCH
    INSERT INTO #storage_alerts (severity, alert_category, alert_name, active_count)
    VALUES ('MEDIUM', 'ACCESS', 'Some storage alerts could not be evaluated', NULL);
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
    FROM #storage_alerts
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

DROP TABLE #storage_alerts;
