extends RefCounted
const Definitions = preload("res://adapters/definitions.gd")
const SAVE_PATH: String = "user://pontevedra-ria-v1.json"

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
	if file.get_length() > 4000000: return sim.result("Guardado demasiado grande")
	var data: Variant = JSON.parse_string(file.get_as_text())
	if not data is Dictionary: return sim.result("Archivo corrupto")
	return sim.restore(Definitions._integers(data))
