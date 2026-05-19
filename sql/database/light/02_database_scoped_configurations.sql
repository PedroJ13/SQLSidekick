-- name: database_scoped_configurations
-- title: Database scoped configurations
-- description: Light inventory of database scoped configuration values when available.
BEGIN TRY
    IF OBJECT_ID('sys.database_scoped_configurations') IS NOT NULL
    BEGIN
        EXEC(N'
SELECT
    name AS configuration_name,
    CONVERT(nvarchar(4000), value) AS value,
    CONVERT(nvarchar(4000), value_for_secondary) AS value_for_secondary
FROM sys.database_scoped_configurations
ORDER BY name;');
    END
    ELSE
    BEGIN
        SELECT
            CAST('sys.database_scoped_configurations is not available on this SQL Server version.' AS nvarchar(128)) AS configuration_name,
            CAST(NULL AS nvarchar(4000)) AS value,
            CAST(NULL AS nvarchar(4000)) AS value_for_secondary;
    END;
END TRY
BEGIN CATCH
    SELECT
        ERROR_MESSAGE() AS configuration_name,
        CAST(NULL AS nvarchar(4000)) AS value,
        CAST(NULL AS nvarchar(4000)) AS value_for_secondary;
END CATCH;
