# Presentación del juego

La ciudad usa exclusivamente mallas GLB creadas en Blender: edificios,
caminos, barcos, árboles y vecinos. Casas y pozos comparten geometría con
sus miniaturas. Hay tres variantes de vivienda sin diferencias de simulación.

La interfaz usa pergamino cálido, marcos finos en nogal, tinta sepia y
acentos de rojo de sello y latón envejecido, con iconos renderizados. La cabecera y la barra inferior van pegadas a los bordes;
la vista se expande con la ventana, sin bandas negras. El estandarte, los
ornamentos y los controles están en `assets/ui/chrome/` como SVG editables.
El tema genera los marcos en nueve secciones para conservar sus biseles al
redimensionar. Los estados activos se distinguen por el relleno rojo de sello y el texto crema.
Almendra da carácter medieval a títulos, navegación y nombres de edificios;
EB Garamond mantiene legibles las cifras y los párrafos. Ambas fuentes y sus
licencias OFL se incluyen localmente en `assets/fonts/` y en la exportación web.

La cabecera ocupa 98 px y la barra inferior 48 px a 1366 × 768. Los menús
principales miden 544 px de ancho y ajustan su altura al contenido o a la
pestaña. Costes, existencias y totales usan icono + cifra. Los nombres de
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

Los paneles principales se sustituyen al abrirse y Escape los cierra.
Los botones de enviar nave y de vista de toda la ría permanecen fuera del área
desplazable. Las confirmaciones bloquean la interacción con el mapa y pausan
la simulación. No se han generado imágenes de edificios: las fichas sin render
específico reutilizan temporalmente la miniatura de su gremio.

Galería reproducible de 15 estados, en `build/folio-*.png`:

```sh
.tools/Godot.app/Contents/MacOS/Godot --path . --script tools/review_ui.gd
```

Las pruebas de `tests/ui_runner.gd` cubren también pestañas, travesías,
ayuda y cancelación/confirmación de una nueva partida.

Construir → categoría → edificio; Escape cancela la herramienta. El inspector
aparece al seleccionar, y las etiquetas del mapa al pasar sobre un edificio.
Ciudad muestra los hitos; Mapa contiene el minimapa navegable; Menú reúne
el guardado, la carga y la ayuda.

La cámara ortográfica, la luz cálida suave y los colores oliva y turquesa del
terreno acompañan a los materiales crema, teja y madera de los modelos.
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
