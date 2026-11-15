extends Node2D

# RESILIENCE - LEVEL BUILDER
# Shared by every level map script (level_1_expansion.gd, tutorial_map.gd, ...).
# A map script lists its ground, enemies, chests and so on in tables, then calls
#   build({"blocks": BLOCKS, "enemies": ENEMIES, ...})
# Keys it understands: blocks, barriers, restyle, props, spikes, enemies, chests,
# checkpoints, secrets, signs, crystals, regions, and for the lab levels:
#   movers  [x, top, width, travel x, travel y, seconds]       moving platforms (moving_platform.gd)
#   zappers [x, y, length, vertical?, on s, off s, delay, boss?]  timed electric beams (zapper.gd);
#           boss = true: stays off until the boss switches it on
#   doors   [x, floor top, height, [lever positions]]          a door that opens when every lever is touched
#   lamps   [x, y, colour]                                     flickering lab lights
#   npcs    [name, Kenney character number, x, floor top]      people (and terminals) you can talk to
#   regions can have a 7th item: the music for that area
# (all optional).
# The level scene must have DarkGroundArt, FrostEdges, Decor (with CrystalGlow),
# Hazards/SpikeGarden1 and Mood/Darkness: they are copied for the new parts.

const CHECKPOINT = preload("res://checkpoint.tscn")
const BARRIER = preload("res://wooden_barrier.gd")
const CHEST = preload("res://chest.tscn")
const MOVER = preload("res://moving_platform.gd")
const ZAPPER = preload("res://zapper.gd")
const DOOR = preload("res://lab_door.gd")
const NPC = preload("res://npc.tscn")
const ENEMY_SCENES = {
	"sword": preload("res://enemies/sword_fighter.tscn"),
	"archer": preload("res://enemies/archer.tscn"),
	"guardian": preload("res://enemies/guardian.tscn"),
}
const SIGN_COLOR = Color(0.84, 0.9, 1, 0.85)
const WARNING_COLOR = Color(1, 0.55, 0.5, 0.95)
const NIGHT = Color(0.62, 0.67, 0.86)   # the level's normal darkness colour

# Tile art for each style. The Deep-Night sheet has the same tile layout in blue
# (columns 13+) and green (columns 0+), so moss = the blue tile moved 13 columns left.
const STYLES = {
	"frost": {"shift": 0, "tint": Color.WHITE},
	"moss": {"shift": -13, "tint": Color.WHITE},
	"violet": {"shift": 0, "tint": Color(0.85, 0.66, 1.0)},
	"stone": {"stone": true, "tint": Color(0.82, 0.84, 0.9)},
	"ember": {"stone": true, "tint": Color(1.0, 0.62, 0.55)},
	"lab": {"stone": true, "tint": Color(0.58, 0.7, 0.95)},     # cold steel
}

const SHEET = preload("res://assets/Deep-Night/Tiles-and-Enemies-transparent.png")
const PROP_ART = {
	"grave": Rect2(24, 88, 8, 8), "fence": Rect2(128, 64, 16, 8), "vine": Rect2(72, 64, 8, 32),
	"pumpkin": Rect2(32, 64, 8, 8), "flower": Rect2(88, 0, 8, 16),
}
const MUSHROOM = preload("res://assets/kenney_pixel-platformer/Tiles/tile_0128.png")

var level: Node
var regions = []
var lamps: Array[PointLight2D] = []
var current_region = -1
var seen_regions = {}
var darkness_tween: Tween


func build(map: Dictionary) -> void:
	level = get_parent()
	regions = map.get("regions", [])
	for r in map.get("restyle", []):
		_restyle(r[0], r[1], r[2])
	for b in map.get("blocks", []):
		_add_block(b)
	for p in map.get("props", []):
		_add_prop(p[0], p[1], p[2])
	for b in map.get("barriers", []):
		var barrier = BARRIER.new()
		barrier.height = b[2]
		barrier.position = Vector2(b[0], b[1])
		add_child(barrier)
	for s in map.get("spikes", []):
		_add_spikes(s[0], s[1])
	for c in map.get("crystals", []):
		_add_crystal(c[0], c[1], c[2])
	for s in map.get("secrets", []):
		_add_secret(Rect2(s[0], s[1], s[2] - s[0], s[3] - s[1]), s[4])
	for s in map.get("signs", []):
		_add_sign(s[0], s[1], s[2], s[3])
	for c in map.get("checkpoints", []):
		var checkpoint = CHECKPOINT.instantiate()
		checkpoint.position = Vector2(c[0], c[1] - 13)
		add_child(checkpoint)   # the level connects every checkpoint in its own _ready
	for c in map.get("chests", []):
		var chest = CHEST.instantiate()
		chest.position = Vector2(c[0], c[1])
		add_child(chest)
	for e in map.get("enemies", []):
		var enemy = ENEMY_SCENES[e[0]].instantiate()
		enemy.position = Vector2(e[1], e[2])   # set before add_child: it remembers its start
		enemy.patrol_distance = e[3]
		if e.size() > 4:   # a tougher lab version: more stomps, walks faster
			enemy.health = e[4]
			enemy.walk_speed *= 1.4
			enemy.modulate = Color(1.15, 0.85, 0.85)
		add_child(enemy)
	for m in map.get("movers", []):
		var mover = MOVER.new()
		mover.position = Vector2(m[0], m[1])
		mover.width = m[2]
		mover.travel = Vector2(m[3], m[4])
		mover.time = m[5]
		add_child(mover)
	for z in map.get("zappers", []):
		var zapper = ZAPPER.new()
		zapper.position = Vector2(z[0], z[1])
		zapper.length = z[2]
		zapper.vertical = z[3]
		zapper.on_time = z[4]
		zapper.off_time = z[5]
		zapper.offset = z[6]
		zapper.active = z.size() < 8 or not z[7]
		if not zapper.active:
			zapper.add_to_group("boss_zapper")
		zapper.level = level
		add_child(zapper)
	for d in map.get("doors", []):
		var door = DOOR.new()
		door.position = Vector2(d[0], d[1])
		door.height = d[2]
		door.levers = d[3]
		door.level = level
		add_child(door)
	for l in map.get("lamps", []):
		_add_crystal(l[0], l[1], l[2])
		lamps.append(get_child(get_child_count() - 2))   # the light just added (before its sparks)
		lamps[-1].set_meta("energy", lamps[-1].energy)
	for n in map.get("npcs", []):
		var npc = NPC.instantiate()
		npc.npc_name = n[0]
		npc.look = load("res://assets/kenney_pixel-platformer/Tiles/Characters/tile_%04d.png" % n[1]) if n[1] is int else load(n[1])
		npc.position = Vector2(n[2], n[3])
		add_child(npc)


func _process(_delta: float) -> void:
	if level == null:
		return
	for lamp in lamps:   # broken lab lights: mostly on, now and then they stutter
		lamp.energy = 0.15 if randf() < 0.04 else lamp.get_meta("energy")
	var p = level.player.global_position
	for i in regions.size():
		var r = regions[i]
		if Rect2(r[1], r[2], r[3] - r[1], r[4] - r[2]).has_point(p):
			if i != current_region:
				_enter_region(i)
			return


# The night changes colour slowly, and each area's name appears the first time you arrive
func _enter_region(i: int) -> void:
	current_region = i
	var r = regions[i]
	if darkness_tween:
		darkness_tween.kill()
	darkness_tween = create_tween()
	darkness_tween.tween_property(level.get_node("Mood/Darkness"), "color", r[5], 1.5)
	if r[0] != "" and not seen_regions.has(r[0]):
		seen_regions[r[0]] = true
		level._show_banner(r[0])
	if r.size() > 6 and not get_tree().get_nodes_in_group("boss").any(func(b): return b.awake):
		Sfx.play_music(r[6])


# A solid box with Deep-Night tiles painted on it, in the block's style
func _add_block(b: Array) -> void:
	var rect = Rect2(b[0], b[1], b[2] - b[0], b[3] - b[1])
	var body = StaticBody2D.new()
	var shape = CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = rect.size
	body.position = rect.get_center()
	body.add_child(shape)
	add_child(body)
	var style = STYLES[b[4]]
	var layers = _layers_for(b[4])
	var left = int(floor(rect.position.x / 8.0))
	var right = int(ceil(rect.end.x / 8.0)) - 1
	var top = int(floor(rect.position.y / 8.0))
	var bottom = mini(int(ceil(rect.end.y / 8.0)) - 1, top + 60)   # deeper than this is darkness anyway
	var wide = right - left > 30
	for x in range(left, right + 1):
		var edge = Vector2i(15 + posmod(x, 3), 2)
		if wide:
			edge = Vector2i(17, 7)
		elif x == left:
			edge = Vector2i(14, 2)
		elif x == right:
			edge = Vector2i(18, 2)
		if style.has("stone"):
			for y in range(top, bottom + 1):
				layers[0].set_cell(Vector2i(x, y), 1, Vector2i(1 + posmod(x, 3), 16))
			layers[1].set_cell(Vector2i(x, top), 0, Vector2i(1 + posmod(x, 3), 15))
			continue
		for y in range(top, bottom + 1):
			layers[0].set_cell(Vector2i(x, y), 1, Vector2i(13 + posmod(x, 3) + style.shift, 9))
		layers[1].set_cell(Vector2i(x, top), 0, edge + Vector2i(style.shift, 0))
		# grass tufts on some tiles (the same pattern every time, so screenshots match)
		var pick = posmod(x * 7 + top * 3, 11)
		if pick < 4 and x > left and x < right:
			layers[2].set_cell(Vector2i(x, top - 1), 0, Vector2i(20 + pick + style.shift, 1))
		elif pick == 4 and x > left and x < right:
			layers[2].set_cell(Vector2i(x, top - 1), 0, Vector2i(23 + style.shift, 12))


# Ground, edge and decor tile layers for a style. Frost uses the level's own layers;
# the others are copies placed just after them, with their own colour.
var style_layers = {}

func _layers_for(style_name: String) -> Array:
	var names = ["DarkGroundArt", "FrostEdges", "Decor"]
	if style_name == "frost":
		return names.map(func(n): return level.get_node(n))
	if not style_layers.has(style_name):
		var made = []
		for n in names:
			var original: TileMapLayer = level.get_node(n)
			var copy = TileMapLayer.new()
			copy.name = n + "_" + style_name
			copy.tile_set = original.tile_set
			copy.modulate = STYLES[style_name].tint
			made.append(copy)
			# the level is still starting up, so add the copy (after the originals) a moment later
			level.add_child.call_deferred(copy)
			level.move_child.call_deferred(copy, level.get_node("Decor").get_index() + 1)
		style_layers[style_name] = made
	return style_layers[style_name]


# Move the original level's tiles in an x range into another style
func _restyle(from_x: float, to_x: float, style_name: String) -> void:
	var style = STYLES[style_name]
	var layers = _layers_for(style_name)
	var names = ["DarkGroundArt", "FrostEdges", "Decor"]
	for i in names.size():
		var original: TileMapLayer = level.get_node(names[i])
		for cell in original.get_used_cells():
			if cell.x * 8 < from_x or cell.x * 8 >= to_x:
				continue
			var atlas = original.get_cell_atlas_coords(cell)
			if style.get("shift", 0) != 0 and atlas.x >= 13:
				atlas.x += style.shift
			layers[i].set_cell(cell, original.get_cell_source_id(cell), atlas)
			original.erase_cell(cell)


func _add_prop(kind: String, x: float, y: float) -> void:
	var prop = Sprite2D.new()
	if kind == "mushroom":
		prop.texture = MUSHROOM
		prop.scale = Vector2(0.6, 0.6)
		prop.position = Vector2(x, y - 5)
	else:
		var art = AtlasTexture.new()
		art.atlas = SHEET
		art.region = PROP_ART[kind]
		prop.texture = art
		# props stand on the floor; vines hang down from the ceiling
		prop.position = Vector2(x, y + art.region.size.y / 2.0 if kind == "vine" else y - art.region.size.y / 2.0)
	add_child(prop)


# A copy of the first Spike Garden strip, so it looks and hurts the same
func _add_spikes(x: float, floor_top: float) -> void:
	var spikes: Area2D = level.get_node("Hazards/SpikeGarden1").duplicate(0)
	spikes.position = Vector2(x, floor_top - 10)
	add_child(spikes)
	spikes.body_entered.connect(level._on_spikes_body_entered)


func _add_crystal(x: float, y: float, color: Color) -> void:
	var glow: PointLight2D = level.get_node("Decor/CrystalGlow").duplicate()
	glow.position = Vector2(x, y)
	glow.color = color
	add_child(glow)
	var spark = CPUParticles2D.new()
	spark.position = Vector2(x, y)
	spark.amount = 6
	spark.lifetime = 2.0
	spark.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	spark.emission_rect_extents = Vector2(10, 4)
	spark.direction = Vector2(0, -1)
	spark.gravity = Vector2(0, -6)
	spark.initial_velocity_min = 2.0
	spark.initial_velocity_max = 8.0
	spark.color = color
	add_child(spark)


# Hidden room: drawn over with darkness until you walk in
func _add_secret(rect: Rect2, covered: bool) -> void:
	var cover = ColorRect.new()
	cover.visible = covered
	cover.position = rect.position
	cover.size = rect.size
	cover.color = Color("#07060C")
	cover.z_index = 4   # in front of the player, chests and enemies
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cover)
	var zone = Area2D.new()
	zone.collision_mask = 1   # the player's layer
	zone.collision_layer = 0
	var shape = CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = rect.size
	zone.position = rect.get_center()
	zone.add_child(shape)
	add_child(zone)
	zone.body_entered.connect(_on_secret_entered.bind(cover))


func _on_secret_entered(body: Node2D, cover: ColorRect) -> void:
	if body != level.player or cover.modulate.a < 1.0:
		return
	Sfx.play("secret")
	level._show_banner("SECRET FOUND")
	create_tween().tween_property(cover, "modulate:a", 0.0, 0.6)


func _add_sign(x: float, y: float, text: String, warning: bool) -> void:
	var label = Label.new()
	label.text = text
	label.position = Vector2(x, y)
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", WARNING_COLOR if warning else SIGN_COLOR)
	label.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.05, 1))
	label.add_theme_constant_override("outline_size", 3)
	add_child(label)
