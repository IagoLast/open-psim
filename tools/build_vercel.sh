#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Keep the editor and export templates on the same release.
GODOT_VERSION=4.7.2
GODOT_ARCHIVE="Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip"
GODOT_SHA256=cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4
mkdir -p .tools
curl --fail --location --retry 3 \
  "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/$GODOT_ARCHIVE" \
  --output ".tools/$GODOT_ARCHIVE"
echo "$GODOT_SHA256  .tools/$GODOT_ARCHIVE" | sha256sum --check
unzip -o ".tools/$GODOT_ARCHIVE" -d .tools
export GODOT_BIN="$PWD/.tools/Godot_v${GODOT_VERSION}-stable_linux.x86_64"
chmod +x "$GODOT_BIN"
python3 tools/install_web_templates.py "$GODOT_VERSION"
bash build.sh

# Publish the game at /play/ and send the domain homepage there.
mkdir -p build/site/play
cp -R build/web/. build/site/play/
cat > build/site/index.html <<'HTML'
<!doctype html>
<html lang="es">
<meta charset="utf-8">
<meta http-equiv="refresh" content="0;url=./play/">
<title>Pontevedra · OPEN-PSIM</title>
<a href="./play/">Jugar a Pontevedra · OPEN-PSIM</a>
</html>
HTML
