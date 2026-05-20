-- name: table_usage
-- title: Table usage
-- description: Tables referenced by SQL code objects from catalog dependencies.
BEGIN TRY
    SELECT
        COALESCE(target_schema.name, sed.referenced_schema_name) AS table_schema,
        COALESCE(target_object.name, sed.referenced_entity_name) AS table_name,
        source_schema.name AS used_by_schema,
        source_object.name AS used_by_object,
        source_object.type_desc AS used_by_type,
        'Catalog dependency' AS detection_method,
        CASE WHEN sed.referenced_id IS NOT NULL THEN 'High' ELSE 'Medium' END AS confidence
    FROM sys.sql_expression_dependencies AS sed
    INNER JOIN sys.objects AS source_object
        ON source_object.object_id = sed.referencing_id
    INNER JOIN sys.schemas AS source_schema
        ON source_schema.schema_id = source_object.schema_id
    LEFT JOIN sys.objects AS target_object
        ON target_object.object_id = sed.referenced_id
    LEFT JOIN sys.schemas AS target_schema
        ON target_schema.schema_id = target_object.schema_id
    WHERE source_object.is_ms_shipped = 0
      AND source_object.type IN ('V', 'P', 'FN', 'IF', 'TF', 'TR')
      AND (
          target_object.type = 'U'
          OR sed.referenced_id IS NULL
      )
      AND COALESCE(target_object.name, sed.referenced_entity_name) IS NOT NULL
    ORDER BY table_schema, table_name, used_by_schema, used_by_object;
END TRY
BEGIN CATCH
    SELECT
        ERROR_MESSAGE() AS table_schema,
        CAST(NULL AS sysname) AS table_name,
        CAST(NULL AS sysname) AS used_by_schema,
        CAST(NULL AS sysname) AS used_by_object,
        CAST(NULL AS nvarchar(60)) AS used_by_type,
        CAST(NULL AS varchar(30)) AS detection_method,
        CAST(NULL AS varchar(10)) AS confidence;
END CATCH;
