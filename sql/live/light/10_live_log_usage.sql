-- name: live_log_usage
-- title: Transaction log usage
-- description: Online transaction log usage for the current database.
BEGIN TRY
    SELECT
        DB_NAME() AS database_name,
        CONVERT(decimal(19,2), total_log_size_in_bytes / 1048576.0) AS total_log_size_mb,
        CONVERT(decimal(19,2), used_log_space_in_bytes / 1048576.0) AS used_log_space_mb,
        CONVERT(decimal(9,2), used_log_space_in_percent) AS used_log_space_percent,
        CASE
            WHEN used_log_space_in_percent >= 90 THEN 'High'
            WHEN used_log_space_in_percent >= 75 THEN 'Medium'
            ELSE 'Low'
        END AS pressure_level
    FROM sys.dm_db_log_space_usage;
END TRY
BEGIN CATCH
    SELECT
        ERROR_MESSAGE() AS database_name,
        CAST(NULL AS decimal(19,2)) AS total_log_size_mb,
        CAST(NULL AS decimal(19,2)) AS used_log_space_mb,
        CAST(NULL AS decimal(9,2)) AS used_log_space_percent,
        CAST(NULL AS varchar(12)) AS pressure_level;
END CATCH;
