extends Node2D

# RESILIENCE - FALLING ROCKS (Level 3)
# Every few seconds dust trickles from the ceiling and a mark blinks on the floor,
# then a rock drops there. Getting hit costs a life (a shield takes it).
# The map places these; the symbol puzzle and the Crystal Behemoth use drop() directly.

const WARN = 0.8

var floor_y = 380.0
var every = 3.0
var t = 0.0


func _physics_process(delta: float) -> void:
	t += delta
	if t >= every:
		t = 0.0
		drop(get_parent(), position.x, floor_y, WARN, 1.0)


# One rock: a mark blinks on the floor at x for warn seconds, then the rock falls onto it.
# It hurts the player if it passes through them on the way down (a shield takes it).
static func drop(parent: Node, x: float, floor_top: float, warn: float, size: float, color := Color(0.62, 0.55, 0.75)) -> void:
	var rock = Node2D.new()
	rock.add_to_group("falling_rock")
	parent.add_child(rock)
	rock.global_position = Vector2(x, floor_top - 300.0)
	var art = Polygon2D.new()
	art.polygon = PackedVector2Array([Vector2(-7, -4), Vector2(-3, -8), Vector2(5, -7), Vector2(8, 0), Vector2(4, 7), Vector2(-5, 7), Vector2(-8, 2)])
	art.scale = Vector2(size, size)
	art.color = color
	art.hide()
	rock.add_child(art)
	var mark = ColorRect.new()
	mark.color = Color(1.6, 0.8, 1.8)   # over 1.0 so it shows through the darkness
	mark.size = Vector2(22 * size, 3)
	mark.position = Vector2(-11 * size, 297)
	rock.add_child(mark)
	var hit = [false]   # only one hit per rock

	var steps = rock.create_tween()
	for i in 3:
		steps.tween_property(mark, "modulate:a", 0.2, warn / 6.0)
		steps.tween_property(mark, "modulate:a", 1.0, warn / 6.0)
	steps.tween_callback(func():
		art.show()
		mark.hide())
	steps.tween_method(func(y: float):
		rock.global_position.y = y
		var level = rock.get_tree().current_scene
		var p = level.get("player")
		if p and not hit[0] and y > floor_top - 100.0 and absf(p.global_position.x - x) < 7.0 * size + 10.0 and absf(p.global_position.y - y) < 7.0 * size + 12.0:
			hit[0] = true
			level.enemy_hit_player(),
		floor_top - 300.0, floor_top - 7.0 * size, 0.35).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	steps.tween_callback(func(): Sfx.play("slam", 1.6 / size))
	steps.tween_property(art, "modulate:a", 0.0, 0.25)
	steps.tween_callback(rock.queue_free)
