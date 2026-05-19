-- name: code_alerts
-- title: SQL code alerts
-- description: SQL code alert flags grouped by impact. Returns only alerts that are currently on, without object-level details.
CREATE TABLE #code_alerts (
    severity varchar(10) NOT NULL,
    alert_category varchar(40) NOT NULL,
    alert_name varchar(160) NOT NULL,
    active_count int NULL
);

BEGIN TRY
    INSERT INTO #code_alerts (severity, alert_category, alert_name, active_count)
    SELECT
        'HIGH',
        'VISIBILITY',
        'Encrypted modules cannot be documented',
        COUNT(*)
    FROM sys.sql_modules AS m
    INNER JOIN sys.objects AS o
        ON o.object_id = m.object_id
    WHERE o.is_ms_shipped = 0
      AND m.definition IS NULL
    HAVING COUNT(*) > 0;

    INSERT INTO #code_alerts (severity, alert_category, alert_name, active_count)
    SELECT
        'MEDIUM',
        'SETTINGS',
        'Modules created with ANSI_NULLS off',
        COUNT(*)
    FROM sys.sql_modules AS m
    INNER JOIN sys.objects AS o
        ON o.object_id = m.object_id
    WHERE o.is_ms_shipped = 0
      AND m.uses_ansi_nulls = 0
    HAVING COUNT(*) > 0;

    INSERT INTO #code_alerts (severity, alert_category, alert_name, active_count)
    SELECT
        'MEDIUM',
        'SETTINGS',
        'Modules created with QUOTED_IDENTIFIER off',
        COUNT(*)
    FROM sys.sql_modules AS m
    INNER JOIN sys.objects AS o
        ON o.object_id = m.object_id
    WHERE o.is_ms_shipped = 0
      AND m.uses_quoted_identifier = 0
    HAVING COUNT(*) > 0;

    INSERT INTO #code_alerts (severity, alert_category, alert_name, active_count)
    SELECT
        'MEDIUM',
        'DYNAMIC_SQL',
        'Modules appear to use dynamic SQL execution',
        COUNT(*)
    FROM sys.sql_modules AS m
    INNER JOIN sys.objects AS o
        ON o.object_id = m.object_id
    WHERE o.is_ms_shipped = 0
      AND (
          m.definition LIKE '%EXEC(%'
          OR m.definition LIKE '%EXECUTE(%'
          OR m.definition LIKE '%sp_executesql%'
      )
    HAVING COUNT(*) > 0;

    INSERT INTO #code_alerts (severity, alert_category, alert_name, active_count)
    SELECT
        'LOW',
        'CURSORS',
        'Modules appear to use cursors',
        COUNT(*)
    FROM sys.sql_modules AS m
    INNER JOIN sys.objects AS o
        ON o.object_id = m.object_id
    WHERE o.is_ms_shipped = 0
      AND m.definition LIKE '%CURSOR%'
    HAVING COUNT(*) > 0;

    INSERT INTO #code_alerts (severity, alert_category, alert_name, active_count)
    SELECT
        'LOW',
        'STYLE',
        'Modules appear to use SELECT *',
        COUNT(*)
    FROM sys.sql_modules AS m
    INNER JOIN sys.objects AS o
        ON o.object_id = m.object_id
    WHERE o.is_ms_shipped = 0
      AND m.definition LIKE '%SELECT%*%'
    HAVING COUNT(*) > 0;
END TRY
BEGIN CATCH
    INSERT INTO #code_alerts (severity, alert_category, alert_name, active_count)
    VALUES ('MEDIUM', 'ACCESS', 'Some SQL code alerts could not be evaluated', NULL);
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
    FROM #code_alerts
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

DROP TABLE #code_alerts;
