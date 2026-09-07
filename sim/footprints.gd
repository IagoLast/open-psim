extends RefCounted
## One geometry contract for commands, simulation, rendering and save validation.
static func dimensions(definition: Dictionary, rotation: int = 0) -> Vector2i:
	var sides: Array = definition.footprint
	return Vector2i(sides[1],sides[0]) if rotation % 2 else Vector2i(sides[0],sides[1])

static func cells(definition: Dictionary, x: int, z: int, width: int, rotation: int = 0) -> Array:
	var result: Array = []
	var size: Vector2i = dimensions(definition,rotation)
	for dz: int in range(size.y):
		for dx: int in range(size.x): result.append((z+dz)*width+x+dx)
	return result

static func side(item: Dictionary, size: Vector2i, cell: int, width: int) -> int:
	var p := Vector2i(cell%width,cell/width)
	if p.y < item.z: return 0
	if p.x < item.x: return 1
	if p.y >= item.z+size.y: return 2
	return 3
