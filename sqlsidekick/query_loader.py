from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

RESERVED_QUERY_DIRS = {"light", "full", "basic_alerts"}


@dataclass(frozen=True)
class QueryDefinition:
    name: str
    title: str
    description: str
    sql: str


def load_named_queries(path: Path, version: str = "full") -> dict[str, QueryDefinition]:
    version = normalize_version(version)
    if path.is_dir():
        queries: dict[str, QueryDefinition] = {}
        for sql_path in iter_sql_files(path, version):
            queries.update(load_named_queries(sql_path, version=version))
        return queries

    queries: dict[str, QueryDefinition] = {}
    current_name: str | None = None
    current_title = ""
    current_description = ""
    current_sql: list[str] = []

    def flush() -> None:
        nonlocal current_name, current_title, current_description, current_sql
        if not current_name:
            return
        sql = "\n".join(current_sql).strip()
        if sql:
            queries[current_name] = QueryDefinition(
                name=current_name,
                title=current_title or current_name.replace("_", " ").title(),
                description=current_description,
                sql=sql,
            )
        current_name = None
        current_title = ""
        current_description = ""
        current_sql = []

    for raw_line in path.read_text(encoding="utf-8-sig").splitlines():
        line = raw_line.strip()
        if line.startswith("-- name:"):
            flush()
            current_name = line.split(":", 1)[1].strip()
            continue
        if current_name and line.startswith("-- title:"):
            current_title = line.split(":", 1)[1].strip()
            continue
        if current_name and line.startswith("-- description:"):
            current_description = line.split(":", 1)[1].strip()
            continue
        if current_name:
            current_sql.append(raw_line)

    flush()
    return queries


def normalize_version(version: str) -> str:
    normalized = (version or "full").strip().lower()
    if normalized not in {"light", "full"}:
        return "full"
    return normalized


def iter_sql_files(path: Path, version: str) -> list[Path]:
    if has_version_children(path):
        selected_dirs = [path / "light"]
        if version == "full":
            selected_dirs.append(path / "full")
        files: list[Path] = []
        for selected_dir in selected_dirs:
            if selected_dir.is_dir():
                files.extend(sorted(selected_dir.glob("*.sql")))
        for child in sorted(path.iterdir()):
            if child.is_dir() and child.name.lower() not in RESERVED_QUERY_DIRS:
                files.extend(iter_sql_files(child, version))
        return files

    files: list[Path] = []
    for child in sorted(path.iterdir()):
        if child.is_file() and child.suffix.lower() == ".sql":
            files.append(child)
        elif child.is_dir() and child.name.lower() not in RESERVED_QUERY_DIRS:
            files.extend(iter_sql_files(child, version))
    return files


def has_version_children(path: Path) -> bool:
    return (path / "light").is_dir() or (path / "full").is_dir()
