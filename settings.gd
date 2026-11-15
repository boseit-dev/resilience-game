extends Node

# RESILIENCE - SETTINGS (autoload "Settings")
# Music volume, sound volume and fullscreen, set from the main menu's Options page.
# Saved to user://settings.cfg so they're kept between runs.

const PATH = "user://settings.cfg"

var music_volume: float = 1.0   # 0 to 1
var sound_volume: float = 1.0   # 0 to 1
var fullscreen: bool = false


func _ready() -> void:
	# Sfx sends music to the "Music" bus and everything else to "Sounds"
	for bus_name in ["Music", "Sounds"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)

	# Godot's menu actions have no controller buttons by default: A = accept, B = back
	_add_joy_button("ui_accept", JOY_BUTTON_A)
	_add_joy_button("ui_cancel", JOY_BUTTON_B)

	var config = ConfigFile.new()
	if config.load(PATH) == OK:
		music_volume = config.get_value("audio", "music", 1.0)
		sound_volume = config.get_value("audio", "sound", 1.0)
		fullscreen = config.get_value("video", "fullscreen", false)
	apply()


func apply() -> void:
	_set_bus("Music", music_volume)
	_set_bus("Sounds", sound_volume)

	var is_fullscreen = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	if fullscreen != is_fullscreen:
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		)


func save() -> void:
	var config = ConfigFile.new()
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "sound", sound_volume)
	config.set_value("video", "fullscreen", fullscreen)
	config.save(PATH)


func _set_bus(bus_name: String, volume: float) -> void:
	var index = AudioServer.get_bus_index(bus_name)
	AudioServer.set_bus_volume_db(index, linear_to_db(max(volume, 0.0001)))  # 0 = silent


func _add_joy_button(action: String, button: JoyButton) -> void:
	var press = InputEventJoypadButton.new()
	press.button_index = button
	if not InputMap.action_has_event(action, press):
		InputMap.action_add_event(action, press)
