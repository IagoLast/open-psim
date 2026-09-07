extends RefCounted

static func capacity(home: Dictionary, definitions: Dictionary) -> int:
	if home.get("ruined",false): return 0
	return definitions.housing.levels[home.level-1].capacity

static func missing(sim: Variant, home: Dictionary, level: int, occupants: Array) -> Array:
	var needs: Array = []
	var definition: Dictionary = sim.definitions.housing.levels[level-1]
	if not home.connected: needs.append("Camino al almacén")
	if occupants.is_empty(): needs.append("Habitantes")
	elif occupants.any(func(c: Dictionary) -> bool: return not c.fed): needs.append("Alimentos")
	for service: String in definition.services:
		if not home.services.get(service,false): needs.append(sim.Citizens.SERVICE_LABELS[service])
	for resource: String in definition.goods:
		if sim.state.inventory[resource] < definition.goods[resource]: needs.append(sim.definitions.resources[resource].label)
	return needs

static func daily(sim: Variant) -> void:
	for home: Dictionary in sim.state.buildings:
		if home.type != "house": continue
		var occupants: Array = sim.state.citizens.filter(func(c: Dictionary) -> bool: return c.home == home.id)
		var next: int = mini(home.level+1,sim.definitions.housing.levels.size())
		var required: Array = missing(sim,home,home.level,occupants)
		var upcoming: Array = missing(sim,home,next,occupants)
		home.needs = ", ".join(required if not required.is_empty() else upcoming)
		if required.is_empty():
			home.decline_days = 0
			if upcoming.is_empty() and home.level < next:
				home.upgrade_days += 1
				if home.upgrade_days >= sim.definitions.housing.upgrade_days:
					home.level = next
					home.upgrade_days = 0
					sim.alert("Vivienda #%d: %s" % [home.id,sim.definitions.housing.levels[next-1].label])
			else: home.upgrade_days = 0
		else:
			home.upgrade_days = 0
			home.decline_days += 1
			if home.level > 1 and home.decline_days >= sim.definitions.housing.downgrade_days:
				home.level -= 1
				home.decline_days = 0
				sim.alert("Vivienda #%d pierde nivel: %s" % [home.id,home.needs])
		# Consume a supplied day's luxury goods, including while working toward an upgrade.
		var supplied_level: int = next if upcoming.is_empty() else home.level
		if missing(sim,home,supplied_level,occupants).is_empty():
			for resource: String in sim.definitions.housing.levels[supplied_level-1].goods:
				sim.state.inventory[resource] -= sim.definitions.housing.levels[supplied_level-1].goods[resource]
		home.care_days = home.upgrade_days
		rehouse(sim,home)

static func rehouse(sim: Variant, home: Dictionary) -> void:
	var occupants: Array = sim.state.citizens.filter(func(c: Dictionary) -> bool: return c.home == home.id)
	var excess: int = occupants.size()-capacity(home,sim.definitions)
	if excess <= 0: return
	for c: Dictionary in occupants.slice(maxi(0,occupants.size()-excess)):
		var relocated: bool = false
		for target: Dictionary in sim.state.buildings:
			if target.type != "house" or target.id == home.id or not target.connected or not target.water: continue
			var used: int = sim.state.citizens.filter(func(other: Dictionary) -> bool: return other.home == target.id).size()
			if used >= capacity(target,sim.definitions): continue
			c.home = target.id
			c.route_version = -1
			c.hardship = 0
			relocated = true
			break
		if not relocated:
			c.hardship += 1
			if c.hardship >= sim.definitions.scenario.emigration_days:
				sim.state.citizens.erase(c)
				sim.alert("Un vecino abandona la villa por falta de alojamiento")
