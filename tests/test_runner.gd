extends SceneTree
const Simulation = preload("res://sim/simulation.gd")
const Definitions = preload("res://adapters/definitions.gd")
const Startup = preload("res://tests/scenarios/startup.gd")
const Validation = preload("res://sim/validation.gd")
const Runner = preload("res://adapters/simulation_runner.gd")
const Economy = preload("res://sim/systems/economy.gd")
const Citizens = preload("res://sim/systems/citizens.gd")
const Maritime = preload("res://sim/systems/maritime.gd")
const Paths = preload("res://sim/pathfinding.gd")
var passed: int = 0
var failed: int = 0

func fresh() -> RefCounted:
	var sim := Simulation.new()
	sim.create(1530,Definitions.load_data())
	return sim

func check(condition: bool, title: String) -> void:
	if condition:
		passed += 1
		print("OK  ",title)
	else:
		failed += 1
		printerr("FAIL ",title)

func advance(sim: Variant, ticks: int) -> void:
	for i: int in range(ticks): sim.step()

func same(a: Variant, b: Variant) -> bool:
	return JSON.stringify(a.serialize()) == JSON.stringify(b.serialize())

func reject(sim: Variant, command: Dictionary, title: String) -> void:
	var before: Dictionary = sim.serialize()
	check(not sim.apply_command(command).ok and sim.serialize() == before,title)

func _initialize() -> void:
	var sim: Variant = fresh()
	check(sim.state.citizens.size() == 8 and sim.state.coins == 1000 and sim.definitions.resources.size() == 16,"Inicio y 16 recursos")
	check(sim.width() == 128 and sim.state.terrain.size() == 16384,"Provincia: 10,24 veces la superficie original")
	check(sim.state.terrain == fresh().state.terrain,"Geografía reproducible")
	check(sim.state.terrain[23*128+45] == "water" and sim.state.terrain[54*128+50] == "water" and sim.state.terrain[80*128+50] == "water" and sim.state.terrain[49*128+22] == "forest" and sim.state.terrain[78*128+19] == "forest","Tres rías e islas separadas del continente")
	for terrain: String in ["fertile","forest","rock","clay","ore"]: check(sim.state.terrain.has(terrain),"Territorio: " + terrain)
	check(not Paths.neighbors(127,128).has(128) and Paths.neighbors(128,128).has(256),"Vecindad sin salto entre filas")
	check(Validation.check(sim.serialize(),sim.definitions).is_empty(),"Guardado inicial válido")
	reject(sim,{"type":"build","kind":"house","x":69,"z":54},"Solapamiento sin cobro ni secuencia")
	var coins: int = sim.state.coins
	check(sim.apply_command({"type":"build","kind":"house","x":69,"z":50}).ok and sim.state.coins == coins-30 and sim.state.inventory.wood == 132,"Construcción y cobro único")
	reject(sim,{"type":"road","cells":[53*128+69,54*128+69]},"Tramo inválido atómico")
	coins = sim.state.coins
	check(sim.apply_command({"type":"road","cells":[53*128+69,53*128+70]}).ok and sim.state.coins == coins,"Caminos existentes gratuitos")
	reject(sim,{"type":"demolish","cell":54*128+69},"Vivienda ocupada protegida")
	reject(sim,{"type":"demolish","cell":54*128+65},"Almacén protegido")
	reject(sim,{"type":"build","kind":"dock","x":80,"z":40},"Muelle exige costa")
	reject(sim,{"type":"build","kind":"quarry","x":69,"z":58},"Cantera exige granito cercano")
	reject(sim,{"type":"build","kind":"vineyard","x":69,"z":58},"Viñedo exige suelo fértil")
	check(sim.apply_command({"type":"build","kind":"house","x":119,"z":117}).ok,"Construir en el extremo ampliado del mapa")
	sim.state.inventory.stone = 0
	reject(sim,{"type":"build","kind":"clinic","x":80,"z":54},"Coste de granito atómico")
	check(Economy.recipe_error(sim,sim.definitions.buildings.smith) == "Falta hierro","Herrería exige insumos")

	sim = fresh()
	Startup.build_economy(sim)
	check(sim.state.voyages.size() == 1 and sim.state.inventory.salt == 0,"Sal importada reservada, no instantánea")
	check(sim.state.voyages[0].path.all(func(c: int) -> bool: return sim.state.terrain[c] == "water") and sim.state.voyages[0].path[-1]%128 == 0,"Nave con ruta continua hasta el Atlántico")
	check(sim.state.citizens.all(func(c: Dictionary) -> bool: return c.job > 0),"Ocho trabajadores en la economía inicial")
	for command: Dictionary in [
		{"type":"trade","dock":9,"port":"porto","direction":"buy","resource":"salt","quantity":-1},
		{"type":"trade","dock":9,"port":"porto","direction":"buy","resource":"salt","quantity":1.5},
		{"type":"trade","dock":9,"port":"porto","direction":"buy","resource":"salt","quantity":61},
		{"type":"trade","dock":1,"port":"porto","direction":"buy","resource":"salt","quantity":1},
		{"type":"trade","dock":9,"port":"porto","direction":"buy","resource":"fish","quantity":1},
		{"type":"trade","dock":9,"port":"porto","direction":"buy","resource":"salt","quantity":1},
		{"type":"demolish","cell":57*128+60}
	]: reject(sim,command,"Orden comercial inválida sin efectos")
	advance(sim,24)
	check(sim.building(5).produced == 0,"Sin producción antes de la jornada")
	advance(sim,20)
	check(sim.state.citizens.any(func(c: Dictionary) -> bool: return c.activity == "Al trabajo"),"Trabajadores caminan realmente")
	var restored: Variant = fresh()
	var saved: Dictionary = Definitions._integers(JSON.parse_string(JSON.stringify(sim.serialize())))
	check(restored.restore(saved).ok,"Guardar y cargar con nave en tránsito")
	advance(sim,556)
	advance(restored,556)
	check(same(sim,restored),"Continuación determinista con entrega marítima")
	check(sim.state.trade_completed == 1 and sim.state.inventory.salt == 30,"Entrega exacta al cumplir dos días")
	advance(sim,600)
	check(sim.building(5).produced > 0 and sim.building(7).produced > 0 and sim.state.inventory.salted_fish >= 10,"Integración: cultivar, pescar, importar sal y salar")
	coins = sim.state.coins
	var stock: int = sim.state.inventory.salted_fish
	check(sim.apply_command({"type":"trade","dock":9,"port":"porto","direction":"sell","resource":"salted_fish","quantity":10}).ok and sim.state.coins == coins-8 and sim.state.inventory.salted_fish == stock-10 and sim.state.exported == 0,"Exportación: carga y flete al salir, ingreso diferido")
	advance(sim,600)
	check(sim.state.exported == 10 and sim.state.coins == coins-8+60+16,"Cobro exacto de exportación y dos días de impuestos")
	check(sim.state.milestones.has("Diez unidades exportadas"),"Objetivo de comercio cumplido por entregas")
	check(sim.apply_command({"type":"build","kind":"house","x":69,"z":50}).ok,"Expansión de viviendas")

	var clone: Variant = fresh()
	var clone2: Variant = fresh()
	var runner := Runner.new()
	runner.advance(clone,1)
	check(clone.state.tick == 0,"Pausa real")
	runner.speed = 1
	for i: int in range(400): runner.advance(clone,0.05)
	runner.speed = 4
	for i: int in range(100): runner.advance(clone2,0.05)
	check(same(clone,clone2),"Mismos ticks a x1 y x4")
	sim = fresh()
	Startup.build_economy(sim)
	advance(sim,35)
	var worker: Dictionary = sim.state.citizens[0]
	var cell: int = worker.cell
	var removed: Array = []
	for next: int in Paths.neighbors(cell,128):
		if sim.roads.has(next):
			sim.apply_command({"type":"demolish","cell":next})
			removed.append(next)
	advance(sim,8)
	check(worker.cell == cell and worker.activity == "Sin ruta","Corte de camino sin teletransporte")
	for next: int in removed: sim.apply_command({"type":"road","cells":[next]})
	advance(sim,30)
	check(worker.activity != "Sin ruta","Ruta recuperada al reconstruir caminos")

	sim = fresh()
	Startup.build_economy(sim)
	sim.apply_command({"type":"demolish","cell":59*128+60})
	advance(sim,600)
	check(sim.state.voyages.size() == 1 and sim.state.inventory.salt == 0 and sim.state.voyages[0].status == "Esperando camino al almacén","Carga espera si el muelle pierde acceso terrestre")
	check(Validation.check(sim.serialize(),sim.definitions).is_empty(),"Guardado válido con entrega pendiente")
	sim.apply_command({"type":"road","cells":[59*128+60]})
	advance(sim,1)
	check(sim.state.voyages.is_empty() and sim.state.inventory.salt == 30,"Reconexión descarga una sola vez")
	check(sim.apply_command({"type":"route","repeat":true,"dock":9,"port":"porto","direction":"buy","resource":"salt","quantity":10}).ok,"Crear ruta recurrente")
	advance(sim,1500)
	check(sim.state.trade_completed >= 3 and sim.state.voyages.size() == 1,"Ruta repite automáticamente después de regresar")
	check(sim.apply_command({"type":"route","repeat":false,"dock":9}).ok and sim.state.trade_routes.is_empty() and sim.state.voyages.size() == 1,"Detener repetición conserva carga en tránsito")
	advance(sim,600)
	sim.state.trade_volume["porto:buy:salt"] = 180
	reject(sim,{"type":"trade","dock":9,"port":"porto","direction":"buy","resource":"salt","quantity":1},"Cupo de puerto limitado")
	sim.state.tick = 2999
	advance(sim,1)
	check(sim.state.trade_volume.is_empty(),"Cupos se renuevan cada diez días")
	for key: String in sim.state.inventory: sim.state.inventory[key] = 0
	sim.state.inventory.wood = 1195
	reject(sim,{"type":"trade","dock":9,"port":"porto","direction":"buy","resource":"salt","quantity":10},"Importación no desborda almacén")
	sim.state.inventory.wood = 1180
	sim.apply_command({"type":"trade","dock":9,"port":"porto","direction":"buy","resource":"salt","quantity":20})
	check(Economy.recipe_error(sim,sim.definitions.buildings.lumber) == "Almacén lleno","Producción respeta espacio reservado para barcos")
	var invalid: Dictionary = sim.serialize()
	invalid.voyages[0].path[0] = 55*128+70
	var before: Dictionary = sim.serialize()
	check(not sim.restore(invalid).ok and sim.serialize() == before,"Guardado con nave en tierra rechazado sin mutar partida")
	invalid = sim.serialize()
	invalid.citizens[0].home = 99999
	check(not sim.restore(invalid).ok,"Referencias de ciudadanos validadas")
	invalid = sim.serialize()
	invalid.schema = 1
	check(not sim.restore(invalid).ok,"Guardado de primera versión no se interpreta como v2")

	test_growth_and_deposits()
	test_services()
	test_chains()
	sim = fresh()
	Startup.build_economy(sim)
	var error: String = ""
	for i: int in range(10000):
		sim.step()
		if i%100 == 0:
			error = Validation.check(sim.serialize(),sim.definitions)
			if not error.is_empty(): break
	check(error.is_empty(),"10.000 ticks: inventario, rutas, cargas y referencias: " + error)
	print("RESULTADO: %d correctas / %d fallidas" % [passed,failed])
	quit(1 if failed > 0 else 0)

func test_services() -> void:
	var sim: Variant = fresh()
	Startup.road(sim,Vector2i(69,52),Vector2i(77,52))
	Startup.road(sim,Vector2i(77,53),Vector2i(77,57))
	Startup.build(sim,"market",69,50)
	Startup.build(sim,"clinic",72,50)
	Startup.build(sim,"chapel",74,50)
	Startup.build(sim,"watch",78,52)
	Startup.build(sim,"school",78,55)
	check(sim.building(2).services.values().all(func(value: bool) -> bool: return value),"Seis servicios llegan a hogares por caminos y personal")
	var coins: int = sim.state.coins
	advance(sim,300)
	check(sim.state.coins == coins-12+8,"Mantenimiento diario e impuestos exactos")
	advance(sim,600)
	check(sim.building(2).level == 2 and sim.building(3).level == 2,"Tres días de comida, agua, mercado, salud y culto mejoran viviendas")
	for resource: String in ["pottery","cloth","wine"]: sim.state.inventory[resource] = 2
	advance(sim,300)
	check(sim.building(2).level == 3 and sim.state.inventory.cloth == 0 and sim.state.inventory.wine == 0 and sim.state.inventory.pottery == 0,"Viviendas mercantiles consumen bienes y exigen todos los servicios")
	advance(sim,300)
	check(sim.building(2).level == 2,"Falta de bienes reduce nivel de vivienda")
	sim.apply_command({"type":"activity","id":6})
	check(not sim.building(2).services.health,"Hospital desactivado pierde cobertura")
	advance(sim,300)
	check(sim.building(2).level == 1,"Pérdida de servicio afecta evolución")
	sim.state.coins = 0
	advance(sim,300)
	check(not sim.building(5).service_active and sim.building(2).water,"Sin presupuesto cierran servicios de pago; pozo continúa")
	check(Validation.check(sim.serialize(),sim.definitions).is_empty(),"Guardado válido con servicios y evolución")

func test_chains() -> void:
	# Isolated recipe tests use actual workers and ticks; starting materials are explicit fixtures.
	for kind: String in ["mill","bakery","winery","potter","smith","weaver"]:
		var sim: Variant = fresh()
		for resource: String in sim.definitions.buildings[kind].inputs: sim.state.inventory[resource] = 40
		var id: int = Startup.build(sim,kind,69,51)
		var before: Dictionary = sim.state.inventory.duplicate()
		advance(sim,249)
		var d: Dictionary = sim.definitions.buildings[kind]
		var produced: bool = sim.building(id).produced > 0
		for resource: String in d.outputs: produced = produced and sim.state.inventory[resource] > before[resource]
		for resource: String in d.inputs: produced = produced and sim.state.inventory[resource] < before[resource]
		check(produced,"Cadena con trabajo e insumos reales: " + d.label)
	var sim: Variant = fresh()
	var id: int = Startup.build(sim,"depot",69,51)
	check(Economy.capacity(sim) == 2000,"Depósito conectado amplía capacidad")
	sim.state.inventory.wood = 1300
	reject(sim,{"type":"demolish","cell":51*128+69},"No se destruye almacenamiento ocupado")
	sim.apply_command({"type":"demolish","cell":53*128+69})
	sim.apply_command({"type":"demolish","cell":53*128+70})
	check(not sim.building(id).connected and Economy.capacity(sim) == 1200,"Depósito desconectado deja de aportar capacidad operativa")
	reject(sim,{"type":"demolish","cell":51*128+69},"Depósito desconectado tampoco pierde existencias por demolición")
	check(Validation.check(sim.serialize(),sim.definitions).is_empty(),"Exceso temporal al cortar depósito se guarda sin perder bienes")

func test_growth_and_deposits() -> void:
	var sim: Variant = fresh()
	Startup.build_economy(sim)
	Startup.build(sim,"house",69,50)
	Startup.build(sim,"mill",71,50)
	Startup.build(sim,"market",74,50)
	Startup.road(sim,Vector2i(69,52),Vector2i(77,52))
	advance(sim,1200)
	check(sim.state.citizens.size() >= 10,"Inmigración con vivienda, agua, comida y nuevos empleos")
	check(sim.building(11).produced > 0,"Vecinos inmigrantes se incorporan a la cadena del molino")
	check(Validation.check(sim.serialize(),sim.definitions).is_empty(),"Expansión desde presupuesto inicial mantiene invariantes")
	for fixture: Array in [["quarry",83,54,Vector2i(84,53)],["claypit",74,65,Vector2i(74,64)],["mine",87,66,Vector2i(87,65)],["sheep",78,55,Vector2i(77,55)],["vineyard",74,41,Vector2i(77,41)]]:
		sim = fresh()
		var id: int = Startup.build(sim,fixture[0],fixture[1],fixture[2])
		if fixture[0] == "claypit":
			Startup.road(sim,Vector2i(77,53),Vector2i(77,64))
			Startup.road(sim,Vector2i(77,64),fixture[3])
		else: Startup.road(sim,Vector2i(77,53),fixture[3])
		advance(sim,600)
		check(sim.building(id).produced > 0,"Extracción/cultivo con terreno real: " + fixture[0])
		check(Validation.check(sim.serialize(),sim.definitions).is_empty(),"Estado válido para " + fixture[0])
	sim = fresh()
	sim.state.inventory.grain = 0
	sim.state.inventory.bread = 0
	sim.state.inventory.fish = 16
	sim.state.inventory.salt = 2
	check(Economy.recipe_error(sim,sim.definitions.buildings.saltery) == "Reserva alimentaria protegida","Salazón respeta dos días de comida")
