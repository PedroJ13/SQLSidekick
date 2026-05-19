-- name: database_extended_properties
-- title: Database extended properties
-- description: Database-level extended properties used as documentation metadata.
SELECT
    ep.name AS property_name,
    SQL_VARIANT_PROPERTY(ep.value, 'BaseType') AS value_type,
    CONVERT(nvarchar(max), ep.value) AS property_value
FROM sys.extended_properties AS ep
WHERE ep.class = 0
ORDER BY ep.name;
