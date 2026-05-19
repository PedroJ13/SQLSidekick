-- name: functions
-- title: Functions
-- description: Full inventory of user SQL functions with module settings.
SELECT
    s.name AS schema_name,
    o.name AS function_name,
    o.object_id,
    o.type,
    o.type_desc AS function_type,
    CONVERT(varchar(16), o.create_date, 120) AS create_date,
    CONVERT(varchar(16), o.modify_date, 120) AS modify_date,
    m.uses_ansi_nulls,
    m.uses_quoted_identifier,
    m.is_schema_bound,
    m.uses_database_collation,
    m.is_recompiled,
    m.null_on_null_input,
    USER_NAME(m.execute_as_principal_id) AS execute_as_principal_name
FROM sys.objects AS o
INNER JOIN sys.schemas AS s
    ON s.schema_id = o.schema_id
LEFT JOIN sys.sql_modules AS m
    ON m.object_id = o.object_id
WHERE o.is_ms_shipped = 0
  AND o.type IN ('FN', 'IF', 'TF')
ORDER BY s.name, o.type_desc, o.name;
