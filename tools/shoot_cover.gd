extends SceneTree

# Gameplay shots of Level 3 for the cover image and thumbnail (tools/make_store_art.py adds the title).
# Run:  open -g -n -W -a Godot.app --args --path . --position 4000,4000 --resolution 1280x720 --script tools/shoot_cover.gd -- <output folder>

const SHOTS = {"cover_arena": Vector2(14000, 368), "cover_caverns": Vector2(1300, 368), "cover_trial": Vector2(11500, 368)}


func _initialize() -> void:
	var out = OS.get_cmdline_user_args()[0]
	for t in ["CHAPTER III", "CHAPTER III  —  THE FRACTURED CAVERNS"]:
		load("res://lab_intro.gd").seen[t] = true   # skip the chapter card
	var level = load("res://level_3.tscn").instantiate()
	root.add_child(level)
	await process_frame
	level.get_node("HUD").visible = false if level.has_node("HUD") else true
	var player = level.get_node("Player")
	for shot in SHOTS:
		player.global_position = SHOTS[shot]
		player.velocity = Vector2.ZERO
		player.get_node("Camera2D").reset_smoothing()
		for i in 50:
			await process_frame
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png(out + "/" + shot + ".png")
	quit()
