# Pontevedra · OPEN-PSIM

Simulación de una villa portuaria pontevedresa hacia 1530, construida en Godot.
Arte low poly original creado en Blender: piedra crema, teja terracota,
madera cálida, agua turquesa y vegetación facetada.

```sh
.tools/Godot.app/Contents/MacOS/Godot --path .
```

También puede abrirse `project.godot` desde Godot 4.7.2 o exportarse a web:

```sh
.tools/Godot.app/Contents/MacOS/Godot --headless --path . --export-release Web build/web/index.html
```

[Ver la colección visual](art/renders/ui-collection.png) ·
[Regenerar los modelos con Blender](art/README.md) ·
[Controlar Blender mediante MCP](docs/BLENDER_MCP.md) ·
[Dirección artística](docs/ART_DIRECTION.md)

Validación:

```sh
.tools/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/test_runner.gd
.tools/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/check_models.gd
.tools/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/check_ui_assets.gd
```
