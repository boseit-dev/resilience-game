extends Node2D

# RESILIENCE - LEVEL 1 EXPANSION
# Builds the newer parts of Level 1 when the level starts, from the tables below.
# To move something, change its numbers here. Every table is in world pixels
# (x grows to the right, y grows DOWN, the main ground top is y = 380).
#
#   Arrival Grounds   x -3600 .. -3040   (you appear at the rift)
#   Forgotten Paths   x -3040 .. 0       (Upper Ruins above, Sunken Hollow below)
#   Spike Garden, Thorn Rise, Hollow Spire, The Breach: the original level (x 0 .. 6140)
#   Warden's Approach x 6140 .. 7036
#   Warden's Hollow   x 7036 .. 7796     (the boss arena, moved right to make room)

const CHECKPOINT = preload("res://checkpoint.tscn")
const BARRIER = preload("res://wooden_barrier.gd")
const NPC = preload("res://npc.tscn")
const CHEST = preload("res://chest.tscn")
const ENEMY_SCENES = {
	"sword": preload("res://enemies/sword_fighter.tscn"),
	"archer": preload("res://enemies/archer.tscn"),
	"guardian": preload("res://enemies/guardian.tscn"),
}
const SIGN_COLOR = Color(0.84, 0.9, 1, 0.85)
const WARNING_COLOR = Color(1, 0.55, 0.5, 0.95)
const NIGHT = Color(0.62, 0.67, 0.86)   # the level's normal darkness colour

# SOLID GROUND: [left, top, right, bottom, style]. Each one gets a collider and tile art.
# Styles (see STYLES below): frost = blue ice, stone = grey ruins, moss = green cave,
# violet = purple Breach rock, ember = red Warden rock.
const BLOCKS = [
	# Arrival Grounds + start of the Forgotten Paths (solid down to the bottom)
	[-3600, 380, -2900, 600, "frost"],
	[-2900, 380, -2600, 420, "frost"],     # thin floor over the Weeping Pit
	# The crack at x -2600 .. -2540 drops you into the Sunken Hollow
	[-2540, 380, -1960, 420, "stone"],     # ruined bridge (Sword Fighter 1)
	# The gap at x -1960 .. -1780 also drops into the Hollow
	[-1780, 380, -1560, 420, "stone"],
	[-1560, 380, 0, 600, "frost"],         # joins the original ground at x 0 (Sword Fighter 2)
	# Upper Ruins: broken stairs up, then a high walkway
	[-3000, 335, -2940, 349, "stone"],
	[-2910, 290, -2850, 304, "stone"],
	[-2820, 245, -2760, 259, "stone"],
	[-2730, 210, -2400, 230, "stone"],
	[-2320, 210, -1900, 230, "stone"],
	[-1850, 210, -1500, 230, "stone"],     # treasure at the far end, then drop back to the path
	# Sunken Hollow: a lower cave under the bridge
	[-2900, 520, -1560, 600, "moss"],
	[-1950, 473, -1905, 485, "moss"],      # two steps to climb out through the gap
	[-1880, 426, -1840, 438, "moss"],
	# Thorn Rise: a high treasure ledge (only a bounce pad gets you up the first time)
	[1600, 258, 1660, 272, "moss"],        # place a pad well to the left of it, then run right
	# Hollow Spire: the hidden hideout and the Crystal Drop floor
	[3722, -20, 3800, -6, "frost"],        # hideout: double jump straight up at the right end of Jump Platform 2
	[3200, 430, 3380, 600, "frost"],       # Crystal Drop: spikes at the bottom of the shaft
	# The Breach: archer perch and the hidden tunnel under floor C
	[4225, 98, 4300, 112, "violet"],
	[4990, 330, 5380, 600, "violet"],      # tunnel floor (drop into the gap between B and C)
	[4960, 260, 4990, 600, "violet"],      # tunnel's back wall
	[5050, 296, 5085, 308, "violet"],      # step to climb back out (then double jump onto floor C)
	# Warden's Approach
	[6140, 170, 6560, 600, "ember"],       # Guardian
	[6220, -240, 6330, 124, "ember"],      # rock overhang: a wooden barrier blocks the way under it
	[6560, 250, 6800, 600, "ember"],       # final checkpoint, Guardian 2
	[6760, 150, 6830, 164, "ember"],       # archer perch above the drop
	[6800, 300, 7036, 600, "ember"],       # then drop into the Warden's arena
	[6860, -240, 6960, 254, "ember"],      # second overhang + barrier
]

# WOODEN BARRIERS: [x, floor top, height]. Dash (Shift) into them to smash them.
const BARRIERS = [
	[5240, 330, 70],    # Breach tunnel, in front of the chest
	[6275, 170, 46],    # Warden's Approach, under the first overhang
	[6910, 300, 46],    # Warden's Approach, under the second overhang
]

# The original level's tiles are restyled in these x ranges, so each area looks different
const RESTYLE = [
	[1600, 2600, "moss"],     # Thorn Rise: overgrown
	[4000, 6140, "violet"],   # The Breach: purple rock
	[7036, 7800, "ember"],    # Warden's Hollow: red rock
]

# Tile art for each style. The Deep-Night sheet has the same tile layout in blue
# (columns 13+) and green (columns 0+), so moss = the blue tile moved 13 columns left.
const STYLES = {
	"frost": {"shift": 0, "tint": Color.WHITE},
	"moss": {"shift": -13, "tint": Color.WHITE},
	"violet": {"shift": 0, "tint": Color(0.85, 0.66, 1.0)},
	"stone": {"stone": true, "tint": Color(0.82, 0.84, 0.9)},
	"ember": {"stone": true, "tint": Color(1.0, 0.62, 0.55)},
}

# PROPS: [kind, x, y]. y is the floor top (for "vine": the ceiling it hangs from).
const PROPS = [
	["grave", -2660, 210], ["grave", -2575, 210], ["grave", -2230, 210], ["grave", -2045, 210], ["grave", -1720, 210],
	["grave", -1000, 380], ["grave", -930, 380], ["fence", -620, 380], ["fence", -600, 380],
	["vine", -2480, 420], ["vine", -2390, 420], ["vine", -2270, 420], ["vine", -2140, 420], ["vine", -2030, 420],
	["mushroom", -2450, 520], ["mushroom", -2180, 520], ["mushroom", -1995, 520], ["mushroom", -1640, 520],
	["pumpkin", -2350, 520], ["pumpkin", -1700, 520], ["flower", -2420, 520], ["flower", -2100, 520], ["flower", -1900, 520],
	["flower", 1990, 290], ["flower", 2210, 290], ["flower", 1628, 258], ["mushroom", 2300, 290],
	["fence", 6400, 170], ["fence", 6416, 170], ["grave", 6500, 170], ["fence", 6640, 250], ["grave", 6720, 250],
	["fence", 6990, 300], ["fence", 7006, 300],
]
const SHEET = preload("res://assets/Deep-Night/Tiles-and-Enemies-transparent.png")
const PROP_ART = {
	"grave": Rect2(24, 88, 8, 8), "fence": Rect2(128, 64, 16, 8), "vine": Rect2(72, 64, 8, 32),
	"pumpkin": Rect2(32, 64, 8, 8), "flower": Rect2(88, 0, 8, 16),
}
const MUSHROOM = preload("res://assets/kenney_pixel-platformer/Tiles/tile_0128.png")

# SPIKES: [x, floor top]. Each strip is 64 px wide, like the Spike Garden ones.
const SPIKES = [
	[-2840, 520], [-2776, 520], [-2712, 520],   # the Weeping Pit
	[3256, 430], [3320, 430],                   # the Crystal Drop
]

# ENEMIES: [type, x, floor top, patrol distance]
const ENEMIES = [
	["sword", -2200, 380, 120],
	["sword", -1200, 380, 140],
	["sword", -2050, 520, 80],     # Sunken Hollow
	["sword", 2120, 290, 70],      # Thorn Rise, after Sable's lesson
	["archer", 3680, 130, 0],      # Hollow Spire: guards Jump Platform 2 (land on it!)
	["archer", 4262, 98, 0],       # The Breach pair: archer above...
	["sword", 4120, 170, 60],      # ...and a sword fighter below
	["guardian", 6430, 170, 80],   # The Breach exit, just past the first wooden barrier
	["guardian", 6690, 250, 50],   # Warden's Approach: the hard encounter
	["archer", 6795, 150, 0],
]

# CHESTS: [x, floor top]
const CHESTS = [
	[-1540, 210],   # Upper Ruins
	[-2300, 520],   # Sunken Hollow
	[1630, 258],    # Thorn Rise ledge
	[3765, -20],    # Spire Hideout
	[5340, 330],    # Breach tunnel
]

# CHECKPOINTS: [x, floor top]
const CHECKPOINTS = [
	[-1300, 380],   # middle of the Forgotten Paths
	[6600, 250],    # Warden's Approach (the final checkpoint before the Warden)
]

# NPCS: [name, Kenney character number, x, floor top]
const NPCS = [
	["PIP", 12, -3070, 380],
]

# SECRETS: [left, top, right, bottom, covered?]. Covered ones are hidden under darkness
# that fades away when you step inside. Either way "SECRET FOUND" shows the first time.
const SECRETS = [
	[3712, -60, 3810, -4, false],   # Spire Hideout (hidden just above the screen)
	[4960, 262, 5380, 334, true],   # Breach tunnel
]

# SIGNS: [x, y, text, is it a warning?]
const SIGNS = [
	[-3000, 396, "FORGOTTEN PATHS", false],
	[-2998, 337, "UP: OLD RUINS", false],
	[-2640, 396, "CRACK: THE HOLLOW", false],
	[-2896, 500, "THE WEEPING PIT  -  TURN BACK", true],
	[3254, 190, "!! CRYSTAL DROP - NO WAY BACK !!", true],
	[6150, 186, "WARDEN'S APPROACH", false],
]

# CRYSTALS: [x, y, colour]. Little glowing lights to make each area look different.
const CRYSTALS = [
	[-2700, 180, Color("#BFD8FF")], [-2100, 180, Color("#BFD8FF")], [-1650, 180, Color("#BFD8FF")],
	[-2500, 505, Color("#7CFFB0")], [-2150, 505, Color("#7CFFB0")], [-1700, 505, Color("#7CFFB0")],
	[3290, 415, Color("#FF7A9A")], [5200, 315, Color("#C08BFF")], [3750, -40, Color("#FFE08A")],
	[6400, 155, Color("#FF6A5A")], [6900, 285, Color("#FF6A5A")],
]

# REGIONS: [name, left, top, right, bottom, darkness colour]. The first match wins,
# so the small branch areas come before the big ones. An empty name shows no banner.
const REGIONS = [
	["UPPER RUINS", -3000, -200, -1500, 300, Color(0.74, 0.8, 0.98)],
	["SUNKEN HOLLOW", -2900, 430, -1560, 700, Color(0.5, 0.72, 0.62)],
	["", -3600, -400, -3040, 700, NIGHT],
	["FORGOTTEN PATHS", -3040, -400, 0, 700, Color(0.6, 0.66, 0.8)],
	["SPIKE GARDEN", 0, -400, 1600, 700, NIGHT],
	["THORN RISE", 1600, -400, 2600, 700, Color(0.7, 0.6, 0.84)],
	["HOLLOW SPIRE", 2600, -400, 4000, 700, Color(0.56, 0.66, 0.92)],
	["THE BREACH", 4000, -400, 6560, 700, Color(0.62, 0.52, 0.82)],
	["WARDEN'S APPROACH", 6560, -400, 7036, 700, Color(0.6, 0.48, 0.55)],
	["WARDEN'S HOLLOW", 7036, -400, 8000, 700, Color(0.56, 0.48, 0.52)],
]

var level: Node
var current_region = -1
var seen_regions = {}
var darkness_tween: Tween


func _ready() -> void:
	level = get_parent()
	for r in RESTYLE:
		_restyle(r[0], r[1], r[2])
	for b in BLOCKS:
		_add_block(b)
	for p in PROPS:
		_add_prop(p[0], p[1], p[2])
	for b in BARRIERS:
		var barrier = BARRIER.new()
		barrier.height = b[2]
		barrier.position = Vector2(b[0], b[1])
		add_child(barrier)
	for s in SPIKES:
		_add_spikes(s[0], s[1])
	for c in CRYSTALS:
		_add_crystal(c[0], c[1], c[2])
	for s in SECRETS:
		_add_secret(Rect2(s[0], s[1], s[2] - s[0], s[3] - s[1]), s[4])
	for s in SIGNS:
		_add_sign(s[0], s[1], s[2], s[3])
	for c in CHECKPOINTS:
		var checkpoint = CHECKPOINT.instantiate()
		checkpoint.position = Vector2(c[0], c[1] - 13)
		add_child(checkpoint)   # the level connects every checkpoint in its own _ready
	for c in CHESTS:
		var chest = CHEST.instantiate()
		chest.position = Vector2(c[0], c[1])
		add_child(chest)
	for e in ENEMIES:
		var enemy = ENEMY_SCENES[e[0]].instantiate()
		enemy.position = Vector2(e[1], e[2])   # set before add_child: it remembers its start
		enemy.patrol_distance = e[3]
		add_child(enemy)
	for n in NPCS:
		var npc = NPC.instantiate()
		npc.npc_name = n[0]
		npc.look = load("res://assets/kenney_pixel-platformer/Tiles/Characters/tile_%04d.png" % n[1])
		npc.position = Vector2(n[2], n[3])
		level.get_node("Npcs").add_child(npc)


func _process(_delta: float) -> void:
	var p = level.player.global_position
	for i in REGIONS.size():
		var r = REGIONS[i]
		if Rect2(r[1], r[2], r[3] - r[1], r[4] - r[2]).has_point(p):
			if i != current_region:
				_enter_region(i)
			return


# The night changes colour slowly, and each area's name appears the first time you arrive
func _enter_region(i: int) -> void:
	current_region = i
	var r = REGIONS[i]
	if darkness_tween:
		darkness_tween.kill()
	darkness_tween = create_tween()
	darkness_tween.tween_property(level.get_node("Mood/Darkness"), "color", r[5], 1.5)
	if r[0] != "" and not seen_regions.has(r[0]):
		seen_regions[r[0]] = true
		level._show_banner(r[0])


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
