extends RefCounted
const Definitions = preload("res://adapters/definitions.gd")
const SAVE_PATH: String = "user://pontevedra-ria-v5.json"

static func save_game(sim: Variant) -> String:
	var file := FileAccess.open(SAVE_PATH + ".tmp", FileAccess.WRITE)
	if file == null: return "No se pudo abrir el guardado"
	file.store_string(JSON.stringify(sim.serialize()))
	file.flush()
	var error: Error = file.get_error()
	file.close()
	if error != OK: return "No se pudo escribir el guardado"
	if DirAccess.rename_absolute(SAVE_PATH + ".tmp", SAVE_PATH) != OK: return "No se pudo finalizar el guardado"
	return "Partida guardada" if OS.is_userfs_persistent() else "Guardado temporal: este navegador no ofrece persistencia"

static func load_game(sim: Variant) -> Dictionary:
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null: return sim.result("No hay una partida guardada")
	if file.get_length() > 16000000: return sim.result("Guardado demasiado grande")
	var data: Variant = JSON.parse_string(file.get_as_text())
	if not data is Dictionary: return sim.result("Archivo corrupto")
	return restore_game(sim,Definitions._integers(data))

static func restore_game(sim: Variant, data: Dictionary) -> Dictionary:
	if data.get("building_layout",1) != 1: return sim.restore(data)
	# Validate the previous layout before migrating on an isolated simulation.
	# Existing buildings, stock and the save file itself must never be overwritten
	# merely to make room for the larger landmark.
	var legacy_definitions: Dictionary = sim.definitions.duplicate(true)
	legacy_definitions.buildings.convent.footprint = [6,5]
	var error: String = preload("res://sim/validation.gd").check(data,legacy_definitions)
	if not error.is_empty(): return sim.result(error)
	var source: Dictionary = data.duplicate(true)
	source.building_layout = 2
	var convents: Array = source.buildings.filter(func(b: Dictionary) -> bool: return b.type == "convent")
	if convents.is_empty(): return sim.restore(source)
	var ids: Array = convents.map(func(b: Dictionary) -> int: return b.id)
	source.buildings = source.buildings.filter(func(b: Dictionary) -> bool: return b.type != "convent")
	for citizen: Dictionary in source.citizens:
		if citizen.job in ids: citizen.job = 0
	var candidate := preload("res://sim/simulation.gd").new()
	candidate.create(source.seed,sim.definitions)
	var restored: Dictionary = candidate.restore(source)
	if not restored.ok: return restored
	candidate.state.coins = 1000000000
	for resource: String in candidate.state.inventory: candidate.state.inventory[resource] = 1000000
	var relocated: bool = false
	for former: Dictionary in convents:
		var id: int = preload("res://sim/city_presets.gd")._place(candidate,"convent",Vector2i(former.x,former.z),former.rotation)
		if id == 0: return sim.result("No hay espacio conectado para ampliar el convento; la partida actual sigue intacta")
		var placed: Dictionary = candidate.building(id)
		var x: int = placed.x
		var z: int = placed.z
		relocated = relocated or x != former.x or z != former.z
		placed.merge(former,true)
		placed.x = x
		placed.z = z
		candidate.rebuild()
	candidate.state.coins = data.coins
	candidate.state.inventory = data.inventory.duplicate(true)
	candidate.state.citizens = data.citizens.duplicate(true)
	candidate.state.next_building = data.next_building
	candidate.state.sequence = data.sequence
	# Connectivity and movement targets must be derived from the enlarged parcel.
	for citizen: Dictionary in candidate.state.citizens:
		citizen.route = []
		citizen.route_version = -1
		citizen.destination = -1
		citizen.progress = 0
	candidate.rebuild()
	candidate.alert("Convento ampliado a 10×8 y recolocado junto al barrio" if relocated else "Convento ampliado a 10×8 en su parcela")
	return sim.restore(candidate.serialize())
