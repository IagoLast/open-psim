# Presentación del juego

La ciudad usa exclusivamente mallas GLB creadas en Blender: edificios,
caminos, barcos, árboles y vecinos. Casas y pozos comparten geometría con
sus miniaturas. Hay tres variantes de vivienda sin diferencias de simulación.

La interfaz conserva pergamino claro, tinta marrón e iconos renderizados.
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
