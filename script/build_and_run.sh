#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="CodebaseExplorerApp"
APP_BUNDLE="$ROOT_DIR/dist/app-store/Codebase Combiner.app"

cd "$ROOT_DIR"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

Packaging/AppStore/build_app_store_package.sh --skip-signing >/tmp/codebase-combiner-build.log

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --verify|verify)
    open_app
    for _ in {1..20}; do
      if pgrep -x "$APP_NAME" >/dev/null; then
        echo "Verified $APP_NAME launched from $APP_BUNDLE"
        exit 0
      fi
      sleep 0.25
    done
    echo "App did not launch. Build log: /tmp/codebase-combiner-build.log" >&2
    exit 1
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  *)
    echo "usage: $0 [run|--verify|--logs]" >&2
    exit 2
    ;;
esac
