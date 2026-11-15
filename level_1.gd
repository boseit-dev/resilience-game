extends Node2D

# RESILIENCE - LEVEL 1 (the tutorial reuses this script too: tutorial.gd)
# Lives, Bounce Pads, power unlocks, checkpoints, death, Game Over, chests and the HUD.

const MAX_LIVES = 5
# Set per level in its .tscn (Inspector): every story level and the tutorial use this script
@export var level_number = 1                       # for the story save (save_game.gd)
@export var level_title = "LEVEL 1  ·  THE ARRIVAL"
@export var music: AudioStream                     # empty = the Level 1 theme
const MAX_PADS = 3
const PAD_LAUNCH_SPEED = -520.0
const RESPAWN_GRACE = 1.0      # seconds enemies can't hurt you after a respawn
const GAME_OVER_TIME = 3.5

const PAD_TEXTURE = preload("res://assets/kenney_pixel-platformer/Tiles/tile_0148.png")
const FACE_TEXTURE = preload("res://assets/kenney_pixel-platformer/Tiles/Characters/tile_0002.png")
const FONT = preload("res://assets/fonts/Cinzel.ttf")
const BRIGHT = Color("#E8F5FF")
const GLOW = Color("#83D9FF")
const DIM = Color("#394256")

const REWARD_TEXT = {
	"pad": "+1 BOUNCE PAD",
	"heart": "+1 LIFE",
	"speed": "SPEED BOOST  ·  10 s",
	"dash": "QUICK DASH  ·  12 s",
	"shield": "SHIELD  ·  BLOCKS ONE HIT",
}

var lives = MAX_LIVES
var shown_lives = MAX_LIVES   # what the HUD shows (to pop the mask of a lost life)
var deaths = 0
var pads_remaining = MAX_PADS
var pad_unlocked = false
var death_powers = true      # each death unlocks the next power (the tutorial turns this off)
var respawning = false
var respawn_grace = 0.0
var restart_armed = false     # R pressed once; press again within 2 s to restart
var placed_pads: Array[Area2D] = []

@onready var player = $Player
@onready var spawn_position = player.global_position

# HUD parts (made in _create_hud)
var hud_layer: CanvasLayer
var effects_layer: CanvasLayer   # glowing effects in the world, not darkened by the night
var life_icons: Array[TextureRect] = []
var power_rows: Array[Control] = []
var pad_counter: Label
var boost_label: Label
var banner: Label
var banner_tween: Tween
var hurt_vignette: TextureRect
var fade_rect: ColorRect
var game_over_screen: Control


func _ready() -> void:
	_create_hud()
	_update_hud()
	add_child(preload("res://pause_menu.gd").new())
	_show_banner(level_title)
	if level_number > 1:   # Level 1 can't be beaten without all three powers, so later levels start with them
		pad_unlocked = true
		player.double_jump_unlocked = true
		player.dash_unlocked = true
		_update_hud()
	Sfx.level_music = music if music else Sfx.MUSIC
	Sfx.start_ambience()
	for boss in get_tree().get_nodes_in_group("boss"):   # the Warden, the Failed Prototype
		boss.defeated.connect(_on_boss_defeated.bind(boss))
	for checkpoint in get_tree().get_nodes_in_group("checkpoint"):
		checkpoint.body_entered.connect(_on_checkpoint_body_entered.bind(checkpoint))


func _process(delta: float) -> void:
	if respawn_grace > 0.0:   # blink while safe
		respawn_grace -= delta
		player.visible = respawn_grace <= 0.0 or int(respawn_grace * 12.0) % 2 == 0
	if player.global_position.y > 900:
		_lose_life()
	_update_boost_label()
	_update_boss_bar()


# The boss bar at the top: name and health of the boss you're fighting
var boss_bar: Control
var boss_fill: ColorRect
var boss_title: Label

func _update_boss_bar() -> void:
	var bosses = get_tree().get_nodes_in_group("boss").filter(func(b): return b.awake and b.health > 0)
	boss_bar.visible = not bosses.is_empty()
	if boss_bar.visible:
		boss_title.text = bosses[0].title
		var target = 300.0 * bosses[0].health / float(bosses[0].max_health)
		boss_fill.size.x = lerpf(boss_fill.size.x, target, 0.15)   # slides down when hit


# ---------- HUD ----------

func _create_hud() -> void:
	hud_layer = CanvasLayer.new()
	hud_layer.name = "HUD"
	hud_layer.layer = 10
	add_child(hud_layer)
	effects_layer = CanvasLayer.new()
	effects_layer.layer = 2
	effects_layer.follow_viewport_enabled = true
	add_child(effects_layer)

	boss_bar = Control.new()   # centred near the bottom, hidden until a boss wakes
	boss_bar.anchor_left = 0.5
	boss_bar.anchor_right = 0.5
	boss_bar.anchor_top = 1.0
	boss_bar.anchor_bottom = 1.0
	boss_bar.position = Vector2(-150, -52)
	boss_bar.visible = false
	hud_layer.add_child(boss_bar)
	boss_title = Label.new()
	boss_title.add_theme_font_override("font", FONT)
	boss_title.add_theme_font_size_override("font_size", 13)
	boss_title.add_theme_color_override("font_color", Color("#E8E2FF"))
	boss_title.size = Vector2(300, 18)
	boss_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_bar.add_child(boss_title)
	var back = ColorRect.new()
	back.color = Color(0.05, 0.03, 0.08, 0.85)
	back.position = Vector2(-2, 20)
	back.size = Vector2(304, 10)
	boss_bar.add_child(back)
	boss_fill = ColorRect.new()
	boss_fill.color = Color(0.85, 0.25, 0.4)
	boss_fill.position = Vector2(0, 22)
	boss_fill.size = Vector2(300, 6)
	boss_bar.add_child(boss_fill)

	# A soft dark corner so the HUD is readable
	var shade = TextureRect.new()
	shade.texture = _gradient([Color(0.02, 0.02, 0.05, 0.75), Color(0.02, 0.02, 0.05, 0.0)], Vector2(0, 0), Vector2(1, 0))
	shade.size = Vector2(420, 240)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(shade)

	var lives_row = HBoxContainer.new()
	lives_row.position = Vector2(22, 18)
	lives_row.add_theme_constant_override("separation", 6)
	hud_layer.add_child(lives_row)
	for i in MAX_LIVES:
		var icon = TextureRect.new()
		icon.texture = FACE_TEXTURE
		icon.custom_minimum_size = Vector2(30, 30)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		lives_row.add_child(icon)
		life_icons.append(icon)

	var powers = VBoxContainer.new()
	powers.position = Vector2(24, 60)
	powers.add_theme_constant_override("separation", 6)
	hud_layer.add_child(powers)
	power_rows.append(_power_row(powers, "E", "BOUNCE PAD"))
	power_rows.append(_power_row(powers, "SPACE", "DOUBLE JUMP"))
	power_rows.append(_power_row(powers, "SHIFT", "DASH"))
	pad_counter = power_rows[0].get_child(1)
	boost_label = _label("", 13, Color("#FFE08A"), powers)
	boost_label.add_theme_font_override("font", ThemeDB.fallback_font)

	banner = _label("", 22, BRIGHT, hud_layer)
	banner.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	banner.offset_top = 20
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_constant_override("outline_size", 6)
	banner.modulate.a = 0.0

	hurt_vignette = TextureRect.new()   # red glow at the screen edges when you die
	hurt_vignette.texture = _gradient([Color(0.6, 0, 0.05, 0), Color(0.6, 0, 0.05, 0.7)], Vector2(0.5, 0.5), Vector2(1, 0.5), [0.7, 1.0])
	hurt_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hurt_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hurt_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hurt_vignette.modulate.a = 0.0
	hud_layer.add_child(hurt_vignette)

	fade_rect = ColorRect.new()   # black screen for the death fade
	fade_rect.color = Color("#05040A")
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.modulate.a = 0.0
	hud_layer.add_child(fade_rect)


# A key in a little box, then what it does. Hidden until that power is unlocked.
func _power_row(parent: Control, key_name: String, text: String) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.visible = false
	parent.add_child(row)
	var key = _label(key_name, 13, BRIGHT, row)
	key.add_theme_font_override("font", ThemeDB.fallback_font)
	var box = StyleBoxFlat.new()
	box.bg_color = Color(0.07, 0.08, 0.14, 0.9)
	box.border_color = GLOW
	box.set_border_width_all(1)
	box.border_width_bottom = 3
	box.set_corner_radius_all(3)
	box.set_content_margin_all(5)
	box.content_margin_top = 1
	box.content_margin_bottom = 2
	key.add_theme_stylebox_override("normal", box)
	var label = _label(text, 14, GLOW, row)
	label.add_theme_font_override("font", ThemeDB.fallback_font)
	return row


func _update_hud() -> void:
	for i in MAX_LIVES:
		life_icons[i].modulate = BRIGHT if i < lives else Color(DIM, 0.5)
	if lives < shown_lives and lives >= 0:   # a life was just lost: its mask pops
		var lost = life_icons[lives]
		lost.pivot_offset = lost.size / 2.0
		lost.scale = Vector2(1.6, 1.6)
		lost.modulate = Color(1.0, 0.45, 0.45)
		var pop = create_tween()
		pop.tween_property(lost, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		pop.parallel().tween_property(lost, "modulate", Color(DIM, 0.5), 0.6)
	shown_lives = lives
	for i in 3:
		var unlocked = [pad_unlocked, player.double_jump_unlocked, player.dash_unlocked][i]
		if unlocked and not power_rows[i].visible:   # fade in the first time
			power_rows[i].visible = true
			power_rows[i].modulate.a = 0.0
			create_tween().tween_property(power_rows[i], "modulate:a", 1.0, 0.3)
	pad_counter.text = "BOUNCE PAD  ·  %d LEFT" % pads_remaining
	pad_counter.modulate.a = 1.0 if pads_remaining > 0 else 0.4


func _update_boost_label() -> void:
	var parts = []
	if player.speed_boost_timer > 0.0:
		parts.append("SPEED %ds" % ceil(player.speed_boost_timer))
	if player.dash_boost_timer > 0.0:
		parts.append("QUICK DASH %ds" % ceil(player.dash_boost_timer))
	if player.has_shield:
		parts.append("SHIELD")
	boost_label.text = "  ·  ".join(parts)


# A message at the top of the screen for a few seconds
func _show_banner(text: String) -> void:
	banner.text = text
	banner.modulate.a = 1.0
	if banner_tween:
		banner_tween.kill()
	banner_tween = create_tween()
	banner_tween.tween_interval(3.0)
	banner_tween.tween_property(banner, "modulate:a", 0.0, 1.0)


# ---------- keys ----------

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo:
		return
	if is_instance_valid(game_over_screen):
		if event.physical_keycode in [KEY_SPACE, KEY_ENTER]:
			_restart_after_game_over()
		return
	if event.physical_keycode == KEY_E:
		_place_jump_pad()
	elif event.physical_keycode == KEY_R:
		if restart_armed:
			get_tree().call_deferred("reload_current_scene")
		else:
			restart_armed = true
			_show_banner("PRESS R AGAIN TO RESTART")
			get_tree().create_timer(2.0).timeout.connect(func(): restart_armed = false)


# ---------- Bounce Pads (they stay where you put them) ----------

func _place_jump_pad() -> void:
	if respawning or not pad_unlocked or pads_remaining <= 0 or not player.is_on_floor():
		return
	var spot = player.global_position + Vector2(player.facing_direction * 55, 12)
	if _is_blocked(spot + Vector2(0, -11), Vector2(70, 16)):
		_show_banner("NO ROOM FOR A PAD HERE")
		return

	var pad = Area2D.new()
	pad.name = "PermanentBouncePad"
	pad.collision_layer = 0
	pad.collision_mask = player.collision_layer
	add_child(pad)
	pad.global_position = spot
	var shape = CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(74, 24)
	shape.position = Vector2(0, -11)
	pad.add_child(shape)
	for i in 4:
		var sprite = Sprite2D.new()
		sprite.texture = PAD_TEXTURE
		sprite.position = Vector2(-27 + i * 18, -9)
		pad.add_child(sprite)
	pad.body_entered.connect(_on_jump_pad_body_entered)

	placed_pads.append(pad)
	pads_remaining -= 1
	Sfx.play("pad_place")
	_update_hud()


# Is any wall or floor inside this box?
func _is_blocked(center: Vector2, box_size: Vector2) -> bool:
	var query = PhysicsShapeQueryParameters2D.new()
	query.shape = RectangleShape2D.new()
	query.shape.size = box_size
	query.transform = Transform2D(0.0, center)
	query.collision_mask = player.collision_mask
	query.exclude = [player.get_rid()]
	return not get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


func _on_jump_pad_body_entered(body: Node2D) -> void:
	if body == player and not respawning and player.velocity.y >= 0.0:
		player.velocity.y = PAD_LAUNCH_SPEED
		Sfx.play("pad_bounce")


# ---------- hurting the player ----------

func _on_spikes_body_entered(body: Node2D) -> void:
	if body == player:
		_lose_life()


# A boss's touch or strike: like an enemy hit (respawn grace and the shield count)
func _on_boss_touched(body: Node2D) -> void:
	if body == player:
		enemy_hit_player()


# Enemies and arrows call this. A shield takes the hit. (Spikes and falls ignore the shield.)
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


# ---------- chests (chest.gd calls this) ----------

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


# A perfect run loses one life per power, so give back any extra lives lost so far
func _top_up_lives() -> void:
	var powers = int(pad_unlocked) + int(player.double_jump_unlocked) + int(player.dash_unlocked)
	if lives < MAX_LIVES - powers:
		lives = MAX_LIVES - powers
		shown_lives = lives
		_show_banner("LIVES RESTORED")
		Sfx.play("checkpoint")
		_update_hud()


# ---------- dying ----------

func _lose_life() -> void:
	if respawning:
		return
	respawning = true
	lives -= 1
	deaths += 1
	_shatter_player()
	if lives <= 0:
		Sfx.play("game_over")
		_show_game_over()
		return
	Sfx.play("death")

	# Each death unlocks the next power you don't have yet
	if death_powers and not pad_unlocked:
		pad_unlocked = true
		_unlock("BOUNCE PAD UNLOCKED")
	elif death_powers and not player.double_jump_unlocked:
		player.double_jump_unlocked = true
		_unlock("DOUBLE JUMP UNLOCKED")
	elif death_powers and not player.dash_unlocked:
		player.dash_unlocked = true
		_unlock("DASH UNLOCKED")

	var fade = create_tween()
	fade.tween_interval(0.5)
	fade.tween_property(fade_rect, "modulate:a", 1.0, 0.22)
	fade.tween_callback(_respawn_player)
	fade.tween_property(fade_rect, "modulate:a", 0.0, 0.35)


func _unlock(text: String) -> void:
	_show_banner(text)
	Sfx.play("unlock")


# The scientist breaks into glowing shards, a soul light floats up, the screen flashes red and shakes
func _shatter_player() -> void:
	player.set_physics_process(false)
	player.velocity = Vector2.ZERO
	player.get_node("Sprite2D").visible = false
	var spot = player.global_position

	var shards = CPUParticles2D.new()
	shards.position = spot
	shards.one_shot = true
	shards.explosiveness = 1.0
	shards.amount = 36
	shards.lifetime = 0.9
	shards.spread = 180.0
	shards.initial_velocity_min = 70.0
	shards.initial_velocity_max = 170.0
	shards.gravity = Vector2(0, 320)
	shards.scale_amount_min = 3.0
	shards.scale_amount_max = 5.0
	shards.color_ramp = Gradient.new()
	shards.color_ramp.colors = PackedColorArray([Color.WHITE, GLOW, Color(GLOW, 0.0)])
	shards.color_ramp.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	shards.material = CanvasItemMaterial.new()
	shards.material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	shards.emitting = true
	effects_layer.add_child(shards)
	get_tree().create_timer(1.2).timeout.connect(shards.queue_free)

	var soul = PointLight2D.new()
	soul.texture = _soft_dot()
	soul.texture_scale = 0.35
	soul.color = GLOW
	soul.energy = 1.6
	soul.position = spot
	add_child(soul)
	var rise = create_tween()
	rise.tween_property(soul, "position:y", spot.y - 60, 0.9)
	rise.parallel().tween_property(soul, "energy", 0.0, 0.9)
	rise.tween_callback(soul.queue_free)

	hurt_vignette.modulate.a = 0.8
	create_tween().tween_property(hurt_vignette, "modulate:a", 0.0, 0.6)
	var camera = player.get_node("Camera2D")
	var shake = create_tween()
	for i in 6:
		shake.tween_property(camera, "offset", Vector2(randf_range(-6, 6), randf_range(-5, 5)), 0.04)
	shake.tween_property(camera, "offset", Vector2.ZERO, 0.05)


func _respawn_player() -> void:
	if not is_inside_tree():
		return
	player.global_position = spawn_position
	player.reset_physics_interpolation()   # appear at the lantern instead of sliding there
	player.reset_after_respawn()
	player.set_physics_process(true)
	player.get_node("Camera2D").reset_smoothing()
	get_tree().call_group("enemies", "reset_after_player_death")
	get_tree().call_group("arrows", "queue_free")
	if pad_unlocked and pads_remaining == 0:   # never stuck: some walls need a Bounce Pad
		pads_remaining = 1
		_update_hud()
	# Come back with a white flash, stretching back into shape
	var sprite = player.get_node("Sprite2D")
	sprite.visible = true
	sprite.scale = Vector2(0.3, 1.8)
	sprite.self_modulate = Color(3, 3, 3)
	var reform = create_tween()
	reform.tween_property(sprite, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	reform.parallel().tween_property(sprite, "self_modulate", Color.WHITE, 0.4)
	respawning = false
	respawn_grace = RESPAWN_GRACE
	_update_hud()


# ---------- Game Over (the whole level restarts) ----------

func _show_game_over() -> void:
	game_over_screen = Control.new()
	game_over_screen.name = "GameOver"
	game_over_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game_over_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game_over_screen.modulate.a = 0.0
	hud_layer.add_child(game_over_screen)
	var shade = ColorRect.new()
	shade.color = Color(0.02, 0.0, 0.03, 0.9)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game_over_screen.add_child(shade)

	var column = _center_column(game_over_screen)
	var title = _screen_label("THE BETWEEN CLAIMS YOU", 46, Color("#F2D6DC"), column)
	title.add_theme_color_override("font_outline_color", Color(0.55, 0.0, 0.08, 0.6))
	title.add_theme_constant_override("outline_size", 14)
	var powers = int(pad_unlocked) + int(player.double_jump_unlocked) + int(player.dash_unlocked)
	_screen_label("Deaths  %d     ·     Powers found  %d / 3" % [deaths, powers], 18, Color("#8D97B3"), column)
	_screen_label("Your echo gathers itself to try again...", 16, Color("#5E6A8A"), column)

	var appear = create_tween()
	appear.tween_interval(0.35)
	appear.tween_property(game_over_screen, "modulate:a", 1.0, 0.8)
	get_tree().create_timer(GAME_OVER_TIME, false).timeout.connect(_restart_after_game_over)   # waits while paused


func _restart_after_game_over() -> void:
	if is_inside_tree() and is_instance_valid(game_over_screen):
		get_tree().paused = false   # never restart into a frozen level
		get_tree().reload_current_scene()


# A one-off puff of sparkles (lanterns)
func _burst(at: Vector2, color: Color) -> void:
	var p = CPUParticles2D.new()
	p.position = at
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = 24
	p.lifetime = 0.8
	p.spread = 180.0
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 110.0
	p.gravity = Vector2(0, -40)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.5
	p.color = color
	add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


# ---------- checkpoints and the boss ----------

func _on_checkpoint_body_entered(body: Node2D, checkpoint: Area2D) -> void:
	if body != player:
		return
	spawn_position = checkpoint.global_position
	if not checkpoint.get_node("Glow").enabled:   # first time you light this lantern
		Sfx.play("checkpoint")
		_top_up_lives()
		_burst(checkpoint.global_position + Vector2(0, -14), GLOW)
		var flame = checkpoint.get_node("Flame")
		var pop = create_tween()
		pop.tween_property(flame, "scale", flame.scale * 1.8, 0.12)
		pop.tween_property(flame, "scale", flame.scale, 0.3)
	checkpoint.get_node("Glow").enabled = true
	checkpoint.get_node("Flame").modulate = GLOW


# The Warden is beaten: save the story, and a Gateway Fragment flies from it into the scientist
func _on_boss_defeated(boss: Node2D) -> void:
	var kept = []
	if pad_unlocked:
		kept.append("pad")
	if player.double_jump_unlocked:
		kept.append("double_jump")
	if player.dash_unlocked:
		kept.append("dash")
	SaveGame.complete_level(level_number, kept)

	var fragment = Polygon2D.new()
	fragment.polygon = PackedVector2Array([Vector2(0, -9), Vector2(6, 0), Vector2(0, 9), Vector2(-6, 0)])
	fragment.color = Color(1.6, 1.9, 2.2)
	fragment.global_position = boss.global_position + Vector2(0, -30)
	effects_layer.add_child(fragment)
	var light = PointLight2D.new()
	light.texture = _soft_dot()
	light.color = GLOW
	light.energy = 1.8
	fragment.add_child(light)
	var fly = create_tween()
	fly.tween_property(fragment, "position:y", fragment.position.y - 50, 1.2)
	fly.parallel().tween_property(fragment, "rotation", TAU, 1.2)
	fly.tween_method(func(t): fragment.global_position = fragment.global_position.lerp(player.global_position, t), 0.0, 1.0, 0.7)
	fly.tween_callback(func():
		fragment.queue_free()
		Sfx.play("rare_reward")
		_show_banner("GATEWAY FRAGMENT RECOVERED  ·  %d / %d" % [SaveGame.fragments, SaveGame.LEVEL_COUNT]))


# ---------- small helpers ----------

func _label(text: String, size: int, color: Color, parent: Node) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("#07060C"))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


# A centred label for the full-screen messages (Game Over, Tutorial Complete)
func _screen_label(text: String, size: int, color: Color, parent: Control) -> Label:
	var label = _label(text, size, color, parent)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_constant_override("outline_size", 0)
	return label


func _center_column(parent: Control) -> VBoxContainer:
	var column = VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 14)
	parent.add_child(column)
	return column


func _gradient(colors: Array, from: Vector2, to: Vector2, offsets: Array = []) -> GradientTexture2D:
	var texture = GradientTexture2D.new()
	texture.gradient = Gradient.new()
	texture.gradient.colors = PackedColorArray(colors)
	if not offsets.is_empty():
		texture.gradient.offsets = PackedFloat32Array(offsets)
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = from
	texture.fill_to = to
	return texture


func _soft_dot() -> GradientTexture2D:
	var dot = _gradient([Color.WHITE, Color(1, 1, 1, 0)], Vector2(0.5, 0.5), Vector2(0.5, 0.0))
	dot.width = 64
	dot.height = 64
	return dot
