extends SceneTree

# Screenshots of Level 1 (or the tutorial) areas, for checking the art after changes.
# Run:  open -g -n -W -a Godot.app --args --path . --position 4000,4000 --resolution 1280x720 --script tools/shoot_regions.gd -- <output folder> [tutorial]

const SPOTS = {
	"01_arrival": Vector2(-3400, 360), "02_fork": Vector2(-2900, 360), "03_upper_ruins": Vector2(-2200, 190),
	"04_upper_chest": Vector2(-1600, 190), "05_sunken_hollow": Vector2(-2300, 500), "06_weeping_pit": Vector2(-2600, 500),
	"07_paths_end": Vector2(-600, 360), "08_thorn_ledge": Vector2(1640, 240), "09_spire": Vector2(3450, 110),
	"10_hideout": Vector2(3670, -30), "11_crystal_drop": Vector2(3290, 150), "12_breach": Vector2(4150, 150),
	"13_tunnel": Vector2(5200, 310), "14_approach": Vector2(6450, 150), "15_approach_end": Vector2(6850, 280),
	"16_arena": Vector2(7400, 360),
}

const TUTORIAL_SPOTS = {
	"t0_start": Vector2(-20, 360), "t1_moving": Vector2(300, 360), "t2_jumping": Vector2(1000, 360), "t3_pads": Vector2(1850, 360),
	"t4_double_jump": Vector2(3050, 220), "t5_dash": Vector2(4100, 360), "t6_combat": Vector2(4850, 360),
	"t7_checkpoints": Vector2(5800, 360), "t8_final": Vector2(6500, 360), "t8_wall": Vector2(7000, 170),
	"t8_end": Vector2(7450, 360), "t9_finish": Vector2(7650, 360),
}

func _initialize() -> void:
	var args = OS.get_cmdline_user_args()
	var out = args[0]
	var tutorial = args.size() > 1 and args[1] == "tutorial"
	var spots = TUTORIAL_SPOTS if tutorial else SPOTS
	var level = load("res://tutorial.tscn" if tutorial else "res://level_1.tscn").instantiate()
	root.add_child(level)
	await process_frame
	var player = level.get_node("Player")
	for shot in spots:
		while level.respawning:   # a death respawn would move the player away mid-shot
			await process_frame
		player.global_position = spots[shot]
		player.velocity = Vector2.ZERO
		player.get_node("Camera2D").reset_smoothing()
		for i in 40:
			await process_frame
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png(out + "/" + shot + ".png")
	quit()
