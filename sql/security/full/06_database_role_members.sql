-- name: database_role_members
-- title: DB role members
-- description: Full inventory of database role memberships.
SELECT
    role_principal.name AS role_name,
    role_principal.principal_id AS role_principal_id,
    role_principal.is_fixed_role,
    member_principal.name AS member_name,
    member_principal.principal_id AS member_principal_id,
    member_principal.type_desc AS member_type,
    member_principal.authentication_type_desc,
    member_principal.default_schema_name,
    CONVERT(varchar(16), member_principal.create_date, 120) AS member_create_date,
    CONVERT(varchar(16), member_principal.modify_date, 120) AS member_modify_date
FROM sys.database_role_members AS drm
INNER JOIN sys.database_principals AS role_principal
    ON role_principal.principal_id = drm.role_principal_id
INNER JOIN sys.database_principals AS member_principal
    ON member_principal.principal_id = drm.member_principal_id
ORDER BY role_principal.name, member_principal.name;
