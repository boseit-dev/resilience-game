extends CharacterBody2D

# RESILIENCE - HEAVY STONE BLOCK (for the pressure plate puzzles)
# Walk into its side to push it slowly. It falls into holes. You can stand on it.
# reset() puts it back where it started.

const SIZE = 28.0
const PUSH_SPEED = 70.0
const ART = preload("res://assets/kenney_pixel-platformer/Tiles/tile_0029.png")

var start: Vector2
var level: Node


func _ready() -> void:
	add_to_group("stone_block")
	start = position
	var shape = CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(SIZE, SIZE)
	add_child(shape)
	var art = Sprite2D.new()
	art.texture = ART
	art.scale = Vector2(SIZE / 18.0, SIZE / 18.0)
	art.modulate = Color(0.72, 0.66, 0.9)
	add_child(art)
	var rune = Polygon2D.new()   # a glowing carving so it reads as a puzzle block
	rune.polygon = PackedVector2Array([Vector2(0, -6), Vector2(4, 0), Vector2(0, 6), Vector2(-4, 0)])
	rune.color = Color(0.9, 1.4, 2.0)
	add_child(rune)


func _physics_process(delta: float) -> void:
	velocity.x = 0.0
	velocity.y = 0.0 if is_on_floor() else minf(velocity.y + 980.0 * delta, 600.0)
	var p = level.player
	var d = p.global_position - global_position
	var push = int(p._key(KEY_D, KEY_RIGHT)) - int(p._key(KEY_A, KEY_LEFT))
	# The player is right beside it, on the ground, walking into it
	if push != 0 and p.is_on_floor() and absf(d.y) < SIZE / 2.0 + 4.0 and absf(d.x) < SIZE / 2.0 + 14.0 and signf(-d.x) == push:
		velocity.x = push * PUSH_SPEED
		if Engine.get_physics_frames() % 20 == 0:
			Sfx.play("pad_place", 0.5)   # stone scraping
	move_and_slide()
	if is_on_floor():
		position.y = roundf(position.y)   # sit exactly on the floor, so a stone in a gap is level with it


func reset() -> void:
	position = start
	velocity = Vector2.ZERO
	reset_physics_interpolation()
