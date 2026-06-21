#!/usr/bin/env bash
# Serve the static dashboard over local HTTP (it must NOT be opened via file://).
# Usage: scripts/serve_dashboard.sh [port]   (default 8080)
set -euo pipefail
PORT="${1:-8080}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)/dashboard"
echo "Serving ${ROOT} at http://localhost:${PORT}/  (Ctrl+C to stop)"
cd "$ROOT"
exec python3 -m http.server "$PORT"
