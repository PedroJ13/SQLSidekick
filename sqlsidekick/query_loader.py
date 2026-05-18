from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class QueryDefinition:
    name: str
    title: str
    description: str
    sql: str


def load_named_queries(path: Path) -> dict[str, QueryDefinition]:
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

    for raw_line in path.read_text(encoding="utf-8").splitlines():
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

