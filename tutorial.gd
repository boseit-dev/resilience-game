extends "res://level_1.gd"

# RESILIENCE - TUTORIAL (training course, separate from the story)
# Uses all of Level 1's rules (level_1.gd: HUD, lives, pads, checkpoints, enemies, chests)
# with these training changes:
#   - each power is switched on when you reach its section (no deaths needed)
#   - you can't run out of lives, and Bounce Pads refill when you run out
#   - it never changes the story save
#   - at the end: TUTORIAL COMPLETE, with Main Menu / Start New Game
# The course itself (ground, signs, enemies) is in tutorial_map.gd.

const CALM_MUSIC = preload("res://assets/music/intro_theme.wav")
const FINISH_X = 7560.0

# SECTIONS: [starts at x, title, power switched on there]
const SECTIONS = [
	[-1000, "1 · MOVING  ·  A / D  or  ← →", ""],
	[700, "2 · JUMPING  ·  W / SPACE / ↑", ""],
	[1600, "3 · BOUNCE PADS  ·  PRESS E", "pad"],
	[2600, "4 · DOUBLE JUMP  ·  JUMP AGAIN IN MID-AIR", "double_jump"],
	[3800, "5 · DASH  ·  PRESS SHIFT", "dash"],
	[4600, "6 · COMBAT  ·  JUMP ON THEIR HEADS", ""],
	[5600, "7 · LIVES AND CHECKPOINTS", ""],
	[6200, "8 · FINAL CHALLENGE", ""],
]

var section = -1
var finished = false
var complete_screen: Control


func _ready() -> void:
	death_powers = false   # here each power switches on at its section instead
	level_title = "TUTORIAL"
	music = CALM_MUSIC     # soft music for training
	super._ready()
	# The camera stops at the outer edges of the rock at both ends (tutorial_map.gd), so you never see empty space
	var camera = player.get_node("Camera2D")
	camera.limit_left = -700
	camera.limit_right = 8400


func _process(delta: float) -> void:
	super._process(delta)
	if finished:
		return
	var x = player.global_position.x
	while section + 1 < SECTIONS.size() and x >= SECTIONS[section + 1][0]:
		section += 1
		_start_section(SECTIONS[section])
	# Training pads: run out and you get 3 more (placed pads still stay where they are)
	if pad_unlocked and pads_remaining <= 0 and not respawning:
		pads_remaining = MAX_PADS
		_show_banner("TRAINING PADS REFILLED")
		_update_hud()
	if x >= FINISH_X and player.is_on_floor():
		_finish()


func _start_section(s: Array) -> void:
	match s[2]:
		"pad":
			pad_unlocked = true
		"double_jump":
			player.double_jump_unlocked = true
		"dash":
			player.dash_unlocked = true
	if s[2] != "":
		Sfx.play("unlock")
	_show_banner(s[1])
	_update_hud()


# Training: you can never run out of lives (the last one is given straight back)
func _lose_life() -> void:
	if not respawning and lives <= 1:
		lives = 2
		get_tree().create_timer(1.0).timeout.connect(func():
			if is_inside_tree():
				lives = MAX_LIVES
				shown_lives = lives
				_show_banner("TRAINING: LIVES REFILLED")
				_update_hud())
	super._lose_life()


# ---------- TUTORIAL COMPLETE ----------

func _finish() -> void:
	finished = true
	player.set_physics_process(false)
	player.velocity = Vector2.ZERO
	Sfx.play("portal_open")

	complete_screen = Control.new()
	complete_screen.name = "TutorialComplete"
	complete_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	complete_screen.modulate.a = 0.0
	hud_layer.add_child(complete_screen)
	var shade = ColorRect.new()
	shade.color = Color(0.02, 0.02, 0.05, 0.85)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	complete_screen.add_child(shade)

	var column = _center_column(complete_screen)
	var title = _screen_label("TUTORIAL COMPLETE", 46, BRIGHT, column)
	title.add_theme_color_override("font_outline_color", Color(GLOW, 0.4))
	title.add_theme_constant_override("outline_size", 12)
	_screen_label("You know everything you need. In the story, powers come from falling.", 16, Color("#8D97B3"), column)
	_screen_label(" ", 8, BRIGHT, column)

	var story_text = "Continue Story" if SaveGame.has_progress() else "Start New Game"
	var story = _finish_button(story_text, column, _start_story)
	_finish_button("Main Menu", column, func(): _leave("res://main_menu.tscn"))
	story.grab_focus.call_deferred()
	create_tween().tween_property(complete_screen, "modulate:a", 1.0, 0.6)


func _finish_button(text: String, parent: Control, action: Callable) -> Button:
	var button = Button.new()
	button.text = text
	button.flat = true
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_color_override("font_color", Color("#8D97B3"))
	for state in ["font_hover_color", "font_focus_color"]:
		button.add_theme_color_override(state, BRIGHT)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.pressed.connect(action)
	button.mouse_entered.connect(button.grab_focus)
	button.focus_entered.connect(func(): Sfx.play("talk", 1.3))
	parent.add_child(button)
	return button


# Start New Game starts the story from the lab; Continue Story keeps the save as it is
func _start_story() -> void:
	if not SaveGame.has_progress():
		SaveGame.start_new_game()
		_leave(SaveGame.STORY_START)
	else:
		_leave(SaveGame.level_scene(SaveGame.current_level))


func _leave(scene: String) -> void:
	Sfx.play("checkpoint")
	hud_layer.move_child(fade_rect, -1)   # the black fade goes over the TUTORIAL COMPLETE screen
	var out = create_tween()
	out.tween_property(fade_rect, "modulate:a", 1.0, 0.6)
	out.tween_callback(func(): get_tree().change_scene_to_file(scene))
