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
        CONVERT(varchar(16), osi.sqlserver_start_time, 120) AS sqlserver_start_time,
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
        CAST(osi.committed_target_kb / 1024.0 / 1024.0 AS decimal(18, 2)) AS committed_target_memory_gb
    FROM sys.dm_os_sys_info AS osi;
END TRY
BEGIN CATCH
    SELECT
        @@SERVERNAME AS server_name,
        CAST(NULL AS varchar(16)) AS sqlserver_start_time,
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
        CAST(NULL AS decimal(18, 2)) AS committed_target_memory_gb;
END CATCH;
