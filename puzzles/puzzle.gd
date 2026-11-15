extends Node2D

# RESILIENCE - PUZZLE (the part every Level 3 puzzle shares)
# A puzzle script extends this one. The map gives it a "data" table (see level_3_map.gd) with:
#   opens   what it opens when solved: [["door", 0], ["zapper", 2], ...] (anything with open()/close())
#   area    [left, top, right, bottom]: while you stand in here unsolved, hints appear
#   hints   three lines: a vague clue, a clearer one, then the answer (40, 80 and 120 s in)
#   reset   where the reset lever stands (press E to put the puzzle back to its start)
# Things you press E at are "spots": add_spot(position, what_to_call).

const HINT_AFTER = [40.0, 80.0, 120.0]
const USE_DISTANCE = 28.0
const LEVER = preload("res://assets/kenney_pixel-platformer/Tiles/tile_0064.png")
const GEM = preload("res://assets/kenney_pixel-platformer/Tiles/tile_0067.png")

var data = {}
var level: Node
var targets = []
var solved = false
var stuck_time = 0.0
var hints_shown = 0
var spots = []          # [position, callable]
var prompt: Label
var hint_label: Label


func _ready() -> void:
	targets = data.get("opens", []).map(func(ref): return get_parent().made[ref[0]][ref[1]])
	prompt = _text("E", Vector2.ZERO, Color(1, 1, 1, 0.9))
	prompt.hide()
	var area = data.get("area", [0, 0, 0, 0])
	hint_label = _text("", Vector2(area[0] + 10, area[1] + 6), Color(0.8, 0.75, 1.0, 0.9))
	if data.has("reset"):
		add_spot(data.reset, reset)
		_sprite(LEVER, data.reset + Vector2(0, -9), Color(0.8, 0.8, 1.0))
		_text("RESET", data.reset + Vector2(-14, -34), Color(0.7, 0.7, 0.85, 0.8))


func add_spot(at: Vector2, action: Callable) -> void:
	spots.append([at, action])


func _nearest_spot():
	var me = level.player.global_position
	var best = null
	for s in spots:
		if s[0].distance_to(me) < USE_DISTANCE and (best == null or s[0].distance_to(me) < best[0].distance_to(me)):
			best = s
	return best


func _process(delta: float) -> void:
	var spot = _nearest_spot()
	prompt.visible = spot != null
	if spot:
		prompt.position = spot[0] + Vector2(-3, -40)
	var a = data.get("area", [0, 0, 0, 0])
	if solved or not Rect2(a[0], a[1], a[2] - a[0], a[3] - a[1]).has_point(level.player.global_position):
		return
	stuck_time += delta
	if hints_shown < data.get("hints", []).size() and stuck_time > HINT_AFTER[hints_shown]:
		hint_label.text = data.hints[hints_shown]
		hints_shown += 1
		Sfx.play("talk", 0.8)


func _unhandled_key_input(event: InputEvent) -> void:
	if event.pressed and not event.echo and event.physical_keycode == KEY_E:
		var spot = _nearest_spot()
		if spot:
			get_viewport().set_input_as_handled()   # so E doesn't also place a Bounce Pad
			spot[1].call()


func solve() -> void:
	if solved:
		return
	solved = true
	hint_label.hide()
	for t in targets:
		t.open()
	Sfx.play("unlock")
	level._show_banner(data.get("solved_text", "SOMETHING OPENED"))


func reset() -> void:   # each puzzle adds its own reset on top
	Sfx.play("pad_place", 0.7)
	level._show_banner("PUZZLE RESET")


func _sprite(texture: Texture2D, at: Vector2, color := Color.WHITE) -> Sprite2D:
	var s = Sprite2D.new()
	s.texture = texture
	s.position = at
	s.modulate = color
	add_child(s)
	return s


func _text(words: String, at: Vector2, color: Color) -> Label:
	var label = Label.new()
	label.text = words
	label.position = at
	label.z_index = 5
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.05))
	label.add_theme_constant_override("outline_size", 3)
	add_child(label)
	return label
