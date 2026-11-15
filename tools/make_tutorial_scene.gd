extends SceneTree

# ONE-OFF TOOL (already run on 2026-11-15; kept so the team can see how it was made).
# Makes tutorial.tscn from level_1.tscn: keeps the player, sky, hills, mist, particles,
# HUD hints and the tile layers' settings, and removes all of Level 1's gameplay
# (ground, spikes, NPCs, lanterns, the Warden, the portal). tutorial_map.gd then
# builds the training course, and tutorial.gd runs it.
# Run:  godot --headless --path . --script tools/make_tutorial_scene.gd

func _initialize() -> void:
	if ResourceLoader.exists("res://tutorial.tscn"):
		print("tutorial.tscn already exists: nothing to do.")
		quit()
		return
	var level = load("res://level_1.tscn").instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	level.name = "Tutorial"
	level.set_script(load("res://tutorial.gd"))

	for path in ["Ground", "Ground2", "Spikes", "Platforms", "Warden", "ExitPortal", "ArrivalRift", "Expansion"]:
		if level.has_node(path):
			level.get_node(path).free()
	for path in ["Checkpoints", "Npcs"]:
		for child in level.get_node(path).get_children():
			child.free()
	# Keep one spike strip and one crystal light as the patterns the map copies, far out of the way
	for child in level.get_node("Hazards").get_children():
		if child.name != "SpikeGarden1":
			child.free()
	level.get_node("Hazards/SpikeGarden1").position = Vector2(-5000, 5000)
	for child in level.get_node("Decor").get_children():
		if child.name != "CrystalGlow":
			child.free()
	level.get_node("Decor/CrystalGlow").position = Vector2(-5000, 5000)
	for layer_name in ["DarkGroundArt", "FrostEdges", "Decor"]:
		level.get_node(layer_name).clear()

	level.get_node("Player").position = Vector2(120, 368)
	level.get_node("Hints").position = Vector2(0, 0)   # A / D, SPACE, ESC key hints near the start

	var map = Node2D.new()
	map.name = "Map"
	map.set_script(load("res://tutorial_map.gd"))
	level.add_child(map)
	map.owner = level

	var packed = PackedScene.new()
	packed.pack(level)
	print("save: ", ResourceSaver.save(packed, "res://tutorial.tscn"))
	quit()
