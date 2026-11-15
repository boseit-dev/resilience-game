extends SceneTree

# Screenshots of Level 1 areas (for checking the art after changes).
# Run:  open -g -n -W -a Godot.app --args --path . --position 4000,4000 --resolution 1280x720 --script tools/shoot_regions.gd -- <output folder>

const SPOTS = {
	"01_arrival": Vector2(-3400, 360), "02_fork": Vector2(-2900, 360), "03_upper_ruins": Vector2(-2200, 190),
	"04_upper_chest": Vector2(-1600, 190), "05_sunken_hollow": Vector2(-2300, 500), "06_weeping_pit": Vector2(-2600, 500),
	"07_paths_end": Vector2(-600, 360), "08_thorn_ledge": Vector2(1640, 240), "09_spire": Vector2(3450, 110),
	"10_hideout": Vector2(3670, -30), "11_crystal_drop": Vector2(3290, 150), "12_breach": Vector2(4150, 150),
	"13_tunnel": Vector2(5200, 310), "14_approach": Vector2(6450, 150), "15_approach_end": Vector2(6850, 280),
	"16_arena": Vector2(7400, 360),
}

func _initialize() -> void:
	var out = OS.get_cmdline_user_args()[0]
	var level = load("res://level_1.tscn").instantiate()
	root.add_child(level)
	await process_frame
	var player = level.get_node("Player")
	for shot in SPOTS:
		while level.respawning:   # a death respawn would move the player away mid-shot
			await process_frame
		player.global_position = SPOTS[shot]
		player.velocity = Vector2.ZERO
		player.get_node("Camera2D").reset_smoothing()
		for i in 40:
			await process_frame
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png(out + "/" + shot + ".png")
	quit()
