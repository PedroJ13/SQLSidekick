-- name: server_overview
-- title: Server overview
-- description: SQL Server instance summary with version, inventory, runtime, and capacity signals.
DECLARE @server_login_count int = NULL;
DECLARE @sql_agent_job_count int = NULL;
DECLARE @linked_server_count int = NULL;
DECLARE @cpu_count int = NULL;
DECLARE @physical_memory_gb decimal(18, 2) = NULL;
DECLARE @max_server_memory_gb decimal(18, 2) = NULL;
DECLARE @host_platform nvarchar(256) = NULL;

BEGIN TRY
    SELECT @server_login_count = COUNT(*)
    FROM sys.server_principals
    WHERE type IN ('S', 'U', 'G')
      AND name NOT LIKE '##%';
END TRY
BEGIN CATCH
    SET @server_login_count = NULL;
END CATCH;

BEGIN TRY
    SELECT @sql_agent_job_count = COUNT(*)
    FROM msdb.dbo.sysjobs;
END TRY
BEGIN CATCH
    SET @sql_agent_job_count = NULL;
END CATCH;

BEGIN TRY
    SELECT @linked_server_count = COUNT(*)
    FROM sys.servers
    WHERE is_linked = 1;
END TRY
BEGIN CATCH
    SET @linked_server_count = NULL;
END CATCH;

BEGIN TRY
    SELECT
        @cpu_count = cpu_count,
        @physical_memory_gb = CAST(physical_memory_kb / 1024.0 / 1024.0 AS decimal(18, 2))
    FROM sys.dm_os_sys_info;
END TRY
BEGIN CATCH
    SET @cpu_count = NULL;
    SET @physical_memory_gb = NULL;
END CATCH;

BEGIN TRY
    SELECT @max_server_memory_gb = CAST(CONVERT(decimal(18, 2), value_in_use) / 1024.0 AS decimal(18, 2))
    FROM sys.configurations
    WHERE name = 'max server memory (MB)';
END TRY
BEGIN CATCH
    SET @max_server_memory_gb = NULL;
END CATCH;

BEGIN TRY
    SELECT @host_platform = CONCAT(host_platform, ' ', host_distribution)
    FROM sys.dm_os_host_info;
END TRY
BEGIN CATCH
    SET @host_platform = NULL;
END CATCH;

SELECT
    @@SERVERNAME AS server_name,
    CAST(SERVERPROPERTY('MachineName') AS nvarchar(256)) AS machine_name,
    COALESCE(CAST(SERVERPROPERTY('InstanceName') AS nvarchar(256)), 'MSSQLSERVER') AS instance_name,
    @host_platform AS host_platform,
    CAST(SERVERPROPERTY('Edition') AS nvarchar(256)) AS edition,
    CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(256)) AS product_version,
    CAST(SERVERPROPERTY('ProductLevel') AS nvarchar(256)) AS product_level,
    CAST(SERVERPROPERTY('EngineEdition') AS int) AS engine_edition,
    CAST(SERVERPROPERTY('Collation') AS nvarchar(256)) AS server_collation,
    (SELECT COUNT(*) FROM sys.databases) AS database_count,
    @server_login_count AS server_login_count,
    @linked_server_count AS linked_server_count,
    @sql_agent_job_count AS sql_agent_job_count,
    CONVERT(varchar(19), SYSDATETIME(), 120) AS server_time,
    @cpu_count AS cpu_count,
    @physical_memory_gb AS physical_memory_gb,
    @max_server_memory_gb AS max_server_memory_gb;

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

-- name: server_runtime
-- title: Server runtime
-- description: SQL Server runtime details, host information, CPU layout, memory visibility, and instance start time.
DECLARE @runtime_host_platform nvarchar(256) = NULL;
DECLARE @runtime_host_distribution nvarchar(256) = NULL;
DECLARE @runtime_host_release nvarchar(256) = NULL;
DECLARE @runtime_host_service_pack nvarchar(256) = NULL;

BEGIN TRY
    SELECT
        @runtime_host_platform = host_platform,
        @runtime_host_distribution = host_distribution,
        @runtime_host_release = host_release,
        @runtime_host_service_pack = host_service_pack_level
    FROM sys.dm_os_host_info;
END TRY
BEGIN CATCH
    SET @runtime_host_platform = NULL;
    SET @runtime_host_distribution = NULL;
    SET @runtime_host_release = NULL;
    SET @runtime_host_service_pack = NULL;
END CATCH;

BEGIN TRY
    SELECT
        @@SERVERNAME AS server_name,
        CONVERT(varchar(19), osi.sqlserver_start_time, 120) AS sqlserver_start_time,
        DATEDIFF(day, osi.sqlserver_start_time, SYSDATETIME()) AS uptime_days,
        @runtime_host_platform AS host_platform,
        @runtime_host_distribution AS host_distribution,
        @runtime_host_release AS host_release,
        @runtime_host_service_pack AS host_service_pack_level,
        osi.cpu_count,
        osi.scheduler_count,
        osi.hyperthread_ratio,
        CAST(osi.physical_memory_kb / 1024.0 / 1024.0 AS decimal(18, 2)) AS physical_memory_gb,
        CAST(osi.virtual_memory_kb / 1024.0 / 1024.0 AS decimal(18, 2)) AS virtual_memory_gb,
        CAST(osi.committed_kb / 1024.0 / 1024.0 AS decimal(18, 2)) AS committed_memory_gb,
        CAST(osi.committed_target_kb / 1024.0 / 1024.0 AS decimal(18, 2)) AS committed_target_memory_gb,
        osi.sqlserver_start_time AS sqlserver_start_datetime
    FROM sys.dm_os_sys_info AS osi;
END TRY
BEGIN CATCH
    SELECT
        @@SERVERNAME AS server_name,
        CAST(NULL AS varchar(19)) AS sqlserver_start_time,
        CAST(NULL AS int) AS uptime_days,
        @runtime_host_platform AS host_platform,
        @runtime_host_distribution AS host_distribution,
        @runtime_host_release AS host_release,
        @runtime_host_service_pack AS host_service_pack_level,
        CAST(NULL AS int) AS cpu_count,
        CAST(NULL AS int) AS scheduler_count,
        CAST(NULL AS int) AS hyperthread_ratio,
        CAST(NULL AS decimal(18, 2)) AS physical_memory_gb,
        CAST(NULL AS decimal(18, 2)) AS virtual_memory_gb,
        CAST(NULL AS decimal(18, 2)) AS committed_memory_gb,
        CAST(NULL AS decimal(18, 2)) AS committed_target_memory_gb,
        CAST(NULL AS datetime) AS sqlserver_start_datetime;
END CATCH;

-- name: server_configurations
-- title: Server configurations
-- description: Server-level configuration values from sys.configurations.
BEGIN TRY
    SELECT
        configuration_id,
        name AS configuration_name,
        value,
        value_in_use,
        minimum,
        maximum,
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
        CAST(NULL AS sql_variant) AS value,
        CAST(NULL AS sql_variant) AS value_in_use,
        CAST(NULL AS sql_variant) AS minimum,
        CAST(NULL AS sql_variant) AS maximum,
        CAST(NULL AS bit) AS is_dynamic,
        CAST(NULL AS bit) AS is_advanced,
        ERROR_MESSAGE() AS description;
END CATCH;

-- name: server_services
-- title: Server services
-- description: SQL Server related Windows services, startup mode, status, service account, and last startup time when available.
BEGIN TRY
    IF OBJECT_ID('sys.dm_server_services') IS NOT NULL
    BEGIN
        EXEC(N'
SELECT
    servicename AS service_name,
    startup_type_desc,
    status_desc,
    process_id,
    last_startup_time,
    service_account,
    filename AS executable_path,
    CAST(NULL AS nvarchar(4000)) AS access_note
FROM sys.dm_server_services
ORDER BY servicename;');
    END
    ELSE
    BEGIN
        SELECT
            CAST(NULL AS nvarchar(256)) AS service_name,
            CAST(NULL AS nvarchar(60)) AS startup_type_desc,
            CAST(NULL AS nvarchar(60)) AS status_desc,
            CAST(NULL AS int) AS process_id,
            CAST(NULL AS datetimeoffset) AS last_startup_time,
            CAST(NULL AS nvarchar(256)) AS service_account,
            CAST(NULL AS nvarchar(4000)) AS executable_path,
            CAST('sys.dm_server_services is not available on this SQL Server version.' AS nvarchar(4000)) AS access_note;
    END;
END TRY
BEGIN CATCH
    SELECT
        CAST(NULL AS nvarchar(256)) AS service_name,
        CAST(NULL AS nvarchar(60)) AS startup_type_desc,
        CAST(NULL AS nvarchar(60)) AS status_desc,
        CAST(NULL AS int) AS process_id,
        CAST(NULL AS datetimeoffset) AS last_startup_time,
        CAST(NULL AS nvarchar(256)) AS service_account,
        CAST(NULL AS nvarchar(4000)) AS executable_path,
        ERROR_MESSAGE() AS access_note;
END CATCH;

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

-- name: server_logins
-- title: Server logins
-- description: Server principal inventory with login type, disabled state, default database, language, and password policy metadata where available.
BEGIN TRY
    SELECT
        sp.name AS login_name,
        sp.type,
        sp.type_desc,
        sp.is_disabled,
        sp.default_database_name,
        sp.default_language_name,
        CONVERT(varchar(19), sp.create_date, 120) AS create_date,
        CONVERT(varchar(19), sp.modify_date, 120) AS modify_date,
        sl.is_policy_checked,
        sl.is_expiration_checked,
        LOGINPROPERTY(sp.name, 'PasswordLastSetTime') AS password_last_set_time,
        LOGINPROPERTY(sp.name, 'DaysUntilExpiration') AS days_until_expiration,
        sp.principal_id,
        sp.sid
    FROM sys.server_principals AS sp
    LEFT JOIN sys.sql_logins AS sl
        ON sl.principal_id = sp.principal_id
    WHERE sp.type IN ('S', 'U', 'G', 'R', 'C', 'K')
      AND sp.name NOT LIKE '##%'
    ORDER BY sp.type_desc, sp.name;
END TRY
BEGIN CATCH
    SELECT
        ERROR_MESSAGE() AS login_name,
        CAST(NULL AS char(1)) AS type,
        CAST(NULL AS nvarchar(60)) AS type_desc,
        CAST(NULL AS bit) AS is_disabled,
        CAST(NULL AS sysname) AS default_database_name,
        CAST(NULL AS sysname) AS default_language_name,
        CAST(NULL AS varchar(19)) AS create_date,
        CAST(NULL AS varchar(19)) AS modify_date,
        CAST(NULL AS bit) AS is_policy_checked,
        CAST(NULL AS bit) AS is_expiration_checked,
        CAST(NULL AS sql_variant) AS password_last_set_time,
        CAST(NULL AS sql_variant) AS days_until_expiration,
        CAST(NULL AS int) AS principal_id,
        CAST(NULL AS varbinary(85)) AS sid;
END CATCH;

-- name: server_role_members
-- title: Server role members
-- description: Server role membership for fixed and custom server roles.
BEGIN TRY
    SELECT
        role_principal.name AS server_role_name,
        role_principal.type_desc AS server_role_type,
        member_principal.name AS member_name,
        member_principal.type_desc AS member_type,
        member_principal.is_disabled AS member_is_disabled,
        CONVERT(varchar(19), member_principal.create_date, 120) AS member_create_date,
        CONVERT(varchar(19), member_principal.modify_date, 120) AS member_modify_date
    FROM sys.server_role_members AS srm
    INNER JOIN sys.server_principals AS role_principal
        ON role_principal.principal_id = srm.role_principal_id
    INNER JOIN sys.server_principals AS member_principal
        ON member_principal.principal_id = srm.member_principal_id
    ORDER BY role_principal.name, member_principal.name;
END TRY
BEGIN CATCH
    SELECT
        ERROR_MESSAGE() AS server_role_name,
        CAST(NULL AS nvarchar(60)) AS server_role_type,
        CAST(NULL AS sysname) AS member_name,
        CAST(NULL AS nvarchar(60)) AS member_type,
        CAST(NULL AS bit) AS member_is_disabled,
        CAST(NULL AS varchar(19)) AS member_create_date,
        CAST(NULL AS varchar(19)) AS member_modify_date;
END CATCH;

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

-- name: availability_groups
-- title: Availability groups
-- description: Always On availability group inventory with replica and synchronization metadata when the feature is available.
BEGIN TRY
    IF OBJECT_ID('sys.availability_groups') IS NOT NULL
    BEGIN
        EXEC(N'
SELECT
    ag.name AS availability_group_name,
    ag.group_id,
    ag.resource_id,
    ag.cluster_type_desc,
    ag.automated_backup_preference_desc,
    ag.failure_condition_level,
    ar.replica_server_name,
    ar.availability_mode_desc,
    ar.failover_mode_desc,
    ar.seeding_mode_desc,
    ars.role_desc,
    ars.operational_state_desc,
    ars.connected_state_desc,
    ars.synchronization_health_desc,
    CAST(NULL AS nvarchar(4000)) AS access_note
FROM sys.availability_groups AS ag
LEFT JOIN sys.availability_replicas AS ar
    ON ar.group_id = ag.group_id
LEFT JOIN sys.dm_hadr_availability_replica_states AS ars
    ON ars.replica_id = ar.replica_id
ORDER BY ag.name, ar.replica_server_name;');
    END
    ELSE
    BEGIN
        SELECT
            CAST(NULL AS sysname) AS availability_group_name,
            CAST(NULL AS uniqueidentifier) AS group_id,
            CAST(NULL AS nvarchar(40)) AS resource_id,
            CAST(NULL AS nvarchar(60)) AS cluster_type_desc,
            CAST(NULL AS nvarchar(60)) AS automated_backup_preference_desc,
            CAST(NULL AS int) AS failure_condition_level,
            CAST(NULL AS nvarchar(256)) AS replica_server_name,
            CAST(NULL AS nvarchar(60)) AS availability_mode_desc,
            CAST(NULL AS nvarchar(60)) AS failover_mode_desc,
            CAST(NULL AS nvarchar(60)) AS seeding_mode_desc,
            CAST(NULL AS nvarchar(60)) AS role_desc,
            CAST(NULL AS nvarchar(60)) AS operational_state_desc,
            CAST(NULL AS nvarchar(60)) AS connected_state_desc,
            CAST(NULL AS nvarchar(60)) AS synchronization_health_desc,
            CAST('Availability Groups catalog views are not available on this SQL Server version.' AS nvarchar(4000)) AS access_note;
    END;
END TRY
BEGIN CATCH
    SELECT
        CAST(NULL AS sysname) AS availability_group_name,
        CAST(NULL AS uniqueidentifier) AS group_id,
        CAST(NULL AS nvarchar(40)) AS resource_id,
        CAST(NULL AS nvarchar(60)) AS cluster_type_desc,
        CAST(NULL AS nvarchar(60)) AS automated_backup_preference_desc,
        CAST(NULL AS int) AS failure_condition_level,
        CAST(NULL AS nvarchar(256)) AS replica_server_name,
        CAST(NULL AS nvarchar(60)) AS availability_mode_desc,
        CAST(NULL AS nvarchar(60)) AS failover_mode_desc,
        CAST(NULL AS nvarchar(60)) AS seeding_mode_desc,
        CAST(NULL AS nvarchar(60)) AS role_desc,
        CAST(NULL AS nvarchar(60)) AS operational_state_desc,
        CAST(NULL AS nvarchar(60)) AS connected_state_desc,
        CAST(NULL AS nvarchar(60)) AS synchronization_health_desc,
        ERROR_MESSAGE() AS access_note;
END CATCH;

