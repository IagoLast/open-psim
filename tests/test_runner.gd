extends SceneTree
const Simulation = preload("res://sim/simulation.gd")
const Definitions = preload("res://adapters/definitions.gd")
const Startup = preload("res://tests/scenarios/startup.gd")
const Validation = preload("res://sim/validation.gd")
const Runner = preload("res://adapters/simulation_runner.gd")
var passed: int = 0
var failed: int = 0

func fresh() -> RefCounted:
	var sim := Simulation.new()
	sim.create(1530, Definitions.load_data())
	return sim

func check(condition: bool, title: String) -> void:
	if condition:
		passed += 1
		print("OK  ", title)
	else:
		failed += 1
		printerr("FAIL ", title)

func same(a: Variant, b: Variant) -> bool:
	return JSON.stringify(a.serialize()) == JSON.stringify(b.serialize())

func _initialize() -> void:
	var sim: Variant = fresh()
	check(sim.state.citizens.size() == 8 and sim.state.coins == 350, "Estado inicial")
	var before: Dictionary = sim.serialize()
	check(not sim.apply_command({"type":"build","kind":"house","x":19,"z":20}).ok and sim.serialize() == before, "Solapamiento sin cobro ni secuencia")
	check(sim.apply_command({"type":"build","kind":"house","x":20,"z":17}).ok and sim.state.coins == 320 and sim.state.inventory.wood == 52, "Construcción y cobro único")
	before = sim.serialize()
	check(not sim.apply_command({"type":"road","cells":[778,779,819]}).ok and sim.serialize() == before, "Tramo inválido atómico")
	check(sim.apply_command({"type":"road","cells":[778,779]}).ok and sim.state.coins == 320, "Caminos existentes gratuitos")
	check(not sim.apply_command({"type":"demolish","cell":819}).ok, "Vivienda ocupada protegida")
	check(not sim.apply_command({"type":"demolish","cell":827}).ok, "Almacén protegido")
	for order: Dictionary in [
		{"type":"trade","direction":"buy","resource":"fish","quantity":1},
		{"type":"trade","direction":"sell","resource":"salt","quantity":1},
		{"type":"trade","direction":"buy","resource":"salt","quantity":-1},
		{"type":"trade","direction":"buy","resource":"salt","quantity":1.5},
		{"type":"trade","direction":"buy","resource":"wood","quantity":500}
	]:
		before = sim.serialize()
		check(not sim.apply_command(order).ok and before == sim.serialize(), "Comercio inválido sin cambios: " + str(order))
	check(sim.apply_command({"type":"trade","direction":"buy","resource":"salt","quantity":10}).ok and sim.state.inventory.salt == 10 and sim.state.coins == 300, "Importación exacta")
	sim.state.inventory.wood = 442
	before = sim.serialize()
	check(not sim.apply_command({"type":"trade","direction":"buy","resource":"salt","quantity":1}).ok and before == sim.serialize(), "Capacidad comercial")
	sim = fresh()
	Startup.build_economy(sim)
	var jobs: int = 0
	for citizen: Dictionary in sim.state.citizens:
		if citizen.job > 0: jobs += 1
	check(jobs == 8, "Ocho trabajadores asignados a cuatro actividades")
	for i: int in range(24): sim.step()
	check(sim.state.inventory.grain == 32 and sim.building(5).produced == 0, "Ausencia sin producción")
	var walking: bool = false
	for i: int in range(90):
		sim.step()
		for citizen: Dictionary in sim.state.citizens:
			if citizen.activity == "Al trabajo": walking = true
	check(walking, "Desplazamiento real al trabajo")
	var restored: Variant = fresh()
	var saved: Dictionary = Definitions._integers(JSON.parse_string(JSON.stringify(sim.serialize())))
	check(restored.restore(saved).ok, "Restauración a media jornada")
	for i: int in range(900):
		sim.step()
		restored.step()
	check(same(sim, restored), "Cargar y continuar equivale al original")
	check(sim.building(5).produced > 0 and sim.building(7).produced > 0 and sim.state.inventory.salted_fish >= 10, "Integración: producir cereal, pescar y salar")
	check(sim.apply_command({"type":"trade","direction":"sell","resource":"salted_fish","quantity":10}).ok, "Integración: exportar diez")
	check(sim.apply_command({"type":"build","kind":"house","x":20,"z":17}).ok, "Integración: ampliar viviendas")
	var clone: Variant = fresh()
	Startup.build_economy(clone)
	var clone2: Variant = fresh()
	Startup.build_economy(clone2)
	var runner := Runner.new()
	runner.advance(clone, 1.0)
	check(clone.state.tick == 0, "Pausa real")
	runner.speed = 1
	for i: int in range(400): runner.advance(clone, 0.05)
	var fast := Runner.new()
	fast.speed = 4
	for i: int in range(100): fast.advance(clone2, 0.05)
	check(same(clone, clone2), "Mismos ticks a x1 y x4; semilla reproducible")
	var old_job: int = clone.state.citizens[0].job
	check(clone.apply_command({"type":"activity","id":old_job}).ok, "Desactivar establecimiento")
	check(clone.building(old_job).assigned == 0, "Desactivación libera puestos")
	# Isolate a walking worker by cutting both neighboring road cells.
	sim = fresh()
	Startup.build_economy(sim)
	for i: int in range(29): sim.step()
	var worker: Dictionary = sim.state.citizens[0]
	var current: int = worker.cell
	print("Route cut fixture: ", worker)
	var removed: Array = []
	for cell: int in preload("res://sim/pathfinding.gd").neighbors(current):
		if sim.roads.has(cell):
			sim.apply_command({"type":"demolish","cell":cell})
			removed.append(cell)
	for i: int in range(8): sim.step()
	check(worker.cell == current and worker.activity == "Sin ruta", "Corte de ruta: espera sin teletransporte")
	for cell: int in removed: sim.apply_command({"type":"road","cells":[cell]})
	for i: int in range(30): sim.step()
	check(worker.activity != "Sin ruta", "Ruta recuperada al restaurar caminos")
	var invalid: Dictionary = sim.serialize()
	invalid.citizens[0].home = 999
	before = sim.serialize()
	check(not sim.restore(invalid).ok and sim.serialize() == before, "Guardado corrupto conserva partida")
	sim = fresh()
	var food: int = sim.state.inventory.grain + sim.state.inventory.fish
	for i: int in range(300): sim.step()
	check(sim.state.inventory.grain + sim.state.inventory.fish == food - 8, "Una comida por ciudadano y día")
	check(sim.state.coins == 358, "Impuesto diario por comida y agua")
	sim.apply_command({"type":"demolish","cell":783})
	check(not sim.building(2).water, "Agua por caminos, no por radio")
	sim = fresh()
	Startup.build_economy(sim)
	var recipe: Dictionary = sim.definitions.buildings.saltery
	sim.state.inventory.salt = 0
	check(preload("res://sim/systems/economy.gd").recipe_error(sim, recipe) == "Falta sal", "Receta bloqueada por sal")
	sim.state.inventory.salt = 10
	sim.state.inventory.grain = 0
	sim.state.inventory.fish = 16
	check(preload("res://sim/systems/economy.gd").recipe_error(sim, recipe) == "Reserva alimentaria protegida", "Protección alimentaria")
	sim.state.inventory.grain = 32
	var invariant: String = ""
	for i: int in range(10000):
		sim.step()
		if i % 100 == 0:
			invariant = Validation.check(sim.serialize(), sim.definitions)
			if not invariant.is_empty(): break
	check(invariant.is_empty(), "10.000 ticks: referencias, puestos, inventario, rutas y límites: " + invariant)
	print("RESULTADO: %d correctas / %d fallidas" % [passed, failed])
	quit(1 if failed > 0 else 0)
