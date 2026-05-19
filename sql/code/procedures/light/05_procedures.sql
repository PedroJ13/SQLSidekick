-- name: procedures
-- title: Stored procedures
-- description: Light inventory of user stored procedures with dates and module settings.
SELECT
    s.name AS schema_name,
    p.name AS procedure_name,
    CONVERT(varchar(16), p.create_date, 120) AS create_date,
    CONVERT(varchar(16), p.modify_date, 120) AS modify_date,
    m.uses_ansi_nulls,
    m.uses_quoted_identifier,
    m.is_recompiled
FROM sys.procedures AS p
INNER JOIN sys.schemas AS s
    ON s.schema_id = p.schema_id
LEFT JOIN sys.sql_modules AS m
    ON m.object_id = p.object_id
WHERE p.is_ms_shipped = 0
ORDER BY s.name, p.name;
