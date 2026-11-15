extends SceneTree

# ONE-OFF TOOL (already run on 2026-11-15; kept so the team can see what changed).
# Makes room in level_1.tscn for the Level 1 expansion:
#   - the arrival (player start, rift, Mira, Dr. Oren, key hints, left wall) moves 3600 px left,
#     leaving x -3040 .. 0 free for the Forgotten Paths
#   - the Warden's arena (floor, wall, lantern, Warden, portal, its art) moves 896 px right,
#     leaving x 6140 .. 7036 free for Warden's Approach
#   - the sky, fog, particles and hills are stretched to cover the wider level
#   - an "Expansion" node (level_1_expansion.gd) is added; it builds the new areas
# Run:  godot --headless --path . --script tools/expand_level_1_layout.gd

const ARRIVAL_SHIFT = -3600.0
const ARENA_SHIFT = 896.0
const ARENA_FROM_X = 6140.0

func _initialize() -> void:
	var level = load("res://level_1.tscn").instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	if level.has_node("Expansion"):
		print("Already expanded: nothing to do.")
		quit()
		return

	for path in ["Player", "ArrivalRift", "Npcs/NpcMira", "Npcs/NpcOren", "Hints", "Platforms/LeftWall"]:
		level.get_node(path).position.x += ARRIVAL_SHIFT
	for path in ["Platforms/ArenaFloor", "Platforms/ArenaWall", "Checkpoints/CP4_Arena", "Warden", "ExitPortal"]:
		level.get_node(path).position.x += ARENA_SHIFT
	for prop in level.get_node("Decor").get_children():
		if prop.position.x < 560.0:
			prop.position.x += ARRIVAL_SHIFT
		elif prop.position.x >= ARENA_FROM_X:
			prop.position.x += ARENA_SHIFT

	# Tile art: the left wall's tiles go with it; the arena's tiles go with the arena
	for layer_name in ["DarkGroundArt", "FrostEdges", "Decor"]:
		var layer: TileMapLayer = level.get_node(layer_name)
		var moves = []
		for cell in layer.get_used_cells():
			var shift = 0
			if cell.x < 0:
				shift = int(ARRIVAL_SHIFT / 8)
			elif cell.x >= int(ARENA_FROM_X / 8) + 1:
				shift = int(ARENA_SHIFT / 8)
			if shift != 0:
				moves.append([cell, cell + Vector2i(shift, 0), layer.get_cell_source_id(cell), layer.get_cell_atlas_coords(cell)])
		for m in moves:
			layer.erase_cell(m[0])
		for m in moves:
			layer.set_cell(m[1], m[2], m[3])

	for path in ["Mood/Sky", "Mood/Fog", "Mood/Abyss"]:
		level.get_node(path).offset_left = -4800.0
		level.get_node(path).offset_right = 9400.0
	for path in ["Background/Fireflies", "Background/FallingFrost"]:
		var particles: CPUParticles2D = level.get_node(path)
		particles.position.x = 2350.0
		particles.emission_rect_extents.x = 6200.0
		particles.amount = int(particles.amount * 1.7)
	level.get_node("Background/FarHills").repeat_size = Vector2(768, 0)
	level.get_node("Background/FarHills").repeat_times = 3
	level.get_node("Background/NearHills").repeat_size = Vector2(1152, 0)
	level.get_node("Background/NearHills").repeat_times = 3

	var expansion = Node2D.new()
	expansion.name = "Expansion"
	expansion.set_script(load("res://level_1_expansion.gd"))
	level.add_child(expansion)
	expansion.owner = level

	var packed = PackedScene.new()
	packed.pack(level)
	print("save: ", ResourceSaver.save(packed, "res://level_1.tscn"))
	quit()
