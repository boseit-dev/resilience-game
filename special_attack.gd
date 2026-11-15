extends CanvasLayer

# RESILIENCE - SPECIAL ABILITY: "SOUL STRIKE"
# The Warden starts this when you've taken 3 of its hearts (warden.gd, SPECIAL_AFTER_HITS).
# The game pauses and asks you to spam SPACE: 20 presses in 3 seconds.
#   Success: light gathers into you, lightning strikes the Warden and rips off one more heart.
#   Too slow: nothing happens and the fight carries on.
# Everything here keeps running while the rest of the game is paused (process_mode = ALWAYS).

const PRESSES_NEEDED = 20
const TIME_LIMIT = 3.0
const CARD_WIDTH = 460.0
const KEY_Y = 104.0          # where the SPACE key sits inside the card
const TIMER_WIDTH = 428.0
const FONT = preload("res://assets/fonts/Cinzel.ttf")

const GLOW = Color("#83D9FF")
const BRIGHT = Color("#E8F5FF")
const DANGER = Color(1.0, 0.45, 0.45)
const BOLT_COLOR = Color(2.0, 2.5, 3.2)  # over 1.0 so it shines through the level's darkness
const HEART_COLOR = Color(1.5, 1.0, 1.7)

var warden: Node2D
var player: Node2D
var presses: int = 0
var time_left: float = TIME_LIMIT
var active: bool = false  # true while it's counting your presses

var fx: Node2D           # world-space effects (particles, lightning)
var warden_size: Vector2 # the Warden art's normal scale (it squashes when hit)
var shake_tween: Tween

var ui: Control
var dim: ColorRect
var flash: ColorRect
var card: Panel           # the dark box behind the challenge
var title: Label
var big: Label
var counter: Label        # message line under the card
var key: Panel            # the big SPACE key
var key_style: StyleBoxFlat
var pips: Array[ColorRect] = []   # one diamond per press needed
var timer_fill: ColorRect


func start(the_warden: Node2D, the_player: Node2D) -> void:
	warden = the_warden
	player = the_player
	warden_size = warden.get_node("Art").scale
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	_build_ui()

	fx = Node2D.new()
	fx.name = "SoulStrikeFx"
	fx.process_mode = Node.PROCESS_MODE_ALWAYS
	fx.z_index = 5
	warden.get_parent().add_child(fx)

	get_tree().paused = true
	Sfx.play("special_ready")

	# Intro: darken the screen and punch the text in
	big.scale = Vector2(0.3, 0.3)
	card.scale = Vector2(0.85, 0.85)
	card.modulate.a = 0.0
	var intro = create_tween()
	intro.tween_property(dim, "color:a", 0.65, 0.2)
	intro.parallel().tween_property(card, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	intro.parallel().tween_property(card, "modulate:a", 1.0, 0.2)
	intro.parallel().tween_property(big, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	intro.tween_callback(func(): active = true)


func _process(delta: float) -> void:
	if not active:
		return
	time_left -= delta
	var left = max(time_left, 0.0) / TIME_LIMIT
	timer_fill.size.x = TIMER_WIDTH * left
	timer_fill.color = DANGER.lerp(GLOW, left)  # turns red as time runs out
	big.modulate = BRIGHT.lerp(GLOW, 0.5 + 0.5 * sin(Time.get_ticks_msec() / 60.0))  # flicker
	if time_left <= 0.0:
		_fail()


# _input (not _unhandled_input) so nothing else can take the key first
func _input(event: InputEvent) -> void:
	if not active or not event is InputEventKey:
		return
	if event.pressed and not event.echo and event.physical_keycode == KEY_SPACE:
		get_viewport().set_input_as_handled()
		presses += 1
		var pip = pips[presses - 1]
		pip.color = GLOW
		_punch(pip, 1.8)
		_press_key()
		Sfx.play("qte_tick", 1.0 + presses * 0.06)  # rises with every press
		_punch(big, 1.1)
		_shake(1.5 + presses * 0.15, 0.09)
		if presses >= PRESSES_NEEDED:
			_succeed()


# ---------- outcomes ----------

func _fail() -> void:
	active = false
	big.text = "TOO SLOW..."
	big.modulate = DANGER
	title.text = "THE WARDEN SHRUGS IT OFF"
	card.get_theme_stylebox("panel").border_color = DANGER
	Sfx.play("qte_fail")
	var outro = create_tween()
	outro.tween_interval(0.8)
	outro.tween_property(ui, "modulate:a", 0.0, 0.3)
	outro.tween_callback(_finish)


func _succeed() -> void:
	active = false
	title.text = "SPECIAL ABILITY"
	big.text = "SOUL  STRIKE!"
	big.modulate = BRIGHT
	_punch(big, 1.6)

	var show = create_tween()
	# 1. Lift the darkness so you can watch, and gather light into the player
	show.tween_property(dim, "color:a", 0.2, 0.3)
	show.parallel().tween_property(card, "modulate:a", 0.0, 0.2)
	show.tween_callback(_charge_up)
	show.tween_interval(0.75)
	# 2. Lightning strikes the Warden (twice, like a real flicker)
	show.tween_callback(_lightning)
	show.tween_interval(0.12)
	show.tween_callback(_lightning)
	show.tween_interval(0.08)
	# 3. One of its hearts is torn off and shatters
	show.tween_callback(_rip_heart)
	show.tween_interval(1.0)
	show.tween_property(ui, "modulate:a", 0.0, 0.35)
	show.tween_callback(_finish)


func _finish() -> void:
	get_tree().paused = false
	if is_instance_valid(fx):
		fx.queue_free()
	queue_free()


# ---------- the Soul Strike animation ----------

func _charge_up() -> void:
	Sfx.play("special_charge")

	# Sparks start in a ring around the player and get pulled into them
	var sparks = CPUParticles2D.new()
	fx.add_child(sparks)
	sparks.global_position = player.global_position
	sparks.amount = 60
	sparks.lifetime = 0.75
	sparks.one_shot = true
	sparks.explosiveness = 0.3
	sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE_SURFACE  # the edge of a circle
	sparks.emission_sphere_radius = 76.0
	sparks.gravity = Vector2.ZERO
	sparks.initial_velocity_min = 0.0
	sparks.initial_velocity_max = 0.0
	sparks.radial_accel_min = -300.0  # negative = towards the middle
	sparks.radial_accel_max = -260.0
	sparks.scale_amount_min = 1.5
	sparks.scale_amount_max = 3.0
	sparks.color = BOLT_COLOR
	sparks.emitting = true

	# The player glows brighter and brighter
	var light = _add_light(player.global_position, GLOW, 0.0, 2.0)
	var glow = create_tween()
	glow.tween_property(light, "energy", 3.0, 0.75)
	glow.parallel().tween_property(player.get_node("Sprite2D"), "modulate", Color(2.2, 2.4, 3.0), 0.75)
	glow.tween_property(light, "energy", 0.0, 0.5)


func _lightning() -> void:
	Sfx.play("special_bolt")
	var bottom = warden.global_position + Vector2(0, -16)
	var top = bottom + Vector2(randf_range(-40.0, 40.0), -440.0)

	# A jagged bolt: a wide glowing line with a thin white core
	var points = PackedVector2Array()
	for i in 13:
		var p = top.lerp(bottom, i / 12.0)
		if i > 0 and i < 12:
			p.x += randf_range(-22.0, 22.0)
		points.append(p)
	for line_style in [[12.0, BOLT_COLOR * Color(1, 1, 1, 0.6)], [4.0, Color(3, 3, 3)]]:
		var bolt = Line2D.new()
		bolt.points = points
		bolt.width = line_style[0]
		bolt.default_color = line_style[1]
		bolt.joint_mode = Line2D.LINE_JOINT_ROUND
		fx.add_child(bolt)
		var fade = create_tween()
		fade.tween_property(bolt, "modulate:a", 0.0, 0.3)
		fade.tween_callback(bolt.queue_free)

	# White flash, a burst of light on the Warden, big screen shake
	flash.color.a = 0.85
	create_tween().tween_property(flash, "color:a", 0.0, 0.35)
	var light = _add_light(bottom, Color(0.8, 0.9, 1.0), 6.0, 3.5)
	create_tween().tween_property(light, "energy", 0.0, 0.5)
	var art = warden.get_node("Art")
	art.modulate = Color(4, 4, 4)
	create_tween().tween_property(art, "modulate", Color.WHITE, 0.5)
	_shake(9.0, 0.4)
	_impact(bottom + Vector2(0, 16))


# Where the bolt lands: the Warden squashes, a shockwave ring spreads out and sparks fly
func _impact(pos: Vector2) -> void:
	var art = warden.get_node("Art")
	art.scale = warden_size * Vector2(1.4, 0.6)
	create_tween().tween_property(art, "scale", warden_size, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	var ring = Line2D.new()
	for i in 33:
		ring.add_point(Vector2.from_angle(TAU * i / 32.0) * Vector2(20, 7))  # a flat ellipse on the ground
	ring.width = 3.0
	ring.default_color = BOLT_COLOR
	fx.add_child(ring)
	ring.global_position = pos
	var grow = create_tween()
	grow.tween_property(ring, "scale", Vector2(5, 5), 0.45).set_ease(Tween.EASE_OUT)
	grow.parallel().tween_property(ring, "modulate:a", 0.0, 0.45)
	grow.tween_callback(ring.queue_free)

	var sparks = CPUParticles2D.new()
	fx.add_child(sparks)
	sparks.global_position = pos
	sparks.amount = 40
	sparks.lifetime = 0.6
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.direction = Vector2(0, -1)
	sparks.spread = 80.0
	sparks.gravity = Vector2(0, 500)
	sparks.initial_velocity_min = 120.0
	sparks.initial_velocity_max = 260.0
	sparks.scale_amount_min = 1.5
	sparks.scale_amount_max = 3.0
	sparks.color = BOLT_COLOR
	sparks.emitting = true
	sparks.finished.connect(sparks.queue_free)


func _rip_heart() -> void:
	var hearts = warden.get_node("Hearts")
	var heart = hearts.get_child(warden.health - 1)  # the last heart still showing

	# A copy of the heart flies up, swells and spins...
	var ghost = Sprite2D.new()
	ghost.texture = heart.texture
	fx.add_child(ghost)
	ghost.global_position = heart.global_position
	ghost.scale = heart.global_scale
	ghost.modulate = HEART_COLOR

	warden.special_hit()  # takes the heart away for real
	Sfx.play("special_shatter")
	counter.text = "THE WARDEN LOSES A HEART"
	counter.modulate.a = 1.0
	_punch(counter, 1.4)

	var fly = create_tween()
	fly.tween_property(ghost, "global_position", ghost.global_position + Vector2(0, -50), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	fly.parallel().tween_property(ghost, "scale", ghost.scale * 3.5, 0.4)
	fly.parallel().tween_property(ghost, "rotation", 0.7, 0.4)
	# ...then shatters into pieces
	fly.tween_callback(func():
		_shatter(ghost.global_position)
		_shake(4.0, 0.2)
		ghost.queue_free())


func _shatter(pos: Vector2) -> void:
	Sfx.play("special_shatter", 1.4)
	var pieces = CPUParticles2D.new()
	fx.add_child(pieces)
	pieces.global_position = pos
	pieces.amount = 36
	pieces.lifetime = 0.9
	pieces.one_shot = true
	pieces.explosiveness = 1.0
	pieces.spread = 180.0
	pieces.gravity = Vector2(0, 320)
	pieces.initial_velocity_min = 90.0
	pieces.initial_velocity_max = 220.0
	pieces.scale_amount_min = 2.0
	pieces.scale_amount_max = 4.0
	pieces.color = HEART_COLOR
	pieces.emitting = true


# ---------- small helpers ----------

# Quick "pop" bigger then back to normal size
func _punch(node: Control, amount: float) -> void:
	node.scale = Vector2(amount, amount)
	create_tween().tween_property(node, "scale", Vector2.ONE, 0.15).set_ease(Tween.EASE_OUT)


# Wobble the camera for a moment
func _shake(strength: float, duration: float) -> void:
	var cam = player.get_node_or_null("Camera2D")
	if cam == null:
		return
	if shake_tween:
		shake_tween.kill()
	shake_tween = create_tween()
	for i in max(1, int(duration / 0.03)):
		shake_tween.tween_property(cam, "offset", Vector2(randf_range(-1, 1), randf_range(-1, 1)) * strength, 0.03)
	shake_tween.tween_property(cam, "offset", Vector2.ZERO, 0.03)


func _add_light(pos: Vector2, color: Color, energy: float, size: float) -> PointLight2D:
	var gradient = Gradient.new()
	gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	var texture = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	var light = PointLight2D.new()
	light.texture = texture
	light.texture_scale = size
	light.color = color
	light.energy = energy
	fx.add_child(light)
	light.global_position = pos
	return light


# ---------- the pop-up ----------

func _build_ui() -> void:
	var screen = get_viewport().get_visible_rect().size

	ui = Control.new()
	ui.size = screen
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)

	dim = _rect(Vector2.ZERO, screen, Color(0.02, 0.01, 0.05, 0.0))
	flash = _rect(Vector2.ZERO, screen, Color(1, 1, 1, 0.0))

	# The card: a dark box with a thin frosty border, above the player
	var top = screen.y / 2.0 - 250.0
	card = Panel.new()
	card.position = Vector2((screen.x - CARD_WIDTH) / 2.0, top)
	card.size = Vector2(CARD_WIDTH, 220)
	card.pivot_offset = card.size / 2.0
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", _box(Color(0.05, 0.045, 0.08, 0.94), Color("#7985AB")))
	ui.add_child(card)

	title = _label("SPECIAL ABILITY", 15, GLOW, top + 16, screen.x)
	big = _label("SPAM  SPACE!", 44, BRIGHT, top + 36, screen.x)

	# The SPACE key. Its thick bottom edge makes it look like a real key; it squashes on every press.
	key = Panel.new()
	key.size = Vector2(220, 50)
	key.position = Vector2((CARD_WIDTH - key.size.x) / 2.0, KEY_Y)
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key_style = _box(Color("#1B2033"), BRIGHT)
	key_style.border_width_bottom = 6
	key.add_theme_stylebox_override("panel", key_style)
	card.add_child(key)
	_label("SPACE", 20, BRIGHT, 8, key.size.x, key)

	# One diamond per press needed; each lights up when you press
	var gap = 20.0
	var start_x = (CARD_WIDTH - gap * (PRESSES_NEEDED - 1)) / 2.0
	for i in PRESSES_NEEDED:
		var pip = _rect(Vector2(start_x + i * gap - 5, 174), Vector2(10, 10), Color("#2A3148"), card)
		pip.pivot_offset = Vector2(5, 5)
		pip.rotation = PI / 4.0  # a square turned into a diamond
		pips.append(pip)

	# Time left: a thin line along the bottom of the card
	timer_fill = _rect(Vector2((CARD_WIDTH - TIMER_WIDTH) / 2.0, 202), Vector2(TIMER_WIDTH, 3), GLOW, card)

	counter = _label("%d PRESSES IN %d SECONDS" % [PRESSES_NEEDED, int(TIME_LIMIT)], 16, GLOW, top + 232, screen.x)


# The SPACE key moves down and flashes, then springs back up
func _press_key() -> void:
	key_style.border_width_bottom = 2
	key.position.y = KEY_Y + 4
	key.modulate = Color(1.8, 2.0, 2.3)
	var spring = create_tween()
	spring.tween_property(key, "position:y", KEY_Y, 0.08)
	spring.parallel().tween_property(key, "modulate", Color.WHITE, 0.15)
	spring.tween_callback(func(): key_style.border_width_bottom = 6)


# A dark rounded box style with a coloured border
func _box(fill: Color, border: Color) -> StyleBoxFlat:
	var box = StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(2)
	box.set_corner_radius_all(6)
	return box


func _label(text: String, font_size: int, color: Color, y: float, width: float, parent: Control = null) -> Label:
	var label = Label.new()
	label.text = text
	label.position = Vector2(0, y)
	label.size = Vector2(width, font_size * 1.5)
	label.pivot_offset = label.size / 2.0  # so punches grow from the middle
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("#07060C"))
	label.add_theme_constant_override("outline_size", max(4, int(font_size / 5.0)))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent else ui).add_child(label)
	return label


func _rect(pos: Vector2, rect_size: Vector2, color: Color, parent: Control = null) -> ColorRect:
	var rect = ColorRect.new()
	rect.position = pos
	rect.size = rect_size
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent else ui).add_child(rect)
	return rect
