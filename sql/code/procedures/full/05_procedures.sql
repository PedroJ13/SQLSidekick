-- name: procedures
-- title: Stored procedures
-- description: Full inventory of user stored procedures with module settings.
SELECT
    s.name AS schema_name,
    p.name AS procedure_name,
    p.object_id,
    o.type_desc,
    CONVERT(varchar(16), p.create_date, 120) AS create_date,
    CONVERT(varchar(16), p.modify_date, 120) AS modify_date,
    m.uses_ansi_nulls,
    m.uses_quoted_identifier,
    m.is_schema_bound,
    m.uses_database_collation,
    m.is_recompiled,
    m.null_on_null_input,
    USER_NAME(m.execute_as_principal_id) AS execute_as_principal_name
FROM sys.procedures AS p
INNER JOIN sys.objects AS o
    ON o.object_id = p.object_id
INNER JOIN sys.schemas AS s
    ON s.schema_id = p.schema_id
LEFT JOIN sys.sql_modules AS m
    ON m.object_id = p.object_id
WHERE p.is_ms_shipped = 0
ORDER BY s.name, p.name;
