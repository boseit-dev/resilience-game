extends SceneTree
# Screenshots of the main menu pages (for checking the look).
# Run from the project folder:  godot --path . --script tools/shoot_menu.gd -- /some/output/folder

func _initialize() -> void:
	var out = OS.get_cmdline_user_args()[0]
	change_scene_to_file("res://main_menu.tscn")
	await create_timer(1.6).timeout  # fade-in
	_save(out, "menu_main")
	var menu = current_scene
	menu._show_page("options")
	await create_timer(0.3).timeout
	_save(out, "menu_options")
	menu._show_page("controls")
	await create_timer(0.3).timeout
	_save(out, "menu_controls")
	quit()


func _save(out: String, shot_name: String) -> void:
	RenderingServer.force_draw()  # the window may be hidden, so draw on purpose
	root.get_texture().get_image().save_png(out.path_join(shot_name + ".png"))
