extends Area2D

# RESILIENCE - ARROW (fired by archer.gd)
# Flies in a straight line. Hits the player = lose a life (or the shield takes it).
# Hits a wall or floor = gone. Gives up after 3 seconds.

var velocity = Vector2.ZERO
var life = 3.0


func _ready() -> void:
	add_to_group("arrows")
	collision_layer = 0
	collision_mask = 1
	var shape = CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(10, 3)
	add_child(shape)
	var shaft = Line2D.new()
	shaft.width = 1.0
	shaft.default_color = Color("#E8D8B0")
	shaft.points = PackedVector2Array([Vector2(-6, 0), Vector2(5, 0)])
	add_child(shaft)
	var tip = Polygon2D.new()
	tip.polygon = PackedVector2Array([Vector2(5, -2), Vector2(8, 0), Vector2(5, 2)])
	tip.color = Color("#D9E2F2")
	add_child(tip)
	rotation = velocity.angle()
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	position += velocity * delta
	life -= delta
	if life <= 0.0:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		get_tree().current_scene.enemy_hit_player()
	queue_free()  # player, wall or floor: the arrow is spent
