extends RefCounted
## Ría interior: Pontevedra–Combarro–Marín. Norte arriba; geografía estilizada.
const ID: String = "pontevedra-inner-ria-v1"
const SIZE: int = 128
const START: Vector2i = Vector2i(95,32)
const START_FOCUS: Vector3 = Vector3(100,0,32)
const OVERVIEW_FOCUS: Vector3 = Vector3(64,0,64)
const OVERVIEW_ZOOM: float = 145
const BURGO_BRIDGE: Rect2i = Rect2i(100,14,2,10)

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
	{"label":"PONTEVEDRA","x":103,"z":32},
	{"label":"COMBARRO","x":22,"z":42},
	{"label":"MARÍN","x":44,"z":112},
	{"label":"POIO","x":57,"z":18},
	{"label":"CAMPELO","x":55,"z":32},
	{"label":"LOURIDO","x":80,"z":22},
	{"label":"LOURIZÁN","x":81,"z":65},
	{"label":"TAMBO","x":22,"z":80},
	{"label":"RÍA DE PONTEVEDRA","x":45,"z":64},
	{"label":"RÍO LÉREZ","x":113,"z":9}
]

static func generate(seed_value: int) -> Array:
	var terrain: Array = []
	var water: PackedVector2Array = PackedVector2Array(WATER_OUTLINE)
	for z: int in range(SIZE):
		for x: int in range(SIZE):
			var point := Vector2(x+0.5,z+0.5)
			var kind: String = "water" if Geometry2D.is_point_in_polygon(point,water) else "land"
			if kind != "water":
				var wave: float = sin(x*0.16)+cos(z*0.19)+sin((x+z+seed_value%31)*0.11)
				if wave > 0.75: kind = "forest"
				elif wave < -0.3: kind = "fertile"
				# Montes y recursos en ambas orillas; depósitos adaptados para jugar.
				if (z < 13 or (x > 90 and z > 65)) and wave > 0.2: kind = "rock"
				if x > 103 and z > 75 and wave > 1.1: kind = "ore"
				if x > 72 and x < 87 and z > 78 and z < 85: kind = "clay"
				# Entorno inicial de A Moureira, al sur del Lérez.
				var local := Vector2i(x,z)-START
				if local.x >= 0 and local.x <= 17 and local.y >= -5 and local.y <= 10: kind = "land"
				if local.x >= 7 and local.x <= 19 and local.y >= -15 and local.y <= -6: kind = "fertile"
				if local.x >= 13 and local.x <= 20 and local.y >= 7 and local.y <= 16: kind = "forest"
				if local.x >= 18 and local.x <= 24 and local.y >= -3 and local.y <= 4: kind = "rock"
				if local.x >= 7 and local.x <= 12 and local.y >= 13 and local.y <= 17: kind = "clay"
				if local.x >= 24 and local.x <= 29 and local.y >= 11 and local.y <= 17: kind = "ore"
			# Tambo, separada de Combarro y Marín por canales navegables.
			if pow((point.x-22)/6.0,2)+pow((point.y-79)/8.0,2) <= 1: kind = "forest"
			# Paso terrestre fijo: permite extender caminos hacia Poio y Combarro.
			if BURGO_BRIDGE.has_point(Vector2i(x,z)): kind = "land"
			terrain.append(kind)
	return terrain
