# Pontevedra · OPEN-PSIM

Simulación de una villa portuaria hacia 1530, construida en Godot. Combina
producción, abastecimiento y servicios urbanos con comercio marítimo.

La primera versión está conservada en el commit `dc5834d`. Esta ampliación incluye:

- **Ría interior de 128×128**: las 16.384 casillas se concentran en el tramo
  Pontevedra–Combarro–Marín. Dos orillas amplias para construir, el Lérez y
  la isla de Tambo; Poio, Campelo, Lourido y Lourizán sirven de referencia.
  Bosques, tierras fértiles, granito, arcilla y hierro abastecen la villa.
  El paso del Burgo permite extender caminos a la orilla de Combarro.
- **16 recursos y 25 tipos de edificios**: cereal → harina → pan;
  sardina + sal → salazón; uva → vino; arcilla + madera → cerámica;
  hierro + madera → herramientas; lana → paños.
- **Comercio con Porto, Lisboa y Burdeos**: un barco por muelle, viajes de
  2–4 días, fletes, precios y cupos por puerto. Las importaciones reservan
  espacio; las exportaciones cobran al volver. Rutas automáticas opcionales.
- **Servicios públicos**: agua, mercado, salud, culto, seguridad y educación.
  Cobertura por caminos, empleos y mantenimiento diario. Las viviendas
  evolucionan con los servicios y consumen bienes para alcanzar el nivel mercantil.
- **Edificios nuevos como bloques con etiquetas**. Se conservan los modelos
  originales de viviendas, granjas, pesca y salazón.

El mapa es una interpretación jugable de la ría interior, con contornos y escala
simplificados; los yacimientos, precios y plazos son de diseño. Referencia geográfica:
[ría de Pontevedra, Turismo Rías Baixas](https://www.turismoriasbaixas.com/es/search/ria-de-pontevedra).

```sh
.tools/Godot.app/Contents/MacOS/Godot --path .
```

También puede abrirse `project.godot` desde Godot 4.7.2. Se empieza en pausa:
construye una granja sobre el terreno fértil al norte del asentamiento y
conecta su borde al camino. Añade leñadores y pesca; después construye un
muelle para importar sal y exportar salazón. Nuevas viviendas con agua,
empleos libres y una reserva de dos días de comida atraen vecinos.

**Construir** abre el catálogo; **Recursos** muestra existencias y cadenas;
**Comercio** configura y sigue los barcos; **Ciudad** muestra los objetivos.
**Mapa** permite recorrer las dos orillas e **Inicio** vuelve al almacén.
WASD/flechas desplazan la cámara, la rueda controla el zoom, Espacio pausa
y clic derecho/Escape cancela la herramienta. Arrastra para trazar caminos.

Los edificios con trabajadores necesitan conexión con el almacén. Los servicios
con coste cierran si falta presupuesto. Una casa alcanza el nivel próspero tras
3 días con comida, agua, mercado, salud y culto; seguridad, educación y una unidad
diaria de cerámica, paños y vino permiten el nivel mercantil. Los niveles mayores
pagan más impuestos. En el mar, una carga espera si el muelle pierde su camino;
reconectarlo permite descargar. Detener una ruta automática conserva el viaje en curso.

Los guardados de este mapa usan `user://pontevedra-ria-v1.json`. Los archivos
anteriores de la provincia se conservan por separado; el cambio de geografía
requiere una nueva partida. Guardan también cargas, cupos y rutas en curso.
Bosques, yacimientos y caladeros no se agotan; el reparto terrestre se centraliza
en el almacén. La prioridad de empleo afecta a nuevas asignaciones.

Exportación web local:

```sh
mkdir -p build/web
.tools/Godot.app/Contents/MacOS/Godot --headless --path . --export-release Web build/web/index.html
```

Validación de simulación, interacción de la escena y recursos visuales:

```sh
.tools/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/test_runner.gd
.tools/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/ui_runner.gd
.tools/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/check_models.gd
.tools/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/check_ui_assets.gd
.tools/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/run_simulation.gd -- --ticks 10000
```

[Modelos originales](art/README.md) · [Dirección artística](docs/ART_DIRECTION.md) ·
[Controlar Blender mediante MCP](docs/BLENDER_MCP.md)
