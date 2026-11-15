extends SceneTree

# ONE-OFF TOOL: makes level_2.tscn from tutorial.tscn's scenery (sky, hills, mist, particles,
# tile layer settings), then adds the Level 2 map, the Failed Prototype, the exit portal and
# the opening. Everything you play is in level_2_map.gd, so edit that, not this.
# Run:  godot --headless --path . --script tools/make_level_2_scene.gd   (won't overwrite)

func _initialize() -> void:
	if ResourceLoader.exists("res://level_2.tscn"):
		print("level_2.tscn already exists: nothing to do.")
		quit()
		return
	var level = load("res://tutorial.tscn").instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	level.name = "Level2"
	level.set_script(load("res://level_1.gd"))
	level.level_number = 2
	level.level_title = "CHAPTER II  —  FORGOTTEN LABORATORIES"
	level.music = load("res://assets/music/level_2_theme.ogg")
	level.get_node("Hints").free()
	level.get_node("Map").set_script(load("res://level_2_map.gd"))
	level.get_node("Background").modulate = Color(0.6, 0.55, 1.0)   # dark blue and purple

	level.get_node("Player").position = Vector2(140, 368)   # camera limits are set in level_2_map.gd

	var boss = _add(level, load("res://prototype.tscn").instantiate(), Vector2(9250, 380))
	var portal = _add(level, load("res://portal.tscn").instantiate(), Vector2(9780, 380))
	portal.name = "ExitPortal"
	portal.next_scene = "res://level_3.tscn"
	boss.defeated.connect(portal.open, CONNECT_PERSIST)
	boss.touched_player.connect(level._on_spikes_body_entered, CONNECT_PERSIST)

	var intro = Node.new()
	intro.name = "Intro"
	intro.set_script(load("res://lab_intro.gd"))
	intro.terminal_position = Vector2(300, 380)
	_add(level, intro, null)

	var packed = PackedScene.new()
	packed.pack(level)
	print("save: ", ResourceSaver.save(packed, "res://level_2.tscn"))
	# Note: Godot also saves the portal's own body_entered connection again; delete that duplicate line.
	quit()


func _add(level: Node, node: Node, at) -> Node:
	if at != null:
		node.position = at
	level.add_child(node)
	node.owner = level
	return node
