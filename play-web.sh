#!/usr/bin/env bash
# Launch Potap Web on macOS/Linux with a local HTTP server.
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_ROOT"
if ! command -v python3 >/dev/null 2>&1; then
  echo "Python 3 не найден. Установите Python 3 и повторите запуск."
  exit 1
fi
python3 tools/serve_web.py
