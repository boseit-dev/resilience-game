extends "res://level_builder.gd"

# RESILIENCE - LEVEL 1 EXPANSION
# Builds the newer parts of Level 1 when the level starts, from the tables below
# (the building code itself is shared, in level_builder.gd).
# To move something, change its numbers here. Every table is in world pixels
# (x grows to the right, y grows DOWN, the main ground top is y = 380).
#
#   Arrival Grounds   x -3600 .. -3040   (you appear at the rift)
#   Forgotten Paths   x -3040 .. 0       (Upper Ruins above, Sunken Hollow below)
#   Spike Garden, Thorn Rise, Hollow Spire, The Breach: the original level (x 0 .. 6140)
#   Warden's Approach x 6140 .. 7036
#   Warden's Hollow   x 7036 .. 7796     (the boss arena, moved right to make room)

# SOLID GROUND: [left, top, right, bottom, style]. Each one gets a collider and tile art.
# Styles (see STYLES below): frost = blue ice, stone = grey ruins, moss = green cave,
# violet = purple Breach rock, ember = red Warden rock.
const BLOCKS = [
	# Arrival Grounds + start of the Forgotten Paths (solid down to the bottom)
	[-3600, 380, -2900, 600, "frost"],
	[-2900, 380, -2600, 420, "frost"],     # thin floor over the Weeping Pit
	# The crack at x -2600 .. -2540 drops you into the Sunken Hollow
	[-2540, 380, -1960, 420, "stone"],     # ruined bridge (Sword Fighter 1)
	# The gap at x -1960 .. -1780 also drops into the Hollow
	[-1780, 380, -1560, 420, "stone"],
	[-1560, 380, 0, 600, "frost"],         # joins the original ground at x 0 (Sword Fighter 2)
	# Upper Ruins: broken stairs up, then a high walkway
	[-3000, 335, -2940, 349, "stone"],
	[-2910, 290, -2850, 304, "stone"],
	[-2820, 245, -2760, 259, "stone"],
	[-2730, 210, -2400, 230, "stone"],
	[-2320, 210, -1900, 230, "stone"],
	[-1850, 210, -1500, 230, "stone"],     # treasure at the far end, then drop back to the path
	# Sunken Hollow: a lower cave under the bridge
	[-2900, 520, -1560, 600, "moss"],
	[-1950, 473, -1905, 485, "moss"],      # two steps to climb out through the gap
	[-1880, 426, -1840, 438, "moss"],
	# Thorn Rise: a high treasure ledge (only a bounce pad gets you up the first time)
	[1600, 258, 1660, 272, "moss"],        # place a pad well to the left of it, then run right
	# Hollow Spire: the hidden hideout and the Crystal Drop floor
	[3722, -20, 3800, -6, "frost"],        # hideout: double jump straight up at the right end of Jump Platform 2
	[3200, 430, 3380, 600, "frost"],       # Crystal Drop: spikes at the bottom of the shaft
	# The Breach: archer perch and the hidden tunnel under floor C
	[4225, 98, 4300, 112, "violet"],
	[4990, 330, 5380, 600, "violet"],      # tunnel floor (drop into the gap between B and C)
	[4960, 260, 4990, 600, "violet"],      # tunnel's back wall
	[5050, 296, 5085, 308, "violet"],      # step to climb back out (then double jump onto floor C)
	# Warden's Approach
	[6140, 170, 6560, 600, "ember"],       # Guardian
	[6220, -240, 6330, 124, "ember"],      # rock overhang: a wooden barrier blocks the way under it
	[6560, 250, 6800, 600, "ember"],       # final checkpoint, Guardian 2
	[6760, 150, 6830, 164, "ember"],       # archer perch above the drop
	[6800, 300, 7036, 600, "ember"],       # then drop into the Warden's arena
	[6860, -240, 6960, 254, "ember"],      # second overhang + barrier
]

# WOODEN BARRIERS: [x, floor top, height]. Dash (Shift) into them to smash them.
const BARRIERS = [
	[5240, 330, 70],    # Breach tunnel, in front of the chest
	[6275, 170, 46],    # Warden's Approach, under the first overhang
	[6910, 300, 46],    # Warden's Approach, under the second overhang
]

# The original level's tiles are restyled in these x ranges, so each area looks different
const RESTYLE = [
	[1600, 2600, "moss"],     # Thorn Rise: overgrown
	[4000, 6140, "violet"],   # The Breach: purple rock
	[7036, 7800, "ember"],    # Warden's Hollow: red rock
]

# PROPS: [kind, x, y]. y is the floor top (for "vine": the ceiling it hangs from).
const PROPS = [
	["grave", -2660, 210], ["grave", -2575, 210], ["grave", -2230, 210], ["grave", -2045, 210], ["grave", -1720, 210],
	["grave", -1000, 380], ["grave", -930, 380], ["fence", -620, 380], ["fence", -600, 380],
	["vine", -2480, 420], ["vine", -2390, 420], ["vine", -2270, 420], ["vine", -2140, 420], ["vine", -2030, 420],
	["mushroom", -2450, 520], ["mushroom", -2180, 520], ["mushroom", -1995, 520], ["mushroom", -1640, 520],
	["pumpkin", -2350, 520], ["pumpkin", -1700, 520], ["flower", -2420, 520], ["flower", -2100, 520], ["flower", -1900, 520],
	["flower", 1990, 290], ["flower", 2210, 290], ["flower", 1628, 258], ["mushroom", 2300, 290],
	["fence", 6400, 170], ["fence", 6416, 170], ["grave", 6500, 170], ["fence", 6640, 250], ["grave", 6720, 250],
	["fence", 6990, 300], ["fence", 7006, 300],
]
# SPIKES: [x, floor top]. Each strip is 64 px wide, like the Spike Garden ones.
const SPIKES = [
	[-2840, 520], [-2776, 520], [-2712, 520],   # the Weeping Pit
	[3256, 430], [3320, 430],                   # the Crystal Drop
]

# ENEMIES: [type, x, floor top, patrol distance]
const ENEMIES = [
	["sword", -2200, 380, 120],
	["sword", -1200, 380, 140],
	["sword", -2050, 520, 80],     # Sunken Hollow
	["sword", 2120, 290, 70],      # Thorn Rise
	["archer", 3680, 130, 0],      # Hollow Spire: guards Jump Platform 2 (land on it!)
	["archer", 4262, 98, 0],       # The Breach pair: archer above...
	["sword", 4120, 170, 60],      # ...and a sword fighter below
	["guardian", 6430, 170, 80],   # The Breach exit, just past the first wooden barrier
	["guardian", 6690, 250, 50],   # Warden's Approach: the hard encounter
	["archer", 6795, 150, 0],
]

# CHESTS: [x, floor top]
const CHESTS = [
	[-1540, 210],   # Upper Ruins
	[-2300, 520],   # Sunken Hollow
	[1630, 258],    # Thorn Rise ledge
	[3765, -20],    # Spire Hideout
	[5340, 330],    # Breach tunnel
]

# CHECKPOINTS: [x, floor top]
const CHECKPOINTS = [
	[-1300, 380],   # middle of the Forgotten Paths
	[6600, 250],    # Warden's Approach (the final checkpoint before the Warden)
]

# SECRETS: [left, top, right, bottom, covered?]. Covered ones are hidden under darkness
# that fades away when you step inside. Either way "SECRET FOUND" shows the first time.
const SECRETS = [
	[3712, -60, 3810, -4, false],   # Spire Hideout (hidden just above the screen)
	[4960, 262, 5380, 334, true],   # Breach tunnel
]

# SIGNS: [x, y, text, is it a warning?]
const SIGNS = [
	[-3000, 396, "FORGOTTEN PATHS", false],
	[-2998, 337, "UP: OLD RUINS", false],
	[-2640, 396, "CRACK: THE HOLLOW", false],
	[-2896, 500, "THE WEEPING PIT  -  TURN BACK", true],
	[3254, 190, "!! CRYSTAL DROP - NO WAY BACK !!", true],
	[6150, 186, "WARDEN'S APPROACH", false],
]

# CRYSTALS: [x, y, colour]. Little glowing lights to make each area look different.
const CRYSTALS = [
	[-2700, 180, Color("#BFD8FF")], [-2100, 180, Color("#BFD8FF")], [-1650, 180, Color("#BFD8FF")],
	[-2500, 505, Color("#7CFFB0")], [-2150, 505, Color("#7CFFB0")], [-1700, 505, Color("#7CFFB0")],
	[3290, 415, Color("#FF7A9A")], [5200, 315, Color("#C08BFF")], [3750, -40, Color("#FFE08A")],
	[6400, 155, Color("#FF6A5A")], [6900, 285, Color("#FF6A5A")],
]

# REGIONS: [name, left, top, right, bottom, darkness colour]. The first match wins,
# so the small branch areas come before the big ones. An empty name shows no banner.
const REGIONS = [
	["UPPER RUINS", -3000, -200, -1500, 300, Color(0.74, 0.8, 0.98)],
	["SUNKEN HOLLOW", -2900, 430, -1560, 700, Color(0.5, 0.72, 0.62)],
	["", -3600, -400, -3040, 700, NIGHT],
	["FORGOTTEN PATHS", -3040, -400, 0, 700, Color(0.6, 0.66, 0.8)],
	["SPIKE GARDEN", 0, -400, 1600, 700, NIGHT],
	["THORN RISE", 1600, -400, 2600, 700, Color(0.7, 0.6, 0.84)],
	["HOLLOW SPIRE", 2600, -400, 4000, 700, Color(0.56, 0.66, 0.92)],
	["THE BREACH", 4000, -400, 6560, 700, Color(0.62, 0.52, 0.82)],
	["WARDEN'S APPROACH", 6560, -400, 7036, 700, Color(0.6, 0.48, 0.55)],
	["WARDEN'S HOLLOW", 7036, -400, 8000, 700, Color(0.56, 0.48, 0.52)],
]



func _ready() -> void:
	build({
		"blocks": BLOCKS, "barriers": BARRIERS, "restyle": RESTYLE, "props": PROPS,
		"spikes": SPIKES, "enemies": ENEMIES, "chests": CHESTS, "checkpoints": CHECKPOINTS,
		"secrets": SECRETS, "signs": SIGNS, "crystals": CRYSTALS, "regions": REGIONS,
	})
