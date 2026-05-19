-- name: structure_alerts
-- title: Structure alerts
-- description: Structure-level alert flags grouped by impact. Returns only alerts that are currently on, without object-level details.
CREATE TABLE #structure_alerts (
    severity varchar(10) NOT NULL,
    alert_category varchar(40) NOT NULL,
    alert_name varchar(160) NOT NULL,
    active_count int NULL
);

BEGIN TRY
    INSERT INTO #structure_alerts (severity, alert_category, alert_name, active_count)
    SELECT
        'HIGH',
        'CONSTRAINTS',
        'Foreign keys are disabled',
        COUNT(*)
    FROM sys.foreign_keys
    WHERE is_disabled = 1
    HAVING COUNT(*) > 0;

    INSERT INTO #structure_alerts (severity, alert_category, alert_name, active_count)
    SELECT
        'HIGH',
        'CONSTRAINTS',
        'Foreign keys are not trusted',
        COUNT(*)
    FROM sys.foreign_keys
    WHERE is_not_trusted = 1
    HAVING COUNT(*) > 0;

    INSERT INTO #structure_alerts (severity, alert_category, alert_name, active_count)
    SELECT
        'MEDIUM',
        'TABLES',
        'User tables without primary key',
        COUNT(*)
    FROM sys.tables AS t
    WHERE t.is_ms_shipped = 0
      AND NOT EXISTS (
          SELECT 1
          FROM sys.key_constraints AS kc
          WHERE kc.parent_object_id = t.object_id
            AND kc.type = 'PK'
      )
    HAVING COUNT(*) > 0;

    INSERT INTO #structure_alerts (severity, alert_category, alert_name, active_count)
    SELECT
        'MEDIUM',
        'INDEXES',
        'Disabled indexes',
        COUNT(*)
    FROM sys.indexes AS i
    INNER JOIN sys.tables AS t
        ON t.object_id = i.object_id
    WHERE t.is_ms_shipped = 0
      AND i.is_disabled = 1
    HAVING COUNT(*) > 0;

    INSERT INTO #structure_alerts (severity, alert_category, alert_name, active_count)
    SELECT
        'MEDIUM',
        'INDEXES',
        'User tables stored as heaps',
        COUNT(*)
    FROM sys.tables AS t
    WHERE t.is_ms_shipped = 0
      AND EXISTS (
          SELECT 1
          FROM sys.indexes AS i
          WHERE i.object_id = t.object_id
            AND i.index_id = 0
      )
    HAVING COUNT(*) > 0;

    INSERT INTO #structure_alerts (severity, alert_category, alert_name, active_count)
    SELECT
        'LOW',
        'COLUMNS',
        'Text, ntext, or image columns are present',
        COUNT(*)
    FROM sys.columns AS c
    INNER JOIN sys.objects AS o
        ON o.object_id = c.object_id
    WHERE o.is_ms_shipped = 0
      AND TYPE_NAME(c.user_type_id) IN ('text', 'ntext', 'image')
    HAVING COUNT(*) > 0;

    INSERT INTO #structure_alerts (severity, alert_category, alert_name, active_count)
    SELECT
        'LOW',
        'COLUMNS',
        'Columns use deprecated timestamp data type',
        COUNT(*)
    FROM sys.columns AS c
    INNER JOIN sys.objects AS o
        ON o.object_id = c.object_id
    WHERE o.is_ms_shipped = 0
      AND TYPE_NAME(c.user_type_id) = 'timestamp'
    HAVING COUNT(*) > 0;
END TRY
BEGIN CATCH
    INSERT INTO #structure_alerts (severity, alert_category, alert_name, active_count)
    VALUES ('MEDIUM', 'ACCESS', 'Some structure alerts could not be evaluated', NULL);
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
    FROM #structure_alerts
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

DROP TABLE #structure_alerts;
