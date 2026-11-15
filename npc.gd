extends Node2D

# RESILIENCE - TALKING NPC (a ghostly echo of another lost explorer)
# Walk up to it and press E. Each press shows the next line; after the last line it closes.
# Walking away also closes it. Set the name and look in the Inspector;
# what each NPC says is in the DIALOGUE table below.
#
# E also places bounce pads. Key presses reach child nodes before the level script,
# so an NPC you're standing next to takes the E press and no pad is placed.
# Anywhere else, E places a pad as usual.

@export var npc_name: String = "WANDERER"
@export var look: Texture2D                          # which Kenney character to show

# What each NPC (or lab terminal) says, by name. Short lines.
const DIALOGUE = {
	"DR. VALE": ["You got past the Warden? Then you're stronger than we were.", "We built this lab to find a way home.", "Something we made still guards the core.", "If it sees you, run. If it stops, jump on it."],
	"LOG 12": ["DAY 12: The gateway frame is finished.", "Power is the problem. We need the fragments the guardians carry."],
	"LOG 40": ["DAY 40: Unit 7 can fetch the fragments for us.", "It doesn't feel pain. It doesn't feel anything."],
	"LOG 41": ["DAY 41: Unit 7 took the fragment and sealed the core.", "It thinks WE are the threat now.", "Prototype chamber: east wing, past security."],
	"LOG 55": ["DAY 55: Nobody who went into the east vent came back."],
}

var lines: Array = ["..."]   # filled from DIALOGUE in _ready()

const BUBBLE_BOTTOM = -34.0  # the speech bubble grows upwards from here

var player_near: bool = false
var line_index: int = -1     # -1 = not talking

@onready var art: Sprite2D = $Art
@onready var prompt: Label = $Prompt
@onready var alert: Label = $Alert
@onready var bubble: PanelContainer = $Bubble
@onready var name_label: Label = $Bubble/Box/Name
@onready var line_label: Label = $Bubble/Box/Line
@onready var hint_label: Label = $Bubble/Box/Hint


func _ready() -> void:
	if look:
		art.texture = look
	lines = DIALOGUE.get(npc_name, ["..."])
	prompt.hide()
	bubble.hide()


# Gentle floating, like a ghost
func _process(_delta: float) -> void:
	art.position.y = -12.0 + sin(Time.get_ticks_msec() / 450.0 + position.x) * 1.5


func _unhandled_key_input(event: InputEvent) -> void:
	if not player_near or not event is InputEventKey:
		return
	if event.pressed and not event.echo and event.physical_keycode == KEY_E:
		get_viewport().set_input_as_handled()  # so the level doesn't also place a pad
		_next_line()


func _next_line() -> void:
	line_index += 1
	if line_index >= lines.size():
		_close()
		return

	alert.hide()  # the "!" goes away once you've talked to them
	prompt.hide()
	name_label.text = npc_name
	line_label.text = lines[line_index]
	hint_label.text = "E  ▸" if line_index < lines.size() - 1 else "E  ✕"
	bubble.offset_top = BUBBLE_BOTTOM     # shrink, then it grows upwards to fit the new line
	bubble.offset_bottom = BUBBLE_BOTTOM
	bubble.show()
	Sfx.play("talk")


func _close() -> void:
	line_index = -1
	bubble.hide()
	prompt.visible = player_near


func _on_talk_zone_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		player_near = true
		prompt.visible = line_index < 0


func _on_talk_zone_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		player_near = false
		_close()
