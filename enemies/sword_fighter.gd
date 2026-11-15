extends "res://enemies/enemy.gd"

# RESILIENCE - SWORD FIGHTER
# Patrols. When it sees you nearby it chases (but never far from home), stops, raises its
# sword (it flashes: that's your warning), then swings. One stomp defeats it.

const SEE_DISTANCE = 170.0
const CHASE_SPEED = 95.0
const CHASE_LIMIT = 200.0       # never chases further than this from its start
const SWING_RANGE = 38.0        # how close you must be for it to start a swing
const WINDUP_TIME = 0.45        # the warning: sword raised
const SWING_TIME = 0.15
const COOLDOWN_TIME = 0.9
const WALK_FRAMES = [15, 16]

enum State { PATROL, CHASE, WINDUP, SWING, COOLDOWN }
var state = State.PATROL
var timer = 0.0
var sword: Polygon2D


func build() -> void:
	for f in WALK_FRAMES:
		frames.append(load(CHARACTERS % f))
	# The sword: a grey blade with a gold guard, held at the hand and rotated to swing
	sword = Polygon2D.new()
	sword.polygon = PackedVector2Array([Vector2(0, -1), Vector2(16, -1), Vector2(19, 0), Vector2(16, 1), Vector2(0, 1)])
	sword.color = Color("#D9E2F2")
	var guard = Polygon2D.new()
	guard.polygon = PackedVector2Array([Vector2(-1, -3), Vector2(1, -3), Vector2(1, 3), Vector2(-1, 3)])
	guard.color = Color("#E0B04A")
	sword.add_child(guard)
	sword.position = Vector2(0, -9)
	add_child(sword)


func think(delta: float) -> void:
	timer -= delta
	match state:
		State.PATROL:
			patrol()
			if sees_player(SEE_DISTANCE, 40.0):
				state = State.CHASE
		State.CHASE:
			var dx = player.global_position.x - global_position.x
			if not sees_player(SEE_DISTANCE + 90.0, 40.0):
				state = State.PATROL
			elif abs(dx) < SWING_RANGE:
				face_player()
				state = State.WINDUP
				timer = WINDUP_TIME
				Sfx.play("sword_warn")
			else:
				walk_towards(player.global_position.x, CHASE_SPEED, CHASE_LIMIT)
		State.WINDUP:
			sprite.modulate = Color(1.8, 1.8, 1.8) if int(timer * 20) % 2 == 0 else Color.WHITE
			if timer <= 0.0:
				sprite.modulate = Color.WHITE
				state = State.SWING
				timer = SWING_TIME
				Sfx.play("sword_swing")
				_swing_hits()
		State.SWING:
			if timer <= 0.0:
				state = State.COOLDOWN
				timer = COOLDOWN_TIME
		State.COOLDOWN:
			if timer <= 0.0:
				state = State.CHASE
	_pose_sword()
	animate_walk(delta, 0.15)


# The swing only hurts if you're in front of it, at arm's length, at the same height
func _swing_hits() -> void:
	var offset = player.global_position - global_position
	if offset.x * direction > -6.0 and offset.x * direction < 42.0 and abs(offset.y + 12) < 26.0:
		hurt_player()


# Sword angle for each state (pointing the way it faces)
func _pose_sword() -> void:
	var angle = 35.0           # resting, pointing forward and down
	if state == State.WINDUP:
		angle = -110.0         # raised high: the warning
	elif state == State.SWING:
		angle = 60.0           # slashed down
	sword.position.x = 5.0 * direction
	sword.scale.x = direction
	sword.rotation_degrees = angle * direction




func on_stomped() -> void:
	state = State.COOLDOWN
	timer = COOLDOWN_TIME


func on_reset() -> void:
	state = State.PATROL
	sprite.modulate = Color.WHITE
