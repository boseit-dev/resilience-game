extends Control

# RESILIENCE - MENU ORNAMENTS
# Draws the decorative flourishes on the main menu with lines and curls (no image files).
#   TOP:    the flourish above the title
#   BOTTOM: the flourish under the title, with a hanging crest
#   MARKER: the little curl next to the selected menu item (set flip for the right-hand one)

enum Kind { TOP, BOTTOM, MARKER }

var kind: int = Kind.TOP
var flip: bool = false
var color: Color = Color("#F2F6FF")


func _draw() -> void:
	match kind:
		Kind.TOP:
			_flourish(1.0)
		Kind.BOTTOM:
			_flourish(-1.0)
			_crest()
		Kind.MARKER:
			_marker()


# Long line with curls at the ends, little leaves and a diamond in the middle.
# up = 1 curls upwards (top flourish), -1 curls downwards (bottom flourish)
func _flourish(up: float) -> void:
	for side in [-1.0, 1.0]:
		# soft glow pass, then the crisp line
		for pass_style in [[5.0, 0.10], [1.6, 0.9]]:
			var c = Color(color, pass_style[1])
			var w = pass_style[0]
			draw_line(Vector2(side * 30, 0), Vector2(side * 232, 0), c, w, true)
			draw_polyline(_spiral(Vector2(side * 240, -7 * up), 9.0, side, up), c, w, true)
			# two leaves along the line
			for x in [95.0, 165.0]:
				draw_polyline(_leaf(Vector2(side * x, 0), side, up, 16.0 if x < 100 else 11.0), c, w, true)
			draw_circle(Vector2(side * 20, 0), 2.2, c)
	_diamond(Vector2.ZERO, 7.0, color)


func _crest() -> void:
	# Two curls hanging from the middle, framing a teardrop
	for side in [-1.0, 1.0]:
		draw_polyline(_spiral(Vector2(side * 16, 14), 8.0, -side, -1.0), Color(color, 0.85), 1.4, true)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, 8), Vector2(5, 20), Vector2(0, 30), Vector2(-5, 20)
	]), Color(color, 0.9))


func _marker() -> void:
	var s = -1.0 if flip else 1.0
	_diamond(Vector2(0, 0), 4.5, color)
	draw_line(Vector2(s * 7, 0), Vector2(s * 20, 0), color, 1.4, true)
	draw_polyline(_spiral(Vector2(s * 26, -4), 5.0, s, 1.0), color, 1.4, true)


# ---------- shape helpers ----------

# A curl that winds inwards (r shrinks as it turns)
func _spiral(center: Vector2, radius: float, side: float, up: float) -> PackedVector2Array:
	var points = PackedVector2Array()
	for i in 24:
		var t = i / 23.0
		var angle = PI / 2.0 * up + t * TAU * 1.1 * side * up
		var r = radius * (1.0 - t * 0.75)
		points.append(center + Vector2(-cos(angle) * side, sin(angle)) * r)
	return points


# A small arc rising off the line like a leaf
func _leaf(start: Vector2, side: float, up: float, length: float) -> PackedVector2Array:
	var points = PackedVector2Array()
	for i in 9:
		var t = i / 8.0
		points.append(start + Vector2(side * t * length, -sin(t * PI) * length * 0.45 * up - t * 3.0 * up))
	return points


func _diamond(center: Vector2, size: float, c: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(0, -size), center + Vector2(size, 0),
		center + Vector2(0, size), center + Vector2(-size, 0)
	]), c)
