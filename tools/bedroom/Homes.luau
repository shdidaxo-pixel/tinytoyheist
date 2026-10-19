--!strict
-- The 8 player homes in the curved wall: open bays in the wall framing (studs, blocking, top plate, OSB at the back),
-- torn drywall up the front edges, cables stapled up the studs, an outlet, a fairy light, the toy pen at the back, and
-- the door props (a toy padlock, the Toy Index box and book, the levelled Speed wheel, an invisible spawn pad), the
-- floating sign and the lock bars.
--
-- Home space: origin at the middle of the open front, on the floor; LookVector into the room, +Z back into the wall,
-- x across (walking in, -x is on your right). MapConfig.BURROW_LAYOUT positions are in this space.
--
-- Used by tools/build-bedroom.luau (build) and by game code (applyLevel, buildWheel, setSign, setLocked) to change a
-- home live.

local Homes = {}

-- A studded toy-brick material in MaterialService, when the place has one
Homes.STUDS = "" -- none yet (the AI stud materials came out as grids and bricks)

-- How each level looks: fairy light, pen floor and the dressing in the bays
Homes.LEVEL_LOOK = {
	{ fairy = 0xFFD27A, pen = 0xC49A6C }, -- 1 Cardboard
	{ fairy = 0xFFB0C8, pen = 0xF28DB2 }, -- 2 Sock-lined
	{ fairy = 0xFFE08A, pen = 0x3DA5FF }, -- 3 Toy bricks
	{ fairy = 0xFF9A4A, pen = 0xC89A62 }, -- 4 Cosy cabin
	{ fairy = 0xFF8FC8, pen = 0xFF8FC8 }, -- 5 Candy land
	{ fairy = 0x7AE8FF, pen = 0x1A1430 }, -- 6 Arcade neon
	{ fairy = 0xFFE07A, pen = 0xFFC93C }, -- 7 Golden vault
}

-- How each Speed wheel level looks, plainest to craziest (names and prices: GameConfig.WHEELS). The ring's segments
-- (colours cycle round it), spokes, rungs (colours cycle), the stand, the tag, and the extras:
--   studs, handles, lollipop / vault / skull / diamond / planet hubs, gems, neon ring / spokes / rungs, a light;
--   clear = see-through ring and spokes; spikes = blocks sticking out of the ring (plates, icicles, gear teeth,
--   crystals, rays); bones / bolts = bone or lightning spokes; pips = bubbles round the ring; moons on the spokes;
--   inner = extra neon rings inside the ring; on the stand: wings, crown (on an arch), halo, clouds, boosters, horns,
--   torches; trail = light streaks off the ring as it spins; particles (presets in buildWheel).
-- The wheel stops growing at level 7 (it has to fit the home); past that the looks get wilder instead.
local RAINBOW = { 0xFF4D5E, 0xFF9A3C, 0xFFE14D, 0x5BE36A, 0x3DC8FF, 0x6B7BFF, 0xB45CFF }
Homes.WHEEL_LOOK = {
	{ -- 1 a plain cardboard spool
		ring = { 0xD9B27C, 0xC49A6C },
		segments = 8,
		spokes = 4,
		spoke = 0xC49A6C,
		rungs = { 0xFFC93C },
		frame = 0x8A5A34,
		tag = 0xD9B27C,
		material = Enum.Material.Cardboard,
	},
	{ -- 2 sock stripes
		ring = { 0xF28DB2, 0xFFFFFF },
		segments = 10,
		spokes = 4,
		spoke = 0xF28DB2,
		rungs = { 0xFFFFFF },
		frame = 0x7FD6E8,
		tag = 0xF28DB2,
		material = Enum.Material.Fabric,
	},
	{ -- 3 toy bricks, studs and all
		ring = { 0xE04848, 0xFFC93C, 0x4DA8FF },
		segments = 12,
		spokes = 6,
		spoke = 0xE04848,
		rungs = { 0xFFC93C },
		frame = 0x4DA8FF,
		tag = 0xFF6B6B,
		material = Enum.Material.SmoothPlastic,
		studs = true,
	},
	{ -- 4 a ship's wheel from the cabin
		ring = { 0xB07A48, 0x9A6A3C },
		segments = 12,
		spokes = 6,
		spoke = 0x6B4A2E,
		rungs = { 0xE8C890 },
		frame = 0x6B4A2E,
		tag = 0xE0A060,
		material = Enum.Material.Wood,
		handles = true,
	},
	{ -- 5 candy: a candy-cane ring and a lollipop hub
		ring = { 0xFF5FA8, 0xFFFFFF },
		segments = 14,
		spokes = 6,
		spoke = 0xFFFFFF,
		rungs = { 0xFF8FC8, 0xFFFFFF },
		frame = 0x8FE8D0,
		hub = 0xFF5FA8,
		tag = 0xFF8FC8,
		material = Enum.Material.SmoothPlastic,
		lollipop = true,
	},
	{ -- 6 arcade neon: glowing ring, spokes and rungs
		ring = { 0x1A1430, 0x22B8E8 },
		segments = 14,
		spokes = 8,
		spoke = 0x7A4CFF,
		rungs = { 0x22B8E8 },
		frame = 0x1A1430,
		tag = 0x7AE8FF,
		material = Enum.Material.SmoothPlastic,
		neonRing = true,
		neonSpokes = true,
		neonRungs = true,
		neon = 0x7A4CFF,
		light = 0x7AE8FF,
	},
	{ -- 7 the golden vault: gold, jewels and a vault-dial hub
		ring = { 0xFFC93C, 0xFFB31A },
		segments = 16,
		spokes = 8,
		spoke = 0xFFC93C,
		rungs = { 0xFFF1B0 },
		frame = 0xE0A82E,
		hub = 0xFFE07A,
		tag = 0xFFD43B,
		material = Enum.Material.SmoothPlastic,
		neonRing = true,
		gems = { 0xFF4D5E, 0x7AE8FF, 0x5BE36A, 0xB45CFF },
		vault = true,
		neon = 0xFFE07A,
		light = 0xFFE07A,
	},
	{ -- 8 dino bones: a fossil ring, bone spokes and stegosaurus plates
		ring = { 0xF2E8D0, 0xE0D2B0 },
		segments = 14,
		spokes = 6,
		spoke = 0xF7F0DC,
		rungs = { 0xC8B890 },
		frame = 0x4E8A3A,
		tag = 0x9BE36A,
		material = Enum.Material.SmoothPlastic,
		bones = true,
		spikes = { colors = { 0x6BBF3A, 0xF0A030 }, length = 1.8, width = 1.8, every = 2 },
	},
	{ -- 9 bubble pop: a see-through soap-bubble ring with bubbles stuck round it
		ring = { 0x9FE8FF, 0xFFB8F0, 0xC8FFB8 },
		segments = 14,
		spokes = 6,
		spoke = 0xBFF0FF,
		rungs = { 0xFFFFFF, 0xFFB8F0 },
		frame = 0x7FD8FF,
		tag = 0xBFF0FF,
		material = Enum.Material.Glass,
		clear = 0.35,
		pips = { 0xBFF4FF, 0xFFC8F4 },
		particles = { { kind = "bubble", color = 0xCFF4FF } },
		light = 0xBFEFFF,
	},
	{ -- 10 frosty ice: an ice ring with icicles and falling snow
		ring = { 0xBFF4FF, 0x8FD8FF },
		segments = 16,
		spokes = 6,
		spoke = 0xDFF8FF,
		rungs = { 0xFFFFFF, 0xBFEFFF },
		frame = 0xE8FAFF,
		tag = 0x8FE8FF,
		material = Enum.Material.Ice,
		spikes = { colors = { 0xE8FAFF, 0xA8E8FF }, length = 2, width = 0.9, every = 1, crystal = true },
		particles = { { kind = "snow", color = 0xFFFFFF } },
		light = 0x9FE8FF,
	},
	{ -- 11 robot gears: a metal gear with teeth, hazard-stripe rungs and red lights
		ring = { 0x8A93A6, 0x6B7385 },
		segments = 16,
		spokes = 6,
		spoke = 0x5A6274,
		rungs = { 0xFFC93C, 0x2A2A2A },
		frame = 0x4A5060,
		hub = 0xE04848,
		tag = 0xFFC93C,
		material = Enum.Material.DiamondPlate,
		spikes = { colors = { 0x7A8396 }, length = 1.2, width = 1.4, every = 1 },
		gems = { 0xFF4D5E },
		neon = 0xFF4D5E,
		light = 0xFF6B6B,
	},
	{ -- 12 rocket: red and white with blue struts, boosters blasting fire
		ring = { 0xFFFFFF, 0xE04848 },
		segments = 16,
		spokes = 6,
		spoke = 0x3A6EE8,
		rungs = { 0xFFFFFF },
		frame = 0x3A6EE8,
		hub = 0xE04848,
		tag = 0xFF6B6B,
		material = Enum.Material.SmoothPlastic,
		boosters = true,
		neon = 0xFFB31A,
		light = 0xFFB31A,
	},
	{ -- 13 lava: cracked rock glowing orange, torches and embers
		ring = { 0x2A1E1E, 0xFF5A1A },
		segments = 16,
		spokes = 6,
		spoke = 0x3A2A2A,
		rungs = { 0xFF8A1A },
		frame = 0x3A2A2A,
		tag = 0xFF7A2A,
		material = Enum.Material.Basalt,
		neonRing = true,
		neonRungs = true,
		torches = true,
		neon = 0xFF5A1A,
		particles = { { kind = "ember", color = 0xFF7A2A } },
		light = 0xFF7A2A,
	},
	{ -- 14 rainbow: every colour, glowing rungs and a rainbow streak
		ring = RAINBOW,
		segments = 14,
		spokes = 7,
		spoke = 0xFFFFFF,
		rungs = RAINBOW,
		frame = 0xFFFFFF,
		tag = 0xFF8FC8,
		material = Enum.Material.SmoothPlastic,
		neonRungs = true,
		rainbowSpokes = true,
		trail = RAINBOW,
		light = 0xFFFFFF,
	},
	{ -- 15 thunderstorm: storm clouds on the stand, lightning-bolt spokes and sparks
		ring = { 0x3A4256, 0x2A3042 },
		segments = 16,
		spokes = 6,
		spoke = 0xFFE65A,
		rungs = { 0xFFE65A },
		frame = 0x2A3042,
		tag = 0xFFE65A,
		material = Enum.Material.Slate,
		bolts = true,
		neonRungs = true,
		clouds = true,
		neon = 0xFFE65A,
		particles = { { kind = "spark", color = 0xFFF08A } },
		light = 0xFFE65A,
	},
	{ -- 16 haunted: a ghostly green ring, bone spokes, a skull hub and wisps
		ring = { 0x7AFFB0, 0x2A2A3A },
		segments = 16,
		spokes = 6,
		spoke = 0xF2EEE0,
		rungs = { 0x7AFFB0 },
		frame = 0x2A2238,
		tag = 0x7AFFB0,
		material = Enum.Material.SmoothPlastic,
		neonRing = true,
		neonRungs = true,
		bones = true,
		skull = true,
		neon = 0x5AFF9A,
		particles = { { kind = "wisp", color = 0x7AFFB0 } },
		light = 0x5AFF9A,
	},
	{ -- 17 diamond: a clear crystal ring with crystal spikes, a diamond hub and sparkles
		ring = { 0x9FF4FF, 0xE8FFFF },
		segments = 16,
		spokes = 8,
		spoke = 0xCFFAFF,
		rungs = { 0xE8FFFF },
		frame = 0xE8FFFF,
		tag = 0x9FF4FF,
		material = Enum.Material.Glass,
		clear = 0.2,
		spikes = { colors = { 0x9FF4FF, 0xE8FFFF }, length = 1.8, width = 1.2, every = 2, crystal = true },
		diamond = true,
		gems = { 0x9FF4FF, 0xFFFFFF },
		particles = { { kind = "sparkle", color = 0xE8FFFF } },
		light = 0xBFF8FF,
	},
	{ -- 18 dragon: green scales, red spines, horns, wings and fire
		ring = { 0x2E9A4A, 0x1E7A3A },
		segments = 16,
		spokes = 6,
		spoke = 0x1E5A2E,
		rungs = { 0xFFB31A },
		frame = 0x3A2A2A,
		tag = 0xFF5A3A,
		material = Enum.Material.SmoothPlastic,
		spikes = { colors = { 0xE0482E, 0xFF8A2A }, length = 1.9, width = 1.1, every = 1 },
		horns = 0xF2E8D0,
		wings = 0x2E9A4A,
		torches = true,
		neon = 0xFF5A1A,
		particles = { { kind = "ember", color = 0xFF7A2A } },
		light = 0xFF7A2A,
	},
	{ -- 19 ringed planet: a night-sky ring round a voxel planet with its own ring, and stars
		ring = { 0x2A3A8A, 0x3A5AC8 },
		segments = 16,
		spokes = 6,
		spoke = 0x8FA8FF,
		rungs = { 0xFFE07A },
		frame = 0x1A1E40,
		tag = 0x8FA8FF,
		material = Enum.Material.SmoothPlastic,
		planet = { body = 0xFFA85A, band = 0xFFE0A8 },
		pips = { 0xFFFFFF, 0xFFE07A },
		particles = { { kind = "stars", color = 0xFFFFFF } },
		light = 0x8FA8FF,
	},
	{ -- 20 galaxy: deep purple and pink neon, an inner ring, moons and a purple streak
		ring = { 0x2A1450, 0xB45CFF },
		segments = 16,
		spokes = 8,
		spoke = 0xFF5FD0,
		rungs = { 0xB45CFF, 0xFF5FD0 },
		frame = 0x1A1030,
		tag = 0xB45CFF,
		material = Enum.Material.SmoothPlastic,
		neonRing = true,
		neonSpokes = true,
		neonRungs = true,
		inner = { 0xFF5FD0 },
		moons = { 0xE8E0FF, 0xFFE07A, 0x8FE8FF },
		trail = { 0xB45CFF, 0xFF5FD0 },
		neon = 0xB45CFF,
		particles = { { kind = "stars", color = 0xE0B8FF } },
		light = 0xB45CFF,
	},
	{ -- 21 black hole: a black ring, glowing rings spiralling in to a black core
		ring = { 0x0A0A12, 0x1A1028 },
		segments = 16,
		spokes = 8,
		spoke = 0x1A1028,
		rungs = { 0xFF8A3C, 0xB45CFF },
		frame = 0x0A0A12,
		tag = 0xA05AFF,
		material = Enum.Material.SmoothPlastic,
		neonRungs = true,
		inner = { 0xFF8A3C, 0xB45CFF, 0xFF5FD0 },
		planet = { body = 0x050508 },
		trail = { 0xFF8A3C, 0xB45CFF },
		neon = 0xA05AFF,
		particles = { { kind = "swirl", color = 0xA05AFF } },
		light = 0xA05AFF,
	},
	{ -- 22 supernova: a blazing sun with rays, fire and a big glow
		ring = { 0xFFB31A, 0xFF6A1A },
		segments = 16,
		spokes = 8,
		spoke = 0xFFE14D,
		rungs = { 0xFFF1B0 },
		frame = 0xE0A82E,
		tag = 0xFFB31A,
		material = Enum.Material.SmoothPlastic,
		neonRing = true,
		neonSpokes = true,
		neonRungs = true,
		spikes = { colors = { 0xFFE14D, 0xFF8A1A }, length = 2, width = 0.8, every = 1, neon = true },
		planet = { body = 0xFFE14D, glow = true },
		torches = true,
		neon = 0xFFB31A,
		particles = { { kind = "fire", color = 0xFFB31A } },
		light = 0xFFC83A,
	},
	{ -- 23 angel wings: white and gold, feathered wings, a halo and sparkles
		ring = { 0xFFFFFF, 0xFFE07A },
		segments = 16,
		spokes = 8,
		spoke = 0xFFFFFF,
		rungs = { 0xFFF1B0 },
		frame = 0xF4F0EA,
		hub = 0xFFE07A,
		tag = 0xFFF1B0,
		material = Enum.Material.Marble,
		neonRing = true,
		wings = 0xFFFFFF,
		halo = 0xFFE07A,
		neon = 0xFFE07A,
		particles = { { kind = "sparkle", color = 0xFFF4C8 } },
		light = 0xFFF4C8,
	},
	{ -- 24 royal crown: gold and jewels round a velvet inner ring, a crown on top
		ring = { 0xFFC93C, 0xFFB31A },
		segments = 16,
		spokes = 8,
		spoke = 0xFFC93C,
		rungs = { 0xFFF1B0 },
		frame = 0x6A2A9A,
		hub = 0xFFE07A,
		tag = 0xFFD43B,
		material = Enum.Material.SmoothPlastic,
		frameMaterial = Enum.Material.Fabric,
		neonRing = true,
		vault = true,
		gems = { 0xFF4D5E, 0x7AE8FF, 0x5BE36A, 0xB45CFF },
		inner = { 0xB0204A },
		crown = 0xFFC93C,
		trail = { 0xFFE07A, 0xFFB31A },
		neon = 0xFFE07A,
		particles = { { kind = "sparkle", color = 0xFFE07A } },
		light = 0xFFD84A,
	},
	{ -- 25 infinity: everything at once, in rainbow neon
		ring = RAINBOW,
		segments = 21,
		spokes = 7,
		spoke = 0xFFFFFF,
		rungs = RAINBOW,
		frame = 0xFFFFFF,
		hub = 0xFFFFFF,
		tag = 0xFFFFFF,
		material = Enum.Material.SmoothPlastic,
		neonRing = true,
		neonSpokes = true,
		neonRungs = true,
		rainbowSpokes = true,
		inner = RAINBOW,
		spikes = { colors = RAINBOW, length = 1.8, width = 0.9, every = 1, neon = true },
		gems = { 0xFFFFFF },
		planet = { body = 0xFFFFFF, glow = true },
		wings = 0xFFFFFF,
		crown = 0xFFE07A,
		halo = 0xFFFFFF,
		trail = RAINBOW,
		neon = 0xFFFFFF,
		particles = { { kind = "sparkle", color = 0xFFFFFF }, { kind = "stars", color = 0xFFE07A } },
		light = 0xFFFFFF,
	},
}

local PINE, PINE_DARK, OSB, GOLD = 0xF2D3A4, 0xD8B07A, 0xDDBB88, 0xFFC93C
local DRYWALL = 0xF2EFE8
local RED = 0xFF4D5E

-- Bays between the back studs: centre x and width
local BAYS = { { -47, 26 }, { 0, 52 }, { 47, 26 } }

local function variant(name: string): string?
	return if game:GetService("MaterialService"):FindFirstChild(name, true) then name else nil
end

-- Build home `index` into `parent` at `level`. Returns the home model (Hole1..8).
function Homes.build(Kit: any, MapConfig: any, parent: Instance, index: number, level: number): Model
	local BW, BD, H = MapConfig.BURROW_WIDTH, MapConfig.BURROW_DEPTH, MapConfig.WALL_HEIGHT
	local LIFT = MapConfig.BURROW_FLOOR_LIFT
	local frame = MapConfig.homeFrame(index)
	local part, block = Kit.part, Kit.block
	local function at(x: number, y: number, z: number): CFrame
		return frame * CFrame.new(x, y, z)
	end

	local home = Kit.model(parent, "Hole" .. index, {
		HoleIndex = index,
		Owner = 0, -- UserId, 0 = free
		Level = level,
		Locked = false,
	})

	-- Shell: subfloor, OSB back sheathing, a side stud each side (they are the home's side walls), two back studs,
	-- staggered blocking between them and the top plate you see when you look up
	local shell = Kit.folder(home, "Shell")
	block(shell, "Floor", BW + 10, 1, BD, frame, 0, LIFT - 1, BD / 2, OSB, {
		material = Enum.Material.Wood,
		variant = nil,
		shadow = false,
		attributes = { FloorType = "Burrow", Noise = 0 },
	})
	block(shell, "Sheathing", BW + 10, H, 2, frame, 0, 0, BD + 1, OSB, {
		material = Enum.Material.Wood,
		variant = nil,
	})
	for _, side in { -1, 1 } do
		block(shell, "SideStud", MapConfig.HOME_STUD, H, BD, frame, side * (BW / 2 + 2.5), 0, BD / 2, PINE, {
			material = Enum.Material.Wood,
		})
	end
	for _, x in { -30, 30 } do
		block(shell, "BackStud", 8, H, 10, frame, x, 0, BD - 5, PINE, { material = Enum.Material.Wood })
	end
	for k, bay in BAYS do
		for _, y in { 120, 240 } do
			local lift = if k == 2 then 6 else 0
			block(shell, "Blocking", bay[2], 8, 10, frame, bay[1], y + lift, BD - 5, PINE_DARK, {
				material = Enum.Material.Wood,
			})
		end
	end
	block(shell, "TopPlate", BW + 10, 8, BD, frame, 0, H - 8, BD / 2, PINE_DARK, { material = Enum.Material.Wood })

	-- Torn drywall up both front edges: a fixed jagged pattern per home
	local drywall = Kit.folder(shell, "Drywall")
	for _, q in { -1, 1 } do
		for y = 0, H - 14, 14 do
			local w = 3 + ((y * 7 + (index - 1) * 5 + (q + 1) * 3) % 9)
			block(drywall, "Drywall", w, 14, 4, frame, q * (BW / 2 + 5 - w / 2), y, 1, DRYWALL, {
				material = Enum.Material.Plaster,
				shadow = false,
			})
		end
	end

	-- Cables: two white runs stapled up the back, one feeding the outlet; a yellow one sagging across the studs
	local cables = Kit.folder(home, "Cables")
	local cz = BD - 11
	local function cable(color: number, points: { { number } })
		for k = 1, #points - 1 do
			local a = (at(points[k][1], points[k][2], points[k][3])).Position
			local b = (at(points[k + 1][1], points[k + 1][2], points[k + 1][3])).Position
			Kit.rod(cables, "Cable", a, b, 1.1, color, { collide = false, shadow = false })
			if k > 1 then
				Kit.ball(cables, "Bend", 1.1, a, color, { collide = false, shadow = false })
			end
		end
	end
	cable(
		0xF4F1E8,
		{ { -26, 30, cz }, { -25, 90, cz - 0.5 }, { -26.5, 170, cz }, { -25, 260, cz - 0.6 }, { -26, H - 8, cz } }
	)
	cable(
		0xF4F1E8,
		{ { 34, 0, cz }, { 35, 80, cz - 0.4 }, { 33.5, 190, cz }, { 35, 290, cz - 0.5 }, { 34, H - 8, cz } }
	)
	cable(0xF2C94C, {
		{ 60, 64, cz },
		{ 47, 61, cz },
		{ 30, 64, cz },
		{ 0, 60, cz },
		{ -30, 64, cz },
		{ -47, 61, cz },
		{ -60, 64, cz },
	})
	for _, s in { { -26, 60 }, { -26, 150 }, { -26, 240 }, { 34, 120 }, { 34, 230 } } do
		block(cables, "Staple", 3, 1.2, 1.6, frame, s[1], s[2], cz - 0.6, 0xC9CED8, {
			material = Enum.Material.Metal,
			collide = false,
		})
	end

	-- Outlet box with two glowing slits
	local outlet = block(home, "Outlet", 9, 13, 5, frame, -30, 24, BD - 12.5, 0x3A6FD8)
	for _, x in { -2, 2 } do
		block(outlet, "Slit", 1.1, 3.6, 0.4, frame, -30 + x, 28.2, BD - 15.2, 0xFFC070, {
			material = Enum.Material.Neon,
			collide = false,
		})
	end

	-- Toy pen at the back: the owner's toys roam it. PenMin/PenMax are the roaming bounds in home space.
	local penDepth = MapConfig.PEN_BACK - MapConfig.PEN_FRONT
	local pen = block(
		home,
		"Pen",
		MapConfig.PEN_WIDTH,
		0.6,
		penDepth,
		frame,
		0,
		LIFT,
		(MapConfig.PEN_FRONT + MapConfig.PEN_BACK) / 2,
		0xC49A6C,
		{ shadow = false }
	)
	pen:SetAttribute("PenMin", Vector3.new(-MapConfig.PEN_WIDTH / 2 + 6, 0, MapConfig.PEN_FRONT + 4))
	pen:SetAttribute("PenMax", Vector3.new(MapConfig.PEN_WIDTH / 2 - 6, 0, MapConfig.PEN_BACK - 6))
	pen:SetAttribute("PenTop", LIFT + 0.6)
	Kit.folder(home, "PenToys")

	-- Door props at MapConfig.BURROW_LAYOUT
	local layout = MapConfig.BURROW_LAYOUT
	local function prop(name: string): CFrame
		local p = layout[name].position
		return at(p.X, LIFT, p.Z)
	end

	-- the lock and the Index stand turn to face the middle of the home and the open front
	local facing = CFrame.Angles(0, -math.pi / 4, 0)
	Homes.buildLock(Kit, home, prop("LockButton") * facing)
	Homes.buildIndex(Kit, home, prop("ToyIndex") * facing)

	-- Spawn: an invisible pad on the floor where you wake up (the matchbox bed is gone, Dylan 19 Oct)
	local spawnPad = Instance.new("SpawnLocation")
	spawnPad.Name = "Spawn"
	spawnPad.Anchored = true
	spawnPad.Size = Vector3.new(16, 0.2, 10)
	spawnPad.CFrame = prop("Spawn") * CFrame.new(0, 0.1, 0)
	spawnPad.Transparency = 1
	spawnPad.CanCollide = false
	spawnPad.CanQuery = false
	spawnPad.CanTouch = false
	spawnPad.CastShadow = false
	spawnPad.Duration = 0
	spawnPad.Neutral = true
	spawnPad.Parent = home

	-- The sign: text floating over the middle of the open front (an invisible anchor carries it)
	local sp = MapConfig.SIGN
	local sign = part(home, "Sign", Vector3.one, at(sp.position.X, sp.position.Y, sp.position.Z), 0xFFFFFF, {
		collide = false,
		transparency = 1,
	})
	Homes.setSign(sign, "EMPTY HOME", "Lv " .. level)

	-- Lock bars across the open front and a barrier behind them; hidden until the door is locked
	local bars = Kit.folder(home, "LockBars")
	for k = 0, 11 do
		Kit.disc(bars, "Bar", 0.8, 30, at(55 - k * 10, 15, -1), RED, {
			material = Enum.Material.Neon,
			collide = false,
			transparency = 1,
		})
	end
	block(
		bars,
		"Bar",
		BW,
		1.6,
		1.6,
		frame,
		0,
		30,
		-1,
		RED,
		{ material = Enum.Material.Neon, collide = false, transparency = 1 }
	)
	block(home, "DoorBarrier", BW + 10, 60, 2, frame, 0, 0, -1.5, RED, { collide = false, transparency = 1 })
	Homes.setLocked(home, false) -- opens the padlock's shackle

	Homes.applyLevel(Kit, MapConfig, home, level)
	return home
end

-- The Door Lock: a chunky toy padlock standing on the floor (Dylan: "make it a toy lock so it's more reasonable").
-- A red body with a yellow face plate and a keyhole, and a blue shackle that pops up when the home is unlocked.
-- `at` is the floor under it; it faces at's LookVector. The body is LockButton (with LockPrompt on it).
function Homes.buildLock(Kit: any, home: Instance, at: CFrame): BasePart
	local plastic = { material = Enum.Material.SmoothPlastic, collide = false }
	local lock = Kit.block(home, "LockButton", 8, 7, 4, at, 0, 0, 0, RED, { material = Enum.Material.SmoothPlastic })
	-- a darker base, so it reads as a moulded toy
	Kit.block(lock, "Base", 8.4, 0.8, 4.4, at, 0, 0, 0, 0x8A1F2A, plastic)
	Kit.block(lock, "Plate", 6, 5, 0.4, at, 0, 1, -2.1, 0xFFC93C, plastic)
	-- the keyhole: a round hole and a slot
	Kit.part(
		lock,
		"Keyhole",
		Vector3.new(0.3, 2, 2),
		at * CFrame.new(0, 4.4, -2.35) * CFrame.Angles(0, math.pi / 2, 0),
		0x1A1430,
		{
			material = Enum.Material.SmoothPlastic,
			collide = false,
			shape = Enum.PartType.Cylinder,
		}
	)
	Kit.block(lock, "Keyhole", 0.8, 1.8, 0.3, at, 0, 2.4, -2.35, 0x1A1430, plastic)
	-- two studs on top, like a toy brick
	for _, x in { -2.4, 2.4 } do
		Kit.disc(lock, "Stud", 0.9, 0.6, at * CFrame.new(x, 7.3, 1.2), RED, plastic)
	end
	-- the shackle: two posts and a top bar (the left post is the Shackle model's PrimaryPart)
	local shackle = Kit.model(lock, "Shackle")
	local post = Kit.block(shackle, "Post", 1.6, 5, 1.6, at, -2.6, 6.2, 0, 0x4DA8FF, plastic)
	Kit.block(shackle, "Post", 1.6, 5, 1.6, at, 2.6, 6.2, 0, 0x4DA8FF, plastic)
	Kit.block(shackle, "Bar", 6.8, 1.6, 1.6, at, 0, 11.2, 0, 0x4DA8FF, plastic)
	shackle.PrimaryPart = post

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "LockPrompt"
	prompt.ActionText = "Lock door"
	prompt.ObjectText = "Door Lock"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = lock
	return lock
end

-- The Toy Index: a toy box with INDEX on the front and a big open picture book propped on top, showing toys.
-- `at` is the floor under it; it faces at's LookVector. The box is IndexStand (with IndexPrompt on it), the book
-- IndexBook.
function Homes.buildIndex(Kit: any, home: Instance, at: CFrame): BasePart
	local plastic = { material = Enum.Material.SmoothPlastic, collide = false }
	local box =
		Kit.block(home, "IndexStand", 9, 5, 6, at, 0, 0, 0, 0x3A6FD8, { material = Enum.Material.SmoothPlastic })
	Kit.block(box, "Trim", 9.4, 0.8, 6.4, at, 0, 0, 0, 0xFFC93C, plastic)
	Kit.block(box, "Trim", 9.4, 0.8, 6.4, at, 0, 4.4, 0, 0xFFC93C, plastic)
	local label = Kit.block(box, "Label", 7, 2.4, 0.3, at, 0, 1.3, -3.1, 0xFFF6D5, plastic)
	Kit.text(label, "INDEX", { color = Color3.fromRGB(224, 72, 72), font = Enum.Font.GothamBlack, glow = true })
	-- the book, propped open and tipped toward you
	local tilt = at * CFrame.new(0, 6.2, 0.6) * CFrame.Angles(math.rad(-28), 0, 0)
	Kit.block(box, "Prop", 6, 1.6, 1.2, at, 0, 5.2, 2.2, 0x2B4E9E, plastic)
	local book = Kit.part(
		box,
		"IndexBook",
		Vector3.new(8.6, 0.5, 6.2),
		tilt,
		0xE04848,
		{ material = Enum.Material.SmoothPlastic }
	)
	for _, s in { -1, 1 } do
		local page = tilt * CFrame.new(s * 2.05, 0.5, 0) * CFrame.Angles(0, 0, -s * 0.1)
		Kit.part(book, "Page", Vector3.new(3.9, 0.6, 5.6), page, 0xFFFFFF, plastic)
		-- toy pictures on the pages
		for k, z in { -1.3, 1.3 } do
			local color = ({ 0xFFD23F, 0xFF7AA8, 0x3DDC97, 0x4DA8FF })[(s + 1) + k]
			Kit.part(book, "Picture", Vector3.new(1.6, 0.1, 1.6), page * CFrame.new(0, 0.33, z), color, plastic)
		end
	end
	Kit.part(book, "Spine", Vector3.new(0.6, 0.7, 6.2), tilt * CFrame.new(0, 0.3, 0), 0x8A1F2A, plastic)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "IndexPrompt"
	prompt.ActionText = "Open Index"
	prompt.ObjectText = "Toy Index"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = box
	return box
end

-- The floating sign over a home: big white outlined text with no board, on a BillboardGui so it always faces you
-- (like Steal an Egg). Line 1 is the owner ("EMPTY HOME", a name, or "YOUR HOME" in gold); line 2 is the level and
-- income ("Lv 3 · $420/s") or a red lock timer ("LOCKED 0:32"). Colours are hex numbers; nil keeps the default.
function Homes.setSign(sign: BasePart, title: string, line2: string, titleColor: number?, line2Color: number?)
	local function hex(n: number): Color3
		return Color3.fromRGB(bit32.rshift(n, 16), bit32.band(bit32.rshift(n, 8), 255), bit32.band(n, 255))
	end
	local gui = sign:FindFirstChild("SignGui") :: BillboardGui?
	if not gui then
		for _, old in sign:GetChildren() do
			if old:IsA("LayerCollector") then
				old:Destroy()
			end
		end
		local g = Instance.new("BillboardGui")
		g.Name = "SignGui"
		g.Size = UDim2.fromScale(80, 26) -- studs, so it shrinks with distance like the world around it
		g.LightInfluence = 0 -- reads at night
		g.MaxDistance = 900
		g.Parent = sign
		local function label(name: string, y: number, h: number): TextLabel
			local t = Instance.new("TextLabel")
			t.Name = name
			t.BackgroundTransparency = 1
			t.Position = UDim2.fromScale(0, y)
			t.Size = UDim2.fromScale(1, h)
			t.Font = Enum.Font.GothamBlack
			t.TextScaled = true
			t.TextColor3 = Color3.new(1, 1, 1)
			t.TextStrokeTransparency = 1
			local stroke = Instance.new("UIStroke")
			stroke.Color = Color3.fromRGB(26, 20, 48)
			stroke.Thickness = 3
			stroke.Parent = t
			t.Parent = g
			return t
		end
		label("Title", 0, 0.58)
		label("Line2", 0.6, 0.36)
		gui = g
	end
	local g = gui :: BillboardGui
	local titleLabel = g:FindFirstChild("Title") :: TextLabel
	titleLabel.Text = title
	titleLabel.TextColor3 = if titleColor then hex(titleColor) else Color3.new(1, 1, 1)
	local second = g:FindFirstChild("Line2") :: TextLabel
	second.Text = line2
	second.TextColor3 = hex(line2Color or 0xFFE58A)
end

-- Show or hide the lock bars, darken the padlock and swing its shackle shut or open. The barrier stays walk-through:
-- game code puts strangers who walk into a locked home back outside, so the owner can still come and go.
function Homes.setLocked(home: Model, locked: boolean)
	local bars = home:FindFirstChild("LockBars")
	if bars then
		for _, bar in bars:GetChildren() do
			if bar:IsA("BasePart") then
				bar.Transparency = if locked then 0 else 1
			end
		end
	end
	local lock = home:FindFirstChild("LockButton")
	if lock and lock:IsA("BasePart") then
		local color = if locked then Color3.fromRGB(138, 31, 42) else Color3.fromRGB(255, 77, 94)
		lock.Color = color
		for _, p in lock:GetChildren() do
			if p:IsA("BasePart") and p.Name == "Stud" then
				p.Color = color
			end
		end
		-- open = the shackle popped up out of the body
		local shackle = lock:FindFirstChild("Shackle")
		if shackle and shackle:IsA("Model") and shackle.PrimaryPart and shackle:GetAttribute("Open") ~= not locked then
			local post = shackle.PrimaryPart
			local open = CFrame.new(0, post.Size.Y * 0.5, 0)
			shackle:PivotTo(shackle:GetPivot() * (if locked then open:Inverse() else open))
			shackle:SetAttribute("Open", not locked)
		end
	end
	home:SetAttribute("Locked", locked)
end

-- Dress a home for its level: the bays' dressing, the gold for Level 7, the fairy light, the pen floor and the Speed
-- wheel. Safe to call again on level up; it replaces what the last level built.
function Homes.applyLevel(Kit: any, MapConfig: any, home: Model, level: number)
	level = math.clamp(level, 1, #Homes.LEVEL_LOOK)
	local look = Homes.LEVEL_LOOK[level]
	local index = home:GetAttribute("HoleIndex") :: number
	local frame = MapConfig.homeFrame(index)
	local BW, BD, H = MapConfig.BURROW_WIDTH, MapConfig.BURROW_DEPTH, MapConfig.WALL_HEIGHT
	local LIFT = MapConfig.BURROW_FLOOR_LIFT
	local rgb, block = Kit.rgb, Kit.block
	local gold = level == 7
	home:SetAttribute("Level", level)

	for _, name in { "Dressing", "FairyLight", "PenFloor", "TrainingWheel" } do
		local old = home:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end

	-- the framing turns gold in the vault
	local shell = home:FindFirstChild("Shell")
	if shell then
		for _, p in shell:GetChildren() do
			if p:IsA("BasePart") then
				if p.Name == "SideStud" or p.Name == "BackStud" then
					p.Color = rgb(if gold then GOLD else PINE)
					p.Material = if gold then Enum.Material.Foil else Enum.Material.Wood
				elseif p.Name == "Sheathing" then
					p.Color = rgb(if gold then GOLD else OSB)
					p.Material = if gold then Enum.Material.Foil else Enum.Material.Wood
					p.MaterialVariant = if gold then "" else ""
				end
			end
		end
	end

	-- Dressing in the three bays at the back
	local dressing = Kit.folder(home, "Dressing")
	local back = BD -- the sheathing's front face
	if level == 1 or level == 3 then
		-- batts of insulation stacked up each bay: brown mineral wool (Dylan's photo) or pink
		local colors = if level == 1 then { 0xA88A62, 0x8E7350, 0x9C7E58 } else { 0xF2A6B8, 0xE58BA1, 0xEC98AD }
		for b, bay in BAYS do
			local row = 0
			for y = 0, H - 30, 20 do
				local depth = 4 + ((row * 7 + b * 3 + index) % 4)
				block(
					dressing,
					"Batt",
					bay[2] + 0.6,
					20.6,
					depth,
					frame,
					bay[1],
					y,
					back - depth / 2,
					colors[row % 3 + 1],
					{
						material = Enum.Material.Fabric,
						shadow = false,
					}
				)
				row += 1
			end
		end
	elseif level == 2 then
		-- odd socks stretched over the bays
		local sockColors = { 0xF28DB2, 0x7FD6E8, 0xFFD95A }
		for b, bay in BAYS do
			for k = 0, 9 do
				block(
					dressing,
					"Sock",
					bay[2] - 2,
					11,
					1.5,
					frame,
					bay[1],
					2 + k * 11,
					back - 1.5,
					if k % 2 == 0 then sockColors[b] else 0xFFFFFF,
					{
						material = Enum.Material.Fabric,
						shadow = false,
					}
				)
			end
			block(dressing, "SockCuff", bay[2], 6, 2.2, frame, bay[1], 112, back - 1.5, sockColors[b], {
				material = Enum.Material.Fabric,
				shadow = false,
			})
		end
	elseif level == 4 then
		-- matchstick panelling
		for x = -58, 58, 3.4 do
			if math.abs(math.abs(x) - 30) >= 5 then
				block(dressing, "Match", 2.6, 100, 1, frame, x, 2, back - 0.5, 0xE8C890, {
					material = Enum.Material.Wood,
					shadow = false,
				})
				block(dressing, "MatchHead", 2.8, 2.6, 1.4, frame, x, 100, back - 0.7, 0xC0392B, { shadow = false })
			end
		end
	elseif level == 5 then
		-- shiny sweet wrappers
		local wrappers = { 0xFF5FA8, 0x7AE8FF, 0xFFD95A, 0x9B7BFF, 0x3DDC97 }
		for k = 0, 21 do
			local x, y = 54 - ((k * 37) % 108), 4 + ((k * 29) % 150)
			Kit.part(
				dressing,
				"Wrapper",
				Vector3.new(12, 8, 0.6),
				frame * CFrame.new(x, y + 4, back - 0.4) * CFrame.Angles(0, 0, -((k % 5) - 2) * 0.25),
				wrappers[k % 5 + 1],
				{ material = Enum.Material.Foil, reflectance = 0.2, shadow = false }
			)
		end
	elseif level == 6 then
		-- LED strips across the back
		for _, strip in { { 0x7AE8FF, 90 }, { 0xFF5FA8, 50 }, { 0x9B7BFF, 130 } } do
			block(dressing, "LED", BW - 4, 1, 1, frame, 0, strip[2], BD - 11, strip[1], {
				material = Enum.Material.Neon,
				collide = false,
			})
		end
	elseif level == 7 then
		-- stacks of gold coins at both front corners
		for _, x in { -56, 56 } do
			for k = 0, 11 do
				Kit.disc(dressing, "CoinStack", 3, 1, frame * CFrame.new(x, LIFT + 0.5 + k * 1.05, 6), GOLD, {
					material = Enum.Material.Foil,
				})
			end
		end
	end

	-- Fairy light hanging off the yellow cable, in the level's colour
	local fairy = Kit.folder(home, "FairyLight")
	local cz = BD - 11
	for k = 0, 8 do
		local x = 50 - k * 12.5
		local y = 62 - math.sin(k / 8 * math.pi) * 1.5 - 2.2
		Kit.ball(
			fairy,
			"Bulb",
			1.2,
			(frame * CFrame.new(x, y, cz - 1.6)).Position,
			if k % 2 == 1 then look.fairy else 0xFFF1C8,
			{
				material = Enum.Material.Neon,
				collide = false,
			}
		)
	end
	local glow = Kit.part(fairy, "Glow", Vector3.one, frame * CFrame.new(0, 50, BD / 2), look.fairy, {
		collide = false,
		transparency = 1,
	})
	-- soft: a warm wash on the back, not a flood (Dylan: "too bright of lights in base")
	Kit.light(glow, "PointLight", look.fairy, if level == 6 then 1.2 else 1, 50, { Shadows = true })
	-- a faint cool fill near the front, so the home reads at night (the room's moonlight can't reach in)
	local fill = Kit.part(fairy, "Fill", Vector3.one, frame * CFrame.new(0, 45, 40), 0xFFFFFF, {
		collide = false,
		transparency = 1,
	})
	Kit.light(fill, "PointLight", 0xD8E0FF, 0.65, 60)

	-- The pen floor, dressed for the level (a layer on the pen part)
	local pen = home:FindFirstChild("Pen") :: BasePart
	local penFloor = Kit.folder(home, "PenFloor")
	local PW, PZ0, PZ1 = MapConfig.PEN_WIDTH, MapConfig.PEN_FRONT, MapConfig.PEN_BACK
	local top = LIFT + 0.6
	pen.Color = rgb(look.pen)
	pen.Material = if level == 1
		then Enum.Material.Cardboard
		elseif level == 4 then Enum.Material.WoodPlanks
		elseif level == 7 then Enum.Material.Foil
		elseif level == 3 then Enum.Material.Plastic
		else Enum.Material.Fabric
	pen.MaterialVariant = if level == 3 then (variant(Homes.STUDS) or "") else ""
	if level == 2 or level == 5 then
		-- pink and white stripes
		pen.Color = Color3.new(1, 1, 1)
		local n = if level == 2 then 12 else 14
		local step = (PZ1 - PZ0) / n
		for k = 0, n - 1, 2 do
			block(penFloor, "Stripe", PW, 0.1, step, frame, 0, top, PZ0 + (k + 0.5) * step, look.pen, {
				material = Enum.Material.Fabric,
				collide = false,
			})
		end
	elseif level == 6 then
		for _, z in { PZ0, PZ1 } do
			block(penFloor, "Edge", PW, 0.8, 1, frame, 0, top - 0.4, z, 0x7AE8FF, {
				material = Enum.Material.Neon,
				collide = false,
			})
		end
	elseif level == 3 and not variant(Homes.STUDS) then
		-- a studded brick plate
		for ix = -5, 5 do
			for iz = 0, 9 do
				Kit.disc(
					penFloor,
					"Stud",
					1.6,
					0.8,
					frame * CFrame.new(ix * 10, top + 0.4, PZ0 + 6 + iz * 11.5),
					look.pen,
					{
						material = Enum.Material.Plastic,
						collide = false,
					}
				)
			end
		end
	end

	-- the wheel has its own level (the home's WheelLevel attribute) when game code has set one
	Homes.buildWheel(Kit, MapConfig, home, frame, (home:GetAttribute("WheelLevel") :: number?) or level)
end

-- Particle presets for the wheel looks (Roblox's built-in particle textures)
local SPARKS = "rbxasset://textures/particles/sparkles_main.dds"
local FLAME = "rbxasset://textures/particles/fire_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local WHEEL_PARTICLES = {
	sparkle = { texture = SPARKS, size = 0.8, speed = 2, life = 1.2, rate = 8 },
	stars = { texture = SPARKS, size = 0.5, speed = 0.6, life = 2.5, rate = 6 },
	snow = { texture = SPARKS, size = 0.45, speed = 0.5, life = 3, rate = 8, accel = Vector3.new(0, -2, 0) },
	bubble = { texture = SPARKS, size = 0.9, speed = 0.5, life = 2.5, rate = 5, accel = Vector3.new(0, 1.5, 0) },
	ember = { texture = FLAME, size = 0.45, speed = 2, life = 1.6, rate = 10, accel = Vector3.new(0, 3, 0) },
	fire = { texture = FLAME, size = 1.6, speed = 1.5, life = 0.9, rate = 16, accel = Vector3.new(0, 2, 0) },
	spark = { texture = SPARKS, size = 0.7, speed = 6, life = 0.35, rate = 7 },
	wisp = { texture = SMOKE, size = 1.6, speed = 0.8, life = 2.5, rate = 4, alpha = 0.6, accel = Vector3.new(0, 1, 0) },
	swirl = { texture = SMOKE, size = 2.2, speed = 0.4, life = 2, rate = 6, alpha = 0.5, spin = 120, dark = true },
}

-- The Speed wheel, dressed for its level: open sides (a ring, spokes and a hub, so you can see the runner inside)
-- that get wilder with every level, from a plain cardboard spool to Infinity. Replaces the home's old wheel. Game
-- code spins TrainingWheel.Wheel about its axle (Wheel's PrimaryPart, which runs along the home's x) by the Wheel's
-- Spin attribute and puts the runner at RunPoint; TrainPrompt is on the axle.
function Homes.buildWheel(Kit: any, MapConfig: any, home: Model, frame: CFrame, level: number)
	level = math.clamp(level, 1, #Homes.WHEEL_LOOK)
	local old = home:FindFirstChild("TrainingWheel")
	if old then
		old:Destroy()
	end
	local look = Homes.WHEEL_LOOK[level]
	local size = math.min(level, 7) -- it has to fit the home, so it stops growing at 7
	local R, W = MapConfig.wheelSize(size)
	local p = MapConfig.BURROW_LAYOUT.TrainingWheel.position
	local base = frame * CFrame.new(p.X, MapConfig.BURROW_FLOOR_LIFT, p.Z)
	local hub = base * CFrame.new(0, R + 2.2, 0)
	local model = Kit.model(home, "TrainingWheel", { Stat = "Speed", Level = level })
	local material = look.material
	local frameMaterial = look.frameMaterial or material
	local function opts(mat: Enum.Material?, clear: number?): any
		return { collide = false, material = mat or material, transparency = clear }
	end
	local function glow(on: boolean?): Enum.Material?
		return if on then Enum.Material.Neon else nil
	end
	-- a chunky voxel ball: three crossed blocks
	local function voxelBall(parent: Instance, name: string, at: CFrame, r: number, color: number, o: any)
		Kit.part(parent, name, Vector3.new(2 * r, 1.4 * r, 1.4 * r), at, color, o)
		Kit.part(parent, name, Vector3.new(1.4 * r, 2 * r, 1.4 * r), at, color, o)
		Kit.part(parent, name, Vector3.new(1.4 * r, 1.4 * r, 2 * r), at, color, o)
	end
	local top = 2 * R + 5 -- above everything that spins (base space): where a crown's arch or a halo goes

	-- the stand: two posts each side and a brace across the top
	for _, sx in { -1, 1 } do
		local x = sx * (W / 2 + 1.4)
		for _, z in { -3, 3 } do
			Kit.block(model, "Post", 1.4, R + 2.2, 1.4, base, x, 0, z, look.frame, { material = frameMaterial })
			if look.torches then
				-- a glowing block on the post with a flame
				local torch =
					Kit.block(model, "Torch", 1.2, 1.2, 1.2, base, x, R + 2.2, z, look.neon, opts(Enum.Material.Neon))
				local fire = Instance.new("Fire")
				fire.Size = 3
				fire.Heat = 6
				fire.Color = Kit.rgb(look.neon)
				fire.SecondaryColor = Kit.rgb(0xFFE14D)
				fire.Parent = torch
			end
			if look.horns then
				-- a horn on each post, curling outward
				local root = base * CFrame.new(x, R + 2.2, z) * CFrame.Angles(0, 0, -sx * math.rad(25))
				Kit.part(model, "Horn", Vector3.new(0.9, 1.8, 0.9), root * CFrame.new(0, 0.9, 0), look.horns, opts())
				Kit.part(
					model,
					"Horn",
					Vector3.new(0.6, 1.2, 0.6),
					root * CFrame.new(0, 1.8, 0) * CFrame.Angles(0, 0, -sx * math.rad(30)) * CFrame.new(0, 0.6, 0),
					look.horns,
					opts()
				)
			end
		end
		Kit.block(model, "Brace", 1.6, 1.6, 7.6, base, x, R + 2.2 - 1.8, 0, look.frame, { material = frameMaterial })
		if look.neon then
			-- a glowing strip along the brace
			Kit.block(model, "Strip", 0.4, 0.4, 7.8, base, x + sx * 0.8, R + 1, 0, look.neon, opts(Enum.Material.Neon))
		end
		if look.gems then
			Kit.part(
				model,
				"Gem",
				Vector3.one * 1.3,
				base * CFrame.new(x, R + 2.8, 0) * CFrame.Angles(math.pi / 4, 0, math.pi / 4),
				look.gems[1],
				opts(Enum.Material.Neon)
			)
		end
		if look.clouds then
			-- a storm cloud sitting on the brace
			for k, c in
				{
					{ 0, 0.6, 0, 2.6 },
					{ 0, 0.3, -2.2, 2 },
					{ 0, 0.3, 2.2, 2.1 },
					{ 0, 1.6, -0.9, 1.8 },
					{ 0, 1.4, 1.2, 1.6 },
				}
			do
				Kit.part(
					model,
					"Cloud",
					Vector3.one * c[4],
					base * CFrame.new(x + c[1], R + 2.2 + c[2], c[3]),
					if k % 2 == 0 then 0x5A6478 else 0x8A93A6,
					opts(Enum.Material.SmoothPlastic)
				)
			end
		end
		if look.boosters then
			-- a rocket booster on the outside of the stand, blasting fire downward
			local bx = sx * (W / 2 + 2.9)
			local body = base * CFrame.new(bx, R * 0.5 + 1.5, 0)
			Kit.part(
				model,
				"Booster",
				Vector3.new(1.8, R * 0.9, 1.8),
				body,
				0xFFFFFF,
				opts(Enum.Material.SmoothPlastic)
			)
			Kit.part(
				model,
				"Booster",
				Vector3.new(1.2, 1.2, 1.2),
				body * CFrame.new(0, R * 0.45 + 0.6, 0),
				0xE04848,
				opts(Enum.Material.SmoothPlastic)
			)
			for _, fz in { -1, 1 } do
				Kit.part(
					model,
					"Fin",
					Vector3.new(0.3, 1.8, 1.2),
					body * CFrame.new(0, -R * 0.45 + 0.9, fz * 1.4),
					0xE04848,
					opts(Enum.Material.SmoothPlastic)
				)
			end
			local nozzle = Kit.part(
				model,
				"Nozzle",
				Vector3.new(1.4, 0.6, 1.4),
				body * CFrame.new(0, -R * 0.45 - 0.3, 0),
				0x4A5060,
				opts(Enum.Material.Metal)
			)
			local e = Instance.new("ParticleEmitter")
			e.Texture = FLAME
			e.EmissionDirection = Enum.NormalId.Bottom
			e.Color = ColorSequence.new(Kit.rgb(0xFFE14D), Kit.rgb(0xFF5A1A))
			e.LightEmission = 1
			e.Size = NumberSequence.new(1, 0.2)
			e.Speed = NumberRange.new(4, 6)
			e.Lifetime = NumberRange.new(0.2, 0.35)
			e.Rate = 30
			e.SpreadAngle = Vector2.new(12, 12)
			e.Parent = nozzle
		end
		if look.wings then
			-- feathered wings fanning up off the top of the stand, outside the ring
			for _, wz in { -1, 1 } do
				for j = 1, 4 do
					local angle = math.rad(18 + 17 * (j - 1))
					local length = 2.6 + 1.1 * j
					local root = base
						* CFrame.new(sx * (W / 2 + 2), R * 1.55 + 2.2, wz * 0.8)
						* CFrame.Angles(0, 0, sx * math.rad(12))
						* CFrame.Angles(-wz * (math.pi / 2 - angle), 0, 0)
					Kit.part(
						model,
						"Feather",
						Vector3.new(0.4, length, 1.1),
						root * CFrame.new(0, length / 2, 0),
						if j % 2 == 0 then look.wings else 0xF4F0EA,
						opts(Enum.Material.SmoothPlastic)
					)
				end
			end
		end
	end
	if look.crown then
		-- an arch over the wheel with a crown on top
		for _, sx in { -1, 1 } do
			local x = sx * (W / 2 + 1.4)
			Kit.block(
				model,
				"Arch",
				1,
				top - (R + 2.2),
				1,
				base,
				x,
				R + 2.2,
				0,
				look.frame,
				{ material = frameMaterial }
			)
		end
		Kit.block(model, "Arch", W + 3.8, 1, 1, base, 0, top, 0, look.frame, { material = frameMaterial })
		local crownAt = base * CFrame.new(0, top + 1, 0)
		for k = 0, 7 do
			local a = 2 * math.pi * k / 8
			local at = crownAt * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, 1.7)
			Kit.part(model, "Crown", Vector3.new(1.4, 1.2, 0.5), at, look.crown, opts(Enum.Material.SmoothPlastic))
			if k % 2 == 0 then
				Kit.part(
					model,
					"Crown",
					Vector3.new(0.7, 1.3, 0.5),
					at * CFrame.new(0, 1.2, 0),
					look.crown,
					opts(Enum.Material.SmoothPlastic)
				)
				Kit.part(
					model,
					"Gem",
					Vector3.one * 0.6,
					at * CFrame.new(0, 2, 0) * CFrame.Angles(math.pi / 4, 0, math.pi / 4),
					if look.gems then look.gems[(k // 2) % #look.gems + 1] else 0xFF4D5E,
					opts(Enum.Material.Neon)
				)
			end
		end
	end
	if look.halo then
		local haloAt = base * CFrame.new(0, (if look.crown then top + 4.5 else top), 0)
		for k = 0, 11 do
			local a = 2 * math.pi * k / 12
			Kit.part(
				model,
				"Halo",
				Vector3.new(1.5, 0.4, 0.5),
				haloAt * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, 2.6),
				look.halo,
				opts(Enum.Material.Neon)
			)
		end
	end

	local wheel = Kit.model(model, "Wheel")
	local axle = Kit.part(wheel, "Axle", Vector3.new(W + 3.6, 1.2, 1.2), hub, look.frame, {
		collide = false,
		shape = Enum.PartType.Cylinder,
		material = frameMaterial,
	})
	local function onSide(sx: number, angle: number, radius: number): CFrame
		return hub * CFrame.new(sx * W / 2, 0, 0) * CFrame.Angles(angle, 0, 0) * CFrame.new(0, radius, 0)
	end
	local streaks = 0
	for _, sx in { -1, 1 } do
		-- the ring: segments in the level's colours
		local n = look.segments
		local chord = 2 * (R + 0.5) * math.sin(math.pi / n)
		for k = 0, n - 1 do
			local color = look.ring[k % #look.ring + 1]
			local at = onSide(sx, 2 * math.pi * k / n, R)
			local lit = look.neonRing and k % 2 == 1
			local rim = Kit.part(wheel, "Rim", Vector3.new(0.9, 1, chord), at, color, opts(glow(lit), look.clear))
			if look.studs and k % 2 == 0 then
				-- toy-brick studs on the outside of the ring
				Kit.part(wheel, "Stud", Vector3.new(0.4, 0.8, 0.8), at * CFrame.new(sx * 0.6, 0, 0), color, {
					collide = false,
					material = material,
					shape = Enum.PartType.Cylinder,
				})
			end
			if look.gems and k % 2 == 1 then
				-- jewels set round the ring
				Kit.part(
					wheel,
					"Gem",
					Vector3.one * 0.8,
					at * CFrame.new(sx * 0.55, 0, 0) * CFrame.Angles(math.pi / 4, 0, 0),
					look.gems[(k // 2) % #look.gems + 1],
					opts(Enum.Material.Neon)
				)
			end
			if look.pips and k % 2 == 0 then
				-- bubbles (or stars) stuck round the outside
				Kit.part(
					wheel,
					"Pip",
					Vector3.one * 1.1,
					at * CFrame.new(sx * 0.6, 0.3, 0),
					look.pips[(k // 2) % #look.pips + 1],
					{
						collide = false,
						material = if look.clear then Enum.Material.Glass else Enum.Material.Neon,
						transparency = look.clear,
						shape = Enum.PartType.Ball,
					}
				)
			end
			local spikes = look.spikes
			if spikes and k % (spikes.every or 1) == 0 then
				-- plates, icicles, gear teeth, crystals or rays sticking out of the ring (short enough to clear the floor)
				local length = math.min(spikes.length, 1.7)
				local width = spikes.width
				local spikeColor = spikes.colors[(k // (spikes.every or 1)) % #spikes.colors + 1]
				local spikeOpts = opts(glow(spikes.neon), look.clear)
				local out = at * CFrame.new(0, 0.5, 0)
				if spikes.crystal then
					out *= CFrame.Angles(0, math.pi / 4, 0)
					Kit.part(
						wheel,
						"Spike",
						Vector3.new(width, length * 0.65, width),
						out * CFrame.new(0, length * 0.33, 0),
						spikeColor,
						spikeOpts
					)
					Kit.part(
						wheel,
						"Spike",
						Vector3.new(width * 0.5, length * 0.35, width * 0.5),
						out * CFrame.new(0, length * 0.82, 0),
						spikeColor,
						spikeOpts
					)
				else
					Kit.part(
						wheel,
						"Spike",
						Vector3.new(0.6, length, width),
						out * CFrame.new(0, length / 2, 0),
						spikeColor,
						spikeOpts
					)
				end
			end
			if look.trail and streaks < 4 and k % math.max(1, n // 2) == 0 then
				-- light streaks off the ring while it spins
				streaks += 1
				local a0 = Instance.new("Attachment")
				a0.Position = Vector3.new(0, -1.2, 0)
				a0.Parent = rim
				local a1 = Instance.new("Attachment")
				a1.Position = Vector3.new(0, 0.6, 0)
				a1.Parent = rim
				local keys = {}
				for i, c in look.trail do
					table.insert(keys, ColorSequenceKeypoint.new((i - 1) / math.max(1, #look.trail - 1), Kit.rgb(c)))
				end
				if #keys == 1 then
					table.insert(keys, ColorSequenceKeypoint.new(1, keys[1].Value))
				end
				local trail = Instance.new("Trail")
				trail.Attachment0 = a0
				trail.Attachment1 = a1
				trail.Color = ColorSequence.new(keys)
				trail.Transparency = NumberSequence.new(0.25, 1)
				trail.Lifetime = 0.35
				trail.LightEmission = 1
				trail.Parent = rim
			end
		end
		-- glowing rings inside the ring (galaxy, black hole): one per colour, or one ring cycling many colours
		if look.inner then
			local rings = if #look.inner <= 3 then #look.inner else 1
			for i = 1, rings do
				local radius = R * (0.78 - 0.17 * (i - 1))
				local count = 14
				local innerChord = 2 * radius * math.sin(math.pi / count)
				for k = 0, count - 1 do
					local color = if rings == 1 and #look.inner > 1
						then look.inner[k % #look.inner + 1]
						else look.inner[i]
					Kit.part(
						wheel,
						"Inner",
						Vector3.new(0.6, 0.6, innerChord),
						onSide(sx, 2 * math.pi * (k + 0.5 * i) / count, radius) * CFrame.new(sx * 0.1, 0, 0),
						color,
						opts(Enum.Material.Neon)
					)
				end
			end
		end
		-- the spokes: plain, bones, lightning bolts; ship's-wheel handles past the ring; moons on them
		for k = 0, look.spokes - 1 do
			local a = 2 * math.pi * (k + 0.5) / look.spokes
			local spokeColor = if look.rainbowSpokes then look.ring[k % #look.ring + 1] else look.spoke
			local spokeOpts = opts(glow(look.neonSpokes or look.bolts), look.clear)
			if look.bolts then
				-- a zigzag in three pieces
				local piece = (R - 1) / 3
				for i = 0, 2 do
					local offset = if i == 1 then 0.12 else -0.06
					Kit.part(
						wheel,
						"Spoke",
						Vector3.new(0.5, piece + 0.4, 0.7),
						onSide(sx, a + offset, 0.5 + piece * (i + 0.5))
							* CFrame.Angles(if i == 1 then -0.5 else 0.5, 0, 0),
						spokeColor,
						spokeOpts
					)
				end
			else
				Kit.part(
					wheel,
					"Spoke",
					Vector3.new(0.6, R - 0.5, 0.7),
					onSide(sx, a, (R - 0.5) / 2),
					spokeColor,
					spokeOpts
				)
			end
			if look.bones then
				-- knobbly bone ends
				for _, r in { 1.6, R - 1.2 } do
					Kit.part(wheel, "Knob", Vector3.new(0.9, 0.8, 1.5), onSide(sx, a, r), spokeColor, opts())
				end
			end
			if look.handles then
				Kit.part(wheel, "Handle", Vector3.new(0.8, 1.8, 0.8), onSide(sx, a, R + 1.4), look.spoke, opts())
			end
			if look.moons and k % 2 == 0 then
				voxelBall(
					wheel,
					"Moon",
					onSide(sx, a, R * 0.55) * CFrame.new(sx * 0.5, 0, 0),
					0.7,
					look.moons[(k // 2) % #look.moons + 1],
					opts(Enum.Material.SmoothPlastic)
				)
			end
		end
		-- the hub: a plain cap, a lollipop swirl (candy), a vault dial (gold), a skull or a diamond
		local capAt = hub * CFrame.new(sx * (W / 2 + 0.15), 0, 0)
		if look.skull then
			local face = capAt * CFrame.new(sx * 0.4, 0, 0)
			Kit.part(wheel, "Hub", Vector3.new(1.6, 2.6, 2.6), face, 0xF2EEE0, opts(Enum.Material.SmoothPlastic))
			for _, ez in { -0.6, 0.6 } do
				Kit.part(
					wheel,
					"Eye",
					Vector3.new(0.3, 0.7, 0.7),
					face * CFrame.new(sx * 0.75, 0.3, ez),
					look.neon or 0x1A1430,
					opts(Enum.Material.Neon)
				)
			end
		elseif look.diamond then
			Kit.part(
				wheel,
				"Hub",
				Vector3.one * 2.4,
				capAt * CFrame.new(sx * 0.5, 0, 0) * CFrame.Angles(math.pi / 4, 0, 0),
				0xCFFAFF,
				opts(Enum.Material.Glass, 0.15)
			)
		else
			local capR = if look.lollipop then 0.3 * R elseif look.vault then 0.24 * R else 1.3
			Kit.part(wheel, "Hub", Vector3.new(0.8, 2 * capR, 2 * capR), capAt, look.hub or look.frame, {
				collide = false,
				shape = Enum.PartType.Cylinder,
				material = material,
			})
			if look.lollipop or look.vault then
				Kit.part(
					wheel,
					"Hub",
					Vector3.new(0.9, capR, capR),
					capAt * CFrame.new(sx * 0.1, 0, 0),
					if look.lollipop then 0xFFFFFF else 0xD9A21E,
					{ collide = false, shape = Enum.PartType.Cylinder, material = material }
				)
			end
		end
	end
	-- a voxel planet (or sun, or black hole) in the middle, with a tilted ring round it
	if look.planet then
		local planet = look.planet
		voxelBall(
			wheel,
			"Planet",
			hub,
			0.24 * R,
			planet.body,
			opts(if planet.glow then Enum.Material.Neon else Enum.Material.SmoothPlastic)
		)
		if planet.band then
			local tilt = hub * CFrame.Angles(0, 0, math.rad(25))
			for k = 0, 13 do
				local a = 2 * math.pi * k / 14
				Kit.part(
					wheel,
					"Band",
					Vector3.new(1.4, 0.3, 1.4),
					tilt * CFrame.new(math.cos(a) * 0.42 * R, 0, math.sin(a) * 0.42 * R),
					planet.band,
					opts(Enum.Material.SmoothPlastic)
				)
			end
		end
	end
	-- the rungs you run on
	local rungs = MapConfig.wheelRungs(size)
	for k = 0, rungs - 1 do
		local a = 2 * math.pi * k / rungs
		Kit.part(
			wheel,
			"Rung",
			Vector3.new(W - 0.2, 0.8, 0.8),
			hub * CFrame.new(0, math.cos(a) * (R - 0.5), math.sin(a) * (R - 0.5)),
			look.rungs[k % #look.rungs + 1],
			{
				collide = false,
				shape = Enum.PartType.Cylinder,
				material = if look.neonRungs then Enum.Material.Neon else Enum.Material.SmoothPlastic,
			}
		)
	end
	wheel.PrimaryPart = axle
	-- idle spin: faster with the level (HomeView spins it faster still while its owner trains)
	wheel:SetAttribute("Spin", MapConfig.wheelSpin(size) + 0.08 * math.max(0, level - 7))
	if look.light then
		Kit.light(axle, "PointLight", look.light, if level == 22 then 0.9 else 0.6, 16)
	end
	-- the look's particles fill a box round the wheel (it doesn't spin, so it costs nothing to move)
	if look.particles then
		local box = Kit.part(model, "Fx", Vector3.new(W + 2, 2 * R + 2, 2 * R + 2), hub, 0xFFFFFF, {
			collide = false,
			transparency = 1,
			query = false,
		})
		for _, spec in look.particles do
			local preset = WHEEL_PARTICLES[spec.kind] or WHEEL_PARTICLES.sparkle
			local e = Instance.new("ParticleEmitter")
			e.Name = "Wheel_" .. spec.kind
			e.Texture = preset.texture
			e.Color = ColorSequence.new(Kit.rgb(spec.color))
			e.LightEmission = if preset.dark then 0 else 1
			e.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.2, preset.size),
				NumberSequenceKeypoint.new(1, 0),
			})
			e.Transparency = NumberSequence.new(preset.alpha or 0.1)
			e.Speed = NumberRange.new(preset.speed * 0.5, preset.speed)
			e.Lifetime = NumberRange.new(preset.life * 0.6, preset.life)
			e.Rate = preset.rate
			e.SpreadAngle = Vector2.new(180, 180)
			e.Acceleration = preset.accel or Vector3.zero
			e.Rotation = NumberRange.new(0, 360)
			e.RotSpeed = NumberRange.new(-(preset.spin or 30), preset.spin or 30)
			e.Shape = Enum.ParticleEmitterShape.Box
			e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
			e.Parent = box
		end
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TrainPrompt"
	prompt.ActionText = "Train Speed"
	prompt.ObjectText = "Speed wheel · Lv " .. level
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = axle
	Kit.part(model, "RunPoint", Vector3.one, base * CFrame.new(0, 1, 0) * CFrame.Angles(0, math.pi, 0), 0x3DDC97, {
		collide = false,
		transparency = 1,
	})

	-- the tag over the wheel, in the level's colour (above the crown or halo when there is one)
	local tagLift = if look.crown
		then top - R - 2.2 + (if look.halo then 8 else 5)
		elseif look.halo then top - R - 0.2
		else R + 4
	local tagAnchor = Kit.part(model, "Tag", Vector3.one, hub * CFrame.new(0, tagLift, 0), 0xFFFFFF, {
		collide = false,
		transparency = 1,
	})
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromScale(13, 2.85)
	billboard.MaxDistance = 120
	billboard.LightInfluence = 0
	billboard.Parent = tagAnchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Kit.rgb(look.tag)
	label.TextColor3 = Color3.fromRGB(26, 20, 48)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Text = (if level >= 7 then "★ " else "") .. "SPEED · Lv " .. level
	label.Parent = billboard
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.4, 0)
	corner.Parent = label
end

return Homes
