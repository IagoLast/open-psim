extends RefCounted

static func build(sim: Variant, kind: String, x: int, z: int, rotation: int = 0) -> int:
	var result: Dictionary = sim.apply_command({"type":"build","kind":kind,"x":x,"z":z,"rotation":rotation})
	assert(result.ok,"%s (%d,%d): %s" % [kind,x,z,result.message])
	return sim.state.next_building-1 if result.ok else 0

static func road(sim: Variant, from: Vector2i, to: Vector2i) -> void:
	var path: Array = [from.y*sim.width()+from.x]
	var cursor: Vector2i = from
	while cursor.x != to.x:
		cursor.x += 1 if to.x > cursor.x else -1
		path.append(cursor.y*sim.width()+cursor.x)
	while cursor.y != to.y:
		cursor.y += 1 if to.y > cursor.y else -1
		path.append(cursor.y*sim.width()+cursor.x)
	var result: Dictionary = sim.apply_command({"type":"road","cells":path})
	assert(result.ok,result.message)

static func connect_building(sim: Variant, id: int) -> void:
	var item: Dictionary = sim.building(id)
	if item.connected: return
	var queue: Array = []
	var previous: Dictionary = {}
	for cell: int in sim.edges(item):
		if sim.state.terrain[cell] != "water" and not sim.occupied.has(cell):
			queue.append(cell)
			previous[cell] = -1
	var index: int = 0
	while index < queue.size():
		var cell: int = queue[index]
		index += 1
		if sim.roads.has(cell):
			var path: Array = [cell]
			while previous[path[-1]] != -1: path.append(previous[path[-1]])
			var result: Dictionary = sim.apply_command({"type":"road","cells":path})
			assert(result.ok,result.message)
			return
		for next: int in sim.Paths.neighbors(cell,sim.width()):
			if previous.has(next) or sim.occupied.has(next) or sim.state.terrain[next] == "water": continue
			previous[next] = cell
			queue.append(next)
	assert(false,"No hay conexión terrestre")

static func nearby(sim: Variant, kind: String, origin: Vector2i, rotation: int = 0) -> int:
	for radius: int in range(30):
		for z: int in range(origin.y-radius,origin.y+radius+1):
			for x: int in range(origin.x-radius,origin.x+radius+1):
				if maxi(absi(x-origin.x),absi(z-origin.y)) != radius: continue
				var command: Dictionary = {"type":"build","kind":kind,"x":x,"z":z,"rotation":rotation}
				if sim.validate_command(command).ok:
					var id: int = build(sim,kind,x,z,rotation)
					connect_building(sim,id)
					return id
	assert(false,"Sin parcela para " + kind)
	return 0

static func build_economy(sim: Variant) -> Dictionary:
	var ids: Dictionary = {}
	ids.warehouse = build(sim,"warehouse",441,128)
	ids.house = build(sim,"house",441,133)
	ids.house2 = build(sim,"house",441,136)
	ids.well = build(sim,"well",441,139)
	ids.farm = nearby(sim,"farm",Vector2i(444,112))
	ids.lumber = nearby(sim,"lumber",Vector2i(456,142))
	ids.fishery = nearby(sim,"fishery",Vector2i(438,70))
	ids.saltery = nearby(sim,"saltery",Vector2i(445,128))
	return ids
