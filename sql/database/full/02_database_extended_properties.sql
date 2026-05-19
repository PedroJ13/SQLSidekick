-- name: database_extended_properties
-- title: Database extended properties
-- description: Full database-level extended properties with class metadata and typed values.
SELECT
    ep.class,
    ep.class_desc,
    ep.major_id,
    ep.minor_id,
    ep.name AS property_name,
    SQL_VARIANT_PROPERTY(ep.value, 'BaseType') AS value_type,
    SQL_VARIANT_PROPERTY(ep.value, 'MaxLength') AS value_max_length,
    SQL_VARIANT_PROPERTY(ep.value, 'Precision') AS value_precision,
    SQL_VARIANT_PROPERTY(ep.value, 'Scale') AS value_scale,
    CONVERT(nvarchar(max), ep.value) AS property_value
FROM sys.extended_properties AS ep
WHERE ep.class = 0
ORDER BY ep.name;
