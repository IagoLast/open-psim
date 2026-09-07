extends SceneTree
const Simulation = preload("res://sim/simulation.gd")
const Definitions = preload("res://adapters/definitions.gd")
const Presets = preload("res://sim/city_presets.gd")
const DeveloperTools = preload("res://sim/developer_tools.gd")
const Validation = preload("res://sim/validation.gd")
const Save = preload("res://adapters/save_service.gd")
const Startup = preload("res://tests/scenarios/startup.gd")
var failures: int = 0

func check(ok: bool, title: String) -> void:
	print("DEV OK " if ok else "DEV FAIL ",title)
	if not ok: failures += 1

func _initialize() -> void:
	var sim := Simulation.new()
	sim.create(1530,Definitions.load_data())
	var dev := DeveloperTools.new()
	var initial: Dictionary = sim.serialize()
	for command: String in ["money -1","money 999999999999999999999999999999","resource wood -2","resource nope 2","resource grain 99999999","city bogus","citizens -1","repair extra","unknown"]:
		check(not dev.execute(sim,command).ok and sim.serialize() == initial,"Rechazo sin cambios: " + command)
	check(dev.execute(sim,"money infinite").ok and sim.state.coins == dev.MONEY_RESERVE,"Activar dinero infinito")
	sim.state.coins -= 1200
	dev.enforce(sim)
	check(sim.state.coins == dev.MONEY_RESERVE,"Reposición tras gastos")
	dev.execute(sim,"money off")
	check(sim.state.coins == initial.coins and not dev.infinite_money,"Desactivar restaura presupuesto")
	dev.execute(sim,"stock")
	check(sim.Economy.can_store(sim,sim.state.inventory) and Validation.check(sim.serialize(),sim.definitions).is_empty(),"Recursos respetan capacidad y guardado")
	check(not Presets.generate(sim,"unknown").ok,"Preset desconocido rechazado")
	for preset: String in ["developing","advanced"]:
		var started: int = Time.get_ticks_msec()
		var result: Dictionary = Presets.generate(sim,preset)
		check(result.ok,"Generar %s: %s (%d ms)" % [preset,result.message,Time.get_ticks_msec()-started])
		if not result.ok: continue
		check(sim.state.citizens.size() == (48 if preset == "advanced" else 24),"Población establecida " + preset)
		check(sim.state.buildings.all(func(b: Dictionary) -> bool: return b.connected and sim.terrain_error(b.type,b.x,b.z,b.rotation).is_empty()),"Parcelas legales y conectadas " + preset)
		check(sim.state.citizens.all(func(c: Dictionary) -> bool: return c.job > 0 and c.water),"Agua y empleo para todos " + preset)
		var homes: Array = sim.state.buildings.filter(func(b: Dictionary) -> bool: return b.type == "house")
		check(homes.any(func(b: Dictionary) -> bool: return b.level >= 2),"Viviendas evolucionadas " + preset)
		if preset == "advanced":
			check(sim.definitions.buildings.keys().all(func(kind: String) -> bool: return sim.state.buildings.any(func(b: Dictionary) -> bool: return b.type == kind)),"Ciudad avanzada muestra todos los edificios")
		var saved: Dictionary = Definitions._integers(JSON.parse_string(JSON.stringify(sim.serialize())))
		var clone := Simulation.new()
		clone.create(1530,sim.definitions)
		check(clone.restore(saved).ok and clone.serialize() == sim.serialize(),"Guardado/carga exactos " + preset)
		for tick: int in range(1500):
			sim.step()
			if tick < 10: clone.step()
			if tick == 9: check(sim.serialize() == clone.serialize(),"Continuación determinista " + preset)
		check(Validation.check(sim.serialize(),sim.definitions).is_empty(),"Estado válido tras cinco días " + preset)
		check(sim.state.citizens.size() >= (48 if preset == "advanced" else 24) and sim.state.citizens.all(func(c: Dictionary) -> bool: return c.fed and c.water),"Ciudad habitable tras cinco días " + preset)
		check(sim.state.buildings.any(func(b: Dictionary) -> bool: return b.produced > 0),"Producción real " + preset)
		dev.execute(sim,"repair")
		check(sim.state.buildings.all(func(b: Dictionary) -> bool: return b.condition == 100 and b.burn_days == 0),"Reparación de desarrollo")
	test_legacy_convents()
	print("DEVELOPER: ",failures," failures")
	quit(1 if failures else 0)

func test_legacy_convents() -> void:
	var legacy := Simulation.new()
	var definitions: Dictionary = Definitions.load_data()
	definitions.buildings.convent.footprint = [6,5]
	legacy.create(1530,definitions)
	legacy.state.erase("building_layout")
	legacy.state.coins = 5000
	legacy.state.inventory.wood = 300
	legacy.state.inventory.stone = 200
	Startup.build(legacy,"warehouse",441,128)
	var home: int = Startup.build(legacy,"house",441,133)
	var first: int = Startup.build(legacy,"convent",441,136,1)
	var neighbor: int = Startup.build(legacy,"house",446,136)
	var second: int = Startup.build(legacy,"convent",441,150)
	legacy.building(first).condition = 70
	legacy.building(first).fire_risk = 10
	legacy.building(second).active = false
	for i: int in range(2): legacy._add_citizen(home,legacy.building(home).access)
	legacy.Citizens.assign_jobs(legacy)
	var saved: Dictionary = Definitions._integers(JSON.parse_string(JSON.stringify(legacy.serialize())))
	var sim := Simulation.new()
	sim.create(1530,Definitions.load_data())
	var loaded: Dictionary = Save.restore_game(sim,saved)
	check(loaded.ok,"Migrar dos conventos antiguos junto a viviendas: " + loaded.message)
	if not loaded.ok: return
	check(sim.state.coins == saved.coins and sim.state.inventory == saved.inventory,"Ampliación de guardado conserva presupuesto y existencias")
	check(sim.state.buildings.size() == saved.buildings.size() and sim.state.next_building == saved.next_building,"Migración conserva edificios e identificadores")
	check(sim.building(neighbor).x == 446 and sim.building(neighbor).z == 136 and sim.building(first).rotation == 1,"No mueve vecinos y conserva el giro del convento")
	check(sim.building(first).condition == 70 and not sim.building(second).active,"Migración conserva conservación y actividad")
	check(sim.state.citizens.size() == 2 and sim.state.citizens.all(func(c: Dictionary) -> bool: return c.job == first),"Migración conserva habitantes y empleos religiosos")
	check(sim.dimensions(sim.building(first)) == Vector2i(8,10) and sim.building(first).connected and Validation.check(sim.serialize(),sim.definitions).is_empty(),"Convento ampliado conectado, sin solapamientos y guardable")
	check(saved == legacy.serialize(),"Migración no modifica los datos originales")
	var clone := Simulation.new()
	clone.create(1530,Definitions.load_data())
	check(Save.restore_game(clone,sim.serialize()).ok and clone.serialize() == sim.serialize(),"Guardado actualizado no vuelve a mover edificios al cargar")
	var corrupt: Dictionary = saved.duplicate(true)
	corrupt.buildings[2].z = 128
	var before: Dictionary = clone.serialize()
	check(not Save.restore_game(clone,corrupt).ok and clone.serialize() == before,"Guardado antiguo corrupto rechazado sin tocar la ciudad actual")
