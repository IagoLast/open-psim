# Colección Blender de Pontevedra

Fuentes de estilo: las tres láminas en `docs/references/` y el prompt
[`docs/design-style.json`](../docs/design-style.json). La paleta principal y los
ángulos de cámara se leen de ese JSON en cada regeneración.
Todas las mallas se construyen en Blender; las miniaturas se renderizan desde
la misma geometría. No hay modelos alternativos ni iconos vectoriales de reserva.

- `blender/common.py`: paleta sRGB, geometría plana, cámara ortográfica,
  iluminación neutra suave, sombras transparentes y exportación.
- `blender/buildings.py`: casa pequeña, porche, balcón, pozo, camino, campo de maíz,
  leñadores, pesquería y salazón.
- `blender/environment.py`: almacén, dos barcos, dos árboles y vecino animable.
- `blender/resources.py`: ocho recursos e indicadores.
- `blender/categories.py`: cuatro categorías y dos herramientas. Vivienda y
  servicios reutilizan los modelos de casa y pozo.
- `blender/*.blend`: fuentes editables con piezas separadas, cámara y luces.
- `../assets/models/*.glb`: exportaciones del juego. Las piezas estáticas se
  unen en una malla con varios materiales; el vecino conserva cuatro articulaciones.
- `../assets/ui/*.png`: renders RGBA, 256 px para iconos y 512 px para modelos.
- `renders/ui-collection.png`: lámina completa de revisión.
- `renders/architecture-review.png`: seis edificios ampliados sobre el fondo del prompt.
- `renders/*-design.png`: modelos aislados sobre crema sólido, listos para revisar.
- `renders/readability-64.png`: siluetas a 64 × 64 píxeles.
- `renders/in-game-review.png`: captura de comprobación de los GLB importados en Godot.

## Regenerar

Requiere Blender (verificado con 5.2.1 LTS) y Pillow para la lámina.

```sh
bash tools/render_assets.sh
.tools/Godot.app/Contents/MacOS/Godot --headless --path . --editor --import
.tools/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/check_models.gd
.tools/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/check_ui_assets.gd
```

Puede configurarse `BLENDER_BIN`. Para regenerar sólo un modelo:

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --python art/blender/buildings.py -- house well
```

Las fuentes usan Z arriba y frontal hacia −Y; GLB convierte a Y arriba.
La escala de edificios se ajusta uniformemente a su huella para conservar
pendientes y proporciones. Árboles, barcos y vecinos conservan su escala natural.
Los caminos son baldosas cuadradas. Las animaciones del vecino giran los nodos
`LegL`, `LegR`, `ArmL` y `ArmR` alrededor de caderas y hombros.
Blender y Pillow no son dependencias de ejecución del juego.
