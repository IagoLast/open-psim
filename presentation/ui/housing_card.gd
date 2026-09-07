extends VBoxContainer
## Residential details share the same needs calculation as the simulation.
signal citizen_selected(id: int)
const Folio = preload("res://presentation/ui/folio.gd")
const Illustration = preload("res://presentation/ui/illustration.gd")
const Housing = preload("res://sim/systems/housing.gd")
const Citizens = preload("res://sim/systems/citizens.gd")
const Palette = preload("res://presentation/ui/parchment_theme.gd")
var artwork: Control
var level_label: Label
var occupancy: Label
var connection: Label
var evolution: Label
var progress: ProgressBar
var next_step: Label
var care: Label
var services: Dictionary = {}
var residents: VBoxContainer
var empty_home: Label
var resident_buttons: Dictionary = {}

func _ready() -> void:
	add_theme_constant_override("separation",10)
	var hero: VBoxContainer = Folio.inset(self)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",10)
	hero.add_child(row)
	artwork = Illustration.new()
	artwork.custom_minimum_size = Vector2(64,64)
	row.add_child(artwork)
	var summary := VBoxContainer.new()
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(summary)
	level_label = Folio.label(summary,"",22)
	level_label.theme_type_variation = "FolioTitle"
	occupancy = Folio.label(summary,"",20)
	connection = Folio.paragraph(summary,"",15)
	var growth: VBoxContainer = Folio.inset(self)
	Folio.section(growth,"Evolución de la casa","sprig")
	evolution = Folio.paragraph(growth,"",17)
	progress = ProgressBar.new()
	progress.custom_minimum_size.y = 10
	progress.show_percentage = false
	growth.add_child(progress)
	next_step = Folio.paragraph(growth,"",16)
	var supply: VBoxContainer = Folio.inset(self)
	Folio.section(supply,"Necesidades del hogar","crate")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation",12)
	grid.add_theme_constant_override("v_separation",5)
	supply.add_child(grid)
	for entry: Array in [["food","Alimentos","bread"],["water","Agua","water"],["market","Mercado","market"],["health","Salud","health"],["faith","Culto","faith"],["safety","Seguridad","safety"],["education","Educación","education"]]:
		var need := HBoxContainer.new()
		need.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(need)
		var icon := Illustration.new()
		icon.custom_minimum_size = Vector2(28,28)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		need.add_child(icon)
		icon.set_kind(entry[2])
		var label: Label = Folio.label(need,"",16)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.set_meta("caption",entry[1])
		services[entry[0]] = label
	Folio.section(self,"Vecinos de esta casa","seal")
	empty_home = Folio.paragraph(self,"Todavía no hay vecinos. Consulta la llegada de vecinos en Tu villa.",16)
	residents = VBoxContainer.new()
	residents.add_theme_constant_override("separation",5)
	add_child(residents)
	care = Folio.paragraph(self,"",15)
	care.add_theme_color_override("font_color",Palette.MUTED)

func update_home(home: Dictionary, snapshot: Dictionary, definitions: Dictionary) -> void:
	var occupants: Array = snapshot.citizens.filter(func(c: Dictionary) -> bool: return c.home == home.id)
	var level: Dictionary = definitions.housing.levels[home.level-1]
	artwork.set_kind(level.model)
	level_label.text = "Casa " + level.label.to_lower()
	occupancy.text = "%d / %d vecinos" % [occupants.size(),Housing.capacity(home,definitions)]
	connection.text = "Conectada al almacén" if home.connected else "Sin camino al almacén"
	connection.add_theme_color_override("font_color",Palette.OLIVE if home.connected else Palette.RUBRIC)
	var target: int = mini(home.level+1,definitions.housing.levels.size())
	var missing: Array = Housing.missing({"definitions":definitions,"state":snapshot,"Citizens":Citizens},home,target,occupants)
	var current_missing: Array = Housing.missing({"definitions":definitions,"state":snapshot,"Citizens":Citizens},home,home.level,occupants)
	evolution.text = "Nivel máximo · Mercantil" if target == home.level else "Hacia %s · %d/%d días" % [definitions.housing.levels[target-1].label.to_lower(),home.upgrade_days,definitions.housing.upgrade_days]
	progress.max_value = definitions.housing.upgrade_days
	progress.value = progress.max_value if target == home.level else home.upgrade_days
	if home.burn_days > 0: next_step.text = "¡Incendio! Conecta vigías del fuego y agua."
	elif home.decline_days > 0:
		next_step.text = "Carencias: %s\n%d/%d días con necesidades sin cubrir." % [", ".join(current_missing),home.decline_days,definitions.housing.downgrade_days]
	elif not missing.is_empty(): next_step.text = "Falta: " + ", ".join(missing)
	else: next_step.text = "Necesidades cubiertas. Mantén los suministros." if target == home.level else "Todo preparado: mantén estos servicios para mejorar."
	next_step.add_theme_color_override("font_color",Palette.RUBRIC if home.burn_days > 0 or home.decline_days > 0 else Palette.MUTED)
	for key: String in services:
		var supplied: bool = occupants.all(func(c: Dictionary) -> bool: return c.fed) and not occupants.is_empty() if key == "food" else home.services.get(key,false)
		var required: bool = key == "food" or key in definitions.housing.levels[target-1].services
		services[key].text = ("✓ " if supplied else "○ ") + services[key].get_meta("caption")
		services[key].add_theme_color_override("font_color",Palette.OLIVE if supplied else (Palette.RUBRIC if required else Palette.MUTED))
		services[key].mouse_filter = Control.MOUSE_FILTER_STOP
		services[key].tooltip_text = "Cubierto" if supplied else ("Necesario para este nivel o el siguiente" if required else "Se necesitará en niveles posteriores")
	var ids: Array = occupants.map(func(c: Dictionary) -> int: return c.id)
	for id: int in resident_buttons.keys():
		if id not in ids:
			residents.remove_child(resident_buttons[id])
			resident_buttons[id].queue_free()
			resident_buttons.erase(id)
	for citizen: Dictionary in occupants:
		if not resident_buttons.has(citizen.id):
			var button := Button.new()
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.custom_minimum_size.y = 44
			button.pressed.connect(func() -> void: citizen_selected.emit(citizen.id))
			residents.add_child(button)
			resident_buttons[citizen.id] = button
		resident_buttons[citizen.id].text = "%s · %d%%\n%s" % [citizen.name,citizen.satisfaction,citizen.activity]
		resident_buttons[citizen.id].tooltip_text = "Ver la ficha de " + citizen.name
	empty_home.visible = occupants.is_empty()
	care.text = "Conservación %d%% · Riesgo de fuego %d%%\nImpuesto: %d moneda(s) por vecino abastecido/día" % [home.condition,home.fire_risk,home.level]
