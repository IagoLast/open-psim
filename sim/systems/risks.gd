extends RefCounted

static func protected_by(sim: Variant, item: Dictionary, service: String) -> bool:
	for provider: Dictionary in sim.state.buildings:
		var definition: Dictionary = sim.definitions.buildings[provider.type]
		if definition.get("service","") != service or not provider.service_active: continue
		var distances: Dictionary = sim.road_distances(provider.access)
		if distances.get(item.access,99999) <= definition.radius: return true
	return false

static func daily(sim: Variant) -> void:
	var incident: bool = sim.state.buildings.any(func(b: Dictionary) -> bool: return b.burn_days > 0)
	var changed: bool = false
	var day: int = sim.state.tick/sim.definitions.balance.ticks_per_day
	for item: Dictionary in sim.state.buildings:
		item.age += 1
		if item.ruined: continue
		var water: bool = protected_by(sim,item,"water")
		var fire_cover: bool = water and protected_by(sim,item,"fire")
		var maintenance: bool = protected_by(sim,item,"maintenance") and sim.state.inventory.wood > 0
		if maintenance:
			if item.condition < 100:
				sim.state.inventory.wood -= 1
				sim.Economy.record_flow(sim,"consumption","wood",1)
			item.condition = mini(100,item.condition+8)
		elif item.age > sim.definitions.scenario.risk_grace_days:
			item.condition = maxi(0,item.condition-(1 if item.connected else 3))
		if item.burn_days > 0:
			if fire_cover:
				item.burn_days = 0
				item.fire_risk = 0
				sim.alert("Incendio extinguido en %s #%d" % [sim.definitions.buildings[item.type].label,item.id])
			else:
				item.burn_days += 1
				item.condition = maxi(0,item.condition-25)
				if item.burn_days >= 4: ruin(sim,item,"Incendio")
			changed = true
			continue
		if day <= sim.definitions.scenario.risk_grace_days: continue
		var ignition: int = 4 if item.type in ["bakery","smith","potter"] else 1
		if item.type == "house" and item.adjoined > 0: ignition += 1
		item.fire_risk = clampi(item.fire_risk+(-12 if fire_cover else ignition),0,100)
		if item.fire_risk >= 60: sim.alert("Riesgo de fuego en %s #%d: necesita vigías y agua" % [sim.definitions.buildings[item.type].label,item.id])
		if item.condition <= 40: sim.alert("Grietas en %s #%d: repara o contrata maestros de obras" % [sim.definitions.buildings[item.type].label,item.id])
		if item.condition <= sim.definitions.scenario.collapse_threshold:
			ruin(sim,item,"Derrumbe")
			changed = true
		elif not incident and item.fire_risk >= sim.definitions.scenario.fire_threshold:
			item.burn_days = 1
			incident = true
			changed = true
			sim.alert("Fuego en %s #%d: conecta vigías y un pozo" % [sim.definitions.buildings[item.type].label,item.id])
	if changed: sim.rebuild()

static func ruin(sim: Variant, item: Dictionary, reason: String) -> void:
	item.ruined = true
	item.active = false
	item.burn_days = 0
	item.condition = 0
	item.connected = false
	item.service_active = false
	item.work = 0
	sim.alert("%s: %s #%d en ruinas; se puede reparar" % [reason,sim.definitions.buildings[item.type].label,item.id])
	if item.type == "house": sim.Housing.rehouse(sim,item)
