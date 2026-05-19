-- name: database_roles
-- title: DB roles
-- description: Light inventory of fixed and custom database roles.
SELECT
    dp.name AS role_name,
    CASE WHEN dp.is_fixed_role = 1 THEN 'FIXED' ELSE 'CUSTOM' END AS role_category,
    owner_principal.name AS owner_name,
    CONVERT(varchar(16), dp.create_date, 120) AS create_date,
    CONVERT(varchar(16), dp.modify_date, 120) AS modify_date
FROM sys.database_principals AS dp
LEFT JOIN sys.database_principals AS owner_principal
    ON owner_principal.principal_id = dp.owning_principal_id
WHERE dp.type = 'R'
  AND dp.principal_id > 0
ORDER BY dp.is_fixed_role DESC, dp.name;
