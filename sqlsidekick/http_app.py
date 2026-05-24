from __future__ import annotations

import json
import mimetypes
from http.server import BaseHTTPRequestHandler
from pathlib import Path
from typing import Any
from urllib.parse import parse_qs, urlparse

from sqlsidekick.query_loader import load_named_queries, normalize_version
from sqlsidekick.sql_server import ConnectionSettings, SQLServerError, execute_query, test_connection


AGENT_METADATA_QUERY_NAMES = {
    "sql_agent_jobs",
    "sql_agent_job_steps",
    "sql_agent_job_schedules",
    "sql_agent_job_history",
    "process_inventory",
    "process_steps",
    "process_sql_objects",
    "process_recent_runs",
    "jobs_health_dashboard",
}


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
        if parsed.path == "/api/run-lineage-query":
            self.handle_run_lineage_query()
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
        if parsed.path == "/api/process-lineage-map":
            self.handle_process_lineage_map()
            return
        if parsed.path == "/api/impact-analysis":
            self.handle_impact_analysis()
            return
        if parsed.path == "/api/recommendations":
            self.handle_recommendations()
            return
        if parsed.path == "/api/query-store-detail":
            self.handle_query_store_detail()
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

        try:
            connection_payload = payload.get("connection", payload)
            agent_payload = payload.get("agentConnection")
            if name in AGENT_METADATA_QUERY_NAMES and agent_payload:
                connection_payload = agent_payload
            settings = ConnectionSettings.from_payload(connection_payload)
            result = execute_query(settings, queries[name].sql)
            self.send_json({"ok": True, **result})
        except SQLServerError as exc:
            self.send_json({"ok": False, "error": str(exc)}, status=400)
        except Exception as exc:
            self.send_json({"ok": False, "error": f"Error inesperado: {exc}"}, status=500)

    def handle_run_lineage_query(self) -> None:
        payload = self.read_json()
        name = str(payload.get("queryName", "")).strip()
        version = normalize_version(str(payload.get("scriptVersion", "full")))
        if name not in {"process_lineage", "used_by_jobs"}:
            self.send_json({"error": "Consulta de lineage no soportada."}, status=400)
            return

        queries = load_named_queries(self.queries_path, version=version)
        if "process_sql_objects" not in queries:
            self.send_json({"error": "Consulta base process_sql_objects no encontrada."}, status=404)
            return

        try:
            primary_settings = ConnectionSettings.from_payload(payload.get("connection", payload))
            agent_payload = payload.get("agentConnection") or payload.get("connection", payload)
            agent_settings = ConnectionSettings.from_payload(agent_payload)
            process_objects = execute_query(agent_settings, queries["process_sql_objects"].sql)
            rows = process_objects.get("resultSets", [{}])[0].get("rows", [])
            sql = lineage_from_process_objects_sql(name, rows)
            result = execute_query(primary_settings, sql)
            self.send_json({"ok": True, **result})
        except SQLServerError as exc:
            self.send_json({"ok": False, "error": str(exc)}, status=400)
        except Exception as exc:
            self.send_json({"ok": False, "error": f"Error inesperado: {exc}"}, status=500)

    def handle_process_lineage_map(self) -> None:
        payload = self.read_json()
        process_name = str(payload.get("processName", "")).strip()
        map_type = str(payload.get("mapType", "jobs")).strip().lower() or "jobs"
        try:
            primary_settings = ConnectionSettings.from_payload(payload.get("connection", payload))
            agent_payload = payload.get("agentConnection") or payload.get("connection", payload)
            agent_settings = ConnectionSettings.from_payload(agent_payload)
            list_settings = agent_settings if map_type == "jobs" else primary_settings
            available_items = execute_query(list_settings, lineage_map_targets_sql(map_type))
            available_item_rows = available_items.get("resultSets", [{}])[0].get("rows", [])
            available_names = [row.get("process_name") for row in available_item_rows if row.get("process_name")]
            if available_names and process_name not in available_names:
                process_name = available_names[0]
            if map_type == "jobs":
                process_objects = execute_query(agent_settings, focused_process_sql_objects_sql(process_name))
            else:
                process_objects = execute_query(primary_settings, focused_sql_object_map_sql(map_type, process_name))
            object_rows = process_objects.get("resultSets", [{}])[0].get("rows", [])
            lineage_sql = lineage_from_process_objects_sql("process_lineage", object_rows)
            lineage = execute_query(primary_settings, lineage_sql)
            lineage_rows = lineage.get("resultSets", [{}])[0].get("rows", [])
            table_features = execute_query(primary_settings, table_lineage_features_sql(lineage_rows))
            table_feature_rows = table_features.get("resultSets", [{}])[0].get("rows", [])
            self.send_json(
                {
                    "ok": True,
                    "processName": process_name,
                    "availableProcesses": available_names,
                    "processObjects": object_rows,
                    "tableFeatures": table_feature_rows,
                    **lineage,
                }
            )
        except SQLServerError as exc:
            self.send_json({"ok": False, "error": str(exc)}, status=400)
        except Exception as exc:
            self.send_json({"ok": False, "error": f"Error inesperado: {exc}"}, status=500)

    def handle_impact_analysis(self) -> None:
        payload = self.read_json()
        search_text = str(payload.get("searchText", "")).strip()
        if len(search_text) < 2:
            self.send_json({"ok": True, "searchText": search_text, "summary": empty_impact_summary(), "resultSets": []})
            return

        try:
            primary_settings = ConnectionSettings.from_payload(payload.get("connection", payload))
            agent_payload = payload.get("agentConnection")
            primary_result = execute_query(primary_settings, impact_analysis_sql(search_text))
            primary_rows = primary_result.get("resultSets", [{}])[0].get("rows", [])
            job_rows: list[dict[str, Any]] = []
            job_error = ""

            if agent_payload:
                try:
                    queries = load_named_queries(self.queries_path, version="full")
                    agent_settings = ConnectionSettings.from_payload(agent_payload)
                    process_objects = execute_query(agent_settings, queries["process_sql_objects"].sql)
                    process_rows = process_objects.get("resultSets", [{}])[0].get("rows", [])
                    lineage = execute_query(primary_settings, lineage_from_process_objects_sql("process_lineage", process_rows))
                    lineage_rows = lineage.get("resultSets", [{}])[0].get("rows", [])
                    recent_runs = execute_query(agent_settings, queries["process_recent_runs"].sql)
                    run_rows = recent_runs.get("resultSets", [{}])[0].get("rows", [])
                    job_rows = build_impact_job_rows(search_text, primary_rows, lineage_rows, process_rows, run_rows)
                except Exception as exc:
                    job_error = str(exc)

            all_rows = primary_rows + job_rows
            if job_error:
                all_rows.append(
                    {
                        "impact_section": "Jobs",
                        "impact_direction": "Operational",
                        "impact_depth": None,
                        "affected_schema": None,
                        "affected_object": "SQL Agent metadata unavailable",
                        "affected_type": "Access",
                        "referenced_schema": None,
                        "referenced_object": search_text,
                        "referenced_column": None,
                        "evidence": job_error,
                        "code_fragment": None,
                        "confidence": "Low",
                        "risk_signal": "Job impact could not be evaluated with the configured credentials.",
                    }
                )

            summary = summarize_impact(search_text, all_rows, job_error)
            self.send_json(
                {
                    "ok": True,
                    "searchText": search_text,
                    "summary": summary,
                    "resultSets": [
                        {
                            "columns": [
                                "impact_section",
                                "impact_direction",
                                "impact_depth",
                                "affected_schema",
                                "affected_object",
                                "affected_type",
                                "referenced_schema",
                                "referenced_object",
                                "referenced_column",
                                "evidence",
                                "code_fragment",
                                "confidence",
                                "risk_signal",
                            ],
                            "rows": all_rows,
                        }
                    ],
                }
            )
        except SQLServerError as exc:
            self.send_json({"ok": False, "error": str(exc)}, status=400)
        except Exception as exc:
            self.send_json({"ok": False, "error": f"Error inesperado: {exc}"}, status=500)

    def handle_recommendations(self) -> None:
        payload = self.read_json()
        rows: list[dict[str, Any]] = []
        errors: list[str] = []
        try:
            primary_settings = ConnectionSettings.from_payload(payload.get("connection", payload))
            agent_payload = payload.get("agentConnection")
            agent_settings = ConnectionSettings.from_payload(agent_payload) if agent_payload else None
            queries = load_named_queries(self.queries_path, version="full")

            sources = [
                ("Jobs", "jobs_health_dashboard", agent_settings),
                ("Index", "index_health_dashboard", primary_settings),
                ("Storage", "storage_datafiles_health", primary_settings),
                ("Waits / TempDB", "waits_tempdb_review", primary_settings),
                ("Query Store", "query_store_regressions", primary_settings),
            ]
            for source_area, query_name, settings in sources:
                if settings is None:
                    errors.append(f"{source_area}: SQL Agent credentials are not configured.")
                    continue
                try:
                    result = execute_query(settings, queries[query_name].sql)
                    findings = result.get("resultSets", [{}])[0].get("rows", [])
                    rows.extend(build_recommendation_rows(source_area, findings))
                except Exception as exc:
                    errors.append(f"{source_area}: {exc}")

            for error in errors:
                rows.append(
                    {
                        "severity": "LOW",
                        "recommendation_area": "Access",
                        "finding": "Recommendation source could not be evaluated",
                        "affected_object": error,
                        "evidence": "The app could not read one recommendation source.",
                        "impact_hint": "Recommendations may be incomplete.",
                        "recommended_action": "Review credentials and permissions for this source.",
                        "suggested_sql": "-- No fix SQL generated.\n-- Configure the required review credentials and rerun Recommendations.",
                        "safety_notes": "No SQL was generated because the source could not be evaluated.",
                    }
                )

            columns = [
                "severity",
                "recommendation_area",
                "finding",
                "affected_object",
                "evidence",
                "impact_hint",
                "recommended_action",
                "suggested_sql",
                "safety_notes",
            ]
            self.send_json({"ok": True, "resultSets": [{"columns": columns, "rows": rows}]})
        except SQLServerError as exc:
            self.send_json({"ok": False, "error": str(exc)}, status=400)
        except Exception as exc:
            self.send_json({"ok": False, "error": f"Error inesperado: {exc}"}, status=500)

    def handle_query_store_detail(self) -> None:
        payload = self.read_json()
        query_id_raw = payload.get("queryId")
        try:
            query_id = int(query_id_raw)
        except (TypeError, ValueError):
            self.send_json({"error": "Query ID is required."}, status=400)
            return

        try:
            primary_settings = ConnectionSettings.from_payload(payload.get("connection", payload))
            overview = execute_query(primary_settings, query_store_query_overview_sql(query_id)).get("resultSets", [{}])[0]
            runtime = execute_query(primary_settings, query_store_query_runtime_sql(query_id)).get("resultSets", [{}])[0]
            plans = execute_query(primary_settings, query_store_query_plans_sql(query_id)).get("resultSets", [{}])[0]
            waits = execute_query(primary_settings, query_store_query_waits_sql(query_id)).get("resultSets", [{}])[0]

            overview_row = (overview.get("rows") or [{}])[0]
            object_schema = overview_row.get("object_schema")
            object_name = overview_row.get("object_name")
            related_rows: list[dict[str, Any]] = []
            related_columns = [
                "process_name",
                "step_order",
                "step_name",
                "database_name",
                "relationship",
                "confidence",
                "command_preview",
            ]

            agent_payload = payload.get("agentConnection")
            if agent_payload and object_name:
                try:
                    queries = load_named_queries(self.queries_path, version="full")
                    agent_settings = ConnectionSettings.from_payload(agent_payload)
                    process_objects = execute_query(agent_settings, queries["process_sql_objects"].sql)
                    process_rows = process_objects.get("resultSets", [{}])[0].get("rows", [])
                    related_rows = query_store_related_process_rows(object_schema, object_name, process_rows)
                    lineage = execute_query(primary_settings, lineage_from_process_objects_sql("process_lineage", process_rows))
                    lineage_rows = lineage.get("resultSets", [{}])[0].get("rows", [])
                    related_rows = merge_related_process_rows(
                        related_rows,
                        query_store_related_lineage_rows(object_schema, object_name, lineage_rows),
                    )
                except Exception as exc:
                    related_rows = [
                        {
                            "process_name": "SQL Agent metadata unavailable",
                            "step_order": None,
                            "step_name": None,
                            "database_name": None,
                            "relationship": str(exc),
                            "confidence": "Low",
                            "command_preview": None,
                        }
                    ]

            self.send_json(
                {
                    "ok": True,
                    "queryId": query_id,
                    "resultSets": [
                        overview,
                        runtime,
                        plans,
                        waits,
                        {"columns": related_columns, "rows": related_rows},
                    ],
                }
            )
        except SQLServerError as exc:
            self.send_json({"ok": False, "error": str(exc)}, status=400)
        except Exception as exc:
            self.send_json({"ok": False, "error": f"Error inesperado: {exc}"}, status=500)

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


def nullable_sql_literal(value: Any) -> str:
    if value is None or value == "":
        return "NULL"
    return sql_literal(str(value))


def nullable_int_literal(value: Any) -> str:
    try:
        return str(int(value))
    except (TypeError, ValueError):
        return "NULL"


def impact_analysis_sql(search_text: str) -> str:
    return f"""
DECLARE @search nvarchar(512) = {sql_literal(search_text)};
DECLARE @clean nvarchar(512) = REPLACE(REPLACE(LTRIM(RTRIM(@search)), '[', ''), ']', '');
DECLARE @parts int = LEN(@clean) - LEN(REPLACE(@clean, '.', '')) + 1;
DECLARE @search_schema sysname = CASE WHEN @parts >= 2 THEN PARSENAME(@clean, CASE WHEN @parts >= 3 THEN 3 ELSE 2 END) END;
DECLARE @search_object sysname = CASE WHEN @parts >= 2 THEN PARSENAME(@clean, CASE WHEN @parts >= 3 THEN 2 ELSE 1 END) ELSE @clean END;
DECLARE @search_column sysname = CASE WHEN @parts >= 3 THEN PARSENAME(@clean, 1) END;

WITH object_catalog AS (
    SELECT
        o.object_id,
        s.name AS schema_name,
        o.name AS object_name,
        o.type_desc,
        sm.definition,
        CONCAT(s.name, N'.', o.name) AS full_name
    FROM sys.objects AS o
    INNER JOIN sys.schemas AS s
        ON s.schema_id = o.schema_id
    LEFT JOIN sys.sql_modules AS sm
        ON sm.object_id = o.object_id
    WHERE o.is_ms_shipped = 0
),
target_objects AS (
    SELECT DISTINCT
        oc.object_id,
        oc.schema_name,
        oc.object_name,
        oc.type_desc
    FROM object_catalog AS oc
    LEFT JOIN sys.columns AS c
        ON c.object_id = oc.object_id
       AND (@search_column IS NULL OR c.name = @search_column)
    WHERE (
            (@search_schema IS NOT NULL AND oc.schema_name = @search_schema AND oc.object_name = @search_object)
         OR (@search_schema IS NULL AND (oc.object_name = @search_object OR oc.full_name LIKE N'%' + @clean + N'%'))
      )
      AND (@search_column IS NULL OR c.column_id IS NOT NULL)
),
dependency_edges AS (
    SELECT DISTINCT
        sed.referencing_id,
        sed.referenced_id,
        sed.referenced_minor_id,
        COALESCE(ref_schema.name, sed.referenced_schema_name) AS referenced_schema,
        COALESCE(ref_obj.name, sed.referenced_entity_name) AS referenced_object,
        ref_obj.type_desc AS referenced_type,
        ref_col.name AS referenced_column,
        referrer.schema_name AS referencing_schema,
        referrer.object_name AS referencing_object,
        referrer.type_desc AS referencing_type,
        referrer.definition AS referencing_definition
    FROM sys.sql_expression_dependencies AS sed
    INNER JOIN object_catalog AS referrer
        ON referrer.object_id = sed.referencing_id
    LEFT JOIN sys.objects AS ref_obj
        ON ref_obj.object_id = sed.referenced_id
    LEFT JOIN sys.schemas AS ref_schema
        ON ref_schema.schema_id = ref_obj.schema_id
    LEFT JOIN sys.columns AS ref_col
        ON ref_col.object_id = sed.referenced_id
       AND ref_col.column_id = sed.referenced_minor_id
    WHERE sed.referenced_database_name IS NULL
),
downstream AS (
    SELECT
        CAST(1 AS int) AS impact_depth,
        edge.referencing_id AS affected_id,
        edge.referencing_schema,
        edge.referencing_object,
        edge.referencing_type,
        edge.referenced_schema,
        edge.referenced_object,
        edge.referenced_type,
        edge.referenced_column,
        edge.referencing_definition,
        CAST(CONCAT(N'|', target.object_id, N'|', edge.referencing_id, N'|') AS nvarchar(max)) AS path_ids
    FROM dependency_edges AS edge
    INNER JOIN target_objects AS target
        ON target.object_id = edge.referenced_id
    WHERE @search_column IS NULL
       OR edge.referenced_minor_id = 0
       OR edge.referenced_column = @search_column

    UNION ALL

    SELECT
        previous.impact_depth + 1,
        edge.referencing_id,
        edge.referencing_schema,
        edge.referencing_object,
        edge.referencing_type,
        edge.referenced_schema,
        edge.referenced_object,
        edge.referenced_type,
        edge.referenced_column,
        edge.referencing_definition,
        CAST(previous.path_ids + CONVERT(nvarchar(20), edge.referencing_id) + N'|' AS nvarchar(max))
    FROM dependency_edges AS edge
    INNER JOIN downstream AS previous
        ON previous.affected_id = edge.referenced_id
    WHERE previous.impact_depth < 3
      AND previous.path_ids NOT LIKE N'%|' + CONVERT(nvarchar(20), edge.referencing_id) + N'|%'
),
upstream AS (
    SELECT
        edge.referenced_schema,
        edge.referenced_object,
        edge.referenced_type,
        edge.referenced_column,
        edge.referencing_schema,
        edge.referencing_object,
        edge.referencing_type,
        edge.referenced_id,
        edge.referencing_definition
    FROM dependency_edges AS edge
    INNER JOIN target_objects AS target
        ON target.object_id = edge.referencing_id
),
table_features AS (
    SELECT
        'Table feature' AS impact_section,
        'Downstream' AS impact_direction,
        CAST(1 AS int) AS impact_depth,
        OBJECT_SCHEMA_NAME(t.object_id) AS affected_schema,
        tr.name AS affected_object,
        CONCAT('Trigger - ', CASE WHEN tr.is_disabled = 1 THEN 'Disabled' ELSE 'Enabled' END) AS affected_type,
        OBJECT_SCHEMA_NAME(t.object_id) AS referenced_schema,
        OBJECT_NAME(t.object_id) AS referenced_object,
        CAST(NULL AS sysname) AS referenced_column,
        CONCAT(
            'Trigger events: ',
            CASE WHEN OBJECTPROPERTY(tr.object_id, 'ExecIsInsertTrigger') = 1 THEN 'INSERT ' ELSE '' END,
            CASE WHEN OBJECTPROPERTY(tr.object_id, 'ExecIsUpdateTrigger') = 1 THEN 'UPDATE ' ELSE '' END,
            CASE WHEN OBJECTPROPERTY(tr.object_id, 'ExecIsDeleteTrigger') = 1 THEN 'DELETE ' ELSE '' END
        ) AS evidence,
        trm.definition AS code_fragment,
        'High' AS confidence,
        'DML behavior can change when this table changes.' AS risk_signal
    FROM target_objects AS t
    INNER JOIN sys.triggers AS tr
        ON tr.parent_id = t.object_id
    LEFT JOIN sys.sql_modules AS trm
        ON trm.object_id = tr.object_id

    UNION ALL

    SELECT
        'Table feature',
        'Downstream',
        1,
        OBJECT_SCHEMA_NAME(t.object_id),
        c.name,
        'Computed column',
        OBJECT_SCHEMA_NAME(t.object_id),
        OBJECT_NAME(t.object_id),
        c.name,
        cc.definition,
        cc.definition,
        CASE WHEN @search_column IS NULL OR cc.definition LIKE N'%' + @search_column + N'%' THEN 'Medium' ELSE 'Low' END,
        'Computed column expression should be reviewed before table or column changes.'
    FROM target_objects AS t
    INNER JOIN sys.computed_columns AS c
        ON c.object_id = t.object_id
    INNER JOIN sys.computed_columns AS cc
        ON cc.object_id = c.object_id
       AND cc.column_id = c.column_id
    WHERE @search_column IS NULL
       OR c.name = @search_column
       OR cc.definition LIKE N'%' + @search_column + N'%'

    UNION ALL

    SELECT
        'Table feature',
        'Downstream',
        1,
        OBJECT_SCHEMA_NAME(t.object_id),
        chk.name,
        'Check constraint',
        OBJECT_SCHEMA_NAME(t.object_id),
        OBJECT_NAME(t.object_id),
        CAST(NULL AS sysname),
        chk.definition,
        chk.definition,
        CASE WHEN @search_column IS NULL OR chk.definition LIKE N'%' + @search_column + N'%' THEN 'Medium' ELSE 'Low' END,
        'Constraint can block data changes after schema or data shape changes.'
    FROM target_objects AS t
    INNER JOIN sys.check_constraints AS chk
        ON chk.parent_object_id = t.object_id
    WHERE @search_column IS NULL
       OR chk.definition LIKE N'%' + @search_column + N'%'
)
SELECT DISTINCT
    'Object dependency' AS impact_section,
    'Downstream' AS impact_direction,
    downstream.impact_depth,
    downstream.referencing_schema AS affected_schema,
    downstream.referencing_object AS affected_object,
    downstream.referencing_type AS affected_type,
    downstream.referenced_schema,
    downstream.referenced_object,
    downstream.referenced_column,
    CONCAT('Dependency depth ', downstream.impact_depth) AS evidence,
    CASE
        WHEN downstream.referencing_definition IS NOT NULL
         AND CHARINDEX(downstream.referenced_object, downstream.referencing_definition) > 0
        THEN SUBSTRING(
            downstream.referencing_definition,
            CASE WHEN CHARINDEX(downstream.referenced_object, downstream.referencing_definition) > 180
                THEN CHARINDEX(downstream.referenced_object, downstream.referencing_definition) - 180
                ELSE 1
            END,
            700
        )
        ELSE NULL
    END AS code_fragment,
    CASE WHEN downstream.impact_depth = 1 THEN 'High' WHEN downstream.impact_depth = 2 THEN 'Medium' ELSE 'Low' END AS confidence,
    CASE WHEN downstream.impact_depth = 1 THEN 'Direct dependency can break on schema changes.' ELSE 'Indirect dependency may be affected through another object.' END AS risk_signal
FROM downstream

UNION ALL

SELECT DISTINCT
    'Object dependency',
    'Upstream',
    CAST(1 AS int),
    upstream.referenced_schema,
    upstream.referenced_object,
    upstream.referenced_type,
    upstream.referencing_schema,
    upstream.referencing_object,
    upstream.referenced_column,
    'Object referenced by selected object',
    CASE
        WHEN upstream.referencing_definition IS NOT NULL
         AND CHARINDEX(upstream.referenced_object, upstream.referencing_definition) > 0
        THEN SUBSTRING(
            upstream.referencing_definition,
            CASE WHEN CHARINDEX(upstream.referenced_object, upstream.referencing_definition) > 180
                THEN CHARINDEX(upstream.referenced_object, upstream.referencing_definition) - 180
                ELSE 1
            END,
            700
        )
        ELSE NULL
    END,
    'High',
    'Changing this upstream object can affect the selected object.'
FROM upstream
WHERE upstream.referenced_object IS NOT NULL
  AND upstream.referenced_id IS NOT NULL

UNION ALL

SELECT
    impact_section,
    impact_direction,
    impact_depth,
    affected_schema,
    affected_object,
    affected_type,
    referenced_schema,
    referenced_object,
    referenced_column,
    evidence,
    code_fragment,
    confidence,
    risk_signal
FROM table_features
ORDER BY impact_section, impact_direction, impact_depth, affected_schema, affected_object
OPTION (MAXRECURSION 25);
"""


def empty_impact_summary() -> dict[str, Any]:
    return {
        "risk": "Unknown",
        "direct_count": 0,
        "indirect_count": 0,
        "job_count": 0,
        "feature_count": 0,
        "confidence": "Low",
        "reason": "Search for a table, column, procedure, view, or function to analyze impact.",
        "suggested_action": "Enter an object name such as dbo.Customer or dbo.Customer.Email.",
    }


def object_key(schema: Any, name: Any) -> str:
    if not name:
        return ""
    return f"{str(schema or 'dbo').lower()}.{str(name).lower()}"


def build_impact_job_rows(
    search_text: str,
    primary_rows: list[dict[str, Any]],
    lineage_rows: list[dict[str, Any]],
    process_rows: list[dict[str, Any]],
    run_rows: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    cleaned = search_text.replace("[", "").replace("]", "").strip().lower()
    search_parts = [part for part in cleaned.split(".") if part]
    search_name = search_parts[-2] if len(search_parts) >= 3 else search_parts[-1] if search_parts else cleaned
    search_schema = search_parts[-3] if len(search_parts) >= 3 else search_parts[-2] if len(search_parts) >= 2 else ""
    impacted_objects = {
        object_key(row.get("affected_schema"), row.get("affected_object"))
        for row in primary_rows
        if row.get("affected_object")
        and str(row.get("impact_section", "")).lower() == "object dependency"
        and str(row.get("impact_direction", "")).lower() == "downstream"
    }
    names_to_match = impacted_objects
    if search_schema and search_name:
        names_to_match.add(f"{search_schema}.{search_name}")
    elif search_name:
        names_to_match.add(f"dbo.{search_name}")
    if search_name:
        names_to_match.add(f"dbo.{search_name}")

    latest_runs: dict[str, dict[str, Any]] = {}
    for run in run_rows:
        process_name = str(run.get("process_name") or "")
        if process_name and process_name not in latest_runs and not process_name.lower().startswith("the "):
            latest_runs[process_name] = run

    rows_by_key: dict[str, dict[str, Any]] = {}
    combined_lineage = list(lineage_rows)
    for process in process_rows:
        combined_lineage.append(
            {
                "process_name": process.get("process_name"),
                "step_order": process.get("step_order"),
                "step_name": process.get("step_name"),
                "database_name": process.get("database_name"),
                "called_schema": process.get("schema_name") or "dbo",
                "called_object_name": process.get("object_name"),
                "called_object_type": process.get("object_type"),
                "referenced_schema": None,
                "referenced_object": None,
                "confidence": process.get("confidence"),
                "command_preview": process.get("command_preview"),
            }
        )

    for row in combined_lineage:
        called_key = object_key(row.get("called_schema"), row.get("called_object_name"))
        referenced_key = object_key(row.get("referenced_schema"), row.get("referenced_object"))
        called_name = str(row.get("called_object_name") or "").lower()
        referenced_name = str(row.get("referenced_object") or "").lower()
        matches = (
            called_key in names_to_match
            or referenced_key in names_to_match
            or (
                not search_schema
                and search_name
                and (called_name == search_name or referenced_name == search_name)
            )
        )
        if not matches:
            continue
        process_name = row.get("process_name")
        if not process_name:
            continue
        run = latest_runs.get(str(process_name), {})
        key = f"{process_name}|{row.get('step_order')}|{called_key or referenced_key}"
        candidate = {
            "impact_section": "Jobs",
            "impact_direction": "Operational",
            "impact_depth": row.get("step_order"),
            "affected_schema": None,
            "affected_object": process_name,
            "affected_type": f"Job step {row.get('step_order') or '-'}",
            "referenced_schema": row.get("called_schema") or row.get("referenced_schema"),
            "referenced_object": row.get("called_object_name") or row.get("referenced_object"),
            "referenced_column": None,
            "evidence": f"Step: {row.get('step_name') or '-'}; Last run: {run.get('run_status') or 'Unknown'} {run.get('run_datetime') or ''}".strip(),
            "code_fragment": row.get("command_preview"),
            "confidence": row.get("confidence") or "Medium",
            "risk_signal": "Related SQL Agent job may fail or load stale data after this change.",
        }
        existing = rows_by_key.get(key)
        if not existing or confidence_rank(candidate.get("confidence")) < confidence_rank(existing.get("confidence")):
            rows_by_key[key] = candidate

    return list(rows_by_key.values())


def confidence_rank(value: Any) -> int:
    ranks = {"high": 0, "medium": 1, "low": 2}
    return ranks.get(str(value or "").lower(), 3)


def summarize_impact(search_text: str, rows: list[dict[str, Any]], job_error: str = "") -> dict[str, Any]:
    direct_count = sum(1 for row in rows if row.get("impact_section") == "Object dependency" and row.get("impact_direction") == "Downstream" and row.get("impact_depth") == 1)
    indirect_count = sum(1 for row in rows if row.get("impact_section") == "Object dependency" and row.get("impact_direction") == "Downstream" and (row.get("impact_depth") or 0) > 1)
    job_names = {row.get("affected_object") for row in rows if row.get("impact_section") == "Jobs" and row.get("affected_object") != "SQL Agent metadata unavailable"}
    feature_count = sum(1 for row in rows if row.get("impact_section") == "Table feature")
    high_confidence = sum(1 for row in rows if str(row.get("confidence") or "").lower() == "high")
    low_confidence = sum(1 for row in rows if str(row.get("confidence") or "").lower() == "low")

    if job_names or direct_count >= 3 or feature_count >= 2:
        risk = "High"
    elif direct_count or indirect_count or feature_count or job_error:
        risk = "Medium"
    else:
        risk = "Low"

    confidence = "High" if high_confidence and not low_confidence else "Medium" if rows else "Low"
    reasons: list[str] = []
    if direct_count:
        reasons.append(f"{direct_count} direct object(s)")
    if indirect_count:
        reasons.append(f"{indirect_count} indirect object(s)")
    if job_names:
        reasons.append(f"{len(job_names)} related job(s)")
    if feature_count:
        reasons.append(f"{feature_count} table feature(s)")
    if job_error:
        reasons.append("job metadata is partial")

    return {
        "risk": risk,
        "direct_count": direct_count,
        "indirect_count": indirect_count,
        "job_count": len(job_names),
        "feature_count": feature_count,
        "confidence": confidence,
        "reason": f"{search_text}: " + (", ".join(reasons) if reasons else "no known impact found with visible metadata."),
        "suggested_action": "Review affected objects and related jobs before changing this object. Treat Low confidence rows as incomplete metadata, not as safe.",
    }


def build_recommendation_rows(source_area: str, findings: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return [build_recommendation_row(source_area, finding) for finding in findings if finding]


def build_recommendation_row(source_area: str, finding: dict[str, Any]) -> dict[str, Any]:
    severity = str(finding.get("severity") or "LOW").upper()
    health_area = str(finding.get("health_area") or source_area)
    check_name = str(finding.get("check_name") or "Review finding")
    if source_area == "Query Store":
        health_area = "Regressions"
        check_name = "Query duration regression detected"
    affected_object = str(
        finding.get("job_name")
        or finding.get("subject_name")
        or finding.get("object_name")
        or (f"Query {finding.get('query_id')}" if finding.get("query_id") else "")
        or finding.get("database_name")
        or "-"
    )
    detail = str(finding.get("detail") or finding.get("recommendation") or "-")
    if source_area == "Query Store":
        detail = (
            f"Recent avg duration: {finding.get('recent_avg_duration_ms') or '-'} ms; "
            f"baseline avg duration: {finding.get('baseline_avg_duration_ms') or '-'} ms; "
            f"regression ratio: {finding.get('regression_ratio') or '-'}."
        )
    suggested_sql = recommendation_sql(source_area, finding)
    if not suggested_sql:
        suggested_sql = "-- No safe generic SQL is available for this finding.\n-- Review the evidence and validate the change manually."
    return {
        "severity": severity,
        "recommendation_area": f"{source_area} - {health_area}",
        "finding": check_name,
        "affected_object": affected_object,
        "evidence": detail,
        "impact_hint": recommendation_impact_hint(source_area),
        "recommended_action": default_recommended_action(source_area) if source_area == "Query Store" else str(finding.get("recommendation") or default_recommended_action(source_area)),
        "suggested_sql": suggested_sql,
        "safety_notes": recommendation_safety_notes(source_area, suggested_sql),
    }


def query_store_query_overview_sql(query_id: int) -> str:
    return f"""
BEGIN TRY
    SELECT TOP (1)
        q.query_id,
        q.object_id,
        SCHEMA_NAME(o.schema_id) AS object_schema,
        o.name AS object_name,
        o.type_desc AS object_type,
        q.is_internal_query,
        CONVERT(varchar(16), q.last_compile_start_time, 120) AS last_compile_start_time,
        CONVERT(varchar(16), q.last_execution_time, 120) AS last_execution_time,
        qt.query_sql_text
    FROM sys.query_store_query AS q
    INNER JOIN sys.query_store_query_text AS qt
        ON qt.query_text_id = q.query_text_id
    LEFT JOIN sys.objects AS o
        ON o.object_id = NULLIF(q.object_id, 0)
    WHERE q.query_id = {int(query_id)};
END TRY
BEGIN CATCH
    SELECT
        CAST({int(query_id)} AS bigint) AS query_id,
        CAST(NULL AS int) AS object_id,
        CAST(NULL AS sysname) AS object_schema,
        CAST(NULL AS sysname) AS object_name,
        CAST(NULL AS nvarchar(60)) AS object_type,
        CAST(NULL AS bit) AS is_internal_query,
        CAST(NULL AS varchar(16)) AS last_compile_start_time,
        CAST(NULL AS varchar(16)) AS last_execution_time,
        ERROR_MESSAGE() AS query_sql_text;
END CATCH;
"""


def query_store_query_runtime_sql(query_id: int) -> str:
    return f"""
BEGIN TRY
    WITH numbered_intervals AS (
        SELECT
            runtime_stats_interval_id,
            ROW_NUMBER() OVER (ORDER BY end_time DESC) AS rn
        FROM sys.query_store_runtime_stats_interval
    ),
    windows AS (
        SELECT
            CASE WHEN ni.rn = 1 THEN 'Recent' ELSE 'Baseline' END AS runtime_window,
            SUM(rs.count_executions) AS execution_count,
            SUM(rs.avg_duration * rs.count_executions) AS weighted_duration,
            SUM(rs.avg_cpu_time * rs.count_executions) AS weighted_cpu,
            SUM(rs.avg_logical_io_reads * rs.count_executions) AS weighted_logical_reads,
            SUM(rs.avg_physical_io_reads * rs.count_executions) AS weighted_physical_reads,
            CONVERT(varchar(16), MIN(rsi.start_time), 120) AS window_start,
            CONVERT(varchar(16), MAX(rsi.end_time), 120) AS window_end
        FROM sys.query_store_runtime_stats AS rs
        INNER JOIN numbered_intervals AS ni
            ON ni.runtime_stats_interval_id = rs.runtime_stats_interval_id
        INNER JOIN sys.query_store_runtime_stats_interval AS rsi
            ON rsi.runtime_stats_interval_id = rs.runtime_stats_interval_id
        INNER JOIN sys.query_store_plan AS p
            ON p.plan_id = rs.plan_id
        WHERE p.query_id = {int(query_id)}
          AND ni.rn <= 8
        GROUP BY CASE WHEN ni.rn = 1 THEN 'Recent' ELSE 'Baseline' END
    )
    SELECT
        runtime_window,
        execution_count,
        CONVERT(decimal(19,2), weighted_duration / NULLIF(execution_count, 0) / 1000.0) AS avg_duration_ms,
        CONVERT(decimal(19,2), weighted_cpu / NULLIF(execution_count, 0) / 1000.0) AS avg_cpu_ms,
        CONVERT(decimal(19,2), weighted_logical_reads / NULLIF(execution_count, 0)) AS avg_logical_reads,
        CONVERT(decimal(19,2), weighted_physical_reads / NULLIF(execution_count, 0)) AS avg_physical_reads,
        window_start,
        window_end
    FROM windows
    ORDER BY CASE runtime_window WHEN 'Recent' THEN 1 ELSE 2 END;
END TRY
BEGIN CATCH
    SELECT
        'Unavailable' AS runtime_window,
        CAST(NULL AS bigint) AS execution_count,
        CAST(NULL AS decimal(19,2)) AS avg_duration_ms,
        CAST(NULL AS decimal(19,2)) AS avg_cpu_ms,
        CAST(NULL AS decimal(19,2)) AS avg_logical_reads,
        CAST(NULL AS decimal(19,2)) AS avg_physical_reads,
        CAST(NULL AS varchar(16)) AS window_start,
        ERROR_MESSAGE() AS window_end;
END CATCH;
"""


def query_store_query_plans_sql(query_id: int) -> str:
    return f"""
BEGIN TRY
    SELECT
        p.plan_id,
        p.is_forced_plan,
        p.force_failure_count,
        p.last_force_failure_reason_desc,
        p.count_compiles,
        CONVERT(decimal(19,2), p.avg_compile_duration / 1000.0) AS avg_compile_duration_ms,
        CONVERT(varchar(16), p.last_execution_time, 120) AS last_execution_time,
        CASE
            WHEN p.force_failure_count > 0 THEN 'Forced plan failed'
            WHEN p.is_forced_plan = 1 THEN 'Forced plan'
            ELSE 'Observed plan'
        END AS plan_signal,
        LEFT(CONVERT(nvarchar(max), p.query_plan), 4000) AS plan_preview
    FROM sys.query_store_plan AS p
    WHERE p.query_id = {int(query_id)}
    ORDER BY
        p.force_failure_count DESC,
        p.is_forced_plan DESC,
        p.last_execution_time DESC;
END TRY
BEGIN CATCH
    SELECT
        CAST(NULL AS bigint) AS plan_id,
        CAST(NULL AS bit) AS is_forced_plan,
        CAST(NULL AS bigint) AS force_failure_count,
        CAST(NULL AS nvarchar(120)) AS last_force_failure_reason_desc,
        CAST(NULL AS bigint) AS count_compiles,
        CAST(NULL AS decimal(19,2)) AS avg_compile_duration_ms,
        CAST(NULL AS varchar(16)) AS last_execution_time,
        'Unavailable' AS plan_signal,
        ERROR_MESSAGE() AS plan_preview;
END CATCH;
"""


def query_store_query_waits_sql(query_id: int) -> str:
    return f"""
BEGIN TRY
    WITH latest_intervals AS (
        SELECT TOP (12) runtime_stats_interval_id
        FROM sys.query_store_runtime_stats_interval
        ORDER BY end_time DESC
    )
    SELECT TOP (12)
        ws.wait_category_desc AS wait_category,
        CONVERT(decimal(19,2), SUM(ws.total_query_wait_time_ms)) AS total_wait_ms,
        CONVERT(decimal(19,2), AVG(ws.avg_query_wait_time_ms)) AS avg_wait_ms,
        CONVERT(varchar(16), MAX(rsi.end_time), 120) AS last_seen
    FROM sys.query_store_wait_stats AS ws
    INNER JOIN latest_intervals AS li
        ON li.runtime_stats_interval_id = ws.runtime_stats_interval_id
    INNER JOIN sys.query_store_runtime_stats_interval AS rsi
        ON rsi.runtime_stats_interval_id = ws.runtime_stats_interval_id
    INNER JOIN sys.query_store_plan AS p
        ON p.plan_id = ws.plan_id
    WHERE p.query_id = {int(query_id)}
    GROUP BY ws.wait_category_desc
    ORDER BY total_wait_ms DESC;
END TRY
BEGIN CATCH
    SELECT
        'Unavailable' AS wait_category,
        CAST(NULL AS decimal(19,2)) AS total_wait_ms,
        CAST(NULL AS decimal(19,2)) AS avg_wait_ms,
        ERROR_MESSAGE() AS last_seen;
END CATCH;
"""


def query_store_related_process_rows(object_schema: Any, object_name: Any, process_rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    target_key = object_key(object_schema, object_name)
    rows_by_key: dict[str, dict[str, Any]] = {}
    for row in process_rows:
        row_key = object_key(row.get("schema_name") or row.get("called_schema"), row.get("object_name") or row.get("called_object_name"))
        if row_key != target_key:
            continue
        process_name = row.get("process_name")
        if not process_name:
            continue
        key = f"{process_name}|{row.get('step_order') or row.get('step_id')}|{row_key}"
        rows_by_key[key] = {
            "process_name": process_name,
            "step_order": row.get("step_order") or row.get("step_id"),
            "step_name": row.get("step_name"),
            "database_name": row.get("database_name"),
            "relationship": "Job step calls this Query Store object",
            "confidence": row.get("confidence") or "Medium",
            "command_preview": row.get("command_preview"),
        }
    return list(rows_by_key.values())


def query_store_related_lineage_rows(object_schema: Any, object_name: Any, lineage_rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    target_key = object_key(object_schema, object_name)
    rows_by_key: dict[str, dict[str, Any]] = {}
    for row in lineage_rows:
        called_key = object_key(row.get("called_schema"), row.get("called_object_name"))
        referenced_key = object_key(row.get("referenced_schema"), row.get("referenced_object"))
        if target_key not in {called_key, referenced_key}:
            continue
        process_name = row.get("process_name")
        if not process_name:
            continue
        key = f"{process_name}|{row.get('step_order')}|{called_key}|{referenced_key}"
        rows_by_key[key] = {
            "process_name": process_name,
            "step_order": row.get("step_order"),
            "step_name": row.get("step_name"),
            "database_name": row.get("database_name"),
            "relationship": "Lineage references this Query Store object",
            "confidence": row.get("confidence") or "Medium",
            "command_preview": row.get("command_preview"),
        }
    return list(rows_by_key.values())


def merge_related_process_rows(*row_groups: list[dict[str, Any]]) -> list[dict[str, Any]]:
    rows_by_key: dict[str, dict[str, Any]] = {}
    for rows in row_groups:
        for row in rows:
            key = f"{row.get('process_name')}|{row.get('step_order')}|{row.get('relationship')}"
            existing = rows_by_key.get(key)
            if not existing or confidence_rank(row.get("confidence")) < confidence_rank(existing.get("confidence")):
                rows_by_key[key] = row
    return list(rows_by_key.values())


def recommendation_sql(source_area: str, finding: dict[str, Any]) -> str:
    check = str(finding.get("check_name") or "").lower()
    area = str(finding.get("health_area") or "").lower()
    job_name = str(finding.get("job_name") or "")
    subject = str(finding.get("subject_name") or "")
    index_name = str(finding.get("index_name") or "")

    if source_area == "Jobs":
        if "failed" in check or "canceled" in check:
            return f"EXEC msdb.dbo.sp_help_jobhistory @job_name = N'{tsql_escape(job_name)}';"
        if "owner" in check and job_name:
            return (
                f"EXEC msdb.dbo.sp_update_job\n"
                f"    @job_name = N'{tsql_escape(job_name)}',\n"
                f"    @owner_login_name = N'<controlled_service_login>';"
            )
        if "schedule" in check:
            return f"EXEC msdb.dbo.sp_help_jobschedule @job_name = N'{tsql_escape(job_name)}';"
        if "disabled" in check:
            return f"EXEC msdb.dbo.sp_update_job @job_name = N'{tsql_escape(job_name)}', @enabled = 1;"
        return f"EXEC msdb.dbo.sp_help_job @job_name = N'{tsql_escape(job_name)}';" if job_name else ""

    if source_area == "Index":
        if "missing" in area:
            return (
                f"-- Review existing indexes and workload before creating anything.\n"
                f"-- Candidate object: {subject}\n"
                f"-- Use equality/inequality/include columns from Evidence to draft a CREATE INDEX statement."
            )
        if "unused" in area and subject and index_name:
            return (
                f"-- Validate with a longer observation window before dropping.\n"
                f"-- DROP INDEX [{tsql_bracket_escape(index_name)}] ON {subject};"
            )
        if "disabled" in area and subject and index_name:
            return f"ALTER INDEX [{tsql_bracket_escape(index_name)}] ON {subject} REBUILD;"
        if "hypothetical" in area and subject and index_name:
            return f"DROP INDEX [{tsql_bracket_escape(index_name)}] ON {subject};"
        if "heap" in area:
            return f"-- Review clustered index design for {subject} before creating one."
        return f"UPDATE STATISTICS {subject};" if subject else ""

    if source_area == "Storage":
        if "autogrowth" in area and subject:
            return (
                "ALTER DATABASE [<database_name>]\n"
                f"MODIFY FILE (NAME = N'{tsql_escape(subject)}', FILEGROWTH = 1024MB);"
            )
        if "space usage" in area and subject:
            return (
                "-- Check current file size, used space, growth setting, and max size first.\n"
                "SELECT\n"
                "    name,\n"
                "    type_desc,\n"
                "    size / 131072.0 AS size_gb,\n"
                "    FILEPROPERTY(name, 'SpaceUsed') / 131072.0 AS used_gb,\n"
                "    is_percent_growth,\n"
                "    growth,\n"
                "    max_size\n"
                "FROM sys.database_files\n"
                f"WHERE name = N'{tsql_escape(subject)}';\n\n"
                "-- Optional pre-grow only after validating disk capacity and maintenance window.\n"
                "-- ALTER DATABASE [<database_name>]\n"
                f"-- MODIFY FILE (NAME = N'{tsql_escape(subject)}', SIZE = <new_size_GB>GB);"
            )
        if "log usage" in area:
            return "SELECT name, log_reuse_wait_desc FROM sys.databases WHERE database_id = DB_ID();"
        return ""

    if source_area == "Waits / TempDB":
        if "blocking" in area:
            return "SELECT * FROM sys.dm_exec_requests WHERE blocking_session_id <> 0;"
        if "tempdb" in area:
            return (
                "SELECT session_id,\n"
                "       (user_objects_alloc_page_count + internal_objects_alloc_page_count\n"
                "        - user_objects_dealloc_page_count - internal_objects_dealloc_page_count) / 128.0 AS net_tempdb_mb\n"
                "FROM sys.dm_db_session_space_usage\n"
                "ORDER BY net_tempdb_mb DESC;"
            )
        return "SELECT session_id, status, wait_type, wait_time, blocking_session_id FROM sys.dm_exec_requests WHERE session_id <> @@SPID;"

    if source_area == "Query Store":
        query_id = finding.get("query_id")
        return (
            "SELECT\n"
            "    q.query_id,\n"
            "    p.plan_id,\n"
            "    p.is_forced_plan,\n"
            "    p.last_execution_time,\n"
            "    qt.query_sql_text\n"
            "FROM sys.query_store_query AS q\n"
            "INNER JOIN sys.query_store_query_text AS qt ON qt.query_text_id = q.query_text_id\n"
            "INNER JOIN sys.query_store_plan AS p ON p.query_id = q.query_id\n"
            f"WHERE q.query_id = {int(query_id)};"
        ) if query_id is not None else ""

    return ""


def recommendation_impact_hint(source_area: str) -> str:
    hints = {
        "Jobs": "Operational process may fail, skip a scheduled load, or run under an unsafe owner.",
        "Index": "Index changes can improve reads but may add write overhead, blocking, or maintenance cost.",
        "Storage": "Storage changes can affect growth behavior, disk pressure, and transaction log availability.",
        "Waits / TempDB": "Current activity can affect users now; review live sessions before acting.",
        "Query Store": "Recent performance changed compared with its Query Store baseline.",
    }
    return hints.get(source_area, "Review impact before applying changes.")


def default_recommended_action(source_area: str) -> str:
    if source_area == "Query Store":
        return (
            "Review plan changes, statistics freshness, related indexes, parameter sensitivity, "
            "and current blocking/waits before forcing plans or changing schema."
        )
    return f"Review the {source_area} finding and validate impact before changing SQL Server."


def recommendation_safety_notes(source_area: str, suggested_sql: str) -> str:
    if not suggested_sql:
        return "No generic SQL is safe enough for this finding; review manually."
    notes = {
        "Index": "Do not run blindly. Check workload, blocking risk, edition support, and maintenance window.",
        "Jobs": "Validate owner, schedule, and failing step first. Suggested SQL is diagnostic or administrative.",
        "Storage": "Replace placeholders, confirm disk capacity, and avoid growth changes during peak load.",
        "Waits / TempDB": "Diagnostic SQL only. Do not kill sessions without confirming business impact.",
        "Query Store": "Diagnostic SQL only. Validate plans, workload window, and business timing before forcing or changing anything.",
    }
    return notes.get(source_area, "Suggested SQL is a starting point, not an automatic fix.")


def tsql_escape(value: str) -> str:
    return str(value or "").replace("'", "''")


def tsql_bracket_escape(value: str) -> str:
    return str(value or "").replace("]", "]]")


def lineage_from_process_objects_sql(query_name: str, rows: list[dict[str, Any]]) -> str:
    payload_rows: list[dict[str, Any]] = []
    for row in rows:
        object_name = row.get("object_name") or row.get("called_object_name")
        if not object_name:
            continue
        payload_rows.append(
            {
                "process_name": row.get("process_name"),
                "job_id": row.get("job_id"),
                "step_order": row.get("step_order") or row.get("step_id"),
                "step_name": row.get("step_name"),
                "database_name": row.get("database_name"),
                "called_schema": row.get("schema_name") or "dbo",
                "called_object_name": object_name,
                "called_object_type": row.get("object_type") or row.get("called_object_type"),
                "detection_method": row.get("detection_method"),
                "source_confidence": row.get("confidence"),
                "command_preview": row.get("command_preview"),
            }
        )

    if not payload_rows:
        if query_name == "used_by_jobs":
            return """
SELECT
    CAST(NULL AS sysname) AS referenced_schema,
    CAST(NULL AS sysname) AS referenced_object,
    CAST(NULL AS nvarchar(60)) AS referenced_type,
    CAST(NULL AS sysname) AS process_name,
    CAST(NULL AS int) AS step_order,
    CAST(NULL AS sysname) AS step_name,
    CAST(NULL AS sysname) AS database_name,
    CAST(NULL AS sysname) AS called_schema,
    CAST(NULL AS sysname) AS called_object_name,
    CAST(NULL AS nvarchar(60)) AS called_object_type,
    CAST(NULL AS varchar(10)) AS confidence
WHERE 1 = 0;
"""
        return """
SELECT
    CAST(NULL AS sysname) AS process_name,
    CAST(NULL AS int) AS step_order,
    CAST(NULL AS sysname) AS step_name,
    CAST(NULL AS sysname) AS database_name,
    CAST(NULL AS sysname) AS called_schema,
    CAST(NULL AS sysname) AS called_object_name,
    CAST(NULL AS nvarchar(60)) AS called_object_type,
    CAST(NULL AS sysname) AS referenced_schema,
    CAST(NULL AS sysname) AS referenced_object,
    CAST(NULL AS nvarchar(60)) AS referenced_type,
    CAST(NULL AS nvarchar(80)) AS resolution_status,
    CAST(NULL AS bit) AS is_resolved,
    CAST(NULL AS bit) AS has_dynamic_sql,
    CAST(NULL AS nvarchar(4000)) AS lineage_note,
    CAST(NULL AS varchar(10)) AS confidence
WHERE 1 = 0;
"""

    payload_json = sql_literal(json.dumps(payload_rows, ensure_ascii=True, default=str))
    common = f"""
DECLARE @lineage_json nvarchar(max) = {payload_json};
DECLARE @called TABLE (
    process_name sysname NULL,
    job_id uniqueidentifier NULL,
    step_order int NULL,
    step_name sysname NULL,
    database_name sysname NULL,
    called_schema sysname NULL,
    called_object_name sysname NULL,
    called_object_type nvarchar(60) NULL,
    detection_method nvarchar(120) NULL,
    source_confidence varchar(10) NULL,
    command_preview nvarchar(500) NULL
);

INSERT INTO @called (
    process_name,
    job_id,
    step_order,
    step_name,
    database_name,
    called_schema,
    called_object_name,
    called_object_type,
    detection_method,
    source_confidence,
    command_preview
)
SELECT
    process_name,
    TRY_CONVERT(uniqueidentifier, job_id),
    step_order,
    step_name,
    database_name,
    called_schema,
    called_object_name,
    called_object_type,
    detection_method,
    source_confidence,
    command_preview
FROM OPENJSON(@lineage_json)
WITH (
    process_name sysname '$.process_name',
    job_id nvarchar(50) '$.job_id',
    step_order int '$.step_order',
    step_name sysname '$.step_name',
    database_name sysname '$.database_name',
    called_schema sysname '$.called_schema',
    called_object_name sysname '$.called_object_name',
    called_object_type nvarchar(60) '$.called_object_type',
    detection_method nvarchar(120) '$.detection_method',
    source_confidence varchar(10) '$.source_confidence',
    command_preview nvarchar(500) '$.command_preview'
);

SELECT
    c.process_name,
    c.job_id,
    c.step_order,
    c.step_name,
    c.database_name,
    COALESCE(c.called_schema, 'dbo') AS called_schema,
    c.called_object_name,
    COALESCE(
        CONVERT(nvarchar(60), o.type_desc) COLLATE DATABASE_DEFAULT,
        c.called_object_type COLLATE DATABASE_DEFAULT,
        N'Unresolved SQL object' COLLATE DATABASE_DEFAULT
    ) AS called_object_type,
    o.object_id AS called_object_id,
    c.detection_method,
    c.source_confidence,
    c.command_preview,
    sm.definition AS called_definition,
    CASE
        WHEN o.object_id IS NULL THEN CAST(0 AS bit)
        ELSE CAST(1 AS bit)
    END AS is_resolved,
    CASE
        WHEN o.object_id IS NULL THEN N'Unresolved object'
        WHEN sm.definition IS NULL AND o.type IN ('P', 'V', 'TR', 'FN', 'IF', 'TF') THEN N'Definition not visible'
        ELSE N'Resolved'
    END AS resolution_status,
    CASE
        WHEN LOWER((COALESCE(c.command_preview, N'') COLLATE DATABASE_DEFAULT) + N' ' + (COALESCE(sm.definition, N'') COLLATE DATABASE_DEFAULT)) LIKE N'%sp_executesql%'
          OR LOWER((COALESCE(c.command_preview, N'') COLLATE DATABASE_DEFAULT) + N' ' + (COALESCE(sm.definition, N'') COLLATE DATABASE_DEFAULT)) LIKE N'%exec(@%'
          OR LOWER((COALESCE(c.command_preview, N'') COLLATE DATABASE_DEFAULT) + N' ' + (COALESCE(sm.definition, N'') COLLATE DATABASE_DEFAULT)) LIKE N'%execute(@%'
          OR LOWER((COALESCE(c.command_preview, N'') COLLATE DATABASE_DEFAULT) + N' ' + (COALESCE(sm.definition, N'') COLLATE DATABASE_DEFAULT)) LIKE N'%exec (@%'
          OR LOWER((COALESCE(c.command_preview, N'') COLLATE DATABASE_DEFAULT) + N' ' + (COALESCE(sm.definition, N'') COLLATE DATABASE_DEFAULT)) LIKE N'%execute (@%'
          OR LOWER((COALESCE(c.command_preview, N'') COLLATE DATABASE_DEFAULT) + N' ' + (COALESCE(sm.definition, N'') COLLATE DATABASE_DEFAULT)) LIKE N'%+ @%'
        THEN CAST(1 AS bit)
        ELSE CAST(0 AS bit)
    END AS has_dynamic_sql
INTO #resolved
FROM @called AS c
LEFT JOIN sys.schemas AS s
    ON s.name = COALESCE(c.called_schema, 'dbo')
LEFT JOIN sys.objects AS o
    ON o.schema_id = s.schema_id
   AND o.name = c.called_object_name
LEFT JOIN sys.sql_modules AS sm
    ON sm.object_id = o.object_id;
"""
    if query_name == "used_by_jobs":
        return common + """
BEGIN TRY
    SELECT
        COALESCE(target_schema.name, sed.referenced_schema_name) AS referenced_schema,
        COALESCE(target_object.name, sed.referenced_entity_name) AS referenced_object,
        target_object.type_desc AS referenced_type,
        resolved.process_name,
        resolved.step_order,
        resolved.step_name,
        resolved.database_name,
        resolved.called_schema,
        resolved.called_object_name,
        resolved.called_object_type,
        resolved.command_preview,
        resolved.called_definition,
        resolved.resolution_status,
        resolved.is_resolved,
        resolved.has_dynamic_sql,
        CASE
            WHEN resolved.called_object_id IS NULL THEN N'Object was detected in command text, but it was not resolved in this database.'
            WHEN resolved.called_definition IS NULL THEN N'Object exists, but its definition is not visible or is encrypted; dependency coverage may be partial.'
            WHEN resolved.has_dynamic_sql = 1 THEN N'Dynamic SQL detected; referenced objects may be incomplete.'
            ELSE NULL
        END AS lineage_note,
        CASE
            WHEN resolved.called_object_id IS NOT NULL AND sed.referenced_id IS NOT NULL THEN 'High'
            WHEN resolved.called_object_id IS NOT NULL AND resolved.called_definition IS NOT NULL THEN 'Medium'
            ELSE 'Low'
        END AS confidence
    FROM #resolved AS resolved
    LEFT JOIN sys.sql_expression_dependencies AS sed
        ON sed.referencing_id = resolved.called_object_id
    LEFT JOIN sys.objects AS target_object
        ON target_object.object_id = sed.referenced_id
    LEFT JOIN sys.schemas AS target_schema
        ON target_schema.schema_id = target_object.schema_id
    WHERE COALESCE(target_object.name, sed.referenced_entity_name) IS NOT NULL
    ORDER BY referenced_schema, referenced_object, process_name, step_order;
END TRY
BEGIN CATCH
    SELECT
        CAST(NULL AS sysname) AS referenced_schema,
        CAST(NULL AS sysname) AS referenced_object,
        CAST(NULL AS nvarchar(60)) AS referenced_type,
        process_name,
        step_order,
        step_name,
        database_name,
        called_schema,
        called_object_name,
        called_object_type,
        command_preview,
        called_definition,
        N'Dependency metadata not visible' AS resolution_status,
        is_resolved,
        has_dynamic_sql,
        CONCAT(N'Dependency metadata could not be read: ', ERROR_MESSAGE()) AS lineage_note,
        'Low' AS confidence
    FROM #resolved AS resolved;
END CATCH;
"""

    return common + """
BEGIN TRY
    SELECT
        resolved.process_name,
        resolved.step_order,
        resolved.step_name,
        resolved.database_name,
        resolved.called_schema,
        resolved.called_object_name,
        resolved.called_object_type,
        resolved.command_preview,
        resolved.called_definition,
        COALESCE(target_schema.name, sed.referenced_schema_name) AS referenced_schema,
        COALESCE(target_object.name, sed.referenced_entity_name) AS referenced_object,
        target_object.type_desc AS referenced_type,
        resolved.resolution_status,
        resolved.is_resolved,
        resolved.has_dynamic_sql,
        CASE
            WHEN resolved.called_object_id IS NULL THEN N'Object was detected in command text, but it was not resolved in this database.'
            WHEN resolved.called_definition IS NULL THEN N'Object exists, but its definition is not visible or is encrypted; dependency coverage may be partial.'
            WHEN resolved.has_dynamic_sql = 1 THEN N'Dynamic SQL detected; referenced objects may be incomplete.'
            WHEN resolved.called_object_id IS NOT NULL AND sed.referenced_id IS NULL THEN N'No catalog dependencies were returned; temp tables, permissions, or dynamic SQL may hide references.'
            ELSE NULL
        END AS lineage_note,
        CASE
            WHEN resolved.called_object_id IS NOT NULL AND sed.referenced_id IS NOT NULL THEN 'High'
            WHEN resolved.called_object_id IS NOT NULL AND resolved.called_definition IS NOT NULL THEN 'Medium'
            ELSE 'Low'
        END AS confidence
    FROM #resolved AS resolved
    LEFT JOIN sys.sql_expression_dependencies AS sed
        ON sed.referencing_id = resolved.called_object_id
    LEFT JOIN sys.objects AS target_object
        ON target_object.object_id = sed.referenced_id
    LEFT JOIN sys.schemas AS target_schema
        ON target_schema.schema_id = target_object.schema_id
    ORDER BY process_name, step_order, referenced_schema, referenced_object;
END TRY
BEGIN CATCH
    SELECT
        process_name,
        step_order,
        step_name,
        database_name,
        called_schema,
        called_object_name,
        called_object_type,
        command_preview,
        called_definition,
        CAST(NULL AS sysname) AS referenced_schema,
        CAST(NULL AS sysname) AS referenced_object,
        CAST(NULL AS nvarchar(60)) AS referenced_type,
        N'Dependency metadata not visible' AS resolution_status,
        is_resolved,
        has_dynamic_sql,
        CONCAT(N'Dependency metadata could not be read: ', ERROR_MESSAGE()) AS lineage_note,
        'Low' AS confidence
    FROM #resolved AS resolved
    ORDER BY process_name, step_order, called_schema, called_object_name;
END CATCH;
"""


def table_lineage_features_sql(rows: list[dict[str, Any]]) -> str:
    table_refs: dict[str, dict[str, Any]] = {}
    for row in rows:
        referenced_type = str(row.get("referenced_type") or "").upper()
        table_schema = row.get("referenced_schema")
        table_name = row.get("referenced_object")
        if not table_schema or not table_name or "TABLE" not in referenced_type:
            continue
        key = f"{table_schema}.{table_name}".lower()
        table_refs[key] = {
            "table_schema": table_schema,
            "table_name": table_name,
        }

    if not table_refs:
        return """
SELECT
    CAST(NULL AS varchar(24)) AS feature_kind,
    CAST(NULL AS sysname) AS table_schema,
    CAST(NULL AS sysname) AS table_name,
    CAST(NULL AS sysname) AS feature_schema,
    CAST(NULL AS sysname) AS feature_name,
    CAST(NULL AS nvarchar(80)) AS feature_type,
    CAST(NULL AS nvarchar(80)) AS status,
    CAST(NULL AS nvarchar(max)) AS events,
    CAST(NULL AS nvarchar(max)) AS referenced_columns,
    CAST(NULL AS nvarchar(max)) AS definition
WHERE 1 = 0;
"""

    payload_json = sql_literal(json.dumps(list(table_refs.values()), ensure_ascii=True, default=str))
    return f"""
DECLARE @table_json nvarchar(max) = {payload_json};

DECLARE @tables TABLE (
    table_schema sysname NOT NULL,
    table_name sysname NOT NULL,
    object_id int NULL
);

INSERT INTO @tables (table_schema, table_name, object_id)
SELECT
    refs.table_schema,
    refs.table_name,
    tbl.object_id
FROM OPENJSON(@table_json)
WITH (
    table_schema sysname '$.table_schema',
    table_name sysname '$.table_name'
) AS refs
LEFT JOIN sys.schemas AS sch
    ON sch.name = refs.table_schema
LEFT JOIN sys.tables AS tbl
    ON tbl.schema_id = sch.schema_id
   AND tbl.name = refs.table_name;

SELECT
    features.feature_kind,
    features.table_schema,
    features.table_name,
    features.feature_schema,
    features.feature_name,
    features.feature_type,
    features.status,
    features.events,
    features.referenced_columns,
    features.definition
FROM (
    SELECT
        CAST('trigger' AS varchar(24)) AS feature_kind,
        refs.table_schema,
        refs.table_name,
        COALESCE(OBJECT_SCHEMA_NAME(trg.object_id), refs.table_schema) AS feature_schema,
        trg.name AS feature_name,
        CONCAT(CASE WHEN trg.is_instead_of_trigger = 1 THEN 'INSTEAD OF' ELSE 'AFTER' END, ' ', trg.type_desc) AS feature_type,
        CASE WHEN trg.is_disabled = 1 THEN 'Disabled' ELSE 'Enabled' END AS status,
        event_list.events,
        column_list.referenced_columns,
        mod.definition
    FROM @tables AS refs
    INNER JOIN sys.triggers AS trg
        ON trg.parent_id = refs.object_id
    LEFT JOIN sys.sql_modules AS mod
        ON mod.object_id = trg.object_id
    OUTER APPLY (
        SELECT STRING_AGG(CONVERT(nvarchar(max), te.type_desc), N', ') WITHIN GROUP (ORDER BY te.type_desc) AS events
        FROM sys.trigger_events AS te
        WHERE te.object_id = trg.object_id
    ) AS event_list
    OUTER APPLY (
        SELECT STRING_AGG(CONVERT(nvarchar(max), col.name), N', ') WITHIN GROUP (ORDER BY col.column_id) AS referenced_columns
        FROM sys.sql_expression_dependencies AS dep
        INNER JOIN sys.columns AS col
            ON col.object_id = dep.referenced_id
           AND col.column_id = dep.referenced_minor_id
        WHERE dep.referencing_id = trg.object_id
          AND dep.referenced_id = refs.object_id
          AND dep.referenced_minor_id > 0
    ) AS column_list

    UNION ALL

    SELECT
        CAST('computed_column' AS varchar(24)) AS feature_kind,
        refs.table_schema,
        refs.table_name,
        refs.table_schema AS feature_schema,
        col.name AS feature_name,
        CAST('Computed column' AS nvarchar(80)) AS feature_type,
        CASE WHEN cc.is_persisted = 1 THEN 'Persisted' ELSE 'Not persisted' END AS status,
        CAST(NULL AS nvarchar(max)) AS events,
        column_list.referenced_columns,
        cc.definition
    FROM @tables AS refs
    INNER JOIN sys.computed_columns AS cc
        ON cc.object_id = refs.object_id
    INNER JOIN sys.columns AS col
        ON col.object_id = cc.object_id
       AND col.column_id = cc.column_id
    OUTER APPLY (
        SELECT STRING_AGG(CONVERT(nvarchar(max), source_col.name), N', ') WITHIN GROUP (ORDER BY source_col.column_id) AS referenced_columns
        FROM sys.sql_expression_dependencies AS dep
        INNER JOIN sys.columns AS source_col
            ON source_col.object_id = dep.referenced_id
           AND source_col.column_id = dep.referenced_minor_id
        WHERE dep.referencing_id = refs.object_id
          AND dep.referencing_minor_id = cc.column_id
          AND dep.referenced_id = refs.object_id
          AND dep.referenced_minor_id > 0
    ) AS column_list
) AS features
ORDER BY
    features.table_schema,
    features.table_name,
    CASE features.feature_kind WHEN 'trigger' THEN 1 ELSE 2 END,
    features.feature_name;
"""


def lineage_map_targets_sql(map_type: str) -> str:
    normalized = map_type.strip().lower()
    if normalized == "procedures":
        return """
SELECT
    CONCAT(s.name, N'.', o.name) AS process_name
FROM sys.objects AS o
INNER JOIN sys.schemas AS s
    ON s.schema_id = o.schema_id
WHERE o.type = 'P'
  AND o.is_ms_shipped = 0
ORDER BY s.name, o.name;
"""
    if normalized == "views":
        return """
SELECT
    CONCAT(s.name, N'.', o.name) AS process_name
FROM sys.objects AS o
INNER JOIN sys.schemas AS s
    ON s.schema_id = o.schema_id
WHERE o.type = 'V'
  AND o.is_ms_shipped = 0
ORDER BY s.name, o.name;
"""
    if normalized == "functions":
        return """
SELECT
    CONCAT(s.name, N'.', o.name) AS process_name
FROM sys.objects AS o
INNER JOIN sys.schemas AS s
    ON s.schema_id = o.schema_id
WHERE o.type IN ('FN', 'IF', 'TF', 'FS', 'FT')
  AND o.is_ms_shipped = 0
ORDER BY s.name, o.name;
"""
    return """
SELECT
    name AS process_name
FROM msdb.dbo.sysjobs
ORDER BY name;
"""


def focused_process_map_jobs_sql() -> str:
    return lineage_map_targets_sql("jobs")


def focused_sql_object_map_sql(map_type: str, object_name: str) -> str:
    object_value = sql_literal(object_name)
    type_filter = {
        "procedures": "o.type = 'P'",
        "views": "o.type = 'V'",
        "functions": "o.type IN ('FN', 'IF', 'TF', 'FS', 'FT')",
    }.get(map_type, "o.type IN ('P', 'V', 'FN', 'IF', 'TF', 'FS', 'FT')")
    return f"""
DECLARE @object_full_name nvarchar(517) = {object_value};
DECLARE @schema_name sysname = COALESCE(PARSENAME(@object_full_name, 2), 'dbo');
DECLARE @object_name sysname = PARSENAME(@object_full_name, 1);

SELECT
    CONCAT(s.name, N'.', o.name) AS process_name,
    CAST(NULL AS uniqueidentifier) AS job_id,
    1 AS step_order,
    CONCAT(s.name, N'.', o.name) AS step_name,
    DB_NAME() AS database_name,
    o.type_desc AS object_type,
    CAST(NULL AS sysname) AS referenced_database,
    s.name AS schema_name,
    o.name AS object_name,
    CONCAT(s.name, N'.', o.name) AS detected_object_text,
    'Selected SQL object' AS detection_method,
    'High' AS confidence,
    CAST(NULL AS nvarchar(500)) AS command_preview
FROM sys.objects AS o
INNER JOIN sys.schemas AS s
    ON s.schema_id = o.schema_id
WHERE {type_filter}
  AND o.is_ms_shipped = 0
  AND s.name = @schema_name
  AND o.name = @object_name
ORDER BY s.name, o.name;
"""


def focused_process_sql_objects_sql(process_name: str) -> str:
    process_value = sql_literal(process_name)
    return f"""
DECLARE @process_name sysname = {process_value};
DECLARE @job_id uniqueidentifier = NULL;

SELECT @job_id = job_id
FROM msdb.dbo.sysjobs
WHERE name = @process_name;

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
    EXEC msdb.dbo.sp_help_jobstep @job_name = @process_name;
END TRY
BEGIN CATCH
    BEGIN TRY
        INSERT INTO #step_raw
        EXEC msdb.dbo.sp_help_jobstep @job_id = @job_id;
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
                js.step_id,
                js.step_name,
                js.subsystem,
                js.command,
                js.flags,
                js.cmdexec_success_code,
                js.on_success_action,
                js.on_success_step_id,
                js.on_fail_action,
                js.on_fail_step_id,
                js.server,
                js.database_name,
                js.database_user_name,
                js.retry_attempts,
                js.retry_interval,
                js.os_run_priority,
                js.output_file_name,
                js.last_run_outcome,
                js.last_run_duration,
                js.last_run_retries,
                js.last_run_date,
                js.last_run_time,
                js.proxy_id
            FROM msdb.dbo.sysjobsteps AS js
            INNER JOIN msdb.dbo.sysjobs AS j
                ON j.job_id = js.job_id
            WHERE j.name = @process_name;
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
    @process_name AS process_name,
    @job_id AS job_id,
    step_id AS step_order,
    step_name,
    database_name,
    'Procedure' AS object_type,
    PARSENAME(detected_object, 3) AS referenced_database,
    COALESCE(PARSENAME(detected_object, 2), 'dbo') AS schema_name,
    PARSENAME(detected_object, 1) AS object_name,
    detected_object AS detected_object_text,
    'Focused job step EXEC keyword' AS detection_method,
    CASE WHEN PARSENAME(detected_object, 2) IS NOT NULL THEN 'High' ELSE 'Medium' END AS confidence,
    command_preview
FROM detected
WHERE detected_object IS NOT NULL
  AND detected_object <> ''
  AND detected_object NOT LIKE '@%'
ORDER BY step_id, detected_object;
"""


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

    IF @steps_error IS NOT NULL
    BEGIN
        SELECT
            @process_name AS process_name,
            CAST(NULL AS int) AS step_order,
            CAST(NULL AS sysname) AS step_name,
            CAST(NULL AS sysname) AS database_name,
            CAST(NULL AS varchar(20)) AS object_type,
            CAST(NULL AS sysname) AS schema_name,
            CAST(NULL AS sysname) AS object_name,
            @steps_error AS detection_method,
            CAST(NULL AS varchar(10)) AS confidence,
            CAST(NULL AS nvarchar(500)) AS command_preview;
    END
    ELSE
    BEGIN
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
            @process_name AS process_name,
            step_id AS step_order,
            step_name,
            database_name,
            'Procedure' AS object_type,
            COALESCE(PARSENAME(detected_object, 2), 'dbo') AS schema_name,
            PARSENAME(detected_object, 1) AS object_name,
            'Process detail EXEC keyword' AS detection_method,
            CASE WHEN PARSENAME(detected_object, 2) IS NOT NULL THEN 'High' ELSE 'Medium' END AS confidence,
            command_preview
        FROM detected
        WHERE detected_object IS NOT NULL
          AND detected_object <> ''
          AND detected_object NOT LIKE '@%'
        ORDER BY step_id, detected_object;
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

    SELECT
        @process_name AS process_name,
        CAST(NULL AS int) AS step_order,
        CAST(NULL AS sysname) AS step_name,
        CAST(NULL AS sysname) AS database_name,
        CAST(NULL AS varchar(20)) AS object_type,
        CAST(NULL AS sysname) AS schema_name,
        CAST(NULL AS sysname) AS object_name,
        ERROR_MESSAGE() AS detection_method,
        CAST(NULL AS varchar(10)) AS confidence,
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
