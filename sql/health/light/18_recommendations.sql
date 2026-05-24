-- name: recommendations
-- title: Recommendations
-- description: Contextual recommended actions and suggested SQL based on online review findings.
SELECT
    CAST(NULL AS varchar(10)) AS severity,
    CAST(NULL AS nvarchar(120)) AS recommendation_area,
    CAST(NULL AS nvarchar(250)) AS finding,
    CAST(NULL AS nvarchar(512)) AS affected_object,
    CAST(NULL AS nvarchar(4000)) AS evidence,
    CAST(NULL AS nvarchar(4000)) AS impact_hint,
    CAST(NULL AS nvarchar(4000)) AS recommended_action,
    CAST(NULL AS nvarchar(max)) AS suggested_sql,
    CAST(NULL AS nvarchar(4000)) AS safety_notes
WHERE 1 = 0;
