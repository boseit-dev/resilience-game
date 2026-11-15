extends Node2D

# RESILIENCE - THE HOLLOW WARDEN (Level 1 mini-boss)
# Walks left and right. Land on its head five times to beat it.
# Every few seconds it flashes red, shakes, then CHARGES at the player: jump over it.
# Each stomp makes it LEAP AWAY to the far side (so you can't keep bouncing on its head)
# and SEALS the player's jump for 5 seconds. Meanwhile it stands still and calls down
# strikes: a red mark flashes on the floor under the player, then an orb slams down there.
# Walk (or dash) away from the marks to dodge.
# On its last 2 hearts it gets angry: hops higher, charges twice as often, strikes faster.
# It sleeps until the player drops into its arena, then the boss music starts.
# After 3 stomps the game pauses for the SOUL STRIKE challenge (special_attack.gd):
# spam SPACE to rip off one more heart.
# Touching its side costs a life: level_1.gd listens to touched_player.

signal touched_player(body: Node2D)
signal defeated

@export var health: int = 5               # hearts are added automatically to match
@export var speed: float = 90.0           # walking speed, goes up after every hit
@export var patrol_distance: float = 190.0  # how far it walks each way from where it starts

const SPEED_UP_PER_HIT = 25.0
const STOMP_BOUNCE = -380.0
const HOP_VELOCITY = -300.0
const ANGRY_HOP_VELOCITY = -420.0
const HOP_EVERY = 2.2                     # seconds between hops once it is hurt
const SAFE_TIME = 0.7                     # flashing time after a hit (can't be hit or hurt you)

const CHARGE_SPEED = 430.0
const CHARGE_EVERY = 3.0                  # seconds between charges (half that when angry)
const WARN_TIME = 0.6                     # how long it flashes red before charging
const ANGRY_AT = 2                        # hearts left when it gets angry
const WARN_COLOR = Color(1.0, 0.4, 0.4)

const JUMP_LOCK_TIME = 5.0                # a stomp seals the player's jump this long...
const STRIKE_EVERY = 0.8                  # ...while a strike comes down this often (faster when angry)
const ANGRY_STRIKE_EVERY = 0.55
const STRIKE_WARN = 0.6                   # how long the red mark shows before the orb drops
const LEAP_AWAY_TIME = 0.45              # after a stomp it leaps to the far end of its patrol
const SPECIAL_AFTER_HITS = 3              # stomps before the Soul Strike challenge pops up
const WAKE_DISTANCE = 420.0               # it wakes when the player is this close and on its floor

var start_x: float
var floor_y: float
var direction: int = -1
var safe_timer: float = 0.0
var hop_timer: float = HOP_EVERY
var hop_speed: float = 0.0
var hop_height: float = 0.0
var max_health: int
var charge_timer: float = CHARGE_EVERY
var warn_timer: float = 0.0
var charging: bool = false
var awake: bool = false
var attack_timer: float = 0.0
var strike_timer: float = 0.0
var orb_texture: AtlasTexture

@onready var art: AnimatedSprite2D = $Art
@onready var hearts: Node2D = $Hearts


func _ready() -> void:
	start_x = position.x
	floor_y = position.y
	max_health = health

	# One heart per point of health, spaced evenly above its head
	while hearts.get_child_count() < health:
		hearts.add_child(hearts.get_child(0).duplicate())
	var count = hearts.get_child_count()
	for i in count:
		hearts.get_child(i).position.x = (i - (count - 1) / 2.0) * 12.0
	_update_hearts()

	# The strike orb is a Deep-Night sparkle
	orb_texture = AtlasTexture.new()
	orb_texture.atlas = preload("res://assets/Deep-Night/Tiles-and-Enemies-transparent.png")
	orb_texture.region = Rect2(0, 136, 8, 8)


func _physics_process(delta: float) -> void:
	var player = get_node_or_null("../Player")

	# Asleep until the player drops into the arena
	if not awake:
		if player and abs(player.global_position.x - start_x) < WAKE_DISTANCE and player.global_position.y > floor_y - 60.0:
			awake = true
			Sfx.play_boss_music()
		else:
			return

	# Flash for a moment after being stomped
	if safe_timer > 0.0:
		safe_timer -= delta
		art.visible = int(safe_timer * 20.0) % 2 == 0
		return
	art.visible = true

	# After a stomp: stand still and call down strikes on the player until the seal wears off
	if attack_timer > 0.0:
		attack_timer -= delta
		strike_timer -= delta
		if strike_timer <= 0.0 and player:
			_spawn_strike(player.global_position.x)
			if _is_angry():  # a second strike near the player, to make dodging harder
				_spawn_strike(player.global_position.x + randf_range(-120.0, 120.0))
			strike_timer = ANGRY_STRIKE_EVERY if _is_angry() else STRIKE_EVERY
		return

	if charging:
		# Rush in one direction until it reaches the edge of its patrol
		position.x += direction * CHARGE_SPEED * delta
		if abs(position.x - start_x) >= patrol_distance:
			position.x = clamp(position.x, start_x - patrol_distance, start_x + patrol_distance)
			_end_charge()

	elif warn_timer > 0.0:
		# Wind-up: stand still, shake and glow red so the player knows to jump
		warn_timer -= delta
		art.offset.x = randf_range(-0.5, 0.5)
		if warn_timer <= 0.0:
			art.offset.x = 0.0
			charging = true

	else:
		# Walk left and right
		position.x += direction * speed * delta
		if position.x < start_x - patrol_distance:
			direction = 1
		elif position.x > start_x + patrol_distance:
			direction = -1

		# Time to charge: turn towards the player and start the wind-up
		charge_timer -= delta
		if charge_timer <= 0.0 and player:
			direction = 1 if player.global_position.x > global_position.x else -1
			warn_timer = WARN_TIME
			art.modulate = WARN_COLOR

	art.flip_h = direction < 0

	# Once hurt, it starts hopping
	if health < max_health and warn_timer <= 0.0:
		hop_timer -= delta
		if hop_timer <= 0.0 and hop_height == 0.0:
			hop_speed = ANGRY_HOP_VELOCITY if _is_angry() else HOP_VELOCITY
			hop_timer = HOP_EVERY / 2.0 if _is_angry() else HOP_EVERY

	if hop_speed != 0.0:
		hop_speed += 980.0 * delta
		hop_height = min(0.0, hop_height + hop_speed * delta)
		if hop_height == 0.0:
			hop_speed = 0.0

	position.y = floor_y + hop_height


# Player touched the Warden: from above = stomp, from the side = hurt
func _on_hitbox_body_entered(body: Node2D) -> void:
	if body.name != "Player" or safe_timer > 0.0:
		return

	var from_above = (
		body.velocity.y > 0.0
		and body.global_position.y < global_position.y - 18.0
	)

	if from_above:
		_take_hit(body)
	else:
		touched_player.emit(body)


func _take_hit(player: Node2D) -> void:
	health -= 1
	player.velocity.y = STOMP_BOUNCE
	speed += SPEED_UP_PER_HIT
	safe_timer = SAFE_TIME
	warn_timer = 0.0  # a stomp interrupts a charge
	art.offset.x = 0.0
	_end_charge()
	hop_speed = 0.0  # land straight away if it was mid-hop
	hop_height = 0.0
	position.y = floor_y
	_update_hearts()
	Sfx.play("warden_hit")

	if health <= 0:
		_die()
	else:
		# Leap to the far end of its patrol, away from the player (it can't be touched while flashing)
		var left_end = start_x - patrol_distance
		var right_end = start_x + patrol_distance
		var target_x = right_end if player.global_position.x < position.x else left_end
		if abs(target_x - position.x) < 100.0:  # already at that end: go to the other one
			target_x = left_end if target_x == right_end else right_end
		direction = 1 if target_x > position.x else -1
		art.flip_h = direction < 0
		create_tween().tween_property(self, "position:x", target_x, LEAP_AWAY_TIME)

		# Seal the player's jump and start the strike attack (after the flashing)
		player.jump_locked_timer = JUMP_LOCK_TIME
		attack_timer = JUMP_LOCK_TIME - SAFE_TIME
		strike_timer = 0.0

		if health == max_health - SPECIAL_AFTER_HITS:
			_start_special.call_deferred(player)  # deferred: we're inside a physics callback


# Pause everything and give the player the Soul Strike challenge
func _start_special(player: Node2D) -> void:
	var special = preload("res://special_attack.gd").new()
	special.name = "SoulStrike"
	get_parent().add_child(special)
	special.start(self, player)


# Called by special_attack.gd when the player wins the challenge
func special_hit() -> void:
	health -= 1
	_update_hearts()
	if health <= 0:
		_die()


func _die() -> void:
	set_physics_process(false)
	$Hitbox.set_deferred("monitoring", false)
	art.visible = true
	hearts.hide()
	$Burst.emitting = true
	Sfx.play("warden_die")
	defeated.emit()
	Sfx.play_level_music()

	var tween = create_tween()
	tween.tween_property(art, "modulate:a", 0.0, 0.8)
	tween.tween_callback(queue_free)


# One strike: a red mark blinks on the floor at x, then an orb drops onto it.
# Only the moment it lands can hurt (it is a short-lived Area2D).
func _spawn_strike(x: float) -> void:
	var strike = Area2D.new()
	strike.name = "WardenStrike"
	strike.add_to_group("warden_strike")
	strike.monitoring = false
	get_parent().add_child(strike)
	strike.global_position = Vector2(x, floor_y)
	strike.body_entered.connect(_on_strike_body_entered)

	var hit_area = CollisionShape2D.new()
	hit_area.shape = RectangleShape2D.new()
	hit_area.shape.size = Vector2(20, 24)
	hit_area.position = Vector2(0, -12)
	strike.add_child(hit_area)

	var marker = ColorRect.new()
	marker.name = "Marker"
	marker.color = Color(1.6, 0.3, 0.3)  # over 1.0 so it glows through the level's darkness
	marker.size = Vector2(28, 4)
	marker.position = Vector2(-14, -4)
	strike.add_child(marker)

	var orb = Sprite2D.new()
	orb.texture = orb_texture
	orb.scale = Vector2(3, 3)
	orb.modulate = Color(1.8, 0.5, 0.5)
	orb.position = Vector2(0, -320)
	orb.hide()
	strike.add_child(orb)

	var steps = strike.create_tween()
	for i in 3:  # blink the mark
		steps.tween_property(marker, "modulate:a", 0.25, STRIKE_WARN / 6.0)
		steps.tween_property(marker, "modulate:a", 1.0, STRIKE_WARN / 6.0)
	steps.tween_callback(orb.show)
	steps.tween_property(orb, "position:y", -12.0, 0.2)  # drop
	steps.tween_callback(func():
		strike.set_deferred("monitoring", true)
		Sfx.play("warden_strike"))
	steps.tween_interval(0.15)
	steps.tween_callback(strike.queue_free)


func _on_strike_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		touched_player.emit(body)


func _end_charge() -> void:
	charging = false
	art.modulate = Color.WHITE
	charge_timer = CHARGE_EVERY / 2.0 if _is_angry() else CHARGE_EVERY


func _is_angry() -> bool:
	return health <= ANGRY_AT


# Little hearts above its head
func _update_hearts() -> void:
	for i in hearts.get_child_count():
		hearts.get_child(i).visible = i < health
