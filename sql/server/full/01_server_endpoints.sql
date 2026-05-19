-- name: server_endpoints
-- title: Server endpoints
-- description: Server endpoints including TSQL, database mirroring, service broker, and TCP endpoint metadata.
BEGIN TRY
    SELECT
        e.name AS endpoint_name,
        e.endpoint_id,
        e.type_desc,
        e.protocol_desc,
        e.state_desc,
        e.is_admin_endpoint,
        te.port,
        te.is_dynamic_port,
        te.ip_address
    FROM sys.endpoints AS e
    LEFT JOIN sys.tcp_endpoints AS te
        ON te.endpoint_id = e.endpoint_id
    ORDER BY e.type_desc, e.name;
END TRY
BEGIN CATCH
    SELECT
        ERROR_MESSAGE() AS endpoint_name,
        CAST(NULL AS int) AS endpoint_id,
        CAST(NULL AS nvarchar(60)) AS type_desc,
        CAST(NULL AS nvarchar(60)) AS protocol_desc,
        CAST(NULL AS nvarchar(60)) AS state_desc,
        CAST(NULL AS bit) AS is_admin_endpoint,
        CAST(NULL AS int) AS port,
        CAST(NULL AS bit) AS is_dynamic_port,
        CAST(NULL AS varchar(45)) AS ip_address;
END CATCH;
