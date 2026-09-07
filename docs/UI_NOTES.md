# Presentación del juego

La ciudad usa exclusivamente mallas GLB creadas en Blender: edificios,
caminos, barcos, árboles y vecinos. Casas y pozos comparten geometría con
sus miniaturas. Hay tres variantes de vivienda sin diferencias de simulación.

La interfaz usa pergamino cálido, marcos finos en nogal, tinta sepia y
acentos de rojo de sello y latón envejecido, con iconos renderizados. La cabecera y el menú lateral permanente van pegados a los bordes;
la vista se expande con la ventana, sin bandas negras. El estandarte, los
ornamentos y los controles están en `assets/ui/chrome/` como SVG editables.
El tema genera los marcos en nueve secciones para conservar sus biseles al
redimensionar. Los estados activos se distinguen por el relleno rojo de sello y el texto crema.
Almendra da carácter medieval a títulos, navegación y nombres de edificios;
EB Garamond mantiene legibles las cifras y los párrafos. Ambas fuentes y sus
licencias OFL se incluyen localmente en `assets/fonts/` y en la exportación web.

La cabecera ocupa 98 px y el lateral derecho 356 px a 1366 × 768. El minimapa
navegable permanece visible sobre seis botones compactos de 36 px de alto,
con ilustración propia y texto en una línea. Construcción, selección, demolición,
ciudad, recursos y comercio comparten ese menú. Sus submenús ocupan la zona
restante del lateral y desplazan su contenido cuando hace falta; la cámara centra
la villa en el espacio de juego disponible. Costes, existencias y totales usan icono + cifra. Los nombres de
recursos, requisitos y detalles de cupos aparecen al pasar el cursor; las
acciones y las distinciones «Al salir» / «Al volver» siguen visibles.
Las fichas muestran también piedra y otros materiales de construcción,
incluida la previsualización sobre el terreno.

## Libros y documentos de la villa

Los paneles interiores comparten madera tallada, hojas de pergamino, sellos,
latón envejecido y cabeceras ilustradas. `folio.gd` reúne las cabeceras,
secciones, fichas y cifras; `folio_banner.gd` compone el arte sin incrustar texto.
La carta náutica original se generó con ImageGen para esta interfaz. El prompt
y la procedencia están en `assets/ui/chrome/ARTWORK.md`. Los iconos de las
mercancías que aún no tienen miniatura están en `assets/ui/resources/`.

- Construcción: seis gremios y fichas de edificios con costes ilustrados.
- Libro de cuentas: existencias, cadenas de producción y territorio.
- Casa de contratación: formulario con precio, flete y duración; las
  travesías tienen fichas de carga y barras de progreso.
- Consejo: resumen de la villa, hitos y avisos; el inspector conserva
  las miniaturas 3D existentes de edificios y vecinos.
- Carta de la ría interior, libro de ayuda, menú y confirmaciones usan el mismo tema.
  Los desplegables, las casillas y las ayudas emergentes también están vestidos.

Los submenús se sustituyen dentro del lateral y Escape los cierra y cancela la
herramienta, conservando el minimapa y la navegación. Elegir y colocar un edificio
mantiene abierto su catálogo para seguir construyendo. El resumen de pago y el
botón de enviar nave permanecen fuera del área desplazable; los accesos a la ría
completa y al asentamiento están junto al minimapa. Las confirmaciones bloquean la interacción con el mapa y pausan
la simulación. No se han generado imágenes de edificios: las fichas sin render
específico reutilizan temporalmente la miniatura de su gremio.

Galería reproducible de 16 estados, en `build/folio-*.png`:

```sh
.tools/Godot.app/Contents/MacOS/Godot --path . --script tools/review_ui.gd
```

Las pruebas de `tests/ui_runner.gd` cubren pestañas, construcción sin cerrar el
catálogo, travesías, ayuda y cancelación/confirmación de una nueva partida.
Comprueban además el minimapa permanente, la navegación sin actuar sobre el
terreno y los límites del lateral a 1280 × 720, 1366 × 768 y 1600 × 900.

Construir → categoría → edificio; Escape cancela la herramienta. El inspector
aparece en el propio lateral al seleccionar, y las etiquetas del mapa al pasar sobre un edificio.
Ciudad muestra los hitos; el minimapa queda siempre visible; Menú reúne
el guardado, la carga y la ayuda.

La cámara ortográfica, la luz neutra suave y los colores oliva y turquesa del
terreno acompañan a los materiales arena y gris beige, teja y madera de los modelos.
`docs/ART_DIRECTION.md` describe la dirección común, `art/README.md` permite
regenerar la colección y `docs/UI_ASSET_LIST.md` enumera los archivos.

## Verificación de la colección

- Regeneración completa desde los scripts con Blender 5.2.1 LTS.
- 23 GLB comprobados: geometría, presupuesto de triángulos, huellas,
  centrado, escala y articulaciones del vecino.
- 29 PNG comprobados: tamaño, contenido, alfa y margen sin recortes.
- 35 pruebas de simulación correctas.
- Exportación Web de Godot 4.7.2, cámara ortográfica y MSAA 4×.
- Capturas locales de revisión en `build/lowpoly-game.png` y
  `build/lowpoly-build.png`; colección en `art/renders/ui-collection.png`.
- Flujo comprobado en Chromium: colocar granja y dos viviendas, trazar diez
  casillas de camino, conectar edificios y avanzar a ×4. Dos vecinos trabajan
  y producen 16 unidades de cereal (32 → 48). Sin errores de consola.
  Evidencia local: `build/lowpoly-qa.json`.

## Fichas residenciales y lectura de menús

La vivienda tiene una ficha específica con la miniatura correspondiente a su
nivel, ocupación, conexión al almacén, progreso hacia el siguiente nivel y
necesidades pendientes calculadas con las reglas reales de la simulación.
Los servicios combinan texto, marcas y color: cubiertos, pendientes o futuros.
La lista de vecinos se actualiza al llegar o marcharse habitantes y permite
abrir sus fichas. Conservación e impuestos quedan al final, junto a las acciones.

Los recuadros interiores usan papel más claro y mayor separación. El catálogo
amplía las ilustraciones y conserva sus costes visibles. Comercio agrupa el
estado del mercader, los campos etiquetados y el presupuesto. El minimapa de
132 × 132 deja más espacio a las fichas sin desaparecer de la navegación.

Los caminos de tierra y pavimentados aparecen como tarjetas separadas en
Servicios, con miniaturas Blender y nombres completos. El minimapa distingue
sus acabados. Los trabajadores quedan ocultos mientras están dentro de su
edificio: un punto con cifra muestra presentes en verde o asignados fuera en
ámbar; el detalle aparece al pasar el ratón y en el inspector.
