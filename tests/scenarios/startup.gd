extends RefCounted

static func build(sim: Variant, kind: String, x: int, z: int) -> int:
	var result: Dictionary = sim.apply_command({"type":"build","kind":kind,"x":x,"z":z})
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
	assert(result.ok,"Camino %s → %s: %s" % [from,to,result.message])

static func build_economy(sim: Variant) -> void:
	build(sim,"farm",103,23)
	build(sim,"lumber",108,36)
	build(sim,"fishery",93,33)
	build(sim,"saltery",99,35)
	road(sim,Vector2i(107,31),Vector2i(107,38))
	road(sim,Vector2i(98,31),Vector2i(98,38))
	road(sim,Vector2i(98,35),Vector2i(93,35))
	build(sim,"dock",90,35)
	road(sim,Vector2i(98,38),Vector2i(90,38))
	road(sim,Vector2i(90,38),Vector2i(90,37))
	var result: Dictionary = sim.apply_command({"type":"trade","dock":9,"port":"porto","direction":"buy","resource":"salt","quantity":30})
	assert(result.ok,result.message)
