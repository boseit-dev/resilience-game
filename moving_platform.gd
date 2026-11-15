extends AnimatableBody2D

# RESILIENCE - MOVING PLATFORM
# A metal platform that glides back and forth between where it starts and start + travel,
# and carries the player standing on it (Godot does that for AnimatableBody2D).
# The map scripts set width, travel and time before adding it.

const TILE = preload("res://assets/kenney_pixel-platformer/Tiles/tile_0029.png")   # a plain block
const HEIGHT = 12.0

var width = 72.0
var travel = Vector2(200, 0)      # how far it moves from its start
var time = 3.0                    # seconds for one trip (there and back takes twice as long)
var start: Vector2
var t = 0.0


func _ready() -> void:
	start = position
	sync_to_physics = true
	var shape = CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(width, HEIGHT)
	shape.position = Vector2(0, HEIGHT / 2.0)   # the top edge is at the platform's position
	add_child(shape)
	var x = -width / 2.0
	while x < width / 2.0 - 1.0:
		var tile = Sprite2D.new()
		tile.texture = TILE
		tile.modulate = Color(0.75, 0.95, 1.05)   # cold lab metal, a little bright so it shows in the dark
		tile.scale = Vector2(1.0, HEIGHT / 18.0)
		tile.position = Vector2(x + 9.0, HEIGHT / 2.0)
		add_child(tile)
		x += 18.0

func _physics_process(delta: float) -> void:
	t += delta
	var phase = 0.5 - 0.5 * cos(t * PI / time)   # 0 -> 1 -> 0, slowing down at each end
	position = start + travel * phase
