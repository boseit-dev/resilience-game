
extends CharacterBody2D

# RESILIENCE - PLAYER CONTROLS

const SPEED = 300.0
const JUMP_VELOCITY = -400.0

const DASH_SPEED = 700.0
const DASH_DURATION = 0.18
const DASH_COOLDOWN = 0.6

# Forgiveness: a jump still counts as a ground jump just after running off a ledge
# (so it doesn't use up the double jump), and a jump pressed just before landing still works
const COYOTE_TIME = 0.07
const JUMP_BUFFER = 0.1

# The Warden's stomp curse: no jumping (or double jumping) while this is above 0
const SEALED_COLOR = Color(0.65, 0.45, 1.0)
var jump_locked_timer: float = 0.0

# Walking animation frames (Kenney Pixel Platformer)
const WALK_FRAMES = [
	preload("res://assets/kenney_pixel-platformer/Tiles/Characters/tile_0002.png"),
	preload("res://assets/kenney_pixel-platformer/Tiles/Characters/tile_0003.png"),
]
const WALK_FRAME_TIME = 0.12  # seconds per frame
var walk_timer: float = 0.0

# Abilities
var double_jump_unlocked: bool = false
var dash_unlocked: bool = false

# Movement
var facing_direction: int = 1
var extra_jump_available: bool = false
var jump_was_pressed: bool = false
var dash_was_pressed: bool = false

var dash_timer: float = 0.0
var dash_cooldown: float = 0.0
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0

# Chest rewards (chest.gd / level_1.gd give_reward): timers count down to 0
const BOOSTED_SPEED = 1.3          # speed boost: 30% faster
const BOOSTED_DASH_COOLDOWN = 0.25 # dash boost: dash again much sooner
var speed_boost_timer: float = 0.0
var dash_boost_timer: float = 0.0
var has_shield: bool = false       # absorbs one enemy hit (not spikes or falls)
var shield_ring: Line2D


func _ready() -> void:
	# A thin glowing ring that shows while the shield is up
	shield_ring = Line2D.new()
	shield_ring.width = 1.5
	shield_ring.default_color = Color(0.5, 0.9, 1.0, 0.8)
	for i in 25:
		shield_ring.add_point(Vector2.from_angle(i * TAU / 24) * 17)
	shield_ring.visible = false
	add_child(shield_ring)


func _key(a: Key, b: Key, c: Key = KEY_NONE) -> bool:
	return Input.is_physical_key_pressed(a) or Input.is_physical_key_pressed(b) or (c != KEY_NONE and Input.is_physical_key_pressed(c))


var was_on_floor = true
var fall_speed = 0.0


func _land_effect() -> void:
	var dust = CPUParticles2D.new()
	dust.position = Vector2(0, 11)
	dust.one_shot = true
	dust.explosiveness = 1.0
	dust.amount = 8
	dust.lifetime = 0.35
	dust.direction = Vector2(0, -1)
	dust.spread = 80.0
	dust.initial_velocity_min = 20.0
	dust.initial_velocity_max = 50.0
	dust.gravity = Vector2(0, 120)
	dust.color = Color(0.8, 0.85, 1.0, 0.6)
	add_child(dust)
	dust.emitting = true
	dust.finished.connect(dust.queue_free)
	var squash = create_tween()
	squash.tween_property($Sprite2D, "scale", Vector2(1.25, 0.8), 0.06)
	squash.tween_property($Sprite2D, "scale", Vector2.ONE, 0.12)


# A fading copy of the scientist left behind while dashing
func _afterimage() -> void:
	var ghost = Sprite2D.new()
	ghost.texture = $Sprite2D.texture
	ghost.flip_h = $Sprite2D.flip_h
	ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ghost.global_position = $Sprite2D.global_position
	ghost.modulate = Color(0.6, 0.85, 1.6, 0.6)
	get_parent().add_child(ghost)
	var fade = ghost.create_tween()
	fade.tween_property(ghost, "modulate:a", 0.0, 0.25)
	fade.tween_callback(ghost.queue_free)


func _physics_process(delta: float) -> void:
	var jump_pressed = _key(KEY_W, KEY_UP, KEY_SPACE)
	var dash_pressed = Input.is_key_pressed(KEY_SHIFT)
	var direction = int(_key(KEY_D, KEY_RIGHT)) - int(_key(KEY_A, KEY_LEFT))

	if direction != 0:
		facing_direction = direction
		$Sprite2D.flip_h = facing_direction > 0  # the sprite is drawn facing left

	# Landing: a puff of dust and a little squash after a real fall
	if is_on_floor() and not was_on_floor and fall_speed > 260.0:
		_land_effect()
	was_on_floor = is_on_floor()
	if not was_on_floor:
		fall_speed = velocity.y

	# Restore extra jump when landing
	if is_on_floor():
		extra_jump_available = double_jump_unlocked
		coyote_timer = COYOTE_TIME
	else:
		coyote_timer = max(0.0, coyote_timer - delta)

	# Countdown for dash
	dash_cooldown = max(0.0, dash_cooldown - delta)

	# Chest boosts wear off; the shield ring pulses while it's up
	speed_boost_timer = max(0.0, speed_boost_timer - delta)
	dash_boost_timer = max(0.0, dash_boost_timer - delta)
	shield_ring.visible = has_shield
	shield_ring.modulate.a = 0.6 + 0.4 * sin(Time.get_ticks_msec() / 150.0)

	# Countdown for the Warden's jump seal (the player glows purple while sealed)
	jump_locked_timer = max(0.0, jump_locked_timer - delta)
	$Sprite2D.modulate = SEALED_COLOR if jump_locked_timer > 0.0 else Color.WHITE

	# Walking animation: swap the two Kenney frames while moving on the ground,
	# legs-apart frame in the air, standing frame when still
	if is_on_floor() and direction != 0:
		walk_timer += delta
		$Sprite2D.texture = WALK_FRAMES[int(walk_timer / WALK_FRAME_TIME) % 2]
	else:
		walk_timer = 0.0
		$Sprite2D.texture = WALK_FRAMES[0] if is_on_floor() else WALK_FRAMES[1]

	# Start dash
	if dash_unlocked and dash_pressed and not dash_was_pressed and dash_cooldown <= 0.0:
		dash_timer = DASH_DURATION
		dash_cooldown = BOOSTED_DASH_COOLDOWN if dash_boost_timer > 0.0 else DASH_COOLDOWN
		Sfx.play("dash")

	dash_was_pressed = dash_pressed

	# Dash movement
	if dash_timer > 0.0:
		dash_timer -= delta
		if Engine.get_physics_frames() % 3 == 0:
			_afterimage()
		velocity.x = facing_direction * DASH_SPEED
		velocity.y = 0.0
		move_and_slide()
		jump_was_pressed = jump_pressed
		return

	# Gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Normal jump and double jump
	var jump_just_pressed = jump_pressed and not jump_was_pressed and jump_locked_timer <= 0.0

	if jump_just_pressed:
		jump_buffer_timer = JUMP_BUFFER
	else:
		jump_buffer_timer = max(0.0, jump_buffer_timer - delta)

	if jump_buffer_timer > 0.0 and (is_on_floor() or coyote_timer > 0.0):
		velocity.y = JUMP_VELOCITY
		coyote_timer = 0.0
		jump_buffer_timer = 0.0
		Sfx.play("jump")

	elif jump_just_pressed and double_jump_unlocked and extra_jump_available:
		velocity.y = JUMP_VELOCITY
		extra_jump_available = false
		jump_buffer_timer = 0.0
		Sfx.play("double_jump")

	jump_was_pressed = jump_pressed

	# Horizontal movement
	if direction != 0:
		velocity.x = direction * SPEED * (BOOSTED_SPEED if speed_boost_timer > 0.0 else 1.0)
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED)

	move_and_slide()


# Reset temporary movement after death
func reset_after_respawn() -> void:
	velocity = Vector2.ZERO
	dash_timer = 0.0
	dash_cooldown = 0.0
	extra_jump_available = false
	coyote_timer = 0.0
	jump_buffer_timer = 0.0
	jump_locked_timer = 0.0
	speed_boost_timer = 0.0   # boosts end when you die (the shield stays until it's used)
	dash_boost_timer = 0.0

	jump_was_pressed = _key(KEY_W, KEY_UP, KEY_SPACE)   # a key still held from before doesn't count as a new press
	dash_was_pressed = Input.is_key_pressed(KEY_SHIFT)
