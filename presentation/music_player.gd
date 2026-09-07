extends AudioStreamPlayer
## The soundtrack continues across menus and towns, independently of simulation speed.
const SETTINGS_PATH := "user://audio.cfg"
const TRACKS := [
	preload("res://assets/music/1.mp3"),
	preload("res://assets/music/2.mp3"),
	preload("res://assets/music/3.mp3"),
	preload("res://assets/music/4.mp3"),
]
var enabled: bool = true
var track_index: int = 0

func _ready() -> void:
	var settings := ConfigFile.new()
	if settings.load(SETTINGS_PATH) == OK:
		enabled = bool(settings.get_value("audio", "music_enabled", true))
	volume_db = -12.0
	finished.connect(_next_track)
	stream = TRACKS[track_index]
	if enabled: play()

func set_enabled(value: bool) -> void:
	enabled = value
	if enabled and not playing:
		play()
	stream_paused = not enabled
	var settings := ConfigFile.new()
	settings.set_value("audio", "music_enabled", enabled)
	if settings.save(SETTINGS_PATH) != OK:
		push_warning("No se pudo guardar la preferencia de música.")

func _next_track() -> void:
	track_index = (track_index + 1) % TRACKS.size()
	stream = TRACKS[track_index]
	if enabled: play()
