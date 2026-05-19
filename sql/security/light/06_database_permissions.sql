-- name: database_permissions
-- title: DB permissions
-- description: Light inventory of explicit database permissions.
SELECT
    grantee.name AS grantee_name,
    grantee.type_desc AS grantee_type,
    perm.state_desc,
    perm.permission_name,
    perm.class_desc,
    CASE
        WHEN perm.class = 0 THEN DB_NAME()
        WHEN perm.class = 1 THEN CONCAT(OBJECT_SCHEMA_NAME(perm.major_id), '.', OBJECT_NAME(perm.major_id))
        WHEN perm.class = 3 THEN SCHEMA_NAME(perm.major_id)
        ELSE CONVERT(nvarchar(256), perm.major_id)
    END AS securable_name
FROM sys.database_permissions AS perm
INNER JOIN sys.database_principals AS grantee
    ON grantee.principal_id = perm.grantee_principal_id
WHERE grantee.name NOT LIKE '##%'
ORDER BY grantee.name, perm.class_desc, securable_name, perm.permission_name;
