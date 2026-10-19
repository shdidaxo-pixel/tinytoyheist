--!strict
-- The 8 player homes in the curved wall: open bays in the wall framing (studs, blocking, top plate, OSB at the back),
-- torn drywall up the front edges, cables stapled up the studs, an outlet, a fairy light, the toy pen at the back, and
-- the door props (cash thimble, lock push pin, Index domino, levelled Speed wheel, matchbox spawn bed), a sign on a
-- lolly stick and the lock bars.
--
-- Home space: origin at the middle of the open front, on the floor; LookVector into the room, +Z back into the wall,
-- x across (walking in, -x is on your right). MapConfig.BURROW_LAYOUT positions are in this space.
--
-- Used by tools/build-bedroom.luau (build) and by game code (applyLevel, setSign, setLocked) to change a home live.

local Homes = {}

-- A studded toy-brick material in MaterialService, when the place has one
Homes.STUDS = "" -- none yet (the AI stud materials came out as grids and bricks)

-- How each level looks: fairy light, pen floor, wheel (sides, rungs, frame), and the dressing in the bays
Homes.LEVEL_LOOK = {
	{ fairy = 0xFFD27A, pen = 0xC49A6C, wheel = { 0xD9B27C, 0xFFC93C, 0x8A5A34 } }, -- 1 Cardboard
	{ fairy = 0xFFB0C8, pen = 0xF28DB2, wheel = { 0xF28DB2, 0xFFFFFF, 0x7FD6E8 } }, -- 2 Sock-lined
	{ fairy = 0xFFE08A, pen = 0x3DA5FF, wheel = { 0xE04848, 0xFFC93C, 0x4DA8FF } }, -- 3 Toy bricks
	{ fairy = 0xFF9A4A, pen = 0xC89A62, wheel = { 0xB07A48, 0xE8C890, 0x6B4A2E } }, -- 4 Cosy cabin
	{ fairy = 0xFF8FC8, pen = 0xFF8FC8, wheel = { 0xFF8FC8, 0xFFFFFF, 0x8FE8D0 } }, -- 5 Candy land
	{ fairy = 0x7AE8FF, pen = 0x1A1430, wheel = { 0x1A1430, 0x7AE8FF, 0x9B7BFF } }, -- 6 Arcade neon
	{ fairy = 0xFFE07A, pen = 0xFFC93C, wheel = { 0xFFC93C, 0xFFF1B0, 0xD9A21E } }, -- 7 Golden vault
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
	local rgb, part, block = Kit.rgb, Kit.part, Kit.block
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

	-- Cash pile: a steel thimble heaped with gold coins, a few spilled. Walk over it to collect.
	local thimbleAt = prop("CashPile")
	local cash = Kit.disc(home, "CashPile", 5.2, 8, thimbleAt * CFrame.new(0, 4, 0), 0xC9CED8, {
		material = Enum.Material.Metal,
		attributes = { Cash = 0 },
	})
	Kit.disc(cash, "Rim", 5.5, 1, thimbleAt * CFrame.new(0, 7.6, 0), 0xB8BFC8, {
		material = Enum.Material.Metal,
		collide = false,
	})
	for k = 0, 15 do
		local angle = k * 2.4
		local r = if k < 9 then math.sqrt(k) * 1.4 else 7 + (k * 3) % 4
		local y = if k < 9 then 8.4 + math.max(0, 2.4 - r) else 0.3
		local coin = Kit.disc(
			cash,
			"Coin",
			1.8,
			0.6,
			thimbleAt
				* CFrame.new(math.cos(angle) * r, y, math.sin(angle) * r)
				* CFrame.Angles(math.sin(k) * 0.4, 0, math.cos(k) * 0.4),
			0xF2C94C,
			{ material = Enum.Material.Foil, collide = false }
		)
		coin.Reflectance = 0.1
	end

	-- Door Lock button: a big red push pin, stuck in the floor on its needle, leaning a little
	local pinAt = prop("LockButton") * CFrame.Angles(0, 0, 0.12)
	local lock =
		Kit.disc(home, "LockButton", 4.5, 2, pinAt * CFrame.new(0, 4, 0), RED, { material = Enum.Material.Plastic })
	Kit.disc(lock, "Waist", 2.7, 4, pinAt * CFrame.new(0, 7, 0), RED, { material = Enum.Material.Plastic })
	Kit.disc(lock, "Cap", 3.6, 1.6, pinAt * CFrame.new(0, 9.6, 0), RED, { material = Enum.Material.Plastic })
	Kit.disc(lock, "Needle", 0.35, 3, pinAt * CFrame.new(0, 1.5, 0), 0xB8BFC8, {
		material = Enum.Material.Metal,
		collide = false,
	})
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "LockPrompt"
	prompt.ActionText = "Lock door"
	prompt.ObjectText = "Door Lock"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = lock

	-- Toy Index: a black domino stand with white pips, a matchbook propped open on top
	local indexAt = prop("ToyIndex")
	local stand = block(home, "IndexStand", 9, 5, 5, indexAt, 0, 0, 0, 0x1A1430)
	for k, pip in { { -2.6, 1.4 }, { -2.6, 3.6 }, { -1.4, 2.5 }, { 1.4, 1.4 }, { 2.6, 3.6 }, { 2.6, 1.4 } } do
		block(stand, "Pip", 0.9, 0.9, 0.3, indexAt, pip[1], pip[2] - 0.45, -2.6, 0xFFFFFF, { collide = false })
		if k == 3 then
			block(stand, "Line", 0.3, 4.4, 0.3, indexAt, 0, 0.3, -2.6, 0xFFFFFF, { collide = false })
		end
	end
	local book = block(
		home,
		"IndexBook",
		5,
		0.6,
		7,
		indexAt * CFrame.new(-2.3, 5.4, 0) * CFrame.Angles(0, 0, 0.35),
		0,
		0,
		0,
		0xE04848
	)
	block(book, "Cover", 5, 0.6, 7, indexAt * CFrame.new(2.3, 5.4, 0) * CFrame.Angles(0, 0, -0.35), 0, 0, 0, 0xF4F1E8)

	-- Spawn: the matchbox bed is the SpawnLocation, so you wake up on it
	local bedAt = prop("Spawn")
	local spawnPad = Instance.new("SpawnLocation")
	spawnPad.Name = "Spawn"
	spawnPad.Anchored = true
	spawnPad.Size = Vector3.new(16, 3.4, 10)
	spawnPad.CFrame = bedAt * CFrame.new(0, 1.7, 0)
	spawnPad.Color = rgb(0xE8D2A8)
	spawnPad.Material = Enum.Material.Cardboard
	spawnPad.TopSurface = Enum.SurfaceType.Smooth
	spawnPad.Duration = 0
	spawnPad.Neutral = true
	spawnPad.CastShadow = false
	spawnPad.Parent = home
	block(spawnPad, "Sleeve", 9, 3.8, 10.4, bedAt, -4, 0, 0, 0x2F6FB9, { collide = false })
	for k = 0, 5 do
		block(
			spawnPad,
			"Blanket",
			11 / 6,
			1,
			8,
			bedAt,
			1.5 - 5.5 + (k + 0.5) * 11 / 6,
			3.4,
			0,
			if k % 2 == 0 then 0xF28DB2 else 0xFFFFFF,
			{
				material = Enum.Material.Fabric,
				collide = false,
			}
		)
	end
	for k = 0, 15 do
		local a0, a1 = k / 16 * 2 * math.pi, (k + 1) / 16 * 2 * math.pi
		local r = 9.75
		Kit.rod(
			spawnPad,
			"Ring",
			(bedAt * CFrame.new(math.cos(a0) * r, 0.12, math.sin(a0) * r)).Position,
			(bedAt * CFrame.new(math.cos(a1) * r, 0.12, math.sin(a1) * r)).Position,
			0.75,
			0x3DDC97,
			{ material = Enum.Material.Neon, collide = false, transparency = 0.35 }
		)
	end

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

	Homes.applyLevel(Kit, MapConfig, home, level)
	return home
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

-- Show or hide the lock bars and darken the push pin. The barrier stays walk-through: game code puts strangers who
-- walk into a locked home back outside, so the owner can still come and go.
function Homes.setLocked(home: Model, locked: boolean)
	local bars = home:FindFirstChild("LockBars")
	if bars then
		for _, bar in bars:GetChildren() do
			if bar:IsA("BasePart") then
				bar.Transparency = if locked then 0 else 1
			end
		end
	end
	local pin = home:FindFirstChild("LockButton")
	if pin and pin:IsA("BasePart") then
		local color = if locked then Color3.fromRGB(138, 31, 42) else Color3.fromRGB(255, 77, 94)
		pin.Color = color
		for _, p in pin:GetChildren() do
			if p:IsA("BasePart") and p.Name ~= "Needle" then
				p.Color = color
			end
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
	Kit.light(glow, "PointLight", look.fairy, if level == 6 then 2.4 else 2, 60, { Shadows = true })
	-- a soft cool fill near the front, so the home reads at night (the room's moonlight can't reach in)
	local fill = Kit.part(fairy, "Fill", Vector3.one, frame * CFrame.new(0, 45, 40), 0xFFFFFF, {
		collide = false,
		transparency = 1,
	})
	Kit.light(fill, "PointLight", 0xD8E0FF, 1.4, 60)

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

	Homes.buildWheel(Kit, MapConfig, home, frame, level)
end

-- The Speed wheel, grown and dressed for the level. Game code spins TrainingWheel.Wheel about its axle (Wheel's
-- PrimaryPart, which runs along the home's x) and puts the runner at RunPoint.
function Homes.buildWheel(Kit: any, MapConfig: any, home: Model, frame: CFrame, level: number)
	local look = Homes.LEVEL_LOOK[level].wheel
	local R, W = MapConfig.wheelSize(level)
	local p = MapConfig.BURROW_LAYOUT.TrainingWheel.position
	local base = frame * CFrame.new(p.X, MapConfig.BURROW_FLOOR_LIFT, p.Z)
	local hub = base * CFrame.new(0, R + 2.2, 0)
	local model = Kit.model(home, "TrainingWheel", { Stat = "Speed", Level = level })
	local metal = level == 7
	local frameMaterial = if metal then Enum.Material.Foil else Enum.Material.Wood
	for _, sx in { -1, 1 } do
		local x = sx * (W / 2 + 1.4)
		for _, z in { -3, 3 } do
			Kit.block(model, "Post", 1.4, R + 2.2, 1.4, base, x, 0, z, look[3], { material = frameMaterial })
		end
		Kit.block(model, "Brace", 1.6, 1.6, 7.6, base, x, R + 2.2 - 1.8, 0, look[3], { material = frameMaterial })
	end

	local wheel = Kit.model(model, "Wheel")
	local free = { collide = false, material = if metal then Enum.Material.Foil else Enum.Material.SmoothPlastic }
	local axle = Kit.part(
		wheel,
		"Axle",
		Vector3.new(W + 3.6, 1.2, 1.2),
		hub,
		look[3],
		{ collide = false, shape = Enum.PartType.Cylinder, material = frameMaterial }
	)
	for _, sx in { -1, 1 } do
		Kit.part(wheel, "Side", Vector3.new(0.9, 2 * R, 2 * R), hub * CFrame.new(sx * W / 2, 0, 0), look[1], {
			collide = false,
			shape = Enum.PartType.Cylinder,
			material = free.material,
		})
		if level >= 3 then
			Kit.part(
				wheel,
				"Rim",
				Vector3.new(0.5, 2 * R + 1, 2 * R + 1),
				hub * CFrame.new(sx * (W / 2 + 0.6), 0, 0),
				look[3],
				{
					collide = false,
					shape = Enum.PartType.Cylinder,
					material = if level == 6 then Enum.Material.Neon else free.material,
				}
			)
		end
	end
	local rungs = MapConfig.wheelRungs(level)
	for k = 0, rungs - 1 do
		local a = 2 * math.pi * k / rungs
		Kit.part(
			wheel,
			"Rung",
			Vector3.new(W - 0.2, 0.8, 0.8),
			hub * CFrame.new(0, math.cos(a) * (R - 0.5), math.sin(a) * (R - 0.5)),
			look[2],
			{
				collide = false,
				shape = Enum.PartType.Cylinder,
				material = if level == 6 then Enum.Material.Neon else Enum.Material.SmoothPlastic,
			}
		)
	end
	wheel.PrimaryPart = axle
	wheel:SetAttribute("Spin", MapConfig.wheelSpin(level))
	if level >= 6 then
		Kit.light(axle, "PointLight", if level == 6 then 0x7AE8FF else 0xFFE07A, 1.2, 16)
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

	-- the tag over the wheel
	local tagAnchor = Kit.part(model, "Tag", Vector3.one, hub * CFrame.new(0, R + 4, 0), 0xFFFFFF, {
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
	label.BackgroundColor3 = Color3.fromRGB(77, 168, 255)
	label.TextColor3 = Color3.fromRGB(26, 20, 48)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Text = "SPEED · Lv " .. level
	label.Parent = billboard
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.4, 0)
	corner.Parent = label
end

return Homes
