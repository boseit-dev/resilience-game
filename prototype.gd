extends "res://warden.gd"

# RESILIENCE - THE FAILED PROTOTYPE (Level 2 mini-boss)
# A broken lab robot. It walks, charges, gets stomped and calls down strikes like the
# Hollow Warden (warden.gd does all of that), and adds:
#   - ELECTRIC BOLTS along the floor. It glows cyan for half a second first: jump over them.
#   - Three phases, by hearts left:
#       1 ACTIVATION      8-6 hearts
#       2 SYSTEM FAILURE  5-3 hearts: faster, more strikes, the arena's beams switch on, faster music
#       3 OVERLOAD        2-1 hearts: its core flashes, bolts come in pairs, music faster still
# No Soul Strike challenge here: every heart has to be stomped.

const BOLT = preload("res://enemies/arrow.gd")
const BOLT_SPEED = 230.0
const BOLT_WARN = 0.5
const BOLT_EVERY = [0.0, 3.0, 2.4, 1.9]       # seconds between bolts, by phase
const MUSIC_PITCH = [1.0, 1.0, 1.1, 1.2]       # the boss music speeds up each phase
const VICTORY_MUSIC = preload("res://assets/music/victory_theme.ogg")
const LOOK = Color(0.75, 0.95, 1.3)             # cold metal
const ROBOT = "res://assets/kenney_pixel-platformer/Tiles/Characters/tile_%04d.png"

var phase = 1
var bolt_timer = 2.0


func _ready() -> void:
	super._ready()
	# A big Kenney robot instead of the Warden's sprite
	var frames = SpriteFrames.new()
	for n in [21, 22]:
		frames.add_frame("default", load(ROBOT % n))
	frames.set_animation_speed("default", 4.0)
	art.sprite_frames = frames
	art.play("default")
	art.scale = Vector2(2.2, 2.2)
	art.position = Vector2(0, -26)
	modulate = LOOK
	$Glow.color = Color("#7FE7FF")


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not awake or health <= 0:
		return
	if phase == 3:   # overload: the core flickers
		$Glow.energy = 0.7 + 0.6 * absf(sin(Time.get_ticks_msec() / 90.0))
	bolt_timer -= delta
	if bolt_timer <= 0.0 and safe_timer <= 0.0 and attack_timer <= 0.0 and not charging and warn_timer <= 0.0:
		bolt_timer = BOLT_EVERY[phase]
		_warn_and_shoot()


# Glow cyan, then fire one bolt (two in phase 3) along the floor towards the player
func _warn_and_shoot() -> void:
	modulate = Color(0.6, 1.8, 2.0)
	var steps = create_tween()
	steps.tween_interval(BOLT_WARN)
	steps.tween_callback(_shoot_bolt)
	if phase == 3:
		steps.tween_interval(0.45)
		steps.tween_callback(_shoot_bolt)
	steps.tween_callback(func(): modulate = LOOK)


func _shoot_bolt() -> void:
	var player = get_node_or_null("../Player")
	if player == null or health <= 0:
		return
	var bolt = BOLT.new()
	bolt.velocity = Vector2(BOLT_SPEED * signf(player.global_position.x - global_position.x), 0)
	bolt.position = Vector2(global_position.x, floor_y - 8)
	bolt.modulate = Color(0.6, 1.8, 2.2)   # an electric spark, not an arrow
	bolt.scale = Vector2(1.6, 1.6)
	get_parent().add_child(bolt)
	Sfx.play("armour_hit", 1.8)


func _take_hit(player: Node2D) -> void:
	super._take_hit(player)
	var new_phase = 1 if health > 5 else (2 if health > 2 else 3)
	if new_phase == phase or health <= 0:
		return
	phase = new_phase
	speed += 30.0
	Sfx.music.pitch_scale = MUSIC_PITCH[phase]
	get_tree().current_scene._show_banner("PROTOTYPE:  " + ["", "", "SYSTEM FAILURE", "OVERLOAD"][phase])
	if phase == 2:
		get_tree().call_group("boss_zapper", "set", "active", true)


func _is_angry() -> bool:
	return phase >= 2   # more strikes and faster charges from System Failure on


func _start_special(_player: Node2D) -> void:
	pass   # no Soul Strike challenge for this boss


func _die() -> void:
	super._die()
	get_tree().call_group("boss_zapper", "set", "active", false)
	Sfx.play_music(VICTORY_MUSIC)
