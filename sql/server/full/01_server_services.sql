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
    CONVERT(varchar(16), last_startup_time, 120) AS last_startup_time,
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
            CAST(NULL AS varchar(16)) AS last_startup_time,
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
        CAST(NULL AS varchar(16)) AS last_startup_time,
        CAST(NULL AS nvarchar(256)) AS service_account,
        CAST(NULL AS nvarchar(4000)) AS executable_path,
        ERROR_MESSAGE() AS access_note;
END CATCH;
