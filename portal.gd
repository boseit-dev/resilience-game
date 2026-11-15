extends Area2D

# RESILIENCE - EXIT PORTAL
# Hidden until open() is called (the Warden's "defeated" signal calls it).
# Walk in to go to next_scene. If that scene doesn't exist yet, a message shows instead.

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
		get_tree().call_deferred("change_scene_to_file", next_scene)
	else:
		$Message.show()
