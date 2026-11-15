extends Area2D

# RESILIENCE - TREASURE CHEST
# Walk up and press E: the lid swings open and you get a random reward (level_1.gd give_reward).
# A chest opens once per run: it stays open when you die, and closes again on Game Over
# (the level reloads). Next to a chest, E opens it instead of placing a bounce pad.
#
# Rewards and their chances: bigger number = more likely. Useless ones are skipped
# (no heart when your lives are full, no pad before you have the Bounce Pad, and so on).

const REWARDS = {"pad": 30, "heart": 25, "speed": 20, "dash": 15, "shield": 10}
const FONT = preload("res://assets/fonts/Cinzel.ttf")

# The chest is drawn from these little pixel maps (one letter = one pixel)
const COLORS = {
	"K": Color("#1E1410"), "B": Color("#5A3420"), "W": Color("#8A5230"),
	"L": Color("#B8743A"), "G": Color("#D8A443"), "Y": Color("#FFE08A"),
}
const LID = [
	"..KKKKKKKKKKKK..",
	".KLLLLLLLLLLLLK.",
	"KLWWWWWWWWWWWWLK",
	"KGGGGGGYYGGGGGGK",
]
const BODY = [
	"KBBBBBBGGBBBBBBK",
	"KWWWWWWYYWWWWWWK",
	"KWWWWWWGGWWWWWWK",
	"KWWWWWWWWWWWWWWK",
	"KGWWWWWWWWWWWWGK",
	"KBBBBBBBBBBBBBBK",
	".KKKKKKKKKKKKKK.",
]

var opened = false
var player_near = false
var lid: Sprite2D
var prompt: Label
var glow: PointLight2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	var zone = CollisionShape2D.new()
	zone.shape = RectangleShape2D.new()
	zone.shape.size = Vector2(44, 34)
	zone.position = Vector2(0, -14)
	add_child(zone)

	var body = Sprite2D.new()
	body.texture = _pixel_texture(BODY)
	body.position = Vector2(0, -BODY.size() / 2.0)
	add_child(body)
	lid = Sprite2D.new()
	lid.texture = _pixel_texture(LID)
	lid.centered = false
	lid.offset = Vector2(0, -LID.size())      # pivot = the lid's back-bottom corner (the hinge)
	lid.position = Vector2(-8, -BODY.size())
	add_child(lid)

	# A faint golden glow so chests can be spotted in the dark (stronger when opened)
	glow = PointLight2D.new()
	glow.texture = _soft_dot()
	glow.color = Color("#FFD27A")
	glow.energy = 0.5
	glow.texture_scale = 0.6
	glow.position = Vector2(0, -8)
	add_child(glow)

	prompt = Label.new()
	prompt.text = "E  OPEN"
	prompt.add_theme_font_override("font", FONT)
	prompt.add_theme_font_size_override("font_size", 9)
	prompt.add_theme_color_override("font_color", Color("#E8F5FF"))
	prompt.add_theme_color_override("font_outline_color", Color("#07060C"))
	prompt.add_theme_constant_override("outline_size", 3)
	prompt.position = Vector2(-18, -34)
	prompt.visible = false
	add_child(prompt)

	body_entered.connect(func(b): if b.name == "Player": _set_near(true))
	body_exited.connect(func(b): if b.name == "Player": _set_near(false))


func _set_near(near: bool) -> void:
	player_near = near
	prompt.visible = near and not opened


# E next to a closed chest opens it (and stops the level from also placing a pad)
func _unhandled_key_input(event: InputEvent) -> void:
	if player_near and not opened and event.pressed and not event.echo and event.physical_keycode == KEY_E:
		get_viewport().set_input_as_handled()
		open()


func open() -> void:
	if opened:
		return
	opened = true
	prompt.visible = false
	Sfx.play("chest_open")
	var level = get_tree().current_scene
	var reward = pick_reward(level)

	# Lid swings back, light bursts out, sparkles rise
	var swing = create_tween()
	swing.tween_property(lid, "rotation_degrees", -100.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	swing.parallel().tween_property(glow, "energy", 2.2, 0.2)
	swing.tween_property(glow, "energy", 0.9, 0.8)
	var sparkle = CPUParticles2D.new()
	sparkle.position = Vector2(0, -8)
	sparkle.emitting = true
	sparkle.one_shot = true
	sparkle.explosiveness = 0.8
	sparkle.amount = 24 if reward in ["heart", "shield"] else 14  # rarer rewards sparkle more
	sparkle.lifetime = 0.9
	sparkle.direction = Vector2(0, -1)
	sparkle.spread = 35.0
	sparkle.initial_velocity_min = 40.0
	sparkle.initial_velocity_max = 90.0
	sparkle.gravity = Vector2(0, 40)
	sparkle.scale_amount_min = 1.5
	sparkle.scale_amount_max = 2.5
	sparkle.color = Color("#FFE08A")
	add_child(sparkle)
	level.give_reward(reward)


# Weighted random pick, leaving out rewards that would be useless right now
func pick_reward(level: Node) -> String:
	var choices = REWARDS.duplicate()
	if level.lives >= level.MAX_LIVES:
		choices.erase("heart")
	if not level.pad_unlocked:
		choices.erase("pad")
	if not level.player.dash_unlocked:
		choices.erase("dash")
	if level.player.has_shield:
		choices.erase("shield")
	var total = 0
	for weight in choices.values():
		total += weight
	var roll = randi_range(1, total)
	for reward in choices:
		roll -= choices[reward]
		if roll <= 0:
			return reward
	return "speed"  # never reached ("speed" is always allowed)


func _pixel_texture(rows: Array) -> ImageTexture:
	var image = Image.create(rows[0].length(), rows.size(), false, Image.FORMAT_RGBA8)
	for y in rows.size():
		for x in rows[y].length():
			var c = rows[y][x]
			image.set_pixel(x, y, COLORS[c] if COLORS.has(c) else Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(image)


func _soft_dot() -> GradientTexture2D:
	var dot = GradientTexture2D.new()
	dot.width = 64
	dot.height = 64
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(0.5, 0.0)
	dot.gradient = Gradient.new()
	dot.gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	return dot
