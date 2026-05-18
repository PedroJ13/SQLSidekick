from __future__ import annotations

import json
from http.server import ThreadingHTTPServer
from pathlib import Path

from sqlsidekick.http_app import SQLSidekickHandler


ROOT = Path(__file__).resolve().parent
HOST = "127.0.0.1"
PORT = 8765


def main() -> None:
    SQLSidekickHandler.configure(root=ROOT)
    server = ThreadingHTTPServer((HOST, PORT), SQLSidekickHandler)
    print(json.dumps({"url": f"http://{HOST}:{PORT}", "app": "SQLSidekick"}))
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nSQLSidekick detenido.")
    finally:
        server.server_close()


if __name__ == "__main__":
    main()

