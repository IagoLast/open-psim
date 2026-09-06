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
	build(sim,"farm",73,45)
	build(sim,"lumber",78,58)
	build(sim,"fishery",63,55)
	build(sim,"saltery",69,57)
	road(sim,Vector2i(77,53),Vector2i(77,60))
	road(sim,Vector2i(68,53),Vector2i(68,60))
	road(sim,Vector2i(68,57),Vector2i(63,57))
	build(sim,"dock",60,57)
	road(sim,Vector2i(68,60),Vector2i(60,60))
	road(sim,Vector2i(60,60),Vector2i(60,59))
	var result: Dictionary = sim.apply_command({"type":"trade","dock":9,"port":"porto","direction":"buy","resource":"salt","quantity":30})
	assert(result.ok,result.message)
