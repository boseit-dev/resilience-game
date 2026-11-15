extends Area2D

# RESILIENCE - ELECTRIC BEAM (timed hazard)
# A crackling beam between two emitters. It is OFF, then flickers as a warning,
# then turns ON. Touching it while it's on costs a life (like spikes).
#   off_time, on_time  seconds in each state      offset  delay at the start (to make patterns)
#   length             beam length in pixels      vertical  true = floor to ceiling
const WARNING = 0.5   # seconds of flicker before it turns on

var length = 80.0
var vertical = true
var on_time = 1.2
var off_time = 1.6
var offset = 0.0
var active = true   # false = switched off (the boss turns its arena beams on)
var level: Node
var beam: Line2D
var glow: PointLight2D
var shape: CollisionShape2D
var t = 0.0
var is_on = false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	t = -offset
	var along = Vector2(0, length) if vertical else Vector2(length, 0)
	shape = CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(10, length) if vertical else Vector2(length, 10)
	shape.position = along / 2.0
	add_child(shape)
	for end in [Vector2.ZERO, along]:   # the two emitters (small dark boxes)
		var box = ColorRect.new()
		box.size = Vector2(12, 6) if vertical else Vector2(6, 12)
		box.position = end - box.size / 2.0
		box.color = Color("#2A3440")
		add_child(box)
	beam = Line2D.new()
	beam.width = 3.0
	beam.default_color = Color(0.6, 0.95, 1.0)
	add_child(beam)
	glow = PointLight2D.new()
	glow.texture = GradientTexture2D.new()   # a soft round light
	glow.texture.fill = GradientTexture2D.FILL_RADIAL
	glow.texture.fill_from = Vector2(0.5, 0.5)
	glow.texture.fill_to = Vector2(0.5, 0.0)
	glow.texture.gradient = Gradient.new()
	glow.texture.gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	glow.texture_scale = length / 40.0
	glow.color = Color("#7FE7FF")
	glow.position = along / 2.0
	add_child(glow)
	body_entered.connect(_on_body_entered)


# Puzzles switch beams with these: open() = off (safe to pass), close() = on again
func open() -> void:
	active = false


func close() -> void:
	active = true


func _physics_process(delta: float) -> void:
	if not active:
		is_on = false   # switched off: invisible AND harmless
		beam.clear_points()
		glow.energy = 0.0
		return
	t += delta
	var cycle = fposmod(t, off_time + on_time) if t >= 0.0 else 0.0
	var was_on = is_on
	is_on = cycle >= off_time
	var warning = not is_on and cycle >= off_time - WARNING
	if is_on and not was_on:
		Sfx.play("armour_hit", 1.6)
		for body in get_overlapping_bodies():   # standing in it when it turns on counts too
			_on_body_entered(body)
	_draw_beam(is_on, warning)


func _draw_beam(on: bool, warning: bool) -> void:
	beam.clear_points()
	glow.energy = 1.2 if on else (0.35 if warning and int(t * 20.0) % 2 == 0 else 0.0)
	if not on and not (warning and int(t * 20.0) % 2 == 0):
		return
	beam.width = 3.0 if on else 1.0
	var along = Vector2(0, length) if vertical else Vector2(length, 0)
	var side = Vector2(1, 0) if vertical else Vector2(0, 1)
	for i in 9:   # a jagged lightning line
		var wobble = randf_range(-3.0, 3.0) if (on and i > 0 and i < 8) else 0.0
		beam.add_point(along * (i / 8.0) + side * wobble)


func _on_body_entered(body: Node2D) -> void:
	if active and is_on and level and body == level.player:
		level._on_spikes_body_entered(body)
