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
