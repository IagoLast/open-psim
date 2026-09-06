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
- `blender/landscape.py`: puente de granito con cuatro arcos, pino de copa abierta,
  rocas con musgo, hierba, flores de pradera, juncos y tojo.
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

El paisaje combina esta colección con terreno generado en Godot. Los bosques
mezclan robles, pinos y cipreses con escala y orientación deterministas; los
materiales de las mallas se convierten en colores de vértice para dibujar cada
grupo de 16×16 casillas con una sola superficie. La brisa usa un shader compartido.
La vegetación se retira de las obras y caminos y reaparece al demoler. En la vista
general se ocultan las plantas pequeñas. Las orillas tienen talud y el agua usa
distancia a costa, ondas y espuma suaves, sin texturas externas.

El puente mantiene su pavimento al nivel de circulación y baja los apoyos hasta
−1,55; el agua está a −1,12. Los barcos usan esa misma cota. La topología y las
reglas de la simulación no cambian.

Comprobación del paisaje y capturas con el renderizador real:

```sh
.tools/Godot.app/Contents/MacOS/Godot --path . --script tests/landscape_runner.gd
.tools/Godot.app/Contents/MacOS/Godot --path . --script tools/review_landscape.gd
```

La prueba de paisaje necesita el renderizador real para leer las instancias
MultiMesh; se ejecuta sin `--headless`. Las cinco vistas de revisión quedan en
`build/landscape-*-after.png`. Ejemplos: [villa](renders/landscape-village.png) y
[puente](renders/landscape-bridge.png).

## Variaciones programables

[`variants.json`](variants.json) define la semilla de autoría, el número de
variantes y amplitudes pequeñas por familia. El catálogo entregado añade **dos
variantes** a cada roble, ciprés, pino, grupo de rocas, tojo y puente: 12 modelos
nuevos, 42 GLB y 48 miniaturas en total. Los nombres canónicos siguen presentes.
Comparación: [`renders/model-variants.png`](renders/model-variants.png).

```sh
# Regenerar el catálogo configurado: .blend editable + GLB + PNG de 512 px.
/Applications/Blender.app/Contents/MacOS/Blender --background --threads 4 --python-exit-code 1 --python art/blender/variants.py

# Experimentar con N variantes por semilla sin sustituir el catálogo del juego.
/Applications/Blender.app/Contents/MacOS/Blender --background --threads 4 --python-exit-code 1 --python art/blender/variants.py -- --seed 2048 --count 3 --assets tree_oak rock_cluster --output-root build/variant-preview

# Repetibilidad y contratos geométricos, sin renderizar ni escribir modelos.
/Applications/Blender.app/Contents/MacOS/Blender --background --threads 4 --python-exit-code 1 --python art/blender/variants.py -- --check
python3 tools/build_variant_sheet.py
```

`--config ruta.json` usa otra configuración. `--count` acepta 1–8 variantes
adicionales por familia; `--seed` es un entero, independiente de la semilla de
partida. `--assets` limita la regeneración. Sin `--output-root`, se escriben los
recursos del juego y `data/model_variants.json`. La orden completa de
`tools/render_assets.sh` también regenera y comprueba las variantes.

API Blender: `variants.build("tree_oak", "1530:1", parametros)` crea una escena
limpia con piezas separadas. También puede llamarse directamente a
`tree_oak(Variation(semilla, parametros))`; sin argumentos conserva el canónico.
Los canales aleatorios tienen nombre: añadir un detalle no desplaza el azar de
otro. El `.blend` contiene `scene["variant_recipe"]`; el manifiesto registra la
receta y una firma de geometría evaluada/materiales. Se compara esa firma, no
los bytes del `.blend` o GLB, cuyos metadatos pueden cambiar.

| Parámetro | Efecto y límite |
|---|---|
| `height` | Altura del esqueleto, ±12 % máximo |
| `lean` | Inclinación del tronco, ±0,15 m máximo |
| `trunk` | Grosor del tronco y las ramas, ±20 % máximo |
| `spread` | Desplazamiento local de lóbulos/piedras, ±0,15 m máximo |
| `crown` | Radio de cada lóbulo, ±20 % máximo |
| `facets` | Irregularidad radial de caras, ±0,06 máximo |
| `rock` | Proporciones de cada piedra, ±20 % máximo |
| `stone`, `moss` | Fracción de caras con otro acabado compartido, hasta 0,65/0,40 |

Se rechazan parámetros desconocidos, familias incompatibles y amplitudes fuera
de rango antes de generar. El puente admite solo `stone` y `moss`: todos sus
vértices, arcos, longitud, huella y pavimento permanecen idénticos al canónico.
La piedra usa la paleta compartida arena/gris beige de `common.py`, siguiendo la
foto de Pontevedra en `docs/references/pontevedra-stone-reference.png`; el musgo
aporta verde solo en zonas concretas.

Las viviendas mantienen `house`, `house_cottage` y `house_tall` y la selección de
silueta existente por identidad. `house_details` configura una extensión optativa
que cambia solo caras de acabado ya existentes, sin tocar huecos, cubierta ni
base. Para generarla, usar `--assets house house_cottage house_tall`; no se
generan variantes de vivienda por defecto. Cualquier detalle futuro debe pasar
la misma comprobación de geometría/huella.

En Godot, `ModelLibrary.create_variant(familia, semilla_partida, identidad)` y
`ModelVariants.choose(...)` seleccionan recursos compartidos del catálogo. Las
decoraciones usan la casilla como identidad y el puente `burgo-bridge`; el detalle
de vivienda usa su posición. La selección v1 usa FNV-1a de 32 bits y un ranking
por candidato, independiente del orden de iteración y del RNG de simulación.
Cada casilla tiene además su RNG visual local para especie, giro, escala y tono.
Los MultiMesh siguen agrupados por modelo y zona de 16×16, con una sola superficie
y tres materiales de brisa compartidos para todo el paisaje (rocas sin brisa).
No se crean mallas ni materiales por ejemplar, ni se usa Blender al ejecutar.
El catálogo actual usa 18 mallas compartidas de decoración y añade unos 1,5 MB
de GLB de autoría. Aumentar N añade lotes por variante visible en cada zona;
`tools/review_landscape.gd` imprime los draw calls para revisar ese coste.

Las partidas existentes necesitan **cero migraciones**: ya guardan semilla,
posición e identidad. Construir oculta instancias y demoler recupera exactamente
las mismas; cargar otra semilla reconstruye su paisaje. La estabilidad se
garantiza para el mismo catálogo/recetas y versión de selección. Cambiar recetas
o miembros activos es una actualización artística deliberada: puede cambiar el
aspecto de partidas antiguas. Para experimentar sin ese efecto, usar
`--output-root`. El generador conserva en el inventario los recursos de
generaciones anteriores, aunque dejen de estar activos, sin borrar archivos.

`tools/check_models.gd` y `tools/check_ui_assets.gd` leen el manifiesto generado,
comprueban todos los recursos y rechazan archivos sin inventariar. La prueba de
paisaje verifica las instancias reales después de construir, demoler, guardar,
cargar y cambiar de semilla. Las cinco capturas se obtienen con el comando de
revisión anterior. Tras validarlo todo, exportar con:

```sh
.tools/Godot.app/Contents/MacOS/Godot --headless --path . --export-release Web build/web/index.html
```
