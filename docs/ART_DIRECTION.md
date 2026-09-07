# Dirección artística — Pontevedra

Guía de diseño: [`design-style.json`](design-style.json), prompt completo del
usuario, con identificador `pontevedra_low_poly_v1` y ejemplo de granja de maíz.
`common.py` lee su paleta principal y sus ángulos de cámara directamente.
Referencias: `references/asset-style-reference.png`, `references/houses-reference.png`,
`references/wells-reference.png` y la [foto de Pontevedra aportada por el usuario](references/pontevedra-stone-reference.png)
para el color de la piedra y su envejecimiento.
La ciudad y sus miniaturas forman una misma colección de maquetas low poly.

## Forma y materiales

Piezas geométricas compactas, caras planas y pequeños biseles. Siluetas claras
antes que microdetalle. Muros y hastiales de granito cálido arena y gris beige, ventanas oscuras,
puertas de tablones y chimeneas abiertas. Ventanas alineadas por planta entre
fachadas, apoyadas en el muro y por debajo del alero; no se colocan ventanas
adicionales en los hastiales de las viviendas. Cubiertas inclinadas de terracota
con grosor, tejas amplias solapadas y cumbrera segmentada; pizarra en el almacén portuario.
El pozo tiene brocal grueso y hueco, agua visible, postes y cubo colgante.

Tres troncos octogonales con cortes claros, mazorca dorada con dos hojas, sardina de
perfil azul, sal facetada y monedas gruesas. Robles con copas lobuladas y ramas
visibles, pinos de copa abierta y cipreses de silueta estrecha. Los bosques mezclan
alturas y orientaciones con sotobosque de tojo, hierba y flores discretas.
Los vecinos usan una figura sencilla con túnica y miembros articulados.

La paleta única de `art/blender/common.py` define granito arena y gris beige, madera cálida,
terracota, oro, oliva y agua turquesa. Materiales mates sin texturas fotográficas.
Las bases son discretas, de tierra, hierba, piedra o agua según función.
Los caminos tienen losas de gris beige con juntas oscuras y pequeñas zonas de musgo;
los zócalos y las primeras hiladas son más oscuros para sugerir humedad.
La piedra conserva la calidez de la referencia, con menos luminosidad que la paleta
crema inicial. La humedad oscurece zonas concretas, sin teñir de verde toda la piedra.
Crema se reserva para lino, otros accesorios claros y el pergamino de la interfaz.
La [revisión de materiales en juego](../art/renders/granite-street.png) se
regenera con `Godot --path . --script tools/review_materials.gd`: captura la
calle, la villa y el puente con los materiales importados y la iluminación real.

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
relieve a las mallas y mantienen la terracota legible. La luz principal, el relleno
y el ambiente son neutros y de intensidad contenida para conservar la calidez del
granito sin blanquearlo en GL Compatibility. La humedad se expresa con tonos más oscuros y
musgo localizado, sin convertir las superficies en plástico brillante.

El paisaje tiene praderas con transiciones suaves entre suelos, granito cálido con
musgo y riberas con taludes, piedras y juncos. El puente del Burgo usa cuatro arcos
de dovelas, tajamares y pretiles de granito; el tablero sigue al nivel de
los caminos. La brisa de la vegetación y las ondas del agua son lentas y sutiles.
Las plantas pequeñas desaparecen al alejar la cámara para conservar la lectura
del territorio. El relieve costero es visual: las casillas edificables permanecen
planas y conservan sus reglas.

## Alcance

Inspiración medieval gallega y portuaria; la simulación empieza hacia 1530.
Las variantes de casa son visuales y comparten capacidades y costes. Los
barcos y árboles son decoración. Los recursos no añaden nuevas mercancías.
La arquitectura es estilizada, sin atribuir reconstrucción histórica exacta.

El convento toma como referencias las fotografías aportadas de
[`San Francisco`](references/san-francisco-convent.png) y su
[`fachada`](references/san-francisco-facade.png). Conserva el ala larga de tres
plantas, la iglesia de hastial de granito, el rosetón con tracería radial, la
portada de arcos concéntricos y el campanario lateral con remate de piedra.
El patio es una simplificación del conjunto para la parcela monumental 10×8. Se omiten los
elementos urbanos contemporáneos y se mantiene la paleta de la colección.

Los servicios se distinguen por volumen y espacios abiertos: el mercado es una
plaza de toldos de lona; el hospital forma una U baja con patio medicinal y
cubiertas de pizarra; la capilla tiene nave estrecha y ábside poligonal; la guardia
ocupa una torre octogonal almenada. La escuela es un aula longitudinal de una
planta, con ventanas altas y una única cubierta de teja a dos aguas; los vigías
usan una torre de madera arriostrada con cisterna; los maestros
de obras tienen un patio abierto con arco en construcción y andamios. La
hospedería tiene dos plantas de habitaciones, chimenea y un balcón pequeño sobre
ménsulas de granito, al que se accede por una puerta en la planta superior.
Escuela y hospedería evitan marquesinas, toldos, torrecillas y escaleras exteriores
sin destino. Los elementos de identificación se fijan a los muros. Los detalles
de actividad refuerzan estas siluetas sin depender de etiquetas o colores.

Las tres viviendas canónicas se amplían con nueve siluetas, tres por nivel:
casas bajas con porche o anexo, dos plantas con patín o balcón y casas mercantiles
con galerías o soportales. La [nueva referencia de casas](references/house-variants-reference.png) guía sus proporciones
compactas, cubiertas de terracota y pequeños arbustos. Cada casa mantiene su
parcela 2×2 y su nivel de juego. El campo combina hileras de maíz, cerca y
caseta de piedra; el identificador de simulación del cereal sigue siendo `grain`.
La pesquería se reconoce por muelle, red y barca; la salazón por secadero y mesa
de sal. Las categorías reutilizan geometría de casas, pozo, maíz y madera.

Los `.blend` son las fuentes editables; GLB y PNG se regeneran con
`tools/render_assets.sh`. No hay versiones provisionales de modelos ni iconos.
