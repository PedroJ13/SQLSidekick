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

