-- name: server_properties
-- title: Server properties
-- description: Extended SERVERPROPERTY values that describe instance identity, version, platform, clustering, HADR, and default paths.
SELECT
    @@SERVERNAME AS server_name,
    CAST(SERVERPROPERTY('ServerName') AS nvarchar(256)) AS property_server_name,
    CAST(SERVERPROPERTY('MachineName') AS nvarchar(256)) AS machine_name,
    CAST(SERVERPROPERTY('ComputerNamePhysicalNetBIOS') AS nvarchar(256)) AS computer_name_physical_netbios,
    COALESCE(CAST(SERVERPROPERTY('InstanceName') AS nvarchar(256)), 'MSSQLSERVER') AS instance_name,
    CAST(SERVERPROPERTY('Edition') AS nvarchar(256)) AS edition,
    CAST(SERVERPROPERTY('EditionID') AS bigint) AS edition_id,
    CAST(SERVERPROPERTY('EngineEdition') AS int) AS engine_edition,
    CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(256)) AS product_version,
    CAST(SERVERPROPERTY('ProductMajorVersion') AS nvarchar(256)) AS product_major_version,
    CAST(SERVERPROPERTY('ProductMinorVersion') AS nvarchar(256)) AS product_minor_version,
    CAST(SERVERPROPERTY('ProductBuild') AS nvarchar(256)) AS product_build,
    CAST(SERVERPROPERTY('ProductBuildType') AS nvarchar(256)) AS product_build_type,
    CAST(SERVERPROPERTY('ProductLevel') AS nvarchar(256)) AS product_level,
    CAST(SERVERPROPERTY('ProductUpdateLevel') AS nvarchar(256)) AS product_update_level,
    CAST(SERVERPROPERTY('ProductUpdateReference') AS nvarchar(256)) AS product_update_reference,
    CAST(SERVERPROPERTY('ResourceVersion') AS nvarchar(256)) AS resource_version,
    CAST(SERVERPROPERTY('Collation') AS nvarchar(256)) AS server_collation,
    CAST(SERVERPROPERTY('IsClustered') AS int) AS is_clustered,
    CAST(SERVERPROPERTY('IsHadrEnabled') AS int) AS is_hadr_enabled,
    CAST(SERVERPROPERTY('IsIntegratedSecurityOnly') AS int) AS is_integrated_security_only,
    CAST(SERVERPROPERTY('FilestreamConfiguredLevel') AS int) AS filestream_configured_level,
    CAST(SERVERPROPERTY('FilestreamEffectiveLevel') AS int) AS filestream_effective_level,
    CAST(SERVERPROPERTY('InstanceDefaultDataPath') AS nvarchar(4000)) AS instance_default_data_path,
    CAST(SERVERPROPERTY('InstanceDefaultLogPath') AS nvarchar(4000)) AS instance_default_log_path;
