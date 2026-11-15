extends StaticBody2D

# RESILIENCE - CRUMBLING LEDGE (Level 3)
# Stand on it and it cracks, shakes for a moment, then falls away. It grows back a few
# seconds later. Keep moving! The map scripts set width before adding it.

const SHAKE_TIME = 0.5
const BACK_AFTER = 3.0
const HEIGHT = 10.0

var width = 48.0
var timer = 0.0        # counting down: shaking, then gone
var state = "solid"    # "solid", "shaking" or "gone"
var art: Node2D
var shape: CollisionShape2D
var level: Node


func _ready() -> void:
	shape = CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(width, HEIGHT)
	shape.position = Vector2(0, HEIGHT / 2.0)   # the top edge is at the ledge's position
	add_child(shape)
	art = Node2D.new()
	add_child(art)
	var x = -width / 2.0
	while x < width / 2.0 - 1.0:   # cracked stone slabs
		var slab = Polygon2D.new()
		var w = minf(16.0, width / 2.0 - x)
		slab.polygon = PackedVector2Array([Vector2(x, 0), Vector2(x + w, 0), Vector2(x + w - 2, HEIGHT), Vector2(x + 2, HEIGHT)])
		slab.color = Color(0.5, 0.42, 0.62)
		art.add_child(slab)
		x += w + 1.0


func _physics_process(delta: float) -> void:
	var p = level.player
	if state == "solid" and p.is_on_floor() and absf(p.global_position.x - global_position.x) < width / 2.0 + 10.0 \
			and absf(p.global_position.y + 12.0 - global_position.y) < 3.0:
		state = "shaking"
		timer = SHAKE_TIME
		Sfx.play("armour_hit", 0.6)   # crack
	elif state == "shaking":
		timer -= delta
		art.position = Vector2(randf_range(-1.5, 1.5), 0)
		if timer <= 0.0:
			state = "gone"
			timer = BACK_AFTER
			shape.set_deferred("disabled", true)
			Sfx.play("slam", 1.5)
			var fall = create_tween()
			fall.tween_property(art, "position:y", 80.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			fall.parallel().tween_property(art, "modulate:a", 0.0, 0.5)
	elif state == "gone":
		timer -= delta
		if timer <= 0.0:
			state = "solid"
			shape.set_deferred("disabled", false)
			art.position = Vector2.ZERO
			create_tween().tween_property(art, "modulate:a", 1.0, 0.3)
