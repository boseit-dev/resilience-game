extends Control

# RESILIENCE - MAIN MENU
# Pages: main (Continue / New Game / Tutorial / Level Select / Options / Controls / Quit),
# levels (the ones you've unlocked), options (volumes, fullscreen), controls.
# Story progress comes from the SaveGame autoload (save_game.gd).
# Up/Down (or W/S, or the mouse) to choose, Enter/Space/click to pick, Esc to go back.
# Everything is built in code below, section by section, like the HUD in level_1.gd.
#
# Easter egg: the Quit Game button is scared of the mouse. It runs away 5 times, then gets
# tired and lets you click it. Keyboard/controller players can always pick it normally.
# Quitting asks "are you sure?" and the Leave button unlocks after a 5-second countdown.

const FONT = preload("res://assets/fonts/Cinzel.ttf")
const Ornament = preload("res://menu_ornament.gd")
const TUTORIAL = "res://tutorial.tscn"

const WHITE = Color("#F2F6FF")
const DIM = Color("#8D97B3")
const GLOW = Color("#83D9FF")

const QUIT_ESCAPES_UNTIL_TIRED = 5
const QUIT_TAUNTS = ["Eek!", "Nope!", "Not today!", "Too slow!", "Catch me if you... huff..."]
const QUIT_COUNTDOWN = 5  # seconds before Leave unlocks

var screen: Vector2
var pages = {}            # page name -> Control
var current_page = ""
var marker_left: Control
var marker_right: Control
var fade: ColorRect
var busy = false          # true while fading out (ignore input)
var bg: Control           # everything behind the title (scaled to cover any window shape)
var corner_left: Label
var corner_right: Label

var main_buttons: Array[Button] = []
var new_game_armed = false  # with a save, New Game must be pressed twice (so it isn't erased by accident)
var quit_button: Button
var quit_escapes = 0
var quit_moving = false
var quit_dialog: Control  # the "are you sure?" window while it's open (null when closed)
var quit_panel: PanelContainer
var quit_shade: ColorRect
var quit_ornament: Control
var quit_seconds_left = 0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR  # smooth gradients (the levels use crisp pixels)
	screen = get_viewport().get_visible_rect().size
	set_anchors_preset(Control.PRESET_TOP_LEFT)  # we place the menu ourselves (see _fit_to_window)
	size = screen

	_build_background()
	bg = Control.new()
	bg.name = "Background"
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background_parts = get_children()
	add_child(bg)
	for part in background_parts:
		part.reparent(bg)
	_build_title()
	pages["main"] = _build_main_page()
	pages["levels"] = _build_levels_page()
	pages["options"] = _build_options_page()
	pages["controls"] = _build_controls_page()
	_build_corner_text()

	marker_left = _ornament(Ornament.Kind.MARKER, Vector2.ZERO, self)
	marker_right = _ornament(Ornament.Kind.MARKER, Vector2.ZERO, self)
	marker_right.flip = true
	get_viewport().gui_focus_changed.connect(_on_focus_changed)

	fade = _rect(Vector2.ZERO, screen, Color.BLACK, self)
	fade.top_level = true  # always covers the whole window
	create_tween().tween_property(fade, "color:a", 0.0, 1.2)  # fade in from black

	_show_page("main")
	Sfx.start_ambience()
	get_viewport().size_changed.connect(_fit_to_window)
	_fit_to_window()


func _process(_delta: float) -> void:
	# The markers gently pulse next to whatever is selected (and follow it if it moves)
	var a = 0.75 + 0.25 * sin(Time.get_ticks_msec() / 300.0)
	marker_left.modulate.a = a
	marker_right.modulate.a = a
	_place_markers(get_viewport().gui_get_focus_owner())


# Keep the menu centred and the background covering the window, whatever its shape
func _fit_to_window(view: Vector2 = Vector2.ZERO) -> void:
	if view == Vector2.ZERO:
		view = get_viewport().get_visible_rect().size  # (the self-test passes other sizes in)
	var old_position = position
	position = ((view - screen) / 2).round()
	var cover = max(view.x / screen.x, view.y / screen.y)
	bg.scale = Vector2(cover, cover)
	bg.position = (view - screen * cover) / 2 - position
	fade.global_position = Vector2.ZERO
	fade.size = view
	corner_left.global_position = Vector2(28, view.y - 40)
	corner_right.global_position = Vector2(view.x - 150, view.y - 40)

	# The Quit button moves on its own once it has run away, so move it with the menu and keep it on screen
	if quit_button.top_level:
		var spot = quit_button.global_position + position - old_position
		quit_button.global_position = spot.clamp(Vector2(8, 8), view - quit_button.size - Vector2(8, 8))
	if is_instance_valid(quit_dialog):
		quit_dialog.size = view
		quit_shade.size = view
		_center_quit_panel()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_check_quit_escape(event.position)


func _unhandled_input(event: InputEvent) -> void:
	if busy:
		return
	if is_instance_valid(quit_dialog):
		if event.is_action_pressed("ui_cancel"):
			_close_quit_dialog()  # Esc = Stay
		return
	if event.is_action_pressed("ui_cancel") and current_page != "main":
		_show_page("main")
	elif event is InputEventKey and event.pressed and not event.echo:
		var focused = get_viewport().gui_get_focus_owner()
		if focused and event.physical_keycode == KEY_W:
			_focus(focused.find_prev_valid_focus())
		elif focused and event.physical_keycode == KEY_S:
			_focus(focused.find_next_valid_focus())


# ---------- background: mist, light rays, drifting spores ----------

func _build_background() -> void:
	# Dark sky, a little lighter at the top
	_gradient_rect(Vector2.ZERO, screen, [Color("#262632"), Color("#08080D")], false)

	# Glow behind the title
	_glow(Vector2(screen.x / 2, 150), Vector2(1000, 520), Color(0.75, 0.82, 1.0, 0.22))

	# Light rays falling from above, slowly breathing
	for i in 6:
		var ray = _gradient_rect(Vector2.ZERO, Vector2(randf_range(60, 150), 900),
			[Color(1, 1, 1, 0), Color(0.85, 0.9, 1, 0.13), Color(1, 1, 1, 0)], true)
		ray.position = Vector2(screen.x / 2 - 380 + i * 140 + randf_range(-30, 30), -120)
		ray.rotation = -0.18 + randf_range(-0.05, 0.05)
		ray.material = CanvasItemMaterial.new()
		ray.material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		var breathe = create_tween().set_loops()
		breathe.tween_property(ray, "modulate:a", 0.25, randf_range(2.5, 4.5)).set_trans(Tween.TRANS_SINE)
		breathe.tween_property(ray, "modulate:a", 1.0, randf_range(2.5, 4.5)).set_trans(Tween.TRANS_SINE)

	# Mist drifting along the bottom
	for i in 3:
		var mist = _glow(Vector2(screen.x * (0.2 + i * 0.3), screen.y - 40), Vector2(700, 260), Color(0.6, 0.65, 0.8, 0.12))
		var drift = create_tween().set_loops()
		drift.tween_property(mist, "position:x", mist.position.x + 80, randf_range(6, 9)).set_trans(Tween.TRANS_SINE)
		drift.tween_property(mist, "position:x", mist.position.x - 80, randf_range(6, 9)).set_trans(Tween.TRANS_SINE)

	# Pale motes and dark spores floating upwards
	_spores(Color(0.85, 0.9, 1.0, 0.45), 0.1, 0.25, 60)
	_spores(Color(0.02, 0.02, 0.04, 0.9), 0.25, 0.5, 22)

	# Darker edges
	_glow(screen / 2, screen * 1.6, Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.75))


func _spores(color: Color, size_min: float, size_max: float, amount: int) -> void:
	var p = CPUParticles2D.new()
	p.position = Vector2(screen.x / 2, screen.y + 20)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(screen.x / 2 + 40, 10)
	p.amount = amount
	p.lifetime = 16.0
	p.preprocess = 16.0  # start with the screen already full
	p.direction = Vector2(0, -1)
	p.spread = 25.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 25.0
	p.initial_velocity_max = 55.0
	p.scale_amount_min = size_min
	p.scale_amount_max = size_max
	p.color = color
	var dot = GradientTexture2D.new()  # a soft round dot, 16 px (scale 0.25 = 4 px)
	dot.width = 16
	dot.height = 16
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(0.5, 0.0)
	dot.gradient = Gradient.new()
	dot.gradient.colors = PackedColorArray([Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)])
	dot.gradient.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	p.texture = dot
	add_child(p)


# ---------- title ----------

func _build_title() -> void:
	var y = 92.0
	_ornament(Ornament.Kind.TOP, Vector2(screen.x / 2, y), self)
	for glow_pass in [[48, 0.03], [30, 0.04], [14, 0.06], [0, 1.0]]:  # two soft halos, then the letters
		var title = _label("RESILIENCE", 88, WHITE, self)
		title.position = Vector2(0, y + 6)
		title.size = Vector2(screen.x, 110)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if glow_pass[0] > 0:
			title.add_theme_color_override("font_color", Color(0, 0, 0, 0))
			title.add_theme_constant_override("outline_size", glow_pass[0])
			title.add_theme_color_override("font_outline_color", Color(0.8, 0.88, 1.0, glow_pass[1]))
	_ornament(Ornament.Kind.BOTTOM, Vector2(screen.x / 2, y + 128), self)


# ---------- pages ----------

func _build_main_page() -> Control:
	var page = _page()
	var resume = _menu_button(page, "Continue Game", func(): _go(SaveGame.level_scene(SaveGame.current_level)))
	var new_game = _menu_button(page, "New Game", func(): pass)
	new_game.pressed.connect(_on_new_game.bind(new_game))
	new_game.focus_exited.connect(func():
		new_game_armed = false
		new_game.text = "New Game")
	_menu_button(page, "Tutorial", _go.bind(TUTORIAL))
	_menu_button(page, "Level Select", _show_page.bind("levels"))
	_menu_button(page, "Options", _show_page.bind("options"))
	_menu_button(page, "Controls", _show_page.bind("controls"))
	quit_button = _menu_button(page, "Quit Game", _open_quit_dialog)
	quit_button.mouse_filter = Control.MOUSE_FILTER_IGNORE  # the mouse can't catch it until it's tired

	# Continue is greyed out until there is a story save
	if not SaveGame.has_progress():
		_lock(resume)
	page.set_meta("first", resume if SaveGame.has_progress() else new_game)

	# Up/Down go down the list (and wrap), skipping greyed-out buttons, wherever Quit has run off to
	main_buttons.assign(page.get_children().filter(func(b): return not b.disabled))
	for i in main_buttons.size():
		var button = main_buttons[i]
		button.focus_neighbor_top = button.get_path_to(main_buttons[i - 1])
		button.focus_neighbor_bottom = button.get_path_to(main_buttons[(i + 1) % main_buttons.size()])
	return page


# One button per level: unlocked levels can be played, the rest are greyed out
func _build_levels_page() -> Control:
	var page = _page()
	for n in range(1, SaveGame.LEVEL_COUNT + 1):
		var title = "%d   %s" % [n, SaveGame.LEVEL_NAMES[n - 1].capitalize()]
		var button = _menu_button(page, title, _go.bind(SaveGame.level_scene(n)))
		button.add_theme_font_size_override("font_size", 19)
		if not SaveGame.can_play(n):
			button.text = "%d   %s" % [n, "Locked" if n > SaveGame.unlocked_level else "Coming soon"]
			_lock(button)
	_menu_button(page, "Back", _show_page.bind("main"))
	page.set_meta("first", page.get_child(0))
	return page


# A greyed-out button that can't be picked
func _lock(button: Button) -> void:
	button.disabled = true
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _build_options_page() -> Control:
	var page = _page()
	var music = _slider_row(page, "Music", Settings.music_volume, func(v):
		Settings.music_volume = v
		Settings.apply()
		Settings.save())
	_slider_row(page, "Sounds", Settings.sound_volume, func(v):
		Settings.sound_volume = v
		Settings.apply()
		Settings.save()
		Sfx.play("talk"))  # so you can hear the new loudness
	var full = _menu_button(page, "", func(): pass)
	full.text = _fullscreen_text()
	full.pressed.connect(func():
		Settings.fullscreen = not Settings.fullscreen
		Settings.apply()
		Settings.save()
		full.text = _fullscreen_text()
		_on_focus_changed(full))
	_menu_button(page, "Back", _show_page.bind("main"))
	page.set_meta("first", music)
	return page


func _build_controls_page() -> Control:
	var page = _page()
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 6)
	var center = CenterContainer.new()
	center.custom_minimum_size = Vector2(0, 190)
	center.add_child(grid)
	page.add_child(center)
	for row in [
		["Move", "A / D   or   ← →"],
		["Jump", "W / ↑ / Space"],
		["Bounce pad  ·  Talk", "E"],
		["Dash", "Shift"],
		["Restart", "R  twice"],
	]:
		var action = _label(row[0], 17, DIM, grid)
		action.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_label(row[1], 17, WHITE, grid)
	var back = _menu_button(page, "Back", _show_page.bind("main"))
	page.set_meta("first", back)
	return page


func _show_page(page_name: String) -> void:
	if current_page != "" and current_page != page_name:
		Sfx.play("talk", 0.8)
	current_page = page_name
	for page_key in pages:
		pages[page_key].visible = page_key == page_name
	_focus(pages[page_name].get_meta("first"))


# ---------- actions ----------

# New Game: starts the story from the lab accident. With a save, the first press only warns.
func _on_new_game(button: Button) -> void:
	if SaveGame.has_progress() and not new_game_armed:
		new_game_armed = true
		button.text = "Erase your save?  Press again"
		Sfx.play("talk", 0.7)
		_on_focus_changed(button)
		return
	SaveGame.start_new_game()
	_go(SaveGame.STORY_START)


# Fade out to another scene (a level, the tutorial or the intro)
func _go(scene: String) -> void:
	if busy:
		return
	busy = true
	Sfx.play("checkpoint")  # a deep bell
	var out = create_tween()
	out.tween_property(fade, "color:a", 1.0, 0.9)
	out.tween_callback(func(): get_tree().change_scene_to_file(scene))


func _on_quit() -> void:
	if busy:
		return
	busy = true
	var out = create_tween()
	out.tween_property(fade, "color:a", 1.0, 0.5)
	out.tween_callback(get_tree().quit)


func _fullscreen_text() -> String:
	return "Fullscreen:  " + ("On" if Settings.fullscreen else "Off")


func _on_focus_changed(control: Control) -> void:
	if control and is_instance_valid(marker_left):
		_place_markers(control)
		Sfx.play("talk", 1.3)


# Put the two markers either side of whatever is selected
func _place_markers(control: Control) -> void:
	if control == null:
		return
	var target = control.get_parent() if control is HSlider else control  # sliders: the whole row
	var width = 400.0 if control is HSlider else control.size.x
	if control is Button:
		width = FONT.get_string_size(control.text, HORIZONTAL_ALIGNMENT_LEFT, -1, control.get_theme_font_size("font_size")).x
	var middle = target.global_position + target.size / 2
	marker_left.global_position = middle - Vector2(width / 2 + 46, -1)
	marker_right.global_position = middle + Vector2(width / 2 + 46, 1)


func _focus(control: Control) -> void:
	if control:
		control.grab_focus.call_deferred()  # deferred: the page may have just become visible


# ---------- easter egg: the scared Quit button ----------

func _check_quit_escape(mouse: Vector2) -> void:
	if quit_escapes >= QUIT_ESCAPES_UNTIL_TIRED or quit_moving or busy:
		return
	if is_instance_valid(quit_dialog) or current_page != "main":
		return
	if _quit_text_rect().grow(36).has_point(mouse):  # the cursor is getting close
		_quit_run_away(mouse)


# The area around the words "Quit Game" (the button itself is as wide as the menu column)
func _quit_text_rect() -> Rect2:
	var text_size = FONT.get_string_size(quit_button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22) + Vector2(20, 14)
	var middle = quit_button.global_position + quit_button.size / 2
	return Rect2(middle - text_size / 2, text_size)


func _quit_run_away(mouse: Vector2) -> void:
	if not quit_button.top_level:
		# Step out of the menu column so it can move freely (the other buttons stay put)
		var middle = quit_button.global_position + quit_button.size / 2
		quit_button.top_level = true
		quit_button.size = quit_button.get_combined_minimum_size()
		quit_button.global_position = middle - quit_button.size / 2
		quit_button.pivot_offset = quit_button.size / 2

	var spot = _find_hiding_spot(mouse)
	quit_escapes += 1
	quit_moving = true
	Sfx.play("quit_escape")
	Sfx.play("jump", 1.4)  # whoosh
	_taunt(QUIT_TAUNTS[quit_escapes - 1])

	# Dash to the new spot with a little overshoot...
	var lean = 1.0 if spot.x > quit_button.global_position.x else -1.0
	var run = create_tween()
	run.tween_property(quit_button, "global_position", spot, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	run.tween_callback(func():
		quit_moving = false
		if quit_escapes >= QUIT_ESCAPES_UNTIL_TIRED:
			_quit_give_up())
	# ...leaning, squashing and wobbling as it goes
	var wobble = create_tween()
	wobble.tween_property(quit_button, "rotation", 0.3 * lean, 0.1)
	wobble.parallel().tween_property(quit_button, "scale", Vector2(1.25, 0.8), 0.1)
	wobble.tween_property(quit_button, "rotation", -0.2 * lean, 0.12)
	wobble.parallel().tween_property(quit_button, "scale", Vector2(0.9, 1.15), 0.12)
	wobble.tween_property(quit_button, "rotation", 0.0, 0.2).set_trans(Tween.TRANS_SINE)
	wobble.parallel().tween_property(quit_button, "scale", Vector2.ONE, 0.2)


# A random spot on screen, away from the mouse, not on top of the title or the other buttons
func _find_hiding_spot(mouse: Vector2) -> Vector2:
	var area = get_viewport().get_visible_rect().grow(-24)
	var button_size = quit_button.size
	var blocked = [Rect2(position + Vector2(screen.x / 2 - 270, 64), Vector2(540, 196))]  # the title
	for button in main_buttons:
		if button != quit_button:
			blocked.append(button.get_global_rect().grow(14))

	var best = quit_button.global_position
	var best_distance = -1.0
	for attempt in 60:
		var spot = Vector2(
			randf_range(area.position.x, area.end.x - button_size.x),
			randf_range(area.position.y, area.end.y - button_size.y))
		var rect = Rect2(spot, button_size)
		if blocked.any(func(b): return b.intersects(rect)):
			continue
		var distance = rect.get_center().distance_to(mouse)
		if distance >= 240.0:
			return spot  # far enough: go!
		if distance > best_distance:
			best = spot
			best_distance = distance
	return best


func _quit_give_up() -> void:
	quit_button.mouse_filter = Control.MOUSE_FILTER_STOP  # now the mouse can click it
	Sfx.play("quit_tired")
	_taunt("*pant pant*  ...fine. You win.")
	var slump = create_tween()
	slump.tween_property(quit_button, "rotation", 0.25, 0.25).set_trans(Tween.TRANS_SINE)
	slump.parallel().tween_property(quit_button, "scale", Vector2(1.1, 0.8), 0.25)
	slump.parallel().tween_property(quit_button, "modulate", Color(0.75, 0.75, 0.85), 0.25)
	slump.tween_property(quit_button, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	slump.tween_property(quit_button, "rotation", 0.06, 0.6).set_trans(Tween.TRANS_SINE)  # stays a bit slumped
	slump.parallel().tween_property(quit_button, "modulate", Color.WHITE, 0.6)


# A little line of text that pops up by the Quit button and floats away
func _taunt(text: String) -> void:
	var view = get_viewport().get_visible_rect().size
	var line = _label(text, 15, GLOW, self)
	line.top_level = true
	line.add_theme_color_override("font_outline_color", Color("#07060C"))
	line.add_theme_constant_override("outline_size", 4)
	var spot = quit_button.global_position + Vector2(0, -28)
	line.global_position = Vector2(clamp(spot.x, 8, view.x - line.size.x - 8), max(spot.y, 8))
	line.modulate.a = 0.0
	var float_away = create_tween()
	float_away.tween_property(line, "modulate:a", 1.0, 0.1)
	float_away.parallel().tween_property(line, "global_position:y", line.global_position.y - 16, 1.0)
	float_away.tween_property(line, "modulate:a", 0.0, 0.4)
	float_away.tween_callback(line.queue_free)


# ---------- quit confirmation ----------

func _open_quit_dialog() -> void:
	if busy or is_instance_valid(quit_dialog):
		return  # only ever one window
	var view = get_viewport().get_visible_rect().size
	Sfx.play("talk", 0.7)

	quit_dialog = Control.new()
	quit_dialog.name = "QuitDialog"
	quit_dialog.top_level = true  # covers the whole window
	quit_dialog.size = view
	add_child(quit_dialog)

	quit_shade = _rect(Vector2.ZERO, view, Color(0.01, 0.01, 0.03, 0.0), quit_dialog)
	quit_shade.mouse_filter = Control.MOUSE_FILTER_STOP  # blocks clicks on the menu behind

	quit_panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.05, 0.085, 0.97)
	style.border_color = Color("#7985AB")
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(28)
	style.content_margin_top = 40
	quit_panel.add_theme_stylebox_override("panel", style)
	quit_dialog.add_child(quit_panel)
	quit_ornament = _ornament(Ornament.Kind.TOP, Vector2.ZERO, quit_dialog)
	quit_ornament.scale = Vector2(0.9, 0.9)

	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	quit_panel.add_child(box)
	var question = _label("Are you absolutely sure you want to leave The Between?", 22, WHITE, box)
	question.custom_minimum_size = Vector2(500, 0)
	question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var countdown = _label("Leaving available in %d..." % QUIT_COUNTDOWN, 15, DIM, box)
	countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 110)
	box.add_child(row)
	var stay = _menu_button(row, "Stay", _close_quit_dialog)
	var leave = _menu_button(row, "Leave", _on_quit)
	leave.name = "Leave"
	leave.disabled = true
	leave.focus_mode = Control.FOCUS_NONE  # can't be selected until the countdown ends
	leave.add_theme_color_override("font_disabled_color", Color(DIM, 0.35))

	# Keyboard/controller focus stays inside the window: Left/Right swap, Up/Down/Tab stay put
	for button in [stay, leave]:
		var other = leave if button == stay else stay
		for side in ["focus_neighbor_top", "focus_neighbor_bottom", "focus_next", "focus_previous"]:
			button.set(side, button.get_path_to(button))
		button.focus_neighbor_left = button.get_path_to(other)
		button.focus_neighbor_right = button.get_path_to(other)

	quit_panel.resized.connect(_center_quit_panel)
	_center_quit_panel()

	# The countdown: a Timer ticks every second. It belongs to the window, so it stops when the window closes.
	quit_seconds_left = QUIT_COUNTDOWN
	var timer = Timer.new()
	timer.name = "Countdown"
	timer.wait_time = 1.0
	quit_dialog.add_child(timer)
	timer.timeout.connect(func():
		quit_seconds_left -= 1
		if quit_seconds_left > 0:
			countdown.text = "Leaving available in %d..." % quit_seconds_left
		else:
			timer.stop()
			countdown.text = "The way out is open."
			leave.text = "Leave The Between"
			leave.disabled = false
			leave.focus_mode = Control.FOCUS_ALL
			Sfx.play("checkpoint", 0.8))
	timer.start()

	# The markers and the black fade stay on top of the window
	move_child(marker_left, -1)
	move_child(marker_right, -1)
	move_child(fade, -1)

	# Fade in and pop up
	quit_panel.modulate.a = 0.0
	quit_panel.scale = Vector2(0.85, 0.85)
	var appear = create_tween()
	appear.tween_property(quit_shade, "color:a", 0.7, 0.25)
	appear.parallel().tween_property(quit_panel, "modulate:a", 1.0, 0.25)
	appear.parallel().tween_property(quit_panel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_focus(stay)


func _center_quit_panel() -> void:
	var view = get_viewport().get_visible_rect().size
	quit_panel.position = ((view - quit_panel.size) / 2).round()
	quit_panel.pivot_offset = quit_panel.size / 2
	quit_ornament.position = quit_panel.position + Vector2(quit_panel.size.x / 2, 0)


# Stay: close the window straight away (and stop the countdown)
func _close_quit_dialog() -> void:
	if not is_instance_valid(quit_dialog):
		return
	var dialog = quit_dialog
	quit_dialog = null
	dialog.get_node("Countdown").stop()
	quit_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Sfx.play("talk", 0.8)
	var close = create_tween()
	close.tween_property(dialog, "modulate:a", 0.0, 0.15)
	close.tween_callback(dialog.queue_free)
	_focus(quit_button)


# ---------- building blocks ----------

func _page() -> VBoxContainer:
	var page = VBoxContainer.new()
	page.position = Vector2(screen.x / 2 - 260, 300)
	page.size = Vector2(520, 0)
	page.alignment = BoxContainer.ALIGNMENT_BEGIN
	page.add_theme_constant_override("separation", 1)
	add_child(page)
	return page


func _menu_button(page: Control, text: String, action: Callable) -> Button:
	var button = Button.new()
	button.text = text
	button.flat = true
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 22)
	for state in ["font_color", "font_disabled_color"]:
		button.add_theme_color_override(state, DIM)
	for state in ["font_hover_color", "font_focus_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(state, WHITE)
	button.add_theme_color_override("font_pressed_color", GLOW)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.pressed.connect(action)
	button.mouse_entered.connect(func():
		if button.focus_mode != Control.FOCUS_NONE:  # the locked Leave button can't take focus
			button.grab_focus())
	# Small "press in" when clicked
	button.button_down.connect(func():
		button.pivot_offset = button.size / 2
		create_tween().tween_property(button, "scale", Vector2(0.94, 0.94), 0.06))
	button.button_up.connect(func(): create_tween().tween_property(button, "scale", Vector2.ONE, 0.12))
	page.add_child(button)
	return button


func _slider_row(page: Control, text: String, value: float, on_change: Callable) -> HSlider:
	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	page.add_child(row)

	var label = _label(text, 22, DIM, row)
	label.custom_minimum_size = Vector2(110, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var slider = HSlider.new()
	slider.custom_minimum_size = Vector2(220, 30)
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.focus_mode = Control.FOCUS_ALL
	var line = StyleBoxFlat.new()
	line.bg_color = Color(DIM, 0.5)
	line.content_margin_top = 1
	line.content_margin_bottom = 1
	var filled = StyleBoxFlat.new()
	filled.bg_color = GLOW
	filled.content_margin_top = 1
	filled.content_margin_bottom = 1
	slider.add_theme_stylebox_override("slider", line)
	slider.add_theme_stylebox_override("grabber_area", filled)
	slider.add_theme_stylebox_override("grabber_area_highlight", filled)
	var knob = _diamond_texture()
	slider.add_theme_icon_override("grabber", knob)
	slider.add_theme_icon_override("grabber_highlight", knob)
	slider.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	slider.value_changed.connect(on_change)
	slider.mouse_entered.connect(slider.grab_focus)
	slider.focus_entered.connect(func(): label.add_theme_color_override("font_color", WHITE))
	slider.focus_exited.connect(func(): label.add_theme_color_override("font_color", DIM))
	row.add_child(slider)
	return slider


func _label(text: String, font_size: int, color: Color, parent: Node) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _ornament(kind: int, pos: Vector2, parent: Node) -> Control:
	var ornament = Ornament.new()
	ornament.kind = kind
	ornament.position = pos
	ornament.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(ornament)
	return ornament


func _build_corner_text() -> void:
	corner_left = _label("Hackathon build", 13, Color(DIM, 0.7), self)
	corner_right = _label("Haven Sydney", 13, Color(DIM, 0.7), self)
	corner_right.size = Vector2(122, 20)
	corner_right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func _rect(pos: Vector2, rect_size: Vector2, color: Color, parent: Node) -> ColorRect:
	var rect = ColorRect.new()
	rect.position = pos
	rect.size = rect_size
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	return rect


# A rectangle filled with a gradient (top to bottom, or left to right when sideways)
func _gradient_rect(pos: Vector2, rect_size: Vector2, colors: Array, sideways: bool) -> TextureRect:
	var gradient = Gradient.new()
	gradient.colors = PackedColorArray(colors)
	if colors.size() == 3:
		gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	var texture = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(1, 0) if sideways else Vector2(0, 1)
	var rect = TextureRect.new()
	rect.texture = texture
	rect.position = pos
	rect.size = rect_size
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	return rect


# A soft round blob of colour (centre colour fading to the edge colour)
func _glow(center: Vector2, glow_size: Vector2, inner: Color, outer: Color = Color(0, 0, 0, 0)) -> TextureRect:
	var gradient = Gradient.new()
	gradient.colors = PackedColorArray([inner, outer])
	var texture = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	var rect = TextureRect.new()
	rect.texture = texture
	rect.size = glow_size
	rect.position = center - glow_size / 2
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	return rect


# The slider knob: a small white diamond
func _diamond_texture() -> ImageTexture:
	var image = Image.create(13, 13, false, Image.FORMAT_RGBA8)
	for x in 13:
		for y in 13:
			if abs(x - 6) + abs(y - 6) <= 6:
				image.set_pixel(x, y, WHITE)
	return ImageTexture.create_from_image(image)
