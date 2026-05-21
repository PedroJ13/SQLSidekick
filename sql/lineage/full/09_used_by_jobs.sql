-- name: used_by_jobs
-- title: Used by jobs
-- description: Full object-to-job usage view from SQL Agent steps and catalog dependencies.
BEGIN TRY
    WITH step_commands AS (
        SELECT
            j.name AS process_name,
            j.job_id,
            js.step_id,
            js.step_name,
            js.database_name,
            js.subsystem,
            js.command,
            CASE
                WHEN PATINDEX('%execute %', LOWER(js.command)) > 0 THEN PATINDEX('%execute %', LOWER(js.command)) + 8
                WHEN PATINDEX('%exec %', LOWER(js.command)) > 0 THEN PATINDEX('%exec %', LOWER(js.command)) + 5
                ELSE 0
            END AS object_start
        FROM msdb.dbo.sysjobsteps AS js
        INNER JOIN msdb.dbo.sysjobs AS j
            ON j.job_id = js.job_id
        WHERE js.subsystem = 'TSQL'
    ),
    detected AS (
        SELECT
            process_name,
            job_id,
            step_id,
            step_name,
            database_name,
            command,
            LTRIM(RTRIM(
                REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                    LEFT(SUBSTRING(command, object_start, 4000), CHARINDEX(' ', SUBSTRING(command, object_start, 4000) + ' ') - 1),
                    '[', ''), ']', ''), ';', ''), CHAR(9), ''), CHAR(10), '')
            )) AS called_object
        FROM step_commands
        WHERE object_start > 0
    ),
    resolved AS (
        SELECT
            process_name,
            job_id,
            step_id,
            step_name,
            database_name,
            COALESCE(PARSENAME(called_object, 2), 'dbo') AS called_schema,
            PARSENAME(called_object, 1) AS called_object_name,
            called_object AS called_object_text,
            OBJECT_ID(QUOTENAME(COALESCE(PARSENAME(called_object, 2), 'dbo')) + '.' + QUOTENAME(PARSENAME(called_object, 1))) AS called_object_id,
            LEFT(REPLACE(REPLACE(command, CHAR(13), ' '), CHAR(10), ' '), 500) AS command_preview
        FROM detected
        WHERE called_object IS NOT NULL
          AND called_object <> ''
          AND called_object NOT LIKE '@%'
    )
    SELECT
        COALESCE(target_schema.name, sed.referenced_schema_name) AS referenced_schema,
        COALESCE(target_object.name, sed.referenced_entity_name) AS referenced_object,
        target_object.type_desc AS referenced_type,
        sed.referenced_server_name,
        sed.referenced_database_name,
        process_name,
        job_id,
        step_id AS step_order,
        step_name,
        database_name,
        called_schema,
        called_object_name,
        called_object_id,
        'Job step EXEC + catalog dependency' AS detection_method,
        CASE
            WHEN resolved.called_object_id IS NOT NULL AND sed.referenced_id IS NOT NULL THEN 'High'
            WHEN resolved.called_object_id IS NOT NULL THEN 'Medium'
            ELSE 'Low'
        END AS confidence,
        command_preview
    FROM resolved
    LEFT JOIN sys.sql_expression_dependencies AS sed
        ON sed.referencing_id = resolved.called_object_id
    LEFT JOIN sys.objects AS target_object
        ON target_object.object_id = sed.referenced_id
    LEFT JOIN sys.schemas AS target_schema
        ON target_schema.schema_id = target_object.schema_id
    WHERE COALESCE(target_object.name, sed.referenced_entity_name) IS NOT NULL
    ORDER BY referenced_schema, referenced_object, process_name, step_id;
END TRY
BEGIN CATCH
    SELECT
        ERROR_MESSAGE() AS referenced_schema,
        CAST(NULL AS sysname) AS referenced_object,
        CAST(NULL AS nvarchar(60)) AS referenced_type,
        CAST(NULL AS sysname) AS referenced_server_name,
        CAST(NULL AS sysname) AS referenced_database_name,
        CAST(NULL AS sysname) AS process_name,
        CAST(NULL AS uniqueidentifier) AS job_id,
        CAST(NULL AS int) AS step_order,
        CAST(NULL AS sysname) AS step_name,
        CAST(NULL AS sysname) AS database_name,
        CAST(NULL AS sysname) AS called_schema,
        CAST(NULL AS sysname) AS called_object_name,
        CAST(NULL AS int) AS called_object_id,
        CAST(NULL AS varchar(40)) AS detection_method,
        CAST(NULL AS varchar(10)) AS confidence,
        CAST(NULL AS nvarchar(500)) AS command_preview;
END CATCH;
