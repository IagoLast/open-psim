# Evolución de la villa y mecánicas de juego

Diseño de referencia · 6 de septiembre de 2026.

**Implementación inicial · 7 de septiembre de 2026:** mapa 256×256, fundación
vacía, huellas rectangulares y rotación, tres niveles con capacidad y modelos,
orientación y detección de adosamiento, objetivos sostenidos, emigración,
incendios, conservación, reparación, hospedería y peregrinos. Añadido comercio
inmediato en almacén con mercaderes periódicos y cupos por visita. Ver el README
para las reglas jugables actuales. Las variantes y módulos artísticos nuevos,
la fusión de parcelas y una propagación de incendios entre edificios siguen
pendientes. El primer sistema usa acumulación determinista de riesgo; la
vecindad aumenta el riesgo residencial. Los umbrales necesitan más juego.

El texto siguiente conserva la propuesta original para contrastar su alcance.
Propuesta de diseño · 6 de septiembre de 2026. Describe el estado comprobado y
una dirección para las siguientes versiones; las reglas propuestas todavía no
están implementadas. Los valores de población, plazos y costes requieren ajuste
jugando.

La experiencia que buscamos: fundar un pequeño asentamiento junto al camino,
conseguir que sus vecinos prosperen y convertirlo en una villa que sostenga a
sus habitantes, el puerto y, más adelante, a quienes peregrinan a Santiago.

## 1. Qué hay hoy y qué falta

| Área | Estado comprobado | Cambio que necesitamos |
| --- | --- | --- |
| Viviendas | Tres niveles: humilde, próspera y mercantil. Mejoran con servicios y bienes; siempre caben cuatro vecinos. | Que nivel, capacidad y aspecto evolucionen juntos, con causas visibles. |
| Aspecto residencial | `asset_factory.gd` escoge entre tres siluetas usando el ID. `world_view.gd` no sustituye el modelo al cambiar de nivel. | Separar nivel, variante estética y relación con caminos y vecinos. |
| Parcelas | Ya existen huellas cuadradas: pozo 1×1, viviendas y muchos talleres 2×2, almacén 3×3, granja 4×4. | Incorporar rectángulos, rotación y una ocupación visual más variada. No hace falta partir de una supuesta huella universal de 6×6. |
| Inicio | Almacén protegido, dos casas, pozo, ocho vecinos y un pequeño camino local. El puente es transitable, pero no hay camino inicial de extremo a extremo. | Empezar sin edificios ni habitantes, con camino exterior y puente. |
| Dificultad | Hay alimentación, empleo, mantenimiento de servicios y comercio. El desempleo reduce satisfacción; no hay emigración, incendios ni derrumbes. | Consecuencias graduales y recuperables por desatender barrios. |
| Objetivos | Trece hitos permanentes, sin condición de victoria de escenario. | Un encargo principal, etapas y condiciones que deban sostenerse. |
| Extensión | Edificios, recursos y puertos ya se cargan de JSON; niveles, servicios y objetivos contienen reglas fijas en código. | Extender ese patrón de datos a necesidades, evolución y escenarios. |

Referencias de implementación: [simulación](../sim/simulation.gd),
[vecinos](../sim/systems/citizens.gd), [economía](../sim/systems/economy.gd),
[edificios](../data/buildings.json), [modelos](../presentation/asset_factory.gd),
[vista](../presentation/world_view.gd) y [variantes](../data/model_variants.json).

Comprobación de referencia: `tests/test_runner.gd` pasa 107 comprobaciones.
`tools/run_simulation.gd -- --ticks 10000`, con semilla 1530 y la economía de
`tests/scenarios/startup.gd`, termina con ocho habitantes, 808 monedas, 200 de
cereal y 368 de pescado. Es una muestra reproducible de acumulación tras montar
la economía básica; no demuestra el equilibrio de todas las estrategias.

## 2. Viviendas que crecen y forman calles

Construimos una parcela residencial pequeña. Con habitantes, abastecimiento y
servicios mantenidos, la casa mejora automáticamente. La evolución debe resultar
visible y ofrecer espacio para más vecinos; también aumenta las necesidades y el
coste de sostener ese barrio.

Primera versión: conservar la parcela 2×2 y aprovechar mejor el espacio y la
altura al mejorar. Esto permite formar calles contiguas desde el principio.
Una ampliación de huella o una fusión de parcelas será una mecánica posterior,
explícita y con espacio disponible: una mejora no ocupa caminos ni terrenos
ajenos automáticamente.

| Nivel propuesto | Requisitos | Capacidad inicial para probar | Aspecto |
| --- | --- | --- | --- |
| Humilde | Acceso, alimentos y agua para mantenerse habitada | 4 | Casa baja, parte de la parcela libre |
| Próspera | Lo anterior más mercado, salud y culto durante tres días | 6 | Más volumen y mejor acabado |
| Mercantil | Servicios anteriores, seguridad, educación y suministro sostenido de cerámica, paños y vino | 8 | Más altura, fachada urbana y detalles de prosperidad |

Empezar con los tres modelos existentes, asignando cada uno al nivel cuya
silueta corresponda tras revisarlos visualmente. No producir nuevas variantes
artísticas en esta fase.

Reglas de evolución:

- Mostrar en el inspector cada requisito y el avance: «Mercado ausente» o
  «Abastecimiento estable: 2/3 días».
- Mejorar como máximo un nivel por evaluación. Los requisitos mercantiles
  también necesitan continuidad; no basta recibir una sola unidad de bienes.
- Una carencia avisa primero. Tras un margen inicial de dos días consecutivos,
  bajar un nivel; evitar cambios diarios de aspecto por fluctuaciones de stock.
- Vincular las raciones a los ocupantes. Los bienes de nivel alto pueden
  calcularse por hogar o por grupos de vecinos, pero deben declararlo en datos.
- Al bajar de capacidad, detener nuevas admisiones y trasladar gradualmente el
  exceso a viviendas disponibles; después, permitir su salida. Guardados y UI
  deben admitir esa sobreocupación temporal sin perder ciudadanos.

### Relación con caminos y casas contiguas

La fachada principal mira hacia un borde con acceso al camino. Si hay varios,
mantener la orientación elegida mientras siga siendo válida; permitir rotación
manual al colocar. El acceso funcional y la puerta visual deben corresponder.

Identificar vecinos por lados completos o tramos compartidos, no por diagonales.
Una casa aislada, entre medianeras o en esquina puede usar módulos diferentes.
Compartir pared no fusiona población, empleo ni IDs de las casas.

Separar tres conceptos:

- **Nivel:** decide capacidad, necesidades y familia de siluetas.
- **Variante:** escoge un modelo compatible de esa familia mediante identidad
  estable; no depende del orden en que se recorre el catálogo.
- **Contexto:** fachada, lados adosados y esquina seleccionan módulos compatibles.

El catálogo ya tiene selección determinista. Ampliarlo con nivel, frente y
compatibilidad de adosamiento; mantener un modelo de respaldo cuando no exista
la combinación. Guardar la elección o versionar el catálogo para que añadir
variantes no cambie arbitrariamente las casas de partidas antiguas. Una fachada
adosada real requerirá modelos preparados con paredes, aleros y detalles
compatibles; girar los actuales es solo el primer paso.

Actualizar únicamente las casas afectadas cuando cambien nivel, camino o
vecindad. Un cambio de nivel necesita refresco visual aunque la red de caminos
no haya cambiado.

## 3. Inicio con camino y puente

El mapa arranca en pausa, con terreno, vegetación, recursos naturales, un camino
continuo de entrada a salida y el puente del Burgo. Cero edificios y cero
habitantes. El tramo principal queda protegido en el escenario inicial para
garantizar acceso exterior; sus ramales los construye el jugador.

Primer encargo visible: **«Funda un barrio: almacén, dos viviendas con agua y
una fuente de trabajo y alimentos»**. El catálogo y la cámara orientan hacia
suelo adecuado sin imponer una parcela exacta.

La ayuda de fundación aporta monedas y materiales al inventario inicial. Se
pueden gastar en el primer almacén, que no requiere empleados. Los vecinos
llegan después de conectar almacén, viviendas, pozo y puestos de trabajo; la
reserva de comida inicial cubre la espera hasta la primera producción. El coste
total de esa secuencia, incluidos caminos y margen para errores, debe caber en
la ayuda inicial. La primera inmigración debe admitir hasta el número de plazas
libres, sin exigir siempre una pareja si solo cabe una persona.

Hay una dependencia que resolver: `building(1)` es hoy el origen de caminos y
de inmigración, y la validación exige que sea el almacén. Sustituirla por puntos
de entrada del escenario y almacenes identificados por su función.

Separar **acceso al exterior** de **acceso al almacenamiento**. Una casa puede
estar junto al camino antes de existir almacén; producir y abastecer exige
alcanzar un almacén operativo por esa red. Mantener inicialmente inventario
global, sin añadir todavía carretas ni inventarios por edificio. Revisar también
la acción «Inicio» para que centre el área de fundación sin necesitar edificio 1.

## 4. Tamaños con intención urbana

Representar la huella mediante ancho y fondo, con giro de 90°. Propuesta de
primera distribución, pendiente de comprobar terreno y encaje de modelos:

| Tipo | Huella propuesta | Intención |
| --- | --- | --- |
| Pozo | 1×1 | Insertarlo dentro de barrios compactos |
| Vivienda | 2×2 | Calles contiguas y crecimiento vertical |
| Taller pequeño | 2×2 o 2×3 | Fachada estrecha y fondo de trabajo |
| Mercado | 3×3 | Centro de barrio |
| Capilla / hospital | 2×3 / 3×4 | Edificios públicos reconocibles |
| Almacén | 3×4 | Volumen portuario y frente de acceso |
| Granja | 4×4 | Conservar espacio agrícola |
| Muelle | 3×2 | Frente de costa y acceso terrestre diferenciados |

Una función común calcula dimensiones orientadas, casillas ocupadas y bordes.
Usarla en construcción, coste previo, acceso, radio a depósitos, selección,
demolición, minimapa, superposiciones y validación de guardados. La validación
marítima también asume actualmente muelles cuadrados.

La geometría debe conservar sus proporciones. Los modelos que no llenen una
parcela rectangular pueden incorporar patio, almacén exterior o campo; evitar
estirarlos para cubrirla. La vista previa muestra la huella real y su orientación.

## 5. Dificultad que nace de decisiones

La base es equilibrar población, puestos de trabajo, abastecimiento y gasto
corriente. Construir más viviendas aumenta capacidad, pero también consumo y
demanda de empleo. Abrir servicios compite por esos mismos trabajadores.

**Paro prolongado y emigración.** Medir días sin trabajo, hambre o falta de
servicios básicos por vecino. El malestar sostenido frena llegadas y puede
provocar salidas, con aviso y margen para corregir. No aplicar emigración
inmediata a recién llegados ni mientras van a su primer empleo. La tasa de paro
usa población apta para trabajar; inicialmente coincide con los vecinos
actuales. Los visitantes futuros no cuentan.

**Incendios.** Acumular riesgo por actividad y características del edificio:
hornos y talleres con fuego exigen más prevención; la continuidad de casas
puede facilitar la propagación. Un servicio de vigilancia contra incendios,
con agua, personal y camino, reduce riesgo y responde a avisos. La interfaz
muestra causas y cobertura. Un fuego pasa por aviso, incidente y daño, con
tiempo para intervenir. Empezar con un único incidente activo y protección
durante la fundación para ajustar la dificultad.

**Deterioro y derrumbes.** Introducir después estado de conservación y una
cuadrilla de mantenimiento. El abandono, la falta de materiales y el crecimiento
sin servicios deterioran edificios durante varios días. Mostrar grietas y
advertencias antes de convertirlos en ruinas. Diferenciar la conservación del
nivel socioeconómico de la vivienda.

La ruina conserva una identidad y permite reparar. Sus habitantes se reubican
o quedan pendientes de alojamiento; los trabajadores y rutas se reasignan.
Resolver esa transición antes de permitir que una catástrofe elimine edificios:
hoy incluso la demolición manual protege las viviendas ocupadas.

Toda crisis debe indicar causa, consecuencia y remedio. Si se usa azar para
incendios, debe estar acotado por el riesgo y ser reproducible al guardar y
cargar. La prevención ha de ser eficaz sin exigir atención continua a cada casa.
No introducir a la vez fuego, derrumbes, enfermedades, delincuencia y cosechas
variables: primero medir una presión económica y un tipo de emergencia.

## 6. Un encargo principal y etapas

Primer escenario propuesto: **«Consolida una villa portuaria»**.

1. **Fundación:** ocho vecinos alojados y abastecidos; producción alimentaria
   operativa. Enseña caminos, trabajo y primeras reservas.
2. **Estabilidad:** 24 vecinos, reserva para tres días y al menos 80 % de empleo
   durante cinco días consecutivos. Enseña a equilibrar crecimiento y servicios.
3. **Prosperidad:** al menos seis viviendas prósperas ocupadas y una primera
   exportación entregada. Conecta desarrollo urbano y puerto.
4. **Encargo cumplido:** 40 vecinos, seis viviendas prósperas ocupadas, reserva
   de tres días, al menos 80 % de empleo y saldo de caja operativo no negativo
   durante cinco días consecutivos; acumular 50 unidades de exportación entregadas.

Los umbrales son hipótesis de balance. El objetivo debe ser alcanzable con los
edificios y recursos actuales. El saldo operativo incluye impuestos, comercio
y mantenimiento; excluye subvención inicial y construcción para que un gasto de
expansión no falsee la sostenibilidad del día. Definir en datos la ventana de
cálculo para que los plazos marítimos no vuelvan arbitrario el indicador.

Mostrar siempre objetivo actual, progreso y requisito pendiente. Los hitos
cumplidos siguen como historial, pero la victoria comprueba condiciones actuales
simultáneas: haber alimentado al barrio una vez no basta. Al terminar, presentar
el resultado y permitir continuar en modo libre.

Fallo inicial: quedarse sin habitantes después de la fundación y sin condiciones
para nuevas llegadas durante un plazo de recuperación visible. Antes, ofrecer
una ayuda de emergencia limitada, con coste sobre la valoración del escenario.
Estar en cero monedas un día no termina por sí solo la partida. El modo libre
puede prescindir del fallo de escenario.

## 7. Camino de Santiago y peregrinos

El camino principal ofrece una base natural para esta expansión. La información
municipal sitúa el Camino Portugués en Pontevedra, su paso por el puente del
Burgo y la atención a peregrinos en el antiguo hospital. Eso fundamenta el tema;
el trazado exacto en 1530, arquitectura, flujos y servicios de época requieren
investigación específica antes de producir contenido histórico.
[Fuente: Turismo de Pontevedra](https://www.visit-pontevedra.com/camino-de-santiago/).

Los peregrinos serían visitantes temporales: entran, recorren la ruta, solicitan
comida, descanso o cuidados y continúan. No ocupan viviendas de residentes,
no pagan impuestos residenciales ni cubren puestos de trabajo. Una posada u
hospedería aporta camas; el hospital y los servicios existentes cubren otras
necesidades según capacidad y acceso.

Buena atención genera ingresos y reputación, pero consume comida, camas y trabajo
que también necesita la villa. Las llegadas se limitan por capacidad y un flujo
de escenario; no aumentan sin límite por reputación. Debe ser viable priorizar
alimentos para residentes, limitar admisiones o ampliar hospitalidad.

Una futura misión puede exigir atender a una comitiva y mantener abastecida la
población al mismo tiempo. Contar visitantes atendidos y salidas completadas,
no solamente entradas. El puerto y el camino aportan así dos demandas distintas
sobre la misma economía.

Preparar ahora entradas/salidas de mapa, necesidades declarativas y objetivos
por escenario. Incorporar actores visitantes, camas, reputación y nuevas
animaciones cuando se implemente esta fase.

## 8. Entregas propuestas y validación

| Fase | Entrega jugable | Criterio de aceptación |
| --- | --- | --- |
| A. Fundación | Camino y puente iniciales, almacén construible, inmigración desde el exterior, encargo guiado | Partida de cero a ocho vecinos y primera producción usando solo presupuesto inicial; guardar/cargar también antes de construir. |
| B. Forma urbana | Huellas rectangulares, rotación, nivel visual y capacidad residencial; catálogo preparado para contexto y variantes | Construir y seleccionar rectángulos girados sin solapamientos; evolución visible, acceso coherente y estabilidad visual al cargar. Los modelos adosados nuevos quedan para una entrega artística posterior. |
| C. Progresión | Escenario completo, gasto sostenible, paro prolongado y emigración | Alcanzar victoria y recuperarse de escasez con avisos comprensibles; evitar bloqueos de inmigración tras una crisis. |
| D. Emergencias | Prevención, primer sistema de incendios y reparación; después conservación y derrumbes | Causas visibles, respuesta eficaz, reubicación válida y continuidad determinista de incidentes al cargar. |
| E. Hospitalidad | Peregrinos, camas, demanda temporal y encargo propio | Recorrido de entrada a salida, consumo real, límites de capacidad y separación de residentes/visitantes. |

Primera implementación recomendada: **A**, seguida de **B**. El primer ciclo de
fundación permite comprobar el balance antes de añadir incendios. **C** convierte
ese ciclo en una partida con dirección y consecuencias; **D** añade emergencias
con una economía ya medible.

Extender las definiciones existentes con niveles de vivienda, necesidades y
escenarios. Mantener sistemas concretos de vivienda, empleo y riesgos que
consuman esos datos; no construir un motor genérico de reglas para futuras
mecánicas todavía indefinidas.

Cambios transversales que deben viajar con cada entrega:

- Revisar `adapters/definitions.gd` y `sim/validation.gd`: hoy fijan dimensiones
  cuadradas, capacidad de cuatro vecinos, tres niveles y almacén con ID 1.
- Versionar guardados y definiciones. Conservar posiciones y huellas de edificios
  antiguos durante una migración o aislar el nuevo escenario con un guardado
  distinto; cambiar dimensiones en el JSON puede solapar partidas existentes.
- Mantener escenarios de prueba con asentamientos preparados de forma explícita,
  separados de la nueva partida vacía. Sustituir IDs fijos en pruebas por los
  devueltos al construir.
- Probar pérdidas de acceso, evolución y descenso de capacidad, corte de
  abastecimiento, recuperación y guardado en estados intermedios. Las pruebas
  actuales son una base de regresión, no pruebas de las propuestas de este texto.
- Medir partidas de fundación, crecimiento y crisis con varias semillas antes
  de fijar umbrales. Más recursos o edificios deben introducir decisiones nuevas
  sin exigir repetir todas las cadenas productivas en cada escenario.
