extends "res://tools/selftest_level_1.gd"
# RESILIENCE - SELF-TEST FOR LEVEL 2 (Forgotten Laboratories)
# Uses the same robot helpers as the Level 1 test (_fresh, _leap, _tap ...).
# Run:  godot --headless --path . --script tools/selftest_level_2.gd

const L2 = "res://level_2.tscn"
# Script paths, not preload(): preloading game scripts here would compile them before the
# autoloads (Sfx, SaveGame) exist, and break them.
const ZAPPER = "res://zapper.gd"
const DOOR = "res://lab_door.gd"
const MOVER = "res://moving_platform.gd"


func _initialize() -> void:
	_use_test_save()
	await _test_intro()
	await _test_start_state()
	await _test_entrance()
	await _test_chambers()
	await _test_high_route()
	await _test_archives()
	await _test_power_core()
	await _test_lockdown()
	await _test_boss()
	await _test_game_over()
	print("\n", "ALL PASSED" if failures == 0 else "%d FAILED" % failures)
	quit(1 if failures > 0 else 0)


# ---------- helpers ----------

func _map_nodes(script: String) -> Array:
	return level.get_node("Map").get_children().filter(func(n): return n.get_script() and n.get_script().resource_path == script)


func _nearest(script: String, x: float) -> Node:
	var nodes = _map_nodes(script)
	nodes.sort_custom(func(a, b): return absf(a.position.x - x) < absf(b.position.x - x))
	return nodes[0]


# Put a beam at the start of its OFF time (so the robot has the whole safe window)
func _beam_off(zapper: Node) -> void:
	zapper.t = 0.0
	zapper.offset = 0.0


func _beam_on(zapper: Node) -> void:
	zapper.t = zapper.off_time + 0.05


# Jump straight up, double jump at the top, then drift in a direction until landing
func _climb(direction: Key) -> void:
	await _tap(KEY_SPACE)
	for i in 60:
		await physics_frame
		if level.player.velocity.y >= 0.0:
			break
	await _tap(KEY_SPACE)
	for i in 20:
		await physics_frame
	_key(direction, true)
	for i in 120:
		await physics_frame
		if level.player.is_on_floor():
			break
	_key(direction, false)
	await _frames(10)


func _wait(seconds: float) -> void:
	await _frames(int(seconds * 60.0))


# Ride a lift from the bottom (checks it carries you), then step off at the top
func _ride(lift: Node, step_off_x: float) -> float:
	lift.t = 0.0
	await _frames(2)
	level.player.global_position = lift.position + Vector2(0, -12)
	await _frames(10)
	var start_y = level.player.global_position.y
	while lift.t < lift.time - 0.05:
		await physics_frame
	await _walk_until(step_off_x, 150)
	return start_y - level.player.global_position.y   # how far it carried you up


# ---------- tests ----------

func _test_intro() -> void:
	load("res://lab_intro.gd").seen = false
	await _fresh(Vector2(140, 368), true, L2)
	_check("Intro: plays on the first visit (no control during it)", not level.player.is_physics_processing() and level.has_node("Intro"))
	await _tap(KEY_SPACE)
	await _frames(30)
	_check("Intro: SPACE skips it, control comes back at the start",
		level.player.is_physics_processing() and level.player.global_position.distance_to(level.spawn_position) < 4.0
		and level.banner.text.begins_with("CHAPTER II") and level.hud_layer.visible)
	await _frames(40)
	_check("Intro: the terminal warning text is gone afterwards", level.get_children().filter(func(n): return n is Label).is_empty())
	await _fresh(Vector2(140, 368), true, L2)
	_check("Intro: does not play again (restarts, Continue)", level.player.is_physics_processing() and not level.has_node("Intro"))


func _test_start_state() -> void:
	await _fresh(Vector2(140, 368), true, L2)
	_check("Level 2: starts with all 3 powers, 5 lives, 3 pads",
		level.level_number == 2 and level.pad_unlocked and level.player.double_jump_unlocked and level.player.dash_unlocked
		and level.lives == 5 and level.pads_remaining == 3)
	_check("Level 2: player spawns at the entrance on the floor", level.player.is_on_floor() and absf(level.player.global_position.x - 140) < 4)
	_check("Level 2: its own music", root.get_node("Sfx").music_target.resource_path.ends_with("level_2_theme.ogg"))
	var enemies = level.get_node("Map").get_children().filter(func(n): return n.is_in_group("enemies"))
	_check("Level 2: 10 enemies, 4 chests, 6 lanterns, 2 doors, 8 beams, 4 lifts",
		enemies.size() == 10 and get_nodes_in_group("checkpoint").size() == 6 and _map_nodes(DOOR).size() == 2
		and _map_nodes(ZAPPER).size() == 8 and _map_nodes(MOVER).size() == 4
		and level.get_node("Map").get_children().filter(func(n): return n.has_method("pick_reward")).size() == 4)
	_check("Level 2: tough enemies need 2 stomps", enemies.filter(func(e): return e.health == 2).size() == 3)


func _test_entrance() -> void:
	await _fresh(Vector2(500, 368), false, L2)
	await _leap(600, 780, false, "")
	_check("Entrance: the collapsed floor can be jumped", _landed_on(700, 900, 380) and level.deaths == 0)

	await _fresh(Vector2(60, 368), false, L2)
	await _walk_until(100, 40)
	await _climb(KEY_RIGHT)
	_check("Entrance: the hidden alcove is reached with a double jump", _landed_on(120, 320, 232))

	await _fresh(Vector2(1200, 368), false, L2)
	var beam = _nearest(ZAPPER, 1300)
	_beam_off(beam)
	await _walk_until(1400, 120)
	_check("Corridor beam: walking through while it's off is safe", level.deaths == 0 and level.player.global_position.x > 1380)
	await _fresh(Vector2(1300, 368), false, L2)
	beam = _nearest(ZAPPER, 1300)
	_beam_on(beam)
	await _frames(5)
	_check("Corridor beam: touching it while on costs a life", level.deaths == 1)


func _test_chambers() -> void:
	await _fresh(Vector2(1700, 368), false, L2)
	var risen = await _ride(_nearest(MOVER, 1760), 2125)
	var door = _nearest(DOOR, 3500)
	_check("Lift: carries you up to the shelf", risen > 150 and level.player.global_position.y < 215)
	_check("Switch 1: flips, but one switch doesn't open the door", door.flipped == 1 and not door.is_open)

	await _fresh(Vector2(2280, 368), false, L2)
	_beam_off(_nearest(ZAPPER, 2320))
	await _walk_until(2680, 120)
	_check("Electrified floor: you can cross while it's off", level.deaths == 0 and level.player.global_position.x > 2650)
	await _fresh(Vector2(2450, 368), false, L2)
	_beam_on(_nearest(ZAPPER, 2320))
	await _frames(5)
	_check("Electrified floor: standing on it while on costs a life", level.deaths == 1)

	await _fresh(Vector2(2680, 368), false, L2)
	door = _nearest(DOOR, 3500)
	door._on_lever_touched(level.player, door.get_children().filter(func(c): return c is Sprite2D and c.top_level)[0])   # switch 1 (tested above)
	_nearest(MOVER, 2740).t = 0.0   # the lift waits at the bottom
	await _walk_until(2745, 30)   # falls down the hole into the hidden room
	_check("Research room: dropping through the hole lands in the hidden room (or on its lift)", level.player.global_position.y > 440 and level.deaths == 0)
	level.player.global_position = Vector2(2850, 508)
	await _walk_until(3105, 200)
	_check("Switch 2: both switches open the door", door.is_open)
	risen = await _ride(_nearest(MOVER, 2740), 2820)
	_check("Research room: the lift takes you back up", risen > 120 and level.player.global_position.y < 390 and level.player.global_position.x > 2790)
	await _frames(60)   # the door slides up
	level.player.global_position = Vector2(3420, 368)
	await _walk_until(3610, 120)
	_check("Door: open, you walk through to the Archives side", level.player.global_position.x > 3600 and level.deaths == 0)


func _test_high_route() -> void:
	await _fresh(Vector2(2100, 198), false, L2)
	await _leap(2150, 2395, true, "")
	_check("High route 1: double jump to the first platform", _landed_on(2360, 2440, 202))
	await _leap(2440, 2690, true, "")
	_check("High route 2: double jump to the second", _landed_on(2660, 2730, 192))
	await _fresh(Vector2(2700, 178), false, L2)
	await _leap(2730, -1, true, "")
	_check("High route 3: a double jump alone falls short", not _landed_on(3215, 3330, 192))
	await _fresh(Vector2(2700, 178), false, L2)
	await _leap(2730, 3270, true, "apex2")
	_check("High route 3: double jump + dash makes it", _landed_on(3215, 3330, 192))
	await _leap(3330, 3500, false, "")
	_check("High route: lands on top of the door frame, past the door", _landed_on(3400, 3650, 172))


func _test_archives() -> void:
	await _fresh(Vector2(4200, 368), false, L2)
	await _walk_until(4300, 60)
	await _frames(40)
	_check("Archives: a gap in the floor drops into the hidden cave", level.player.global_position.y > 470 and level.deaths == 0)
	level.player.global_position = Vector2(4712, 488)
	await _frames(10)
	await _climb(KEY_RIGHT)
	_check("Archives: a double jump climbs out of the cave", _landed_on(4750, 5000, 382))

	await _fresh(Vector2(4760, 368), false, L2)
	await _climb(KEY_RIGHT)
	_check("Archives: the dead-end shelf is reached with a double jump", _landed_on(4800, 5150, 232))


func _test_power_core() -> void:
	await _fresh(Vector2(5600, 318), false, L2)
	var lift = _nearest(MOVER, 5600)
	lift.t = 0.0
	level.player.global_position = Vector2(5600, 318)
	await _wait(2.4)
	await _leap(5920, 6020, false, "")
	_check("Core: the moving platform carries you to the pillar", _landed_on(5980, 6120, 302) and level.deaths == 0)

	_beam_off(_nearest(ZAPPER, 6290))
	await _fresh(Vector2(6000, 288), false, L2)
	await _leap(6110, 6300, true, "")
	_check("Core climb: a double jump alone can't reach the high ledge", not _landed_on(6280, 6460, 122))
	await _fresh(Vector2(5995, 288), false, L2)
	_beam_off(_nearest(ZAPPER, 6290))
	await _tap(KEY_E)
	_key(KEY_RIGHT, true)
	var launched = false
	for i in 200:
		await physics_frame
		if level.player.velocity.y < -450.0:
			launched = true
		if launched and level.player.velocity.y >= 0.0:
			break
	await _tap(KEY_SPACE)
	for i in 200:
		await physics_frame
		if level.player.global_position.x > 6420:
			_key(KEY_RIGHT, false)
		if level.player.is_on_floor():
			break
	_key(KEY_RIGHT, false)
	await _frames(10)
	_check("Core climb: Bounce Pad + double jump reaches the ledge", _landed_on(6280, 6460, 122) and level.deaths == 0)

	await _fresh(Vector2(6440, 108), false, L2)
	await _leap(6460, 6640, false, "")
	_check("Core gap: the ceiling is too low to jump across", level.deaths == 1)
	await _fresh(Vector2(6420, 108), false, L2)
	await _leap(6460, 6640, false, "edge")
	_check("Core gap: a dash crosses it", _landed_on(6580, 6800, 122) and level.deaths == 0)


func _test_lockdown() -> void:
	await _fresh(Vector2(7300, 368), false, L2)
	var risen = await _ride(_nearest(MOVER, 7380), 7705)
	var door = _nearest(DOOR, 8520)
	_check("Lockdown: the lift reaches the catwalk and switch A", risen > 120 and door.flipped == 1 and level.player.global_position.y < 225)
	level.player.global_position = Vector2(7860, 208)
	await _frames(5)
	await _leap(7870, 7950, true, "")
	_check("Lockdown: the side ledge (chest) is reachable", _landed_on(7900, 8000, 162))

	await _fresh(Vector2(8080, 368), false, L2)
	door = _nearest(DOOR, 8520)
	door.flipped = 1   # switch A (tested above)
	for z in [8180, 8280, 8380]:
		_beam_off(_nearest(ZAPPER, z))
	await _walk_until(8425, 200)
	_check("Lockdown: past the beams while they're off, switch B opens the door", door.is_open and level.deaths == 0)


func _test_boss() -> void:
	await _fresh(Vector2(8620, 368), false, L2)
	var boss = level.get_node("Prototype")
	await _frames(30)
	_check("Prototype: asleep while you're at the lantern", not boss.awake)
	level.player.global_position = Vector2(8850, 368)
	await _frames(10)
	_check("Prototype: wakes when you walk in, boss music starts", boss.awake and root.get_node("Sfx").music_target.resource_path.ends_with("boss_theme.ogg"))
	_check("Prototype: 8 hearts shown", boss.health == 8 and boss.hearts.get_child_count() == 8)
	boss.bolt_timer = 0.0
	await _frames(int((boss.BOLT_WARN + 0.1) * 60))
	_check("Prototype: fires an electric bolt after a warning glow", get_nodes_in_group("arrows").size() >= 1)

	var zappers = get_nodes_in_group("boss_zapper")
	_check("Prototype: arena beams are off in phase 1", zappers.size() == 2 and zappers.all(func(z): return not z.active))
	for i in 3:
		boss.safe_timer = 0.0
		boss._take_hit(level.player)
	_check("Prototype: phase 2 (System Failure) at 5 hearts: beams on, faster music",
		boss.phase == 2 and zappers.all(func(z): return z.active) and root.get_node("Sfx").music.pitch_scale > 1.05)
	for i in 3:
		boss.safe_timer = 0.0
		boss._take_hit(level.player)
	_check("Prototype: phase 3 (Overload) at 2 hearts", boss.phase == 3 and level.banner.text.contains("OVERLOAD"))
	_check("Prototype: no Soul Strike pause", not paused)

	# A real stomp from above still works
	boss.bolt_timer = 99.0
	await _frames(40)   # let its leap away finish
	boss.safe_timer = 0.0
	boss.attack_timer = 0.0
	boss.charging = false
	boss.warn_timer = 0.0
	boss.speed = 0.0
	level.player.global_position = boss.global_position + Vector2(0, -70)
	level.player.velocity = Vector2.ZERO
	for i in 60:
		await physics_frame
		if boss.health < 2:
			break
	_check("Prototype: a stomp on its head takes a heart", boss.health == 1)
	boss.safe_timer = 0.0
	boss._take_hit(level.player)
	await _frames(20)
	var save = root.get_node("SaveGame")
	_check("Prototype beaten: Level 2 saved, Level 3 unlocked, 2nd fragment",
		save.completed.has(2) and save.unlocked_level == 3 and save.current_level == 3 and save.fragments >= 1)
	_check("Prototype beaten: victory music, beams off, portal opens",
		root.get_node("Sfx").music_target.resource_path.ends_with("victory_theme.ogg") and zappers.all(func(z): return not z.active)
		and level.get_node("ExitPortal").is_open)
	level.player.global_position = level.get_node("ExitPortal").global_position + Vector2(0, -13)
	await _frames(10)
	_check("Portal: says LEVEL 3 COMING SOON (Level 3 not built yet)", level.get_node("ExitPortal/Message").text == "LEVEL 3 COMING SOON")
	_use_test_save()


func _test_game_over() -> void:
	await _fresh(Vector2(1000, 368), false, L2)
	level.lives = 1
	level._lose_life()
	for i in 400:
		await physics_frame
		if current_scene != level and current_scene != null:
			break
	await _frames(20)
	_check("Game Over in Level 2 restarts Level 2 with 5 lives, no intro",
		current_scene.name == "Level2" and current_scene.lives == 5 and not current_scene.has_node("Intro"))
