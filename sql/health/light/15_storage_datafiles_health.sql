-- name: storage_datafiles_health
-- title: Storage / Datafiles health
-- description: Actionable online review for database files, growth settings, free space, and transaction log usage.
BEGIN TRY
    WITH file_base AS (
        SELECT
            df.file_id,
            df.name AS logical_name,
            df.physical_name,
            df.type_desc,
            fg.name AS filegroup_name,
            CONVERT(decimal(19,2), df.size / 131072.0) AS size_gb,
            CONVERT(decimal(19,2), FILEPROPERTY(df.name, 'SpaceUsed') / 131072.0) AS used_gb,
            CASE WHEN df.size > 0 THEN CONVERT(decimal(9,2), (FILEPROPERTY(df.name, 'SpaceUsed') * 100.0) / df.size) ELSE NULL END AS used_percent,
            df.growth,
            df.is_percent_growth,
            df.max_size
        FROM sys.database_files AS df
        LEFT JOIN sys.filegroups AS fg
            ON fg.data_space_id = df.data_space_id
    ),
    log_usage AS (
        SELECT
            CONVERT(decimal(19,2), total_log_size_in_bytes / 1048576.0) AS total_log_size_mb,
            CONVERT(decimal(19,2), used_log_space_in_bytes / 1048576.0) AS used_log_space_mb,
            CONVERT(decimal(9,2), used_log_space_in_percent) AS used_log_space_percent
        FROM sys.dm_db_log_space_usage
    ),
    findings AS (
        SELECT
            CASE WHEN used_percent >= 95 THEN 'HIGH' WHEN used_percent >= 85 THEN 'MEDIUM' ELSE 'LOW' END AS severity,
            'Space usage' AS health_area,
            'Database file is running low on free space' AS check_name,
            logical_name AS subject_name,
            type_desc,
            filegroup_name,
            size_gb,
            used_gb,
            used_percent,
            CONCAT('Physical name: ', physical_name) AS detail,
            'Review disk capacity, growth settings, and whether data cleanup or file expansion is needed.' AS recommendation
        FROM file_base
        WHERE used_percent >= 80

        UNION ALL

        SELECT
            'MEDIUM',
            'Autogrowth',
            'File uses percent autogrowth',
            logical_name,
            type_desc,
            filegroup_name,
            size_gb,
            used_gb,
            used_percent,
            CONCAT('Growth: ', growth, '%. Physical name: ', physical_name),
            'Prefer a fixed MB growth increment sized for the workload to reduce unpredictable growth events.'
        FROM file_base
        WHERE is_percent_growth = 1

        UNION ALL

        SELECT
            'LOW',
            'Autogrowth',
            'File has very small fixed autogrowth',
            logical_name,
            type_desc,
            filegroup_name,
            size_gb,
            used_gb,
            used_percent,
            CONCAT('Growth: ', CONVERT(decimal(19,2), growth / 128.0), ' MB. Physical name: ', physical_name),
            'Review growth increment to avoid frequent small autogrowth events.'
        FROM file_base
        WHERE is_percent_growth = 0
          AND growth > 0
          AND growth / 128.0 < 64

        UNION ALL

        SELECT
            CASE WHEN used_log_space_percent >= 90 THEN 'HIGH' ELSE 'MEDIUM' END,
            'Log usage',
            'Transaction log usage is elevated',
            DB_NAME(),
            'LOG',
            CAST(NULL AS sysname),
            CONVERT(decimal(19,2), total_log_size_mb / 1024.0),
            CONVERT(decimal(19,2), used_log_space_mb / 1024.0),
            used_log_space_percent,
            CONCAT('Log used: ', used_log_space_percent, '%.'),
            'Review active transactions, log backups, recovery model, and log reuse wait.'
        FROM log_usage
        WHERE used_log_space_percent >= 75

        UNION ALL

        SELECT
            'LOW',
            'File layout',
            'Multiple data files exist in same filegroup',
            filegroup_name,
            'ROWS',
            filegroup_name,
            SUM(size_gb),
            SUM(used_gb),
            CAST(NULL AS decimal(9,2)),
            CONCAT('File count: ', COUNT(*)),
            'Confirm multiple files are intentional and balanced for the storage layout.'
        FROM file_base
        WHERE type_desc = 'ROWS'
        GROUP BY filegroup_name
        HAVING COUNT(*) > 1
    )
    SELECT
        severity,
        health_area,
        check_name,
        subject_name,
        type_desc,
        filegroup_name,
        size_gb,
        used_gb,
        used_percent,
        detail,
        recommendation
    FROM findings
    ORDER BY
        CASE severity WHEN 'HIGH' THEN 1 WHEN 'MEDIUM' THEN 2 WHEN 'LOW' THEN 3 ELSE 4 END,
        health_area,
        subject_name;
END TRY
BEGIN CATCH
    SELECT
        'HIGH' AS severity,
        'Access' AS health_area,
        'Storage health could not be evaluated' AS check_name,
        ERROR_MESSAGE() AS subject_name,
        CAST(NULL AS varchar(20)) AS type_desc,
        CAST(NULL AS sysname) AS filegroup_name,
        CAST(NULL AS decimal(19,2)) AS size_gb,
        CAST(NULL AS decimal(19,2)) AS used_gb,
        CAST(NULL AS decimal(9,2)) AS used_percent,
        'The current login could not read all required storage metadata or DMVs.' AS detail,
        'Grant appropriate metadata/DMV permissions or rerun with a privileged review login.' AS recommendation;
END CATCH;
