from __future__ import annotations

import json
import mimetypes
from http.server import BaseHTTPRequestHandler
from pathlib import Path
from typing import Any
from urllib.parse import parse_qs, urlparse

from sqlsidekick.query_loader import load_named_queries, normalize_version
from sqlsidekick.sql_server import ConnectionSettings, SQLServerError, execute_query, test_connection


class SQLSidekickHandler(BaseHTTPRequestHandler):
    root: Path
    queries_path: Path
    static_path: Path

    @classmethod
    def configure(cls, root: Path) -> None:
        cls.root = root
        cls.queries_path = root / "sql"
        cls.static_path = root / "static"

    def do_GET(self) -> None:
        try:
            parsed = urlparse(self.path)
            if parsed.path == "/":
                self.serve_file(self.static_path / "index.html")
                return
            if parsed.path == "/api/health":
                self.send_json({"ok": True, "name": "SQLSidekick"})
                return
            if parsed.path == "/api/queries":
                version = self.requested_version(parsed)
                queries = load_named_queries(self.queries_path, version=version)
                self.send_json(
                    {
                        "version": version,
                        "queries": [
                            {
                                "name": query.name,
                                "title": query.title,
                                "description": query.description,
                            }
                            for query in queries.values()
                        ]
                    }
                )
                return
            if parsed.path == "/api/default-connection":
                self.send_json({"connection": self.load_default_connection()})
                return
            if parsed.path == "/api/query-sql":
                name = parse_qs(parsed.query).get("name", [""])[0]
                version = self.requested_version(parsed)
                queries = load_named_queries(self.queries_path, version=version)
                if name not in queries:
                    self.send_json({"error": "Consulta no encontrada."}, status=404)
                    return
                self.send_json({"name": name, "version": version, "sql": queries[name].sql})
                return
            if parsed.path.startswith("/static/"):
                relative = parsed.path.removeprefix("/static/")
                self.serve_file(self.static_path / relative)
                return
            self.send_json({"error": "Ruta no encontrada."}, status=404)
        except Exception as exc:
            self.send_json({"ok": False, "error": f"Error inesperado: {exc}"}, status=500)

    def do_POST(self) -> None:
        parsed = urlparse(self.path)
        if parsed.path == "/api/test-connection":
            self.handle_sql_action(test_connection)
            return
        if parsed.path == "/api/run-query":
            self.handle_run_query()
            return
        if parsed.path == "/api/run-alerts":
            self.handle_run_alerts()
            return
        if parsed.path == "/api/table-detail":
            self.handle_table_detail()
            return
        if parsed.path == "/api/code-object-detail":
            self.handle_code_object_detail()
            return
        if parsed.path == "/api/process-detail":
            self.handle_process_detail()
            return
        if parsed.path == "/api/process-step-sql-objects":
            self.handle_process_step_sql_objects()
            return
        self.send_json({"error": "Ruta no encontrada."}, status=404)

    def handle_run_query(self) -> None:
        payload = self.read_json()
        name = str(payload.get("queryName", "")).strip()
        version = normalize_version(str(payload.get("scriptVersion", "full")))
        queries = load_named_queries(self.queries_path, version=version)
        if name not in queries:
            self.send_json({"error": "Consulta no encontrada."}, status=404)
            return

        def action(settings: ConnectionSettings) -> dict[str, Any]:
            return execute_query(settings, queries[name].sql)

        self.handle_sql_action(action, payload=payload)

    def handle_run_alerts(self) -> None:
        payload = self.read_json()
        category = self.safe_category_name(str(payload.get("category", "")).strip().lower())
        if not category:
            self.send_json({"error": "Categoria de alertas no valida."}, status=400)
            return

        alert_path = self.queries_path / category / "basic_alerts"
        if not alert_path.is_dir():
            self.send_json({"ok": True, "category": category, "resultSets": [], "messages": ["No alert script found."]})
            return

        queries = load_named_queries(alert_path)
        if not queries:
            self.send_json({"ok": True, "category": category, "resultSets": [], "messages": ["No alert queries found."]})
            return

        def action(settings: ConnectionSettings) -> dict[str, Any]:
            result_sets: list[dict[str, Any]] = []
            messages: list[str] = []
            for query in queries.values():
                result = execute_query(settings, query.sql)
                result_sets.extend(result.get("resultSets", []))
                messages.extend(result.get("messages", []))
            return {"category": category, "resultSets": result_sets, "messages": messages}

        self.handle_sql_action(action, payload=payload)

    def handle_table_detail(self) -> None:
        payload = self.read_json()
        schema_name = str(payload.get("schemaName", "")).strip()
        table_name = str(payload.get("tableName", "")).strip()
        if not schema_name or not table_name:
            self.send_json({"error": "Schema and table are required."}, status=400)
            return

        sql = table_detail_sql(schema_name, table_name)

        def action(settings: ConnectionSettings) -> dict[str, Any]:
            return execute_query(settings, sql)

        self.handle_sql_action(action, payload=payload)

    def handle_code_object_detail(self) -> None:
        payload = self.read_json()
        schema_name = str(payload.get("schemaName", "")).strip()
        object_name = str(payload.get("objectName", "")).strip()
        if not schema_name or not object_name:
            self.send_json({"error": "Schema and object are required."}, status=400)
            return

        sql = code_object_detail_sql(schema_name, object_name)

        def action(settings: ConnectionSettings) -> dict[str, Any]:
            return execute_query(settings, sql)

        self.handle_sql_action(action, payload=payload)

    def handle_process_detail(self) -> None:
        payload = self.read_json()
        process_name = str(payload.get("processName", "")).strip()
        job_id = str(payload.get("jobId", "")).strip()
        if not process_name:
            self.send_json({"error": "Process name is required."}, status=400)
            return

        sql = process_detail_sql(process_name, job_id)

        def action(settings: ConnectionSettings) -> dict[str, Any]:
            return execute_query(settings, sql)

        self.handle_sql_action(action, payload=payload)

    def handle_process_step_sql_objects(self) -> None:
        payload = self.read_json()
        process_name = str(payload.get("processName", "")).strip()
        job_id = str(payload.get("jobId", "")).strip()
        step_order = int(payload.get("stepOrder", 0) or 0)
        if not process_name or step_order <= 0:
            self.send_json({"error": "Process name and step order are required."}, status=400)
            return

        sql = process_step_sql_objects_sql(process_name, step_order, job_id)

        def action(settings: ConnectionSettings) -> dict[str, Any]:
            return execute_query(settings, sql)

        self.handle_sql_action(action, payload=payload)

    def handle_sql_action(self, action: Any, payload: dict[str, Any] | None = None) -> None:
        try:
            body = payload if payload is not None else self.read_json()
            settings = ConnectionSettings.from_payload(body.get("connection", body))
            result = action(settings)
            self.send_json({"ok": True, **result})
        except SQLServerError as exc:
            self.send_json({"ok": False, "error": str(exc)}, status=400)
        except Exception as exc:
            self.send_json({"ok": False, "error": f"Error inesperado: {exc}"}, status=500)

    def read_json(self) -> dict[str, Any]:
        length = int(self.headers.get("Content-Length", "0"))
        if length == 0:
            return {}
        raw = self.rfile.read(length).decode("utf-8")
        return json.loads(raw)

    def load_default_connection(self) -> dict[str, Any] | None:
        path = self.root / "local_connection.json"
        if not path.is_file():
            return None
        return json.loads(path.read_text(encoding="utf-8-sig"))

    def requested_version(self, parsed: Any) -> str:
        return normalize_version(parse_qs(parsed.query).get("version", ["full"])[0])

    def safe_category_name(self, value: str) -> str:
        return "".join(char for char in value if char.isalnum() or char in {"_", "-"})

    def serve_file(self, path: Path) -> None:
        resolved = path.resolve()
        if not str(resolved).startswith(str(self.root.resolve())) or not resolved.is_file():
            self.send_json({"error": "Archivo no encontrado."}, status=404)
            return
        content_type = mimetypes.guess_type(str(resolved))[0] or "application/octet-stream"
        data = resolved.read_bytes()
        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def send_json(self, payload: dict[str, Any], status: int = 200) -> None:
        data = json.dumps(payload, ensure_ascii=True, default=str).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, format: str, *args: Any) -> None:
        return


def sql_literal(value: str) -> str:
    return "N'" + value.replace("'", "''") + "'"


def table_detail_sql(schema_name: str, table_name: str) -> str:
    schema_value = sql_literal(schema_name)
    table_value = sql_literal(table_name)
    return f"""
DECLARE @schema_name sysname = {schema_value};
DECLARE @table_name sysname = {table_value};
DECLARE @object_id int = OBJECT_ID(QUOTENAME(@schema_name) + N'.' + QUOTENAME(@table_name));

SELECT
    c.column_id,
    c.name AS column_name,
    TYPE_NAME(c.user_type_id) AS data_type,
    CASE
        WHEN TYPE_NAME(c.user_type_id) IN ('varchar', 'char', 'varbinary', 'binary')
            THEN CASE WHEN c.max_length = -1 THEN 'max' ELSE CONVERT(varchar(20), c.max_length) END
        WHEN TYPE_NAME(c.user_type_id) IN ('nvarchar', 'nchar')
            THEN CASE WHEN c.max_length = -1 THEN 'max' ELSE CONVERT(varchar(20), c.max_length / 2) END
        WHEN TYPE_NAME(c.user_type_id) IN ('decimal', 'numeric')
            THEN CONCAT(c.precision, ',', c.scale)
        ELSE NULL
    END AS type_detail,
    c.is_nullable,
    c.is_identity,
    c.is_computed,
    dc.definition AS default_definition
FROM sys.columns AS c
LEFT JOIN sys.default_constraints AS dc
    ON dc.parent_object_id = c.object_id
    AND dc.parent_column_id = c.column_id
WHERE c.object_id = @object_id
ORDER BY c.column_id;

SELECT
    i.name AS index_name,
    i.type_desc,
    i.is_unique,
    i.is_primary_key,
    i.is_unique_constraint,
    ic.key_ordinal,
    ic.index_column_id,
    c.name AS column_name,
    ic.is_included_column,
    ic.is_descending_key,
    i.filter_definition
FROM sys.indexes AS i
LEFT JOIN sys.index_columns AS ic
    ON ic.object_id = i.object_id
    AND ic.index_id = i.index_id
LEFT JOIN sys.columns AS c
    ON c.object_id = ic.object_id
    AND c.column_id = ic.column_id
WHERE i.object_id = @object_id
  AND i.index_id > 0
ORDER BY i.is_primary_key DESC, i.name, ic.is_included_column, ic.key_ordinal, ic.index_column_id;

SELECT
    fk.name AS foreign_key_name,
    CASE WHEN fk.parent_object_id = @object_id THEN 'outgoing' ELSE 'incoming' END AS relationship_direction,
    parent_schema = ps.name,
    parent_table = pt.name,
    parent_column = pc.name,
    referenced_schema = rs.name,
    referenced_table = rt.name,
    referenced_column = rc.name,
    fk.delete_referential_action_desc,
    fk.update_referential_action_desc,
    fk.is_disabled,
    fk.is_not_trusted
FROM sys.foreign_keys AS fk
INNER JOIN sys.foreign_key_columns AS fkc
    ON fkc.constraint_object_id = fk.object_id
INNER JOIN sys.tables AS pt
    ON pt.object_id = fkc.parent_object_id
INNER JOIN sys.schemas AS ps
    ON ps.schema_id = pt.schema_id
INNER JOIN sys.columns AS pc
    ON pc.object_id = fkc.parent_object_id
    AND pc.column_id = fkc.parent_column_id
INNER JOIN sys.tables AS rt
    ON rt.object_id = fkc.referenced_object_id
INNER JOIN sys.schemas AS rs
    ON rs.schema_id = rt.schema_id
INNER JOIN sys.columns AS rc
    ON rc.object_id = fkc.referenced_object_id
    AND rc.column_id = fkc.referenced_column_id
WHERE fk.parent_object_id = @object_id
   OR fk.referenced_object_id = @object_id
ORDER BY relationship_direction, fk.name, fkc.constraint_column_id;

WITH referencing_code AS (
    SELECT DISTINCT
        s.name AS schema_name,
        o.name AS object_name,
        o.type_desc AS object_type,
        CONVERT(varchar(16), o.create_date, 120) AS create_date,
        CONVERT(varchar(16), o.modify_date, 120) AS modify_date
    FROM sys.sql_expression_dependencies AS sed
    INNER JOIN sys.objects AS o
        ON o.object_id = sed.referencing_id
    INNER JOIN sys.schemas AS s
        ON s.schema_id = o.schema_id
    WHERE o.is_ms_shipped = 0
      AND o.object_id <> @object_id
      AND o.type IN ('V', 'P', 'FN', 'IF', 'TF', 'TR')
      AND (
          sed.referenced_id = @object_id
          OR (
              sed.referenced_schema_name = @schema_name
              AND sed.referenced_entity_name = @table_name
          )
      )
)
SELECT
    schema_name,
    object_name,
    object_type,
    create_date,
    modify_date
FROM referencing_code;
"""


def code_object_detail_sql(schema_name: str, object_name: str) -> str:
    schema_value = sql_literal(schema_name)
    object_value = sql_literal(object_name)
    return f"""
DECLARE @schema_name sysname = {schema_value};
DECLARE @object_name sysname = {object_value};
DECLARE @object_id int = OBJECT_ID(QUOTENAME(@schema_name) + N'.' + QUOTENAME(@object_name));

WITH referenced_objects AS (
    SELECT DISTINCT
        COALESCE(referenced_schema.name, sed.referenced_schema_name) AS referenced_schema_name,
        COALESCE(referenced_object.name, sed.referenced_entity_name) AS referenced_object_name,
        referenced_object.type_desc AS referenced_object_type,
        sed.referenced_database_name,
        sed.referenced_server_name,
        CASE WHEN referenced_object.type = 'U' THEN 1 ELSE 0 END AS is_table_reference
    FROM sys.sql_expression_dependencies AS sed
    LEFT JOIN sys.objects AS referenced_object
        ON referenced_object.object_id = sed.referenced_id
    LEFT JOIN sys.schemas AS referenced_schema
        ON referenced_schema.schema_id = referenced_object.schema_id
    WHERE sed.referencing_id = @object_id
)
SELECT
    referenced_schema_name,
    referenced_object_name,
    referenced_object_type,
    referenced_database_name,
    referenced_server_name,
    is_table_reference
FROM referenced_objects;
"""


def uniqueidentifier_literal(value: str) -> str:
    stripped = value.strip()
    if not stripped:
        return "NULL"
    return "TRY_CONVERT(uniqueidentifier, " + sql_literal(stripped) + ")"


def process_detail_sql(process_name: str, job_id: str = "") -> str:
    process_value = sql_literal(process_name)
    job_id_value = uniqueidentifier_literal(job_id)
    return f"""
DECLARE @process_name sysname = {process_value};
DECLARE @job_id uniqueidentifier = {job_id_value};
DECLARE @steps_error nvarchar(4000) = NULL;

IF @job_id IS NULL
BEGIN
    SELECT @job_id = job_id
    FROM msdb.dbo.sysjobs
    WHERE name = @process_name;
END;

SELECT
    j.name AS process_name,
    j.job_id,
    CASE WHEN j.enabled = 1 THEN 'Enabled' ELSE 'Disabled' END AS process_status,
    SUSER_SNAME(j.owner_sid) AS owner_name,
    c.name AS category_name,
    j.description,
    CONVERT(varchar(16), j.date_created, 120) AS create_date,
    CONVERT(varchar(16), j.date_modified, 120) AS modify_date
FROM msdb.dbo.sysjobs AS j
LEFT JOIN msdb.dbo.syscategories AS c
    ON c.category_id = j.category_id
WHERE j.job_id = @job_id
   OR (@job_id IS NULL AND j.name = @process_name);

BEGIN TRY
    CREATE TABLE #step_raw (
        step_id int,
        step_name sysname,
        subsystem nvarchar(40),
        command nvarchar(max),
        flags int,
        cmdexec_success_code int,
        on_success_action tinyint,
        on_success_step_id int,
        on_fail_action tinyint,
        on_fail_step_id int,
        server sysname NULL,
        database_name sysname NULL,
        database_user_name sysname NULL,
        retry_attempts int,
        retry_interval int,
        os_run_priority int,
        output_file_name nvarchar(200) NULL,
        last_run_outcome int,
        last_run_duration int,
        last_run_retries int,
        last_run_date int,
        last_run_time int,
        proxy_id int NULL
    );

    CREATE TABLE #job_step_raw (
        step_id int,
        step_name sysname,
        subsystem nvarchar(40),
        command nvarchar(3200),
        flags nvarchar(4000),
        cmdexec_success_code int,
        on_success_action nvarchar(4000),
        on_success_step_id int,
        on_fail_action nvarchar(4000),
        on_fail_step_id int,
        server sysname NULL,
        database_name sysname NULL,
        database_user_name sysname NULL,
        retry_attempts int,
        retry_interval int,
        os_run_priority varchar(4000),
        output_file_name varchar(200),
        last_run_outcome int,
        last_run_duration int,
        last_run_retries int,
        last_run_date int,
        last_run_time int,
        proxy_id int NULL
    );

    BEGIN TRY
        INSERT INTO #step_raw
        EXEC msdb.dbo.sp_help_jobstep @job_id = @job_id;
    END TRY
    BEGIN CATCH
        BEGIN TRY
            INSERT INTO #step_raw
            EXEC msdb.dbo.sp_help_jobstep @job_name = @process_name;
        END TRY
        BEGIN CATCH
            BEGIN TRY
                INSERT INTO #job_step_raw
                EXEC msdb.dbo.sp_help_job @job_id = @job_id, @job_aspect = 'STEPS';

                INSERT INTO #step_raw (
                    step_id,
                    step_name,
                    subsystem,
                    command,
                    flags,
                    cmdexec_success_code,
                    on_success_action,
                    on_success_step_id,
                    on_fail_action,
                    on_fail_step_id,
                    server,
                    database_name,
                    database_user_name,
                    retry_attempts,
                    retry_interval,
                    os_run_priority,
                    output_file_name,
                    last_run_outcome,
                    last_run_duration,
                    last_run_retries,
                    last_run_date,
                    last_run_time,
                    proxy_id
                )
                SELECT
                    step_id,
                    step_name,
                    subsystem,
                    command,
                    TRY_CONVERT(int, flags),
                    cmdexec_success_code,
                    TRY_CONVERT(tinyint, LEFT(on_success_action, 1)),
                    on_success_step_id,
                    TRY_CONVERT(tinyint, LEFT(on_fail_action, 1)),
                    on_fail_step_id,
                    server,
                    database_name,
                    database_user_name,
                    retry_attempts,
                    retry_interval,
                    TRY_CONVERT(int, os_run_priority),
                    output_file_name,
                    last_run_outcome,
                    last_run_duration,
                    last_run_retries,
                    last_run_date,
                    last_run_time,
                    proxy_id
                FROM #job_step_raw;
            END TRY
            BEGIN CATCH
                SET @steps_error = CONCAT('Steps are not available for this login through msdb SQL Agent procedures. Last error: ', ERROR_MESSAGE());
            END CATCH;
        END CATCH;
    END CATCH;

    IF @steps_error IS NOT NULL
    BEGIN
        SELECT
            @steps_error AS step_order,
            CAST(NULL AS sysname) AS step_name,
            CAST(NULL AS nvarchar(40)) AS subsystem,
            CAST(NULL AS sysname) AS database_name,
            CAST(NULL AS varchar(20)) AS command_type,
            CAST(NULL AS varchar(20)) AS on_success_action,
            CAST(NULL AS varchar(20)) AS on_fail_action,
            CAST(NULL AS int) AS retry_attempts,
            CAST(NULL AS int) AS retry_interval,
            CAST(NULL AS int) AS command_length,
            CAST(NULL AS nvarchar(500)) AS command_preview;
    END
    ELSE
    BEGIN
        SELECT
            step_id AS step_order,
            step_name,
            subsystem,
            database_name,
            CASE
                WHEN subsystem = 'TSQL' AND (LOWER(command) LIKE '%exec %' OR LOWER(command) LIKE '%execute %') THEN 'Procedure call'
                WHEN subsystem = 'TSQL' THEN 'T-SQL batch'
                ELSE subsystem
            END AS command_type,
            CASE on_success_action
                WHEN 1 THEN 'Quit with success'
                WHEN 2 THEN 'Quit with failure'
                WHEN 3 THEN 'Go to next step'
                WHEN 4 THEN 'Go to step'
                ELSE 'Unknown'
            END AS on_success_action,
            CASE on_fail_action
                WHEN 1 THEN 'Quit with success'
                WHEN 2 THEN 'Quit with failure'
                WHEN 3 THEN 'Go to next step'
                WHEN 4 THEN 'Go to step'
                ELSE 'Unknown'
            END AS on_fail_action,
            retry_attempts,
            retry_interval,
            LEN(command) AS command_length,
            LEFT(REPLACE(REPLACE(command, CHAR(13), ' '), CHAR(10), ' '), 500) AS command_preview
        FROM #step_raw
        ORDER BY step_id;
    END;
END TRY
BEGIN CATCH
    SELECT
        ERROR_MESSAGE() AS step_order,
        CAST(NULL AS sysname) AS step_name,
        CAST(NULL AS nvarchar(40)) AS subsystem,
        CAST(NULL AS sysname) AS database_name,
        CAST(NULL AS varchar(20)) AS command_type,
        CAST(NULL AS varchar(20)) AS on_success_action,
        CAST(NULL AS varchar(20)) AS on_fail_action,
        CAST(NULL AS int) AS retry_attempts,
        CAST(NULL AS int) AS retry_interval,
        CAST(NULL AS int) AS command_length,
        CAST(NULL AS nvarchar(500)) AS command_preview;
END CATCH;

BEGIN TRY
    SELECT TOP (100)
        CASE h.run_status
            WHEN 0 THEN 'Failed'
            WHEN 1 THEN 'Succeeded'
            WHEN 2 THEN 'Retry'
            WHEN 3 THEN 'Canceled'
            WHEN 4 THEN 'In Progress'
            ELSE 'Unknown'
        END AS run_status,
        STUFF(STUFF(CONVERT(char(8), h.run_date), 5, 0, '-'), 8, 0, '-')
            + ' '
            + STUFF(LEFT(RIGHT('000000' + CONVERT(varchar(6), h.run_time), 6), 4), 3, 0, ':') AS run_datetime,
        h.run_duration,
        h.message
    FROM msdb.dbo.sysjobhistory AS h
    INNER JOIN msdb.dbo.sysjobs AS j
        ON j.job_id = h.job_id
    WHERE j.job_id = @job_id
      AND h.step_id = 0
    ORDER BY h.run_date DESC, h.run_time DESC, h.instance_id DESC;
END TRY
BEGIN CATCH
    SELECT
        ERROR_MESSAGE() AS run_status,
        CAST(NULL AS varchar(16)) AS run_datetime,
        CAST(NULL AS int) AS run_duration,
        CAST(NULL AS nvarchar(4000)) AS message;
END CATCH;
"""


def process_step_sql_objects_sql(process_name: str, step_order: int, job_id: str = "") -> str:
    process_value = sql_literal(process_name)
    job_id_value = uniqueidentifier_literal(job_id)
    return f"""
DECLARE @process_name sysname = {process_value};
DECLARE @job_id uniqueidentifier = {job_id_value};
DECLARE @step_order int = {step_order};

IF @job_id IS NULL
BEGIN
    SELECT @job_id = job_id
    FROM msdb.dbo.sysjobs
    WHERE name = @process_name;
END;

BEGIN TRY
    CREATE TABLE #step_raw (
        step_id int,
        step_name sysname,
        subsystem nvarchar(40),
        command nvarchar(max),
        flags int,
        cmdexec_success_code int,
        on_success_action tinyint,
        on_success_step_id int,
        on_fail_action tinyint,
        on_fail_step_id int,
        server sysname NULL,
        database_name sysname NULL,
        database_user_name sysname NULL,
        retry_attempts int,
        retry_interval int,
        os_run_priority int,
        output_file_name nvarchar(200) NULL,
        last_run_outcome int,
        last_run_duration int,
        last_run_retries int,
        last_run_date int,
        last_run_time int,
        proxy_id int NULL
    );

    CREATE TABLE #job_step_raw (
        step_id int,
        step_name sysname,
        subsystem nvarchar(40),
        command nvarchar(3200),
        flags nvarchar(4000),
        cmdexec_success_code int,
        on_success_action nvarchar(4000),
        on_success_step_id int,
        on_fail_action nvarchar(4000),
        on_fail_step_id int,
        server sysname NULL,
        database_name sysname NULL,
        database_user_name sysname NULL,
        retry_attempts int,
        retry_interval int,
        os_run_priority varchar(4000),
        output_file_name varchar(200),
        last_run_outcome int,
        last_run_duration int,
        last_run_retries int,
        last_run_date int,
        last_run_time int,
        proxy_id int NULL
    );

    BEGIN TRY
        INSERT INTO #step_raw
        EXEC msdb.dbo.sp_help_jobstep @job_id = @job_id, @step_id = @step_order;
    END TRY
    BEGIN CATCH
        BEGIN TRY
            INSERT INTO #step_raw
            EXEC msdb.dbo.sp_help_jobstep @job_name = @process_name, @step_id = @step_order;
        END TRY
        BEGIN CATCH
            BEGIN TRY
                INSERT INTO #job_step_raw
                EXEC msdb.dbo.sp_help_job @job_id = @job_id, @job_aspect = 'STEPS';

                INSERT INTO #step_raw (
                    step_id,
                    step_name,
                    subsystem,
                    command,
                    flags,
                    cmdexec_success_code,
                    on_success_action,
                    on_success_step_id,
                    on_fail_action,
                    on_fail_step_id,
                    server,
                    database_name,
                    database_user_name,
                    retry_attempts,
                    retry_interval,
                    os_run_priority,
                    output_file_name,
                    last_run_outcome,
                    last_run_duration,
                    last_run_retries,
                    last_run_date,
                    last_run_time,
                    proxy_id
                )
                SELECT
                    step_id,
                    step_name,
                    subsystem,
                    command,
                    TRY_CONVERT(int, flags),
                    cmdexec_success_code,
                    TRY_CONVERT(tinyint, LEFT(on_success_action, 1)),
                    on_success_step_id,
                    TRY_CONVERT(tinyint, LEFT(on_fail_action, 1)),
                    on_fail_step_id,
                    server,
                    database_name,
                    database_user_name,
                    retry_attempts,
                    retry_interval,
                    TRY_CONVERT(int, os_run_priority),
                    output_file_name,
                    last_run_outcome,
                    last_run_duration,
                    last_run_retries,
                    last_run_date,
                    last_run_time,
                    proxy_id
                FROM #job_step_raw
                WHERE step_id = @step_order;
            END TRY
            BEGIN CATCH
                SELECT
                    CONCAT('Step SQL objects are not available for this login through msdb SQL Agent procedures. Last error: ', ERROR_MESSAGE()) AS step_order,
                    CAST(NULL AS sysname) AS step_name,
                    CAST(NULL AS sysname) AS database_name,
                    CAST(NULL AS varchar(20)) AS object_type,
                    CAST(NULL AS sysname) AS referenced_database,
                    CAST(NULL AS sysname) AS schema_name,
                    CAST(NULL AS sysname) AS object_name,
                    CAST(NULL AS nvarchar(512)) AS detected_object_text,
                    CAST(NULL AS varchar(40)) AS detection_method,
                    CAST(NULL AS varchar(10)) AS confidence,
                    CAST(NULL AS nvarchar(500)) AS command_preview;
                RETURN;
            END CATCH;
        END CATCH;
    END CATCH;

    WITH step_commands AS (
        SELECT
            step_id,
            step_name,
            database_name,
            command,
            CASE
                WHEN PATINDEX('%execute %', LOWER(command)) > 0 THEN PATINDEX('%execute %', LOWER(command)) + 8
                WHEN PATINDEX('%exec %', LOWER(command)) > 0 THEN PATINDEX('%exec %', LOWER(command)) + 5
                ELSE 0
            END AS object_start
        FROM #step_raw
        WHERE subsystem = 'TSQL'
    ),
    detected AS (
        SELECT
            step_id,
            step_name,
            database_name,
            LTRIM(RTRIM(
                REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                    LEFT(SUBSTRING(command, object_start, 4000), CHARINDEX(' ', SUBSTRING(command, object_start, 4000) + ' ') - 1),
                    '[', ''), ']', ''), ';', ''), CHAR(9), ''), CHAR(10), '')
            )) AS detected_object,
            LEFT(REPLACE(REPLACE(command, CHAR(13), ' '), CHAR(10), ' '), 500) AS command_preview
        FROM step_commands
        WHERE object_start > 0
    )
    SELECT
        step_id AS step_order,
        step_name,
        database_name,
        'Procedure' AS object_type,
        PARSENAME(detected_object, 3) AS referenced_database,
        PARSENAME(detected_object, 2) AS schema_name,
        PARSENAME(detected_object, 1) AS object_name,
        detected_object AS detected_object_text,
        'sp_help_jobstep + EXEC keyword' AS detection_method,
        CASE WHEN PARSENAME(detected_object, 2) IS NOT NULL THEN 'High' ELSE 'Medium' END AS confidence,
        command_preview
    FROM detected
    WHERE detected_object IS NOT NULL
      AND detected_object <> ''
      AND detected_object NOT LIKE '@%';
END TRY
BEGIN CATCH
    SELECT
        ERROR_MESSAGE() AS step_order,
        CAST(NULL AS sysname) AS step_name,
        CAST(NULL AS sysname) AS database_name,
        CAST(NULL AS varchar(20)) AS object_type,
        CAST(NULL AS sysname) AS referenced_database,
        CAST(NULL AS sysname) AS schema_name,
        CAST(NULL AS sysname) AS object_name,
        CAST(NULL AS nvarchar(512)) AS detected_object_text,
        CAST(NULL AS varchar(40)) AS detection_method,
        CAST(NULL AS varchar(10)) AS confidence,
        CAST(NULL AS nvarchar(500)) AS command_preview;
END CATCH;
"""
