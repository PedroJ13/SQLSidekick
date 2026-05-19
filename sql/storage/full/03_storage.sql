-- name: database_files
-- title: Database files
-- description: Data and log files with current size and configured growth.
SELECT
    name AS logical_name,
    type_desc,
    physical_name,
    state_desc,
    CAST(size * 8.0 / 1024 / 1024 AS decimal(18, 2)) AS size_gb,
    CASE
        WHEN is_percent_growth = 1 THEN CONCAT(growth, '%')
        ELSE CONCAT(CAST(growth * 8.0 / 1024 / 1024 AS decimal(18, 2)), ' GB')
    END AS growth_setting,
    max_size
FROM sys.database_files
ORDER BY type_desc, logical_name;

-- name: filegroups
-- title: Filegroups
-- description: Filegroups, default status, read-only status, and memory-optimized flags.
SELECT
    fg.name AS filegroup_name,
    fg.type_desc,
    fg.is_default,
    fg.is_read_only,
    fg.is_autogrow_all_files,
    ds.data_space_id
FROM sys.filegroups AS fg
INNER JOIN sys.data_spaces AS ds
    ON ds.data_space_id = fg.data_space_id
ORDER BY fg.is_default DESC, fg.name;

-- name: space_usage
-- title: Space usage
-- description: Database and table-level space usage summary for documentation and growth review.
SELECT
    'DATABASE_TOTAL' AS scope,
    DB_NAME() AS object_name,
    CAST(SUM(size) * 8.0 / 1024 / 1024 AS decimal(18, 2)) AS reserved_gb,
    CAST(NULL AS decimal(18, 2)) AS data_gb,
    CAST(NULL AS decimal(18, 2)) AS index_gb,
    CAST(NULL AS decimal(18, 2)) AS unused_gb,
    CAST(NULL AS bigint) AS row_count
FROM sys.database_files
UNION ALL
SELECT
    'USER_TABLE' AS scope,
    CONCAT(s.name, '.', t.name) AS object_name,
    CAST(SUM(ps.reserved_page_count) * 8.0 / 1024 / 1024 AS decimal(18, 2)) AS reserved_gb,
    CAST(SUM(
        CASE WHEN i.index_id IN (0, 1)
            THEN ps.in_row_data_page_count + ps.lob_used_page_count + ps.row_overflow_used_page_count
            ELSE 0
        END
    ) * 8.0 / 1024 / 1024 AS decimal(18, 2)) AS data_gb,
    CAST(SUM(
        CASE WHEN i.index_id > 1
            THEN ps.used_page_count
            ELSE 0
        END
    ) * 8.0 / 1024 / 1024 AS decimal(18, 2)) AS index_gb,
    CAST(SUM(ps.reserved_page_count - ps.used_page_count) * 8.0 / 1024 / 1024 AS decimal(18, 2)) AS unused_gb,
    SUM(CASE WHEN i.index_id IN (0, 1) THEN ps.row_count ELSE 0 END) AS row_count
FROM sys.dm_db_partition_stats AS ps
INNER JOIN sys.indexes AS i
    ON i.object_id = ps.object_id
    AND i.index_id = ps.index_id
INNER JOIN sys.tables AS t
    ON t.object_id = ps.object_id
INNER JOIN sys.schemas AS s
    ON s.schema_id = t.schema_id
WHERE t.is_ms_shipped = 0
GROUP BY s.name, t.name
ORDER BY scope, reserved_gb DESC, object_name;

