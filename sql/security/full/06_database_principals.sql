-- name: database_principals
-- title: DB users
-- description: Full inventory of database users and principals.
SELECT
    dp.name AS principal_name,
    dp.principal_id,
    dp.type,
    dp.type_desc AS principal_type,
    dp.authentication_type,
    dp.authentication_type_desc,
    dp.default_schema_name,
    owning_principal.name AS owning_principal_name,
    CONVERT(varchar(16), dp.create_date, 120) AS create_date,
    CONVERT(varchar(16), dp.modify_date, 120) AS modify_date,
    dp.owning_principal_id,
    dp.sid
FROM sys.database_principals AS dp
LEFT JOIN sys.database_principals AS owning_principal
    ON owning_principal.principal_id = dp.owning_principal_id
WHERE dp.principal_id > 4
  AND dp.type NOT IN ('R')
  AND dp.name NOT LIKE '##%'
ORDER BY dp.type_desc, dp.name;
