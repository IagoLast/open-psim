#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ -z "${BLENDER_BIN:-}" ]]; then
  if command -v blender >/dev/null 2>&1; then
    BLENDER_BIN="$(command -v blender)"
  elif [[ -x /Applications/Blender.app/Contents/MacOS/Blender ]]; then
    BLENDER_BIN=/Applications/Blender.app/Contents/MacOS/Blender
  else
    echo "Blender no encontrado. Define BLENDER_BIN con la ruta del ejecutable." >&2
    exit 1
  fi
fi
for group in buildings environment resources categories; do
  "$BLENDER_BIN" --background --threads 4 --python-exit-code 1 --python "art/blender/$group.py"
done
python3 tools/build_asset_sheet.py
