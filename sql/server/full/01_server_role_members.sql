-- name: server_role_members
-- title: Server role members
-- description: Server role membership for fixed and custom server roles.
BEGIN TRY
    SELECT
        role_principal.name AS server_role_name,
        role_principal.type_desc AS server_role_type,
        member_principal.name AS member_name,
        member_principal.type_desc AS member_type,
        member_principal.is_disabled AS member_is_disabled,
        CONVERT(varchar(16), member_principal.create_date, 120) AS member_create_date,
        CONVERT(varchar(16), member_principal.modify_date, 120) AS member_modify_date
    FROM sys.server_role_members AS srm
    INNER JOIN sys.server_principals AS role_principal
        ON role_principal.principal_id = srm.role_principal_id
    INNER JOIN sys.server_principals AS member_principal
        ON member_principal.principal_id = srm.member_principal_id
    ORDER BY role_principal.name, member_principal.name;
END TRY
BEGIN CATCH
    SELECT
        ERROR_MESSAGE() AS server_role_name,
        CAST(NULL AS nvarchar(60)) AS server_role_type,
        CAST(NULL AS sysname) AS member_name,
        CAST(NULL AS nvarchar(60)) AS member_type,
        CAST(NULL AS bit) AS member_is_disabled,
        CAST(NULL AS varchar(16)) AS member_create_date,
        CAST(NULL AS varchar(16)) AS member_modify_date;
END CATCH;
