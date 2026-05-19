-- name: triggers
-- title: Triggers
-- description: Full inventory of database DML triggers with parent object and module settings.
SELECT
    trigger_schema.name AS schema_name,
    tr.name AS trigger_name,
    tr.object_id,
    tr.parent_class_desc,
    parent_schema.name AS parent_schema_name,
    parent_object.name AS parent_object_name,
    parent_object.type_desc AS parent_object_type,
    tr.is_disabled,
    tr.is_instead_of_trigger,
    CONVERT(varchar(16), tr.create_date, 120) AS create_date,
    CONVERT(varchar(16), tr.modify_date, 120) AS modify_date,
    m.uses_ansi_nulls,
    m.uses_quoted_identifier,
    m.is_schema_bound,
    m.uses_database_collation,
    m.is_recompiled,
    m.null_on_null_input,
    USER_NAME(m.execute_as_principal_id) AS execute_as_principal_name
FROM sys.triggers AS tr
INNER JOIN sys.objects AS trigger_object
    ON trigger_object.object_id = tr.object_id
INNER JOIN sys.schemas AS trigger_schema
    ON trigger_schema.schema_id = trigger_object.schema_id
LEFT JOIN sys.objects AS parent_object
    ON parent_object.object_id = tr.parent_id
LEFT JOIN sys.schemas AS parent_schema
    ON parent_schema.schema_id = parent_object.schema_id
LEFT JOIN sys.sql_modules AS m
    ON m.object_id = tr.object_id
WHERE tr.is_ms_shipped = 0
ORDER BY trigger_schema.name, tr.name;
