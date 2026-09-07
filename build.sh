#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

if [[ -n "${GODOT_BIN:-}" ]]; then
  GODOT="$GODOT_BIN"
elif [[ -x "$PROJECT_DIR/.tools/Godot.app/Contents/MacOS/Godot" ]]; then
  GODOT="$PROJECT_DIR/.tools/Godot.app/Contents/MacOS/Godot"
elif command -v godot >/dev/null 2>&1; then
  GODOT="$(command -v godot)"
elif command -v godot4 >/dev/null 2>&1; then
  GODOT="$(command -v godot4)"
else
  echo 'No se encuentra Godot. Instálalo o indica su ejecutable con GODOT_BIN.' >&2
  exit 1
fi

mkdir -p build/web
echo 'Importando recursos…'
"$GODOT" --headless --path "$PROJECT_DIR" --editor --import
echo 'Exportando web…'
"$GODOT" --headless --path "$PROJECT_DIR" --export-release Web build/web/index.html

for asset in index.html index.js index.wasm index.pck; do
  if [[ ! -s "build/web/$asset" ]]; then
    echo "La exportación no ha generado build/web/$asset." >&2
    exit 1
  fi
done

echo "Web generada en $PROJECT_DIR/build/web"
echo 'Sube todo su contenido a la carpeta pública play/ de tu hosting.'
