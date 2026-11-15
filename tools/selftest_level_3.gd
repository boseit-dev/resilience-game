extends "res://tools/selftest_level_2.gd"
# RESILIENCE - SELF-TEST FOR LEVEL 3 (The Fractured Caverns, the final level) AND THE ENDING
# Uses the robot helpers from the Level 1 and 2 tests (_fresh, _leap, _tap, _ride ...).
# Run:  godot --headless --path . --script tools/selftest_level_3.gd

const L3 = "res://level_3.tscn"
const CRUMBLE = "res://crumbling_platform.gd"


func _initialize() -> void:
	_use_test_save()
	await _test_l3_intro()
	await _test_l3_start()
	await _test_l2_to_l3()
	await _test_l3_entrance()
	await _test_l3_maze()
	await _test_l3_plates()
	await _test_l3_power()
	await _test_l3_depths()
	await _test_l3_symbols()
	await _test_l3_trials()
	await _test_l3_final_trial()
	await _test_l3_boss()
	await _test_l3_escape()
	await _test_ending()
	print("\n", "ALL PASSED" if failures == 0 else "%d FAILED" % failures)
	quit(1 if failures > 0 else 0)


# ---------- helpers ----------

func _puzzles(type: String) -> Array:
	return level.get_node("Map").get_children().filter(func(n): return "data" in n and n.data.get("type") == type)


func _door(i: int) -> Node:
	return level.get_node("Map").made.door[i]


# Stand on the floor at x (feet on floor_top) and press E
func _use_at(x: float, floor_top: float) -> void:
	level.player.global_position = Vector2(x, floor_top - 12)
	level.player.velocity = Vector2.ZERO
	await _frames(6)
	await _tap(KEY_E)
	await _frames(3)


# Walk right (pushing whatever is in front) until the stone reaches x
func _push_until(stone: Node, x: float) -> void:
	_key(KEY_RIGHT, true)
	for i in 900:
		await physics_frame
		if stone.global_position.x >= x:
			break
	_key(KEY_RIGHT, false)
	await _frames(20)


# Walk right onto a Bounce Pad (no jump), double jump at the top of the bounce, land
# Walk onto the pad; between pause_x and the double jump stand still in the air (so you
# don't bump the ledge's underside), then drift right and stop at stop_x.
func _pad_climb(stop_x := INF, pause_x := INF) -> void:
	_key(KEY_RIGHT, true)
	var bounced = false
	for i in 300:
		await physics_frame
		var p = level.player
		if p.global_position.x >= minf(stop_x, pause_x):
			_key(KEY_RIGHT, false)
		if not bounced and p.velocity.y < -450.0:
			bounced = true
		elif bounced and p.velocity.y >= 0.0:
			await _tap(KEY_SPACE)
			if p.global_position.x < stop_x:
				_key(KEY_RIGHT, true)
			break
	for i in 120:
		await physics_frame
		if level.player.global_position.x >= stop_x:
			_key(KEY_RIGHT, false)
		if level.player.is_on_floor():
			break
	_key(KEY_RIGHT, false)
	await _frames(10)


func _place(at: Vector2) -> void:
	level.player.global_position = at
	level.player.velocity = Vector2.ZERO
	level.player.reset_physics_interpolation()
	await _frames(8)


# ---------- tests ----------

func _test_l3_intro() -> void:
	load("res://lab_intro.gd").seen.clear()
	await _fresh(Vector2(140, 368), true, L3)
	_check("L3 intro: plays the first time", not level.player.is_physics_processing() and level.has_node("Intro"))
	await _tap(KEY_SPACE)
	await _frames(30)
	_check("L3 intro: SPACE skips it, CHAPTER III title", level.player.is_physics_processing() and level.banner.text.begins_with("CHAPTER III"))
	await _fresh(Vector2(140, 368), true, L3)
	_check("L3 intro: not again after a restart", level.player.is_physics_processing() and not level.has_node("Intro"))


func _test_l3_start() -> void:
	await _fresh(Vector2(140, 368), true, L3)
	var map = level.get_node("Map")
	_check("Level 3: all powers, 5 lives, 3 pads, the quiet cavern music at the entrance",
		level.level_number == 3 and level.pad_unlocked and level.player.double_jump_unlocked and level.player.dash_unlocked
		and level.lives == 5 and level.pads_remaining == 3 and root.get_node("Sfx").music_target.resource_path.ends_with("intro_theme.wav"))
	var enemies = map.get_children().filter(func(n): return n.is_in_group("enemies"))
	_check("Level 3: 11 enemies (4 tough), 5 chests, 13 lanterns, 11 doors, 10 puzzles, 14 crumbling ledges",
		enemies.size() == 11 and enemies.filter(func(e): return e.health == 2).size() == 4
		and map.get_children().filter(func(n): return n.has_method("pick_reward")).size() == 5
		and get_nodes_in_group("checkpoint").size() == 13 and map.made.door.size() == 11
		and map.get_children().filter(func(n): return "data" in n).size() == 10 and _map_nodes(CRUMBLE).size() == 14)
	_check("Level 3: the six puzzle types are all there",
		["beam", "plate", "symbol", "timed", "power"].all(func(t): return _puzzles(t).size() > 0))
	_check("Level 3: the final boss is the Null Architect with 12 hearts", level.get_node("NullArchitect").health == 12)


func _test_l2_to_l3() -> void:
	await _fresh(Vector2(9700, 368), false, L2)
	level.get_node("ExitPortal").open()
	level.player.global_position = level.get_node("ExitPortal").global_position + Vector2(0, -13)
	for i in 120:
		await physics_frame
		if current_scene != level and current_scene != null:
			break
	await _frames(5)
	_check("Level 2 portal leads to Level 3", current_scene != null and current_scene.name == "Level3")


func _test_l3_entrance() -> void:
	await _fresh(Vector2(760, 368), false, L3)
	for trap in level.get_node("Map").get_children().filter(func(n): return n.get_script() and n.get_script().resource_path == "res://rock_trap.gd"):
		trap.set_physics_process(false)   # no rocks while testing the jump
	await _leap(820, 1060, false, "")
	_check("Entrance: the broken bridge can be jumped", _landed_on(1000, 1200, 381) and level.deaths == 0)

	var beam = _puzzles("beam")[0]
	_check("Light puzzle 1: the door is shut until the light reaches it", not _door(0).is_open and not beam.solved)
	await _use_at(1180, 380)
	await _tap(KEY_E)
	_check("Light puzzle 1: E turns a prism (twice: left -> up -> right)", beam.facing[0] == 0)
	await _use_at(1300, 380)   # the reset lever
	_check("Light puzzle 1: the reset lever puts the prisms back", beam.facing[0] == 2)
	await _use_at(1180, 380)
	await _tap(KEY_E)
	await _use_at(1400, 380)
	await _tap(KEY_E)
	await _tap(KEY_E)
	await _frames(5)
	_check("Light puzzle 1: left RIGHT + right UP lights the receiver, the door opens", beam.solved and _door(0).is_open)
	_check("Light puzzle 1: E at a prism doesn't place a Bounce Pad", level.pads_remaining == 3)

	var plates = _puzzles("plate")[0]
	await _place(Vector2(4300, 368))
	plates.stuck_time = 41.0
	await _frames(3)
	_check("Hints: the first (vague) hint appears after 40 s stuck", plates.hint_label.text == plates.data.hints[0])
	plates.stuck_time = 81.0
	await _frames(3)
	_check("Hints: then a clearer one", plates.hint_label.text == plates.data.hints[1] and plates.hints_shown == 2)


func _test_l3_maze() -> void:
	await _fresh(Vector2(2380, 368), false, L3)
	await _walk_until(2440, 60)
	await _frames(40)
	_check("Maze: dropping down at the fork reaches the lower route safely", level.player.global_position.y > 520 and level.deaths == 0)
	await _place(Vector2(3360, 528))
	await _leap(3372, 3400, false, "")
	await _leap(3432, 3470, false, "")
	await _leap(3492, 3560, false, "")
	_check("Maze: the steps lead back up from the lower route", _landed_on(3500, 3700, 381))
	await _place(Vector2(2880, 368))
	level.get_node("Map").made.mover[0].t = 0.0
	await _leap(2900, 3200, true, "")
	_check("Maze: the upper gap is crossed with a double jump", _landed_on(3140, 3390, 381) and level.deaths == 0)
	var door = _door(1)
	await _place(Vector2(2650, 528))
	await _frames(5)
	_check("Maze: one lever is not enough", not door.is_open and door.flipped == 1)
	await _place(Vector2(3300, 368))
	await _frames(5)
	_check("Maze: a lever on each route opens the maze door", door.is_open)


func _test_l3_plates() -> void:
	await _fresh(Vector2(4425, 368), false, L3)
	var p = _puzzles("plate")[0]
	var a = p.stones[0]
	var b = p.stones[1]
	await _push_until(b, 4574)
	await _frames(30)
	_check("Plates: a pushed stone falls into the gap and presses the plate in it", absf(b.global_position.x - 4574) < 6 and b.global_position.y > 390 and not p.solved)
	await _place(Vector2(4340, 368))
	await _push_until(a, 4818)
	await _frames(20)
	_check("Plates: the second stone rolls over the first onto the far plate: solved, door opens", p.solved and _door(2).is_open)
	await _use_at(4250, 380)
	_check("Plates: the reset lever puts both stones back", a.global_position.distance_to(a.start) < 2 and b.global_position.distance_to(b.start) < 2)


func _test_l3_power() -> void:
	await _fresh(Vector2(5060, 368), false, L3)
	var p = _puzzles("power")[0]
	var map = level.get_node("Map")
	var lift = map.made.mover[1]
	var beams = [map.made.zapper[0], map.made.zapper[1]]
	_check("Power: the lift is still and the barrier is on with no power", not lift.running and beams.all(func(z): return z.active))
	await _use_at(5110, 380)   # LIFT
	await _use_at(5180, 380)   # BARRIER
	_check("Power: LIFT + BARRIER powered: lift moves, barrier off, door still shut",
		lift.running and beams.all(func(z): return not z.active) and not _door(3).is_open)
	await _use_at(5250, 380)   # DOOR: no energy left
	_check("Power: a third machine is refused (only 2 energy)", not p.powered[2] and not _door(3).is_open)
	await _use_at(5180, 380)   # take the barrier's power back
	await _use_at(5250, 380)   # DOOR
	await _use_at(5250, 380)   # and back again
	_check("Power: the door stays open after its power is taken back (latched)", _door(3).is_open and not p.powered[2])
	await _use_at(5180, 380)
	_check("Power: then LIFT + BARRIER again", lift.running and beams.all(func(z): return not z.active))
	var risen = await _ride(lift, 5600)
	_check("Power: the lift carries you up to the high shelf", risen > 200 and _landed_on(5520, 5700, 152))
	await _walk_until(6232, 400)
	_check("Power: past the barrier and through the door (guardian removed)", level.player.global_position.x > 6215 and level.deaths == 0)


func _test_l3_depths() -> void:
	await _fresh(Vector2(6230, 138), false, L3)
	var ledge = _nearest(CRUMBLE, 6400)
	await _place(Vector2(6400, 163))
	await _frames(5)
	_check("Crumbling ledge: cracks when you stand on it", ledge.state == "shaking")
	await _frames(40)
	_check("Crumbling ledge: falls away", ledge.state == "gone")
	await _after_death()
	await _wait(3.2)
	_check("Crumbling ledge: grows back", ledge.state == "solid")
	await _fresh(Vector2(6790, 248), false, L3)
	await _leap(6815, 7250, true, "")
	_check("Depths: a double jump alone can't cross the big gap", level.deaths == 1)
	await _fresh(Vector2(6790, 248), false, L3)
	await _leap(6815, 7250, true, "apex2")
	_check("Depths: Double Jump + Dash crosses it", _landed_on(7205, 7295, 261) and level.deaths == 0)
	await _place(Vector2(7270, 248))
	await _leap(7285, 7440, true, "")
	_check("Depths: the wall is climbed with a double jump", _landed_on(7395, 7485, 121))
	await _fresh(Vector2(350, 368), false, L3)
	await _wait(5.0)
	_check("Falling rocks: standing under the dust costs a life", level.deaths >= 1)


func _test_l3_symbols() -> void:
	await _fresh(Vector2(8600, 368), false, L3)
	var p = _puzzles("symbol")[0]
	_check("Symbols: 4 stones and 4 wall carvings (the clues)", p.data.stones.size() == 4 and p.data.clues.size() == 4)
	await _use_at(8640, 380)   # CRYSTAL first: wrong
	await _frames(2)
	_check("Symbols: a wrong stone resets the sequence and drops a rock (with a warning)", p.pressed.is_empty() and get_nodes_in_group("falling_rock").size() >= 1)
	await _wait(1.5)
	for x in [8720, 8800, 8640, 8880]:   # MOON, FLAME, CRYSTAL, GATE
		await _use_at(x, 380)
	_check("Symbols: MOON, FLAME, CRYSTAL, GATE opens the sanctuary", p.solved and _door(4).is_open)


func _test_l3_trials() -> void:
	await _fresh(Vector2(9450, 368), false, L3)
	var beam = _puzzles("beam")[1]
	await _frames(5)
	_check("Trial 1: not solved at the start", not beam.solved)
	for i in [0, 1, 2, 3]:   # turn each prism until it points the right way: right, down, right, up
		while beam.facing[i] != [0, 1, 0, 3][i]:
			beam.turn(i)
	await _frames(5)
	_check("Trial 1: the light goes down into the pit and back up: solved", beam.solved and _door(5).is_open)

	await _fresh(Vector2(10265, 368), false, L3)
	var p = _puzzles("plate")[1]
	await _push_until(p.stones[1], 10416)
	await _place(Vector2(10170, 368))
	await _push_until(p.stones[0], 10576)
	await _frames(30)
	_check("Trial 2: two stones in two gaps press both plates at once", p.solved and _door(6).is_open)

	await _fresh(Vector2(10860, 368), false, L3)
	var timed = _puzzles("timed")[0]
	await _use_at(10850, 380)
	_check("Trial 3: the lever opens the gate", _door(7).is_open and timed.time_left > 9.0)
	await _wait(10.5)
	_check("Trial 3: it shuts again after 10 seconds (pull it again to retry)", not _door(7).is_open)
	await _use_at(10850, 380)
	_check("Trial 3: the lever works again", _door(7).is_open)
	await _place(Vector2(11205, 308))
	await _leap(11222, 11400, false, "edge")
	_check("Trial 3: a dash gets under the low rock", _landed_on(11340, 11460, 321) and level.deaths == 0)
	await _place(Vector2(11490, 308))
	await _wait(10.0)
	_check("Trial 3: once you're through, the gate stays open", timed.solved and _door(7).is_open)
	await _place(Vector2(11205, 308))
	await _leap(11222, 11400, false, "")
	_check("Trial 3: a jump can't get under the rock", level.deaths == 1)

	await _fresh(Vector2(11800, 128), false, L3)
	await _leap(11840, 11990, false, "edge")
	_check("Trial 4: dash under the second low rock", _landed_on(11950, 12050, 141) and level.deaths == 0)


func _test_l3_final_trial() -> void:
	await _fresh(Vector2(12155, 368), false, L3)
	var p = _puzzles("plate")[2]
	await _push_until(p.stones[1], 12266)
	await _place(Vector2(12080, 368))
	await _push_until(p.stones[0], 12378)
	await _frames(30)
	_check("Final trial: plates again (the lesson from before) open the door", p.solved and _door(8).is_open)
	var beam = _puzzles("beam")[2]
	var barrier = level.get_node("Map").made.zapper[2]
	_check("Final trial: the barrier is on before the light puzzle", barrier.active)
	for i in 5:
		while beam.facing[i] != [2, 1, 2, 2, 3][i]:
			beam.turn(i)
	await _frames(5)
	_check("Final trial: the light (through the middle prism too) switches the barrier off", beam.solved and not barrier.active)

	# The timed climb: pad first, then the lever, then pad + double jump, dash, through the gate
	await _place(Vector2(12955, 368))
	level._place_jump_pad()
	await _use_at(12935, 380)
	var timed = _puzzles("timed")[1]
	_check("Final trial: the last lever opens the gate (9 s)", _door(9).is_open)
	await _place(Vector2(12935, 368))
	await _pad_climb(13090)
	_check("Final trial: Bounce Pad + Double Jump gets up the wall", _landed_on(13050, 13135, 171))
	await _leap(13122, 13300, false, "edge")
	await _walk_until(13420, 120)
	_check("Final trial: dash under the rock and through the gate in time", timed.solved and level.player.global_position.x > 13400 and level.deaths == 0)


func _test_l3_boss() -> void:
	await _fresh(Vector2(13480, 158), false, L3)
	var boss = level.get_node("NullArchitect")
	await _frames(20)
	_check("Null Architect: asleep in the core at first", not boss.awake)
	await _place(Vector2(13900, 368))
	await _frames(10)
	_check("Null Architect: wakes and rises out of the floor (can't be hurt while rising)", boss.awake and boss.emerge_timer > 0.0)
	await _wait(2.8)
	_check("Null Architect: then its music and 12 hearts", root.get_node("Sfx").music_target.resource_path.ends_with("architect_theme.ogg") and boss.hearts.visible and boss.health == 12)
	boss.slam_timer = 0.0
	boss.bolt_timer = 99.0
	await _wait(0.9)
	_check("Null Architect: a slam sends shockwaves both ways", get_nodes_in_group("arrows").size() >= 2)
	boss.bolt_timer = 0.0
	boss.slam_timer = 99.0
	await _wait(0.8)
	_check("Null Architect: energy bolts after a cyan glow", get_nodes_in_group("arrows").size() >= 1)

	var movers = get_nodes_in_group("boss_mover")
	for i in 5:
		boss.safe_timer = 0.0
		boss._take_hit(level.player)
	_check("Phase 2 at 7 hearts (about 60%): red arena, platforms move, beams on",
		boss.phase == 2 and movers.size() == 2 and movers.all(func(m): return m.running)
		and get_nodes_in_group("boss_zapper").all(func(z): return z.active) and level.banner.text.contains("REALITY"))
	boss.attack_timer = 0.0
	boss.safe_timer = 0.0
	boss.teleport_timer = 0.0
	boss.slam_timer = 99.0
	boss.bolt_timer = 99.0
	var x_before = boss.position.x
	await _frames(3)
	_check("Phase 2: it teleports a short way", boss.position.x != x_before)
	for i in 4:
		boss.safe_timer = 0.0
		boss._take_hit(level.player)
	_check("Phase 3 at 3 hearts (25%): THE FINAL STAND, its core shows", boss.phase == 3 and boss.core.visible and level.banner.text.contains("FINAL STAND"))
	boss.attack_timer = 0.0
	boss.safe_timer = 0.0
	boss.rift_timer = 0.0
	boss.slam_timer = 99.0
	boss.bolt_timer = 99.0
	boss.teleport_timer = 99.0
	await _frames(3)
	_check("Phase 3: a dimensional rift opens under you (warning flicker first)",
		level.get_children().any(func(n): return n.get_script() and n.get_script().resource_path == "res://zapper.gd" and not n.is_on))

	# Side touches cost one life, then a grace time (no repeated loss)
	await _place(boss.global_position + Vector2(-20, -12))
	await _frames(20)
	await _after_death()
	_check("Touching its side costs exactly one life", level.deaths == 1)

	level.pads_remaining = 0
	for i in 2:
		boss.safe_timer = 0.0
		boss.finale = false
		boss._take_hit(level.player)
	await _wait(2.4)
	_check("Final attack at 1 heart: it floats to the top, the beam switches on, you get a pad back",
		boss.finale and boss.position.distance_to(boss.core_spot) < 4 and level.pads_remaining >= 1
		and get_nodes_in_group("finale_zapper").all(func(z): return z.active))

	# The climb: Bounce Pad + Double Jump, Double Jump over the beam, Dash under the rock, stomp the core
	for r in get_nodes_in_group("falling_rock"):
		r.queue_free()
	await _place(Vector2(13890, 368))
	level._place_jump_pad()
	await _place(Vector2(13870, 368))
	await _pad_climb(14040, 13960)
	_check("Final attack: Bounce Pad + Double Jump up to the first ledge", _landed_on(13990, 14090, 191))
	await _place(Vector2(14020, 178))
	await _leap(14058, 14300, true, "")   # jump early: a single jump can't clear the beam, a double jump can
	_check("Final attack: Double Jump over the energy beam", _landed_on(14260, 14340, 191) and level.deaths == 1)
	await _leap(14333, 14490, false, "edge")
	_check("Final attack: Dash under the rock", _landed_on(14450, 14550, 191))
	await _place(Vector2(14470, 178))
	_key(KEY_SPACE, true)
	await _frames(2)
	_key(KEY_SPACE, false)
	for i in 120:
		await physics_frame
		if level.player.velocity.y >= 0.0:
			break
	await _tap(KEY_SPACE)
	for i in 120:
		await physics_frame
		if boss.health <= 0:
			break
	var beaten = boss.health <= 0   # (it removes itself soon after)
	await _frames(30)
	var save = root.get_node("SaveGame")
	_check("Final stomp on the core defeats the Null Architect: Level 3 saved", beaten and save.completed.has(3))
	for i in 300:   # the slow-motion finish takes a moment
		if level.get_node("Map").escaping:
			break
		await physics_frame
	await create_timer(1.0).timeout
	_check("The escape starts: door open, gateway open, the collapse is coming, urgent music",
		_door(10).is_open and level.get_node("ExitPortal").is_open and level.get_node("Map").escaping
		and root.get_node("Sfx").music_target.resource_path.ends_with("level_1_theme.ogg"))


func _test_l3_escape() -> void:
	# carries on from the boss test: same level, escape running
	var map = level.get_node("Map")
	await _place(Vector2(14960, 368))
	level.spawn_position = level.player.global_position
	var deaths = level.deaths
	await _wait(10.0)
	await _after_death()
	_check("Escape: standing still, the collapse catches you", level.deaths > deaths)
	_check("Escape: you come back at the escape lantern with the collapse behind you",
		absf(level.player.global_position.x - 14960) < 4 and map.collapse.position.x + map.collapse.size.x < 14960)
	await _place(Vector2(15180, 368))
	await _leap(15200, 15280, false, "")
	_check("Escape: onto the crumbling bridge", _landed_on(15240, 15300, 361))
	level.lives = 1
	level._lose_life()
	for i in 400:
		await physics_frame
		if current_scene != level and current_scene != null:
			break
	await _frames(20)
	level = current_scene
	_check("Escape: Game Over restarts at the escape, not the boss fight",
		level.name == "Level3" and not level.has_node("NullArchitect") and level.get_node("Map").escaping
		and absf(level.player.global_position.x - 14960) < 4)
	await _place(Vector2(18500, 368))
	await _walk_until(18610, 60)
	for i in 120:
		await physics_frame
		if current_scene != level and current_scene != null:
			break
	await _frames(10)
	var save = root.get_node("SaveGame")
	_check("Gateway: the story is saved as finished, the ending plays", current_scene.name == "Ending" and save.finished and save.completed.has(3))


func _test_ending() -> void:
	var ending = current_scene
	await create_timer(2.0).timeout
	_check("Ending: starts at the gateway in The Between", ending.gateway.visible and not ending.lab.visible)
	ending.t = 24.0
	await _frames(5)
	_check("Ending: home in the lab (the scientist lands on the floor)", ending.lab.visible and ending.scientist.visible and not ending.tunnel.visible)
	ending.t = 0.0
	ending.next_beat = 0
	await _frames(2)
	await _tap(KEY_SPACE)
	await _frames(10)
	_check("Ending: a SPACE press in the first moment doesn't skip it (a leftover jump)", not ending.credits_layer.visible)
	ending.t = 2.0
	await _tap(KEY_SPACE)
	await _frames(10)
	_check("Ending: SPACE skips to the credits", ending.credits_layer.visible)
	await _tap(KEY_SPACE)
	await _frames(5)
	_check("Credits: an instant second SPACE doesn't skip the credits too", current_scene == ending)
	ending.t = 57.0
	await _tap(KEY_SPACE)
	await create_timer(1.2).timeout
	var save = root.get_node("SaveGame")
	_check("Credits: SPACE goes to the main menu and the save is still finished",
		current_scene.scene_file_path == "res://main_menu.tscn" and save.finished and save.current_level == 3)
	var cs = root.get_node("SaveGame")
	var keep = [cs.completed.duplicate(), cs.current_level]
	cs.completed = []
	cs.current_level = 1
	_check("Continue before beating Level 1 plays the opening cutscene first (tutorial + menu)", cs.continue_scene() == cs.STORY_START)
	cs.completed = [1]
	cs.current_level = 2
	_check("Continue after Level 1 goes straight to the level", cs.continue_scene() == "res://level_2.tscn")
	cs.completed = keep[0]
	cs.current_level = keep[1]
	_check("Continue Game is enabled for a finished story (replay Level 3)", not current_scene.pages["main"].get_child(0).disabled)
	save.start_new_game()
	_check("New Game starts a fresh story (finished cleared)", not save.finished and save.completed.is_empty() and save.current_level == 1)
	_use_test_save()
