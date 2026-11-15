extends Area2D

# RESILIENCE - EXIT PORTAL
# Hidden until open() is called (the Warden's "defeated" signal calls it).
# Walk in to go to next_scene. If that scene doesn't exist yet, a message shows instead,
# then you go back to the main menu (your progress is already saved).

@export_file("*.tscn") var next_scene: String = "res://level_2.tscn"

var is_open: bool = false


func _ready() -> void:
	hide()  # "Monitoring" is also off in portal.tscn until open()


func open() -> void:
	is_open = true
	show()
	Sfx.play("portal_open")
	set_deferred("monitoring", true)


func _process(delta: float) -> void:
	if is_open:
		var t = Time.get_ticks_msec() / 1000.0
		$Glow.energy = 1.4 + sin(t * 3.0) * 0.4
		$Ring.modulate.a = 0.6 + sin(t * 5.0) * 0.4


func _on_body_entered(body: Node2D) -> void:
	if body.name != "Player" or $Message.visible:
		return

	Sfx.play("portal_enter")

	if ResourceLoader.exists(next_scene):
		if travelling:
			return
		travelling = true
		if next_scene.ends_with("ending.tscn"):
			SaveGame.finish_story()   # the last gateway: the story is complete
		body.set_physics_process(false)
		body.visible = false
		_travel(STORY.get(next_scene.get_file().get_basename(), ""))
	else:
		$Message.text = next_scene.get_file().get_basename().replace("_", " ").to_upper() + " COMING SOON"
		$Message.show()
		get_tree().create_timer(4.0).timeout.connect(_back_to_menu)


# Between levels: fade to black, one line of story, then the next level
const STORY = {
	"level_2": "The fragment pulled at me like a compass...\ntowards the lights of an abandoned laboratory.",
	"level_3": "Dr. Vale's notes ended at one word: BELOW.\nUnder the labs, the rock had started to sing.",
}
var travelling = false

func _travel(text: String) -> void:
	var layer = CanvasLayer.new()
	layer.layer = 60
	get_tree().current_scene.add_child(layer)
	var black = ColorRect.new()
	black.color = Color(0, 0, 0, 0)
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(black)
	var line = Label.new()
	line.text = text
	line.set_anchors_preset(Control.PRESET_FULL_RECT)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.add_theme_font_override("font", preload("res://assets/fonts/Cinzel.ttf"))
	line.add_theme_font_size_override("font_size", 20)
	line.add_theme_color_override("font_color", Color("#D9D2F2"))
	line.modulate.a = 0.0
	layer.add_child(line)
	var go = create_tween()
	go.tween_property(black, "color:a", 1.0, 0.6)
	if text != "":
		go.tween_property(line, "modulate:a", 1.0, 0.5)
		go.tween_interval(2.2)
		go.tween_property(line, "modulate:a", 0.0, 0.4)
	go.tween_callback(func(): get_tree().change_scene_to_file(next_scene))


func _back_to_menu() -> void:
	if is_inside_tree():
		get_tree().change_scene_to_file("res://main_menu.tscn")
