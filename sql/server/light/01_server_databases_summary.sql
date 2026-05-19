-- name: server_databases_summary
-- title: Server databases summary
-- description: Simple server-level database inventory with system/user category, creation date, status, access, and total size.
BEGIN TRY
    WITH database_sizes AS (
        SELECT
            database_id,
            CAST(SUM(size) * 8.0 / 1024 / 1024 AS decimal(18, 2)) AS total_size_gb
        FROM sys.master_files
        GROUP BY database_id
    )
    SELECT
        d.name AS database_name,
        CASE
            WHEN d.database_id <= 4 THEN 'SYSTEM'
            ELSE 'USER'
        END AS database_category,
        CONVERT(varchar(16), d.create_date, 120) AS create_date,
        d.state_desc,
        d.user_access_desc,
        COALESCE(ds.total_size_gb, 0) AS total_size_gb
    FROM sys.databases AS d
    LEFT JOIN database_sizes AS ds
        ON ds.database_id = d.database_id
    ORDER BY
        CASE WHEN d.database_id <= 4 THEN 0 ELSE 1 END,
        d.name;
END TRY
BEGIN CATCH
    SELECT
        ERROR_MESSAGE() AS database_name,
        CAST(NULL AS varchar(6)) AS database_category,
        CAST(NULL AS varchar(16)) AS create_date,
        CAST(NULL AS nvarchar(60)) AS state_desc,
        CAST(NULL AS nvarchar(60)) AS user_access_desc,
        CAST(NULL AS decimal(18, 2)) AS total_size_gb;
END CATCH;
