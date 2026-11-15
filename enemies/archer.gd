extends "res://enemies/enemy.gd"

# RESILIENCE - ARCHER
# Stands guard on high ground. When it can see you (no wall in between), it turns to face
# you, draws its bow (the string pulls back: your warning), and fires an arrow at where you
# are. Then it waits before the next shot. One stomp defeats it.

const ARROW = preload("res://enemies/arrow.gd")
const SEE_DISTANCE = 360.0
const DRAW_TIME = 0.6
const COOLDOWN_TIME = 1.8
const ARROW_SPEED = 240.0

var draw_timer = 0.0
var cooldown = 0.6
var bow: Line2D
var string: Line2D


func _init() -> void:
	patrol_distance = 0.0  # archers hold their ground
	hitbox_size = Vector2(14, 18)
	look = 18


func build() -> void:
	bow = Line2D.new()
	bow.width = 1.5
	bow.default_color = Color("#B07A44")
	bow.points = PackedVector2Array([Vector2(0, -8), Vector2(3, -4), Vector2(4, 0), Vector2(3, 4), Vector2(0, 8)])
	add_child(bow)
	string = Line2D.new()
	string.width = 1.0
	string.default_color = Color("#E8F5FF")
	add_child(string)


func think(delta: float) -> void:
	cooldown -= delta
	var sees = sees_player(SEE_DISTANCE, 200.0)
	if sees:
		face_player()
	if draw_timer > 0.0:
		draw_timer -= delta
		if draw_timer <= 0.0:
			_fire()
	elif sees and cooldown <= 0.0:
		draw_timer = DRAW_TIME
		Sfx.play("bow_draw")
	_pose_bow()


func _fire() -> void:
	cooldown = COOLDOWN_TIME
	if not sees_player(SEE_DISTANCE + 40.0, 220.0):
		return  # you ducked behind something: hold the arrow
	var arrow = ARROW.new()
	var from = global_position + Vector2(direction * 8, -10)
	arrow.velocity = (player.global_position - from).normalized() * ARROW_SPEED
	get_parent().add_child(arrow)  # not a child of the archer, so it keeps flying if the archer dies
	arrow.global_position = from
	Sfx.play("arrow")


# The bow sits in front; the string is pulled back while drawing
func _pose_bow() -> void:
	bow.position = Vector2(6 * direction, -10)
	bow.scale.x = direction
	var pull = 0.0
	if draw_timer > 0.0:
		pull = 6.0 * (1.0 - draw_timer / DRAW_TIME)
	string.position = bow.position
	string.points = PackedVector2Array([Vector2(0, -8), Vector2(-pull * direction, 0), Vector2(0, 8)])


func on_stomped() -> void:
	draw_timer = 0.0


func on_reset() -> void:
	draw_timer = 0.0
	cooldown = 0.6
