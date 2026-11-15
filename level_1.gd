
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
const LESSONS = {"SABLE": 1, "TOMAS": 2, "IVY": 3, "RHEA": 4}   # RHEA: lives top-up before the end

var lives = MAX_LIVES
var deaths = 0
var pads_remaining = MAX_PADS
var respawning = false
var respawn_grace = 0.0     # seconds after a respawn where enemies and arrows can't hurt you
var restart_armed = false   # R was pressed once; a second press within 2 s restarts
var pad_unlocked = false
var lesson = 0   # the latest lesson reached (see LESSONS)

var placed_pads: Array[Area2D] = []

@onready var player = $Player
@onready var spawn_position = player.global_position

var life_icons: Array[TextureRect] = []
var shown_lives = MAX_LIVES          # so the HUD knows when a life was just lost
var hud_layer: CanvasLayer
var fade_rect: ColorRect             # black screen for the death fade
var hurt_vignette: TextureRect       # red glow around the screen edges when you die
var game_over_screen: Control        # shown when the last life is lost (null otherwise)
var effects_layer: CanvasLayer       # bright effects drawn in the world but not darkened by the night

# Death: shatter (DEATH_PAUSE) -> fade to black -> respawn -> fade back in
const DEATH_PAUSE = 0.5
const FADE_OUT = 0.22
const FADE_IN = 0.35
const RESPAWN_GRACE = 1.0           # seconds you can't be hurt by enemies after respawning
const GAME_OVER_TIME = 3.5           # seconds on the Game Over screen (Space/Enter skips)
var power_rows: Array[Control] = []  # pad, double jump, dash (hidden until unlocked)
var pad_counter: Label
var boost_label: Label               # active chest boosts (speed, dash, shield)
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
	hud_layer = layer
	effects_layer = CanvasLayer.new()
	effects_layer.layer = 2
	effects_layer.follow_viewport_enabled = true  # moves with the camera like the world does
	add_child(effects_layer)

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

	# Active chest boosts, e.g. "SPEED 6s  ·  SHIELD" (empty when there are none)
	boost_label = Label.new()
	boost_label.add_theme_font_size_override("font_size", 13)
	boost_label.add_theme_color_override("font_color", Color("#FFE08A"))
	boost_label.add_theme_color_override("font_outline_color", Color("#07060C"))
	boost_label.add_theme_constant_override("outline_size", 4)
	powers.add_child(boost_label)

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

	# Death effects: a red glow at the screen edges, and a black fade (both start invisible)
	var red = Gradient.new()
	red.colors = PackedColorArray([Color(0.6, 0.0, 0.05, 0.0), Color(0.6, 0.0, 0.05, 0.7)])
	red.offsets = PackedFloat32Array([0.7, 1.0])
	var red_texture = GradientTexture2D.new()
	red_texture.gradient = red
	red_texture.fill = GradientTexture2D.FILL_RADIAL
	red_texture.fill_from = Vector2(0.5, 0.5)
	red_texture.fill_to = Vector2(1.0, 0.5)
	hurt_vignette = TextureRect.new()
	hurt_vignette.texture = red_texture
	hurt_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	hurt_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hurt_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hurt_vignette.modulate.a = 0.0
	layer.add_child(hurt_vignette)
	fade_rect = ColorRect.new()
	fade_rect.color = Color("#05040A")
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.modulate.a = 0.0
	layer.add_child(fade_rect)


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
		if event.pressed and not event.echo and is_instance_valid(game_over_screen):
			if event.physical_keycode in [KEY_SPACE, KEY_ENTER]:
				_restart_after_game_over()
			return
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

func _process(delta: float) -> void:
	# Just respawned: blink while enemies can't hurt you
	if respawn_grace > 0.0:
		respawn_grace -= delta
		player.visible = respawn_grace <= 0.0 or int(respawn_grace * 12.0) % 2 == 0
	if player.global_position.y > 900:
		_lose_life()
	_check_lessons()
	_update_boost_label()


func _update_boost_label() -> void:
	var parts = []
	if player.speed_boost_timer > 0.0:
		parts.append("SPEED %ds" % ceil(player.speed_boost_timer))
	if player.dash_boost_timer > 0.0:
		parts.append("QUICK DASH %ds" % ceil(player.dash_boost_timer))
	if player.has_shield:
		parts.append("SHIELD")
	boost_label.text = "  ·  ".join(parts)


# ENEMIES (enemies/enemy.gd, arrow.gd call this when they hit you)
# A shield takes the hit; otherwise you lose a life. Spikes and falls ignore the shield,
# so the deaths that unlock powers always work.

func enemy_hit_player() -> void:
	if respawning or respawn_grace > 0.0:
		return
	if player.has_shield:
		player.has_shield = false
		Sfx.play("shield_break")
		_show_banner("SHIELD BROKE")
		return
	Sfx.play("hurt")
	_lose_life()


# CHEST REWARDS (chest.gd picks one and calls this)

const REWARD_TEXT = {
	"pad": "+1 BOUNCE PAD",
	"heart": "+1 LIFE",
	"speed": "SPEED BOOST  ·  10 s",
	"dash": "QUICK DASH  ·  12 s",
	"shield": "SHIELD  ·  BLOCKS ONE HIT",
}

func give_reward(reward: String) -> void:
	match reward:
		"pad":
			pads_remaining += 1
		"heart":
			lives = min(lives + 1, MAX_LIVES)
			shown_lives = lives
		"speed":
			player.speed_boost_timer = 10.0
		"dash":
			player.dash_boost_timer = 12.0
		"shield":
			player.has_shield = true
	_show_banner("TREASURE:  " + REWARD_TEXT[reward])
	Sfx.play("rare_reward" if reward in ["heart", "shield"] else "reward")
	_update_hud()


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

	_shatter_player()

	if lives <= 0:
		Sfx.play("game_over")
		_show_game_over()
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

	# Fade to black, respawn at the lantern, fade back in
	var fade = create_tween()
	fade.tween_interval(DEATH_PAUSE)
	fade.tween_property(fade_rect, "modulate:a", 1.0, FADE_OUT)
	fade.tween_callback(_respawn_player)
	fade.tween_property(fade_rect, "modulate:a", 0.0, FADE_IN)


# DEATH EFFECTS
# The scientist shatters into shards, a little soul-light floats up, the screen edges
# flash red and the camera shakes. The player is frozen and hidden until the respawn.

func _shatter_player() -> void:
	player.set_physics_process(false)
	player.velocity = Vector2.ZERO
	player.get_node("Sprite2D").visible = false
	var spot = player.global_position

	var shards = CPUParticles2D.new()
	shards.position = spot
	shards.emitting = true
	shards.one_shot = true
	shards.explosiveness = 1.0
	shards.amount = 36
	shards.lifetime = 0.9
	shards.spread = 180.0
	shards.initial_velocity_min = 70.0
	shards.initial_velocity_max = 170.0
	shards.gravity = Vector2(0, 320)
	shards.angular_velocity_min = -360.0
	shards.angular_velocity_max = 360.0
	shards.scale_amount_min = 3.0
	shards.scale_amount_max = 5.0
	var colors = Gradient.new()
	colors.colors = PackedColorArray([Color.WHITE, GLOW, Color(GLOW, 0.0)])
	colors.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	shards.color_ramp = colors
	shards.material = CanvasItemMaterial.new()
	shards.material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD  # glowing shards
	effects_layer.add_child(shards)
	get_tree().create_timer(1.2).timeout.connect(shards.queue_free)

	# A burst of light where you fell (lights shine through the level's darkness)
	var flash = PointLight2D.new()
	flash.texture = _soft_dot()
	flash.texture_scale = 1.6
	flash.color = Color("#CFE8FF")
	flash.energy = 3.0
	flash.position = spot
	add_child(flash)
	var dim = create_tween()
	dim.tween_property(flash, "energy", 0.0, 0.45)
	dim.tween_callback(flash.queue_free)

	# The soul: a small light that drifts up and fades
	var soul = PointLight2D.new()
	soul.texture = _soft_dot()
	soul.texture_scale = 0.35
	soul.color = GLOW
	soul.energy = 1.6
	soul.position = spot
	add_child(soul)
	var rise = create_tween()
	rise.tween_property(soul, "position:y", spot.y - 60, 0.9).set_ease(Tween.EASE_OUT)
	rise.parallel().tween_property(soul, "energy", 0.0, 0.9)
	rise.tween_callback(soul.queue_free)

	# Red flash at the edges + camera shake
	hurt_vignette.modulate.a = 0.8
	create_tween().tween_property(hurt_vignette, "modulate:a", 0.0, 0.6)
	var camera = player.get_node("Camera2D")
	var shake = create_tween()
	for i in 6:
		shake.tween_property(camera, "offset", Vector2(randf_range(-6, 6), randf_range(-5, 5)), 0.04)
	shake.tween_property(camera, "offset", Vector2.ZERO, 0.05)


# Coming back: a white flash and the sprite stretches back into shape
func _reform_player() -> void:
	var sprite = player.get_node("Sprite2D")
	sprite.visible = true
	sprite.scale = Vector2(0.3, 1.8)
	sprite.self_modulate = Color(3, 3, 3)
	var reform = create_tween()
	reform.tween_property(sprite, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	reform.parallel().tween_property(sprite, "self_modulate", Color.WHITE, 0.4)


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


# GAME OVER SCREEN
# Fades in over the frozen level with the run's numbers, then the level restarts
# (everything resets: lives, powers, pads, chests). Space or Enter restarts sooner.

func _show_game_over() -> void:
	var screen = Control.new()
	screen.name = "GameOver"
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.modulate.a = 0.0
	hud_layer.add_child(screen)
	game_over_screen = screen

	var shade = ColorRect.new()
	shade.color = Color(0.02, 0.0, 0.03, 0.9)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.add_child(shade)

	var column = VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 14)
	screen.add_child(column)

	var title = _screen_label("THE BETWEEN CLAIMS YOU", 46, Color("#F2D6DC"), column)
	title.add_theme_color_override("font_outline_color", Color(0.55, 0.0, 0.08, 0.6))
	title.add_theme_constant_override("outline_size", 14)
	var powers = int(pad_unlocked) + int(player.double_jump_unlocked) + int(player.dash_unlocked)
	_screen_label("Deaths  %d     ·     Powers found  %d / 3" % [deaths, powers], 18, Color("#8D97B3"), column)
	_screen_label("Your echo gathers itself to try again...", 16, Color("#5E6A8A"), column)

	var appear = create_tween()
	appear.tween_interval(0.35)
	appear.tween_property(screen, "modulate:a", 1.0, 0.8)
	title.pivot_offset = Vector2(title.get_combined_minimum_size().x / 2, 30)
	title.scale = Vector2(1.15, 1.15)
	appear.parallel().tween_property(title, "scale", Vector2.ONE, 1.6).set_ease(Tween.EASE_OUT)
	get_tree().create_timer(GAME_OVER_TIME).timeout.connect(_restart_after_game_over)


func _screen_label(text: String, size: int, color: Color, parent: Control) -> Label:
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _restart_after_game_over() -> void:
	if is_inside_tree() and is_instance_valid(game_over_screen):
		get_tree().reload_current_scene()


# RESPAWN

func _respawn_player() -> void:
	if not is_inside_tree():
		return  # the level was already closed (restart or menu) before this respawn ran
	player.global_position = spawn_position
	player.reset_after_respawn()
	player.set_physics_process(true)
	_reform_player()
	player.get_node("Camera2D").reset_smoothing()  # jump straight there, don't glide across the level
	get_tree().call_group("enemies", "reset_after_player_death")  # living enemies go home
	get_tree().call_group("arrows", "queue_free")                 # no arrows left in the air

	respawning = false
	respawn_grace = RESPAWN_GRACE
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
