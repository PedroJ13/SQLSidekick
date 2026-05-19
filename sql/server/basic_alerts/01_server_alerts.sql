-- name: server_alerts
-- title: Server alerts
-- description: Server-level alert flags grouped by impact. Returns only alerts that are currently on, without object-level details.
CREATE TABLE #server_alerts (
    severity varchar(10) NOT NULL,
    alert_category varchar(40) NOT NULL,
    alert_name varchar(160) NOT NULL,
    active_count int NULL
);

BEGIN TRY
    INSERT INTO #server_alerts (severity, alert_category, alert_name, active_count)
    SELECT
        'HIGH',
        'CONFIGURATION',
        'xp_cmdshell is enabled',
        COUNT(*)
    FROM sys.configurations
    WHERE name = 'xp_cmdshell'
      AND CONVERT(int, value_in_use) = 1
    HAVING COUNT(*) > 0;

    INSERT INTO #server_alerts (severity, alert_category, alert_name, active_count)
    SELECT
        'HIGH',
        'CONFIGURATION',
        'Ole Automation Procedures is enabled',
        COUNT(*)
    FROM sys.configurations
    WHERE name = 'Ole Automation Procedures'
      AND CONVERT(int, value_in_use) = 1
    HAVING COUNT(*) > 0;

    INSERT INTO #server_alerts (severity, alert_category, alert_name, active_count)
    SELECT
        'HIGH',
        'SECURITY',
        'SQL logins without password policy enforcement',
        COUNT(*)
    FROM sys.sql_logins
    WHERE is_disabled = 0
      AND is_policy_checked = 0
      AND name NOT LIKE '##%'
    HAVING COUNT(*) > 0;

    INSERT INTO #server_alerts (severity, alert_category, alert_name, active_count)
    SELECT
        'HIGH',
        'SECURITY',
        'Members in sysadmin server role',
        COUNT(*)
    FROM sys.server_role_members AS srm
    INNER JOIN sys.server_principals AS role_principal
        ON role_principal.principal_id = srm.role_principal_id
    INNER JOIN sys.server_principals AS member_principal
        ON member_principal.principal_id = srm.member_principal_id
    WHERE role_principal.name = 'sysadmin'
      AND member_principal.name NOT LIKE '##%'
    HAVING COUNT(*) > 0;

    INSERT INTO #server_alerts (severity, alert_category, alert_name, active_count)
    SELECT
        'MEDIUM',
        'CONFIGURATION',
        'Ad Hoc Distributed Queries is enabled',
        COUNT(*)
    FROM sys.configurations
    WHERE name = 'Ad Hoc Distributed Queries'
      AND CONVERT(int, value_in_use) = 1
    HAVING COUNT(*) > 0;

    INSERT INTO #server_alerts (severity, alert_category, alert_name, active_count)
    SELECT
        'MEDIUM',
        'CONFIGURATION',
        'Remote admin connections is enabled',
        COUNT(*)
    FROM sys.configurations
    WHERE name = 'remote admin connections'
      AND CONVERT(int, value_in_use) = 1
    HAVING COUNT(*) > 0;

    INSERT INTO #server_alerts (severity, alert_category, alert_name, active_count)
    SELECT
        'MEDIUM',
        'CONFIGURATION',
        'Max server memory is unlimited/default',
        COUNT(*)
    FROM sys.configurations
    WHERE name = 'max server memory (MB)'
      AND CONVERT(int, value_in_use) >= 2147483647
    HAVING COUNT(*) > 0;

    INSERT INTO #server_alerts (severity, alert_category, alert_name, active_count)
    SELECT
        'MEDIUM',
        'CONFIGURATION',
        'Max degree of parallelism is set to 0',
        COUNT(*)
    FROM sys.configurations
    WHERE name = 'max degree of parallelism'
      AND CONVERT(int, value_in_use) = 0
    HAVING COUNT(*) > 0;

    INSERT INTO #server_alerts (severity, alert_category, alert_name, active_count)
    SELECT
        'MEDIUM',
        'CONFIGURATION',
        'Cost threshold for parallelism is default or very low',
        COUNT(*)
    FROM sys.configurations
    WHERE name = 'cost threshold for parallelism'
      AND CONVERT(int, value_in_use) <= 5
    HAVING COUNT(*) > 0;

    INSERT INTO #server_alerts (severity, alert_category, alert_name, active_count)
    SELECT
        'MEDIUM',
        'CONFIGURATION',
        'CLR integration is enabled',
        COUNT(*)
    FROM sys.configurations
    WHERE name = 'clr enabled'
      AND CONVERT(int, value_in_use) = 1
    HAVING COUNT(*) > 0;

    INSERT INTO #server_alerts (severity, alert_category, alert_name, active_count)
    SELECT
        'MEDIUM',
        'SECURITY',
        'Members in elevated server roles',
        COUNT(*)
    FROM sys.server_role_members AS srm
    INNER JOIN sys.server_principals AS role_principal
        ON role_principal.principal_id = srm.role_principal_id
    INNER JOIN sys.server_principals AS member_principal
        ON member_principal.principal_id = srm.member_principal_id
    WHERE role_principal.name IN ('securityadmin', 'serveradmin', 'setupadmin', 'processadmin', 'diskadmin', 'dbcreator', 'bulkadmin')
      AND member_principal.name NOT LIKE '##%'
    HAVING COUNT(*) > 0;

    INSERT INTO #server_alerts (severity, alert_category, alert_name, active_count)
    SELECT
        'LOW',
        'CONFIGURATION',
        'Optimize for ad hoc workloads is disabled',
        COUNT(*)
    FROM sys.configurations
    WHERE name = 'optimize for ad hoc workloads'
      AND CONVERT(int, value_in_use) = 0
    HAVING COUNT(*) > 0;

    INSERT INTO #server_alerts (severity, alert_category, alert_name, active_count)
    SELECT
        'LOW',
        'CONFIGURATION',
        'Backup compression default is disabled',
        COUNT(*)
    FROM sys.configurations
    WHERE name = 'backup compression default'
      AND CONVERT(int, value_in_use) = 0
    HAVING COUNT(*) > 0;

    INSERT INTO #server_alerts (severity, alert_category, alert_name, active_count)
    SELECT
        'LOW',
        'INTEGRATION',
        'Linked servers are configured',
        COUNT(*)
    FROM sys.servers
    WHERE is_linked = 1
    HAVING COUNT(*) > 0;
END TRY
BEGIN CATCH
    INSERT INTO #server_alerts (severity, alert_category, alert_name, active_count)
    VALUES ('MEDIUM', 'ACCESS', 'Some server configuration alerts could not be evaluated', NULL);
END CATCH;

BEGIN TRY
    IF OBJECT_ID('sys.dm_server_services') IS NOT NULL
    BEGIN
        INSERT INTO #server_alerts (severity, alert_category, alert_name, active_count)
        EXEC(N'
SELECT
    ''MEDIUM'' AS severity,
    ''SERVICE'' AS alert_category,
    ''SQL Server Agent service is not running'' AS alert_name,
    COUNT(*) AS active_count
FROM sys.dm_server_services
WHERE servicename LIKE ''SQL Server Agent%''
  AND status_desc <> ''Running''
HAVING COUNT(*) > 0;');
    END;
END TRY
BEGIN CATCH
    INSERT INTO #server_alerts (severity, alert_category, alert_name, active_count)
    VALUES ('LOW', 'ACCESS', 'SQL Server service status could not be evaluated', NULL);
END CATCH;

BEGIN TRY
    IF OBJECT_ID('sys.dm_hadr_availability_replica_states') IS NOT NULL
    BEGIN
        INSERT INTO #server_alerts (severity, alert_category, alert_name, active_count)
        EXEC(N'
SELECT
    ''HIGH'' AS severity,
    ''AVAILABILITY'' AS alert_category,
    ''Availability Group replica synchronization is not healthy'' AS alert_name,
    COUNT(*) AS active_count
FROM sys.dm_hadr_availability_replica_states
WHERE synchronization_health_desc <> ''HEALTHY''
HAVING COUNT(*) > 0;');
    END;
END TRY
BEGIN CATCH
    INSERT INTO #server_alerts (severity, alert_category, alert_name, active_count)
    VALUES ('LOW', 'ACCESS', 'Availability Group health could not be evaluated', NULL);
END CATCH;

WITH ranked_alerts AS (
    SELECT
        severity,
        alert_category,
        alert_name,
        active_count,
        MIN(CASE severity
            WHEN 'HIGH' THEN 1
            WHEN 'MEDIUM' THEN 2
            WHEN 'LOW' THEN 3
            ELSE 4
        END) OVER () AS highest_detected_severity_rank
    FROM #server_alerts
)
SELECT
    CASE highest_detected_severity_rank
        WHEN 1 THEN 'HIGH'
        WHEN 2 THEN 'MEDIUM'
        WHEN 3 THEN 'LOW'
        ELSE 'UNKNOWN'
    END AS highest_detected_severity,
    severity,
    alert_category,
    alert_name,
    active_count
FROM ranked_alerts
ORDER BY
    CASE severity
        WHEN 'HIGH' THEN 1
        WHEN 'MEDIUM' THEN 2
        WHEN 'LOW' THEN 3
        ELSE 4
    END,
    alert_category,
    alert_name;

DROP TABLE #server_alerts;
