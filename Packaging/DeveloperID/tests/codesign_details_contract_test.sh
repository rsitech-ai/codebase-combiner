#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
CHECKS="$ROOT_DIR/Packaging/DeveloperID/codesign_details.sh"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/codebase-combiner-codesign-details.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

if [[ ! -f "$CHECKS" ]]; then
  echo "Code-signing detail checks are missing: $CHECKS" >&2
  exit 1
fi
source "$CHECKS"

cat > "$TMP_DIR/current.txt" <<'DETAILS'
Executable=/Applications/Codebase Combiner.app/Contents/MacOS/CodebaseExplorerApp
CodeDirectory v=20500 size=4521 flags=0x10000(runtime) hashes=130+7 location=embedded
Runtime Version=26.5.0
DETAILS

cat > "$TMP_DIR/legacy.txt" <<'DETAILS'
Executable=/Applications/Codebase Combiner.app/Contents/MacOS/CodebaseExplorerApp
flags=0x10000(runtime)
DETAILS

cat > "$TMP_DIR/no-runtime-flag.txt" <<'DETAILS'
CodeDirectory v=20500 size=4521 flags=0x0(none) hashes=130+7 location=embedded
Runtime Version=26.5.0
DETAILS

cat > "$TMP_DIR/misleading-runtime.txt" <<'DETAILS'
CodeDirectory v=20500 size=4521 flags=0x0(none) hashes=130+7 location=embedded
Path=/tmp/runtime/Codebase Combiner.app
DETAILS

codesign_details_has_hardened_runtime "$TMP_DIR/current.txt"
codesign_details_has_hardened_runtime "$TMP_DIR/legacy.txt"

if codesign_details_has_hardened_runtime "$TMP_DIR/no-runtime-flag.txt"; then
  echo "Runtime version metadata was mistaken for the hardened-runtime signing flag." >&2
  exit 1
fi

if codesign_details_has_hardened_runtime "$TMP_DIR/misleading-runtime.txt"; then
  echo "An unrelated runtime path was mistaken for the hardened-runtime signing flag." >&2
  exit 1
fi

echo "Code-signing details contract passed"
