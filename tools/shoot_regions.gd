extends SceneTree

# Screenshots of Level 1 (or the tutorial, or Level 2) areas, for checking the art after changes.
# Run:  open -g -n -W -a Godot.app --args --path . --position 4000,4000 --resolution 1280x720 --script tools/shoot_regions.gd -- <output folder> [tutorial | level_2]

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

const LEVEL_2_SPOTS = {
	"l2_01_entrance": Vector2(140, 360), "l2_02_alcove": Vector2(220, 210), "l2_03_corridor": Vector2(1250, 360),
	"l2_04_chambers": Vector2(1900, 190), "l2_05_floor": Vector2(2450, 360), "l2_06_room": Vector2(2900, 500),
	"l2_07_high_route": Vector2(3100, 160), "l2_08_door": Vector2(3450, 360), "l2_09_archives": Vector2(4000, 360),
	"l2_10_cave": Vector2(4500, 480), "l2_11_dead_end": Vector2(4950, 210), "l2_12_core": Vector2(5600, 300),
	"l2_13_pillar": Vector2(6050, 280), "l2_14_ledge": Vector2(6420, 100), "l2_15_lockdown": Vector2(7400, 360),
	"l2_16_catwalk": Vector2(7650, 200), "l2_17_beams": Vector2(8300, 360), "l2_18_arena": Vector2(8900, 360),
}

func _initialize() -> void:
	var args = OS.get_cmdline_user_args()
	var out = args[0]
	var mode = args[1] if args.size() > 1 else ""
	var spots = {"tutorial": TUTORIAL_SPOTS, "level_2": LEVEL_2_SPOTS}.get(mode, SPOTS)
	var scene = {"tutorial": "res://tutorial.tscn", "level_2": "res://level_2.tscn"}.get(mode, "res://level_1.tscn")
	load("res://lab_intro.gd").seen = true   # no opening cutscene in screenshots
	var level = load(scene).instantiate()
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
