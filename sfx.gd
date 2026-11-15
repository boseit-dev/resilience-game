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
	# Level 1 expansion: enemies, chests, cutscene (all reuse the CC0 files above)
	"stomp": preload("res://assets/kenney_audio/slime_000.ogg"),
	"enemy_defeat": preload("res://assets/kenney_audio/explosionCrunch_000.ogg"),
	"sword_warn": preload("res://assets/kenney_audio/pluck_002.ogg"),
	"sword_swing": preload("res://assets/swishes/swish-1.wav"),
	"bow_draw": preload("res://assets/kenney_audio/pluck_002.ogg"),
	"arrow": preload("res://assets/swishes/swish-4.wav"),
	"armour_hit": preload("res://assets/kenney_audio/bong_001.ogg"),
	"guardian_warn": preload("res://assets/kenney_audio/forceField_000.ogg"),
	"slam": preload("res://assets/kenney_audio/lowFrequency_explosion_000.ogg"),
	"hurt": preload("res://assets/kenney_audio/drop_002.ogg"),
	"chest_open": preload("res://assets/kenney_audio/doorOpen_001.ogg"),
	"reward": preload("res://assets/kenney_audio/confirmation_002.ogg"),
	"rare_reward": preload("res://assets/kenney_audio/maximize_005.ogg"),
	"shield_break": preload("res://assets/kenney_audio/forceField_000.ogg"),
	"secret": preload("res://assets/kenney_audio/maximize_005.ogg"),
	"machine_hum": preload("res://assets/kenney_audio/spaceEngineLow_001.ogg"),
	"switch": preload("res://assets/kenney_audio/drop_002.ogg"),
	"energy": preload("res://assets/kenney_audio/forceField_000.ogg"),
	"alarm": preload("res://assets/kenney_audio/bong_001.ogg"),
	"rift": preload("res://assets/kenney_audio/lowFrequency_explosion_001.ogg"),
	"whoosh": preload("res://assets/swishes/swish-4.wav"),
	"thud": preload("res://assets/kenney_audio/lowFrequency_explosion_001.ogg"),
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
	"stomp": -4.0,
	"enemy_defeat": -8.0,
	"sword_warn": -10.0,
	"sword_swing": -6.0,
	"bow_draw": -10.0,
	"arrow": -9.0,
	"armour_hit": -6.0,
	"guardian_warn": -9.0,
	"slam": -6.0,
	"chest_open": -5.0,
	"shield_break": -6.0,
	"machine_hum": -8.0,
	"energy": -8.0,
	"alarm": -6.0,
	"whoosh": -4.0,
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
	"stomp": 1.4,
	"enemy_defeat": 1.5,
	"sword_warn": 2.4,
	"sword_swing": 0.8,
	"bow_draw": 0.6,
	"arrow": 1.7,
	"armour_hit": 0.7,
	"guardian_warn": 0.5,
	"slam": 1.4,
	"hurt": 0.8,
	"chest_open": 1.2,
	"rare_reward": 1.3,
	"shield_break": 0.6,
	"secret": 1.5,
	"switch": 1.6,
	"energy": 0.7,
	"alarm": 1.9,
	"rift": 0.7,
	"whoosh": 0.6,
	"thud": 0.9,
}

const AMBIENCE = preload("res://assets/kenney_audio/spaceEngineLow_001.ogg")
const AMBIENCE_VOLUME = -26.0

# Background music: "Level 1" chiptune by Juhani Junkala (CC0), see assets/music/LICENSE.txt
const MUSIC = preload("res://assets/music/level_1_theme.ogg")
const MUSIC_VOLUME = -15.0

# Boss music: "Level 3" by Juhani Junkala (CC0). To use another track, change this path.
const BOSS_MUSIC = preload("res://assets/music/boss_theme.ogg")

var players: Array[AudioStreamPlayer] = []
var ambience: AudioStreamPlayer
var music: AudioStreamPlayer
var music_fade: Tween
var music_target: AudioStream  # the track playing, or fading in
var level_music: AudioStream = MUSIC   # set by each level (level_1.gd)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # sounds and music keep going while the game is paused

	# A few players so sounds can overlap (death + unlock at the same time)
	for i in 16:
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
# Hazards far away stay quiet (and leave the sound players free for the player's own sounds)
func play_near(sound_name: String, where: Vector2, pitch: float = 1.0) -> void:
	var player = get_tree().current_scene.get_node_or_null("Player")
	if player == null or player.global_position.distance_to(where) < 700.0:
		play(sound_name, pitch)


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
	play_music(level_music)


func play_boss_music() -> void:
	play_music(BOSS_MUSIC)


func fade_out_music(time: float) -> void:
	music_target = null
	if music_fade:
		music_fade.kill()
	music_fade = create_tween()
	music_fade.tween_property(music, "volume_db", -40.0, time)


# Fade out whatever is playing, then fade the new track in
func play_music(stream: AudioStream) -> void:
	if music_target == stream:
		return
	music_target = stream
	music.pitch_scale = 1.0   # the Prototype speeds its music up; any new track starts normal
	if "loop" in stream:   # Ogg files loop here; WAV files loop through their import settings
		stream.loop = true

	if music_fade:
		music_fade.kill()  # a new switch replaces one still fading
	music_fade = create_tween()
	if music.playing:
		music_fade.tween_property(music, "volume_db", -40.0, 0.8)
	music_fade.tween_callback(func():
		music.stream = stream
		music.volume_db = -40.0
		music.play())
	music_fade.tween_property(music, "volume_db", MUSIC_VOLUME, 1.5)
