-- name: server_logins
-- title: Server logins
-- description: Server principal inventory with login type, disabled state, default database, language, and password policy metadata where available.
BEGIN TRY
    SELECT
        sp.name AS login_name,
        sp.type,
        sp.type_desc,
        sp.is_disabled,
        sp.default_database_name,
        sp.default_language_name,
        CONVERT(varchar(16), sp.create_date, 120) AS create_date,
        CONVERT(varchar(16), sp.modify_date, 120) AS modify_date,
        sl.is_policy_checked,
        sl.is_expiration_checked,
        CONVERT(varchar(16), CONVERT(datetime, LOGINPROPERTY(sp.name, 'PasswordLastSetTime')), 120) AS password_last_set_time,
        CONVERT(nvarchar(4000), LOGINPROPERTY(sp.name, 'DaysUntilExpiration')) AS days_until_expiration,
        sp.principal_id,
        sp.sid
    FROM sys.server_principals AS sp
    LEFT JOIN sys.sql_logins AS sl
        ON sl.principal_id = sp.principal_id
    WHERE sp.type IN ('S', 'U', 'G', 'R', 'C', 'K')
      AND sp.name NOT LIKE '##%'
    ORDER BY sp.type_desc, sp.name;
END TRY
BEGIN CATCH
    SELECT
        ERROR_MESSAGE() AS login_name,
        CAST(NULL AS char(1)) AS type,
        CAST(NULL AS nvarchar(60)) AS type_desc,
        CAST(NULL AS bit) AS is_disabled,
        CAST(NULL AS sysname) AS default_database_name,
        CAST(NULL AS sysname) AS default_language_name,
        CAST(NULL AS varchar(16)) AS create_date,
        CAST(NULL AS varchar(16)) AS modify_date,
        CAST(NULL AS bit) AS is_policy_checked,
        CAST(NULL AS bit) AS is_expiration_checked,
        CAST(NULL AS varchar(16)) AS password_last_set_time,
        CAST(NULL AS nvarchar(4000)) AS days_until_expiration,
        CAST(NULL AS int) AS principal_id,
        CAST(NULL AS varbinary(85)) AS sid;
END CATCH;
