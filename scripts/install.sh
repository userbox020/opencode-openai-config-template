#!/usr/bin/env bash
set -euo pipefail

PROJECT_PATH="${1:-$PWD}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE_DIR="$REPO_ROOT/template/.opencode"
DEST_DIR="$PROJECT_PATH/.opencode"

if [[ ! -d "$PROJECT_PATH" ]]; then
  echo "Project path does not exist or is not a directory: $PROJECT_PATH" >&2
  exit 1
fi

if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "Template source not found: $SOURCE_DIR" >&2
  exit 1
fi

if [[ -e "$DEST_DIR" && "${FORCE:-0}" != "1" ]]; then
  echo "Target already has .opencode. Re-run with FORCE=1 to merge and overwrite matching template files." >&2
  exit 1
fi

mkdir -p "$DEST_DIR"
cp -R "$SOURCE_DIR"/. "$DEST_DIR"/

echo "Installed generic OpenCode config to $DEST_DIR"
echo "Restart OpenCode in the target project so it loads the new config."
