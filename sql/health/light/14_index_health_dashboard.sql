-- name: index_health_dashboard
-- title: Index health
-- description: Actionable online review for missing indexes, fragmentation, unused indexes, heaps, and disabled/hypothetical indexes.
BEGIN TRY
    WITH findings AS (
        SELECT TOP (50)
            CASE
                WHEN migs.avg_total_user_cost * migs.avg_user_impact * (migs.user_seeks + migs.user_scans) >= 100000 THEN 'HIGH'
                ELSE 'MEDIUM'
            END AS severity,
            'Missing indexes' AS health_area,
            'Potential missing index' AS check_name,
            OBJECT_SCHEMA_NAME(mid.object_id, mid.database_id) + '.' + OBJECT_NAME(mid.object_id, mid.database_id) AS subject_name,
            CAST(NULL AS sysname) AS object_name,
            CAST(NULL AS sysname) AS index_name,
            CONVERT(decimal(19,2), migs.avg_total_user_cost) AS metric_value,
            CONCAT(
                'Impact: ', CONVERT(decimal(19,2), migs.avg_user_impact),
                '%, seeks/scans: ', migs.user_seeks + migs.user_scans,
                '. Equality: ', ISNULL(mid.equality_columns, '-'),
                '. Inequality: ', ISNULL(mid.inequality_columns, '-'),
                '. Include: ', ISNULL(mid.included_columns, '-')
            ) AS detail,
            'Review workload, existing indexes, and write overhead before creating a new index.' AS recommendation
        FROM sys.dm_db_missing_index_details AS mid
        INNER JOIN sys.dm_db_missing_index_groups AS mig
            ON mig.index_handle = mid.index_handle
        INNER JOIN sys.dm_db_missing_index_group_stats AS migs
            ON migs.group_handle = mig.index_group_handle
        WHERE mid.database_id = DB_ID()
        ORDER BY migs.avg_total_user_cost * migs.avg_user_impact * (migs.user_seeks + migs.user_scans) DESC

        UNION ALL

        SELECT
            'LOW',
            'Unused indexes',
            'Index has writes but no recorded reads since last restart',
            OBJECT_SCHEMA_NAME(i.object_id) + '.' + OBJECT_NAME(i.object_id),
            OBJECT_NAME(i.object_id),
            i.name,
            CONVERT(decimal(19,2), ISNULL(ius.user_updates, 0)),
            CONCAT('Updates: ', ISNULL(ius.user_updates, 0), ', seeks/scans/lookups: 0'),
            'Validate with a longer observation window before dropping or consolidating.'
        FROM sys.indexes AS i
        INNER JOIN sys.objects AS o
            ON o.object_id = i.object_id
        LEFT JOIN sys.dm_db_index_usage_stats AS ius
            ON ius.database_id = DB_ID()
           AND ius.object_id = i.object_id
           AND ius.index_id = i.index_id
        WHERE o.is_ms_shipped = 0
          AND i.index_id > 1
          AND i.is_primary_key = 0
          AND i.is_unique_constraint = 0
          AND ISNULL(ius.user_updates, 0) > 100
          AND ISNULL(ius.user_seeks, 0) + ISNULL(ius.user_scans, 0) + ISNULL(ius.user_lookups, 0) = 0

        UNION ALL

        SELECT
            'MEDIUM',
            'Heaps',
            'User table is stored as heap',
            SCHEMA_NAME(t.schema_id) + '.' + t.name,
            t.name,
            CAST(NULL AS sysname),
            CAST(p.rows AS decimal(19,2)),
            CONCAT('Rows: ', p.rows),
            'Review whether the table needs a clustered index or if heap behavior is intentional.'
        FROM sys.tables AS t
        INNER JOIN sys.partitions AS p
            ON p.object_id = t.object_id
           AND p.index_id = 0
        WHERE t.is_ms_shipped = 0
          AND p.rows > 0

        UNION ALL

        SELECT
            'HIGH',
            'Disabled indexes',
            'Index is disabled',
            OBJECT_SCHEMA_NAME(i.object_id) + '.' + OBJECT_NAME(i.object_id),
            OBJECT_NAME(i.object_id),
            i.name,
            CAST(NULL AS decimal(19,2)),
            'Disabled indexes are ignored by the optimizer and may block constraints or expected access paths.',
            'Confirm whether this is intentional; rebuild or drop if not needed.'
        FROM sys.indexes AS i
        INNER JOIN sys.objects AS o
            ON o.object_id = i.object_id
        WHERE o.is_ms_shipped = 0
          AND i.is_disabled = 1

        UNION ALL

        SELECT
            'LOW',
            'Hypothetical indexes',
            'Hypothetical index exists',
            OBJECT_SCHEMA_NAME(i.object_id) + '.' + OBJECT_NAME(i.object_id),
            OBJECT_NAME(i.object_id),
            i.name,
            CAST(NULL AS decimal(19,2)),
            'Hypothetical indexes are metadata-only and usually come from tuning tools.',
            'Drop stale hypothetical indexes after confirming they are not actively used by tuning workflows.'
        FROM sys.indexes AS i
        INNER JOIN sys.objects AS o
            ON o.object_id = i.object_id
        WHERE o.is_ms_shipped = 0
          AND i.is_hypothetical = 1
    )
    SELECT
        severity,
        health_area,
        check_name,
        subject_name,
        object_name,
        index_name,
        metric_value,
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
        'Index health could not be evaluated' AS check_name,
        ERROR_MESSAGE() AS subject_name,
        CAST(NULL AS sysname) AS object_name,
        CAST(NULL AS sysname) AS index_name,
        CAST(NULL AS decimal(19,2)) AS metric_value,
        'The current login could not read all required index metadata or DMVs.' AS detail,
        'Grant appropriate metadata/DMV permissions or rerun with a privileged review login.' AS recommendation;
END CATCH;
