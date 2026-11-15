extends SceneTree

# Screenshots of the intro cutscene at a few moments (for checking it after changes).
# Run:  open -g -n -W -a Godot.app --args --path . --position 4000,4000 --resolution 1280x720 --script tools/shoot_intro.gd -- <output folder>

const MOMENTS = [3.0, 7.5, 11.0, 16.0, 21.0, 24.5, 28.0, 34.0, 38.0]

func _initialize() -> void:
	var out = OS.get_cmdline_user_args()[0]
	var intro = load("res://intro_cutscene.tscn").instantiate()
	root.add_child(intro)
	intro.set_process_unhandled_key_input(false)   # stray key presses must not skip it
	for moment in MOMENTS:
		while intro.t < moment:
			await process_frame
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png(out + "/intro_%04.1f.png" % moment)
	quit()
