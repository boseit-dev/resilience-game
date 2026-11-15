extends "res://level_builder.gd"

# RESILIENCE - LEVEL 2: FORGOTTEN LABORATORIES (the map)
# Built from the tables below when the level starts (the building code is in level_builder.gd).
# Rules (lives, pads, checkpoints, the HUD) are the same as Level 1: level_1.gd.
# The boss is prototype.tscn and the opening is lab_intro.gd (both placed in level_2.tscn).
# World pixels: x grows to the right, y grows DOWN, the main floor top is y = 380.
#
#   1 Abandoned Entrance  x  -900 .. 1500   a hidden alcove (double jump up, top left)
#   2 Experiment Chambers x  1500 .. 3700   two switches open the door; or a hard high route over it
#   3 The Archives        x  3700 .. 5300   a hidden cave under the floor, a dangerous dead end above
#   4 The Power Core      x  5300 .. 7000   moving platform, Bounce Pad + Double Jump climb, Dash gap
#   5 Security Lockdown   x  7000 .. 8650   two switches, timed beams, mixed enemies
#   6 Prototype Chamber   x  8650 .. 9900   the boss

const L2 = preload("res://assets/music/level_2_theme.ogg")
const QUIET = preload("res://assets/music/intro_theme.wav")
const URGENT = preload("res://assets/music/level_1_theme.ogg")
const TERMINAL = "res://assets/kenney_pixel-platformer/Tiles/tile_0130.png"
const CYAN = Color("#7FE7FF")
const PURPLE = Color("#B98CFF")
const RED = Color("#FF5A5A")

# SOLID GROUND: [left, top, right, bottom, style]
const BLOCKS = [
	# 1 Abandoned Entrance
	[-900, 120, -240, 600, "stone"],
	[-240, 380, 600, 600, "lab"],
	[120, 230, 320, 260, "lab"],            # hidden alcove (double jump)
	[600, 470, 700, 600, "lab"],            # collapsed floor (spikes)
	[700, 380, 1150, 600, "lab"],
	[1150, 380, 1500, 600, "lab"],
	[1150, 120, 1450, 300, "lab"],          # low corridor with an electric beam
	# 2 Experiment Chambers
	[1500, 380, 2300, 600, "lab"],
	[1796, 210, 2150, 240, "violet"],       # shelf with switch 1 (lift up)
	[2300, 380, 2650, 600, "lab"],          # electrified floor
	[2650, 380, 2700, 440, "lab"],
	[2780, 380, 3150, 440, "lab"],          # thin floor over the hidden research room
	[2640, 520, 3150, 600, "lab"],          # research room floor (switch 2)
	[3150, 380, 3400, 600, "lab"],
	[3400, 380, 3700, 600, "lab"],
	[3400, 170, 3650, 260, "lab"],          # above the door: the high route lands here
	[2360, 200, 2440, 215, "violet"],       # high route: double jumps, then a long double jump + dash
	[2660, 190, 2730, 205, "violet"],
	[3215, 190, 3330, 205, "violet"],
	# 3 The Archives
	[3700, 380, 4280, 600, "stone"],
	[4320, 380, 4680, 440, "stone"],        # thin floor over the hidden cave
	[4280, 500, 4750, 600, "stone"],        # cave floor
	[4750, 380, 5300, 600, "stone"],
	[4800, 230, 5150, 260, "stone"],        # dead end shelf
	# 4 The Power Core
	[5300, 380, 5520, 600, "violet"],
	[5300, 220, 5420, 240, "violet"],       # archer ledge
	[5520, 540, 6580, 600, "violet"],       # the pit (spikes)
	[5980, 300, 6120, 600, "violet"],       # pillar (checkpoint)
	[6280, 120, 6460, 600, "violet"],       # too high for a double jump: pad first
	[6400, -120, 6720, 70, "violet"],       # low ceiling: dash across the gap
	[6580, 120, 6800, 600, "violet"],
	[6800, 380, 7000, 600, "violet"],
	# 5 Security Lockdown
	[7000, 380, 8650, 600, "ember"],
	[7412, 220, 7850, 240, "ember"],        # catwalk (switch A, archer)
	[7900, 160, 8000, 180, "ember"],        # side ledge (chest)
	[8100, 200, 8450, 250, "ember"],        # beam ceiling
	[8450, 100, 8650, 260, "ember"],        # above the lockdown door
	# 6 Prototype Chamber
	[8650, 380, 9900, 600, "lab"],
	[9900, 100, 10600, 600, "stone"],
]

# SPIKES: [x, floor top]
const SPIKES = [
	[632, 470], [668, 470],
	[5118, 230],
	[5552, 540], [5616, 540], [5680, 540], [5744, 540], [5808, 540], [5872, 540], [5936, 540], [6000, 540], [6064, 540], [6128, 540], [6192, 540], [6256, 540], [6320, 540], [6384, 540], [6448, 540], [6512, 540], [6560, 540],
]

# MOVING PLATFORMS: [x, top, width, travel x, travel y, seconds]
const MOVERS = [
	[1760, 370, 72, 0, -162, 2.5],          # lift to switch 1
	[2740, 512, 56, 0, -135, 2.0],          # lift out of the research room
	[5600, 330, 72, 300, 0, 2.5],           # across the core pit
	[7380, 370, 64, 0, -152, 2.2],          # lift to the catwalk
]

# ELECTRIC BEAMS: [x, y, length, vertical?, on seconds, off seconds, delay, boss arena?]
const ZAPPERS = [
	[1300, 300, 80, true, 1.0, 1.8, 0.0],
	[2320, 372, 300, false, 1.3, 1.8, 0.0], # electrified floor
	[6290, 116, 100, false, 1.0, 2.0, 0.0], # top of the pad climb (land on the right)
	[8180, 250, 130, true, 1.0, 1.4, 0.0],
	[8280, 250, 130, true, 1.0, 1.4, 0.6],
	[8380, 250, 130, true, 1.0, 1.4, 1.2],
	[8950, 230, 150, true, 1.0, 2.2, 0.0, true],   # boss arena: on from phase 2
	[9550, 230, 150, true, 1.0, 2.2, 1.1, true],
]

# DOORS: [x, floor top, height, [every lever that must be touched]]
const DOORS = [
	[3500, 380, 120, [Vector2(2120, 210), Vector2(3100, 520)]],
	[8520, 380, 120, [Vector2(7700, 220), Vector2(8420, 380)]],
]

# ENEMIES: [type, x, floor top, patrol distance, (stomps: a tougher, faster lab version)]
const ENEMIES = [
	["sword", 950, 380, 80],
	["sword", 2000, 380, 60, 2],
	["archer", 3300, 380, 0],
	["archer", 4500, 380, 0],
	["sword", 4850, 380, 60, 2],
	["archer", 5360, 220, 0],
	["guardian", 6900, 380, 40],
	["sword", 7250, 380, 80, 2],
	["archer", 7800, 220, 0],
	["guardian", 8000, 380, 60],
]

const CHESTS = [[220, 230], [2900, 520], [4500, 500], [7950, 160]]
const CHECKPOINTS = [[1480, 380], [3620, 380], [5250, 380], [6050, 300], [7060, 380], [8600, 380]]

# SECRETS: [left, top, right, bottom, covered?]
const SECRETS = [
	[120, 170, 320, 230, true],
	[2650, 440, 3150, 520, true],
	[4280, 440, 4750, 500, true],
]

# PEOPLE AND TERMINALS: [name, Kenney character number or image, x, floor top] (lines in npc.gd)
const NPCS = [
	["LOG 12", TERMINAL, 300, 380],
	["DR. VALE", 6, 520, 380],
	["LOG 40", TERMINAL, 3900, 380],
	["LOG 55", TERMINAL, 4860, 230],
	["LOG 41", TERMINAL, 5050, 380],
]

# SIGNS: [x, y, text, is it a warning?]
const SIGNS = [
	[-60, 320, "LAB 7  -  AUTHORISED STAFF ONLY", false],
	[1180, 345, "HIGH VOLTAGE", true],
	[2300, 320, "ELECTRIFIED FLOOR", true],
	[4900, 200, "EAST VENT  -  SEALED", true],
	[5320, 320, "CORE ACCESS", false],
	[7080, 320, "!! LOCKDOWN !!", true],
	[8660, 320, "UNIT 7", true],
]

# FLICKERING LIGHTS: [x, y, colour]
const LAMPS = [
	[180, 330, CYAN], [900, 300, CYAN], [1300, 310, RED], [1700, 320, PURPLE], [2470, 330, CYAN],
	[2900, 480, PURPLE], [3500, 240, RED], [4100, 330, Color("#FFE08A")], [4500, 470, Color("#FFE08A")],
	[5700, 260, CYAN], [6050, 260, CYAN], [6600, 100, CYAN], [7300, 330, RED], [7700, 190, RED],
	[8300, 330, RED], [8950, 220, RED], [9250, 300, CYAN], [9550, 220, RED],
]

# REGIONS: [name, left, top, right, bottom, night colour, music]
const REGIONS = [
	["ABANDONED ENTRANCE", -900, -400, 1500, 700, Color(0.45, 0.55, 0.85), L2],
	["EXPERIMENT CHAMBERS", 1500, -400, 3700, 700, Color(0.55, 0.45, 0.85), L2],
	["THE ARCHIVES", 3700, -400, 5300, 700, Color(0.5, 0.52, 0.72), QUIET],
	["THE POWER CORE", 5300, -400, 7000, 700, Color(0.45, 0.62, 0.95), L2],
	["SECURITY LOCKDOWN", 7000, -400, 8650, 700, Color(0.9, 0.4, 0.45), URGENT],
	["PROTOTYPE CHAMBER", 8650, -400, 10600, 700, Color(0.5, 0.45, 0.8), L2],
]


func _ready() -> void:
	build({
		"blocks": BLOCKS, "spikes": SPIKES, "movers": MOVERS, "zappers": ZAPPERS, "doors": DOORS,
		"enemies": ENEMIES, "chests": CHESTS, "checkpoints": CHECKPOINTS, "secrets": SECRETS,
		"npcs": NPCS, "signs": SIGNS, "lamps": LAMPS, "regions": REGIONS,
	})
	var camera = level.get_node("Player/Camera2D")   # stop at the rock at both ends
	camera.limit_left = -900
	camera.limit_right = 10600
