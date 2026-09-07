extends SceneTree
const Simulation = preload("res://sim/simulation.gd")
const Definitions = preload("res://adapters/definitions.gd")
const Startup = preload("res://tests/scenarios/startup.gd")
const Validation = preload("res://sim/validation.gd")
const Map = preload("res://sim/world_map.gd")
const Citizens = preload("res://sim/systems/citizens.gd")
const Housing = preload("res://sim/systems/housing.gd")
const Risks = preload("res://sim/systems/risks.gd")
const Progression = preload("res://sim/systems/progression.gd")
var passed: int = 0
var failed: int = 0

func fresh() -> RefCounted:
	var sim := Simulation.new()
	sim.create(1530,Definitions.load_data())
	return sim

func check(condition: bool, title: String) -> void:
	print("OK " if condition else "FAIL ",title)
	if condition: passed += 1
	else: failed += 1

func advance(sim: Variant, ticks: int) -> void:
	for i: int in range(ticks): sim.step()

func reject(sim: Variant, command: Dictionary, title: String) -> void:
	var before: Dictionary = sim.serialize()
	check(not sim.apply_command(command).ok and sim.serialize() == before,title)

func valid(sim: Variant, title: String) -> void:
	var error: String = Validation.check(sim.serialize(),sim.definitions)
	check(error.is_empty(),title+": "+error)

func _initialize() -> void:
	var sim: Variant = fresh()
	check(sim.width() == 512 and sim.state.terrain.size() == 262144,"Mapa 512×512: cuatro veces la superficie")
	check(sim.state.buildings.is_empty() and sim.state.citizens.is_empty(),"Fundación vacía")
	check(sim.state.roads == Map.main_road() and sim.exterior.has(Map.exit_cell()),"Camino continuo entre extremos por el puente")
	check(sim.state.roads.size() == Map.SIZE and sim.state.roads.all(func(c: int) -> bool: return c%Map.SIZE == Map.BURGO_BRIDGE.position.x),"Camino completamente recto y alineado con el puente")
	check(sim.state.roads.all(func(c: int) -> bool: return sim.state.terrain[c] != "water"),"Camino principal sobre terreno transitable")
	var bridge: Rect2i = Map.BURGO_BRIDGE
	check(bridge.position.x > 400 and bridge.size.y < 40,"Puente desplazado al este y más corto")
	check(sim.state.terrain[(bridge.position.y-1)*Map.SIZE+bridge.position.x] != "water" and sim.state.terrain[bridge.end.y*Map.SIZE+bridge.position.x] != "water","Puente apoyado en ambas orillas")
	check(sim.state.terrain[60*Map.SIZE+439] == "water" and sim.state.terrain[60*Map.SIZE+442] == "water","El nuevo puente cruza el cauce estrecho")
	check(sim.state.terrain[76*Map.SIZE+400] == "water","El cruce anterior recupera el río")
	check(sim.state.terrain == fresh().state.terrain,"Geografía determinista")
	valid(sim,"Guardado sin edificios")
	var clone: Variant = fresh()
	check(clone.restore(sim.serialize()).ok,"Carga de partida vacía")
	reject(sim,{"type":"demolish","cell":Map.entrance()},"Camino exterior protegido sin efectos")
	reject(sim,{"type":"build","kind":"house","x":bridge.position.x,"z":bridge.position.y},"Puente protegido")
	reject(sim,{"type":"build","kind":"house","x":511,"z":511},"Límites de huella")
	reject(sim,{"type":"build","kind":"warehouse","x":441,"z":128,"rotation":7},"Giro inválido")
	var house: int = Startup.build(sim,"house",441,133)
	check(not sim.building(house).connected and sim.building(house).access >= 0,"Casa accede al exterior antes del almacén")
	var warehouse: int = Startup.build(sim,"warehouse",441,128,1)
	check(warehouse != 1 and sim.building(house).connected,"Almacén construible sin ID reservado")
	check(sim.footprint("warehouse",441,128,1).size() == 12 and sim.occupied.has(130*512+444) and not sim.occupied.has(131*512+441),"Huella rectangular girada real")
	reject(sim,{"type":"build","kind":"house","x":444,"z":129},"Solapamiento rectangular rechazado sin cobro")
	valid(sim,"Guardado de rectángulo girado")
	check(clone.restore(sim.serialize()).ok and clone.occupied == sim.occupied,"Rotación sobrevive a carga")

	sim = fresh()
	var ids: Dictionary = Startup.build_economy(sim)
	check(sim.state.coins > 0 and sim.state.inventory.wood > 0,"Fundación completa asequible con ayuda inicial")
	advance(sim,2400)
	check(sim.state.citizens.size() == 8,"Ocho vecinos inmigran desde el camino")
	check(sim.state.citizens.all(func(c: Dictionary) -> bool: return c.job > 0 and not c.arriving),"Llegan andando y se incorporan al empleo")
	check(sim.building(ids.farm).produced > 0 and sim.building(ids.fishery).produced > 0,"Producción alimentaria real")
	check(sim.state.objective.founded,"Encargo de fundación completado")
	valid(sim,"Fundación integrada")
	check(not sim.state.merchant.is_empty(),"Mercaderes llegan sin muelle propio")
	while sim.state.merchant.is_empty() or sim.state.merchant.status != "En puerto": sim.step()
	var recorded_flow: Dictionary = sim.state.resource_flow.duplicate(true)
	check(preload("res://sim/systems/economy.gd").total(recorded_flow.previous.production) > 0,"Balance registra producción local real del último día")
	check(preload("res://sim/systems/economy.gd").total(recorded_flow.previous.consumption) > 0,"Balance registra consumo interno real del último día")
	var coins: int = sim.state.coins
	var salt: int = sim.state.inventory.salt
	check(sim.apply_command({"type":"merchant_trade","warehouse":ids.warehouse,"direction":"buy","resource":"salt","quantity":10}).ok,"Comprar sal desde almacén")
	check(sim.state.coins == coins-20 and sim.state.inventory.salt == salt+10,"Compra inmediata: cobro y mercancía exactos")
	coins = sim.state.coins
	var wood: int = sim.state.inventory.wood
	check(sim.apply_command({"type":"merchant_trade","warehouse":ids.warehouse,"direction":"sell","resource":"wood","quantity":5}).ok,"Venta al mercader visitante")
	check(sim.state.coins == coins+10 and sim.state.inventory.wood == wood-5,"Venta cobra una vez")
	check(sim.state.resource_flow == recorded_flow,"Compras y ventas no alteran producción ni consumo interno")
	reject(sim,{"type":"merchant_trade","warehouse":ids.warehouse,"direction":"buy","resource":"salt","quantity":31},"Cupo agotado rechaza sin efectos")
	reject(sim,{"type":"merchant_trade","warehouse":ids.warehouse,"direction":"buy","resource":"fish","quantity":1},"Mercancías solo de compra respetadas")
	var saved: Dictionary = Definitions._integers(JSON.parse_string(JSON.stringify(sim.serialize())))
	check(clone.restore(saved).ok,"Guardar y cargar visita con cupos gastados")
	check(clone.state.resource_flow == sim.state.resource_flow,"Balance diario sobrevive al guardado JSON")
	advance(sim,50)
	advance(clone,50)
	check(sim.serialize() == clone.serialize(),"Continuación determinista de inmigración y mercaderes")
	var visit_number: int = sim.state.merchant_visits
	advance(sim,1201)
	check(sim.state.merchant_visits > visit_number,"Visitas marítimas recurrentes")
	var dock: int = Startup.nearby(sim,"dock",Vector2i(430,70))
	var trade: Dictionary = sim.apply_command({"type":"trade","dock":dock,"port":"porto","direction":"buy","resource":"salt","quantity":10})
	check(trade.ok,"Ruta propia del muelle conserva comercio marítimo")
	if trade.ok:
		var before: int = sim.state.inventory.salt
		advance(sim,600)
		check(sim.state.voyages.is_empty() and sim.state.trade_completed > 0,"Travesía entrega y finaliza")
	valid(sim,"Comercio, mercaderes y producción coexistentes")

	test_housing()
	test_risks()
	test_pilgrims()
	test_objective()
	test_granary()
	test_arrivals()
	test_road_surfaces()
	test_food_chains()
	test_coastal_fill()
	test_convent()
	print("RESULTADO: %d correctas / %d fallidas" % [passed,failed])
	quit(1 if failed else 0)

func test_convent() -> void:
	var sim: Variant = fresh()
	sim.state.coins = 2000
	sim.state.inventory.stone = 100
	Startup.build(sim,"warehouse",441,128)
	var home_id: int = Startup.build(sim,"house",441,133)
	var home: Dictionary = sim.building(home_id)
	var coins: int = sim.state.coins
	var wood: int = sim.state.inventory.wood
	var stone: int = sim.state.inventory.stone
	var convent: int = Startup.build(sim,"convent",441,136,1)
	Startup.connect_building(sim,convent)
	check(sim.dimensions(sim.building(convent)) == Vector2i(8,10) and sim.footprint("convent",441,136,1).size() == 80,"Convento: parcela monumental 10×8 giratoria")
	check(sim.state.coins == coins-320 and sim.state.inventory.wood == wood-40 and sim.state.inventory.stone == stone-80,"Convento: coste de monedas, madera y granito")
	check(not home.services.faith,"Convento sin personal no aporta culto")
	for i: int in range(2): sim._add_citizen(home_id,home.access)
	Citizens.assign_jobs(sim)
	check(home.services.faith and sim.building(convent).assigned == 2,"Convento con personal cubre culto por caminos")
	sim.apply_command({"type":"activity","id":convent})
	check(not home.services.faith,"Desactivar convento retira cobertura")
	sim.apply_command({"type":"activity","id":convent})
	var before_upkeep: int = sim.state.coins
	Citizens.daily(sim)
	check(sim.state.coins == before_upkeep-5,"Convento cobra cinco monedas de mantenimiento diario")
	valid(sim,"Guardado válido con convento")
	var clone: Variant = fresh()
	check(clone.restore(Definitions._integers(JSON.parse_string(JSON.stringify(sim.serialize())))).ok and clone.building(convent).type == "convent","Cargar convento conserva edificio y servicio")

func test_food_chains() -> void:
	var sim: Variant = fresh()
	# Start with no assumed imports or initial stock: detect missing producers and cycles.
	var obtainable: Dictionary = {}
	for iteration: int in range(sim.definitions.resources.size()):
		for d: Dictionary in sim.definitions.buildings.values():
			if d.get("outputs",{}).is_empty(): continue
			if d.get("inputs",{}).keys().all(func(r: String) -> bool: return obtainable.has(r)):
				for resource: String in d.outputs: obtainable[resource] = true
	for resource: String in sim.definitions.resources:
		check(obtainable.has(resource),"Producción local alcanzable: " + resource)

	sim.state.coins = 10000
	sim.state.inventory.wood = 500
	Startup.build(sim,"warehouse",441,128)
	reject(sim,{"type":"build","kind":"saltworks","x":445,"z":128},"Salinas rechazan parcelas interiores")
	var producers: Array = []
	for kind: String in ["lumber","farm","fishery","saltworks","saltery","mill","bakery","vineyard","winery"]:
		var origin := Vector2i(445,128)
		if kind in ["farm","vineyard"]: origin = Vector2i(444,112)
		if kind == "lumber": origin = Vector2i(456,142)
		if kind in ["fishery","saltworks"]: origin = Vector2i(438,70)
		producers.append(sim.building(Startup.nearby(sim,kind,origin,1 if kind == "saltworks" else 0)))
	valid(sim,"Cadenas alimentarias construibles en el mapa real")
	var clone: Variant = fresh()
	check(clone.restore(sim.serialize()).ok,"Guardado con salinas giradas se puede cargar")
	for resource: String in sim.state.inventory: sim.state.inventory[resource] = 0
	var saltworks: Dictionary = producers[3]
	sim.Economy.produce(sim)
	check(sim.state.inventory.salt == 0 and saltworks.block == "0/1 trabajadores","Salinas sin personal no producen")
	# Isolate production from daily consumption and walking; inputs must come from these buildings.
	for item: Dictionary in producers:
		item.assigned = sim.definitions.buildings[item.type].jobs
		item.present = item.assigned
	saltworks.connected = false
	sim.Economy.produce(sim)
	check(sim.state.inventory.salt == 0 and saltworks.block == "Sin camino al almacén","Salinas desconectadas no producen")
	saltworks.connected = true
	for tick: int in range(600): sim.Economy.produce(sim)
	for item: Dictionary in producers:
		check(item.produced > 0,"Cadena alimentaria produce sin compras: " + item.type)
	check(sim.state.inventory.salted_fish > 0 and sim.state.inventory.bread > 0 and sim.state.inventory.wine > 0,"Salazón, pan y vino desde inventario vacío")

func test_granary() -> void:
	var sim: Variant = fresh()
	var warehouse: int = Startup.build(sim,"warehouse",441,128)
	var horreo: int = Startup.build(sim,"horreo",447,133)
	check(sim.footprint("horreo",447,133).size() == 1,"El hórreo ocupa una sola casilla")
	for resource: String in sim.state.inventory: sim.state.inventory[resource] = 0
	sim.state.inventory.wood = 1200
	check(not sim.Economy.has_room(sim,"grain",1),"Hórreo desconectado no amplía capacidad")
	Startup.connect_building(sim,horreo)
	check(sim.Economy.has_room(sim,"grain",400),"Hórreo conectado añade 400 plazas de cereal")
	check(not sim.Economy.has_room(sim,"wood",1),"La madera no ocupa la reserva alimentaria")
	sim.state.inventory.grain = 399
	advance(sim,301)
	check(sim.apply_command({"type":"merchant_trade","warehouse":warehouse,"direction":"buy","resource":"grain","quantity":1}).ok,"Compra de cereal entra en el hórreo con almacén general lleno")
	reject(sim,{"type":"merchant_trade","warehouse":warehouse,"direction":"buy","resource":"grain","quantity":1},"Hórreo lleno rechaza sobrecapacidad sin cobro")
	valid(sim,"Guardado con 1200 mercancías y 400 alimentos")
	var clone: Variant = fresh()
	check(clone.restore(sim.serialize()).ok and clone.state.inventory.grain == 400,"Carga conserva los alimentos del hórreo")
	var item: Dictionary = sim.building(horreo)
	reject(sim,{"type":"demolish","cell":item.z*sim.width()+item.x},"No se demuele un hórreo cuya reserva está ocupada")
	sim.state.inventory.grain = 0
	check(sim.Economy.has_room(sim,"flour",400) and sim.Economy.has_room(sim,"bread",400),"Harina y pan comparten reserva alimentaria")
	check(not sim.Economy.has_room(sim,"salt",1),"La sal necesita almacenamiento general")
	check(sim.apply_command({"type":"demolish","cell":item.z*sim.width()+item.x}).ok,"Hórreo vacío se puede demoler")

func test_arrivals() -> void:
	var sim: Variant = fresh()
	check(Citizens.immigration_plan(sim.state,sim.definitions).reason.contains("almacén"),"La llegada explica que falta almacén")
	Startup.build(sim,"warehouse",441,128)
	check(Citizens.immigration_plan(sim.state,sim.definitions).reason.contains("vivienda"),"La llegada explica que falta vivienda")
	Startup.build(sim,"house",441,133)
	check(Citizens.immigration_plan(sim.state,sim.definitions).reason.contains("agua"),"La llegada explica que falta agua")
	Citizens.immigrate(sim)
	check(sim.state.citizens.is_empty(),"Sin agua no llegan vecinos")
	Startup.build(sim,"well",441,139)
	check(Citizens.immigration_plan(sim.state,sim.definitions).reason.contains("empleos"),"La llegada explica que faltan empleos")
	Startup.nearby(sim,"lumber",Vector2i(456,142))
	check(Citizens.immigration_plan(sim.state,sim.definitions).count == 2,"Vivienda, agua, alimentos y empleo permiten llegar")
	Citizens.immigrate(sim)
	check(sim.state.citizens.size() == 2 and sim.state.citizens[0].cell == Map.exit_cell(),"Los vecinos entran por el extremo más cercano")
	check(Citizens.immigration_plan(sim.state,sim.definitions).arriving == 2,"El estado diferencia vecinos de camino")
	advance(sim,300)
	check(sim.state.citizens.size() == 2 and sim.state.citizens.all(func(c: Dictionary) -> bool: return not c.arriving and c.job > 0),"Primera pareja llega a casa y obtiene trabajo en una jornada")
	valid(sim,"Llegada desde el norte se puede guardar")

func test_road_surfaces() -> void:
	var sim: Variant = fresh()
	Startup.build(sim,"warehouse",441,128)
	var home: int = Startup.build(sim,"house",445,128)
	Startup.build(sim,"well",441,126)
	var dirt: Array = [127*Map.SIZE+441,127*Map.SIZE+442,127*Map.SIZE+443,127*Map.SIZE+444]
	var paved: Array = [127*Map.SIZE+445,127*Map.SIZE+446]
	check(sim.apply_command({"type":"road","surface":"dirt","cells":dirt}).ok,"Construir un tramo de tierra")
	check(sim.apply_command({"type":"road","surface":"paved","cells":paved}).ok,"Continuar con pavimento")
	check(sim.building(home).connected and sim.building(home).water,"Caminos mixtos conectan almacén, vivienda y agua")
	var coins: int = sim.state.coins
	check(sim.apply_command({"type":"road","surface":"dirt","cells":dirt}).ok and sim.state.coins == coins,"Repasar el mismo acabado no vuelve a cobrar")
	check(sim.apply_command({"type":"road","surface":"paved","cells":dirt}).ok and sim.state.coins == coins-dirt.size()*sim.definitions.balance.road_cost,"Pavimentar un camino cambia acabado y cobra solo sus casillas")
	check(sim.RoadSurfaces.at(sim.state,dirt[0]) == "paved" and sim.building(home).water,"Cambiar acabado conserva la cobertura")
	sim.apply_command({"type":"road","surface":"dirt","cells":dirt})
	var saved: Dictionary = Definitions._integers(JSON.parse_string(JSON.stringify(sim.serialize())))
	var clone: Variant = fresh()
	check(clone.restore(saved).ok and clone.RoadSurfaces.at(clone.state,dirt[0]) == "dirt" and clone.RoadSurfaces.at(clone.state,paved[0]) == "paved","Los dos acabados sobreviven al guardado JSON")
	var legacy: Dictionary = saved.duplicate(true)
	legacy.erase("road_surfaces")
	check(clone.restore(legacy).ok and clone.RoadSurfaces.at(clone.state,dirt[0]) == "paved","Los guardados anteriores conservan el pavimento")
	check(clone.apply_command({"type":"road","surface":"dirt","cells":dirt}).ok,"Una partida antigua permite usar tierra")
	check(sim.apply_command({"type":"demolish","cell":paved[-1]}).ok and not sim.state.road_surfaces.has(str(paved[-1])),"Demoler limpia el tipo de camino")
	reject(sim,{"type":"road","surface":"lava","cells":dirt},"Acabado desconocido rechazado sin cambios")
	reject(sim,{"type":"road","surface":"dirt","cells":[Map.BURGO_BRIDGE.position.y*Map.SIZE+Map.BURGO_BRIDGE.position.x]},"El puente mantiene su piedra")
	var bad: Dictionary = saved.duplicate(true)
	bad.road_surfaces["-1"] = "dirt"
	check(not clone.restore(bad).ok,"Guardados con superficies fuera del mapa rechazados")
	valid(sim,"Caminos mixtos válidos tras edición")

func populated() -> Variant:
	var sim: Variant = fresh()
	Startup.build_economy(sim)
	advance(sim,2400)
	sim.state.coins = 10000
	sim.state.inventory.wood = 500
	return sim

func test_housing() -> void:
	var sim: Variant = populated()
	for kind: String in ["market","clinic","chapel","watch","school"]:
		Startup.nearby(sim,kind,Vector2i(444,136))
	# Controlled service fixture isolates housing hysteresis and consumption from staffing.
	for home: Dictionary in sim.state.buildings:
		if home.type != "house": continue
		for service: String in Citizens.SERVICE_LABELS: home.services[service] = true
		home.water = true
	for c: Dictionary in sim.state.citizens: c.fed = true
	for i: int in range(3): Housing.daily(sim)
	check(sim.building(2).level == 2 and Housing.capacity(sim.building(2),sim.definitions) == 6,"Tres días mejoran nivel y capacidad")
	for resource: String in ["pottery","cloth","wine"]: sim.state.inventory[resource] = 6
	for i: int in range(3): Housing.daily(sim)
	check(sim.building(2).level == 3 and Housing.capacity(sim.building(2),sim.definitions) == 8,"Mercantil requiere suministro continuo")
	check(sim.state.inventory.wine == 0,"Bienes se consumen cada día por hogar")
	Housing.daily(sim)
	check(sim.building(2).level == 3 and sim.building(2).decline_days == 1,"Un día de carencia avisa sin descenso inmediato")
	Housing.daily(sim)
	check(sim.building(2).level == 2,"Dos días de carencia bajan solo un nivel")
	valid(sim,"Evolución residencial válida")
	var neighborhood: Variant = fresh()
	var first: int = Startup.build(neighborhood,"house",441,133)
	var adjacent: int = Startup.build(neighborhood,"house",443,133)
	check(neighborhood.building(first).adjoined != 0 and neighborhood.building(adjacent).adjoined != 0,"Casas detectan medianeras")
	var unemployed: Variant = populated()
	for b: Dictionary in unemployed.state.buildings:
		if unemployed.definitions.buildings[b.type].jobs > 0: b.active = false
	unemployed.Citizens.assign_jobs(unemployed)
	advance(unemployed,2700)
	check(unemployed.state.citizens.size() < 8,"Paro prolongado causa emigración")
	valid(unemployed,"Emigración conserva referencias")

func test_risks() -> void:
	var sim: Variant = populated()
	sim.state.tick = 4500
	var home: Dictionary = sim.building(2)
	home.age = 15
	home.fire_risk = 79
	Risks.daily(sim)
	check(home.burn_days == 1,"Riesgo acumulado inicia incendio con aviso")
	for i: int in range(3): Risks.daily(sim)
	check(home.ruined and home.condition == 0,"Fuego desatendido deja ruinas reparables")
	valid(sim,"Ruina con habitantes pendientes de realojo se guarda")
	check(sim.apply_command({"type":"repair","id":home.id}).ok and home.connected and not home.ruined,"Reparación recupera edificio y conexión")
	var firewatch: int = Startup.nearby(sim,"firewatch",Vector2i(443,139))
	sim.building(firewatch).service_active = true
	home.fire_risk = 90
	home.burn_days = 1
	Risks.daily(sim)
	check(home.burn_days == 0 and home.fire_risk == 0,"Vigías con agua extinguen fuego")
	home.condition = 21
	Risks.daily(sim)
	check(home.ruined,"Abandono estructural termina en derrumbe")
	check(sim.apply_command({"type":"repair","id":home.id}).ok,"Derrumbe reparable")

func test_pilgrims() -> void:
	var sim: Variant = populated()
	var inn: int = Startup.nearby(sim,"inn",Vector2i(441,141))
	# Transfer a worker using public activity commands.
	sim.apply_command({"type":"activity","id":8})
	advance(sim,3600)
	check(sim.state.pilgrims_served > 0,"Peregrinos llegan, se alojan y completan la salida")
	check(sim.state.reputation > 0,"Atención completada mejora reputación")
	check(sim.state.pilgrims.all(func(p: Dictionary) -> bool: return not p.has("job") and p.inn == inn),"Visitantes separados de población y empleo")
	valid(sim,"Peregrinos y camas se guardan")
	var clone: Variant = fresh()
	check(clone.restore(sim.serialize()).ok,"Carga con peregrinos")
	advance(sim,100)
	advance(clone,100)
	check(sim.serialize() == clone.serialize(),"Peregrinos continúan de forma determinista")

func test_objective() -> void:
	var sim: Variant = populated()
	# Exercise the rolling objective with attainable thresholds in an isolated scenario.
	sim.definitions.scenario.population = 8
	sim.definitions.scenario.stability_population = 8
	sim.definitions.scenario.prosperous_homes = 2
	sim.definitions.scenario.exports = 5
	for home: Dictionary in sim.state.buildings:
		if home.type == "house": home.level = 2
	sim.state.exported = 5
	sim.state.trade_completed = 1
	for i: int in range(4):
		sim.state.operating = 8
		Progression.daily(sim)
	check(not sim.state.objective.won,"Victoria exige mantener condiciones")
	sim.state.inventory.grain = 0
	sim.state.inventory.fish = 0
	Progression.daily(sim)
	check(sim.state.objective.victory_days == 0,"Carencia interrumpe la estabilidad")
	sim.state.inventory.grain = 100
	for i: int in range(10):
		sim.state.operating = 8
		Progression.daily(sim)
	check(sim.state.objective.won,"Encargo completo con condiciones sostenidas")
	sim.state.coins = 0
	check(sim.apply_command({"type":"aid"}).ok and sim.state.coins == 250,"Ayuda de emergencia permite recuperación")
	reject(sim,{"type":"aid"},"Ayuda no repetible")

func test_coastal_fill() -> void:
	var sim: Variant = fresh()
	var x: int = 100
	var z: int = 100
	# Deliberately jagged bank: half of the 3×2 saltworks lies in water.
	for dz: int in range(-1,4):
		for dx: int in range(-1,5): sim.state.terrain[(z+dz)*sim.width()+x+dx] = "water" if dz >= 1 else "land"
	var order: Dictionary = {"type":"build","kind":"saltworks","x":x,"z":z}
	var before: Dictionary = sim.serialize()
	check(sim.validate_command(order).ok and before == sim.serialize(),"Preview costera acepta ribera irregular sin modificar terreno")
	check(sim.apply_command(order).ok,"Salinas rellenan media parcela automáticamente")
	check(sim.state.get("shoreline_fill",[]).size() == 3 and sim.terrain_error("saltworks",x,z).is_empty(),"Relleno conserva un borde de agua operativo")
	valid(sim,"Relleno costero se guarda con estado válido")
	var restored: Variant = fresh()
	restored.restore(sim.serialize())
	check(restored.state.get("shoreline_fill",[]) == sim.state.shoreline_fill,"Relleno se conserva al cargar")
	reject(sim,{"type":"build","kind":"saltworks","x":x,"z":z+2},"No se puede construir flotando en agua")
	var inland: Variant = fresh()
	inland.state.terrain[100*inland.width()+100] = "water"
	reject(inland,{"type":"build","kind":"warehouse","x":100,"z":100},"Edificios terrestres no rellenan agua")
