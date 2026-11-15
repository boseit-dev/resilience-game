extends SceneTree
# Quick check that every main scene loads without errors (much faster than the full self-test).
# Run:  godot --headless --path . --script tools/smoke_test.gd
func _initialize() -> void:
	for scene in ["res://level_1.tscn", "res://level_2.tscn", "res://level_3.tscn", "res://tutorial.tscn", "res://main_menu.tscn", "res://intro_cutscene.tscn", "res://ending.tscn"]:
		change_scene_to_file(scene)
		for i in 30:
			await process_frame
		print("OK ", scene, " ", current_scene != null)
		if "banner" in current_scene:   # level titles must be centred across the whole screen
			var wide = current_scene.banner.size.x == current_scene.get_viewport().get_visible_rect().size.x
			print("OK" if wide else "FAIL", " banner spans the screen (", current_scene.banner.size.x, ")")
	quit()
