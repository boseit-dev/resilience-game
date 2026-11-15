extends Node

# RESILIENCE - LEVEL 2 OPENING (about 18 seconds, SPACE or ENTER skips)
# The scientist walks into the dark lab, a terminal wakes up with a warning, something
# mechanical booms in the distance, then "CHAPTER II" appears and you get control.
# It only plays the first time the level loads this session (not after deaths or Game Over).

const TERMINAL_TEXT = "> SECURITY LOG 7\n> PROTOTYPE UNIT: ACTIVE\n> WARNING: EXPERIMENTAL GUARDIAN\n  NOT CONTAINED"
const TITLE = "CHAPTER II  —  FORGOTTEN LABORATORIES"
static var seen = false

@export var terminal_position = Vector2(260, 330)
var level: Node
var steps: Tween
var bars: CanvasLayer
var terminal: Label


func _ready() -> void:
	if seen:
		queue_free()
		return
	seen = true
	_start.call_deferred()   # after the level has made its HUD


func _start() -> void:
	level = get_parent()
	var player = level.player
	var end = player.global_position
	player.set_physics_process(false)
	player.global_position = end - Vector2(220, 0)
	player.reset_physics_interpolation()
	level.banner.modulate.a = 0.0
	level.hud_layer.hide()

	bars = CanvasLayer.new()   # black film bars top and bottom
	add_child(bars)
	for top in [true, false]:
		var bar = ColorRect.new()
		bar.color = Color.BLACK
		bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
		bar.custom_minimum_size.y = 70
		bar.grow_vertical = Control.GROW_DIRECTION_END if top else Control.GROW_DIRECTION_BEGIN
		bars.add_child(bar)

	terminal = Label.new()   # the computer screen text, typed out
	terminal.text = TERMINAL_TEXT
	terminal.visible_ratio = 0.0
	terminal.add_theme_font_size_override("font_size", 8)
	terminal.add_theme_color_override("font_color", Color(0.55, 1.6, 1.8))
	terminal.position = terminal_position + Vector2(-60, -70)
	level.add_child(terminal)

	var camera = player.get_node("Camera2D")
	steps = create_tween()
	steps.tween_property(player, "global_position", end - Vector2(60, 0), 4.0)            # walk in
	steps.tween_callback(Sfx.play.bind("unlock", 0.6))                                   # the terminal wakes
	steps.tween_property(terminal, "visible_ratio", 1.0, 3.5)
	steps.tween_interval(1.0)
	steps.tween_callback(func():                                                         # a mechanical boom
		Sfx.play("warden_hit", 0.5)
		var shake = create_tween()
		for i in 6:
			shake.tween_property(camera, "offset", Vector2(randf_range(-4, 4), randf_range(-3, 3)), 0.06)
		shake.tween_property(camera, "offset", Vector2.ZERO, 0.06))
	steps.tween_interval(1.5)
	steps.tween_property(camera, "offset", Vector2(120, 0), 2.0).set_trans(Tween.TRANS_SINE)   # look ahead
	steps.tween_property(player, "global_position", end, 1.5)
	steps.tween_callback(func():
		level.hud_layer.show()
		level._show_banner(TITLE)
		Sfx.play("portal_open"))
	steps.tween_property(camera, "offset", Vector2.ZERO, 1.5).set_trans(Tween.TRANS_SINE)
	steps.tween_interval(2.0)
	steps.tween_callback(_finish)


func _unhandled_input(event: InputEvent) -> void:
	if steps and event is InputEventKey and event.pressed and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		get_viewport().set_input_as_handled()
		_finish()


func _finish() -> void:
	if steps == null:
		return
	steps.kill()
	steps = null
	var player = level.player
	player.global_position = level.spawn_position
	player.reset_physics_interpolation()
	player.get_node("Camera2D").offset = Vector2.ZERO
	var fade = terminal.create_tween()   # the warning goes away, so it never covers a speech bubble
	fade.tween_property(terminal, "modulate:a", 0.0, 0.6)
	fade.tween_callback(terminal.queue_free)
	level.hud_layer.show()
	level._show_banner(TITLE)
	bars.queue_free()
	get_tree().create_timer(0.25).timeout.connect(player.set_physics_process.bind(true))   # so the skip key doesn't also jump
