
extends Node2D

# RESILIENCE - LEVEL 1

const MAX_LIVES = 5
const MAX_PADS = 3
const PAD_LAUNCH_SPEED = -520.0

const PAD_TEXTURE = preload(
    "res://assets/kenney_pixel-platformer/Tiles/tile_0148.png"
)

const FACE_TEXTURE = preload(
    "res://assets/kenney_pixel-platformer/Tiles/Characters/tile_0002.png"
)

const BRIGHT = Color("#E8F5FF")
const GLOW = Color("#83D9FF")
const DIM = Color("#394256")
const FONT = preload("res://assets/fonts/Cinzel.ttf")

# The three NPCs who each teach a power (1 = Bounce Pad, 2 = Double Jump, 3 = Dash).
# Walking past one starts its lesson: your next death unlocks that power,
# and your lives are topped up to what a perfect run would have by then.
const LESSONS = {"SABLE": 1, "TOMAS": 2, "IVY": 3}

var lives = MAX_LIVES
var deaths = 0
var pads_remaining = MAX_PADS
var respawning = false
var restart_armed = false   # R was pressed once; a second press within 2 s restarts
var pad_unlocked = false
var lesson = 0   # the latest lesson reached (see LESSONS)

var placed_pads: Array[Area2D] = []

@onready var player = $Player
@onready var spawn_position = player.global_position

var life_icons: Array[TextureRect] = []
var shown_lives = MAX_LIVES          # so the HUD knows when a life was just lost
var power_rows: Array[Control] = []  # pad, double jump, dash (hidden until unlocked)
var pad_counter: Label
var banner: Label
var banner_tween: Tween


func _ready() -> void:
	_create_hud()
	_update_hud()
	add_child(preload("res://pause_menu.gd").new())  # Esc / P / Start pauses
	_show_banner("LEVEL 1  ·  THE ARRIVAL")
	Sfx.start_ambience()

	# Every lantern in the "checkpoint" group becomes a respawn point
	for checkpoint in get_tree().get_nodes_in_group("checkpoint"):
		checkpoint.body_entered.connect(
			_on_checkpoint_body_entered.bind(checkpoint)
		)


# SMALL COMPACT HUD

func _create_hud() -> void:
	var layer = CanvasLayer.new()
	layer.name = "HUD"
	layer.layer = 10
	add_child(layer)

	# A soft dark shadow in the corner, so the HUD is readable over anything
	var shade_colors = Gradient.new()
	shade_colors.colors = PackedColorArray([Color(0.02, 0.02, 0.05, 0.75), Color(0.02, 0.02, 0.05, 0.0)])
	var shade_texture = GradientTexture2D.new()
	shade_texture.gradient = shade_colors
	shade_texture.fill = GradientTexture2D.FILL_RADIAL
	shade_texture.fill_from = Vector2(0, 0)
	shade_texture.fill_to = Vector2(1, 0)
	var shade = TextureRect.new()
	shade.texture = shade_texture
	shade.size = Vector2(420, 240)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(shade)

	# Lives: one mask per life
	var lives_row = HBoxContainer.new()
	lives_row.position = Vector2(22, 18)
	lives_row.add_theme_constant_override("separation", 6)
	layer.add_child(lives_row)
	for i in range(MAX_LIVES):
		var icon = TextureRect.new()
		icon.texture = FACE_TEXTURE
		icon.custom_minimum_size = Vector2(30, 30)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		lives_row.add_child(icon)
		life_icons.append(icon)

	# Powers: each one appears (with its key) once you unlock it
	var powers = VBoxContainer.new()
	powers.position = Vector2(24, 60)
	powers.add_theme_constant_override("separation", 6)
	layer.add_child(powers)
	power_rows.append(_power_row(powers, "E", "BOUNCE PAD"))
	power_rows.append(_power_row(powers, "SPACE", "DOUBLE JUMP  ·  IN MID-AIR"))
	power_rows.append(_power_row(powers, "SHIFT", "DASH"))
	pad_counter = power_rows[0].get_child(1)

	# Messages (level title, unlocks) at the top in the middle
	banner = Label.new()
	banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	banner.offset_top = 20
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_font_override("font", FONT)
	banner.add_theme_font_size_override("font_size", 22)
	banner.add_theme_color_override("font_color", BRIGHT)
	banner.add_theme_color_override("font_outline_color", Color("#07060C"))
	banner.add_theme_constant_override("outline_size", 6)
	banner.modulate.a = 0.0
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(banner)


# One power line: a little key, then what it does. Hidden until unlocked.
func _power_row(parent: Control, key_name: String, text: String) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.visible = false
	parent.add_child(row)

	var key = Label.new()
	key.text = key_name
	key.add_theme_font_size_override("font_size", 13)
	key.add_theme_color_override("font_color", BRIGHT)
	var box = StyleBoxFlat.new()
	box.bg_color = Color(0.07, 0.08, 0.14, 0.9)
	box.border_color = GLOW
	box.set_border_width_all(1)
	box.border_width_bottom = 3  # thick bottom edge = looks like a key
	box.set_corner_radius_all(3)
	box.set_content_margin_all(5)
	box.content_margin_top = 1
	box.content_margin_bottom = 2
	key.add_theme_stylebox_override("normal", box)
	row.add_child(key)

	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", GLOW)
	label.add_theme_color_override("font_outline_color", Color("#07060C"))
	label.add_theme_constant_override("outline_size", 4)
	row.add_child(label)
	return row


# UPDATE HUD

func _update_hud() -> void:
	for i in range(MAX_LIVES):
		life_icons[i].modulate = BRIGHT if i < lives else Color(DIM, 0.5)

	# A life was just lost: that mask pops before going dark
	if lives < shown_lives and lives >= 0:
		var lost = life_icons[lives]
		lost.pivot_offset = lost.size / 2.0
		lost.scale = Vector2(1.6, 1.6)
		lost.modulate = Color(1.0, 0.45, 0.45)
		var pop = create_tween()
		pop.tween_property(lost, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		pop.parallel().tween_property(lost, "modulate", Color(DIM, 0.5), 0.6)
	shown_lives = lives

	_show_power(power_rows[0], pad_unlocked)
	_show_power(power_rows[1], player.double_jump_unlocked)
	_show_power(power_rows[2], player.dash_unlocked)
	pad_counter.text = "BOUNCE PAD  ·  %d LEFT" % pads_remaining
	pad_counter.modulate = Color.WHITE if pads_remaining > 0 else Color(1, 1, 1, 0.4)


# Fade a power line in the first time it's unlocked
func _show_power(row: Control, unlocked: bool) -> void:
	if unlocked and not row.visible:
		row.visible = true
		row.modulate.a = 0.0
		create_tween().tween_property(row, "modulate:a", 1.0, 0.3)


# KEYBOARD CONTROLS

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and not event.echo:

			if event.physical_keycode == KEY_E:
				_place_jump_pad()

			elif event.physical_keycode == KEY_R:
				# Ask twice, so one accidental press doesn't throw away the whole run
				if restart_armed:
					get_tree().call_deferred("reload_current_scene")
				else:
					restart_armed = true
					_show_banner("PRESS R AGAIN TO RESTART")
					get_tree().create_timer(2.0).timeout.connect(func(): restart_armed = false)


# PERMANENT JUMP PAD

func _place_jump_pad() -> void:
	if respawning or not pad_unlocked:
		return

	if pads_remaining <= 0:
		return

	if not player.is_on_floor():
		return

	# No room (a wall or the ground is where the pad would go): don't waste a pad
	var spot = player.global_position + Vector2(player.facing_direction * 55, 12)
	if _is_blocked(spot + Vector2(0, -11), Vector2(70, 16)):
		_show_banner("NO ROOM FOR A PAD HERE")
		return

	var pad = Area2D.new()
	pad.name = "PermanentBouncePad"
	pad.collision_layer = 0
	pad.collision_mask = player.collision_layer
	pad.monitoring = true

	add_child(pad)

	pad.global_position = spot

	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()

	shape.size = Vector2(74, 24)
	collision.shape = shape
	collision.position = Vector2(0, -11)

	pad.add_child(collision)

	for i in range(4):
		var sprite = Sprite2D.new()
		sprite.texture = PAD_TEXTURE
		sprite.texture_filter = (
			CanvasItem.TEXTURE_FILTER_NEAREST
		)
		sprite.position = Vector2(
			-27 + i * 18, -9  # half the 18 px tile, so the pad sits on the floor
		)
		pad.add_child(sprite)

	pad.body_entered.connect(
		_on_jump_pad_body_entered
	)

	placed_pads.append(pad)
	pads_remaining -= 1
	Sfx.play("pad_place")

	_update_hud()


# Is any solid thing (wall, ground, platform) inside this box? (box centre and size)
func _is_blocked(center: Vector2, box_size: Vector2) -> bool:
	var box = RectangleShape2D.new()
	box.size = box_size
	var query = PhysicsShapeQueryParameters2D.new()
	query.shape = box
	query.transform = Transform2D(0.0, center)
	query.collision_mask = player.collision_mask
	query.exclude = [player.get_rid()]
	return not get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


# PAD BOUNCE

func _on_jump_pad_body_entered(body: Node2D) -> void:
	if body != player or respawning:
		return

	if player.velocity.y < 0.0:
		return

	player.velocity.y = PAD_LAUNCH_SPEED
	Sfx.play("pad_bounce")


# SPIKES

func _on_spikes_body_entered(body: Node2D) -> void:
	if body == player:
		_lose_life()


# FALL DETECTION

func _process(_delta: float) -> void:
	if player.global_position.y > 900:
		_lose_life()
	_check_lessons()


# LESSONS: reaching a teaching NPC

func _check_lessons() -> void:
	for npc in $Npcs.get_children():
		var number = LESSONS.get(npc.npc_name, 0)
		if number > lesson and player.global_position.x > npc.global_position.x - 40:
			lesson = number
			_top_up_lives()


# Give back lives lost to mistakes: a perfect run has lost one life per power so far
func _top_up_lives() -> void:
	var powers = int(pad_unlocked) + int(player.double_jump_unlocked) + int(player.dash_unlocked)
	var fair_lives = MAX_LIVES - powers
	if lives < fair_lives:
		lives = fair_lives
		shown_lives = lives
		_show_banner("LIVES RESTORED")
		Sfx.play("checkpoint")
		_update_hud()


# LIVES AND UNLOCKS

func _lose_life() -> void:
	if respawning:
		return

	respawning = true
	lives -= 1
	deaths += 1

	# Placed pads and inventory stay unchanged

	if lives <= 0:
		Sfx.play("game_over")
		_show_banner("THE BETWEEN CLAIMS YOU")
		await get_tree().create_timer(1.5).timeout  # respawning stays true, so nothing else happens meanwhile
		get_tree().reload_current_scene()
		return

	Sfx.play("death")

	# Dying unlocks the power of the lesson you're on (if you don't have it yet)
	if lesson >= 1 and not pad_unlocked:
		pad_unlocked = true
		_show_banner("BOUNCE PAD UNLOCKED  ·  PRESS E")
		Sfx.play("unlock")

	elif lesson >= 2 and not player.double_jump_unlocked:
		player.double_jump_unlocked = true
		_show_banner("DOUBLE JUMP UNLOCKED  ·  JUMP IN MID-AIR")
		Sfx.play("unlock")

	elif lesson >= 3 and not player.dash_unlocked:
		player.dash_unlocked = true
		_show_banner("DASH UNLOCKED  ·  PRESS SHIFT")
		Sfx.play("unlock")

	call_deferred("_respawn_player")


# RESPAWN

func _respawn_player() -> void:
	player.global_position = spawn_position
	player.reset_after_respawn()
	player.get_node("Camera2D").reset_smoothing()  # jump straight there, don't glide across the level

	respawning = false
	_update_hud()


# CHECKPOINTS
# Touching a lantern makes it the new respawn point and lights it up.

func _on_checkpoint_body_entered(
	body: Node2D,
	checkpoint: Area2D
) -> void:
	if body != player:
		return

	spawn_position = checkpoint.global_position
	if not checkpoint.get_node("Glow").enabled:
		Sfx.play("checkpoint")  # only the first time it lights up
	checkpoint.get_node("Glow").enabled = true
	checkpoint.get_node("Flame").modulate = GLOW


# MESSAGE BANNER (shows for a few seconds, then fades)

func _show_banner(text: String) -> void:
	banner.text = text
	banner.modulate.a = 1.0

	if banner_tween:
		banner_tween.kill()  # a new message replaces the old one

	banner_tween = create_tween()
	banner_tween.tween_interval(3.0)
	banner_tween.tween_property(banner, "modulate:a", 0.0, 1.0)
