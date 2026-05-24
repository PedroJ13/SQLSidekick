-- name: impact_analysis
-- title: Impact analysis
-- description: Online risk analysis for object changes using dependencies, table features, and related jobs.
SELECT
    CAST(NULL AS varchar(30)) AS impact_section,
    CAST(NULL AS varchar(30)) AS impact_direction,
    CAST(NULL AS int) AS impact_depth,
    CAST(NULL AS sysname) AS affected_schema,
    CAST(NULL AS sysname) AS affected_object,
    CAST(NULL AS nvarchar(80)) AS affected_type,
    CAST(NULL AS sysname) AS referenced_schema,
    CAST(NULL AS sysname) AS referenced_object,
    CAST(NULL AS sysname) AS referenced_column,
    CAST(NULL AS nvarchar(4000)) AS evidence,
    CAST(NULL AS nvarchar(4000)) AS code_fragment,
    CAST(NULL AS varchar(10)) AS confidence,
    CAST(NULL AS nvarchar(4000)) AS risk_signal
WHERE 1 = 0;
