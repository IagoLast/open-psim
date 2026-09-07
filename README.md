# Pontevedra · OPEN-PSIM

Simulación de una villa portuaria hacia 1530, construida en Godot. Combina
producción, abastecimiento y servicios urbanos con comercio marítimo.

La primera versión está conservada en el commit `dc5834d`. Esta ampliación incluye:

- **Ría interior de 512×512**: las 262.144 casillas se concentran en el tramo
  Pontevedra–Combarro–Marín. Dos orillas amplias para construir, el Lérez y
  la isla de Tambo; Poio, Campelo, Lourido y Lourizán sirven de referencia.
  Bosques, tierras fértiles, granito, arcilla y hierro abastecen la villa.
  El paso del Burgo permite extender caminos a la orilla de Combarro.
- **16 recursos y 31 tipos de edificios**: cereal → harina → pan;
  pesquería + salinas → salazón; uva → vino; arcilla + madera → cerámica;
  hierro + madera → herramientas; lana → paños.
- **Comercio con Porto, Lisboa y Burdeos**: un barco por muelle, viajes de
  2–4 días, fletes, precios y cupos por puerto. Las importaciones reservan
  espacio; las exportaciones cobran al volver. Rutas automáticas opcionales.
- **Servicios públicos**: agua, mercado, salud, culto, seguridad y educación.
  Cobertura por caminos, empleos y mantenimiento diario. Las viviendas
  evolucionan con los servicios y consumen bienes para alcanzar el nivel mercantil.
- **Catálogo completo con modelos Blender e iconos propios**: los 22 edificios
  pendientes ya tienen geometría de producción, servicios y puerto.

El mapa es una interpretación jugable de la ría interior, con contornos y escala
simplificados; los yacimientos, precios y plazos son de diseño. Referencia geográfica:
[ría de Pontevedra, Turismo Rías Baixas](https://www.turismoriasbaixas.com/es/search/ria-de-pontevedra).

```sh
.tools/Godot.app/Contents/MacOS/Godot --path .
```

También puede abrirse `project.godot` desde Godot 4.7.2. El menú principal permite
elegir **Nueva villa**, **Villa en desarrollo** (24 vecinos, 30 edificios),
**Ciudad avanzada** (48 vecinos, 55 edificios) o **Cargar guardado**.
Las ciudades preparadas incluyen caminos, empleos, agua, reservas y viviendas
evolucionadas; la avanzada contiene todos los tipos de edificio. Todas se abren
en pausa: pulsa Espacio para avanzar. **Menú** o Escape con la herramienta de
selección permite volver al menú, guardar o cambiar de ciudad; sustituir una
partida iniciada requiere confirmar dentro del juego.

Nueva villa empieza sin edificios ni habitantes, junto al camino principal que
atraviesa el mapa por el puente del Burgo. La nueva escala duplica el ancho y el alto respecto al mapa de 256×256,
conserva el tamaño de los edificios y multiplica por cuatro la superficie de la ría.

Construye un **almacén** junto al camino y añade **viviendas, un pozo y empleos**.
La tierra fértil está al norte del área inicial; el bosque, al sudeste. Conecta
las explotaciones al camino. Los vecinos llegan desde el extremo del camino más cercano a su vivienda cuando hay
vivienda con agua, puestos libres y reserva de comida. La ayuda inicial permite
montar granja, leñadores, pesca y salazón; el almacén no necesita trabajadores.

**Construir** abre el catálogo. **R** gira las parcelas rectangulares; la vista
previa representa su ocupación real. Las viviendas conservan una parcela 2×2 y
crecen de humilde a próspera y mercantil, con modelos y capacidades de 4, 6 y 8
vecinos. Orientan la fachada al camino y detectan casas contiguas; el catálogo
admite modelos específicos para medianeras. Hay nueve variantes Blender adicionales, tres por nivel: porches, anexos,
escaleras, balcones, galerías y soportales. Se eligen de forma estable por casa.
Las piezas específicas para medianeras quedan pendientes. [Ver las casas](art/renders/house-variants.png).

**Comercio**, o **Comprar / vender** en la ficha del almacén, permite negociar
con mercaderes sin construir un muelle. Si aún no hay almacén, el botón
**Construir almacén** activa directamente su colocación; también está en
**Construir → Puerto**. Sus barcos llegan periódicamente: un día
de aproximación, dos en puerto y uno de regreso. Cada visita repone existencias
y demanda limitadas. Durante el atraque, la compra o venta entrega recursos y
cobra inmediatamente. Algunas mercancías solo se pueden vender. Las **rutas
propias del muelle** conservan viajes de 2–4 días y repetición automática.

**Ciudad** muestra el encargo y sus etapas: fundación, estabilidad, prosperidad
y villa portuaria. La victoria exige mantener población, empleo, alimentos,
viviendas prósperas y saldo operativo, además de exportar. Se puede continuar
jugando después de cumplirlo. Hay una ayuda de emergencia única cuando quedan
100 monedas o menos.

Las necesidades residenciales deben mantenerse tres días para mejorar; dos días
de carencia reducen un nivel. El paro y la falta de suministros prolongados
provocan emigración. Los **vigías del fuego**, con agua y personal, previenen y
extinguen incendios; los **maestros de obras** conservan edificios usando madera.
El riesgo y las grietas se anuncian antes de los daños. Las ruinas conservan su
parcela y se reparan desde el inspector por 20 monedas y cuatro de madera.

La **hospedería** admite peregrinos que recorren el camino, descansan y salen del
mapa. Consumen alimentos solo por encima de la reserva de tres días para los
residentes; la atención aporta ingresos y reputación. Sus camas y visitantes
están separados de las viviendas y los trabajadores.

**Hórreo**, en **Construir → Alimentos**, cuesta 45 monedas, 12 de madera y
6 de piedra, y ocupa 1×1 casillas. Conectado al almacén, añade 400 plazas
exclusivas para cereal (incluido el maíz), harina y pan. La producción y las
compras usan esa reserva automáticamente; las demás mercancías usan el almacén
general. No se puede demoler si las existencias o cargas reservadas dejarían de
caber. Tiene modelo Blender e icono propios, con pilares, tornarratos, cámara
ventilada y cubierta de teja.

Las ayudas del catálogo explican primero la función de cada edificio y después
sus requisitos. Desplazar el menú con la rueda no modifica el zoom del mapa.

**Recursos** muestra existencias y cadenas. El minimapa permite recorrer las dos
orillas; **Inicio** vuelve al almacén o al área de fundación si aún no existe.
WASD/flechas desplazan la cámara, la rueda controla el zoom, Espacio pausa y clic
derecho/Escape cancela la herramienta. Arrastra para trazar caminos.

Las **salinas**, en **Construir → Alimentos**, producen 4 de sal por ciclo con
un trabajador. Cuestan 60 monedas y 10 de madera, ocupan 3×2 casillas y necesitan
un borde junto al agua y camino al almacén. Todos los recursos tienen una cadena
de producción local. Los vecinos comen cereal, sardina y pan; la harina y la uva
son ingredientes, el vino abastece viviendas y la salazón se destina al comercio.

**Convento**, en **Construir → Servicios**, está inspirado en San Francisco de
Pontevedra: rosetón de piedra, portada con arcos, campanario lateral y ala
conventual con patio. Ocupa 10×8 casillas (R gira la parcela) y cuesta 320 monedas,
40 de madera y 80 de piedra. Ofrece culto hasta 48 pasos por caminos, tiene dos
empleos y consume cinco monedas de mantenimiento diario. Necesita conexión al
almacén y personal para activar el servicio. Está incluido en **Ciudad avanzada**.
[Ver el modelo](art/renders/convent-design.png).

Los edificios cívicos tienen arquitecturas diferenciadas: mercado de toldos,
hospital con patio y soportales, capilla con ábside, torre de guardia octogonal,
escuela de una planta con ventanas altas, torre abierta de vigías, taller de
obras con andamios y hospedería de dos plantas con balcón sobre ménsulas.
[Ver la colección](art/renders/civic-buildings-review.png).

Al cargar una partida con el convento anterior de 6×5, el juego amplía su
parcela. Si no cabe, busca una ubicación próxima con acceso por caminos, sin
mover los demás edificios ni cobrar recursos. Conserva habitantes, empleos y
conservación; el archivo original permanece intacto hasta que vuelvas a guardar.

El puente del Burgo cruza ahora un tramo más estrecho del Lérez, 40 casillas
más al este; el camino es recto de norte a sur y está alineado con el puente. Su longitud pasa de
40 a 22 casillas.

El panel **Tu villa** explica qué falta para recibir vecinos, muestra cuántos
están de camino y avisa cuando la simulación está en pausa.

Los guardados nuevos usan `user://pontevedra-ria-v5.json`, con esquema 3.
Los mapas anteriores conservan sus archivos `pontevedra-ria-v2.json` y
`pontevedra-ria-v3.json` y `pontevedra-ria-v4.json` separados; su geografía y huellas no se reinterpretan
como partidas nuevas. Se guardan niveles, orientación, conservación, visitantes,
cupos, objetivos, cargas y rutas. Los valores de balance están en JSON y aún
necesitan ajuste mediante partidas largas.


Exportación web local:

```sh
mkdir -p build/web
.tools/Godot.app/Contents/MacOS/Godot --headless --path . --export-release Web build/web/index.html
```

Validación de simulación, interacción de la escena y recursos visuales:

```sh
.tools/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/test_runner.gd
.tools/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/ui_runner.gd
.tools/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/developer_runner.gd
.tools/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/check_models.gd
.tools/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/check_ui_assets.gd
.tools/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/run_simulation.gd -- --ticks 10000
```

[Modelos originales](art/README.md) · [Dirección artística](docs/ART_DIRECTION.md) ·
[Propuesta de evolución de las mecánicas](docs/MECHANICS_ROADMAP.md) ·
[Controlar Blender mediante MCP](docs/BLENDER_MCP.md)

### Consola de desarrollo

**F4** o **Consola** abre la consola y pausa la partida. Ofrece botones para
dinero infinito, añadir monedas, reponer recursos, reparar edificios y preparar
ciudades. F4 o Escape la cierra; Espacio reanuda la simulación.

```text
help                     # lista de comandos
money infinite           # mantiene 1.000.000.000 de monedas
money off                # desactiva el truco y restaura el saldo anterior
money 10000              # añade monedas
resources                # identificadores de recursos
resource wood 100        # añade madera si cabe en el almacén
stock                    # repone hasta 200 unidades por recurso según espacio
citizens 10              # añade vecinos con plazas, agua, alimentos y empleos
repair                   # restaura edificios y extingue incendios
city developing          # villa preparada; pide confirmar la sustitución
city advanced            # ciudad avanzada; pide confirmar la sustitución
```

Escribe solo el comando, sin el comentario. ↑ y ↓ recorren el historial.
El dinero infinito se desactiva al iniciar o cargar otra ciudad. Los cambios de
saldo, recursos y edificios se conservan si guardas, incluido el saldo elevado
si guardas con dinero infinito activo. Los recursos respetan almacenes, hórreos
y cargas reservadas para que los guardados sigan siendo válidos.

### Caminos y trabajadores

**Construir → Servicios** permite elegir **Camino de tierra** o **Camino
pavimentado**. Ambos conectan viviendas, empleos y servicios de la misma manera.
Cada casilla nueva o cuyo acabado se cambie cuesta una moneda; repasar el mismo
acabado no cobra. Arrastra sobre un camino para cambiarlo. El puente conserva
su pavimento de piedra. Los guardados anteriores se leen como pavimentados;
los nuevos conservan el acabado por casilla, también en el minimapa.

Al llegar al lugar de trabajo, el vecino queda dentro del edificio y vuelve a
verse al salir. Un **punto verde** indica cuántos trabajadores hay dentro; un
**punto ámbar** indica personal asignado que está fuera. Al pasar el ratón por
el edificio se muestran presentes y asignados. Los indicadores se ocultan en
la vista general para mantener el mapa despejado.
