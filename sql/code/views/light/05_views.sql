-- name: views
-- title: Views
-- description: Light inventory of user views with dates and module settings.
SELECT
    s.name AS schema_name,
    v.name AS view_name,
    CONVERT(varchar(16), v.create_date, 120) AS create_date,
    CONVERT(varchar(16), v.modify_date, 120) AS modify_date,
    m.uses_ansi_nulls,
    m.uses_quoted_identifier,
    m.is_schema_bound
FROM sys.views AS v
INNER JOIN sys.schemas AS s
    ON s.schema_id = v.schema_id
LEFT JOIN sys.sql_modules AS m
    ON m.object_id = v.object_id
WHERE v.is_ms_shipped = 0
ORDER BY s.name, v.name;
