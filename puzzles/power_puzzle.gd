extends "res://puzzles/puzzle.gd"

# RESILIENCE - CRYSTAL POWER NETWORK
# One power crystal can only feed a few machines at once (energy). Press E at a machine's
# panel to give it power, or to take its power back. Powered panels glow.
# A latched machine (a door) stays open once it has had power, even after you take it away:
# so the order you do things in matters.
# data: energy, machines [[panel position, name, [targets], latched?], ...], past_x

var powered = []
var lights = []


func _ready() -> void:
	super._ready()
	for i in data.machines.size():
		var m = data.machines[i]
		powered.append(false)
		lights.append(_sprite(GEM, m[0] + Vector2(0, -12)))
		_text(m[1], m[0] + Vector2(-14, -36), Color(0.75, 0.85, 1.0, 0.9))
		add_spot(m[0], toggle.bind(i))
	_show()


func toggle(i: int) -> void:
	var m = data.machines[i]
	if not powered[i] and powered.count(true) >= data.energy:
		Sfx.play("qte_fail")
		level._show_banner("NO ENERGY LEFT  ·  TAKE IT FROM ANOTHER MACHINE")
		return
	powered[i] = not powered[i]
	for ref in m[2]:
		var target = get_parent().made[ref[0]][ref[1]]
		if powered[i]:
			target.open()
		elif not (m.size() > 3 and m[3]):   # a latched door stays open
			target.close()
	Sfx.play("unlock" if powered[i] else "qte_fail", 1.2)
	level._show_banner("ENERGY  %d / %d" % [powered.count(true), data.energy])
	_show()


func reset() -> void:   # all power back to the crystal (latched doors stay open)
	super.reset()
	for i in powered.size():
		if powered[i]:
			toggle(i)


func _show() -> void:
	for i in lights.size():
		lights[i].modulate = Color(0.8, 1.8, 2.2) if powered[i] else Color(0.3, 0.3, 0.4)


func _physics_process(_delta: float) -> void:
	if not solved and level.player.global_position.x > data.past_x:
		solved = true   # got through: no more hints
		hint_label.hide()
