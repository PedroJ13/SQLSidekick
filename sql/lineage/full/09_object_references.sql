-- name: object_references
-- title: Object references
-- description: Full SQL object dependency inventory from SQL Server catalog metadata.
BEGIN TRY
    SELECT
        referencing_schema.name AS source_schema,
        referencing_object.name AS source_object,
        referencing_object.type_desc AS source_type,
        referencing_object.object_id AS source_object_id,
        sed.referenced_server_name,
        sed.referenced_database_name,
        COALESCE(referenced_schema.name, sed.referenced_schema_name) AS target_schema,
        COALESCE(referenced_object.name, sed.referenced_entity_name) AS target_object,
        referenced_object.type_desc AS target_type,
        sed.referenced_id AS target_object_id,
        sed.referenced_minor_id,
        sed.is_schema_bound_reference,
        'Catalog dependency' AS detection_method,
        CASE
            WHEN sed.referenced_id IS NOT NULL THEN 'High'
            ELSE 'Medium'
        END AS confidence
    FROM sys.sql_expression_dependencies AS sed
    INNER JOIN sys.objects AS referencing_object
        ON referencing_object.object_id = sed.referencing_id
    INNER JOIN sys.schemas AS referencing_schema
        ON referencing_schema.schema_id = referencing_object.schema_id
    LEFT JOIN sys.objects AS referenced_object
        ON referenced_object.object_id = sed.referenced_id
    LEFT JOIN sys.schemas AS referenced_schema
        ON referenced_schema.schema_id = referenced_object.schema_id
    WHERE referencing_object.is_ms_shipped = 0
      AND referencing_object.type IN ('V', 'P', 'FN', 'IF', 'TF', 'TR')
      AND COALESCE(referenced_object.name, sed.referenced_entity_name) IS NOT NULL
    ORDER BY source_schema, source_object, target_schema, target_object;
END TRY
BEGIN CATCH
    SELECT
        ERROR_MESSAGE() AS source_schema,
        CAST(NULL AS sysname) AS source_object,
        CAST(NULL AS nvarchar(60)) AS source_type,
        CAST(NULL AS int) AS source_object_id,
        CAST(NULL AS sysname) AS referenced_server_name,
        CAST(NULL AS sysname) AS referenced_database_name,
        CAST(NULL AS sysname) AS target_schema,
        CAST(NULL AS sysname) AS target_object,
        CAST(NULL AS nvarchar(60)) AS target_type,
        CAST(NULL AS int) AS target_object_id,
        CAST(NULL AS int) AS referenced_minor_id,
        CAST(NULL AS bit) AS is_schema_bound_reference,
        CAST(NULL AS varchar(30)) AS detection_method,
        CAST(NULL AS varchar(10)) AS confidence;
END CATCH;
