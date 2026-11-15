extends CanvasLayer

# RESILIENCE - PAUSE MENU
# Esc, P or controller Start pauses the game. Resume / Options / Restart / Main Menu.
# Options = music and sound volume and fullscreen (saved by settings.gd, same as the main menu).
# Up/Down (or the D-pad, or the mouse) to choose, Enter/A/click to pick, Esc/B/Start to resume.
# level_1.gd adds this in _ready(). Built in code, styled like the main menu.

const FONT = preload("res://assets/fonts/Cinzel.ttf")
const Ornament = preload("res://menu_ornament.gd")
const MAIN_MENU = "res://main_menu.tscn"

const WHITE = Color("#F2F6FF")
const DIM = Color("#8D97B3")

var root: Control       # everything on screen (hidden while playing)
var buttons: Array[Button] = []
var is_open = false
var column: VBoxContainer    # the main buttons
var options: VBoxContainer   # the Options page (swaps with column)
var music_slider: HSlider
var full_button: Button


func _ready() -> void:
	layer = 50                                # above the HUD
	process_mode = Node.PROCESS_MODE_ALWAYS   # keeps working while the game is paused

	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.visible = false
	add_child(root)

	# Dark see-through shade over the game (also blocks clicks on the game)
	var shade = ColorRect.new()
	shade.color = Color(0.02, 0.02, 0.04, 0.72)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)

	# Title, flourish and buttons in a centred column
	column = VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 14)
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(column)

	var title = Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", FONT)
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", WHITE)
	column.add_child(title)

	# The flourish draws around its own centre, so it sits in an empty box
	var flourish_box = Control.new()
	flourish_box.custom_minimum_size = Vector2(0, 40)
	flourish_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(flourish_box)
	var flourish = Ornament.new()
	flourish.kind = Ornament.Kind.BOTTOM
	flourish.scale = Vector2(0.7, 0.7)
	flourish_box.add_child(flourish)
	flourish_box.resized.connect(func(): flourish.position = Vector2(flourish_box.size.x / 2, 4))

	_button(column, "Resume", close)
	_button(column, "Options", _show_options.bind(true))
	_button(column, "Restart", _on_restart)
	_button(column, "Main Menu", _on_main_menu)

	# Up from the top button wraps to the bottom and back
	for i in buttons.size():
		buttons[i].focus_neighbor_top = buttons[i - 1].get_path()
		buttons[i].focus_neighbor_bottom = buttons[(i + 1) % buttons.size()].get_path()
		buttons[i].focus_neighbor_left = buttons[i].get_path()   # left/right do nothing
		buttons[i].focus_neighbor_right = buttons[i].get_path()
	_build_options()


func _build_options() -> void:
	options = VBoxContainer.new()
	options.alignment = BoxContainer.ALIGNMENT_CENTER
	options.add_theme_constant_override("separation", 18)
	options.set_anchors_preset(Control.PRESET_FULL_RECT)
	options.mouse_filter = Control.MOUSE_FILTER_IGNORE
	options.visible = false
	root.add_child(options)
	var title = Label.new()
	title.text = "OPTIONS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", FONT)
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", WHITE)
	options.add_child(title)
	music_slider = _slider(options, "Music", Settings.music_volume, func(v):
		Settings.music_volume = v
		Settings.apply()
		Settings.save())
	_slider(options, "Sounds", Settings.sound_volume, func(v):
		Settings.sound_volume = v
		Settings.apply()
		Settings.save()
		Sfx.play("talk"))   # so you can hear the new loudness
	full_button = _button(options, _fullscreen_text(), func():
		Settings.fullscreen = not Settings.fullscreen
		Settings.apply()
		Settings.save()
		full_button.text = _fullscreen_text())
	_button(options, "Back", _show_options.bind(false))
	buttons.resize(4)   # the wrap-around focus above is only for the main buttons


func _show_options(show: bool) -> void:
	options.visible = show
	column.visible = not show
	if show:
		music_slider.value = Settings.music_volume
		music_slider.grab_focus()
	else:
		buttons[1].grab_focus()   # back on "Options"


func _fullscreen_text() -> String:
	return "Fullscreen:  " + ("On" if Settings.fullscreen else "Off")


func _slider(parent: Control, text: String, value: float, on_change: Callable) -> HSlider:
	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	parent.add_child(row)
	var label = Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(110, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", DIM)
	row.add_child(label)
	var slider = HSlider.new()
	slider.custom_minimum_size = Vector2(220, 30)
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.focus_mode = Control.FOCUS_ALL
	slider.value_changed.connect(on_change)
	slider.mouse_entered.connect(slider.grab_focus)
	slider.focus_entered.connect(func(): label.add_theme_color_override("font_color", WHITE))
	slider.focus_exited.connect(func(): label.add_theme_color_override("font_color", DIM))
	row.add_child(slider)
	return slider


func _unhandled_input(event: InputEvent) -> void:
	var toggle = (
		(event is InputEventKey and event.pressed and not event.echo
			and event.physical_keycode in [KEY_ESCAPE, KEY_P])
		or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START)
		or (is_open and event.is_action_pressed("ui_cancel"))  # B on a controller
	)
	if not toggle:
		return
	get_viewport().set_input_as_handled()
	if is_open and options.visible:   # Esc on the Options page goes back first
		_show_options(false)
	elif is_open:
		close()
	elif not get_tree().paused:  # don't open on top of the Soul Strike (it pauses the game too)
		open()


func open() -> void:
	is_open = true
	get_tree().paused = true
	root.visible = true
	_show_options(false)
	root.modulate.a = 0.0
	create_tween().tween_property(root, "modulate:a", 1.0, 0.15)
	buttons[0].grab_focus()
	Sfx.play("talk")


func close() -> void:
	is_open = false
	get_tree().paused = false
	root.visible = false
	Sfx.play("talk")


func _on_restart() -> void:
	close()
	get_tree().reload_current_scene()


func _on_main_menu() -> void:
	close()
	get_tree().change_scene_to_file(MAIN_MENU)


# Same look as the main menu buttons: dim text, white when selected
func _button(parent: Control, text: String, action: Callable) -> Button:
	var button = Button.new()
	button.text = text
	button.flat = true
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 24)
	button.add_theme_color_override("font_color", DIM)
	for state in ["font_hover_color", "font_focus_color", "font_hover_pressed_color", "font_pressed_color"]:
		button.add_theme_color_override(state, WHITE)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.pressed.connect(action)
	button.mouse_entered.connect(button.grab_focus)
	button.focus_entered.connect(func(): Sfx.play("qte_tick"))
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	parent.add_child(button)
	buttons.append(button)
	return button
