extends RefCounted
## Norte arriba, Atlántico al oeste. Geografía estilizada, no cartografía histórica.
const SIZE: int = 128
const COAST: Array[Vector2] = [Vector2(50,0),Vector2(45,8),Vector2(32,12),Vector2(49,18),Vector2(58,22),Vector2(60,26),Vector2(52,30),Vector2(38,34),Vector2(28,38),Vector2(33,42),Vector2(49,46),Vector2(59,50),Vector2(64,54),Vector2(60,57),Vector2(48,60),Vector2(35,64),Vector2(28,67),Vector2(36,71),Vector2(54,76),Vector2(62,80),Vector2(59,84),Vector2(42,88),Vector2(26,92),Vector2(24,98),Vector2(28,108),Vector2(32,120),Vector2(38,127)]
const LANDMARKS: Array = [
	{"label":"RÍA DE AROUSA","x":29,"z":23}, {"label":"O SALNÉS","x":45,"z":37},
	{"label":"RÍA DE PONTEVEDRA","x":32,"z":55}, {"label":"PONTEVEDRA","x":69,"z":51},
	{"label":"O MORRAZO","x":42,"z":67}, {"label":"RÍA DE VIGO","x":32,"z":82},
	{"label":"VIGO","x":51,"z":91}, {"label":"BAIXO MIÑO","x":55,"z":116},
	{"label":"DEZA · TERRA DE MONTES","x":101,"z":28}, {"label":"ONS","x":22,"z":49},
	{"label":"CÍES","x":19,"z":78}, {"label":"ATLÁNTICO","x":10,"z":104}
]
static func generate(seed_value: int) -> Array:
	var terrain: Array = []
	for z: int in range(SIZE):
		var coast: float = 50
		for i: int in range(COAST.size()-1):
			if z >= COAST[i].y and z <= COAST[i+1].y:
				coast = lerpf(COAST[i].x,COAST[i+1].x,(z-COAST[i].y)/(COAST[i+1].y-COAST[i].y))
				break
		for x: int in range(SIZE):
			var kind: String = "water" if x < coast else "land"
			if kind == "land":
				var wave: float = sin(x*0.16)+cos(z*0.19)+sin((x+z+seed_value%31)*0.11)
				if wave > 0.75: kind = "forest"
				elif wave < -0.3: kind = "fertile"
				if x > 86 and wave > 0.2: kind = "rock"
				if x > 96 and z > 28 and z < 82 and wave > 1.1: kind = "ore"
				if x > 58 and x < 79 and z > 95 and z < 104: kind = "clay"
			# Playable hinterland near Pontevedra: an initial foothold, not a prebuilt economy.
			if x >= 65 and x <= 82 and z >= 49 and z <= 64: kind = "land"
			if x >= 72 and x <= 84 and z >= 39 and z <= 48: kind = "fertile"
			if x >= 78 and x <= 85 and z >= 61 and z <= 70: kind = "forest"
			if x >= 83 and x <= 89 and z >= 51 and z <= 58: kind = "rock"
			if x >= 72 and x <= 77 and z >= 67 and z <= 71: kind = "clay"
			if x >= 89 and x <= 94 and z >= 65 and z <= 71: kind = "ore"
			# Ons, Cíes and A Illa de Arousa.
			for island: Vector3 in [Vector3(22,49,2),Vector3(19,78,2),Vector3(21,83,1.5),Vector3(41,26,2)]:
				if pow((x-island.x)/island.z,2)+pow((z-island.y)/(island.z*1.7),2) <= 1: kind = "forest"
			terrain.append(kind)
	return terrain
