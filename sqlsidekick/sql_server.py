from __future__ import annotations

import importlib.util
import re
from dataclasses import dataclass
from typing import Any


class SQLServerError(RuntimeError):
    pass


@dataclass
class ConnectionSettings:
    server: str
    database: str
    auth_type: str
    username: str = ""
    password: str = ""
    encrypt: bool = True
    trust_server_certificate: bool = True
    timeout: int = 12

    @classmethod
    def from_payload(cls, payload: dict[str, Any]) -> "ConnectionSettings":
        server = str(payload.get("server", "")).strip()
        database = str(payload.get("database", "")).strip()
        auth_type = str(payload.get("authType", "sql")).strip().lower()
        if not server or not database:
            raise SQLServerError("Servidor y base de datos son obligatorios.")
        if auth_type not in {"sql", "windows"}:
            raise SQLServerError("Tipo de autenticacion no soportado.")
        return cls(
            server=server,
            database=database,
            auth_type=auth_type,
            username=str(payload.get("username", "")).strip(),
            password=str(payload.get("password", "")),
            encrypt=bool(payload.get("encrypt", True)),
            trust_server_certificate=bool(payload.get("trustServerCertificate", True)),
        )

    def connection_string(self) -> str:
        driver = detect_sql_server_driver()
        parts = [
            f"DRIVER={{{driver}}}",
            f"SERVER={odbc_value(self.server)}",
            f"DATABASE={odbc_value(self.database)}",
            f"Encrypt={'yes' if self.encrypt else 'no'}",
            f"TrustServerCertificate={'yes' if self.trust_server_certificate else 'no'}",
            f"Connection Timeout={self.timeout}",
        ]
        if self.auth_type == "windows":
            parts.append("Trusted_Connection=yes")
        else:
            if not self.username:
                raise SQLServerError("Usuario SQL requerido para autenticacion SQL.")
            parts.extend([f"UID={odbc_value(self.username)}", f"PWD={odbc_value(self.password)}"])
        return ";".join(parts)


def pyodbc_available() -> bool:
    return importlib.util.find_spec("pyodbc") is not None


def pymssql_available() -> bool:
    return importlib.util.find_spec("pymssql") is not None


def detect_sql_server_driver() -> str:
    if not pyodbc_available():
        raise SQLServerError("pyodbc no esta instalado. Ejecuta: python -m pip install pyodbc")

    import pyodbc  # type: ignore[import-not-found]

    preferred = [
        "ODBC Driver 18 for SQL Server",
        "ODBC Driver 17 for SQL Server",
        "SQL Server Native Client 11.0",
        "SQL Server",
    ]
    installed = set(pyodbc.drivers())
    for driver in preferred:
        if driver in installed:
            return driver
    raise SQLServerError(
        "No encontre un driver ODBC de SQL Server instalado. Instala Microsoft ODBC Driver 18 o 17 for SQL Server."
    )


def execute_query(settings: ConnectionSettings, sql: str) -> dict[str, Any]:
    if pyodbc_available():
        try:
            return execute_query_pyodbc(settings, sql)
        except SQLServerError as exc:
            if settings.auth_type == "sql" and pymssql_available() and should_fallback_to_pymssql(str(exc)):
                return execute_query_pymssql(settings, sql)
            raise

    if settings.auth_type == "sql" and pymssql_available():
        return execute_query_pymssql(settings, sql)

    raise SQLServerError(
        "No hay cliente SQL Server disponible. Instala pyodbc o pymssql: python -m pip install pyodbc pymssql"
    )


def execute_query_pyodbc(settings: ConnectionSettings, sql: str) -> dict[str, Any]:
    import pyodbc  # type: ignore[import-not-found]

    batches = split_batches(sql)
    result_sets: list[dict[str, Any]] = []
    messages: list[str] = []

    try:
        with pyodbc.connect(settings.connection_string()) as conn:
            conn.timeout = settings.timeout
            cursor = conn.cursor()
            for batch in batches:
                cursor.execute(batch)
                collect_result_sets(cursor, result_sets)
            messages.append("Consulta ejecutada correctamente.")
    except pyodbc.Error as exc:
        raise SQLServerError(format_pyodbc_error(exc)) from exc

    return {"resultSets": result_sets, "messages": messages}


def execute_query_pymssql(settings: ConnectionSettings, sql: str) -> dict[str, Any]:
    if settings.auth_type != "sql":
        raise SQLServerError("pymssql solo esta disponible para autenticacion SQL Login.")

    import pymssql  # type: ignore[import-not-found]

    host, port = split_server_port(settings.server)
    batches = split_batches(sql)
    result_sets: list[dict[str, Any]] = []

    try:
        with pymssql.connect(
            server=host,
            port=port,
            user=settings.username,
            password=settings.password,
            database=settings.database,
            login_timeout=settings.timeout,
            timeout=settings.timeout,
        ) as conn:
            cursor = conn.cursor()
            for batch in batches:
                cursor.execute(batch)
                collect_pymssql_result_sets(cursor, result_sets)
    except Exception as exc:
        raise SQLServerError(format_pymssql_error(exc)) from exc

    return {"resultSets": result_sets, "messages": ["Consulta ejecutada correctamente con pymssql."]}


def test_connection(settings: ConnectionSettings) -> dict[str, Any]:
    sql = """
SELECT
    @@SERVERNAME AS server_name,
    DB_NAME() AS database_name,
    SYSTEM_USER AS login_name,
    SUSER_SNAME() AS security_context,
    CONVERT(varchar(30), SYSDATETIME(), 126) AS server_time;
"""
    return execute_query(settings, sql)


def split_batches(sql: str) -> list[str]:
    batches: list[str] = []
    current: list[str] = []
    go_pattern = re.compile(r"^\s*GO\s*(?:--.*)?$", re.IGNORECASE)
    for line in sql.splitlines():
        if go_pattern.match(line):
            batch = "\n".join(current).strip()
            if batch:
                batches.append(batch)
            current = []
        else:
            current.append(line)
    tail = "\n".join(current).strip()
    if tail:
        batches.append(tail)
    return batches


def collect_result_sets(cursor: Any, output: list[dict[str, Any]]) -> None:
    while True:
        if cursor.description:
            columns = [column[0] for column in cursor.description]
            rows = [dict(zip(columns, normalize_row(row))) for row in cursor.fetchall()]
            output.append({"columns": columns, "rows": rows})
        if not cursor.nextset():
            break


def collect_pymssql_result_sets(cursor: Any, output: list[dict[str, Any]]) -> None:
    while True:
        if cursor.description:
            columns = [column[0] for column in cursor.description]
            rows = [dict(zip(columns, normalize_row(row))) for row in cursor.fetchall()]
            output.append({"columns": columns, "rows": rows})
        if not hasattr(cursor, "nextset") or not cursor.nextset():
            break


def normalize_row(row: Any) -> list[Any]:
    values: list[Any] = []
    for value in row:
        if hasattr(value, "isoformat"):
            values.append(value.isoformat())
        elif isinstance(value, bytes):
            values.append(value.hex())
        else:
            values.append(value)
    return values


def odbc_value(value: str) -> str:
    text = str(value)
    if not text:
        return ""
    if any(char in text for char in [";", "{", "}", "="]) or text != text.strip():
        return "{" + text.replace("}", "}}") + "}"
    return text


def format_pyodbc_error(exc: Exception) -> str:
    raw = str(exc)
    hints: list[str] = []
    if "Encryption not supported on the client" in raw or "SSL Provider" in raw:
        hints.append("Prueba desmarcar Encrypt y volver a conectar.")
    if "Server is not found or not accessible" in raw:
        hints.append("Verifica servidor, puerto 1433, firewall/security group y que el endpoint acepte conexiones externas.")
    if "Login failed" in raw:
        hints.append("Verifica usuario, password y permisos sobre la base de datos.")

    cleaned = (
        raw.replace("\\r\\n", " ")
        .replace("\r", " ")
        .replace("\n", " ")
        .replace("('", "")
        .replace("')", "")
    )
    while "  " in cleaned:
        cleaned = cleaned.replace("  ", " ")
    if hints:
        return f"{'; '.join(hints)} Detalle ODBC: {cleaned}"
    return cleaned


def format_pymssql_error(exc: Exception) -> str:
    raw = str(exc).replace("\r", " ").replace("\n", " ")
    while "  " in raw:
        raw = raw.replace("  ", " ")
    if "Login failed" in raw:
        return f"Login fallido. Verifica usuario, password y permisos. Detalle: {raw}"
    return raw


def should_fallback_to_pymssql(error: str) -> bool:
    signals = [
        "Encryption not supported on the client",
        "SSL Provider",
        "No credentials are available in the security package",
        "SSL Security error",
        "SECCreateCredentials",
    ]
    return any(signal in error for signal in signals)


def split_server_port(server: str) -> tuple[str, int]:
    if "," not in server:
        return server, 1433
    host, raw_port = server.rsplit(",", 1)
    try:
        return host.strip(), int(raw_port.strip())
    except ValueError as exc:
        raise SQLServerError("El puerto del servidor debe ser numerico, por ejemplo servidor.amazonaws.com,1433.") from exc
