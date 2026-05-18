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

