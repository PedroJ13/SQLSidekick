-- name: database_principals
-- title: DB users
-- description: Light inventory of database users and principals.
SELECT
    dp.name AS principal_name,
    dp.type_desc AS principal_type,
    dp.authentication_type_desc,
    dp.default_schema_name,
    CONVERT(varchar(16), dp.create_date, 120) AS create_date,
    CONVERT(varchar(16), dp.modify_date, 120) AS modify_date
FROM sys.database_principals AS dp
WHERE dp.principal_id > 4
  AND dp.type NOT IN ('R')
  AND dp.name NOT LIKE '##%'
ORDER BY dp.type_desc, dp.name;
