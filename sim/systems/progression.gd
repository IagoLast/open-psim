extends RefCounted

static func daily(sim: Variant) -> void:
	var objective: Dictionary = sim.state.objective
	var d: Dictionary = sim.definitions.scenario
	var population: int = sim.state.citizens.size()
	var employed: int = sim.state.citizens.filter(func(c: Dictionary) -> bool: return c.job > 0).size()
	var supplied: int = sim.state.citizens.filter(func(c: Dictionary) -> bool: return c.fed and c.water).size()
	var prosperous: int = 0
	for b: Dictionary in sim.state.buildings:
		if b.type == "house" and b.level >= 2 and b.connected and sim.state.citizens.any(func(c: Dictionary) -> bool: return c.home == b.id): prosperous += 1
	sim.state.cash_history.append(sim.state.operating)
	if sim.state.cash_history.size() > d.hold_days: sim.state.cash_history.pop_front()
	sim.state.operating = 0
	var cash: int = 0
	for value: int in sim.state.cash_history: cash += value
	var food: bool = sim.Economy.food(sim) >= population*d.reserve_days
	var labor: bool = population > 0 and employed*100 >= population*d.employment_percent
	var stable: bool = population >= d.stability_population and food and labor and supplied == population
	objective.stable_days = mini(d.hold_days,objective.stable_days+1) if stable else 0
	var victory: bool = stable and population >= d.population and prosperous >= d.prosperous_homes and sim.state.exported >= d.exports and cash >= 0 and sim.state.cash_history.size() == d.hold_days
	objective.victory_days = mini(d.hold_days,objective.victory_days+1) if victory else 0
	if population >= 8 and supplied == population and sim.state.buildings.any(func(b: Dictionary) -> bool: return b.type in ["farm","fishery"] and b.produced > 0):
		objective.founded = true
		objective.stage = maxi(1,objective.stage)
	if objective.stage >= 1 and objective.stable_days >= d.hold_days: objective.stage = maxi(2,objective.stage)
	if objective.stage >= 2 and prosperous >= d.prosperous_homes and sim.state.trade_completed > 0 and sim.state.exported > 0: objective.stage = maxi(3,objective.stage)
	if objective.stage >= 3 and objective.victory_days >= d.hold_days and not objective.won:
		objective.won = true
		objective.stage = 4
		sim.alert("Encargo cumplido: la villa prospera. Puedes seguir construyendo.")
	objective.empty_days = objective.empty_days+1 if objective.founded and population == 0 else 0
	if objective.empty_days >= d.recovery_days: objective.failed = true
	var titles: Array = ["Fundación: almacén, viviendas, pozo y producción de alimentos", "Estabilidad: 24 vecinos, 80% de empleo y 3 días de comida", "Prosperidad: 6 viviendas prósperas ocupadas y una exportación", "Villa portuaria: 40 vecinos, 50 exportaciones y economía estable", "Encargo cumplido · continúa en modo libre"]
	objective.message = titles[objective.stage]
	if objective.failed: objective.message = "Villa despoblada · solicita ayuda si queda disponible o inicia otra partida"
	objective.details = "Vecinos %d/%d · Empleo %d%%\nViviendas prósperas %d/%d · Exportado %d/%d\nEstabilidad %d/%d días · Encargo %d/%d días\nSaldo operativo (%d días): %d\nPeregrinos atendidos: %d · Reputación: %d" % [population,d.population,employed*100/maxi(1,population),prosperous,d.prosperous_homes,sim.state.exported,d.exports,objective.stable_days,d.hold_days,objective.victory_days,d.hold_days,sim.state.cash_history.size(),cash,sim.state.pilgrims_served,sim.state.reputation]
