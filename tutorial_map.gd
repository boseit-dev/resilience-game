extends "res://level_builder.gd"

# RESILIENCE - TUTORIAL MAP
# The training course, built from the tables below when the tutorial starts
# (the building code is in level_builder.gd). The rules (training powers, lives that
# refill, the TUTORIAL COMPLETE screen) are in tutorial.gd.
# World pixels: x grows to the right, y grows DOWN, the main floor top is y = 380.
#
#   1 Moving          x     0 .. 700
#   2 Jumping         x   700 .. 1600
#   3 Bounce Pads     x  1600 .. 2600
#   4 Double Jump     x  2600 .. 3800
#   5 Dash            x  3800 .. 4600
#   6 Combat          x  4600 .. 5600
#   7 Lives and checkpoints  x 5600 .. 6200
#   8 Final challenge x  6200 .. 7700

# SOLID GROUND: [left, top, right, bottom, style]
const BLOCKS = [
	[-700, 120, -40, 600, "stone"],       # solid rock to the left of the start (tutorial.gd stops the camera at its edge)
	# 1 Moving
	[-40, 380, 700, 600, "frost"],
	# 2 Jumping: two small safe gaps (fall in and just jump out) and a step
	[700, 440, 820, 600, "frost"],         # spiky gap 1 (60 deep)
	[820, 380, 1050, 600, "frost"],
	[1050, 320, 1250, 600, "frost"],       # step up
	[1250, 440, 1380, 600, "frost"],       # spiky gap 2
	[1380, 380, 1600, 600, "frost"],
	# 3 Bounce Pads: a ledge too high to jump (100 px), easy with a pad
	[1600, 380, 2000, 600, "moss"],
	[2000, 280, 2300, 600, "moss"],
	[2300, 380, 2600, 600, "moss"],
	# 4 Double Jump: a 140 px step, then a 280 px safe gap
	[2600, 380, 2900, 600, "moss"],
	[2900, 240, 3100, 600, "moss"],
	[3100, 380, 3300, 600, "moss"],
	[3300, 440, 3580, 600, "moss"],        # spiky gap (60 deep)
	[3580, 380, 3800, 600, "moss"],
	# 5 Dash: a low ceiling over a gap (too low to jump across), then a wooden barrier
	[3800, 380, 4000, 600, "violet"],
	[4000, 430, 4120, 600, "violet"],      # spiky gap (50 deep), a dash is just long enough
	[4120, 380, 4600, 600, "violet"],
	[3940, 60, 4400, 330, "violet"],     # the low ceiling
	# 6 Combat + 7 Lives and checkpoints
	[4600, 380, 6200, 600, "stone"],
	# 8 Final challenge: spike pit, an enemy, a pad + double jump wall, a barrier
	[6200, 380, 6300, 600, "ember"],
	[6300, 520, 6560, 600, "ember"],       # spike pit floor
	[6560, 380, 6900, 600, "ember"],
	[6900, 190, 7150, 600, "ember"],       # 190 px wall: Bounce Pad, then Double Jump at the top
	[7150, 380, 7700, 600, "ember"],
	[7250, 60, 7450, 330, "ember"],      # low ceiling over the last barrier
	[7700, 120, 8400, 600, "stone"],      # solid rock after the finish
]

# WOODEN BARRIERS: [x, floor top, height]
const BARRIERS = [
	[4300, 380, 50],
	[7350, 380, 50],
]

# SPIKES: [x, floor top]. Every gap has spikes (playtest feedback); a lantern before each one.
const SPIKES = [
	[730, 440], [790, 440],                                       # 2 Jumping, gap 1
	[1282, 440], [1346, 440],                                     # 2 Jumping, gap 2
	[3332, 440], [3396, 440], [3460, 440], [3524, 440], [3548, 440],   # 4 Double Jump gap
	[4030, 430], [4090, 430],                                     # 5 Dash gap
	[5900, 380],                                # optional: touch them to see a respawn
	[6340, 520], [6404, 520], [6468, 520], [6532, 520],
]

# ENEMIES: [type, x, floor top, patrol distance]. The dummy is added by tutorial.gd.
const ENEMIES = [
	["sword", 5050, 380, 80],
	["archer", 5420, 380, 0],
	["sword", 6700, 380, 50],
]

# CHECKPOINTS: one at the start of every section, so a fall never sends you far back
const CHECKPOINTS = [
	[620, 380],     # 2 Jumping
	[1640, 380],    # 3 Bounce Pads
	[2640, 380],    # 4 Double Jump
	[3840, 380],    # 5 Dash
	[4640, 380],    # 6 Combat (playtest feedback: a lantern before the enemies)
	[5680, 380],
	[6150, 380],
]

# SIGNS: [x, y, text, is it a warning?]
const SIGNS = [
	[300, 330, "Walk right to begin", false],
	[760, 300, "W / SPACE / UP  to jump over the spikes.", false],
	[1060, 270, "Jump up the step", false],
	[1660, 290, "E places a BOUNCE PAD in front of you.", false],
	[1640, 302, "Walk onto it and it throws you up.", false],
	[1640, 324, "Pads stay where you put them: you can't pick them up.", false],
	[1640, 336, "You only carry 3, so think before you place one.", false],
	[1720, 356, "Leave a run-up: too close to the wall and you bonk it", true],
	[2620, 300, "DOUBLE JUMP: press jump again in mid-air.", false],
	[2620, 312, "Jump at the very top of your first jump to go highest.", false],
	[3140, 330, "This gap is too wide for one jump", false],
	[3810, 342, "SHIFT to DASH: a fast, straight burst.", false],
	[3810, 354, "The ceiling is too low to jump. Dash across!", false],
	[4150, 350, "Dashing also smashes wooden crates", false],
	[4640, 300, "Jump on an enemy's HEAD to defeat it.", false],
	[4640, 312, "This one is a harmless dummy. Try it!", false],
	[4900, 300, "Real enemies walk about. Touching their SIDES costs a life.", true],
	[5250, 300, "Archers shoot. Jump over the arrows.", true],
	[5620, 290, "Top left: your 5 LIVES.", false],
	[5620, 302, "Lanterns are CHECKPOINTS: you come back to the last one you touched.", false],
	[5620, 314, "Here your lives refill, so it's safe to try the spikes.", false],
	[6210, 300, "FINAL CHALLENGE: use everything!", false],
	[6800, 300, "Too high for a double jump alone: pad first", true],
]

const CRYSTALS = [
	[1800, 250, Color("#7CFFB0")], [2150, 250, Color("#7CFFB0")], [3000, 210, Color("#7CFFB0")],
	[4200, 345, Color("#C08BFF")], [5680, 330, Color("#BFD8FF")], [6420, 490, Color("#FF6A5A")],
	[7000, 160, Color("#FF6A5A")], [7600, 340, Color("#FFE08A")],
]

const PROPS = [
	["flower", 1700, 380], ["mushroom", 1900, 380], ["flower", 2150, 280], ["mushroom", 2450, 380],
	["flower", 2700, 380], ["pumpkin", 3000, 240], ["mushroom", 3650, 380],
	["vine", 4000, 330], ["vine", 4250, 330],
	["fence", 4620, 380], ["fence", 4636, 380], ["grave", 5550, 380], ["fence", 5600, 380],
	["grave", 6600, 380], ["fence", 7180, 380], ["fence", 7196, 380],
]

# REGIONS: the night colour of each section (tutorial.gd shows the section titles)
const REGIONS = [
	["", -100, -400, 1600, 700, NIGHT],
	["", 1600, -400, 3800, 700, Color(0.6, 0.76, 0.66)],
	["", 3800, -400, 4600, 700, Color(0.66, 0.56, 0.86)],
	["", 4600, -400, 6200, 700, Color(0.7, 0.72, 0.84)],
	["", 6200, -400, 7800, 700, Color(0.72, 0.52, 0.55)],
]


func _ready() -> void:
	build({
		"blocks": BLOCKS, "barriers": BARRIERS, "spikes": SPIKES, "enemies": ENEMIES,
		"checkpoints": CHECKPOINTS, "signs": SIGNS, "crystals": CRYSTALS, "props": PROPS,
		"regions": REGIONS,
	})
	# The training dummy: a sword fighter that stands still and can't hurt you
	var dummy = ENEMY_SCENES["sword"].instantiate()
	dummy.position = Vector2(4760, 380)
	dummy.patrol_distance = 0
	dummy.harmless = true
	add_child(dummy)
