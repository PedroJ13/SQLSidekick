-- name: database_overview
-- title: Database overview
-- description: Executive database summary with core settings, object counts, security counts, and storage KPIs.
DECLARE @server_login_count int = NULL;

BEGIN TRY
    SELECT @server_login_count = COUNT(*)
    FROM sys.server_principals
    WHERE type IN ('S', 'U', 'G')
      AND name NOT LIKE '##%';
END TRY
BEGIN CATCH
    SET @server_login_count = NULL;
END CATCH;

SELECT
    d.name AS database_name,
    @@SERVERNAME AS server_name,
    CONVERT(varchar(19), d.create_date, 120) AS create_date,
    d.compatibility_level,
    d.collation_name,
    d.recovery_model_desc,
    d.state_desc,
    d.page_verify_option_desc,
    suser_sname(d.owner_sid) AS owner_name,
    CAST((SELECT SUM(size) * 8.0 / 1024 / 1024 FROM sys.database_files) AS decimal(18, 2)) AS allocated_gb,
    CAST((
        SELECT SUM(FILEPROPERTY(name, 'SpaceUsed')) * 8.0 / 1024
        FROM sys.database_files
    ) / 1024 AS decimal(18, 2)) AS used_gb,
    (SELECT COUNT(*) FROM sys.database_files) AS file_count,
    (SELECT COUNT(*) FROM sys.filegroups) AS filegroup_count,
    (SELECT COUNT(*) FROM sys.schemas WHERE name NOT IN ('sys', 'INFORMATION_SCHEMA')) AS schema_count,
    (SELECT COUNT(*) FROM sys.database_principals WHERE type IN ('S', 'U', 'G', 'E', 'X') AND principal_id > 4) AS database_user_count,
    (SELECT COUNT(*) FROM sys.database_principals WHERE type = 'R' AND is_fixed_role = 0) AS custom_role_count,
    @server_login_count AS server_login_count,
    (SELECT COUNT(*) FROM sys.tables WHERE is_ms_shipped = 0) AS table_count,
    (SELECT COUNT(*) FROM sys.views WHERE is_ms_shipped = 0) AS view_count,
    (SELECT COUNT(*) FROM sys.procedures WHERE is_ms_shipped = 0) AS stored_procedure_count,
    (SELECT COUNT(*) FROM sys.objects WHERE type IN ('FN', 'IF', 'TF') AND is_ms_shipped = 0) AS function_count,
    (SELECT COUNT(*) FROM sys.triggers WHERE is_ms_shipped = 0) AS trigger_count,
    (SELECT COUNT(*) FROM sys.foreign_keys) AS foreign_key_count,
    (SELECT COUNT(*) FROM sys.indexes WHERE object_id > 0 AND index_id > 0 AND is_hypothetical = 0) AS index_count
FROM sys.databases AS d
WHERE d.name = DB_NAME();

-- name: database_properties
-- title: Database properties
-- description: Database-level options, isolation behavior, Query Store, and safety-related settings.
SELECT
    d.name AS database_name,
    d.compatibility_level,
    d.collation_name,
    d.recovery_model_desc,
    d.snapshot_isolation_state_desc,
    d.is_read_committed_snapshot_on,
    d.page_verify_option_desc,
    d.is_auto_create_stats_on,
    d.is_auto_update_stats_on,
    d.is_auto_update_stats_async_on,
    d.is_auto_close_on,
    d.is_auto_shrink_on,
    d.is_query_store_on,
    d.is_broker_enabled,
    d.is_cdc_enabled,
    d.is_encrypted,
    d.target_recovery_time_in_seconds,
    d.log_reuse_wait_desc
FROM sys.databases AS d
WHERE d.name = DB_NAME();

