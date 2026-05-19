-- name: triggers
-- title: Triggers
-- description: Light inventory of database DML triggers with parent object, dates, and status.
SELECT
    trigger_schema.name AS schema_name,
    tr.name AS trigger_name,
    parent_schema.name AS parent_schema_name,
    parent_object.name AS parent_object_name,
    parent_object.type_desc AS parent_object_type,
    tr.is_disabled,
    tr.is_instead_of_trigger,
    CONVERT(varchar(16), tr.create_date, 120) AS create_date,
    CONVERT(varchar(16), tr.modify_date, 120) AS modify_date
FROM sys.triggers AS tr
INNER JOIN sys.objects AS trigger_object
    ON trigger_object.object_id = tr.object_id
INNER JOIN sys.schemas AS trigger_schema
    ON trigger_schema.schema_id = trigger_object.schema_id
LEFT JOIN sys.objects AS parent_object
    ON parent_object.object_id = tr.parent_id
LEFT JOIN sys.schemas AS parent_schema
    ON parent_schema.schema_id = parent_object.schema_id
WHERE tr.is_ms_shipped = 0
ORDER BY trigger_schema.name, tr.name;
