extends StaticBody2D

# RESILIENCE - LAB DOOR + LEVERS
# A heavy door that blocks a corridor until you have touched ALL of its levers (they can be
# anywhere). Each lever flips when touched; when the last one flips the door slides up and stays open.
# The map scripts set height and levers (world positions on the floor) before adding it.
# Puzzles (Level 3) open and close it themselves with open() and close(), with no levers.

const DOOR_TILE = preload("res://assets/kenney_pixel-platformer/Tiles/tile_0029.png")
const LEVER_OFF = preload("res://assets/kenney_pixel-platformer/Tiles/tile_0064.png")
const LEVER_ON = preload("res://assets/kenney_pixel-platformer/Tiles/tile_0066.png")
const WIDTH = 16.0

var height = 80.0
var levers = []          # Vector2 positions
var flipped = 0
var level: Node
var is_open = false
var colors = [Color(0.95, 0.75, 0.35), Color(0.5, 0.55, 0.62)]   # the two plate colours
var closed_y: float
var slide: Tween


func _ready() -> void:
	closed_y = position.y
	var shape = CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(WIDTH, height)
	shape.position = Vector2(0, -height / 2.0)
	add_child(shape)
	var y = 0.0
	while y < height - 1.0:   # a column of metal plates, with a warning stripe colour
		var plate = Sprite2D.new()
		plate.texture = DOOR_TILE
		var h = minf(18.0, height - y)
		plate.scale = Vector2(WIDTH / 18.0, h / 18.0)
		plate.position = Vector2(0, -y - h / 2.0)
		plate.modulate = colors[int(y / 18.0) % 2]
		add_child(plate)
		y += h
	for spot in levers:
		var lever = Sprite2D.new()
		lever.texture = LEVER_OFF
		lever.top_level = true
		lever.global_position = spot + Vector2(0, -9)
		add_child(lever)
		var zone = Area2D.new()
		zone.collision_layer = 0
		zone.collision_mask = 1
		var zone_shape = CollisionShape2D.new()
		zone_shape.shape = RectangleShape2D.new()
		zone_shape.shape.size = Vector2(24, 24)
		zone.add_child(zone_shape)
		zone.top_level = true
		zone.global_position = spot + Vector2(0, -12)
		add_child(zone)
		zone.body_entered.connect(_on_lever_touched.bind(lever))


func _on_lever_touched(body: Node2D, lever: Sprite2D) -> void:
	if lever.texture == LEVER_ON or body != level.player:
		return
	lever.texture = LEVER_ON
	flipped += 1
	Sfx.play("unlock")
	if flipped < levers.size():
		level._show_banner("SWITCH %d / %d" % [flipped, levers.size()])
		return
	level._show_banner("A DOOR OPENED SOMEWHERE")
	open()


func open() -> void:
	if is_open:
		return
	is_open = true
	Sfx.play("portal_open", 0.7)
	_move_to(closed_y - height, 1.2, true)


func close() -> void:
	if not is_open:
		return
	is_open = false
	Sfx.play("slam", 1.3)
	_move_to(closed_y, 0.4, false)


func _move_to(y: float, time: float, passable: bool) -> void:
	if slide:
		slide.kill()
	slide = create_tween()
	slide.tween_property(self, "position:y", y, time).set_trans(Tween.TRANS_SINE)
	for child in get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", passable)
