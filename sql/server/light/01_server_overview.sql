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
    CONVERT(varchar(16), SYSDATETIME(), 120) AS server_time,
    @cpu_count AS cpu_count,
    @physical_memory_gb AS physical_memory_gb,
    @max_server_memory_gb AS max_server_memory_gb;

