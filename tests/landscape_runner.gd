extends SceneTree
## Scenery must clear playable footprints and return after demolition or restore.
const Main = preload("res://presentation/main.gd")
const Map = preload("res://sim/world_map.gd")
var game: Node3D
var failures: int = 0

func _initialize() -> void:
	# The dummy headless renderer does not retain MultiMesh instance transforms.
	if DisplayServer.get_name() == "headless":
		printerr("Esta prueba lee las instancias dibujadas: ejecuta sin --headless.")
		quit(2)
		return
	call_deferred("run")

func check(ok: bool, title: String) -> void:
	print("LANDSCAPE OK " if ok else "LANDSCAPE FAIL ",title)
	if not ok: failures += 1

func visible_at(cell: int) -> int:
	var count: int = 0
	for batch: MultiMeshInstance3D in game.world.landscape.batches.values():
		var multi: MultiMesh = batch.multimesh
		for i: int in range(multi.visible_instance_count):
			var position: Vector3 = multi.get_instance_transform(i).origin
			if int(floor(position.z))*Map.SIZE+int(floor(position.x)) == cell: count += 1
	return count

func visible_signature() -> int:
	var result: Array = []
	var keys: Array = game.world.landscape.batches.keys()
	keys.sort()
	for key: String in keys:
		var multi: MultiMesh = game.world.landscape.batches[key].multimesh
		result.append(key)
		for i: int in range(multi.visible_instance_count):
			result.append(multi.get_instance_transform(i))
			result.append(multi.get_instance_color(i))
	return hash(result)

func run() -> void:
	game = Main.new()
	root.add_child(game)
	game.set_process(false)
	await process_frame
	var cell: int = -1
	for key: String in game.world.landscape.placements:
		if not key.begins_with("tree_"): continue
		for placement: Dictionary in game.world.landscape.placements[key]:
			var candidate: int = placement.cell
			var order: Dictionary = {"type":"build","kind":"house","x":candidate%Map.SIZE,"z":candidate/Map.SIZE}
			if visible_at(candidate) > 0 and game.sim.validate_command(order).ok:
				cell = candidate
				break
		if cell >= 0: break
	check(cell >= 0,"Hay bosque edificable para comprobar el desbroce")
	if cell >= 0:
		var before: int = visible_at(cell)
		var original: int = visible_signature()
		var saved: Dictionary = game.sim.serialize()
		check(game.sim.apply_command({"type":"road","cells":[cell]}).ok,"Camino sobre una casilla arbolada")
		game.refresh()
		check(visible_at(cell) == 0,"El camino retira árboles y sotobosque")
		check(game.sim.apply_command({"type":"demolish","cell":cell}).ok,"Demolición del camino")
		game.refresh()
		check(visible_at(cell) == before,"La vegetación reaparece al demoler")
		check(visible_signature() == original,"Demoler conserva modelos, transforms y colores exactos")
		check(game.sim.apply_command({"type":"build","kind":"house","x":cell%Map.SIZE,"z":cell/Map.SIZE}).ok,"Vivienda sobre terreno con vegetación")
		game.refresh()
		for offset: int in [0,1,Map.SIZE,Map.SIZE+1]:
			check(visible_at(cell+offset) == 0,"Huella de vivienda despejada: %d" % offset)
		check(game.sim.restore(saved).ok,"Restauración de la partida anterior a la obra")
		game.refresh()
		check(visible_at(cell) == before,"Restaurar repone el paisaje original")
		check(visible_signature() == original,"Guardar/cargar conserva el catálogo elegido y sus transforms")
	var crossing: Array = []
	for z: int in range(Map.BURGO_BRIDGE.position.y,Map.BURGO_BRIDGE.end.y): crossing.append(z*Map.SIZE+Map.BURGO_BRIDGE.position.x)
	check(game.sim.apply_command({"type":"road","cells":crossing}).ok,"El puente conserva todas sus casillas transitables")
	game.refresh()
	check(game.world.landscape.get_node("BurgoBridge") != null,"Puente Blender presente al trazar caminos")
	check(game.world.landscape.get_node("Estuary").position.y < -1.0,"Lámina de agua por debajo de los arcos")
	game.world.camera.size = 145
	game.world.update_camera()
	check(game.world.landscape.overview,"Vista general reduce el detalle pequeño")
	game.world.camera.size = 30
	game.world.update_camera()
	check(not game.world.landscape.overview,"El detalle vuelve al acercar la cámara")
	var saved_world: Dictionary = game.sim.serialize()
	var original_world: int = visible_signature()
	var used: Dictionary = {}
	var shared: bool = true
	var rocks_still: bool = true
	for key: String in game.world.landscape.batches:
		var kind: String = key.get_slice(":",0)
		var mesh: Mesh = game.world.landscape.batches[key].multimesh.mesh
		if used.has(kind) and used[kind] != mesh: shared = false
		used[kind] = mesh
		if kind.begins_with("rock_cluster") and mesh.surface_get_material(0).get_shader_parameter("wind_strength") != 0.0: rocks_still = false
	var catalog_limit: int = 3 # grass, flowers, reeds
	for family: String in ["tree_oak","tree_cypress","tree_pine","rock_cluster","gorse"]:
		catalog_limit += game.world.landscape.Variants.options(family).size()
	check(shared and used.size() <= catalog_limit,"Catálogo finito: mallas compartidas entre zonas, no por ejemplar")
	check(rocks_still,"Ninguna variante de granito recibe brisa")
	var all_variants: bool = true
	for family: String in ["tree_oak","tree_cypress","tree_pine","rock_cluster","gorse"]:
		for kind: String in game.world.landscape.Variants.options(family):
			if not used.has(kind): all_variants = false
	check(all_variants,"Todos los árboles, rocas y tojos del catálogo aparecen en juego")
	game.sim.create(1531,game.sim.definitions)
	game.refresh()
	check(game.world.landscape.world_seed == 1531 and visible_signature() != original_world,"Otra semilla reconstruye su propio paisaje")
	check(game.sim.restore(saved_world).ok,"Cargar la semilla original tras otra partida")
	game.refresh()
	check(visible_signature() == original_world,"Reconstruir desde la partida guardada reproduce cada instancia")
	check(game.sim.serialize().rng_state == saved_world.rng_state,"Las variantes no consumen el RNG de simulación")
	print("LANDSCAPE RESULTADO: ",failures," fallos")
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
