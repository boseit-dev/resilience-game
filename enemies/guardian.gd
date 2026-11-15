extends "res://enemies/enemy.gd"

# RESILIENCE - ARMOURED GUARDIAN
# Slow and heavy. When you get close it crouches and glows red (your warning), then
# slams the ground, hurting anyone near it on either side. Needs 3 stomps:
#   1st stomp: the armour cracks.   2nd: it breaks (pieces fall off).   3rd: defeated.
# After each stomp it's stunned for a moment (it can't attack).

const SEE_DISTANCE = 220.0
const SLAM_RANGE = 70.0         # starts a slam when you're this close
const SLAM_REACH = 58.0         # the slam hurts within this distance (both sides)
const WARN_TIME = 0.8
const RECOVER_TIME = 1.0
const STUN_TIME = 1.0
const CHASE_LIMIT = 160.0
const WALK_FRAMES = [21, 22]

enum State { PATROL, WARN, RECOVER, STUN }
var state = State.PATROL
var timer = 0.0
var cracks: Node2D


func _init() -> void:
	health = 3
	walk_speed = 32.0
	hitbox_size = Vector2(20, 22)
	look = 21


func build() -> void:
	for f in WALK_FRAMES:
		frames.append(load(CHARACTERS % f))
	cracks = Node2D.new()
	cracks.position = sprite.position
	add_child(cracks)


func think(delta: float) -> void:
	timer -= delta
	match state:
		State.PATROL:
			if sees_player(SEE_DISTANCE, 40.0):
				var dx = player.global_position.x - global_position.x
				if abs(dx) < SLAM_RANGE:
					state = State.WARN
					timer = WARN_TIME
					Sfx.play("guardian_warn")
				else:
					walk_towards(player.global_position.x, walk_speed * 1.4, CHASE_LIMIT)
			else:
				patrol()
		State.WARN:
			# Crouch and glow red: the slam is coming
			var t = 1.0 - timer / WARN_TIME
			sprite.scale = Vector2(1.0 + 0.15 * t, 1.0 - 0.2 * t)
			sprite.modulate = Color(1.0 + t, 1.0 - 0.6 * t, 1.0 - 0.6 * t)
			if timer <= 0.0:
				_slam()
		State.RECOVER, State.STUN:
			if timer <= 0.0:
				state = State.PATROL
				sprite.modulate = _armour_color()
	animate_walk(delta, 0.25)
	cracks.scale.x = -1.0 if direction > 0 else 1.0  # cracks flip with the sprite


func _slam() -> void:
	state = State.RECOVER
	timer = RECOVER_TIME
	sprite.scale = Vector2.ONE
	sprite.modulate = _armour_color()
	Sfx.play("slam")
	var dust = CPUParticles2D.new()
	dust.emitting = true
	dust.one_shot = true
	dust.explosiveness = 1.0
	dust.amount = 14
	dust.lifetime = 0.5
	dust.direction = Vector2(0, -1)
	dust.spread = 80.0
	dust.initial_velocity_min = 60.0
	dust.initial_velocity_max = 120.0
	dust.gravity = Vector2(0, 300)
	dust.scale_amount_min = 2.0
	dust.scale_amount_max = 3.0
	dust.color = Color("#8D97B3")
	add_child(dust)
	var offset = player.global_position - global_position
	if abs(offset.x) < SLAM_REACH and abs(offset.y + 12) < 30.0:
		hurt_player()


func on_stomped() -> void:
	Sfx.play("armour_hit")
	state = State.STUN
	timer = STUN_TIME
	sprite.scale = Vector2.ONE
	sprite.modulate = _armour_color()
	_draw_cracks()


# Armour gets darker as it breaks
func _armour_color() -> Color:
	return [Color.WHITE, Color.WHITE, Color(0.8, 0.8, 0.9), Color(0.62, 0.62, 0.75)][clamp(4 - health, 0, 3)]


# 1st stomp: a few cracks. 2nd stomp: many cracks and armour pieces fall off.
func _draw_cracks() -> void:
	var lines = [[Vector2(-6, -8), Vector2(-2, -3), Vector2(-4, 2)], [Vector2(5, -9), Vector2(2, -4)]]
	if health <= 1:
		lines += [[Vector2(-8, 0), Vector2(-3, 4), Vector2(1, 2), Vector2(6, 6)], [Vector2(3, -2), Vector2(7, 1)], [Vector2(-1, -10), Vector2(0, -6), Vector2(-2, -4)]]
		var pieces = CPUParticles2D.new()
		pieces.emitting = true
		pieces.one_shot = true
		pieces.explosiveness = 1.0
		pieces.amount = 8
		pieces.lifetime = 0.8
		pieces.spread = 60.0
		pieces.direction = Vector2(0, -1)
		pieces.initial_velocity_min = 50.0
		pieces.initial_velocity_max = 90.0
		pieces.gravity = Vector2(0, 400)
		pieces.scale_amount_min = 3.0
		pieces.scale_amount_max = 4.0
		pieces.color = Color("#5B7DB8")
		pieces.position = Vector2(0, -14)
		add_child(pieces)
	for child in cracks.get_children():
		child.queue_free()
	for points in lines:
		var crack = Line2D.new()
		crack.width = 1.0
		crack.default_color = Color("#10121C")
		crack.points = PackedVector2Array(points)
		cracks.add_child(crack)




func on_reset() -> void:
	state = State.PATROL
	sprite.scale = Vector2.ONE
	sprite.modulate = _armour_color()
