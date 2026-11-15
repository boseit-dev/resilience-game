extends SceneTree
# RESILIENCE - DEMO PLAYTHROUGH (for recording a video)
# A robot plays the whole game with real key presses: menu, every NPC, pause menu,
# dying to unlock each power, lives top-up, the Warden + Soul Strike, the portal,
# and finally the scared Quit button.
#
# Record a video (Godot's Movie Maker writes every frame, with sound):
#   godot --path . --resolution 1280x720 --fixed-fps 30 --write-movie demo.avi --script tools/record_demo.gd -- seed=2
# (seed=2 fixes the Warden's random strikes so the robot wins; '-- boss' skips to the arena)
# Dry run without video (prints progress):
#   godot --headless --path . --script tools/record_demo.gd

var level: Node
var held := {}


func _initialize() -> void:
	# Godot skips drawing while macOS says the window is hidden (off-screen, covered, display asleep),
	# and Movie Maker would then repeat the last frame. So draw anyway.
	process_frame.connect(func():
		if not DisplayServer.window_can_draw():
			RenderingServer.force_draw(false))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("seed="):  # same seed + --fixed-fps = the exact same run every time
			seed(int(arg.substr(5)))
	await _menu_tour()
	if "boss" in OS.get_cmdline_user_args():  # test shortcut: jump straight to the arena
		level.lesson = 3
		level.pad_unlocked = true
		level.player.double_jump_unlocked = true
		level.player.dash_unlocked = true
		level.lives = 2
		level.player.global_position = Vector2(6068, 158)
		level.spawn_position = Vector2(6200, 367)
		await _talk(6090)
		await _warden_fight()
		await _portal_and_quit()
		return
	await _arrival()
	await _spike_garden()
	await _thorn_rise()
	await _hollow_spire()
	await _jump_run()
	await _breach()
	await _leap_of_faith()
	await _warden_fight()
	await _portal_and_quit()


func _log(text: String) -> void:
	var where = ""
	if is_instance_valid(level) and "player" in level:
		where = "  at %s  lives %d  deaths %d" % [level.player.global_position.round(), level.lives, level.deaths]
	print("DEMO ", text, where)


# ---------- the run ----------

func _menu_tour() -> void:
	change_scene_to_file("res://main_menu.tscn")
	await _wait(2.0)
	await _tap(KEY_DOWN)            # Options
	await _wait(0.5)
	await _tap(KEY_ENTER)
	await _wait(2.0)
	await _tap(KEY_ESCAPE)
	await _wait(0.5)
	await _tap(KEY_DOWN)
	await _tap(KEY_DOWN)            # Controls
	await _wait(0.5)
	await _tap(KEY_ENTER)
	await _wait(2.5)
	await _tap(KEY_ESCAPE)
	await _wait(0.8)
	await _tap(KEY_ENTER)           # Start Game
	while current_scene == null or not current_scene.scene_file_path.ends_with("level_1.tscn"):
		await process_frame
	level = current_scene
	await _wait(1.5)
	_log("level started")


func _arrival() -> void:
	await _talk(220)                # Mira: move / jump / talk
	await _walk_to(330)             # over the SPACE JUMP hint
	await _tap(KEY_ESCAPE)          # show the pause menu
	await _wait(1.5)
	await _tap(KEY_ESCAPE)
	await _wait(0.4)
	_log("pause shown, paused=%s" % paused)
	await _talk(440)                # Dr. Oren: lives, dying unlocks powers, spikes tip
	await _leap(548, -1, false, "") # first spike
	await _leap(896, 1000, false, "") # spike strip 1 (stop before the next one)
	_log("arrival done")


func _spike_garden() -> void:
	await _walk_to(1030)
	await _leap(1100, 1268, false, "")   # short hop into the safe gap
	await _wait(0.3)
	await _leap(1250, -1, false, "")     # then over the second strip
	_log("spike garden done")


func _thorn_rise() -> void:
	await _talk(1560)                    # Sable: die in the thorns to unlock the pad
	await _leap(1700, -1, false, "")     # death 1 -> Bounce Pad
	await _wait(2.0)
	await _leap(1700, -1, false, "")     # an extra "oops" death (lives get topped up at Tomas)
	await _wait(1.5)
	await _walk_to(1676)
	await _tap(KEY_E)                    # place a pad at the edge
	await _wait(0.3)
	await _walk_until(1990, 150)         # bounce onto the ledge
	_log("thorn rise done")


func _hollow_spire() -> void:
	await _talk(2370)                    # Tomas (LIVES RESTORED)
	await _walk_to(2440)
	await _leap(2500, -1, false, "")     # death 2 -> Double Jump
	await _wait(2.0)
	await _leap(2500, 2860, true, "")    # jump, jump to the top
	_log("hollow spire done")


func _jump_run() -> void:
	await _walk_to(2900)
	await _leap(2950, 3290, true, "")
	await _leap(3330, 3670, true, "")
	await _leap(3710, 4100, true, "")
	_log("jump run done")


func _breach() -> void:
	await _talk(4370)                    # Ivy: die in the gap to unlock Dash
	await _walk_to(4450)
	await _leap(4600, -1, true, "")      # death 3 -> Dash
	await _wait(2.0)
	await _leap(4600, -1, false, "edge") # dash across all three gaps
	await _leap(5000, -1, false, "edge")
	await _leap(5300, -1, false, "edge")
	_log("breach done")


func _leap_of_faith() -> void:
	await _talk(5490)                    # Old Harrow
	await _leap(5560, 6060, true, "apex2")  # jump, jump, dash
	await _wait(0.5)
	await _talk(6090)                    # Rhea: how to beat the Warden
	_log("leap done")


# A simple boss brain: stomp it when it's open, jump its charge, and after a stomp
# (jump sealed) step between two spots, moving whenever a red mark lands under you.
# Spam SPACE for the Soul Strike.
func _warden_fight() -> void:
	var warden = level.get_node("Warden")
	var frames = 0
	var space_down = false
	var spots = []
	var target = 0
	var pace = 1
	var last = [level.deaths, warden.health]
	while is_instance_valid(warden) and warden.health > 0 and frames < 60 * 120:
		await physics_frame
		frames += 1
		if not is_instance_valid(level):
			_log("game over - level restarted")
			return
		var p = level.player
		if [level.deaths, warden.health] != last:
			last = [level.deaths, warden.health]
			_log("warden hearts %d" % warden.health)

		if paused:  # Soul Strike: hammer SPACE
			space_down = not space_down
			_key(KEY_SPACE, space_down)
			continue
		if space_down:
			space_down = false
			_key(KEY_SPACE, false)

		var px = p.global_position.x
		var dx = warden.global_position.x - px
		var go = 0.0  # where to walk (0 = stay)
		var jump = false
		if warden.safe_timer > 0.0:
			spots = []  # it is leaping away (and harmless): wait for it to land
		elif warden.attack_timer > 0.0 or p.jump_locked_timer > 0.0:
			if spots.is_empty():  # spots 120 px apart on the open side, between it and the wall
				var wx = warden.global_position.x
				var side = 1 if px > wx else -1
				for d in [280, 160, 400]:
					if wx + side * d > 6230 and wx + side * d < 6860:
						spots.append(wx + side * d)
				target = 0
			var marks = []
			for strike in get_nodes_in_group("warden_strike"):
				if not strike.monitoring:
					marks.append(strike.global_position.x)
			if _near_mark(spots[target], marks):  # move to the nearest spot with no mark on it
				var best = target
				for i in spots.size():
					if not _near_mark(spots[i], marks) and (best == target or abs(spots[i] - px) < abs(spots[best] - px)):
						best = i
				target = best
			go = sign(spots[target] - px) if abs(spots[target] - px) > 4 else 0.0
			if warden.health <= 2:  # angry (two strikes at once): keep running, turn at a mark or the wall
				var ahead = px + pace * 45
				if ahead < 6240 or ahead > 6850 or _near_mark(ahead, marks) or abs(warden.global_position.x - ahead) < 70:
					pace = -pace
				go = pace
		else:
			spots = []
			if not p.is_on_floor():
				go = sign(dx) if abs(dx) > 6 else 0.0  # steer onto its head
			elif warden.charging:
				jump = abs(dx) < 90
			else:
				go = sign(dx)
				jump = abs(dx) < 120
		_key(KEY_RIGHT, go > 0)
		_key(KEY_LEFT, go < 0)
		if jump:
			_key(KEY_SPACE, true)
			await _frames(2)
			_key(KEY_SPACE, false)
	_release_all()
	_log("warden fight over (frames %d)" % frames)


func _near_mark(x: float, marks: Array) -> bool:
	for m in marks:
		if abs(m - x) < 30:
			return true
	return false


func _portal_and_quit() -> void:
	await _wait(2.5)                     # it fades away, the portal opens
	await _walk_to(6835)
	await _wait(3.0)                     # TUTORIAL COMPLETE
	_log("portal reached")

	await _tap(KEY_ESCAPE)               # pause -> Main Menu
	await _wait(0.6)
	await _tap(KEY_UP)                   # wraps to Main Menu
	await _wait(0.4)
	await _tap(KEY_ENTER)
	while current_scene == null or not current_scene.scene_file_path.ends_with("main_menu.tscn"):
		await process_frame
	var menu = current_scene
	await _wait(1.5)

	# The Quit button runs from the mouse five times, then gives up
	for i in 5:
		await _mouse_to(menu.quit_button.get_global_rect().get_center())
		await _wait(0.8)
	await _wait(1.2)
	await _click(menu.quit_button.get_global_rect().get_center())
	await _wait(5.6)                     # the countdown
	var leave: Button = menu.quit_dialog.find_child("Leave", true, false)
	_log("leaving")
	await _click(leave.get_global_rect().get_center())  # quits the game (ends the video)
	await _wait(3.0)
	quit()


# ---------- robot helpers ----------

func _talk(npc_x: float) -> void:
	await _walk_to(npc_x - 22)
	await _wait(0.3)
	var npc = null
	for n in level.get_node("Npcs").get_children():
		if abs(n.global_position.x - npc_x) < 5:
			npc = n
	for i in npc.lines.size() + 1:
		await _tap(KEY_E)
		await _wait(1.6 if i < npc.lines.size() else 0.3)


func _walk_to(x: float) -> void:
	var p = level.player
	for i in 900:
		var dx = x - p.global_position.x
		if abs(dx) < 6:
			break
		_key(KEY_RIGHT, dx > 0)
		_key(KEY_LEFT, dx < 0)
		await physics_frame
	_key(KEY_RIGHT, false)
	_key(KEY_LEFT, false)
	await _frames(6)


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
			_log("died on leap from %d" % edge_x)
			break
		if p.is_on_floor() and t > 15:
			break
	_key(KEY_RIGHT, false)
	await _frames(10)


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


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
	await _frames(2)


# pos is in game (canvas) coordinates; input events use window coordinates
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
