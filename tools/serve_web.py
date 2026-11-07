#!/usr/bin/env python3
"""Serve the exported Godot game locally using only Python's standard library.

Open from the repository root with: python3 tools/serve_web.py
Unlike file://, HTTP allows fetching .pck and .wasm resources. The
COOP/COEP headers support Godot Web exports that use WebAssembly threads.
"""
from __future__ import annotations

import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import sys
import webbrowser


DOCS = Path(__file__).resolve().parent.parent / "docs"


class GameHandler(SimpleHTTPRequestHandler):
    extensions_map = {
        **SimpleHTTPRequestHandler.extensions_map,
        ".wasm": "application/wasm",
        ".pck": "application/octet-stream",
        ".js": "text/javascript",
    }

    def do_GET(self) -> None:
        if self.path == "/":
            self.path = "/potap.html"
        super().do_GET()

    def end_headers(self) -> None:
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cross-Origin-Resource-Policy", "same-origin")
        self.send_header("Cache-Control", "no-store")
        super().end_headers()


def main() -> int:
    parser = argparse.ArgumentParser(description="Run the Potap Web export locally")
    parser.add_argument("--port", type=int, default=8000, help="local port (default: 8000)")
    parser.add_argument("--no-open", action="store_true", help="do not open a browser")
    args = parser.parse_args()

    if not (DOCS / "potap.html").is_file() or not (DOCS / "potap.pck").is_file():
        print("Ошибка: файлы экспорта в docs/ отсутствуют. Обновите репозиторий.", file=sys.stderr)
        return 1

    handler = partial(GameHandler, directory=str(DOCS))
    try:
        server = ThreadingHTTPServer(("127.0.0.1", args.port), handler)
    except OSError as exc:
        print(f"Не удалось запустить сервер: {exc}", file=sys.stderr)
        print("Попробуйте другой порт: python3 tools/serve_web.py --port 8001", file=sys.stderr)
        return 1

    address = f"http://127.0.0.1:{server.server_port}/potap.html"
    print(f"Potap доступен по адресу: {address}", flush=True)
    print("Для остановки сервера нажмите Ctrl+C.", flush=True)
    if not args.no_open:
        webbrowser.open(address)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nСервер остановлен.", flush=True)
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
