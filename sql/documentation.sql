-- name: database_overview
-- title: Database overview
-- description: Executive database summary with core settings, object counts, security counts, and storage KPIs.
DECLARE @server_login_count int = NULL;
DECLARE @sql_agent_job_count int = NULL;

BEGIN TRY
    SELECT @server_login_count = COUNT(*)
    FROM sys.server_principals
    WHERE type IN ('S', 'U', 'G')
      AND name NOT LIKE '##%';
END TRY
BEGIN CATCH
    SET @server_login_count = NULL;
END CATCH;

BEGIN TRY
    SELECT @sql_agent_job_count = COUNT(*)
    FROM msdb.dbo.sysjobs;
END TRY
BEGIN CATCH
    SET @sql_agent_job_count = NULL;
END CATCH;

SELECT
    d.name AS database_name,
    @@SERVERNAME AS server_name,
    CONVERT(varchar(19), d.create_date, 120) AS create_date,
    d.compatibility_level,
    d.collation_name,
    d.recovery_model_desc,
    d.state_desc,
    d.page_verify_option_desc,
    suser_sname(d.owner_sid) AS owner_name,
    CAST((SELECT SUM(size) * 8.0 / 1024 / 1024 FROM sys.database_files) AS decimal(18, 2)) AS allocated_gb,
    CAST((
        SELECT SUM(FILEPROPERTY(name, 'SpaceUsed')) * 8.0 / 1024
        FROM sys.database_files
    ) / 1024 AS decimal(18, 2)) AS used_gb,
    (SELECT COUNT(*) FROM sys.database_files) AS file_count,
    (SELECT COUNT(*) FROM sys.filegroups) AS filegroup_count,
    (SELECT COUNT(*) FROM sys.schemas WHERE name NOT IN ('sys', 'INFORMATION_SCHEMA')) AS schema_count,
    (SELECT COUNT(*) FROM sys.database_principals WHERE type IN ('S', 'U', 'G', 'E', 'X') AND principal_id > 4) AS database_user_count,
    (SELECT COUNT(*) FROM sys.database_principals WHERE type = 'R' AND is_fixed_role = 0) AS custom_role_count,
    @server_login_count AS server_login_count,
    (SELECT COUNT(*) FROM sys.tables WHERE is_ms_shipped = 0) AS table_count,
    (SELECT COUNT(*) FROM sys.views WHERE is_ms_shipped = 0) AS view_count,
    (SELECT COUNT(*) FROM sys.procedures WHERE is_ms_shipped = 0) AS stored_procedure_count,
    (SELECT COUNT(*) FROM sys.objects WHERE type IN ('FN', 'IF', 'TF') AND is_ms_shipped = 0) AS function_count,
    (SELECT COUNT(*) FROM sys.triggers WHERE is_ms_shipped = 0) AS trigger_count,
    (SELECT COUNT(*) FROM sys.foreign_keys) AS foreign_key_count,
    (SELECT COUNT(*) FROM sys.indexes WHERE object_id > 0 AND index_id > 0 AND is_hypothetical = 0) AS index_count,
    @sql_agent_job_count AS sql_agent_job_count
FROM sys.databases AS d
WHERE d.name = DB_NAME();

-- name: database_properties
-- title: Database properties
-- description: Database-level options, isolation behavior, Query Store, and safety-related settings.
SELECT
    d.name AS database_name,
    d.compatibility_level,
    d.collation_name,
    d.recovery_model_desc,
    d.snapshot_isolation_state_desc,
    d.is_read_committed_snapshot_on,
    d.page_verify_option_desc,
    d.is_auto_create_stats_on,
    d.is_auto_update_stats_on,
    d.is_auto_update_stats_async_on,
    d.is_auto_close_on,
    d.is_auto_shrink_on,
    d.is_query_store_on,
    d.is_broker_enabled,
    d.is_cdc_enabled,
    d.is_encrypted,
    d.target_recovery_time_in_seconds,
    d.log_reuse_wait_desc
FROM sys.databases AS d
WHERE d.name = DB_NAME();

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

-- name: schemas
-- title: Schemas
-- description: User schemas, owners, and object counts.
SELECT
    s.name AS schema_name,
    dp.name AS owner_name,
    s.schema_id,
    COUNT(o.object_id) AS object_count,
    SUM(CASE WHEN o.type = 'U' THEN 1 ELSE 0 END) AS table_count,
    SUM(CASE WHEN o.type = 'V' THEN 1 ELSE 0 END) AS view_count,
    SUM(CASE WHEN o.type = 'P' THEN 1 ELSE 0 END) AS procedure_count,
    SUM(CASE WHEN o.type IN ('FN', 'IF', 'TF') THEN 1 ELSE 0 END) AS function_count
FROM sys.schemas AS s
LEFT JOIN sys.database_principals AS dp
    ON dp.principal_id = s.principal_id
LEFT JOIN sys.objects AS o
    ON o.schema_id = s.schema_id
    AND o.is_ms_shipped = 0
WHERE s.name NOT IN ('sys', 'INFORMATION_SCHEMA')
GROUP BY
    s.name,
    dp.name,
    s.schema_id
ORDER BY s.name;

-- name: objects
-- title: Objects
-- description: Inventory of tables, views, procedures, functions, triggers, and other objects.
SELECT
    s.name AS schema_name,
    o.name AS object_name,
    o.type,
    o.type_desc,
    CONVERT(varchar(19), o.create_date, 120) AS create_date,
    CONVERT(varchar(19), o.modify_date, 120) AS modify_date,
    CASE WHEN o.is_ms_shipped = 1 THEN 'system' ELSE 'user' END AS object_scope
FROM sys.objects AS o
INNER JOIN sys.schemas AS s
    ON s.schema_id = o.schema_id
WHERE o.is_ms_shipped = 0
ORDER BY s.name, o.type_desc, o.name;

-- name: tables
-- title: Tables
-- description: Tables with approximate row count, reserved size, and used size.
SELECT
    s.name AS schema_name,
    t.name AS table_name,
    SUM(p.rows) AS row_count,
    CAST(SUM(a.total_pages) * 8.0 / 1024 / 1024 AS decimal(18, 2)) AS reserved_gb,
    CAST(SUM(a.used_pages) * 8.0 / 1024 / 1024 AS decimal(18, 2)) AS used_gb,
    CAST((SUM(a.total_pages) - SUM(a.used_pages)) * 8.0 / 1024 / 1024 AS decimal(18, 2)) AS unused_gb,
    CONVERT(varchar(19), t.create_date, 120) AS create_date,
    CONVERT(varchar(19), t.modify_date, 120) AS modify_date,
    t.temporal_type_desc,
    t.is_memory_optimized
FROM sys.tables AS t
INNER JOIN sys.schemas AS s
    ON s.schema_id = t.schema_id
INNER JOIN sys.indexes AS i
    ON i.object_id = t.object_id
INNER JOIN sys.partitions AS p
    ON p.object_id = i.object_id
    AND p.index_id = i.index_id
INNER JOIN sys.allocation_units AS a
    ON a.container_id = p.partition_id
WHERE t.is_ms_shipped = 0
  AND i.index_id IN (0, 1)
GROUP BY
    s.name,
    t.name,
    t.create_date,
    t.modify_date,
    t.temporal_type_desc,
    t.is_memory_optimized
ORDER BY reserved_gb DESC, row_count DESC, s.name, t.name;

-- name: columns
-- title: Columns
-- description: Columns by table/view with type, nullability, identity, computed flag, and default.
SELECT
    s.name AS schema_name,
    o.name AS object_name,
    o.type_desc AS object_type,
    c.column_id,
    c.name AS column_name,
    TYPE_NAME(c.user_type_id) AS data_type,
    CASE
        WHEN TYPE_NAME(c.user_type_id) IN ('varchar', 'char', 'varbinary', 'binary')
            THEN CASE WHEN c.max_length = -1 THEN 'max' ELSE CONVERT(varchar(20), c.max_length) END
        WHEN TYPE_NAME(c.user_type_id) IN ('nvarchar', 'nchar')
            THEN CASE WHEN c.max_length = -1 THEN 'max' ELSE CONVERT(varchar(20), c.max_length / 2) END
        WHEN TYPE_NAME(c.user_type_id) IN ('decimal', 'numeric')
            THEN CONCAT(c.precision, ',', c.scale)
        ELSE NULL
    END AS type_detail,
    c.is_nullable,
    c.is_identity,
    c.is_computed,
    dc.definition AS default_definition
FROM sys.columns AS c
INNER JOIN sys.objects AS o
    ON o.object_id = c.object_id
INNER JOIN sys.schemas AS s
    ON s.schema_id = o.schema_id
LEFT JOIN sys.default_constraints AS dc
    ON dc.parent_object_id = c.object_id
    AND dc.parent_column_id = c.column_id
WHERE o.is_ms_shipped = 0
ORDER BY s.name, o.name, c.column_id;

-- name: indexes
-- title: Indexes
-- description: Indexes by table and column, compatible with older SQL Server versions.
SELECT
    schema_name = s.name,
    table_name = t.name,
    index_name = i.name,
    i.type_desc,
    i.is_unique,
    i.is_primary_key,
    i.is_unique_constraint,
    ic.key_ordinal,
    ic.index_column_id,
    c.name AS column_name,
    ic.is_included_column,
    ic.is_descending_key,
    i.filter_definition
FROM sys.indexes AS i
INNER JOIN sys.tables AS t
    ON t.object_id = i.object_id
INNER JOIN sys.schemas AS s
    ON s.schema_id = t.schema_id
LEFT JOIN sys.index_columns AS ic
    ON ic.object_id = i.object_id
    AND ic.index_id = i.index_id
LEFT JOIN sys.columns AS c
    ON c.object_id = ic.object_id
    AND c.column_id = ic.column_id
WHERE t.is_ms_shipped = 0
  AND i.index_id > 0
ORDER BY s.name, t.name, i.is_primary_key DESC, i.name, ic.is_included_column, ic.key_ordinal, ic.index_column_id;

-- name: foreign_keys
-- title: Foreign keys
-- description: Relationships between tables and columns.
SELECT
    fk.name AS foreign_key_name,
    parent_schema = ps.name,
    parent_table = pt.name,
    parent_column = pc.name,
    referenced_schema = rs.name,
    referenced_table = rt.name,
    referenced_column = rc.name,
    fk.delete_referential_action_desc,
    fk.update_referential_action_desc,
    fk.is_disabled,
    fk.is_not_trusted
FROM sys.foreign_keys AS fk
INNER JOIN sys.foreign_key_columns AS fkc
    ON fkc.constraint_object_id = fk.object_id
INNER JOIN sys.tables AS pt
    ON pt.object_id = fkc.parent_object_id
INNER JOIN sys.schemas AS ps
    ON ps.schema_id = pt.schema_id
INNER JOIN sys.columns AS pc
    ON pc.object_id = fkc.parent_object_id
    AND pc.column_id = fkc.parent_column_id
INNER JOIN sys.tables AS rt
    ON rt.object_id = fkc.referenced_object_id
INNER JOIN sys.schemas AS rs
    ON rs.schema_id = rt.schema_id
INNER JOIN sys.columns AS rc
    ON rc.object_id = fkc.referenced_object_id
    AND rc.column_id = fkc.referenced_column_id
ORDER BY ps.name, pt.name, fk.name, fkc.constraint_column_id;

-- name: modules
-- title: SQL code
-- description: Views, procedures, functions, and triggers with definitions for documentation.
SELECT
    s.name AS schema_name,
    o.name AS object_name,
    o.type_desc,
    CONVERT(varchar(19), o.create_date, 120) AS create_date,
    CONVERT(varchar(19), o.modify_date, 120) AS modify_date,
    m.uses_ansi_nulls,
    m.uses_quoted_identifier,
    m.definition
FROM sys.sql_modules AS m
INNER JOIN sys.objects AS o
    ON o.object_id = m.object_id
INNER JOIN sys.schemas AS s
    ON s.schema_id = o.schema_id
WHERE o.is_ms_shipped = 0
ORDER BY s.name, o.type_desc, o.name;

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
