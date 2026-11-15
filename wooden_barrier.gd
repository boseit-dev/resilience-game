extends StaticBody2D

# RESILIENCE - WOODEN BARRIER
# A stack of wooden crates blocking a low passage. Walking into it does nothing;
# DASH into it (Shift) and it smashes. It stays broken until the level restarts.
# level_1_expansion.gd places these: set `height` (floor to ceiling) before adding it.

const CRATE = preload("res://assets/kenney_pixel-platformer/Tiles/tile_0026.png")
const WIDTH = 18.0

var height = 54.0
var player: Node2D
var sensor: Area2D
var broken = false


func _ready() -> void:
	player = _find_player()
	var shape = CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(WIDTH, height)
	shape.position = Vector2(0, -height / 2.0)
	add_child(shape)

	# A slightly wider zone: a dash that reaches the crates is inside it
	sensor = Area2D.new()
	sensor.collision_layer = 0
	sensor.collision_mask = 1
	var zone = CollisionShape2D.new()
	zone.shape = RectangleShape2D.new()
	zone.shape.size = Vector2(WIDTH + 10.0, height)
	zone.position = shape.position
	sensor.add_child(zone)
	add_child(sensor)

	# Crates stacked from the floor up (the top one squashed to fit)
	var y = 0.0
	while y < height - 1.0:
		var crate = Sprite2D.new()
		crate.texture = CRATE
		var h = minf(18.0, height - y)
		crate.scale.y = h / 18.0
		crate.position = Vector2(0, -y - h / 2.0)
		add_child(crate)
		y += h


func _find_player() -> Node2D:
	var node = get_parent()
	while node and not node.has_node("Player"):
		node = node.get_parent()
	return node.get_node("Player") if node else null


func _physics_process(_delta: float) -> void:
	if not broken and player and player.dash_timer > 0.0 and sensor.overlaps_body(player):
		smash()


func smash() -> void:
	broken = true
	Sfx.play("thud")
	Sfx.play("armour_hit")
	var pieces = CPUParticles2D.new()
	pieces.position = Vector2(0, -height / 2.0)
	pieces.emitting = true
	pieces.one_shot = true
	pieces.explosiveness = 1.0
	pieces.amount = 22
	pieces.lifetime = 0.9
	pieces.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	pieces.emission_rect_extents = Vector2(8, height / 2.0)
	pieces.direction = Vector2(1, -0.6)
	pieces.spread = 50.0
	pieces.initial_velocity_min = 80.0
	pieces.initial_velocity_max = 180.0
	pieces.gravity = Vector2(0, 500)
	pieces.angular_velocity_min = -400.0
	pieces.angular_velocity_max = 400.0
	pieces.scale_amount_min = 2.0
	pieces.scale_amount_max = 4.0
	pieces.color = Color("#B9773F")
	add_child(pieces)
	for child in get_children():
		if child is Sprite2D:
			child.queue_free()
		elif child is CollisionShape2D:
			child.set_deferred("disabled", true)
	sensor.queue_free()
