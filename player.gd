
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


func _physics_process(delta: float) -> void:

	# Read movement keys
	var left_pressed = (
		Input.is_physical_key_pressed(KEY_A)
		or Input.is_physical_key_pressed(KEY_LEFT)
	)

	var right_pressed = (
		Input.is_physical_key_pressed(KEY_D)
		or Input.is_physical_key_pressed(KEY_RIGHT)
	)

	var jump_pressed = (
		Input.is_physical_key_pressed(KEY_W)
		or Input.is_physical_key_pressed(KEY_UP)
		or Input.is_physical_key_pressed(KEY_SPACE)
	)

	var dash_pressed = Input.is_key_pressed(KEY_SHIFT)

	var direction = int(right_pressed) - int(left_pressed)

	if direction != 0:
		facing_direction = direction
		$Sprite2D.flip_h = facing_direction > 0  # the sprite is drawn facing left

	# Restore extra jump when landing
	if is_on_floor():
		extra_jump_available = double_jump_unlocked
		coyote_timer = COYOTE_TIME
	else:
		coyote_timer = max(0.0, coyote_timer - delta)

	# Countdown for dash
	dash_cooldown = max(0.0, dash_cooldown - delta)

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
	if (
		dash_unlocked
		and dash_pressed
		and not dash_was_pressed
		and dash_cooldown <= 0.0
	):
		dash_timer = DASH_DURATION
		dash_cooldown = DASH_COOLDOWN
		Sfx.play("dash")

	dash_was_pressed = dash_pressed

	# Dash movement
	if dash_timer > 0.0:
		dash_timer -= delta
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
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(
			velocity.x,
			0.0,
			SPEED
		)

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

	jump_was_pressed = (
		Input.is_physical_key_pressed(KEY_W)
		or Input.is_physical_key_pressed(KEY_UP)
		or Input.is_physical_key_pressed(KEY_SPACE)
	)

	dash_was_pressed = Input.is_key_pressed(KEY_SHIFT)
