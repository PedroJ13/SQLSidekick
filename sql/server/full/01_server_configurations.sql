-- name: server_configurations
-- title: Server configurations
-- description: Server-level configuration values from sys.configurations.
BEGIN TRY
    SELECT
        configuration_id,
        name AS configuration_name,
        CONVERT(nvarchar(4000), value) AS value,
        CONVERT(nvarchar(4000), value_in_use) AS value_in_use,
        CONVERT(nvarchar(4000), minimum) AS minimum,
        CONVERT(nvarchar(4000), maximum) AS maximum,
        is_dynamic,
        is_advanced,
        description
    FROM sys.configurations
    ORDER BY name;
END TRY
BEGIN CATCH
    SELECT
        CAST(NULL AS int) AS configuration_id,
        CAST(NULL AS nvarchar(128)) AS configuration_name,
        CAST(NULL AS nvarchar(4000)) AS value,
        CAST(NULL AS nvarchar(4000)) AS value_in_use,
        CAST(NULL AS nvarchar(4000)) AS minimum,
        CAST(NULL AS nvarchar(4000)) AS maximum,
        CAST(NULL AS bit) AS is_dynamic,
        CAST(NULL AS bit) AS is_advanced,
        ERROR_MESSAGE() AS description;
END CATCH;
