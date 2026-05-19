-- name: database_overview
-- title: Database overview
-- description: Light database summary with identity, core settings, size, and main object counts.
SELECT
    d.name AS database_name,
    @@SERVERNAME AS server_name,
    CONVERT(varchar(16), d.create_date, 120) AS create_date,
    SUSER_SNAME(d.owner_sid) AS owner_name,
    d.state_desc,
    d.compatibility_level,
    d.collation_name,
    d.recovery_model_desc,
    CAST((SELECT SUM(size) * 8.0 / 1024 / 1024 FROM sys.database_files) AS decimal(18, 2)) AS allocated_gb,
    CAST((
        SELECT SUM(FILEPROPERTY(name, 'SpaceUsed')) * 8.0 / 1024 / 1024
        FROM sys.database_files
    ) AS decimal(18, 2)) AS used_gb,
    (SELECT COUNT(*) FROM sys.schemas WHERE name NOT IN ('sys', 'INFORMATION_SCHEMA')) AS schema_count,
    (SELECT COUNT(*) FROM sys.tables WHERE is_ms_shipped = 0) AS table_count,
    (SELECT COUNT(*) FROM sys.views WHERE is_ms_shipped = 0) AS view_count,
    (SELECT COUNT(*) FROM sys.procedures WHERE is_ms_shipped = 0) AS stored_procedure_count,
    (SELECT COUNT(*) FROM sys.objects WHERE type IN ('FN', 'IF', 'TF') AND is_ms_shipped = 0) AS function_count
FROM sys.databases AS d
WHERE d.name = DB_NAME();
