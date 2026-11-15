extends "res://level_builder.gd"

# RESILIENCE - LEVEL 3: THE FRACTURED CAVERNS (the map) - the final level
# Built from the tables below when the level starts (the building code is in level_builder.gd,
# the puzzles are in puzzles/). Rules (lives, pads, checkpoints, the HUD) are level_1.gd.
# The final boss is null_architect.tscn and the opening is lab_intro.gd (both placed in level_3.tscn).
# World pixels: x grows to the right, y grows DOWN, the main floor top is y = 380.
#
#   1 Cavern Entrance       x  -900 ..  1600  falling rocks, broken bridge, first light puzzle
#   2 Crystal Maze          x  1600 ..  4200  upper and lower routes; a lever on each opens the door
#   3 Ancient Mechanisms    x  4200 ..  6250  pressure plates, then the crystal power network
#   4 Collapsing Depths     x  6250 ..  7800  crumbling ledges, falling rocks, a Double Jump + Dash gap
#   5 Forgotten Sanctuary   x  7800 ..  9400  the symbol puzzle (clues carved on the walls)
#   6 Crystal Trials        x  9400 .. 13400  light, plates, timed gate, ledges, then the final trial
#   7 The Core              x 13400 .. 14900  the Null Architect (the final boss)
#   8 The Collapse          x 14900 .. 18800  after the boss: run to the gateway before the core falls
#
# PUZZLE SOLUTIONS (for developers):
#   Entrance light:  left prism RIGHT, right prism UP
#   Maze door:       a lever on the lower route AND one on the upper route
#   Plates:          push one stone into the gap, push the other over it onto the far plate
#   Power:           power the DOOR first (it stays open), take that power back, power LIFT + BARRIER
#   Symbols:         MOON, FLAME, CRYSTAL, GATE (carvings with 1-4 dots; the Keeper's riddle)
#   Trial 1 light:   right, down, right, up
#   Trial 2 plates:  first stone into the first gap, second stone over it into the second gap
#   Trial 3 timed:   lever, moving stone, pillar, DASH under the low rock (10 s)
#   Final trial:     plates again -> light (left, down, left [middle prism], left, up) switches the
#                    barrier off -> put a Bounce Pad by the wall FIRST, pull the lever, pad + Double
#                    Jump up the wall, Dash under the rock (9 s)
#   Null Architect:  12 stomps; at the last heart it floats up: Bounce Pad + Double Jump to the first
#                    ledge, Double Jump over the beam, Dash under the rock, stomp its core

const QUIET = preload("res://assets/music/intro_theme.wav")
const CAVES = preload("res://assets/music/level_3_theme.ogg")
const MACHINES = preload("res://assets/music/level_2_theme.ogg")
const DANGER = preload("res://assets/music/caverns_danger.ogg")
const SANCTUARY = preload("res://assets/music/sanctuary_theme.ogg")
const ESCAPE_MUSIC = preload("res://assets/music/level_1_theme.ogg")
const ARCHITECT = preload("res://null_architect.gd")
const WALL_SPEED = 95.0          # the collapse chasing you during the escape (pixels a second)
const ESCAPE_START = Vector2(14960, 380)
const TABLET = "res://assets/kenney_pixel-platformer/Tiles/tile_0130.png"
const CYAN = Color("#7FE7FF")
const VIOLET = Color("#B98CFF")
const PINK = Color("#FF8AD8")
const GOLD = Color("#FFE08A")
const CRYSTAL_DOOR = [Color(0.75, 0.6, 1.3), Color(0.45, 0.4, 0.7)]
const ALWAYS_ON = [100.0, 0.01]   # beam timing for a barrier that never switches off by itself

# SOLID GROUND: [left, top, right, bottom, style]
const BLOCKS = [
	# 1 Cavern Entrance
	[-900, 100, -200, 700, "cave"],
	[-200, 0, 600, 220, "cave"],             # low ceiling: a narrow way in
	[-200, 380, 820, 700, "cave"],
	[820, 520, 1000, 700, "cave"],           # under the broken bridge (spikes)
	[1000, 380, 1600, 700, "cave"],
	[1100, 0, 1500, 180, "cave"],
	[1500, 0, 1600, 260, "cave"],            # above the crystal door
	# 2 Crystal Maze
	[1600, 380, 2300, 440, "cave"],          # thin floor over the dead end
	[1600, 440, 2000, 540, "cave"],
	[1600, 540, 2420, 700, "cave"],          # dead end floor
	[2420, 380, 2900, 410, "violet"],        # upper route
	[3150, 380, 3380, 410, "violet"],
	[2420, 540, 3380, 700, "cave"],          # lower route
	[2420, 100, 2600, 250, "cave"],          # upper ceiling, with a hidden room in it
	[2600, 100, 2800, 190, "cave"],
	[2700, 230, 2800, 250, "cave"],          # hidden room ledge
	[2800, 100, 3380, 250, "cave"],
	[3380, 485, 3440, 700, "cave"],          # steps up from the lower route
	[3440, 430, 3500, 700, "cave"],
	[3500, 380, 4200, 700, "cave"],
	[4050, 0, 4200, 260, "cave"],            # above the maze door
	# 3 Ancient Mechanisms
	[4200, 380, 4560, 700, "ruin"],
	[4558, 408, 4590, 700, "ruin"],          # the gap a stone fits in (plate at the bottom)
	[4590, 380, 5520, 700, "ruin"],
	[4200, 0, 5000, 200, "ruin"],
	[4900, 0, 5000, 260, "ruin"],            # above door 2
	[5400, -100, 6250, 30, "ruin"],          # machine hall ceiling
	[5520, 150, 6250, 700, "ruin"],          # the high shelf (only the lift gets you up)
	# 4 Collapsing Depths
	[6250, 640, 7760, 700, "cave"],          # the pit (spikes all along)
	[6750, 260, 6820, 700, "cave"],          # pillar 1
	[6900, 120, 6960, 135, "cave"],          # side ledge (chest)
	[7215, 260, 7285, 700, "cave"],          # pillar 2 (checkpoint)
	[7400, 120, 7480, 700, "cave"],          # wall: Double Jump up
	# 5 Forgotten Sanctuary
	[7760, 380, 9400, 700, "ruin"],
	[7800, -200, 9400, 60, "ruin"],
	[8300, 230, 8450, 245, "ruin"],          # hidden room (a carving and a chest)
	[9300, 60, 9400, 260, "ruin"],           # above the sanctuary door
	# 6 Crystal Trials
	[9400, 380, 9620, 700, "violet"],        # trial 1: light (a pit in the middle)
	[9620, 500, 9900, 700, "violet"],
	[9900, 380, 10400, 700, "violet"],
	[9400, -100, 10100, 180, "cave"],
	[10040, -100, 10100, 260, "cave"],       # above door 5
	[10400, 408, 10432, 700, "violet"],      # trial 2: plates (two gaps)
	[10432, 380, 10560, 700, "violet"],
	[10560, 408, 10592, 700, "violet"],
	[10592, 380, 10900, 700, "violet"],
	[10100, -100, 10800, 200, "cave"],
	[10740, -100, 10800, 260, "cave"],       # above door 6
	[10900, 600, 11340, 700, "cave"],        # trial 3: timed gate (spikes below)
	[11180, 320, 11230, 700, "violet"],      # pillar
	[11230, 150, 11340, 290, "cave"],        # low rock: dash under it
	[11340, 320, 11700, 700, "violet"],
	[11440, -100, 11500, 200, "cave"],       # above door 7
	[11700, 600, 11950, 700, "cave"],        # trial 4: ledges (spikes below)
	[11760, 140, 11840, 700, "violet"],
	[11840, -100, 11950, 110, "cave"],       # low rock: dash under it
	[11950, 140, 12050, 700, "violet"],
	[12050, 380, 12250, 700, "violet"],      # final trial: plates
	[12250, 408, 12282, 700, "violet"],
	[12282, 380, 12560, 700, "violet"],
	[12560, 500, 12800, 700, "violet"],      # final trial: light (a pit)
	[12800, 380, 13050, 700, "violet"],
	[12420, -100, 12930, 180, "cave"],      # (open above the wall: room for the pad climb)
	[13050, 170, 13130, 700, "violet"],      # the wall: Bounce Pad + Double Jump
	[13130, 600, 13240, 700, "cave"],
	[13130, -100, 13240, 140, "cave"],       # low rock: dash under it
	[13240, 170, 13560, 700, "violet"],      # final crystal chamber
	[13350, -100, 13400, 50, "cave"],        # above door 9
	# 7 The Core (final boss arena)
	[13560, 380, 14900, 700, "cave"],
	[13760, 310, 13800, 700, "cave"],        # pillars to dodge shockwaves on
	[14760, 310, 14800, 700, "cave"],
	[13990, 190, 14090, 205, "violet"],      # final attack: Bounce Pad + Double Jump up here,
	[14260, 190, 14340, 205, "violet"],      # Double Jump over the beam to here,
	[14340, 40, 14450, 160, "cave"],         # Dash under this rock,
	[14450, 190, 14550, 205, "violet"],      # and stomp the core above this ledge
	[13560, -300, 14900, -60, "cave"],
	[14860, -300, 14900, 180, "cave"],       # above the escape door
	# 8 The Collapse (escape)
	[14900, 380, 15200, 700, "cave"],
	[15200, 600, 15900, 700, "cave"],        # pit under the crumbling bridge
	[15900, 380, 16330, 700, "cave"],
	[16330, 600, 16620, 700, "cave"],
	[16620, 170, 17200, 700, "cave"],        # high ground (beams)
	[16620, -100, 17200, 50, "cave"],
	[17200, 380, 17500, 700, "cave"],
	[17500, 600, 17610, 700, "cave"],
	[17500, 150, 17610, 350, "cave"],        # low rock: dash under it
	[17610, 380, 18800, 700, "cave"],
	[18800, -300, 19400, 700, "cave"],]

# SPIKES: [x, floor top] (the long pit is added in _ready)
const SPIKES = [
	[850, 520], [910, 520], [970, 520],
	[2050, 540], [2110, 540],
	[10920, 600], [10984, 600], [11048, 600], [11112, 600], [11176, 600], [11240, 600], [11304, 600],
	[11720, 600], [11784, 600], [11848, 600], [11912, 600],
	[13150, 600], [13214, 600],
	[16360, 600], [16424, 600], [16488, 600], [16552, 600], [16616, 600], [17520, 600], [17584, 600],
]

# MOVING PLATFORMS: [x, top, width, travel x, travel y, seconds, (moving at the start?)]
const MOVERS = [
	[2960, 372, 56, 120, 0, 2.0],            # across the upper route's gap
	[5450, 370, 72, 0, -232, 2.5, false],    # mover 1: the machine hall lift (needs power; tops out above the shelf so you step down)
	[10990, 360, 64, 120, 0, 1.4],           # trial 3
	[13900, 290, 64, 0, -80, 2.0, false, "boss_mover"],    # the Null Architect starts these in phase 2
	[14600, 250, 64, -140, 0, 2.4, false, "boss_mover"],
]

# ELECTRIC BEAMS: [x, y, length, vertical?, on s, off s, delay, boss arena?]
const ZAPPERS = [
	[5580, 30, 120, true, ALWAYS_ON[0], ALWAYS_ON[1], 0.0],   # zapper 0, 1: the machine hall barrier
	[5660, 30, 120, true, ALWAYS_ON[0], ALWAYS_ON[1], 0.0],
	[12910, 180, 200, true, ALWAYS_ON[0], ALWAYS_ON[1], 0.0], # zapper 2: barrier before the last lever
	[13680, 200, 180, true, 1.0, 2.2, 0.0, true],             # boss arena beams (from phase 2)
	[14650, 200, 180, true, 1.0, 2.2, 1.1, true],
	[14230, 100, 90, true, ALWAYS_ON[0], ALWAYS_ON[1], 0.0, "finale_zapper"],   # final attack: double jump over it
	[16800, 50, 120, true, 0.8, 1.3, 0.0],                    # escape: energy bursts
	[16960, 50, 120, true, 0.8, 1.3, 0.7],
	[17100, 50, 120, true, 0.8, 1.3, 0.3],
]

# DOORS: [x, floor top, height, [levers], (colours)]  (puzzles open them by number)
const DOORS = [
	[1540, 380, 120, [], CRYSTAL_DOOR],                                    # 0 entrance light puzzle
	[4130, 380, 120, [Vector2(2650, 540), Vector2(3300, 380)], CRYSTAL_DOOR],   # 1 maze: two levers
	[4950, 380, 120, [], CRYSTAL_DOOR],                                    # 2 plates
	[6200, 150, 120, [], CRYSTAL_DOOR],                                    # 3 power network
	[9350, 380, 120, [], CRYSTAL_DOOR],                                    # 4 symbols
	[10070, 380, 120, [], CRYSTAL_DOOR],                                   # 5 trial 1
	[10770, 380, 120, [], CRYSTAL_DOOR],                                   # 6 trial 2
	[11470, 320, 120, [], CRYSTAL_DOOR],                                   # 7 trial 3 (timed)
	[12420, 380, 200, [], CRYSTAL_DOOR],                                   # 8 final plates
	[13375, 170, 120, [], CRYSTAL_DOOR],                                   # 9 final timed gate
	[14880, 380, 200, [], CRYSTAL_DOOR],                                   # 10 the way out (after the boss)
]

const PUZZLES = [
	{"type": "beam", "opens": [["door", 0]], "area": [1000, 0, 1600, 400], "reset": Vector2(1300, 380),
		"emitter": [Vector2(1180, 190), 1], "receiver": Vector2(1400, 190),
		"prisms": [[Vector2(1180, 362), 2], [Vector2(1400, 362), 0]],
		"hints": ["The door wants the light.", "Each crystal sends the light where its arrow points. E turns it.", "Point the left crystal RIGHT and the right crystal UP."],
		"solved_text": "THE CRYSTAL DOOR OPENS"},
	{"type": "plate", "opens": [["door", 2]], "area": [4200, 0, 5000, 400], "reset": Vector2(4250, 380),
		"plates": [Vector2(4574, 408), Vector2(4820, 380)], "stones": [Vector2(4380, 380), Vector2(4460, 380)],
		"hints": ["Two plates. You are too light to press them.", "A stone could fill the gap, and the other could roll over it.", "Push one stone into the gap, then push the other over it onto the far plate."],
		"solved_text": "THE PLATES HOLD"},
	{"type": "power", "area": [5000, -100, 6250, 400], "energy": 2, "past_x": 6000, "reset": Vector2(5040, 380),
		"machines": [[Vector2(5110, 380), "LIFT", [["mover", 1]]], [Vector2(5180, 380), "BARRIER", [["zapper", 0], ["zapper", 1]]],
			[Vector2(5250, 380), "DOOR", [["door", 3]], true]],
		"hints": ["Three machines, one crystal.", "The engineer said a door that has had power stays open.", "Power the DOOR, take it back, then power the LIFT and the BARRIER."]},
	{"type": "symbol", "opens": [["door", 4]], "area": [8450, -200, 9400, 400], "reset": Vector2(8540, 380),
		"stones": [[Vector2(8640, 380), "CRYSTAL"], [Vector2(8720, 380), "MOON"], [Vector2(8800, 380), "FLAME"], [Vector2(8880, 380), "GATE"]],
		"order": ["MOON", "FLAME", "CRYSTAL", "GATE"],
		"clues": [[Vector2(7980, 300), "MOON", 1], [Vector2(8560, 200), "FLAME", 2], [Vector2(9150, 300), "CRYSTAL", 3], [Vector2(8400, 190), "GATE", 4]],
		"hints": ["The walls remember the order.", "Count the dots under each carving on the walls.", "MOON, then FLAME, then CRYSTAL, then GATE."],
		"solved_text": "THE SANCTUARY OPENS"},
	{"type": "beam", "opens": [["door", 5]], "area": [9400, -100, 10100, 600], "reset": Vector2(9440, 380),
		"emitter": [Vector2(9500, 190), 1], "receiver": Vector2(9888, 230),
		"prisms": [[Vector2(9500, 362), 2], [Vector2(9632, 362), 3], [Vector2(9632, 482), 1], [Vector2(9888, 482), 2]],
		"hints": ["Light can fall as well as fly.", "The beam has to go down into the pit and come back up.", "In the order the light reaches them: right, down, right, up."],
		"solved_text": "FIRST TRIAL PASSED"},
	{"type": "plate", "opens": [["door", 6]], "area": [10100, -100, 10800, 400], "reset": Vector2(10140, 380),
		"plates": [Vector2(10416, 408), Vector2(10576, 408)], "stones": [Vector2(10220, 380), Vector2(10300, 380)],
		"hints": ["Two gaps, two plates, two stones.", "The far gap can only be reached over the near one.", "First stone into the first gap, second stone over it into the second gap."],
		"solved_text": "SECOND TRIAL PASSED"},
	{"type": "timed", "opens": [["door", 7]], "area": [10800, -100, 11500, 700], "lever": Vector2(10850, 380), "seconds": 10.0, "past_x": 11480,
		"hints": ["Pull the lever, then hurry.", "The rock over the last gap is too low to jump under: dash.", "Lever, the moving stone, the pillar, then DASH under the low rock."]},
	{"type": "plate", "opens": [["door", 8]], "area": [12050, -100, 12420, 400], "reset": Vector2(12070, 380),
		"plates": [Vector2(12266, 408), Vector2(12380, 380)], "stones": [Vector2(12120, 380), Vector2(12180, 380)],
		"hints": ["You have done this before.", "One stone fills the gap.", "First stone into the gap, the second over it onto the plate."],
		"solved_text": "THE LAST DOOR OPENS"},
	{"type": "beam", "opens": [["zapper", 2]], "area": [12420, -100, 12900, 600], "reset": Vector2(12450, 380),
		"emitter": [Vector2(12840, 190), 1], "receiver": Vector2(12572, 230),
		"prisms": [[Vector2(12840, 362), 1], [Vector2(12788, 362), 0], [Vector2(12788, 482), 3], [Vector2(12680, 482), 3], [Vector2(12572, 482), 0]],
		"hints": ["The light must cross the pit and climb out.", "A crystal in the middle can pass the light along too.", "Left, down, left, left, up."],
		"solved_text": "THE BARRIER FADES"},
	{"type": "timed", "opens": [["door", 9]], "area": [12900, -100, 13400, 700], "lever": Vector2(12935, 380), "gives_pad": true, "seconds": 9.0, "past_x": 13390,
		"hints": ["Prepare before you pull.", "A Bounce Pad placed BEFORE pulling the lever saves time.", "Pad by the wall, lever, pad + Double Jump up, then DASH under the rock."]},
]

# ENEMIES: [type, x, floor top, patrol distance, (stomps: a tougher, faster version)]
const ENEMIES = [
	["sword", 600, 380, 60],
	["sword", 1900, 380, 60, 2],
	["sword", 2850, 540, 60, 2],             # lower route...
	["archer", 3220, 380, 0],                # ...with an archer above on the upper route
	["guardian", 3150, 540, 30],             # guarding the narrow lower passage
	["sword", 3750, 380, 80, 2],             # attacked from both sides
	["archer", 4000, 380, 0],
	["archer", 5330, 380, 0],                # by the lift
	["guardian", 5900, 150, 40],             # between the barrier and the door
	["archer", 6785, 260, 0],                # on pillar 1, shooting at the crumbling ledges
	["sword", 7900, 380, 60, 2],
]

const CHESTS = [[2750, 230], [2300, 540], [6930, 120], [8400, 230], [11000, 600 - 400]]
const CHECKPOINTS = [[1650, 380], [3560, 380], [5050, 380], [6235, 150], [7272, 260], [7820, 380], [9450, 380],
	[10860, 380], [12070, 380], [12860, 380], [13480, 170], [ESCAPE_START.x, ESCAPE_START.y], [16700, 170]]

# SECRETS: [left, top, right, bottom, covered?]
const SECRETS = [[2600, 190, 2800, 250, true], [8300, 160, 8450, 230, true]]

# PEOPLE: [name, Kenney character number or image, x, floor top] (lines in npc.gd)
const NPCS = [
	["MIRA", 4, 200, 380],
	["MINER LOG", TABLET, 2200, 540],
	["ENGINEER LOG", TABLET, 4975, 380],
	["THE KEEPER", 8, 8180, 380],
	["VALE'S LOG", TABLET, 7900, 380],          # what happened to Dr. Vale
	["TABLET", TABLET, 9200, 380],
	["TRIAL STONE", TABLET, 9380, 380],
]

const CRUMBLES = [
	[6400, 175, 48], [6520, 205, 48], [6640, 235, 48],                 # down to pillar 1
	[7560, 250, 48], [7670, 310, 48],                                  # down off the wall
	[11580, 280, 40], [11680, 240, 40],                                # trial 4
	[15270, 360, 48], [15390, 340, 48], [15510, 320, 48], [15630, 340, 48], [15750, 360, 48],   # escape bridge
	[16410, 310, 44], [16520, 240, 44],                                # escape climb
]
# FALLING ROCKS: [x, floor top, every n seconds]
const FALLING_ROCKS = [[350, 380, 3.0], [700, 380, 2.4], [2200, 540, 2.6], [6520, 205, 2.8], [7250, 260, 3.2], [7670, 310, 2.6],
	[16000, 380, 1.6], [16180, 380, 1.9], [17350, 380, 1.7], [17800, 380, 1.5], [18000, 380, 1.8]]

const SIGNS = [
	[-120, 330, "THE FRACTURED CAVERNS", false],
	[300, 330, "LOOSE ROCK", true],
	[2310, 330, "UPPER WAY  /  LOWER WAY", false],
	[1700, 470, "DEAD END", true],
	[4220, 330, "ANCIENT MECHANISMS", false],
	[6270, 110, "THE DEPTHS  -  DO NOT STOP", true],
	[7830, 330, "SANCTUARY", false],
	[13250, 130, "THE CORE", false],
	[18420, 330, "THE GATEWAY", false],
]

# GLOWING CRYSTALS (also landmarks): [x, y, colour]
const CRYSTALS = [
	[60, 340, CYAN], [1050, 340, VIOLET], [1300, 200, PINK], [2330, 340, CYAN], [2700, 500, Color("#8AFFB0")], [2700, 210, VIOLET],
	[3600, 340, CYAN], [4400, 340, GOLD], [5200, 340, GOLD], [5900, 120, CYAN], [6785, 230, PINK], [7250, 230, VIOLET],
	[8000, 330, GOLD], [8650, 300, VIOLET], [9100, 330, GOLD], [9760, 460, PINK], [10500, 340, CYAN], [11100, 300, VIOLET],
	[11900, 120, PINK], [12680, 460, CYAN], [13480, 140, Color("#FFFFFF")], [13800, 280, VIOLET], [14200, 300, PINK], [14780, 280, VIOLET],
	[15550, 300, PINK], [16900, 140, CYAN], [18450, 330, Color("#FFFFFF")], [18600, 300, CYAN], [18750, 330, Color("#FFFFFF")],
]

const SPIRES = [
	[-100, 220, -40], [100, 220, -30], [450, 220, -50], [1250, 180, -40], [2500, 250, -30], [3000, 250, -40], [3700, 380, 40],
	[6300, 640, 60], [6900, 640, 90], [7100, 640, 70], [8500, 60, -40], [13700, 380, 50], [14100, 0, -70], [14400, 0, -60], [14800, 380, 60],
]
const STATUES = [[8050, 380, 0], [8300, 380, 3], [9000, 380, 6], [9250, 380, 3]]
const PROPS = [["mushroom", 120, 380], ["mushroom", 1700, 380], ["vine", 2650, 250], ["mushroom", 4300, 380], ["vine", 8200, 60], ["mushroom", 8850, 380], ["mushroom", 13650, 380]]

# REGIONS: [name, left, top, right, bottom, night colour, music]
const REGIONS = [
	["THE CAVERN ENTRANCE", -900, -400, 1600, 800, Color(0.42, 0.38, 0.68), QUIET],
	["THE CRYSTAL MAZE", 1600, -400, 4200, 800, Color(0.5, 0.45, 0.8), CAVES],
	["THE ANCIENT MECHANISMS", 4200, -400, 6250, 800, Color(0.62, 0.55, 0.7), MACHINES],
	["THE COLLAPSING DEPTHS", 6250, -400, 7800, 800, Color(0.6, 0.38, 0.55), DANGER],
	["THE FORGOTTEN SANCTUARY", 7800, -400, 9400, 800, Color(0.7, 0.6, 0.5), SANCTUARY],
	["THE CRYSTAL TRIALS", 9400, -400, 13400, 800, Color(0.45, 0.5, 0.85), MACHINES],
	["THE CORE OF THE BETWEEN", 13400, -400, 14900, 800, Color(0.5, 0.35, 0.7), CAVES],
	["", 14900, -400, 19400, 800, Color(0.85, 0.42, 0.45)],
]


func _ready() -> void:
	var spikes = SPIKES.duplicate()
	for x in range(6280, 7760, 64):   # the whole Collapsing Depths pit
		spikes.append([x, 640])
	build({
		"blocks": BLOCKS, "spikes": spikes, "movers": MOVERS, "zappers": ZAPPERS, "doors": DOORS,
		"enemies": ENEMIES, "chests": CHESTS, "checkpoints": CHECKPOINTS, "secrets": SECRETS, "npcs": NPCS,
		"signs": SIGNS, "crystals": CRYSTALS, "regions": REGIONS, "crumbles": CRUMBLES, "rocks": FALLING_ROCKS,
		"spires": SPIRES, "statues": STATUES, "props": PROPS, "puzzles": PUZZLES,
	})
	var camera = level.get_node("Player/Camera2D")   # stop at the rock at both ends
	camera.limit_left = -900
	camera.limit_right = 19400
	collapse = ColorRect.new()   # the collapse that chases you in the escape
	collapse.color = Color(1.4, 0.5, 1.6, 0.85)
	collapse.size = Vector2(500, 1200)
	collapse.position = Vector2(14000, -500)
	collapse.hide()
	add_child(collapse)
	var boss = level.get_node("NullArchitect")
	if ARCHITECT.beaten_this_run:   # Game Over during the escape: start again at the escape, not the boss
		boss.queue_free()
		level.get_node("Player").global_position = ESCAPE_START + Vector2(0, -12)   # the level spawns you here
		_start_escape.call_deferred()
	else:
		boss.defeated.connect(_start_escape)


# ---------- the escape: the core collapses behind you ----------

var collapse: ColorRect
var escaping = false


func _start_escape() -> void:
	escaping = true
	made.door[10].open()
	level.get_node("ExitPortal").open()
	collapse.position.x = minf(level.player.global_position.x, ESCAPE_START.x) - 900.0   # always starts behind you
	collapse.show()
	Sfx.play_music(ESCAPE_MUSIC)
	Sfx.music.pitch_scale = 1.15
	level._show_banner("THE CORE IS COLLAPSING  ·  RUN!")


func _physics_process(delta: float) -> void:
	if not escaping:
		return
	if level.respawning:   # it starts again a little behind the lantern you come back to
		collapse.position.x = level.spawn_position.x - 900.0
		return
	collapse.position.x = minf(collapse.position.x + WALL_SPEED * delta, 18100.0)
	var shake = level.player.get_node("Camera2D")
	shake.offset = Vector2(randf_range(-1.5, 1.5), randf_range(-1.0, 1.0))
	if level.player.global_position.x < collapse.position.x + collapse.size.x:
		level._on_spikes_body_entered(level.player)
