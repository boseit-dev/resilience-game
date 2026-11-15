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
	await _test_expansion()
	await _test_checkpoint_and_pads()
	await _test_enemies()
	await _test_one_life_per_enemy_death()
	await _test_chests_and_rewards()
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


# The newer areas (level_1_expansion.gd): every branch can be reached AND left again
func _test_expansion() -> void:
	await _fresh(Vector2(-3400, 368), true)
	var ex = level.get_node("Expansion")
	var placed = ex.get_children().filter(func(n): return n.is_in_group("enemies"))
	var chests = ex.get_children().filter(func(n): return n.scene_file_path == "res://chest.tscn")
	_check("Expansion: 10 enemies and 5 chests are placed", placed.size() == 10 and chests.size() == 5)
	_check("Expansion: the player starts at the arrival rift", level.player.global_position.x < -3000)
	await _frames(60)
	_check("Expansion: no enemy fell out of the world", placed.all(func(e): return is_instance_valid(e) and e.global_position.y < 600))

	# Upper Ruins: up the broken stairs to the high walkway (no powers needed)
	await _fresh(Vector2(-3100, 368))
	await _leap(-3055, -2985, false, "")
	_check("Upper Ruins: first stair step", _landed_on(-3000, -2940, 330))
	await _leap(-2965, -2895, false, "")
	_check("Upper Ruins: second stair step", _landed_on(-2910, -2850, 285))
	await _leap(-2875, -2805, false, "")
	_check("Upper Ruins: third stair step", _landed_on(-2820, -2760, 240))
	await _leap(-2785, -2650, false, "")
	_check("Upper Ruins: onto the high walkway", _landed_on(-2730, -2400, 205) and level.deaths == 0)

	# Sunken Hollow: drop through the crack (safe), then climb out without any powers
	await _fresh(Vector2(-2700, 368))
	await _walk_until(-2570, 120)
	await _frames(50)
	_check("Sunken Hollow: falling through the crack is safe", _landed_on(-2610, -2530, 530) and level.deaths == 0)
	_check("Sunken Hollow: the area name shows", level.banner.text == "SUNKEN HOLLOW")
	await _fresh(Vector2(-2060, 508))
	await _leap(-2005, -1945, false, "")
	_check("Sunken Hollow: jump onto the first step", _landed_on(-1950, -1905, 470))
	await _leap(-1935, -1865, false, "")
	_check("Sunken Hollow: jump onto the second step", _landed_on(-1880, -1840, 425))
	await _leap(-1855, -1750, false, "")
	_check("Sunken Hollow: climb back out to the path", _landed_on(-1780, -1560, 375) and level.deaths == 0)

	# Thorn Rise: a bounce pad placed well before the treasure ledge gets you onto it
	await _fresh(Vector2(1466, 367))
	level.pad_unlocked = true
	await _tap(KEY_E)
	await _walk_until(1625, 120)
	await _frames(70)
	_check("Thorn Rise: a pad gets you onto the treasure ledge", _landed_on(1600, 1660, 250))

	# Hollow Spire: at the right end of Jump Platform 2, double jump straight up, then step right
	await _fresh(Vector2(3700, 117))
	level.player.double_jump_unlocked = true
	await _tap(KEY_SPACE)
	while level.player.velocity.y < 0.0:
		await physics_frame
	await _tap(KEY_SPACE)
	while level.player.velocity.y < -60.0:
		await physics_frame
	_key(KEY_RIGHT, true)
	while level.player.global_position.x < 3755:
		await physics_frame
	_key(KEY_RIGHT, false)
	await _frames(60)
	_check("Spire Hideout: double jump reaches it", _landed_on(3722, 3800, -20) and level.deaths == 0)

	# The Breach: the gap between floors B and C hides a tunnel; you can climb back up
	await _fresh(Vector2(4960, 157))
	level.player.double_jump_unlocked = true
	await _walk_until(5040, 120)
	await _frames(60)
	_check("Breach tunnel: dropping into the gap lands in the tunnel", _landed_on(4990, 5380, 340) and level.deaths == 0)
	level.player.global_position = Vector2(4997, 318)
	await _frames(10)
	await _leap(5000, 5068, false, "")
	_check("Breach tunnel: jump onto the step", _landed_on(5050, 5085, 290))
	# jump, double jump, and only then move right (moving right too early walks under floor C)
	await _tap(KEY_SPACE)
	while level.player.velocity.y < 0.0:
		await physics_frame
	await _tap(KEY_SPACE)
	while level.player.velocity.y < -150.0:
		await physics_frame
	_key(KEY_RIGHT, true)
	await _frames(12)
	_key(KEY_RIGHT, false)
	await _frames(40)
	_check("Breach tunnel: double jump back up to floor C", _landed_on(5090, 5300, 165))

	# Warden's Approach: the final checkpoint, then the drop into the arena
	await _fresh(Vector2(6520, 157))
	await _walk_until(6605, 150)
	await _frames(20)
	_check("Warden's Approach: the final checkpoint becomes the respawn point", level.spawn_position.x > 6550 and level.spawn_position.x < 6650)
	var barrier = level.get_node("Expansion").get_children().filter(func(n): return n.get_script() == load("res://wooden_barrier.gd") and n.position.x > 6900)[0]
	level.player.dash_unlocked = true
	await _walk_until(6905, 120)
	_check("Wooden barrier: walking into it does nothing (it blocks the way)", not barrier.broken and level.player.global_position.x < 6900)
	_key(KEY_RIGHT, true)
	await _tap(KEY_SHIFT)
	await _frames(10)
	_check("Wooden barrier: a dash smashes it", barrier.broken)
	await _walk_until(7080, 300)
	await _frames(40)
	_check("Warden's Approach: drops into the Warden's arena", _landed_on(7036, 7796, 390) and level.deaths == 0)


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
	await _after_death()
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
	_check("Game over: the Game Over screen shows before restarting", current_scene == before and is_instance_valid(level.game_over_screen))
	while current_scene == before or current_scene == null:
		await process_frame
	_check("Game over then restarts the level with 5 lives", current_scene.lives == 5)
	level = current_scene


# ---------- Level 1 expansion: enemies ----------

func _spawn(scene_path: String, at: Vector2) -> Node:
	var thing = load(scene_path).instantiate()
	thing.position = at  # before add_child, so enemies remember this as home
	level.add_child(thing)
	return thing


func _test_enemies() -> void:
	# Sword Fighter: sees you, chases, warns, swings: exactly one life lost
	await _fresh(Vector2(300, 368))
	level.spawn_position = Vector2(60, 368)  # respawn far away, out of its sight
	var sword = _spawn("res://enemies/sword_fighter.tscn", Vector2(380, 380))
	await _frames(20)
	_check("Sword Fighter: spots you and chases", sword.state != sword.State.PATROL)
	await _frames(70)
	_check("Sword Fighter: its swing costs exactly one life", level.lives == 4 and level.deaths == 1)
	await _frames(60)
	_check("Sword Fighter: no second hit after you respawn far away", level.lives == 4)

	# Stomp from above defeats it, without hurting you
	await _fresh(Vector2(400, 300))
	sword = _spawn("res://enemies/sword_fighter.tscn", Vector2(400, 380))
	await _frames(40)
	_check("Sword Fighter: one stomp from above defeats it (no life lost)", (not is_instance_valid(sword) or sword.defeated) and level.lives == 5)

	# Walking into one: one life, not one per frame
	await _fresh(Vector2(300, 368))
	level.spawn_position = Vector2(300, 368)
	var walker = _spawn("res://enemies/sword_fighter.tscn", Vector2(300, 380))
	walker.set_physics_process(false)
	await _frames(3)  # let physics notice the overlap
	walker.hurt_cooldown = 0.0
	walker._check_player_touch()
	walker._check_player_touch()
	walker._check_player_touch()
	await _frames(5)
	_check("Enemies: touching one costs one life, not one per frame", level.lives == 4)
	walker.queue_free()

	# Archer: draws, fires a real arrow that flies and hits
	await _fresh(Vector2(260, 368))
	level.spawn_position = Vector2(-2000, 368) if level.has_node("Expansion") else Vector2(60, 368)
	var archer = _spawn("res://enemies/archer.tscn", Vector2(480, 380))
	var saw_arrow = false
	for i in 200:
		await physics_frame
		saw_arrow = saw_arrow or not get_nodes_in_group("arrows").is_empty()
		if level.deaths > 0:
			break
	_check("Archer: fires an arrow you can see", saw_arrow)
	_check("Archer: the arrow hits you (one life)", level.lives == 4)
	archer.queue_free()

	# Arrows stop at walls, and archers don't shoot through them
	await _fresh(Vector2(200, 368))
	var wall = StaticBody2D.new()
	var wall_shape = CollisionShape2D.new()
	wall_shape.shape = RectangleShape2D.new()
	wall_shape.shape.size = Vector2(30, 200)
	wall.add_child(wall_shape)
	level.add_child(wall)
	wall.global_position = Vector2(330, 300)
	archer = _spawn("res://enemies/archer.tscn", Vector2(460, 380))
	await _frames(90)
	_check("Archer: doesn't shoot through a wall", get_nodes_in_group("arrows").is_empty() and level.lives == 5)
	var arrow = load("res://enemies/arrow.gd").new()
	arrow.velocity = Vector2(-240, 0)
	level.add_child(arrow)
	arrow.global_position = Vector2(420, 360)
	await _frames(40)
	_check("Arrow: disappears when it hits a wall", not is_instance_valid(arrow) and level.lives == 5)
	archer.queue_free()
	wall.queue_free()

	# Armoured Guardian: three stomps, armour cracks, then breaks
	await _fresh(Vector2(420, 260))
	var guardian = _spawn("res://enemies/guardian.tscn", Vector2(420, 380))
	var cracks_seen = []
	for i in 300:
		await physics_frame
		if is_instance_valid(guardian) and not guardian.defeated and cracks_seen.size() < 3 - guardian.health:
			cracks_seen.append(guardian.cracks.get_child_count())
		if not is_instance_valid(guardian) or guardian.defeated:
			break
	_check("Guardian: 3 stomps defeat it", not is_instance_valid(guardian) or guardian.defeated)
	_check("Guardian: armour cracks after stomp 1 and breaks more after stomp 2", cracks_seen.size() >= 2 and cracks_seen[1] > cracks_seen[0] and cracks_seen[0] > 0)
	_check("Guardian: bouncing on its head didn't cost a life", level.lives == 5)

	# Guardian slam: warns first, then hurts if you stay close
	await _fresh(Vector2(380, 368))
	level.spawn_position = Vector2(60, 368)
	guardian = _spawn("res://enemies/guardian.tscn", Vector2(430, 380))
	await _frames(10)
	_check("Guardian: crouches and glows before slamming (warning)", guardian.state == guardian.State.WARN and level.lives == 5)
	await _frames(40)
	_check("Guardian: its slam hits you if you stay close", level.lives == 4)
	guardian.queue_free()

	# Respawning sends living enemies home
	await _fresh(Vector2(300, 368))
	sword = _spawn("res://enemies/sword_fighter.tscn", Vector2(500, 380))
	sword.global_position = Vector2(420, 380)
	level._lose_life()
	await _after_death()
	_check("Enemies: respawning sends them back to where they started", sword.global_position.distance_to(Vector2(500, 380)) < 10)
	sword.queue_free()


# ---------- Level 1 expansion: chests and rewards ----------

# Bug report: dying to an enemy cost 2 lives (one from the enemy, one just from respawning)
func _test_one_life_per_enemy_death() -> void:
	await _fresh(Vector2(300, 368))
	level.spawn_position = Vector2(-3400, 368)
	var sword = _spawn("res://enemies/sword_fighter.tscn", Vector2(300, 380))
	await create_timer(3.0).timeout
	_check("Enemy death: one hit costs exactly one life (not one more on respawn)", level.lives == level.MAX_LIVES - 1 and level.deaths == 1)
	# An enemy right next to the lantern can't hit you the moment you reappear
	level.spawn_position = Vector2(300, 368)
	sword.reset_after_player_death()
	level._lose_life()
	await _after_death()
	await _frames(20)
	_check("Respawn: a short safe time (the player blinks) before enemies can hurt you", level.respawn_grace > 0.0 and level.lives == level.MAX_LIVES - 2)
	await create_timer(2.0).timeout
	_check("Respawn: after the safe time, enemies hurt you again", level.lives == level.MAX_LIVES - 3)


func _test_chests_and_rewards() -> void:
	await _fresh(Vector2(300, 368))
	var chest = _spawn("res://chest.tscn", Vector2(310, 380))
	await _frames(5)
	_check("Chest: walking up shows 'E  OPEN'", chest.prompt.visible)
	var pads_before = level.pads_remaining
	await _tap(KEY_E)
	await _frames(5)
	_check("Chest: E opens it (and places no pad)", chest.opened and level.placed_pads.is_empty() and level.pads_remaining == pads_before)
	_check("Chest: the reward is shown", level.banner.text.begins_with("TREASURE"))
	var banner_text = level.banner.text
	await _tap(KEY_E)
	await _frames(5)
	_check("Chest: it can't be opened twice", level.banner.text == banner_text)
	level._lose_life()
	await _after_death()
	_check("Chest: stays open after an ordinary death", is_instance_valid(chest) and chest.opened)

	# Reward picks never include useless ones (start clean: the chest's random reward may have been a shield)
	level.player.has_shield = false
	level.player.speed_boost_timer = 0.0
	level.lives = 5
	var picks = {}
	for i in 300:
		picks[chest.pick_reward(level)] = true
	_check("Chest: no heart at full lives, no pad or dash before they're unlocked", not picks.has("heart") and not picks.has("pad") and not picks.has("dash"))
	level.lives = 3
	level.pad_unlocked = true
	level.player.dash_unlocked = true
	picks = {}
	for i in 400:
		picks[chest.pick_reward(level)] = true
	_check("Chest: all five rewards can appear when useful", picks.size() == 5)

	# Each reward works
	level.lives = 3
	level.give_reward("heart")
	level.give_reward("pad")
	_check("Rewards: +1 life and +1 bounce pad", level.lives == 4 and level.pads_remaining == pads_before + 1)
	level.lives = 5
	level.give_reward("heart")
	_check("Rewards: a heart never goes above 5 lives", level.lives == 5)
	level.give_reward("speed")
	_key(KEY_RIGHT, true)
	await _frames(5)
	var fast = level.player.velocity.x
	_check("Rewards: speed boost makes you faster", fast > level.player.SPEED * 1.2)
	_key(KEY_RIGHT, false)
	level.player.speed_boost_timer = 0.2
	await _frames(15)
	_check("Rewards: the speed boost wears off", level.player.speed_boost_timer == 0.0 and level.boost_label.text == "")
	level.give_reward("dash")
	await _frames(2)
	_check("Rewards: quick dash shows in the HUD", level.boost_label.text.begins_with("QUICK DASH"))
	level.player.dash_boost_timer = 0.0

	# Shield: blocks one enemy hit, not spikes (so power-unlocking deaths still work)
	await _fresh(Vector2(300, 368))
	level.give_reward("shield")
	await _frames(2)
	level.enemy_hit_player()
	await _frames(5)
	_check("Shield: blocks one enemy hit", level.lives == 5 and not level.player.has_shield)
	level.enemy_hit_player()
	await _frames(5)
	_check("Shield: the next hit costs a life", level.lives == 4)
	await _after_death()
	level.give_reward("shield")
	level._on_spikes_body_entered(level.player)
	await _frames(5)
	_check("Shield: spikes ignore it (unlock deaths still work)", level.lives == 3 and level.player.has_shield)


func _test_warden_and_portal() -> void:
	await _fresh(Vector2(7096, 367))
	var warden = level.get_node("Warden")
	level.player.global_position = Vector2(warden.global_position.x - 70, 367)
	await _frames(120)
	_check("Warden: touching its side costs a life", level.deaths == 1)

	# Charge: it flashes red, then rushes at you. Standing still costs a life...
	await _fresh(Vector2(7096, 367))
	warden = level.get_node("Warden")
	level.player.global_position = Vector2(warden.global_position.x - 150, 367)
	warden.charge_timer = 0.01
	await _frames(100)
	_check("Warden: its charge hits you if you stand still", level.deaths == 1)

	# ...jumping over it as it arrives is safe
	await _fresh(Vector2(7096, 367))
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
	_check("Warden: after a stomp it leaps away, so you can't keep bouncing on it", abs(warden_now().global_position.x - 7456) > 150)
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
	var side = 1 if wx < 7456 else -1  # it leapt to one end of the arena: dodge on the open side
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
	await _fresh(Vector2(7096, 367))
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
	await _fresh(Vector2(7096, 367))
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
	_check("NPC: all 8 NPCs are there, and every one has real lines (not 'Hello')",
		level.get_node("Npcs").get_child_count() == 8 and not level.has_node("Signs") and all_talk)


# Lessons: powers unlock where their NPC teaches them, and lives top up at each teacher
func _test_lessons() -> void:
	await _fresh(Vector2(1000, 367))  # spike garden, before Sable
	level._lose_life()
	await _after_death()
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
	await _after_death()
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
	_check("Menu: Start Game fades into the intro cutscene", current_scene != null and current_scene.scene_file_path == "res://intro_cutscene.tscn")
	var sfx = root.get_node("Sfx")
	_check("Intro: its own music plays", sfx.music_target == current_scene.CALM_MUSIC)
	await _tap(KEY_SPACE)
	await create_timer(1.0).timeout
	_check("Intro: Space skips straight to Level 1", current_scene != null and current_scene.scene_file_path == "res://level_1.tscn")
	await create_timer(2.5).timeout
	_check("Intro: Level 1 switches back to the level music", sfx.music_target == sfx.MUSIC)

	# Watched to the end (time jumped forward), it also starts Level 1, and a death doesn't replay it
	change_scene_to_file("res://intro_cutscene.tscn")
	await create_timer(0.3).timeout
	current_scene.t = 39.5
	await create_timer(1.6).timeout
	_check("Intro: when it ends, Level 1 starts", current_scene != null and current_scene.scene_file_path == "res://level_1.tscn")
	level = current_scene
	level._lose_life()
	await _after_death()
	await _frames(5)
	_check("Intro: dying in Level 1 does not replay the intro", current_scene == level and level.lives == level.MAX_LIVES - 1)


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
	await _fresh(Vector2(7096, 367))
	var warden = warden_now()
	warden.speed = 0.0
	warden.charge_timer = 99.0
	level.player.global_position = warden.global_position + Vector2(0, -70)
	level.player.velocity = Vector2.ZERO
	await _frames(40)


func warden_now() -> Node2D:
	return level.get_node("Warden")


# A new copy of the level with the player at start. The enemies placed around the level
# are removed (unless keep_enemies) so movement checks only test the level's shape;
# the enemies have their own checks.
func _fresh(start: Vector2, keep_enemies := false) -> void:
	_release_all()
	var old = current_scene
	change_scene_to_file("res://level_1.tscn")
	while current_scene == null or current_scene == old:
		await process_frame
	level = current_scene
	if not keep_enemies:
		for node in level.get_node("Expansion").get_children():
			if node.is_in_group("enemies"):
				node.free()
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
		if stop_x != -1.0 and p.global_position.x >= stop_x:   # -1 = never stop
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
	await _after_death()


# Wait for the death animation and respawn to finish
func _after_death() -> void:
	for i in 120:
		if not level.respawning:
			return
		await physics_frame


func _landed_on(x_min: float, x_max: float, y_max: float) -> bool:
	var p = level.player.global_position
	return level.player.is_on_floor() and p.x > x_min and p.x < x_max and p.y < y_max


func _check(what: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1
		if is_instance_valid(level) and "player" in level:
			print("      player at ", level.player.global_position, "  deaths ", level.deaths)
