extends SceneTree
# Takes a screenshot of every Level 1 section (for checking the art).
# Run from the project folder:  godot --path . --script tools/shoot_level_1.gd -- /some/output/folder

const SHOTS = [
	["01_arrival", Vector2(260, 360)],
	["02_spike_garden", Vector2(1268, 360)],
	["03_thorn_rise", Vector2(1680, 360)],
	["04_hollow_spire", Vector2(2560, 270)],
	["05_jump_run", Vector2(3450, 100)],
	["06_breach_tunnel", Vector2(4640, 150)],
	["07_leap_of_faith", Vector2(5500, 150)],
	["08_arena", Vector2(6300, 360)],
	["09_portal", Vector2(6720, 360)],
	["10_bounce_pad", Vector2(1660, 360)],
	["11_warden_npc", Vector2(6120, 150)],
	["13_npc_talk", Vector2(1590, 360)],
	["12_warden_strike", Vector2(6400, 367)],
]


func _initialize() -> void:
	var out = OS.get_cmdline_user_args()[0]
	change_scene_to_file("res://level_1.tscn")
	for i in 5:
		await process_frame
	var level = current_scene
	for shot in SHOTS:
		if shot[0] == "08_arena":
			level.get_node("ExitPortal").open()
		level.player.global_position = shot[1]
		level.player.velocity = Vector2.ZERO
		for i in 30:
			await process_frame
		if shot[0] == "12_warden_strike":
			var warden = level.get_node("Warden")
			warden.health = 2  # angry, so two strikes come down
			warden._take_hit(level.player)
			level.player.global_position = Vector2(warden.global_position.x - 150, 367)
			level.player.velocity = Vector2.ZERO
			await create_timer(1.42).timeout  # flashing, then the red marks, orbs mid-drop
		if shot[0] == "13_npc_talk":
			var npc = level.get_node("Npcs/NpcSable")
			npc._next_line()
			npc._next_line()  # the second line is a long one
			await create_timer(0.2).timeout
		if shot[0] == "10_bounce_pad":
			level.pad_unlocked = true
			level._place_jump_pad()
			for i in 5:
				await process_frame
		_save(out, shot[0])

	# The Soul Strike special ability, frame by frame (fresh level)
	change_scene_to_file("res://level_1.tscn")
	await create_timer(0.3).timeout
	level = current_scene
	var warden = level.get_node("Warden")
	level.player.global_position = Vector2(warden.global_position.x - 140, 367)
	await create_timer(0.5).timeout
	warden.health = 3
	warden._take_hit(level.player)
	level.player.global_position = Vector2(warden.global_position.x - 140, 367)
	await create_timer(0.6).timeout
	for i in 8:
		_press_space()
	await create_timer(0.1).timeout
	_save(out, "14_special_popup")
	for i in 7:
		_press_space()
	for frame in [["15_special_charge", 0.65], ["16_special_bolt", 0.45], ["17_special_heart", 0.3], ["18_special_shatter", 0.3]]:
		await create_timer(frame[1]).timeout
		_save(out, frame[0])
	quit()


func _press_space() -> void:
	for down in [true, false]:
		var e = InputEventKey.new()
		e.physical_keycode = KEY_SPACE
		e.keycode = KEY_SPACE
		e.pressed = down
		Input.parse_input_event(e)


func _save(out: String, shot_name: String) -> void:
	RenderingServer.force_draw()  # the window may be hidden, so draw on purpose
	root.get_texture().get_image().save_png(out.path_join(shot_name + ".png"))
