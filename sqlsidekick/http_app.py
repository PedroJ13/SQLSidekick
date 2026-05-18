from __future__ import annotations

import json
import mimetypes
from http.server import BaseHTTPRequestHandler
from pathlib import Path
from typing import Any
from urllib.parse import parse_qs, urlparse

from sqlsidekick.query_loader import load_named_queries
from sqlsidekick.sql_server import ConnectionSettings, SQLServerError, execute_query, test_connection


class SQLSidekickHandler(BaseHTTPRequestHandler):
    root: Path
    queries_path: Path
    static_path: Path

    @classmethod
    def configure(cls, root: Path) -> None:
        cls.root = root
        cls.queries_path = root / "sql" / "documentation.sql"
        cls.static_path = root / "static"

    def do_GET(self) -> None:
        parsed = urlparse(self.path)
        if parsed.path == "/":
            self.serve_file(self.static_path / "index.html")
            return
        if parsed.path == "/api/health":
            self.send_json({"ok": True, "name": "SQLSidekick"})
            return
        if parsed.path == "/api/queries":
            queries = load_named_queries(self.queries_path)
            self.send_json(
                {
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
            queries = load_named_queries(self.queries_path)
            if name not in queries:
                self.send_json({"error": "Consulta no encontrada."}, status=404)
                return
            self.send_json({"name": name, "sql": queries[name].sql})
            return
        if parsed.path.startswith("/static/"):
            relative = parsed.path.removeprefix("/static/")
            self.serve_file(self.static_path / relative)
            return
        self.send_json({"error": "Ruta no encontrada."}, status=404)

    def do_POST(self) -> None:
        parsed = urlparse(self.path)
        if parsed.path == "/api/test-connection":
            self.handle_sql_action(test_connection)
            return
        if parsed.path == "/api/run-query":
            self.handle_run_query()
            return
        self.send_json({"error": "Ruta no encontrada."}, status=404)

    def handle_run_query(self) -> None:
        payload = self.read_json()
        name = str(payload.get("queryName", "")).strip()
        queries = load_named_queries(self.queries_path)
        if name not in queries:
            self.send_json({"error": "Consulta no encontrada."}, status=404)
            return

        def action(settings: ConnectionSettings) -> dict[str, Any]:
            return execute_query(settings, queries[name].sql)

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
