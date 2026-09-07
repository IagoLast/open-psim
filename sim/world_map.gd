extends RefCounted
## Ría interior: Pontevedra–Combarro–Marín. Norte arriba; geografía estilizada.
const ID: String = "pontevedra-inner-ria-v5"
const SIZE: int = 512
const START: Vector2i = Vector2i(444,128)
const START_FOCUS: Vector3 = Vector3(443,0,130)
const OVERVIEW_FOCUS: Vector3 = Vector3(256,0,256)
const OVERVIEW_ZOOM: float = 580
const BURGO_BRIDGE: Rect2i = Rect2i(440,46,2,22)

# Ambas orillas y el Lérez forman una sola lámina de agua que sale por el oeste.
# El tramo local ocupa el tablero completo; las otras rías quedan fuera del mapa.
const WATER_OUTLINE: Array[Vector2] = [
	Vector2(-1,55),Vector2(8,54),Vector2(15,51),Vector2(22,47),
	Vector2(27,49),Vector2(31,53),Vector2(39,51),Vector2(44,46),
	Vector2(48,45),Vector2(50,38),Vector2(59,35),Vector2(64,37),
	Vector2(67,42),Vector2(71,39),Vector2(75,31),Vector2(80,29),
	Vector2(84,26),Vector2(89,25),Vector2(94,27),
	Vector2(96,20),Vector2(102,14),Vector2(110,12),Vector2(118,8),Vector2(129,7),
	Vector2(129,11),Vector2(120,12),Vector2(113,16),Vector2(106,17),
	Vector2(100,22),Vector2(98,29),Vector2(94,32),
	Vector2(93,33),Vector2(92,34),Vector2(90,35),Vector2(87,37),
	Vector2(78,42),Vector2(72,48),Vector2(69,56),Vector2(67,67),
	Vector2(63,73),Vector2(60,83),Vector2(51,91),Vector2(47,102),
	Vector2(39,110),Vector2(28,117),Vector2(13,126),Vector2(-1,130)
]
const LANDMARKS: Array = [
	{"label":"PONTEVEDRA","x":412,"z":128},
	{"label":"COMBARRO","x":88,"z":168},
	{"label":"MARÍN","x":176,"z":448},
	{"label":"POIO","x":228,"z":72},
	{"label":"CAMPELO","x":220,"z":128},
	{"label":"LOURIDO","x":320,"z":88},
	{"label":"LOURIZÁN","x":324,"z":260},
	{"label":"TAMBO","x":88,"z":320},
	{"label":"RÍA DE PONTEVEDRA","x":180,"z":256},
	{"label":"RÍO LÉREZ","x":452,"z":36}
]

static func generate(seed_value: int) -> Array:
	var terrain: Array = []
	var water := PackedVector2Array()
	for vertex: Vector2 in WATER_OUTLINE: water.append(vertex*4.0)
	for z: int in range(SIZE):
		for x: int in range(SIZE):
			var point := Vector2(x+0.5,z+0.5)
			var kind: String = "water" if Geometry2D.is_point_in_polygon(point,water) else "land"
			if kind != "water":
				var sx: float = x/4.0
				var sz: float = z/4.0
				var wave: float = sin(sx*0.16)+cos(sz*0.19)+sin((sx+sz+seed_value%31)*0.11)
				if wave > 0.75: kind = "forest"
				elif wave < -0.3: kind = "fertile"
				# Montes y recursos en ambas orillas; depósitos adaptados para jugar.
				if (sz < 13 or (sx > 90 and sz > 65)) and wave > 0.2: kind = "rock"
				if sx > 103 and sz > 75 and wave > 1.1: kind = "ore"
				if sx > 72 and sx < 87 and sz > 78 and sz < 85: kind = "clay"
				# Entorno inicial de A Moureira, al sur del Lérez.
				var local := Vector2i((x-240)/2,(z-64)/2)-Vector2i(95,32)
				if local.x >= 0 and local.x <= 17 and local.y >= -5 and local.y <= 10: kind = "land"
				if local.x >= 7 and local.x <= 19 and local.y >= -15 and local.y <= -6: kind = "fertile"
				if local.x >= 13 and local.x <= 20 and local.y >= 7 and local.y <= 16: kind = "forest"
				if local.x >= 18 and local.x <= 24 and local.y >= -3 and local.y <= 4: kind = "rock"
				if local.x >= 7 and local.x <= 12 and local.y >= 13 and local.y <= 17: kind = "clay"
				if local.x >= 24 and local.x <= 29 and local.y >= 11 and local.y <= 17: kind = "ore"
			# Tambo, separada de Combarro y Marín por canales navegables.
			if pow((point.x-88)/24.0,2)+pow((point.y-316)/32.0,2) <= 1: kind = "forest"
			# Paso terrestre fijo: permite extender caminos hacia Poio y Combarro.
			if BURGO_BRIDGE.has_point(Vector2i(x,z)): kind = "land"
			terrain.append(kind)
	return terrain

static func main_road() -> Array:
	var cells: Array = []
	# A straight north–south road aligned with the narrow river crossing.
	for z: int in range(SIZE): cells.append(z*SIZE+BURGO_BRIDGE.position.x)
	return cells

static func entrance() -> int:
	return (SIZE-1)*SIZE+BURGO_BRIDGE.position.x

static func exit_cell() -> int:
	return BURGO_BRIDGE.position.x
