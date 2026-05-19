-- name: database_role_members
-- title: DB role members
-- description: Light inventory of database role memberships.
SELECT
    role_principal.name AS role_name,
    member_principal.name AS member_name,
    member_principal.type_desc AS member_type
FROM sys.database_role_members AS drm
INNER JOIN sys.database_principals AS role_principal
    ON role_principal.principal_id = drm.role_principal_id
INNER JOIN sys.database_principals AS member_principal
    ON member_principal.principal_id = drm.member_principal_id
ORDER BY role_principal.name, member_principal.name;
