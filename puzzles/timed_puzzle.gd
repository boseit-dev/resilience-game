extends "res://puzzles/puzzle.gd"

# RESILIENCE - TIMED GATE
# Press E at the lever: the gate opens for a few seconds (it ticks), then slams shut.
# Run, jump and dash to get through in time. Too slow? Walk back and pull it again.
# Once you are past the gate (past_x) it stays open, so it can never shut you in.
# data: lever position, seconds, past_x

var time_left = 0.0
var lever_art: Sprite2D


func _ready() -> void:
	super._ready()
	lever_art = _sprite(LEVER, data.lever + Vector2(0, -9), Color(1.6, 1.3, 0.7))
	add_spot(data.lever, pull)


func pull() -> void:
	if solved or time_left > 0.0:
		return
	time_left = data.seconds
	for t in targets:
		t.open()
	Sfx.play("unlock")
	level._show_banner("THE GATE IS OPEN  ·  %d" % int(data.seconds))


func _physics_process(delta: float) -> void:
	if solved or time_left <= 0.0:
		return
	if level.player.global_position.x > data.past_x:
		solved = true   # made it: the gate stays open
		hint_label.hide()
		level._show_banner("MADE IT")
		return
	var before = ceili(time_left)
	time_left -= delta
	if ceili(time_left) < before and time_left > 0.0:
		Sfx.play("qte_tick", 1.6)
		level._show_banner(str(ceili(time_left)))
	if time_left <= 0.0:
		if targets.any(func(t): return absf(t.global_position.x - level.player.global_position.x) < 24.0):
			time_left = 0.05   # never shut on top of you: wait until you're clear
			return
		for t in targets:
			t.close()
		level._show_banner("THE GATE SHUT")
