extends "res://intro_cutscene.gd"

# RESILIENCE - THE ENDING (about 55 seconds, then the credits). Plays after the gateway in Level 3.
# The intro run backwards: the restored gateway in The Between, the tunnel of stars, then home in
# the lab. It reuses the intro's lab, tunnel and helpers (intro_cutscene.gd); this file only adds
# the gateway scene, the credits and its own BEATS.
# SPACE / ENTER skips to the credits; in the credits it goes back to the menu.
# The story is saved as finished BEFORE this scene starts (the portal does it), so skipping is safe.

const ENDING_MUSIC = preload("res://assets/music/intro_theme.wav")
const CREDITS_MUSIC = preload("res://assets/music/victory_theme.ogg")
const QUOTE = "I built a machine to discover new worlds.\nI never imagined how much I'd fight to return to mine."
const CREDITS = """RESILIENCE


A GAME BY
Aarush  ·  Gene


DESIGN, CODE AND STORY
Aarush and Gene
Made for the Haven Sydney hackathon (Hack Club)


ART
Deep Night tiles and characters by VEXED (v3x3d.itch.io), CC0
Pixel Platformer by Kenney (kenney.nl), CC0
Cinzel font by Natanael Gama, SIL Open Font License


MUSIC
Retro Game Music Pack and Chiptune Adventures
by Juhani Junkala (SubspaceAudio), CC0


SOUND
Interface and Sci-Fi Sounds by Kenney (kenney.nl), CC0
Swishes Sound Pack by artisticdude (OpenGameArt), CC0


TOOLS
Godot Engine 4


AI ASSISTANCE
Parts of the code were written with help from Claude (Anthropic),
as allowed by the Haven organisers and disclosed in our submission.


THANK YOU FOR PLAYING"""

var gateway: Node2D
var walker: Sprite2D
var gate_ring: Line2D
var gate_light: PointLight2D
var gate_core: Sprite2D
var energy: CPUParticles2D
var credits_layer: CanvasLayer
var credits: Label
var in_credits = false


func _ready() -> void:
	beats = [
		[0.0, "gateway"], [1.0, "walk"], [5.0, "look_back"], [8.5, "gate_wakes"], [13.0, "run"],
		[15.0, "flash"], [15.4, "tunnel"], [19.0, "colours"], [23.5, "home"], [27.0, "stand"],
		[30.0, "look_around"], [33.5, "power_down"], [37.0, "quote"], [44.0, "silence"],
		[47.0, "switch_off"], [50.0, "lights_out"], [54.0, "credits"], [58.0, "roll"], [92.0, "end"],
	]
	next_scene = "res://main_menu.tscn"
	load("res://null_architect.gd").beaten_this_run = false
	super._ready()
	_build_gateway()
	lab.visible = false
	scientist.visible = false
	title.text = "RESILIENCE"
	subtitle.text = "Every fall was another way forward."
	_build_credits()


# ---------- the restored gateway, deep in The Between ----------

func _build_gateway() -> void:
	gateway = Node2D.new()
	add_child(gateway)
	move_child(gateway, lab.get_index())
	_rect(gateway, Vector2(-240, -140), Vector2(480, 280), Color("#120A20"))
	var rng = RandomNumberGenerator.new()
	rng.seed = 3
	for i in 9:   # jagged cave crystals around the edges
		var crystal = Polygon2D.new()
		var x = rng.randf_range(-220, 220)
		var h = rng.randf_range(20, 60)
		crystal.polygon = PackedVector2Array([Vector2(-6, 0), Vector2(0, -h), Vector2(6, 0)])
		crystal.position = Vector2(x, FLOOR_Y)
		crystal.color = [Color("#6A4AB0"), Color("#3E7FA8"), Color("#8A3E9A")][i % 3]
		gateway.add_child(crystal)
	_rect(gateway, Vector2(-240, FLOOR_Y), Vector2(480, 90), Color("#1E1430"))
	gate_ring = _circle(gateway, 34.0, 3.0, RIFT)
	gate_ring.position = Vector2(110, FLOOR_Y - 36)
	gate_ring.material = _additive()
	gate_ring.modulate.a = 0.3
	gate_core = Sprite2D.new()
	gate_core.texture = _soft_dot()
	gate_core.position = gate_ring.position
	gate_core.scale = Vector2(0.1, 0.1)
	gate_core.material = _additive()
	gateway.add_child(gate_core)
	gate_light = _light(gateway, gate_ring.position, RIFT, 0.4, 2.0)
	energy = _particles(gateway, Vector2(110, FLOOR_Y), 60, 1.6, Color("#C9A8FF"))
	energy.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	energy.emission_rect_extents = Vector2(40, 2)
	energy.direction = Vector2(0, -1)
	energy.spread = 15.0
	energy.gravity = Vector2(0, -40)
	energy.initial_velocity_min = 20.0
	energy.initial_velocity_max = 50.0
	energy.emitting = false
	var falling = _particles(gateway, Vector2(0, -150), 40, 2.5, Color("#9C8CB8"))   # the world collapsing
	falling.material = null
	falling.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	falling.emission_rect_extents = Vector2(240, 4)
	falling.direction = Vector2(0, 1)
	falling.gravity = Vector2(0, 160)
	falling.scale_amount_min = 1.5
	falling.scale_amount_max = 3.0
	walker = Sprite2D.new()
	walker.texture = WALK[0]
	walker.position = Vector2(-200, FLOOR_Y - 12)
	walker.flip_h = true   # the sprite is drawn facing left
	gateway.add_child(walker)
	_light(gateway, Vector2(-120, -40), Color("#6A4AB0"), 0.6, 3.0)


# ---------- the credits ----------

func _build_credits() -> void:
	credits_layer = CanvasLayer.new()
	credits_layer.layer = 5
	credits_layer.visible = false
	add_child(credits_layer)
	var black = ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	credits_layer.add_child(black)
	title.reparent(credits_layer)
	subtitle.reparent(credits_layer)
	credits = _label(credits_layer, CREDITS, 18, TEXT)
	credits.add_theme_constant_override("line_spacing", 6)
	credits.position.y = 760
	credits.modulate.a = 0.0
	var skip = _label(credits_layer, "SPACE / ENTER   MAIN MENU", 11, Color(0.84, 0.9, 1, 0.5))
	skip.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	skip.anchor_top = 0.95
	skip.anchor_bottom = 0.95
	skip.offset_right = -28


# ---------- every frame ----------

func _process(delta: float) -> void:
	super._process(delta)
	match mode:
		"walk":
			walker.position.x = move_toward(walker.position.x, 40.0, 40.0 * delta)
			walker.texture = WALK[int(t / 0.15) % 2] if walker.position.x < 40.0 else WALK[0]
			shake = maxf(shake, 0.6)
		"waking":
			gate_ring.modulate.a = minf(1.0, gate_ring.modulate.a + delta * 0.25)
			gate_core.scale = gate_core.scale.move_toward(Vector2(0.5, 0.5), delta * 0.12)
			gate_light.energy = minf(2.2, gate_light.energy + delta * 0.4)
			gate_ring.rotation += delta
			shake = maxf(shake, 1.0)
		"run":
			walker.position = walker.position.move_toward(gate_ring.position, 110.0 * delta)
			walker.texture = WALK[int(t / 0.08) % 2]
			walker.scale = walker.scale.move_toward(Vector2(0.4, 0.4), delta * 0.5)
		"fallen":
			pass
		"to_lever":
			var going = scientist.position.x > -86.0
			scientist.position.x = move_toward(scientist.position.x, -86.0, 30.0 * delta)
			scientist.texture = WALK[int(t / 0.15) % 2] if going else WALK[0]
	if in_credits:
		credits.position.y -= 60.0 * delta   # about 35 seconds to roll past


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event.pressed and not event.echo and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE]):
		return
	get_viewport().set_input_as_handled()
	if credits_layer.visible:
		_finish()   # back to the main menu
	else:
		_skip_to_credits()


func _skip_to_credits() -> void:
	t = 54.0
	next_beat = beats.find(beats.filter(func(b): return b[1] == "credits")[0])


# ---------- beats ----------

func _run_beat(beat: String) -> void:
	match beat:
		"gateway":
			Sfx.play_music(ENDING_MUSIC)
			_fade_from_black(1.5)
		"walk":
			mode = "walk"
		"look_back":
			mode = "look"
			walker.texture = WALK[0]
			walker.flip_h = false   # turns to look back at the collapsing world
			_caption("Everything I survived was falling apart behind me.")
		"gate_wakes":
			mode = "waking"
			walker.flip_h = true
			energy.emitting = true
			Sfx.play("energy")
			_caption("The gateway was waking up.")
		"run":
			mode = "run"
			_caption("")
			Sfx.play("whoosh")
		"flash":
			_flash(Color.WHITE, 0.8)
			Sfx.play("rift")
		"tunnel":
			gateway.visible = false
			tunnel.visible = true
			shake = 0.0
			darkness.color = Color(0.85, 0.85, 1.0)
		"colours":
			Sfx.play("whoosh")
			create_tween().tween_property(darkness, "color", Color(1.0, 0.8, 0.7), 3.0)
		"home":
			tunnel.visible = false
			lab.visible = true
			darkness.color = Color(0.34, 0.37, 0.5)
			_flash(Color.WHITE, 1.0)
			Sfx.play("thud")
			shake = 4.0
			charge = 1.0
			ring_glow.modulate.a = 1.0
			core.scale = Vector2(0.3, 0.3)
			ring_light.energy = 1.6
			scientist.visible = true
			scientist.position = Vector2(RING_CENTER.x - 34, FLOOR_Y - 6)
			scientist.rotation = PI / 2.0   # lying on the floor
			mode = "fallen"
		"stand":
			var up = create_tween()
			up.tween_property(scientist, "rotation", 0.0, 1.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			up.parallel().tween_property(scientist, "position:y", FLOOR_Y - 12.0, 1.2)
		"look_around":
			_caption("The lab. My lab.")
			var look = create_tween()
			look.tween_callback(func(): scientist.flip_h = true)
			look.tween_interval(0.9)
			look.tween_callback(func(): scientist.flip_h = false)
			look.tween_interval(0.9)
			look.tween_callback(func(): scientist.flip_h = true)
		"power_down":
			_caption("I was home.")
			Sfx.play("energy", 0.5)
			var off = create_tween()
			off.tween_property(ring_glow, "modulate:a", 0.0, 3.0)
			off.parallel().tween_property(core, "scale", Vector2.ZERO, 3.0)
			off.parallel().tween_property(ring_light, "energy", 0.0, 3.0)
			screens_color = Color("#2A3A4A")
		"quote":
			_caption(QUOTE)
		"silence":
			Sfx.fade_out_music(2.5)
			_caption("")
		"switch_off":
			mode = "to_lever"
			scientist.flip_h = false
			get_tree().create_timer(2.0).timeout.connect(func():
				lever.texture = LEVER_OFF
				Sfx.play("switch"))
		"lights_out":
			mode = "dark"
			create_tween().tween_property(darkness, "color", Color.BLACK, 3.5)
		"credits":
			mode = "credits"
			credits_layer.visible = true
			Sfx.play_music(CREDITS_MUSIC)
			title.modulate.a = 0.0
			subtitle.modulate.a = 0.0
			var show = create_tween()
			show.tween_property(title, "modulate:a", 1.0, 1.5)
			show.tween_property(subtitle, "modulate:a", 1.0, 1.0)
		"roll":
			var hide_title = create_tween()
			hide_title.tween_property(title, "modulate:a", 0.0, 1.0)
			hide_title.parallel().tween_property(subtitle, "modulate:a", 0.0, 1.0)
			hide_title.tween_property(credits, "modulate:a", 1.0, 0.5)
			in_credits = true
		"end":
			_finish()
