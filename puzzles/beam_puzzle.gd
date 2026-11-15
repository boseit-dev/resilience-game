extends "res://puzzles/puzzle.gd"

# RESILIENCE - CRYSTAL LIGHT PUZZLE
# A beam of light shoots out of an emitter. Each prism catches the beam and sends it on in the
# direction its arrow points. Press E next to a prism to turn it a quarter turn.
# Walls and closed doors stop the beam. Get it to the receiver and the puzzle is solved.
# data: emitter [position, direction], prisms [[position, direction], ...], receiver position
# Directions: 0 right, 1 down, 2 left, 3 up.

const DIRS = [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]
const BEAM_COLOR = Color(1.9, 1.3, 2.6)

var facing = []         # where each prism points now
var arrows = []         # the little arrow on each prism
var beam: Line2D
var receiver_light: PointLight2D


func _ready() -> void:
	super._ready()
	beam = Line2D.new()
	beam.width = 2.0
	beam.default_color = BEAM_COLOR
	add_child(beam)
	_sprite(GEM, data.emitter[0], Color(2.2, 1.6, 2.6)).scale = Vector2(1.3, 1.3)
	for i in data.prisms.size():
		var p = data.prisms[i]
		facing.append(p[1])
		_sprite(GEM, p[0], Color(0.75, 1.5, 1.9))
		var arrow = Polygon2D.new()
		arrow.polygon = PackedVector2Array([Vector2(7, -3), Vector2(13, 0), Vector2(7, 3)])
		arrow.color = Color(1.6, 1.6, 0.8)
		arrow.position = p[0]
		add_child(arrow)
		arrows.append(arrow)
		add_spot(p[0], turn.bind(i))
	_sprite(GEM, data.receiver, Color(1.2, 0.6, 0.6)).scale = Vector2(1.4, 1.4)
	receiver_light = level.get_node("Decor/CrystalGlow").duplicate()
	receiver_light.position = data.receiver
	receiver_light.energy = 0.0
	add_child(receiver_light)


func turn(i: int) -> void:
	facing[i] = (facing[i] + 1) % 4
	Sfx.play("pad_bounce", 1.5)


func reset() -> void:
	super.reset()
	for i in facing.size():
		facing[i] = data.prisms[i][1]


# Follow the beam every frame (doors can move into its way)
func _physics_process(_delta: float) -> void:
	for i in arrows.size():
		arrows[i].rotation = DIRS[facing[i]].angle()
	var pos: Vector2 = data.emitter[0]
	var dir: Vector2 = DIRS[data.emitter[1]]
	var points = [pos]
	var lit = false
	for bounce in 10:
		var hit = _next_in_line(pos, dir)
		var end = pos + dir * 900.0 if hit == -2 else (data.receiver if hit == -1 else data.prisms[hit][0])
		var wall = get_world_2d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters2D.create(pos + dir * 2.0, end, 1, [level.player.get_rid()]))
		if wall:
			points.append(wall.position)
			break
		points.append(end)
		if hit == -2:
			break
		if hit == -1:
			lit = true
			break
		pos = end
		dir = DIRS[facing[hit]]
	beam.points = PackedVector2Array(points)
	receiver_light.energy = 1.4 if lit else 0.0
	if lit:
		solve()


# The nearest prism (its number) or the receiver (-1) straight ahead on the beam's line; -2 = none
func _next_in_line(from: Vector2, dir: Vector2) -> int:
	var best = -2
	var best_distance = INF
	var things = data.prisms.map(func(p): return p[0]) + [data.receiver]
	for i in things.size():
		var d: Vector2 = things[i] - from
		var ahead = d.dot(dir)
		if ahead > 1.0 and absf(d.cross(dir)) < 4.0 and ahead < best_distance:
			best_distance = ahead
			best = i if i < data.prisms.size() else -1
	return best
