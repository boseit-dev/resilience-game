extends "res://puzzles/puzzle.gd"

# RESILIENCE - PRESSURE PLATE PUZZLE
# Push the heavy stone blocks onto the plates. Only a block is heavy enough (not you).
# When EVERY plate has a block on it at the same time, the puzzle is solved.
# Pushed a block somewhere useless? Use the reset lever.
# data: plates [floor positions], stones [floor positions where each block starts]

const BLOCK = preload("res://puzzles/stone_block.gd")

var plates = []      # [area, art]
var stones = []


func _ready() -> void:
	super._ready()
	for at in data.plates:
		var plate = Area2D.new()
		plate.collision_layer = 0
		plate.collision_mask = 1
		var shape = CollisionShape2D.new()
		shape.shape = RectangleShape2D.new()
		shape.shape.size = Vector2(20, 6)
		plate.add_child(shape)
		plate.position = at + Vector2(0, -3)
		add_child(plate)
		var art = ColorRect.new()
		art.size = Vector2(28, 4)
		art.position = at + Vector2(-14, -4)
		add_child(art)
		plates.append([plate, art])
	for at in data.stones:
		var stone = BLOCK.new()
		stone.level = level
		stone.position = at + Vector2(0, -BLOCK.SIZE / 2.0)
		add_child(stone)
		stones.append(stone)


func reset() -> void:
	super.reset()
	for stone in stones:
		stone.reset()


func _physics_process(_delta: float) -> void:
	var pressed = 0
	for p in plates:
		var down = p[0].get_overlapping_bodies().any(func(b): return b.is_in_group("stone_block"))
		if down and p[1].color.g < 1.0:
			Sfx.play("armour_hit", 0.7)   # clunk
		p[1].color = Color(0.6, 1.8, 1.4) if down else Color(0.55, 0.45, 0.7)
		pressed += int(down)
	if pressed == plates.size() and not solved:
		solve()
