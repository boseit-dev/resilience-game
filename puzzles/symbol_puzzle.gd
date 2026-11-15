extends "res://puzzles/puzzle.gd"

# RESILIENCE - ANCIENT SYMBOL PUZZLE
# Four stones carry a symbol each. Press E on them in the right order to open the chamber.
# The order is hidden in carvings around the sanctuary: each carving shows one symbol with
# 1 to 4 dots under it (the dots = its place in the order). The Keeper's riddle says the same.
# A wrong stone: they all go dark, and a rock falls where you stand (step aside!).
# data: stones [[position, symbol], ...], order [symbol, ...], clues [[position, symbol, dots], ...]

const ROCKS = preload("res://rock_trap.gd")
const COLORS = {"MOON": Color(1.2, 1.3, 2.0), "FLAME": Color(2.0, 1.0, 0.5), "CRYSTAL": Color(0.7, 1.7, 2.0), "GATE": Color(1.7, 1.5, 0.8)}

var pressed = []      # symbols pressed so far, in order
var glyphs = {}       # symbol -> its glyph on the stone


func _ready() -> void:
	super._ready()
	for s in data.stones:
		var stone = ColorRect.new()   # a carved standing stone
		stone.color = Color(0.32, 0.3, 0.42)
		stone.size = Vector2(22, 30)
		stone.position = s[0] + Vector2(-11, -30)
		add_child(stone)
		glyphs[s[1]] = _glyph(s[1], s[0] + Vector2(0, -18), 1.0)
		add_spot(s[0] + Vector2(0, -12), press.bind(s[1]))
	for c in data.get("clues", []):
		_glyph(c[1], c[0], 1.4)
		for d in c[2]:   # the dots, centred under the carving
			var dot = ColorRect.new()
			dot.color = COLORS[c[1]]
			dot.size = Vector2(3, 3)
			dot.position = c[0] + Vector2((d - (c[2] - 1) / 2.0) * 6.0 - 1.5, 16)
			add_child(dot)
	_light()


# A symbol drawn as a glowing shape
func _glyph(symbol: String, at: Vector2, size: float) -> Polygon2D:
	var shape = Polygon2D.new()
	match symbol:
		"CRYSTAL": shape.polygon = PackedVector2Array([Vector2(0, -8), Vector2(5, 0), Vector2(0, 8), Vector2(-5, 0)])
		"FLAME": shape.polygon = PackedVector2Array([Vector2(0, -9), Vector2(4, -2), Vector2(5, 3), Vector2(0, 7), Vector2(-5, 3), Vector2(-4, -2)])
		"GATE": shape.polygon = PackedVector2Array([Vector2(-6, 7), Vector2(-6, -3), Vector2(-3, -7), Vector2(3, -7), Vector2(6, -3), Vector2(6, 7), Vector2(3, 7), Vector2(3, -2), Vector2(-3, -2), Vector2(-3, 7)])
		"MOON":   # a crescent: the outer circle's left side, back along a smaller circle
			var points = []
			for i in 13:
				points.append(Vector2.from_angle(deg_to_rad(90 + i * 15)) * 7)
			for i in 13:
				points.append(Vector2(3, 0) + Vector2.from_angle(deg_to_rad(270 - i * 15)) * 5)
			shape.polygon = PackedVector2Array(points)
	shape.color = COLORS[symbol]
	shape.position = at
	shape.scale = Vector2(size, size)
	add_child(shape)
	return shape


func press(symbol: String) -> void:
	if solved or pressed.has(symbol):
		return
	pressed.append(symbol)
	if data.order[pressed.size() - 1] != symbol:   # wrong: reset and a small, avoidable trap
		pressed.clear()
		Sfx.play("qte_fail", 0.7)
		level._show_banner("THE SYMBOLS GO DARK")
		ROCKS.drop(get_parent(), level.player.global_position.x, level.player.global_position.y + 12.0, 0.9, 1.0)
	else:
		Sfx.play("checkpoint", 0.8 + pressed.size() * 0.15)
		if pressed.size() == data.order.size():
			solve()
	_light()


func reset() -> void:
	super.reset()
	pressed.clear()
	_light()


func _light() -> void:   # pressed stones glow, the rest are dim
	for symbol in glyphs:
		glyphs[symbol].modulate = Color.WHITE if pressed.has(symbol) or solved else Color(0.35, 0.35, 0.45)
