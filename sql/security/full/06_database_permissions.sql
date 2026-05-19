-- name: database_permissions
-- title: DB permissions
-- description: Full inventory of explicit database permissions with grantor and securable metadata.
SELECT
    grantee.name AS grantee_name,
    grantee.principal_id AS grantee_principal_id,
    grantee.type_desc AS grantee_type,
    grantor.name AS grantor_name,
    grantor.principal_id AS grantor_principal_id,
    perm.state,
    perm.state_desc,
    perm.permission_name,
    perm.class,
    perm.class_desc,
    perm.major_id,
    perm.minor_id,
    CASE
        WHEN perm.class = 0 THEN CONVERT(nvarchar(256), DB_NAME())
        WHEN perm.class = 1 THEN CONVERT(nvarchar(256), CONCAT(OBJECT_SCHEMA_NAME(perm.major_id), '.', OBJECT_NAME(perm.major_id)))
        WHEN perm.class = 3 THEN CONVERT(nvarchar(256), SCHEMA_NAME(perm.major_id))
        WHEN perm.class = 4 THEN CONVERT(nvarchar(256), USER_NAME(perm.major_id))
        ELSE CONVERT(nvarchar(256), perm.major_id)
    END AS securable_name,
    CASE
        WHEN perm.class = 1 AND perm.minor_id > 0 THEN COL_NAME(perm.major_id, perm.minor_id)
        ELSE NULL
    END AS column_name
FROM sys.database_permissions AS perm
INNER JOIN sys.database_principals AS grantee
    ON grantee.principal_id = perm.grantee_principal_id
LEFT JOIN sys.database_principals AS grantor
    ON grantor.principal_id = perm.grantor_principal_id
WHERE grantee.name NOT LIKE '##%'
ORDER BY grantee.name, perm.class_desc, securable_name, column_name, perm.permission_name;
