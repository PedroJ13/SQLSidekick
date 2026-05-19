-- name: linked_servers
-- title: Linked servers
-- description: Linked server inventory with provider, data source, RPC settings, collation settings, and connection timeout.
BEGIN TRY
    SELECT
        name AS linked_server_name,
        product,
        provider,
        data_source,
        location,
        provider_string,
        catalog,
        connect_timeout,
        query_timeout,
        is_linked,
        is_remote_login_enabled,
        is_rpc_out_enabled,
        is_data_access_enabled,
        is_collation_compatible,
        uses_remote_collation,
        collation_name,
        lazy_schema_validation,
        is_system
    FROM sys.servers
    WHERE is_linked = 1
    ORDER BY name;
END TRY
BEGIN CATCH
    SELECT
        CAST(NULL AS sysname) AS linked_server_name,
        CAST(NULL AS nvarchar(128)) AS product,
        CAST(NULL AS nvarchar(128)) AS provider,
        CAST(NULL AS nvarchar(4000)) AS data_source,
        CAST(NULL AS nvarchar(4000)) AS location,
        ERROR_MESSAGE() AS provider_string,
        CAST(NULL AS sysname) AS catalog,
        CAST(NULL AS int) AS connect_timeout,
        CAST(NULL AS int) AS query_timeout,
        CAST(NULL AS bit) AS is_linked,
        CAST(NULL AS bit) AS is_remote_login_enabled,
        CAST(NULL AS bit) AS is_rpc_out_enabled,
        CAST(NULL AS bit) AS is_data_access_enabled,
        CAST(NULL AS bit) AS is_collation_compatible,
        CAST(NULL AS bit) AS uses_remote_collation,
        CAST(NULL AS sysname) AS collation_name,
        CAST(NULL AS bit) AS lazy_schema_validation,
        CAST(NULL AS bit) AS is_system;
END CATCH;
