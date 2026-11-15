extends "res://warden.gd"

# RESILIENCE - THE NULL ARCHITECT (the final boss, Level 3)
# The guardian of The Between's core. It walks, charges, gets stomped and calls down strikes
# like the Hollow Warden (warden.gd does all of that). On top of that:
#   It rises out of the core when you walk in (slow rumble, then a roar).
#   PHASE 1  THE GUARDIAN AWAKENS  12-8 hearts: ground slams with shockwaves (jump them),
#            energy bolts aimed at you (a cyan glow first), charges.
#   PHASE 2  REALITY FRACTURES      7-4 hearts (about 60%): the arena turns red, floating platforms
#            start moving, energy beams switch on, debris falls, it TELEPORTS short distances,
#            two rings of shockwaves per slam.
#   PHASE 3  THE FINAL STAND        3-2 hearts (about 25%): huge shockwaves, dimensional rifts open
#            under you (they flicker first), bolts in threes, the fastest attacks.
#   FINAL ATTACK (1 heart): it rises to the top of the arena and opens its core. Climb to it:
#            Bounce Pad + Double Jump up the first ledge, Double Jump over the energy beam,
#            Dash under the low rock, then stomp the core.

@export var core_spot = Vector2(14500, 150)    # where it floats for the final attack

const BOLT = preload("res://enemies/arrow.gd")
const ZAPPER = preload("res://zapper.gd")
const ROCKS = preload("res://rock_trap.gd")
const LOOK = Color(0.7, 0.62, 1.05)
const WARN = Color(1.6, 0.8, 2.2)                  # violet: a slam is coming
const AIM = Color(0.7, 1.7, 2.3)                   # cyan: bolts are coming
const PHASE_AT = [99, 12, 7, 3]                    # hearts left when each phase starts
const SLAM_EVERY = [0.0, 4.0, 3.2, 2.6]
const BOLT_EVERY = [0.0, 3.4, 2.8, 2.2]
const DEBRIS_EVERY = [0.0, 0.0, 2.4, 1.8]
const TELEPORT_EVERY = 5.0
const RIFT_EVERY = 3.0
const WAVE_SPEED = [0.0, 210.0, 250.0, 280.0]
const WAVE_HEIGHT = [0.0, 3.0, 3.0, 7.0]           # phase 3: big waves (still one jump high)
const MUSIC = [null, preload("res://assets/music/architect_theme.ogg"), preload("res://assets/music/boss_theme.ogg"),
	preload("res://assets/music/caverns_danger.ogg"), preload("res://assets/music/architect_theme.ogg")]
const MUSIC_PITCH = [1.0, 1.0, 1.05, 1.2, 1.3]    # index 4 = the final attack

static var beaten_this_run = false   # Game Over during the escape must not bring it back

var phase = 1
var finale = false
var emerge_timer = 0.0
var slam_timer = 3.0
var bolt_timer = 2.0
var debris_timer = 2.0
var teleport_timer = TELEPORT_EVERY
var rift_timer = RIFT_EVERY
var busy = false
var core: Polygon2D
var rings: Array[Line2D] = []


func _ready() -> void:
	super._ready()
	art.scale = Vector2(8, 8)
	art.position = Vector2(0, -32)
	modulate = LOOK
	$Glow.color = Color("#9A6CFF")
	$Glow.texture_scale *= 2.0
	var box = $Hitbox/CollisionShape2D
	box.shape = box.shape.duplicate()
	box.shape.size = Vector2(50, 46)
	box.position = Vector2(0, -23)
	hearts.position.y = -86
	for i in 2:   # two halo rings that spin around it
		var ring = Line2D.new()
		ring.width = 1.5
		ring.closed = true
		ring.default_color = Color(1.4, 0.9, 2.2, 0.8)
		for k in 32:
			ring.add_point(Vector2(cos(k * TAU / 32.0) * (44 + i * 10), sin(k * TAU / 32.0) * (12 + i * 4)))
		ring.position = Vector2(0, -36)
		add_child(ring)
		rings.append(ring)
	core = Polygon2D.new()   # the dimensional core: shows from phase 3, opens in the final attack
	core.polygon = PackedVector2Array([Vector2(0, -9), Vector2(7, 0), Vector2(0, 9), Vector2(-7, 0)])
	core.color = Color(1.0, 0.6, 1.4)
	core.position = Vector2(0, -34)
	core.hide()
	add_child(core)
	art.hide()     # deep in the core until you walk in
	hearts.hide()
	for r in rings:
		r.hide()


func _physics_process(delta: float) -> void:
	for i in rings.size():
		rings[i].rotation = sin(Time.get_ticks_msec() / (700.0 + i * 300.0)) * 0.3
	if finale:   # it floats at the top of the arena, waiting for the final stomp
		core.scale = Vector2.ONE * (1.3 + 0.3 * sin(Time.get_ticks_msec() / 90.0))
		var player = get_node_or_null("../Player")
		if player and $Hitbox.overlaps_body(player):   # checked every frame: you may jump up through it first
			_on_hitbox_body_entered(player)
		return
	if emerge_timer > 0.0:
		emerge_timer -= delta
		return
	var was_awake = awake
	super._physics_process(delta)
	if not awake:
		return
	if not was_awake:
		_emerge()
		return
	if health <= 0 or busy or safe_timer > 0.0 or attack_timer > 0.0 or charging or warn_timer > 0.0:
		return
	slam_timer -= delta
	bolt_timer -= delta
	debris_timer -= delta
	teleport_timer -= delta
	rift_timer -= delta
	if slam_timer <= 0.0:
		slam_timer = SLAM_EVERY[phase]
		_slam()
	elif bolt_timer <= 0.0:
		bolt_timer = BOLT_EVERY[phase]
		_bolts()
	elif phase >= 2 and teleport_timer <= 0.0:
		teleport_timer = TELEPORT_EVERY
		_teleport()
	if phase >= 2 and debris_timer <= 0.0:
		debris_timer = DEBRIS_EVERY[phase]
		_debris()
	if phase == 3 and rift_timer <= 0.0:
		rift_timer = RIFT_EVERY
		_rift()


# It rises out of the floor: the ground shakes, then it roars and the music starts
func _emerge() -> void:
	emerge_timer = 2.6
	Sfx.fade_out_music(0.8)
	art.show()
	art.position.y = 40.0
	art.modulate.a = 0.0
	var rise = create_tween()
	rise.tween_callback(_shake.bind(4.0, 16))
	rise.tween_interval(0.9)
	rise.tween_callback(func(): Sfx.play("warden_die", 0.5))
	rise.tween_property(art, "position:y", -32.0, 1.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	rise.parallel().tween_property(art, "modulate:a", 1.0, 0.5)
	rise.tween_callback(func():
		$Burst.emitting = true
		hearts.show()
		for r in rings:
			r.show()
		_music(1)
		_banner("THE NULL ARCHITECT"))


# Rear up glowing violet, slam, shockwaves run both ways along the floor
func _slam() -> void:
	busy = true
	modulate = WARN
	var steps = create_tween()
	steps.tween_property(art, "position:y", -54.0, 0.55).set_trans(Tween.TRANS_SINE)
	steps.tween_property(art, "position:y", -32.0, 0.12)
	steps.tween_callback(func():
		modulate = LOOK
		busy = false
		Sfx.play("slam", 0.7)
		_shake(5.0, 5)
		_waves()
		if phase >= 2:
			get_tree().create_timer(0.5).timeout.connect(_waves))


func _waves() -> void:
	if health <= 0 or finale:
		return
	for side in [-1, 1]:
		var wave = BOLT.new()
		wave.velocity = Vector2(WAVE_SPEED[phase] * side, 0)
		wave.position = Vector2(global_position.x + side * 34.0, floor_y - 2.0 - WAVE_HEIGHT[phase] * 1.5)
		wave.modulate = WARN
		wave.scale = Vector2(2.4, WAVE_HEIGHT[phase])
		get_parent().add_child(wave)


# Glow cyan, then energy bolts fly at the player (one, two in phase 2, a fan of three in phase 3)
func _bolts() -> void:
	busy = true
	modulate = AIM
	var steps = create_tween()
	steps.tween_interval(0.5)
	steps.tween_callback(func():
		modulate = LOOK
		busy = false
		var player = get_node_or_null("../Player")
		if player == null or health <= 0 or finale:
			return
		var from = global_position + Vector2(0, -40)
		var aim = (player.global_position - from).normalized()
		for angle in [[0.0], [-0.1, 0.1], [-0.2, 0.0, 0.2]][phase - 1]:
			var bolt = BOLT.new()
			bolt.velocity = aim.rotated(angle) * 250.0
			bolt.position = from
			bolt.modulate = AIM
			bolt.scale = Vector2(1.6, 1.6)
			get_parent().add_child(bolt)
		Sfx.play("special_bolt", 1.6))


# Blink out and back in a short way off (it flashes while it moves, and can't hurt you)
func _teleport() -> void:
	var player = get_node_or_null("../Player")
	if player == null:
		return
	var side = 1.0 if randf() < 0.5 else -1.0
	var x = clampf(player.global_position.x + side * 170.0, start_x - patrol_distance, start_x + patrol_distance)
	safe_timer = 0.5
	Sfx.play("dash", 0.6)
	position.x = x


func _debris() -> void:
	var player = get_node_or_null("../Player")
	if player:
		ROCKS.drop(get_parent(), player.global_position.x + randf_range(-60.0, 60.0), floor_y, 0.8, 1.0 if phase < 3 else 1.5, Color(0.6, 0.5, 0.8))


# Phase 3: a rift tears open under the player: it flickers, then a beam fills it for a moment
func _rift() -> void:
	var player = get_node_or_null("../Player")
	if player == null:
		return
	var rift = ZAPPER.new()
	rift.level = get_tree().current_scene
	rift.position = Vector2(player.global_position.x, floor_y - 200.0)
	rift.length = 200.0
	rift.off_time = 0.8   # the last 0.5 s of this flickers as the warning
	rift.on_time = 0.7
	get_parent().add_child(rift)
	get_tree().create_timer(1.5).timeout.connect(rift.queue_free)


# Stomps. In the final attack only the core counts, and touching its side is harmless.
func _on_hitbox_body_entered(body: Node2D) -> void:
	if body.name != "Player" or safe_timer > 0.0 or emerge_timer > 0.0 or health <= 0:
		return
	var from_above = body.velocity.y > 0.0 and body.global_position.y < global_position.y - 32.0
	if finale:
		if from_above:
			finale = false
			body.velocity.y = STOMP_BOUNCE
			special_hit()   # the final blow (warden.gd: takes the last heart and dies)
		return
	if from_above:
		_take_hit(body)
	else:
		touched_player.emit(body)


func _take_hit(player: Node2D) -> void:
	super._take_hit(player)
	$Burst.emitting = true
	if health <= 0:
		return
	if health == 1:
		_start_finale(player)
		return
	var new_phase = 1 if health > PHASE_AT[2] else (2 if health > PHASE_AT[3] else 3)
	if new_phase == phase:
		return
	phase = new_phase
	speed += 30.0
	Sfx.play("special_shatter")
	_shake(8.0, 8)
	_music(phase)
	_banner(["", "", "REALITY FRACTURES", "THE FINAL STAND"][phase])
	var level = get_tree().current_scene
	if phase == 2:   # the arena changes: red light, moving platforms, energy beams
		modulate = LOOK
		level.get_node("Mood/Darkness").color = Color(0.75, 0.35, 0.55)
		get_tree().call_group("boss_mover", "open")
		get_tree().call_group("boss_zapper", "set", "active", true)
	else:
		level.get_node("Mood/Darkness").color = Color(0.85, 0.3, 0.4)
		core.show()


# The last heart: it floats up and opens its core. The player has to climb to it.
func _start_finale(player: Node2D) -> void:
	finale = true
	attack_timer = 0.0
	player.jump_locked_timer = 0.0   # the climb needs every jump
	get_tree().call_group("warden_strike", "queue_free")
	get_tree().call_group("arrows", "queue_free")
	get_tree().call_group("boss_zapper", "set", "active", false)
	get_tree().call_group("finale_zapper", "set", "active", true)
	var level = get_tree().current_scene
	level.pads_remaining = maxi(level.pads_remaining, 1)   # the climb needs a Bounce Pad
	level._update_hud()
	_music(4)
	_banner("ITS CORE IS OPEN  ·  CLIMB TO IT")
	core.show()
	core.color = Color(2.4, 2.2, 2.8)
	var rise = create_tween()
	rise.tween_interval(0.5)   # after its leap away (warden.gd) has finished
	rise.tween_property(self, "position", core_spot, 1.6).set_trans(Tween.TRANS_SINE)


func _is_angry() -> bool:
	return phase >= 2


func _start_special(_player: Node2D) -> void:
	pass   # no Soul Strike challenge: the final attack is a climb instead


# The final blow: slow motion, a white flash, the core shatters
func _die() -> void:
	beaten_this_run = true
	core.hide()
	for r in rings:
		r.hide()
	super._die()
	get_tree().call_group("finale_zapper", "set", "active", false)
	get_tree().call_group("falling_rock", "queue_free")
	get_tree().call_group("arrows", "queue_free")
	_shake(10.0, 10)
	Sfx.play("special_shatter", 0.6)
	Engine.time_scale = 0.3
	get_tree().create_timer(0.7, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)
	_banner("THE NULL ARCHITECT FALLS")


func _music(index: int) -> void:
	Sfx.play_music(MUSIC[index])
	Sfx.music.pitch_scale = MUSIC_PITCH[index]


func _banner(text: String) -> void:
	get_tree().current_scene._show_banner(text)


func _shake(strength: float, steps: int) -> void:
	var camera = get_node_or_null("../Player/Camera2D")
	if camera == null:
		return
	var shake = create_tween()
	for i in steps:
		shake.tween_property(camera, "offset", Vector2(randf_range(-strength, strength), randf_range(-strength, strength) * 0.7), 0.05)
	shake.tween_property(camera, "offset", Vector2.ZERO, 0.05)
