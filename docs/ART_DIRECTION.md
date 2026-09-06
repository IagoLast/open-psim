# Dirección artística — Pontevedra

Guía de diseño: [`design-style.json`](design-style.json), prompt completo del
usuario, con identificador `pontevedra_low_poly_v1` y ejemplo de granja de maíz.
`common.py` lee su paleta principal y sus ángulos de cámara directamente.
Referencias: `references/asset-style-reference.png`, `references/houses-reference.png`
y `references/wells-reference.png`.
La ciudad y sus miniaturas forman una misma colección de maquetas low poly.

## Forma y materiales

Piezas geométricas compactas, caras planas y pequeños biseles. Siluetas claras
antes que microdetalle. Muros crema con hastiales de piedra, ventanas oscuras,
puertas de tablones y chimeneas abiertas. Ventanas alineadas por planta entre
fachadas, apoyadas en el muro y por debajo del alero; no se colocan ventanas
adicionales en los hastiales de las viviendas. Cubiertas inclinadas de terracota
con grosor, tejas amplias solapadas y cumbrera segmentada; pizarra en el almacén portuario.
El pozo tiene brocal grueso y hueco, agua visible, postes y cubo colgante.

Tres troncos octogonales con cortes claros, mazorca dorada con dos hojas, sardina de
perfil azul, sal facetada y monedas gruesas. Vegetación en una copa facetada.
Los vecinos usan una figura sencilla con túnica y miembros articulados.

La paleta única de `art/blender/common.py` define piedra crema, madera cálida,
terracota, oro, oliva y agua turquesa. Materiales mates sin texturas fotográficas.
Las bases son discretas, de tierra, hierba, piedra o agua según función.

## Cámara y luz

La cámara Blender es ortográfica, a 45° de giro horizontal y 35° de elevación,
con frontal, lateral derecho y cubierta visibles. Luz principal suave superior
izquierda y relleno neutro. La misma escena de render sirve a toda la colección.
PNG de ejecución con transparencia, sombra de contacto y margen para componer
sobre la interfaz. Los renders de diseño `art/renders/*-design.png` y las láminas
usan el fondo crema sólido `#F3E5C5` del prompt. Cada modelo ocupa aproximadamente
el 74 % del encuadre. El captor de sombras y el compositor no se exportan al juego.

En Godot se conservan las proporciones al ajustar la huella de los edificios.
El terreno usa verdes oliva y agua turquesa. La luz y las sombras suaves dan
relieve a las mallas sin oscurecer la piedra ni saturar los tejados. Un relleno
cálido ilumina la fachada opuesta en el renderizador GL Compatibility.

## Alcance

Inspiración medieval gallega y portuaria; la simulación empieza hacia 1530.
Las variantes de casa son visuales y comparten capacidades y costes. Los
barcos y árboles son decoración. Los recursos no añaden nuevas mercancías.
La arquitectura es estilizada, sin atribuir reconstrucción histórica exacta.

Las tres viviendas se distinguen por su silueta: casa pequeña, porche de madera
y casa de dos plantas con balcón. El campo combina hileras de maíz, cerca y
caseta de piedra; el identificador de simulación del cereal sigue siendo `grain`.
La pesquería se reconoce por muelle, red y barca; la salazón por secadero y mesa
de sal. Las categorías reutilizan geometría de casas, pozo, maíz y madera.

Los `.blend` son las fuentes editables; GLB y PNG se regeneran con
`tools/render_assets.sh`. No hay versiones provisionales de modelos ni iconos.
