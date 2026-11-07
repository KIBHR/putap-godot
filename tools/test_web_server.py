#!/usr/bin/env python3
"""Smoke-test the browser files and localhost HTTP response headers."""
from __future__ import annotations

from functools import partial
from http.server import ThreadingHTTPServer
from pathlib import Path
from threading import Thread
import urllib.request

import serve_web


def main() -> None:
    server = ThreadingHTTPServer(
        ("127.0.0.1", 0),
        partial(serve_web.GameHandler, directory=str(serve_web.DOCS)),
    )
    worker = Thread(target=server.serve_forever, daemon=True)
    worker.start()
    base_url = f"http://127.0.0.1:{server.server_port}"
    try:
        for path in ("/", "/potap.html", "/index.html", "/potap.js", "/potap.pck", "/potap.wasm"):
            with urllib.request.urlopen(base_url + path, timeout=10) as response:
                assert response.status == 200, path
                assert response.read(16), path
                assert response.headers["Cross-Origin-Opener-Policy"] == "same-origin", path
                assert response.headers["Cross-Origin-Embedder-Policy"] == "require-corp", path
                assert response.headers["Cross-Origin-Resource-Policy"] == "same-origin", path
                if path == "/potap.wasm":
                    assert response.headers.get_content_type() == "application/wasm"
        for file in ("potap.html", "index.html"):
            html = (serve_web.DOCS / file).read_text(encoding="utf-8")
            assert "window.location.protocol === 'file:'" in html
        print("PASS: local HTTP Web launch, Godot assets, MIME types and COOP/COEP headers")
    finally:
        server.shutdown()
        server.server_close()
        worker.join(timeout=2)


if __name__ == "__main__":
    main()
