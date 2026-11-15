extends Node

# RESILIENCE - SOUND EFFECTS
# This is an autoload (Project Settings > Globals), so any script can call:
#     Sfx.play("jump")
# Every sound is CC0: Kenney (assets/kenney_audio), artisticdude's swishes (assets/swishes)
# and Juhani Junkala's chiptune music (assets/music). To change a sound, swap the file below.

const SOUNDS = {
	"jump": preload("res://assets/swishes/swish-1.wav"),
	"double_jump": preload("res://assets/swishes/swish-4.wav"),
	"dash": preload("res://assets/kenney_audio/forceField_000.ogg"),
	"pad_place": preload("res://assets/kenney_audio/drop_002.ogg"),
	"pad_bounce": preload("res://assets/kenney_audio/pluck_002.ogg"),
	"death": preload("res://assets/kenney_audio/lowFrequency_explosion_001.ogg"),
	"game_over": preload("res://assets/kenney_audio/lowFrequency_explosion_000.ogg"),
	"unlock": preload("res://assets/kenney_audio/confirmation_002.ogg"),
	"checkpoint": preload("res://assets/kenney_audio/bong_001.ogg"),
	"warden_hit": preload("res://assets/kenney_audio/slime_000.ogg"),
	"warden_die": preload("res://assets/kenney_audio/explosionCrunch_000.ogg"),
	"portal_open": preload("res://assets/kenney_audio/doorOpen_001.ogg"),
	"portal_enter": preload("res://assets/kenney_audio/maximize_005.ogg"),
	"warden_strike": preload("res://assets/kenney_audio/explosionCrunch_000.ogg"),
	"talk": preload("res://assets/kenney_audio/pluck_002.ogg"),
	"special_ready": preload("res://assets/kenney_audio/confirmation_002.ogg"),
	"qte_tick": preload("res://assets/kenney_audio/pluck_002.ogg"),
	"qte_fail": preload("res://assets/kenney_audio/drop_002.ogg"),
	"special_charge": preload("res://assets/kenney_audio/maximize_005.ogg"),
	"special_bolt": preload("res://assets/kenney_audio/lowFrequency_explosion_000.ogg"),
	"special_shatter": preload("res://assets/kenney_audio/explosionCrunch_000.ogg"),
	"quit_escape": preload("res://assets/kenney_audio/slime_000.ogg"),
	"quit_tired": preload("res://assets/kenney_audio/slime_000.ogg"),
}

# Loudness in decibels. Anything not listed plays at -4.
const VOLUME = {
	"jump": -9.0,
	"double_jump": -7.0,
	"dash": -10.0,
	"death": -1.0,
	"game_over": 0.0,
	"pad_bounce": -2.0,
	"warden_strike": -12.0,
	"talk": -12.0,
	"qte_tick": -8.0,
	"qte_fail": -2.0,
	"special_charge": -2.0,
	"special_bolt": 2.0,
	"quit_escape": -6.0,
}

# Pitch (1.0 = normal). Double jump uses a higher swish so it sounds different from the first jump.
const PITCH = {
	"double_jump": 1.3,
	"warden_strike": 1.6,
	"talk": 1.8,
	"qte_fail": 0.6,
	"special_charge": 0.8,
	"special_bolt": 1.15,
	"special_shatter": 0.8,
	"quit_escape": 1.9,
	"quit_tired": 0.55,
}

const AMBIENCE = preload("res://assets/kenney_audio/spaceEngineLow_001.ogg")
const AMBIENCE_VOLUME = -26.0

# Background music: "Level 1" chiptune by Juhani Junkala (CC0), see assets/music/LICENSE.txt
const MUSIC = preload("res://assets/music/level_1_theme.ogg")
const MUSIC_VOLUME = -15.0

# Boss music: the first file in this list that exists is used.
# To use Night Shade by AdhesiveWombat, save your copy as assets/music/night_shade.mp3 (or .ogg).
# The number is the second the track starts at (and loops back to): set it to the intense part.
const BOSS_MUSIC = [
	["res://assets/music/night_shade.mp3", 0.0],
	["res://assets/music/night_shade.ogg", 0.0],
	["res://assets/music/boss_theme.ogg", 0.0],  # CC0 stand-in: "Level 3" by Juhani Junkala
]

var players: Array[AudioStreamPlayer] = []
var ambience: AudioStreamPlayer
var music: AudioStreamPlayer
var music_fade: Tween
var music_target: AudioStream  # the track playing, or fading in


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # sounds and music keep going while the game is paused

	# A few players so sounds can overlap (death + unlock at the same time)
	for i in 8:
		var p = AudioStreamPlayer.new()
		p.bus = "Sounds"  # volume set in Options (settings.gd)
		add_child(p)
		players.append(p)

	ambience = AudioStreamPlayer.new()
	ambience.stream = AMBIENCE
	ambience.stream.loop = true
	ambience.volume_db = AMBIENCE_VOLUME
	ambience.bus = "Sounds"
	add_child(ambience)

	music = AudioStreamPlayer.new()
	music.stream = MUSIC
	music.stream.loop = true
	music.bus = "Music"
	add_child(music)


# pitch (optional) multiplies the sound's normal pitch, e.g. a rising tone for each press
func play(sound_name: String, pitch: float = 1.0) -> void:
	for p in players:
		if not p.playing:
			p.stream = SOUNDS[sound_name]
			p.volume_db = VOLUME.get(sound_name, -4.0)
			p.pitch_scale = pitch * PITCH.get(sound_name, 1.0) * randf_range(0.95, 1.05)  # tiny variation so repeats don't sound robotic
			p.play()
			return


# Music + low hum of The Between. Keeps playing through deaths and restarts.
func start_ambience() -> void:
	if not ambience.playing:
		ambience.play()

	play_level_music()


func play_level_music() -> void:
	_switch_music(MUSIC, 0.0)


# Called by the Warden when you drop into its arena
func play_boss_music() -> void:
	for entry in BOSS_MUSIC:
		if ResourceLoader.exists(entry[0]):
			_switch_music(load(entry[0]), entry[1])
			return


# Fade out whatever is playing, then fade the new track in
func _switch_music(stream: AudioStream, start: float) -> void:
	if music_target == stream:
		return
	music_target = stream
	stream.loop = true
	stream.loop_offset = start

	if music_fade:
		music_fade.kill()  # a new switch replaces one still fading
	music_fade = create_tween()
	if music.playing:
		music_fade.tween_property(music, "volume_db", -40.0, 0.8)
	music_fade.tween_callback(func():
		music.stream = stream
		music.volume_db = -40.0
		music.play(start))
	music_fade.tween_property(music, "volume_db", MUSIC_VOLUME, 1.5)
