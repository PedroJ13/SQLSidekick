-- name: database_scoped_configurations
-- title: Database scoped configurations
-- description: Full inventory of database scoped configuration values when available.
BEGIN TRY
    IF OBJECT_ID('sys.database_scoped_configurations') IS NOT NULL
    BEGIN
        EXEC(N'
SELECT
    configuration_id,
    name AS configuration_name,
    CONVERT(nvarchar(4000), value) AS value,
    CONVERT(nvarchar(4000), value_for_secondary) AS value_for_secondary,
    is_value_default
FROM sys.database_scoped_configurations
ORDER BY name;');
    END
    ELSE
    BEGIN
        SELECT
            CAST(NULL AS int) AS configuration_id,
            CAST('sys.database_scoped_configurations is not available on this SQL Server version.' AS nvarchar(128)) AS configuration_name,
            CAST(NULL AS nvarchar(4000)) AS value,
            CAST(NULL AS nvarchar(4000)) AS value_for_secondary,
            CAST(NULL AS bit) AS is_value_default;
    END;
END TRY
BEGIN CATCH
    SELECT
        CAST(NULL AS int) AS configuration_id,
        ERROR_MESSAGE() AS configuration_name,
        CAST(NULL AS nvarchar(4000)) AS value,
        CAST(NULL AS nvarchar(4000)) AS value_for_secondary,
        CAST(NULL AS bit) AS is_value_default;
END CATCH;
