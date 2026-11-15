extends SceneTree

# ONE-OFF TOOL: makes level_3.tscn from level_2.tscn's scenery (sky, hills, mist, particles,
# tile layer settings), then swaps in the Level 3 map, the Null Architect, the gateway portal
# and the cave opening. Everything you play is in level_3_map.gd, so edit that, not this.
# Run:  godot --headless --path . --script tools/make_level_3_scene.gd   (won't overwrite)

func _initialize() -> void:
	if ResourceLoader.exists("res://level_3.tscn"):
		print("level_3.tscn already exists: nothing to do.")
		quit()
		return
	var level = load("res://level_2.tscn").instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	level.name = "Level3"
	level.level_number = 3
	level.level_title = "CHAPTER III  —  THE FRACTURED CAVERNS"
	level.music = load("res://assets/music/level_3_theme.ogg")
	level.get_node("Map").set_script(load("res://level_3_map.gd"))
	level.get_node("Background").modulate = Color(0.55, 0.4, 0.85)   # deep purple caves
	level.get_node("Background/MoonLayer").hide()                     # underground: no moon or stars
	level.get_node("Background/FarStars").hide()
	level.get_node("Background/FallingFrost").modulate = Color(0.8, 0.7, 1.0, 0.7)   # falling dust
	level.get_node("Prototype").free()

	var boss = load("res://null_architect.tscn").instantiate()
	boss.position = Vector2(14250, 380)
	level.add_child(boss)
	boss.owner = level
	boss.touched_player.connect(level._on_boss_touched, CONNECT_PERSIST)
	var portal = level.get_node("ExitPortal")   # the restored gateway, opened when the escape starts
	portal.position = Vector2(18600, 380)
	portal.next_scene = "res://ending.tscn"
	portal.scale = Vector2(1.6, 1.6)

	var intro = level.get_node("Intro")
	intro.text = "THE SCIENTIST WAS HERE\nTHE CORE LIES BELOW\nTHE ARCHITECT WAKES\nNOBODY LEAVES"
	intro.title = "CHAPTER III  —  THE FRACTURED CAVERNS"
	intro.text_color = Color(1.4, 1.1, 2.0)
	level.move_child(intro, -1)

	var packed = PackedScene.new()
	packed.pack(level)
	print("save: ", ResourceSaver.save(packed, "res://level_3.tscn"))
	quit()
