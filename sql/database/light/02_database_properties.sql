-- name: database_properties
-- title: Database properties
-- description: Light database properties with the most relevant documentation settings.
SELECT
    d.name AS database_name,
    d.state_desc,
    d.user_access_desc,
    d.recovery_model_desc,
    d.page_verify_option_desc,
    d.snapshot_isolation_state_desc,
    d.is_read_committed_snapshot_on,
    d.is_auto_create_stats_on,
    d.is_auto_update_stats_on,
    d.is_query_store_on,
    d.is_broker_enabled,
    d.is_cdc_enabled,
    d.is_encrypted,
    d.log_reuse_wait_desc
FROM sys.databases AS d
WHERE d.name = DB_NAME();
