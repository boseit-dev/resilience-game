extends SceneTree
# RESILIENCE - LEVEL 1 SELF-TEST
# A robot plays each challenge and checks it works the way the design says
# (for example: a plain jump can't cross Thorn Rise, the Bounce Pad can).
# Run from the project folder:
#   godot --headless --path . --script tools/selftest_level_1.gd
# Prints PASS/FAIL for each check. Exit code 1 if anything fails.

var level: Node
var held := {}
var failures := 0


func _initialize() -> void:
	await _test_sounds()
	await _test_spike_garden()
	await _test_thorn_rise()
	await _test_hollow_spire()
	await _test_jump_run()
	await _test_late_jumps()
	await _test_breach()
	await _test_leap()
	await _test_checkpoint_and_pads()
	await _test_warden_and_portal()
	await _test_special()
	await _test_npcs()
	await _test_pause()
	await _test_lessons()
	await _test_menu()
	await _test_quit_egg()
	print("\n", "ALL PASSED" if failures == 0 else "%d FAILED" % failures)
	if failures > 0:
		quit(1)
		return
	await _test_leave_quits()  # last: if Leave works, the game (and this test) closes with exit code 0


# ---------- the checks ----------

func _test_sounds() -> void:
	await _fresh(Vector2(220, 368))
	var sfx = root.get_node("Sfx")
	var all_loaded = true
	for sound_name in sfx.SOUNDS:
		all_loaded = all_loaded and sfx.SOUNDS[sound_name] != null
	_check("All %d sound effects load" % sfx.SOUNDS.size(), all_loaded)
	_check("Ambient hum is playing", sfx.ambience.playing)
	_check("Background music is playing (looped)", sfx.music.playing and sfx.music.stream.loop)


func _test_spike_garden() -> void:
	await _fresh(Vector2(1030, 368))
	await _leap(1110, -1, false, "")
	_check("Spike Garden: one long jump over both strips fails", level.deaths == 1)

	await _fresh(Vector2(1030, 368))
	await _leap(1100, 1268, false, "")
	_check("Spike Garden: a short hop lands in the safe gap", _landed_on(1243, 1293, 380) and level.deaths == 0)
	await _leap(1250, -1, false, "")  # jump straight from where it landed
	_check("Spike Garden: from the gap you can clear the second strip", _landed_on(1433, 1600, 380) and level.deaths == 0)


func _test_thorn_rise() -> void:
	await _fresh(Vector2(1640, 367))
	await _leap(1700, -1, false, "")
	_check("Thorn Rise: a plain jump fails (death 1)", level.deaths == 1)
	_check("Death 1 unlocks the Bounce Pad", level.pad_unlocked)

	await _fresh(Vector2(1676, 367))
	level.pad_unlocked = true
	await _tap(KEY_E)
	_check("E places a pad (2 left)", level.pads_remaining == 2)
	await _walk_until(1990, 150)
	_check("Thorn Rise: the Bounce Pad gets you onto the ledge", _landed_on(1925, 2500, 300))


func _test_hollow_spire() -> void:
	await _fresh(Vector2(2440, 277))
	level.pad_unlocked = true
	await _leap(2500, -1, false, "")
	_check("Hollow Spire: a single jump fails", level.deaths == 1)

	await _fresh(Vector2(2440, 277))
	level.player.double_jump_unlocked = true
	await _leap(2500, 2860, true, "")
	_check("Hollow Spire: double jump reaches the top", _landed_on(2785, 2950, 180))


func _test_jump_run() -> void:
	await _fresh(Vector2(2900, 157))
	await _leap(2950, 3290, false, "")
	_check("Jump run: gaps need the double jump", level.deaths == 1)

	await _fresh(Vector2(2900, 157))
	level.player.double_jump_unlocked = true
	await _leap(2950, 3290, true, "")
	await _leap(3330, 3670, true, "")
	await _leap(3710, 4100, true, "")
	_check("Jump run: all three gaps with double jump", _landed_on(4010, 4600, 180))


func _test_late_jumps() -> void:
	# Bug report: jumping a moment after running off a ledge used up the double jump
	await _fresh(Vector2(2900, 157))
	level.player.double_jump_unlocked = true
	await _run_off_ledge(2)
	await _tap(KEY_SPACE)
	await _frames(8)
	await _tap(KEY_SPACE)
	_check("A jump just after leaving a ledge still leaves the double jump", level.player.velocity.y < -300)
	_key(KEY_RIGHT, false)

	# The extra forgiveness must not make the 300 px gaps possible without double jump
	await _fresh(Vector2(2900, 157))
	await _run_off_ledge(int(level.player.COYOTE_TIME * 60.0) - 1)
	await _tap(KEY_SPACE)
	await _frames(150)
	_check("Even the latest allowed jump can't cross a jump-run gap alone", level.deaths == 1)

	await _fresh(Vector2(5500, 157))
	level.player.double_jump_unlocked = true
	await _run_off_ledge(int(level.player.COYOTE_TIME * 60.0) - 1)
	await _tap(KEY_SPACE)
	for t in 120:
		await physics_frame
		if level.player.velocity.y >= 0.0:
			await _tap(KEY_SPACE)
			break
	await _frames(150)
	_check("Even the latest jump + double jump can't clear the Leap without dash", level.deaths == 1)


func _run_off_ledge(frames_late: int) -> void:
	_key(KEY_RIGHT, true)
	while level.player.is_on_floor():
		await physics_frame
	await _frames(frames_late)


func _test_breach() -> void:
	await _fresh(Vector2(4450, 157))
	level.player.double_jump_unlocked = true
	await _leap(4600, -1, true, "")
	_check("Tunnel: jumping hits the ceiling and fails", level.deaths == 1)

	await _fresh(Vector2(4450, 157))
	level.player.double_jump_unlocked = true
	level.player.dash_unlocked = true
	await _leap(4600, -1, false, "edge")
	await _leap(5000, -1, false, "edge")
	await _leap(5300, -1, false, "edge")
	_check("Tunnel: dash crosses all three gaps", _landed_on(5400, 5560, 180))


func _test_leap() -> void:
	await _fresh(Vector2(5500, 157))
	level.player.double_jump_unlocked = true
	await _leap(5560, -1, true, "")
	_check("Leap of Faith: double jump alone falls short", level.deaths == 1)

	await _fresh(Vector2(5500, 157))
	level.player.double_jump_unlocked = true
	level.player.dash_unlocked = true
	await _leap(5560, 6090, true, "apex2")
	_check("Leap of Faith: jump, jump, dash makes it", level.deaths == 0 and _landed_on(6040, 6900, 400))


func _test_checkpoint_and_pads() -> void:
	await _fresh(Vector2(300, 368))
	level.pad_unlocked = true
	await _tap(KEY_E)
	var pad = level.placed_pads[0]
	level.player.global_position = Vector2(2440, 277)
	await _frames(10)
	var cp = level.get_node("Checkpoints/CP2_HollowSpire")
	_check("Touching a lantern lights it", cp.get_node("Glow").enabled)
	level._lose_life()
	await _frames(5)
	_check("Respawn happens at the last lantern", level.player.global_position.distance_to(cp.global_position) < 30)
	_check("Placed pads survive death", is_instance_valid(pad) and level.pads_remaining == 2)

	# A wall right in front of you: E must not put a pad inside it (or use one up)
	await _fresh(Vector2(300, 368))
	level.pad_unlocked = true
	var wall = StaticBody2D.new()
	var wall_shape = CollisionShape2D.new()
	wall_shape.shape = RectangleShape2D.new()
	wall_shape.shape.size = Vector2(40, 200)
	wall.add_child(wall_shape)
	wall.collision_layer = level.player.collision_mask
	level.add_child(wall)
	wall.global_position = Vector2(level.player.global_position.x + 50, 300)
	level.player.facing_direction = 1
	await _frames(3)
	await _tap(KEY_E)
	_check("No pad is placed inside a wall (and none is used up)", level.placed_pads.is_empty() and level.pads_remaining == 3)
	wall.queue_free()

	# R once only asks; a second R within 2 s restarts
	var before = level
	await _tap(KEY_R)
	await _frames(10)
	_check("R once only asks 'PRESS R AGAIN TO RESTART'", current_scene == before and level.banner.text == "PRESS R AGAIN TO RESTART")
	await _tap(KEY_R)
	while current_scene == before or current_scene == null:
		await process_frame
	_check("R twice restarts the level", current_scene != before)

	# Game over: a message shows for a moment before the level restarts
	await _fresh(Vector2(300, 368))
	before = level
	level.lives = 1
	level._lose_life()
	await _frames(10)
	_check("Game over shows 'THE BETWEEN CLAIMS YOU' before restarting", current_scene == before and level.banner.text == "THE BETWEEN CLAIMS YOU")
	while current_scene == before or current_scene == null:
		await process_frame
	_check("Game over then restarts the level with 5 lives", current_scene.lives == 5)
	level = current_scene


func _test_warden_and_portal() -> void:
	await _fresh(Vector2(6200, 367))
	var warden = level.get_node("Warden")
	level.player.global_position = Vector2(warden.global_position.x - 70, 367)
	await _frames(120)
	_check("Warden: touching its side costs a life", level.deaths == 1)

	# Charge: it flashes red, then rushes at you. Standing still costs a life...
	await _fresh(Vector2(6200, 367))
	warden = level.get_node("Warden")
	level.player.global_position = Vector2(warden.global_position.x - 150, 367)
	warden.charge_timer = 0.01
	await _frames(100)
	_check("Warden: its charge hits you if you stand still", level.deaths == 1)

	# ...jumping over it as it arrives is safe
	await _fresh(Vector2(6200, 367))
	warden = level.get_node("Warden")
	level.player.global_position = Vector2(warden.global_position.x - 150, 367)
	await _frames(5)
	warden.charge_timer = 0.01
	var jumped = false
	for i in 150:
		await physics_frame
		if warden.charging and not jumped and abs(warden.global_position.x - level.player.global_position.x) < 90:
			await _tap(KEY_SPACE)
			jumped = true
	_check("Warden: jumping over its charge is safe", jumped and level.deaths == 0)

	# A stomp seals your jump for 5 s while strikes come down
	await _stomp_once()
	_check("Warden: after a stomp it leaps away, so you can't keep bouncing on it", abs(warden_now().global_position.x - 6560) > 150)
	await _frames(30)
	_check("Warden: standing where it was doesn't stomp it again", warden_now().health == 4)
	_check("Warden: a stomp seals your jump for 5 s", warden_now().health == 4 and level.player.jump_locked_timer > 4.0)
	level.player.global_position = Vector2(warden_now().global_position.x - 150, 367)
	await _frames(10)
	await _tap(KEY_SPACE)
	await _frames(3)
	_check("Warden: you can't jump while sealed", level.player.is_on_floor())
	await _frames(90)  # stand still (not too long: losing all your lives restarts the level)
	_check("Warden: its strikes hit you if you stand still", level.deaths >= 1)

	# Dodge: stand on one of two spots and move to the other whenever a red mark appears under you
	await _stomp_once()
	var wx = warden_now().global_position.x
	var side = 1 if wx < 6560 else -1  # it leapt to one end of the arena: dodge on the open side
	var spots = [wx + side * 280, wx + side * 160]
	var target = 0
	level.player.global_position = Vector2(spots[0], 367)
	var strikes_seen = {}
	for i in 330:
		await physics_frame
		for strike in get_nodes_in_group("warden_strike"):
			strikes_seen[strike] = true
			if not strike.monitoring and abs(strike.global_position.x - spots[target]) < 30:
				target = 1 - target
		var px = level.player.global_position.x
		_key(KEY_RIGHT, spots[target] - px > 4)
		_key(KEY_LEFT, px - spots[target] > 4)
	_release_all()
	_check("Warden: walking away from the red marks dodges every strike (%d strikes)" % strikes_seen.size(), strikes_seen.size() >= 4 and level.deaths == 0)
	_check("Boss music plays in the arena", root.get_node("Sfx").music.stream.resource_path.ends_with("boss_theme.ogg"))

	# Five stomps beat it (it is held still and not charging, so the robot only tests stomping)
	await _fresh(Vector2(6200, 367))
	warden = level.get_node("Warden")
	var portal = level.get_node("ExitPortal")
	_check("Warden has 5 hearts", warden.health == 5 and warden.get_node("Hearts").get_child_count() == 5)
	while is_instance_valid(warden) and warden.health > 0:
		while warden.safe_timer > 0.0 or paused:  # paused = the Soul Strike challenge (left to time out)
			await physics_frame
		warden.speed = 0.0
		warden.charge_timer = 99.0
		var health_before = warden.health
		level.player.global_position = warden.global_position + Vector2(0, -70)
		level.player.velocity = Vector2.ZERO
		for i in 60:
			await physics_frame
			if warden.health < health_before:
				warden.attack_timer = 0.0  # skip the strike attack (tested above)
				break
		if warden.health == health_before:
			break  # missed, don't loop forever
	await _frames(150)  # fade-out before it disappears
	_check("Warden: five stomps beat it without getting hurt", not is_instance_valid(warden) and level.deaths == 0)
	if is_instance_valid(warden):
		print("      warden health ", warden.health, " alpha ", warden.get_node("Art").modulate.a)
	_check("Beating the Warden opens the portal", portal.is_open)
	level.player.global_position = portal.global_position + Vector2(0, -13)
	await _frames(10)
	_check("Portal shows 'Tutorial Complete' while level_2.tscn doesn't exist", portal.get_node("Message").visible)
	await _frames(150)
	_check("Level music returns after the Warden dies", root.get_node("Sfx").music.stream.resource_path.ends_with("level_1_theme.ogg"))


# Soul Strike: after the 3rd stomp the game pauses and asks for 20 SPACE presses in 3 s
func _special_setup() -> Node:
	await _fresh(Vector2(6200, 367))
	var warden = warden_now()
	warden.speed = 0.0
	warden.charge_timer = 99.0
	warden.health = 3  # two stomps already taken; the next one is the 3rd
	warden._update_hearts()
	level.player.global_position = warden.global_position + Vector2(0, -70)
	level.player.velocity = Vector2.ZERO
	for i in 90:
		await physics_frame
		if paused:
			break
	var special = level.get_node_or_null("SoulStrike")
	if special:
		while not special.active:
			await physics_frame
	return special


func _wait_unpaused() -> void:
	for i in 600:
		if not paused:
			break
		await physics_frame
	await _frames(5)


func _test_special() -> void:
	var special = await _special_setup()
	_check("Soul Strike: taking its 3rd heart pauses the game and shows the challenge", paused and special != null)
	for i in 21:
		await _tap(KEY_SPACE)
	await _wait_unpaused()
	_check("Soul Strike: 20 presses in 3 s rips off another heart (2 -> 1)", warden_now().health == 1 and level.deaths == 0)
	_check("Soul Strike: the game unpauses and the pop-up is gone", not paused and not level.has_node("SoulStrike"))

	await _special_setup()
	for i in 15:
		await _tap(KEY_SPACE)
	await _wait_unpaused()
	_check("Soul Strike: only 15 presses does nothing (still 2 hearts)", warden_now().health == 2 and not paused)


func _test_npcs() -> void:
	await _fresh(Vector2(1580, 367))
	level.pad_unlocked = true
	var npc = level.get_node("Npcs/NpcSable")
	_check("NPC: '!' shows before you talk, prompt shows when close", npc.get_node("Alert").visible and npc.get_node("Prompt").visible)
	await _tap(KEY_E)
	_check("NPC: E next to an NPC shows its first line (and places no pad)",
		npc.get_node("Bubble").visible and npc.line_index == 0 and level.pads_remaining == 3)
	for i in npc.lines.size() - 1:
		await _tap(KEY_E)
	_check("NPC: E goes through every line", npc.line_index == npc.lines.size() - 1)
	await _tap(KEY_E)
	_check("NPC: E after the last line closes the bubble", not npc.get_node("Bubble").visible and not npc.get_node("Alert").visible)
	await _tap(KEY_E)
	level.player.global_position = Vector2(1500, 367)
	await _frames(5)
	_check("NPC: walking away closes the bubble", not npc.get_node("Bubble").visible and level.pads_remaining == 3)
	var all_talk = level.get_node("Npcs").get_children().all(func(n): return n.lines.size() >= 2)
	_check("NPC: all 7 NPCs are there, and every one has real lines (not 'Hello')",
		level.get_node("Npcs").get_child_count() == 7 and not level.has_node("Signs") and all_talk)


# Lessons: powers unlock where their NPC teaches them, and lives top up at each teacher
func _test_lessons() -> void:
	await _fresh(Vector2(1000, 367))  # spike garden, before Sable
	level._lose_life()
	await _frames(5)
	_check("Lessons: dying before reaching Sable unlocks nothing", level.deaths == 1 and not level.pad_unlocked)

	# The example: died twice before Tomas (3 lives left), Bounce Pad already unlocked
	await _fresh(Vector2(2300, 290))
	level.lesson = 1
	level.pad_unlocked = true
	level.lives = 3
	level.player.global_position = Vector2(2365, 290)  # walk up to Tomas
	await _frames(5)
	_check("Lessons: reaching Tomas with 3 lives tops you up to 4", level.lesson == 2 and level.lives == 4)
	level._lose_life()
	await _frames(5)
	_check("Lessons: then one death there unlocks Double Jump", level.player.double_jump_unlocked and level.lives == 3)


func _test_pause() -> void:
	await _fresh(Vector2(300, 367))
	var pause = level.find_children("*", "CanvasLayer", false, false).filter(func(n): return n.has_method("open"))[0]
	var focus = func(): return root.gui_get_focus_owner()
	await _tap(KEY_ESCAPE)
	_check("Pause: Esc pauses the game and selects Resume",
		paused and pause.is_open and focus.call() and focus.call().text == "Resume")
	var x = level.player.global_position.x
	_key(KEY_RIGHT, true)
	await _frames(20)
	_key(KEY_RIGHT, false)
	_check("Pause: the player can't move while paused", abs(level.player.global_position.x - x) < 1)
	await _tap(KEY_DOWN)
	_check("Pause: Down moves to Restart", focus.call().text == "Restart")
	await _tap(KEY_ESCAPE)
	_check("Pause: Esc again resumes", not paused and not pause.is_open)
	await _joy(JOY_BUTTON_START)
	var joy_open = pause.is_open
	await _joy(JOY_BUTTON_B)
	_check("Pause: controller Start pauses and B resumes", joy_open and not paused)
	await _tap(KEY_P)
	await _tap(KEY_UP)  # wraps from Resume to Main Menu
	var wrapped = focus.call().text == "Main Menu"
	await _tap(KEY_ENTER)
	await create_timer(0.5).timeout
	_check("Pause: Main Menu goes back to the menu, unpaused",
		wrapped and current_scene and current_scene.name == "MainMenu" and not paused)
	await _fresh(Vector2(300, 367))
	var old_level = level
	await _tap(KEY_P)
	await _tap(KEY_DOWN)
	await _tap(KEY_ENTER)
	await create_timer(0.5).timeout
	_check("Pause: Restart reloads the level, unpaused",
		current_scene and current_scene != old_level and current_scene.scene_file_path == "res://level_1.tscn" and not paused)


func _test_menu() -> void:
	_release_all()
	change_scene_to_file("res://main_menu.tscn")
	await create_timer(0.4).timeout
	var menu = current_scene
	var focus = func(): return root.gui_get_focus_owner()
	_check("Menu: opens with Start Game selected", menu.name == "MainMenu" and focus.call() and focus.call().text == "Start Game")
	await _tap(KEY_DOWN)
	await _tap(KEY_S)
	var after_down = focus.call().text
	await _tap(KEY_W)
	_check("Menu: arrow keys and W/S move the selection", after_down == "Controls" and focus.call().text == "Options")
	await _tap(KEY_ENTER)
	await _frames(3)
	_check("Menu: Options opens with the music slider selected", menu.pages["options"].visible and focus.call() is HSlider)
	var settings = root.get_node("Settings")
	var original = settings.music_volume
	focus.call().value = 0.5
	var changed = settings.music_volume == 0.5
	focus.call().value = original  # put the player's real setting back
	_check("Menu: the music slider changes the music volume", changed)
	await _tap(KEY_ESCAPE)
	await _frames(3)
	_check("Menu: Esc goes back to the main page", menu.pages["main"].visible and focus.call().text == "Start Game")
	await _tap(KEY_ENTER)
	await create_timer(1.5).timeout
	_check("Menu: Start Game fades into Level 1", current_scene != null and current_scene.scene_file_path == "res://level_1.tscn")


# ---------- the scared Quit button + "are you sure?" window ----------

func _fresh_menu() -> Control:
	_release_all()
	change_scene_to_file("res://main_menu.tscn")
	await create_timer(0.5).timeout
	return current_scene


func _test_quit_egg() -> void:
	# Keyboard: Quit can be picked straight away, no chasing
	var menu = await _fresh_menu()
	for i in 3:
		await _tap(KEY_DOWN)
	_check("Quit egg: keyboard Down x3 selects Quit Game", root.gui_get_focus_owner() == menu.quit_button)
	await _tap(KEY_ENTER)
	_check("Quit egg: Enter on Quit opens the confirmation (no chasing needed)", is_instance_valid(menu.quit_dialog))
	await _tap(KEY_ESCAPE)
	_check("Quit egg: Esc closes the confirmation", menu.quit_dialog == null)

	# Mouse: it runs away 5 times, never off screen or over another button, then gives up
	menu = await _fresh_menu()
	var quit_button = menu.quit_button
	var start_spot = menu._quit_text_rect().get_center()
	await _mouse_to(start_spot)
	await create_timer(0.6).timeout
	_check("Quit egg: the mouse getting close makes Quit run away",
		menu.quit_escapes == 1 and quit_button.get_global_rect().get_center().distance_to(start_spot) > 100)
	var always_ok = _quit_spot_ok(menu)
	for i in 4:
		await _mouse_to(quit_button.get_global_rect().get_center())
		await create_timer(0.6).timeout
		always_ok = always_ok and _quit_spot_ok(menu)
	_check("Quit egg: it always stays on screen and off the other buttons", always_ok)
	_check("Quit egg: after 5 escapes it gets tired and becomes clickable",
		menu.quit_escapes == 5 and quit_button.mouse_filter == Control.MOUSE_FILTER_STOP)
	var resting = quit_button.position  # (position ignores the slump tilt; global_position doesn't)
	await _mouse_to(quit_button.get_global_rect().get_center())
	await create_timer(1.4).timeout  # give-up animation
	_check("Quit egg: once tired it stays put", menu.quit_escapes == 5 and quit_button.position.distance_to(resting) < 2)

	# Clicking it opens the window; Leave is locked for 5 seconds
	await _click(quit_button.get_global_rect().get_center())
	_check("Quit egg: clicking the tired Quit opens the confirmation", is_instance_valid(menu.quit_dialog))
	var dialog = menu.quit_dialog
	var leave: Button = dialog.find_child("Leave", true, false)
	var question_shown = dialog.find_children("*", "Label", true, false).any(func(l):
		return l.text == "Are you absolutely sure you want to leave The Between?")
	_check("Quit egg: it asks 'Are you absolutely sure you want to leave The Between?'", question_shown)
	await create_timer(1.1).timeout
	await _click(leave.get_global_rect().get_center())
	_check("Quit egg: after 1 s Leave is disabled, says 4..., and clicking it does nothing",
		leave.disabled and _countdown_text(dialog) == "Leaving available in 4..." and not menu.busy)
	await create_timer(3.4).timeout
	_check("Quit egg: still locked at 4.5 s", leave.disabled)
	await create_timer(0.8).timeout
	_check("Quit egg: after 5 s it unlocks as 'Leave The Between'", not leave.disabled and leave.text == "Leave The Between")

	# Stay closes straight away and the countdown stops
	await _tap(KEY_ESCAPE)
	await _click(quit_button.get_global_rect().get_center())
	menu._open_quit_dialog()  # a second open must not make a second window
	var windows = menu.get_children().filter(func(c): return c.name.begins_with("QuitDialog")).size()
	_check("Quit egg: opening twice still shows only one window", windows == 1)
	await create_timer(1.2).timeout
	var stay: Button = menu.quit_dialog.find_children("*", "Button", true, false)[0]
	await _click(stay.get_global_rect().get_center())
	var closed_now = menu.quit_dialog == null
	var seconds_when_closed = menu.quit_seconds_left
	await create_timer(0.3).timeout
	var gone = not menu.has_node("QuitDialog")
	await create_timer(1.5).timeout
	_check("Quit egg: Stay closes it at once and the countdown stops",
		closed_now and gone and menu.quit_seconds_left == seconds_when_closed and not menu.busy)

	# Controller: D-pad to Quit, A opens, B closes
	await _tap(KEY_UP)  # move off Quit
	for i in 3:
		await _joy(JOY_BUTTON_DPAD_UP)
	var on_quit = root.gui_get_focus_owner() == quit_button
	await _joy(JOY_BUTTON_A)
	var opened = is_instance_valid(menu.quit_dialog)
	await _joy(JOY_BUTTON_B)
	_check("Quit egg: controller D-pad reaches Quit, A opens and B closes the window",
		on_quit and opened and menu.quit_dialog == null)

	# Different window shapes: menu stays centred, background covers, Quit stays on screen.
	# The headless test window is square (a real non-16:9 shape); wide and tall are passed in directly.
	var shapes_ok = true
	for shape in [Vector2(1600, 648), Vector2(1152, 900), Vector2.ZERO]:
		menu._fit_to_window(shape)
		await _frames(2)
		var view = shape if shape != Vector2.ZERO else root.get_visible_rect().size
		var start_button: Button = menu.main_buttons[0]
		var centred = abs(start_button.get_global_rect().get_center().x - view.x / 2) < 3
		var cover = Rect2(menu.bg.global_position, menu.screen * menu.bg.scale).encloses(Rect2(Vector2.ZERO, view).grow(-1))
		var on_screen = Rect2(Vector2.ZERO, view).encloses(quit_button.get_global_rect())
		if not (centred and cover and on_screen):
			print("      shape ", shape, " view ", view, " centred ", centred, " cover ", cover, " quit on screen ", on_screen)
			shapes_ok = false
	_check("Quit egg: wide, tall and normal windows keep the menu centred and Quit on screen", shapes_ok)


func _test_leave_quits() -> void:
	var menu = await _fresh_menu()
	for i in 3:
		await _tap(KEY_DOWN)
	await _tap(KEY_ENTER)
	await create_timer(5.3).timeout
	await _tap(KEY_RIGHT)  # Stay -> Leave The Between
	print("PASS  Quit egg: Leave The Between is selectable after the countdown (pressing it now; the game should close)")
	await _tap(KEY_ENTER)
	await create_timer(2.0).timeout
	print("FAIL  Quit egg: Leave did not close the game")
	quit(1)


func _quit_spot_ok(menu: Control) -> bool:
	var view = root.get_visible_rect().size
	var rect = menu.quit_button.get_global_rect()
	var ok = Rect2(Vector2.ZERO, view).encloses(rect)
	for button in menu.main_buttons:
		if button != menu.quit_button and button.get_global_rect().intersects(rect):
			ok = false
	return ok


func _countdown_text(dialog: Node) -> String:
	for label in dialog.find_children("*", "Label", true, false):
		if label.text.begins_with("Leaving") or label.text.begins_with("The way"):
			return label.text
	return ""


# pos is in menu (canvas) coordinates; input events use window coordinates, so convert
func _mouse_to(pos: Vector2) -> void:
	var e = InputEventMouseMotion.new()
	e.position = root.get_final_transform() * pos
	e.global_position = e.position
	Input.parse_input_event(e)
	await _frames(2)


func _click(pos: Vector2) -> void:
	await _mouse_to(pos)
	for down in [true, false]:
		var e = InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		e.position = root.get_final_transform() * pos
		e.global_position = e.position
		Input.parse_input_event(e)
		await _frames(2)


func _joy(button: JoyButton) -> void:
	for down in [true, false]:
		var e = InputEventJoypadButton.new()
		e.button_index = button
		e.pressed = down
		Input.parse_input_event(e)
		await _frames(2)


# ---------- robot helpers ----------

# Fresh level, Warden held still and not charging, player dropped on its head once
func _stomp_once() -> void:
	await _fresh(Vector2(6200, 367))
	var warden = warden_now()
	warden.speed = 0.0
	warden.charge_timer = 99.0
	level.player.global_position = warden.global_position + Vector2(0, -70)
	level.player.velocity = Vector2.ZERO
	await _frames(40)


func warden_now() -> Node2D:
	return level.get_node("Warden")


func _fresh(start: Vector2) -> void:
	_release_all()
	var old = current_scene
	change_scene_to_file("res://level_1.tscn")
	while current_scene == null or current_scene == old:
		await process_frame
	level = current_scene
	level.player.global_position = start
	level.spawn_position = start
	await _frames(15)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _key(code: Key, down: bool) -> void:
	if held.get(code, false) == down:
		return
	held[code] = down
	var e = InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = down
	Input.parse_input_event(e)


func _release_all() -> void:
	for code in held.keys():
		_key(code, false)


func _tap(code: Key) -> void:
	_key(code, true)
	await _frames(2)
	_key(code, false)
	await _frames(1)


func _walk_until(stop_x: float, max_frames: int) -> void:
	_key(KEY_RIGHT, true)
	for i in max_frames:
		await physics_frame
		if level.player.global_position.x >= stop_x:
			_key(KEY_RIGHT, false)
	_key(KEY_RIGHT, false)
	await _frames(20)


# Walk right to edge_x, take off (jump, or dash for "edge"), optionally double jump at
# the top and dash at the second top ("apex2"). Stop moving right at stop_x (-1 = never).
func _leap(edge_x: float, stop_x: float, double_jump: bool, dash_mode: String) -> void:
	var deaths_before = level.deaths
	_key(KEY_RIGHT, true)
	for i in 300:
		if level.player.global_position.x >= edge_x - 8:
			break
		await physics_frame

	if dash_mode == "edge":
		await _tap(KEY_SHIFT)
	else:
		await _tap(KEY_SPACE)

	var did_double = false
	var did_dash = false
	for t in 300:
		await physics_frame
		var p = level.player
		if stop_x > 0 and p.global_position.x >= stop_x:
			_key(KEY_RIGHT, false)
		if double_jump and not did_double and p.velocity.y >= 0.0:
			await _tap(KEY_SPACE)
			did_double = true
		elif dash_mode == "apex2" and did_double and not did_dash and p.velocity.y >= 0.0:
			await _tap(KEY_SHIFT)
			did_dash = true
		if level.deaths > deaths_before:
			break
		if p.is_on_floor() and t > 15:
			break
	_key(KEY_RIGHT, false)
	await _frames(10)


func _landed_on(x_min: float, x_max: float, y_max: float) -> bool:
	var p = level.player.global_position
	return level.player.is_on_floor() and p.x > x_min and p.x < x_max and p.y < y_max


func _check(what: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1
		if is_instance_valid(level) and "player" in level:
			print("      player at ", level.player.global_position, "  deaths ", level.deaths)
