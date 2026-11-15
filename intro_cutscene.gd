extends Node2D

# RESILIENCE - INTRO CUTSCENE (about 40 seconds, plays after START on the main menu)
# A scientist turns on the Galaxy Gate, it malfunctions, opens a rift and pulls them
# through a tunnel of stars into The Between. Then Level 1 starts.
# SPACE, ENTER or ESC skips it. It never plays again after a death (deaths respawn you,
# and Game Over reloads only the level).
#
# How it works: everything is built in code in _ready() (lab, tunnel, arrival).
# The BEATS table says what happens at which second; _run_beat() does it.
# _process() animates the things that move every frame (walking, screens, lights, swirl).
# Art: the game's own Deep-Night tiles and Kenney sprites, lit with 2D lights.

const NEXT_SCENE = "res://level_1.tscn"
const FONT = preload("res://assets/fonts/Cinzel.ttf")
const SHEET = preload("res://assets/Deep-Night/Tiles-and-Enemies.png")
const SHEET_CLEAR = preload("res://assets/Deep-Night/Tiles-and-Enemies-transparent.png")
const WALK = [
	preload("res://assets/kenney_pixel-platformer/Tiles/Characters/tile_0002.png"),
	preload("res://assets/kenney_pixel-platformer/Tiles/Characters/tile_0003.png"),
]
const LEVER_OFF = preload("res://assets/kenney_pixel-platformer/Tiles/tile_0064.png")
const LEVER_ON = preload("res://assets/kenney_pixel-platformer/Tiles/tile_0066.png")
# Music (CC0, Juhani Junkala, see assets/music/LICENSE.txt): calm in the lab, tense when it goes wrong
const CALM_MUSIC = preload("res://assets/music/intro_theme.wav")   # loops (set in its import settings)
const TENSE_MUSIC = preload("res://assets/music/boss_theme.ogg")
const GLOW = Color("#83D9FF")
const DANGER = Color("#FF4A5A")
const RIFT = Color("#B07CFF")
const TEXT = Color("#E8F5FF")
const FLOOR_Y = 50.0
const RING_CENTER = Vector2(70, -14)

# [second, beat name]. What each beat does is in _run_beat() below.
const BEATS = [
	[0.0, "lab"], [1.0, "walk_in"], [5.4, "tonight"], [7.2, "lever"],
	[8.0, "power_100"], [10.0, "power_140"], [12.0, "power_200"], [13.5, "malfunction"],
	[19.0, "rift_opens"], [22.5, "pulled_in"], [26.0, "fade_out"], [26.6, "tunnel"],
	[29.5, "whoosh"], [32.5, "arrival"], [34.4, "land"], [35.6, "title"], [40.0, "end"],
]

var beats = BEATS              # the ending (ending.gd) swaps in its own
var next_scene = NEXT_SCENE
var t = 0.0
var next_beat = 0
var mode = "idle"
var finished = false
var shake = 0.0
var screens_color = GLOW
var alarm_timer = 0.0
var charge = 0.0          # 0 = gate off, 1 = fully charged

var camera: Camera2D
var darkness: CanvasModulate
var lab: Node2D
var scientist: Sprite2D
var lever: Sprite2D
var screens: Array[ColorRect] = []
var screen_lines: Array[ColorRect] = []
var screen_light: PointLight2D
var ring_glow: Line2D
var ring_light: PointLight2D
var core: Sprite2D
var swirl: Node2D
var sparks: CPUParticles2D
var debris: CPUParticles2D
var beacons: Array[Node2D] = []
var tunnel: Node2D
var tunnel_rings: Array[Line2D] = []
var tumbler: Sprite2D
var arrival: Node2D
var faller: Sprite2D
var faller_light: PointLight2D
var dust: CPUParticles2D
var fade: ColorRect
var caption: Label
var title: Label
var subtitle: Label


func _ready() -> void:
	camera = Camera2D.new()
	camera.zoom = Vector2(3, 3)
	add_child(camera)
	darkness = CanvasModulate.new()
	darkness.color = Color(0.34, 0.37, 0.5)
	add_child(darkness)
	_build_lab()
	_build_tunnel()
	_build_arrival()
	_build_overlay()


# ---------- the laboratory ----------

func _build_lab() -> void:
	lab = Node2D.new()
	add_child(lab)

	# Stone walls and a frosty floor, made from the same Deep-Night tiles as the level
	_tiled(lab, Rect2(-240, -140, 480, 200), Rect2(104, 72, 24, 8), SHEET, Color(0.45, 0.5, 0.72))
	for x in [-200, -60, 180]:
		_rect(lab, Vector2(x, -140), Vector2(10, 190), Color("#0E111C"))    # dark support beams
		_rect(lab, Vector2(x + 1, -140), Vector2(2, 190), Color("#2A3350"))
	_tiled(lab, Rect2(-240, FLOOR_Y, 480, 90), Rect2(104, 72, 24, 8), SHEET, Color(0.32, 0.36, 0.52))
	_tiled(lab, Rect2(-240, FLOOR_Y - 2, 480, 8), Rect2(136, 56, 8, 8), SHEET_CLEAR, Color.WHITE)

	# A window onto the night sky
	_rect(lab, Vector2(-176, -92), Vector2(72, 50), Color("#2A3350"))
	_rect(lab, Vector2(-172, -88), Vector2(64, 42), Color("#070B1C"))
	var rng = RandomNumberGenerator.new()
	rng.seed = 11
	for i in 22:
		_rect(lab, Vector2(rng.randf_range(-171, -110), rng.randf_range(-87, -48)), Vector2.ONE, Color(0.85, 0.9, 1, rng.randf_range(0.4, 1)))
	var moon = Sprite2D.new()
	moon.texture = _region(SHEET_CLEAR, Rect2(24, 64, 16, 21))
	moon.position = Vector2(-124, -70)
	moon.scale = Vector2(0.7, 0.7)
	lab.add_child(moon)
	_rect(lab, Vector2(-141, -88), Vector2(2, 42), Color("#2A3350"))     # window bars
	_rect(lab, Vector2(-172, -68), Vector2(64, 2), Color("#2A3350"))

	# Ceiling lamps: a cord, a shade and a soft cone of light
	for x in [-130, -10, 150]:
		var cord = Line2D.new()
		cord.width = 1.0
		cord.default_color = Color("#1A1F30")
		cord.points = PackedVector2Array([Vector2(x, -140), Vector2(x, -104)])
		lab.add_child(cord)
		_rect(lab, Vector2(x - 6, -104), Vector2(12, 4), Color("#5B6478"))
		var cone = Polygon2D.new()
		cone.polygon = PackedVector2Array([Vector2(x - 5, -100), Vector2(x + 5, -100), Vector2(x + 34, FLOOR_Y), Vector2(x - 34, FLOOR_Y)])
		cone.color = Color(1, 0.92, 0.75, 0.05)
		cone.material = _additive()
		lab.add_child(cone)
		_light(lab, Vector2(x, -96), Color(1, 0.9, 0.7), 0.7, 1.4)

	# The console: a desk, two monitors with scrolling data, and the big lever
	_rect(lab, Vector2(-150, 24), Vector2(64, 26), Color("#232A40"))
	_rect(lab, Vector2(-150, 24), Vector2(64, 3), Color("#4A5370"))
	for i in 2:
		var x = -146 + i * 32
		_rect(lab, Vector2(x + 10, 12), Vector2(4, 12), Color("#1A1F30"))       # stand
		_rect(lab, Vector2(x, -10), Vector2(26, 22), Color("#3A4258"))         # frame
		var screen = _rect(lab, Vector2(x + 2, -8), Vector2(22, 18), GLOW)
		screens.append(screen)
		for k in 4:
			var line = _rect(lab, Vector2(x + 4, -6 + k * 4), Vector2(14, 1), Color(0.05, 0.08, 0.12, 0.8))
			screen_lines.append(line)
	screen_light = _light(lab, Vector2(-120, 0), GLOW, 0.8, 0.9)
	lever = Sprite2D.new()
	lever.texture = LEVER_OFF
	lever.position = Vector2(-92, 15)
	lab.add_child(lever)

	# Pipes running from the console to the gate
	for y_off in [0.0, 5.0]:
		var pipe = Line2D.new()
		pipe.width = 3.0
		pipe.default_color = Color("#2E3650")
		pipe.points = PackedVector2Array([Vector2(-86, 40 + y_off), Vector2(-40, 40 + y_off), Vector2(-30, 46 + y_off * 0.2), Vector2(40, 46 + y_off * 0.2)])
		lab.add_child(pipe)

	# The Galaxy Gate: a bolted metal ring on a pedestal
	var pedestal = Polygon2D.new()
	pedestal.polygon = PackedVector2Array([Vector2(40, FLOOR_Y), Vector2(100, FLOOR_Y), Vector2(88, 26), Vector2(52, 26)])
	pedestal.color = Color("#262C40")
	lab.add_child(pedestal)
	_rect(lab, Vector2(52, 26), Vector2(36, 3), Color("#4A5370"))
	var back = _circle(lab, 40.0, 14.0, Color("#1A1F30"))
	back.position = RING_CENTER
	var ring = _circle(lab, 40.0, 8.0, Color("#59627A"))
	ring.position = RING_CENTER
	var ring_edge = _circle(lab, 44.0, 1.0, Color("#8892AE"))
	ring_edge.position = RING_CENTER
	for k in 8:
		var bolt = _rect(lab, Vector2.ZERO, Vector2(4, 4), Color("#A5AEC8"))
		bolt.position = RING_CENTER + Vector2(cos(k * TAU / 8.0), sin(k * TAU / 8.0)) * 40.0 - Vector2(2, 2)
	ring_glow = _circle(lab, 36.0, 2.0, GLOW)
	ring_glow.position = RING_CENTER
	ring_glow.modulate.a = 0.0
	ring_glow.material = _additive()
	core = Sprite2D.new()
	core.texture = _soft_dot()
	core.position = RING_CENTER
	core.scale = Vector2.ZERO
	core.material = _additive()
	lab.add_child(core)
	ring_light = _light(lab, RING_CENTER, GLOW, 0.0, 2.2)

	# The rift: purple arcs spinning both ways inside the ring
	swirl = Node2D.new()
	swirl.position = RING_CENTER
	swirl.visible = false
	lab.add_child(swirl)
	for i in 6:
		var arc = Line2D.new()
		arc.width = 2.0 if i % 2 == 0 else 1.0
		arc.default_color = RIFT.lerp(Color.WHITE, i * 0.12)
		arc.material = _additive()
		var points = PackedVector2Array()
		for k in 14:
			var a = k * 0.32 + i * TAU / 6.0
			points.append(Vector2(cos(a), sin(a)) * (6.0 + i * 5.0 + k * 1.2))
		arc.points = points
		swirl.add_child(arc)

	# Red alarm beacons (they only switch on when things go wrong)
	for x in [-30, 190]:
		var beacon = Node2D.new()
		beacon.position = Vector2(x, -96)
		beacon.visible = false
		lab.add_child(beacon)
		_rect(beacon, Vector2(-4, -2), Vector2(8, 6), DANGER)
		var beam = Polygon2D.new()
		beam.name = "Beam"
		beam.polygon = PackedVector2Array([Vector2(0, 0), Vector2(120, -18), Vector2(120, 18)])
		beam.color = Color(1, 0.2, 0.25, 0.18)
		beam.material = _additive()
		beacon.add_child(beam)
		var red = _light(beacon, Vector2.ZERO, DANGER, 1.2, 2.0)
		red.name = "Light"
		beacons.append(beacon)

	sparks = _particles(lab, RING_CENTER, 50, 0.7, Color("#FFE08A"))
	sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	sparks.emission_sphere_radius = 40.0
	sparks.spread = 180.0
	sparks.initial_velocity_min = 50.0
	sparks.initial_velocity_max = 140.0
	sparks.gravity = Vector2(0, 260)
	sparks.emitting = false

	# Papers and dust pulled into the rift
	debris = _particles(lab, RING_CENTER, 40, 1.4, Color("#C9D3EA"))
	debris.material = null
	debris.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	debris.emission_rect_extents = Vector2(200, 80)
	debris.gravity = Vector2.ZERO
	debris.radial_accel_min = -260.0
	debris.radial_accel_max = -160.0
	debris.angular_velocity_min = -300.0
	debris.angular_velocity_max = 300.0
	debris.scale_amount_min = 1.0
	debris.scale_amount_max = 2.5
	debris.emitting = false

	scientist = Sprite2D.new()
	scientist.texture = WALK[0]
	scientist.position = Vector2(-230, FLOOR_Y - 12)
	lab.add_child(scientist)


# ---------- the tunnel of stars ----------

func _build_tunnel() -> void:
	tunnel = Node2D.new()
	tunnel.visible = false
	add_child(tunnel)
	_rect(tunnel, Vector2(-240, -140), Vector2(480, 280), Color("#05040A"))
	var nebula = Sprite2D.new()
	nebula.texture = _soft_dot()
	nebula.scale = Vector2(1.6, 1.0)
	nebula.modulate = Color(0.45, 0.25, 0.8, 0.5)
	nebula.material = _additive()
	tunnel.add_child(nebula)
	for i in 8:
		var ring = _circle(tunnel, 20.0, 1.0, [GLOW, RIFT][i % 2])
		ring.material = _additive()
		tunnel_rings.append(ring)
	for i in 2:
		var stars = _particles(tunnel, Vector2.ZERO, 180, 0.7, [Color("#BFD8FF"), RIFT][i])
		stars.texture = _streak()
		stars.particle_flag_align_y = true
		stars.preprocess = 1.0
		stars.spread = 180.0
		stars.gravity = Vector2.ZERO
		stars.initial_velocity_min = 60.0
		stars.initial_velocity_max = 260.0
		stars.radial_accel_min = 300.0
		stars.radial_accel_max = 600.0
		stars.scale_amount_min = 0.6
		stars.scale_amount_max = 1.4
	tumbler = Sprite2D.new()
	tumbler.texture = WALK[0]
	tunnel.add_child(tumbler)
	_light(tunnel, Vector2.ZERO, RIFT, 1.5, 2.5)


# ---------- arriving in The Between (looks like the start of Level 1) ----------

func _build_arrival() -> void:
	arrival = Node2D.new()
	arrival.visible = false
	add_child(arrival)
	_rect(arrival, Vector2(-240, -140), Vector2(480, 280), Color("#0B1024"))
	var rng = RandomNumberGenerator.new()
	rng.seed = 5
	for i in 70:
		_rect(arrival, Vector2(rng.randf_range(-220, 220), rng.randf_range(-130, 20)), Vector2.ONE, Color(0.85, 0.9, 1, rng.randf_range(0.3, 1)))
	var moon = Sprite2D.new()
	moon.texture = _region(SHEET_CLEAR, Rect2(24, 64, 16, 21))
	moon.position = Vector2(-140, -50)
	arrival.add_child(moon)
	for h in [["res://assets/backdrops/far_hills.png", 2.0, 55.0, Color(0.55, 0.6, 0.85)], ["res://assets/backdrops/near_hills.png", 2.5, 80.0, Color(0.7, 0.75, 1.0)]]:
		var hills = Sprite2D.new()
		hills.texture = load(h[0])
		hills.scale = Vector2(h[1], h[1])
		hills.position = Vector2(0, h[2])
		hills.modulate = h[3]
		arrival.add_child(hills)
	_tiled(arrival, Rect2(-240, FLOOR_Y, 480, 90), Rect2(104, 72, 24, 8), SHEET, Color.WHITE)
	_tiled(arrival, Rect2(-240, FLOOR_Y - 2, 480, 8), Rect2(136, 56, 8, 8), SHEET_CLEAR, Color.WHITE)
	_tiled(arrival, Rect2(-240, FLOOR_Y - 9, 480, 8), Rect2(160, 8, 32, 8), SHEET_CLEAR, Color.WHITE)   # grass tufts

	# The rift in the sky the scientist falls out of
	var rift = Node2D.new()
	rift.position = Vector2(0, -90)
	arrival.add_child(rift)
	var glow = Sprite2D.new()
	glow.texture = _soft_dot()
	glow.scale = Vector2(0.25, 0.6)
	glow.modulate = RIFT
	glow.material = _additive()
	rift.add_child(glow)
	var tear = _circle(rift, 10.0, 1.5, Color("#E2CCFF"))
	tear.scale = Vector2(0.45, 2.2)
	var motes = _particles(rift, Vector2.ZERO, 30, 1.6, Color("#E2CCFF"))
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = Vector2(4, 20)
	motes.spread = 180.0
	motes.initial_velocity_min = 5.0
	motes.initial_velocity_max = 20.0
	motes.gravity = Vector2.ZERO
	_light(rift, Vector2.ZERO, RIFT, 1.4, 2.0)

	faller = Sprite2D.new()
	faller.texture = WALK[0]
	faller.position = Vector2(0, -90)
	arrival.add_child(faller)
	faller_light = _light(arrival, faller.position, Color("#BFD8FF"), 0.9, 1.0)
	dust = _particles(arrival, Vector2(0, FLOOR_Y), 26, 0.8, Color("#BFD8FF"))
	dust.material = null
	dust.one_shot = true
	dust.explosiveness = 1.0
	dust.direction = Vector2(0, -1)
	dust.spread = 80.0
	dust.initial_velocity_min = 30.0
	dust.initial_velocity_max = 90.0
	dust.gravity = Vector2(0, 200)
	dust.scale_amount_min = 1.5
	dust.scale_amount_max = 2.5
	dust.emitting = false


# ---------- captions, title, black bars, fade ----------

func _build_overlay() -> void:
	var layer = CanvasLayer.new()
	add_child(layer)
	for top in [true, false]:   # cinematic black bars
		var bar = ColorRect.new()
		bar.color = Color.BLACK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.anchor_right = 1.0
		bar.anchor_top = 0.0 if top else 0.9
		bar.anchor_bottom = 0.1 if top else 1.0
		layer.add_child(bar)
	caption = _label(layer, "", 20, TEXT)
	caption.anchor_top = 0.8
	caption.anchor_bottom = 0.8
	title = _label(layer, "THE ARRIVAL", 56, TEXT)
	title.anchor_top = 0.3
	title.anchor_bottom = 0.3
	title.modulate.a = 0.0
	subtitle = _label(layer, "LEVEL 1   ·   SOMEWHERE BETWEEN WORLDS", 16, GLOW)
	subtitle.anchor_top = 0.43
	subtitle.anchor_bottom = 0.43
	subtitle.modulate.a = 0.0
	var skip = _label(layer, "SPACE / ENTER   SKIP", 11, Color(0.84, 0.9, 1, 0.5))
	skip.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	skip.anchor_top = 0.935
	skip.anchor_bottom = 0.935
	skip.offset_right = -28
	fade = ColorRect.new()
	fade.color = Color.BLACK
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(fade)


# ---------- every frame ----------

func _process(delta: float) -> void:
	t += delta
	while next_beat < beats.size() and t >= beats[next_beat][0]:
		_run_beat(beats[next_beat][1])
		next_beat += 1

	# Screens blink and their data lines scroll (fast and red once things go wrong)
	var speed = 8.0 if mode == "malfunction" else 2.0
	for i in screens.size():
		screens[i].color = screens_color if int(t * speed + i) % 4 != 0 else screens_color.darkened(0.5)
	for i in screen_lines.size():
		screen_lines[i].size.x = 4.0 + fposmod(t * 10.0 * speed + i * 5.3, 14.0)
	screen_light.color = screens_color

	match mode:
		"walk_in":
			var walking = scientist.position.x < -102.0
			scientist.position.x = move_toward(scientist.position.x, -102.0, 34.0 * delta)
			scientist.texture = WALK[int(t / 0.15) % 2] if walking else WALK[0]
		"charge":
			charge = minf(1.0, charge + delta * 0.18)
		"malfunction":
			screens_color = DANGER
			ring_glow.default_color = GLOW if randf() > 0.3 else RIFT
			core.modulate = Color.WHITE if randf() > 0.2 else RIFT
			darkness.color = Color(0.34, 0.37, 0.5) if randf() > 0.08 else Color(0.18, 0.18, 0.26)
			shake = maxf(shake, 1.5)
			alarm_timer -= delta
			if alarm_timer <= 0.0:
				alarm_timer = 0.7
				Sfx.play("alarm")
		"rift", "pulled":
			ring_glow.default_color = RIFT
			ring_light.color = RIFT
			ring_light.energy = 2.0 + sin(t * 10.0) * 0.4
			swirl.rotation += delta * (4.0 if mode == "rift" else 9.0)
			for i in swirl.get_child_count():
				swirl.get_child(i).rotation = t * (1.5 if i % 2 == 0 else -2.5)
			swirl.scale = swirl.scale.move_toward(Vector2(1.15, 1.15), delta * 0.4)
			core.modulate = RIFT
			core.scale = core.scale.move_toward(Vector2(0.45, 0.45), delta * 0.3)
			shake = maxf(shake, 1.0)
			if mode == "pulled":
				# sliding into the rift, spinning and shrinking
				scientist.position = scientist.position.move_toward(RING_CENTER, 40.0 * delta)
				scientist.rotation += delta * 9.0
				scientist.scale = scientist.scale.move_toward(Vector2(0.15, 0.15), delta * 0.28)
	if mode == "charge" or mode == "malfunction":
		ring_glow.modulate.a = charge
		core.scale = Vector2.ONE * charge * 0.3
		ring_light.energy = charge * 1.6
	for beacon in beacons:
		if beacon.visible:
			beacon.get_node("Beam").rotation = t * 5.0
			beacon.get_node("Light").energy = 0.8 + absf(sin(t * 5.0))

	if tunnel.visible:
		for i in tunnel_rings.size():
			var grow = fposmod(t * 0.9 + i / float(tunnel_rings.size()), 1.0)
			tunnel_rings[i].scale = Vector2.ONE * (0.1 + grow * grow * 9.0)
			tunnel_rings[i].modulate.a = (1.0 - grow) * 0.7
		tumbler.rotation += delta * 5.0
		tumbler.position = Vector2(sin(t * 3.0) * 14.0, cos(t * 2.0) * 8.0)
		tumbler.scale = Vector2.ONE * (1.0 + sin(t * 4.0) * 0.15)
	if arrival.visible and faller.position.y < FLOOR_Y - 12.0:
		faller.position.y = minf(FLOOR_Y - 12.0, faller.position.y + 70.0 * delta)
		faller.rotation += delta * 6.0
		if faller.position.y >= FLOOR_Y - 12.0:
			faller.rotation = 0.0
		faller_light.position = faller.position

	shake = maxf(0.0, shake - delta * 4.0)
	camera.offset = Vector2(randf_range(-shake, shake), randf_range(-shake, shake))


func _unhandled_key_input(event: InputEvent) -> void:
	if event.pressed and not event.echo and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE]:
		get_viewport().set_input_as_handled()
		_finish()


# ---------- beats ----------

func _run_beat(beat: String) -> void:
	match beat:
		"lab":
			Sfx.play_music(CALM_MUSIC)
			_fade_from_black(1.5)
			Sfx.play("machine_hum")
			_caption("Year 7 of the Galaxy Gate project.")
		"walk_in":
			mode = "walk_in"
		"tonight":
			_caption("Tonight, the gate opens.")
		"lever":
			mode = "lever"
			scientist.texture = WALK[0]
			lever.texture = LEVER_ON
			Sfx.play("switch")
			screens_color = Color("#5CFF9A")
		"power_100", "power_140", "power_200":
			mode = "charge"
			Sfx.play("energy")
			_caption({"power_100": "Power 100%...", "power_140": "Power 140%...", "power_200": "Power 200%?!"}[beat])
		"malfunction":
			mode = "malfunction"
			Sfx.play_music(TENSE_MUSIC)
			sparks.emitting = true
			for beacon in beacons:
				beacon.visible = true
			_caption("WARNING:  FIELD UNSTABLE", DANGER)
		"rift_opens":
			mode = "rift"
			Sfx.play("rift")
			_flash(Color.WHITE, 0.6)
			swirl.visible = true
			sparks.emitting = false
			debris.emitting = true
			darkness.color = Color(0.4, 0.34, 0.55)
			_caption("No... no, no, no!")
		"pulled_in":
			mode = "pulled"
			Sfx.play("whoosh")
			_caption("")
		"fade_out":
			_fade_to_black(0.5)
		"tunnel":
			lab.visible = false
			tunnel.visible = true
			shake = 0.0
			darkness.color = Color(0.85, 0.85, 1.0)
			_fade_from_black(0.4)
		"whoosh":
			Sfx.play("whoosh")
		"arrival":
			Sfx.fade_out_music(2.0)   # quiet for the landing; Level 1 starts its own music
			tunnel.visible = false
			arrival.visible = true
			darkness.color = Color(0.62, 0.67, 0.86)   # the same night colour as Level 1
			_flash(Color.WHITE, 0.9)
		"land":
			Sfx.play("thud")
			dust.emitting = true
			shake = 4.0
		"title":
			var tween = create_tween()
			tween.tween_property(title, "modulate:a", 1.0, 1.4)
			tween.tween_property(subtitle, "modulate:a", 1.0, 0.8)
			Sfx.play("checkpoint")
		"end":
			_finish()


func _finish() -> void:
	if finished:
		return
	finished = true
	var tween = create_tween()
	tween.tween_property(fade, "color:a", 1.0, 0.5)
	tween.tween_callback(func(): get_tree().change_scene_to_file(next_scene))


# Captions type themselves out letter by letter
func _caption(text: String, color := TEXT) -> void:
	caption.text = text
	caption.add_theme_color_override("font_color", color)
	caption.visible_ratio = 0.0
	create_tween().tween_property(caption, "visible_ratio", 1.0, 0.03 * text.length())


func _fade_from_black(time: float) -> void:
	fade.color = Color(0, 0, 0, 1)
	create_tween().tween_property(fade, "color:a", 0.0, time)


func _fade_to_black(time: float) -> void:
	create_tween().tween_property(fade, "color:a", 1.0, time)


func _flash(color: Color, time: float) -> void:
	fade.color = Color(color, 1.0)
	create_tween().tween_property(fade, "color:a", 0.0, time)


# ---------- small helpers ----------

func _rect(parent: Node, pos: Vector2, size: Vector2, color: Color) -> ColorRect:
	var r = ColorRect.new()
	r.position = pos
	r.size = size
	r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r


# A rectangle covered with one tile (or a strip of tiles) from a sprite sheet, repeated
func _tiled(parent: Node, area: Rect2, tile: Rect2, sheet: Texture2D, tint: Color) -> TextureRect:
	var image = sheet.get_image().get_region(Rect2i(tile))
	var r = TextureRect.new()
	r.texture = ImageTexture.create_from_image(image)
	r.stretch_mode = TextureRect.STRETCH_TILE
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.position = area.position
	r.size = area.size
	r.modulate = tint
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r


func _region(sheet: Texture2D, rect: Rect2) -> AtlasTexture:
	var a = AtlasTexture.new()
	a.atlas = sheet
	a.region = rect
	return a


func _circle(parent: Node, radius: float, width: float, color: Color) -> Line2D:
	var line = Line2D.new()
	line.width = width
	line.default_color = color
	line.closed = true
	for k in 48:
		line.add_point(Vector2(cos(k * TAU / 48.0), sin(k * TAU / 48.0)) * radius)
	parent.add_child(line)
	return line


func _light(parent: Node, pos: Vector2, color: Color, energy: float, size: float) -> PointLight2D:
	var light = PointLight2D.new()
	light.texture = _soft_dot()
	light.position = pos
	light.color = color
	light.energy = energy
	light.texture_scale = size
	parent.add_child(light)
	return light


func _particles(parent: Node, pos: Vector2, amount: int, life: float, color: Color) -> CPUParticles2D:
	var p = CPUParticles2D.new()
	p.position = pos
	p.amount = amount
	p.lifetime = life
	p.color = color
	p.material = _additive()
	parent.add_child(p)
	return p


func _label(parent: Node, text: String, size: int, color: Color) -> Label:
	var label = Label.new()
	label.text = text
	label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("#07060C"))
	label.add_theme_constant_override("outline_size", 6)
	parent.add_child(label)
	return label


func _additive() -> CanvasItemMaterial:
	var m = CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m


var soft_dot: GradientTexture2D

func _soft_dot() -> GradientTexture2D:
	if soft_dot:
		return soft_dot
	var g = Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0)])
	g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	soft_dot = GradientTexture2D.new()
	soft_dot.gradient = g
	soft_dot.width = 128
	soft_dot.height = 128
	soft_dot.fill = GradientTexture2D.FILL_RADIAL
	soft_dot.fill_from = Vector2(0.5, 0.5)
	soft_dot.fill_to = Vector2(0.5, 0.0)
	return soft_dot


# A thin bright line that fades at both ends: the tunnel's star streaks
func _streak() -> GradientTexture2D:
	var g = Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	g.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	var tex = GradientTexture2D.new()
	tex.gradient = g
	tex.width = 2
	tex.height = 18
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	return tex
