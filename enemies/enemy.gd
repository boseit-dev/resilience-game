extends CharacterBody2D
class_name Enemy

# RESILIENCE - SHARED ENEMY BEHAVIOUR
# Used by sword_fighter.gd, archer.gd and guardian.gd (each one only adds its own attack).
#   - Walks back and forth around where it was placed, turning at walls and ledges.
#   - Land on its head while falling = a stomp (it loses 1 health, you bounce up).
#   - Touch it any other way = you lose a life (once; then it can't hurt you for a moment).
#   - When you respawn, living enemies walk back to their start. Defeated ones stay
#     defeated until Game Over (the whole level reloads then).
# Enemies don't block the player: you walk through them (and get hurt).

@export var health = 1                 # stomps needed
@export var patrol_distance = 80.0     # how far it walks either side of its start
@export var walk_speed = 45.0
@export var look = 15                  # Kenney character tile (tile_0015.png ...)
@export var harmless = false           # a training dummy (tutorial): stands still and never hurts you

const GRAVITY = 900.0
const STOMP_BOUNCE = -330.0
const TOUCH_COOLDOWN = 1.0             # after hurting you, it can't hurt you again for this long
const SIZE = 1.5                       # enemies are drawn (and hit) 1.5x bigger than the player
const CHARACTERS = "res://assets/kenney_pixel-platformer/Tiles/Characters/tile_%04d.png"

var start_position: Vector2
var direction = -1                     # -1 = walking left, 1 = right
var hurt_cooldown = 0.0
var stomp_cooldown = 0.0               # one bounce can't count as two stomps
var above_last_frame = false           # was the player falling onto it last frame?
var defeated = false
var hitbox_size = Vector2(16, 20)
var frames: Array[Texture2D] = []   # walking animation frames (each enemy type fills these in build())
var walk_time = 0.0
var sprite: Sprite2D
var hitbox: Area2D
var player: CharacterBody2D
var level: Node


func _ready() -> void:
	add_to_group("enemies")
	start_position = global_position
	level = get_parent()
	while level and not level.has_node("Player"):   # the level is the ancestor that has the Player
		level = level.get_parent()
	player = level.get_node_or_null("Player") if level else null
	scale = Vector2(SIZE, SIZE)   # everything below (body, sprite, hitbox, weapon) grows with it
	collision_layer = 0   # the player passes through enemies
	collision_mask = 1    # but enemies stand on floors

	var body = CollisionShape2D.new()
	body.shape = RectangleShape2D.new()
	body.shape.size = Vector2(14, hitbox_size.y)
	body.position = Vector2(0, -hitbox_size.y / 2)
	add_child(body)

	sprite = Sprite2D.new()
	sprite.texture = load(CHARACTERS % look)
	sprite.position = Vector2(0, -12)
	add_child(sprite)

	hitbox = Area2D.new()
	hitbox.collision_layer = 0
	hitbox.collision_mask = 1
	var shape = CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = hitbox_size
	shape.position = Vector2(0, -hitbox_size.y / 2)
	hitbox.add_child(shape)
	add_child(hitbox)
	build()
	if harmless:
		modulate = Color(0.75, 0.85, 0.7)   # looks like a straw dummy, not a real fighter


func _physics_process(delta: float) -> void:
	if defeated:
		return
	hurt_cooldown = max(0.0, hurt_cooldown - delta)
	stomp_cooldown = max(0.0, stomp_cooldown - delta)
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	velocity.x = 0.0
	if not harmless:
		think(delta)
	move_and_slide()
	sprite.flip_h = direction > 0  # Kenney characters are drawn facing left
	_check_player_touch()


# ---------- each enemy type fills these in ----------

func build() -> void:      # add the sword, bow, cracks...
	pass

func think(_delta: float) -> void:   # decide where to walk and when to attack
	patrol()

func on_stomped() -> void:   # react to a stomp that didn't defeat it
	pass

func on_reset() -> void:     # go back to the starting state
	pass


# ---------- touching the player ----------

func _check_player_touch() -> void:
	if player == null:
		return
	# A stomp: you're falling and your middle is above its middle, now OR one frame ago.
	# (Touching is only reported a frame late, and a fast fall can reach the floor by then.)
	var middle = global_position.y - hitbox_size.y * SIZE * 0.5
	var above_now = player.velocity.y > 0.0 and player.global_position.y < middle
	var from_above = above_now or above_last_frame
	above_last_frame = above_now
	if not hitbox.overlaps_body(player):
		return
	if from_above and stomp_cooldown <= 0.0:
		stomp_cooldown = 0.3
		player.velocity.y = STOMP_BOUNCE
		take_stomp()
	elif stomp_cooldown <= 0.0:
		hurt_player()


# Called by attacks too (sword swing, slam). Respects the cooldown, so one hit = one life.
func hurt_player() -> void:
	if hurt_cooldown > 0.0 or defeated or harmless:
		return
	hurt_cooldown = TOUCH_COOLDOWN
	level.enemy_hit_player()


func take_stomp() -> void:
	health -= 1
	Sfx.play("stomp")
	sprite.modulate = Color(3, 3, 3)  # white flash
	create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.25)
	if health <= 0:
		_die()
	else:
		on_stomped()


func _die() -> void:
	defeated = true
	Sfx.play("enemy_defeat")
	hitbox.set_deferred("monitoring", false)
	var poof = CPUParticles2D.new()
	poof.position = Vector2(0, -12)
	poof.emitting = true
	poof.one_shot = true
	poof.explosiveness = 1.0
	poof.amount = 16
	poof.lifetime = 0.6
	poof.spread = 180.0
	poof.initial_velocity_min = 40.0
	poof.initial_velocity_max = 110.0
	poof.gravity = Vector2(0, 160)
	poof.scale_amount_min = 2.0
	poof.scale_amount_max = 3.0
	poof.color = Color("#B8E4FF")
	add_child(poof)
	var fade = create_tween()
	fade.tween_property(sprite, "scale", Vector2(1.3, 0.3), 0.15)
	fade.parallel().tween_property(self, "modulate:a", 0.0, 0.6)
	fade.tween_callback(queue_free)


# The level calls this (through the "enemies" group) when the player respawns
func reset_after_player_death() -> void:
	if defeated:
		return
	global_position = start_position
	reset_physics_interpolation()
	velocity = Vector2.ZERO
	direction = -1
	hurt_cooldown = TOUCH_COOLDOWN   # not 0: its hitbox can still "remember" touching you for a frame
	on_reset()


# ---------- helpers for the enemy types ----------

# Walk back and forth, turning at the patrol limits, walls and ledges
func patrol(speed: float = walk_speed) -> void:
	if patrol_distance <= 0.0:
		return
	var past_limit = (global_position.x - start_position.x) * direction > patrol_distance
	if past_limit or is_on_wall() or not ground_ahead():
		direction = -direction
	velocity.x = direction * speed


# Walk towards x, but never further than `limit` from the start, and never off a ledge
func walk_towards(x: float, speed: float, limit: float) -> void:
	var target = clamp(x, start_position.x - limit, start_position.x + limit)
	if abs(target - global_position.x) < 4.0:
		return
	direction = 1 if target > global_position.x else -1
	if ground_ahead() and not is_on_wall():
		velocity.x = direction * speed


# Swap between the walking frames while moving
func animate_walk(delta: float, frame_time: float) -> void:
	if frames.is_empty():
		return
	walk_time = walk_time + delta if velocity.x != 0.0 else 0.0
	sprite.texture = frames[int(walk_time / frame_time) % frames.size()]


func ground_ahead() -> bool:
	var from = global_position + Vector2(direction * 10, -4) * SIZE
	var query = PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 16), 1, [get_rid()])
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()


# Can it see the player? (close enough, and no wall or floor in between)
func sees_player(max_distance: float, max_height: float = 60.0) -> bool:
	if player == null or level.respawning:
		return false
	var offset = player.global_position - global_position
	if abs(offset.x) > max_distance or abs(offset.y + 12) > max_height:
		return false
	var eye = global_position + Vector2(0, -14) * SIZE
	var query = PhysicsRayQueryParameters2D.create(eye, player.global_position, 1, [get_rid()])
	var hit = get_world_2d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.collider == player


func face_player() -> void:
	direction = 1 if player.global_position.x > global_position.x else -1
