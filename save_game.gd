extends Node

# RESILIENCE - STORY SAVE (autoload "SaveGame")
# Remembers how far the story has got, in user://save.cfg (settings live in settings.cfg).
# Only finishing a level changes it. Deaths, restarts and the tutorial never touch it.
#
#   unlocked_level   highest level you may play (1 to LEVEL_COUNT)
#   completed        level numbers you have beaten
#   fragments        Gateway Fragments collected (one per boss)
#   powers           powers you keep in later levels: "pad", "double_jump", "dash"
#   current_level    where Continue Game takes you

var path = "user://save.cfg"   # the self-test points this at a test file, so it never touches your save
const LEVEL_COUNT = 5
const LEVEL_NAMES = ["THE ARRIVAL", "FORGOTTEN LABORATORIES", "THE FRACTURED CAVERNS", "THE BROKEN GATEWAY", "THE HEART OF THE BETWEEN"]
const STORY_START = "res://intro_cutscene.tscn"   # New Game: the lab accident, then Level 1

var unlocked_level = 1
var completed: Array = []
var fragments = 0
var powers: Array = []
var current_level = 0      # 0 = no story started yet (Continue is greyed out)


func _ready() -> void:
	load_save()


# The scene for a level number, e.g. 2 -> res://level_2.tscn
func level_scene(number: int) -> String:
	return "res://level_%d.tscn" % number


# Is this level built yet, and has the player unlocked it?
func can_play(number: int) -> bool:
	return number >= 1 and number <= unlocked_level and ResourceLoader.exists(level_scene(number))


func has_progress() -> bool:
	return current_level >= 1 and can_play(current_level)


func start_new_game() -> void:
	unlocked_level = 1
	completed = []
	fragments = 0
	powers = []
	current_level = 1
	save()


# Called when a level's boss is beaten: the fragment, the next level and your powers are kept
func complete_level(number: int, kept_powers: Array) -> void:
	if not completed.has(number):
		completed.append(number)
		fragments = completed.size()
	for p in kept_powers:
		if not powers.has(p):
			powers.append(p)
	unlocked_level = clampi(max(unlocked_level, number + 1), 1, LEVEL_COUNT)
	current_level = number + 1 if number < LEVEL_COUNT else number
	save()


func save() -> void:
	var config = ConfigFile.new()
	config.set_value("story", "unlocked_level", unlocked_level)
	config.set_value("story", "completed", completed)
	config.set_value("story", "fragments", fragments)
	config.set_value("story", "powers", powers)
	config.set_value("story", "current_level", current_level)
	config.save(path)


# A missing or damaged file just means a fresh start. Bad numbers are pulled back into range.
func load_save() -> void:
	var config = ConfigFile.new()
	if config.load(path) != OK:
		return
	unlocked_level = clampi(int(config.get_value("story", "unlocked_level", 1)), 1, LEVEL_COUNT)
	completed = Array(config.get_value("story", "completed", [])).filter(func(n): return n is int and n >= 1 and n <= LEVEL_COUNT)
	fragments = completed.size()
	powers = Array(config.get_value("story", "powers", [])).filter(func(p): return p in ["pad", "double_jump", "dash"])
	current_level = clampi(int(config.get_value("story", "current_level", 0)), 0, unlocked_level)
