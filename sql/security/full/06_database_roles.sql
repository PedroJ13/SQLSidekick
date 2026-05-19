-- name: database_roles
-- title: DB roles
-- description: Full inventory of fixed and custom database roles.
SELECT
    dp.name AS role_name,
    dp.principal_id,
    CASE WHEN dp.is_fixed_role = 1 THEN 'FIXED' ELSE 'CUSTOM' END AS role_category,
    dp.is_fixed_role,
    owner_principal.name AS owner_name,
    dp.owning_principal_id,
    CONVERT(varchar(16), dp.create_date, 120) AS create_date,
    CONVERT(varchar(16), dp.modify_date, 120) AS modify_date,
    dp.sid
FROM sys.database_principals AS dp
LEFT JOIN sys.database_principals AS owner_principal
    ON owner_principal.principal_id = dp.owning_principal_id
WHERE dp.type = 'R'
  AND dp.principal_id > 0
ORDER BY dp.is_fixed_role DESC, dp.name;
