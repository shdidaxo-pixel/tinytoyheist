--!strict
-- The bedroom's shell: the floor bands, the teal safe ring with its white edge, the tape lines and painted labels,
-- the curved wall the homes sit in (the solid walls between them), the shoulders, the long walls with their wallpaper,
-- the far wall with the open hallway door, a short hallway (blocked for now), the ceiling and its glow-star stickers.
-- Called by tools/build-bedroom.luau with the builder Kit and MapConfig.

return function(Kit: any, MapConfig: any, bedroom: Model)
	local rgb, part, block = Kit.rgb, Kit.part, Kit.block
	local HW, LEN, H = MapConfig.HALF_WIDTH, MapConfig.LENGTH, MapConfig.WALL_HEIGHT
	local T = MapConfig.WALL_THICKNESS
	local CZ, CR = MapConfig.HOME_CURVE_CENTER_Z, MapConfig.HOME_CURVE_RADIUS
	local SX, SZ = MapConfig.SHOULDER_START_X, MapConfig.SHOULDER_END_Z
	local DOOR_W, DOOR_H = MapConfig.DOOR_WIDTH, MapConfig.DOOR_HEIGHT
	local ORIGIN = CFrame.new()

	local SAGE = rgb(0x9DB08A) -- painted in its true colour; the night light turns it blue-grey
	local PAPER = rgb(0x8A9E78)
	local PAPER_STRIPE = rgb(0x97AA84)
	local CREAM = rgb(0xF1EBDD)
	local BASEBOARD = rgb(0xE6E1D6)

	---------------------------------------------------------------------------------------------------------------
	-- Floor. The run's bands sit with their tops at y = 0. The start area is three flat discs stacked a little lower
	-- (teal ring under the white line under the carpet), so the run's carpet covers their front halves cleanly.
	local floor = Kit.folder(bedroom, "Floor")
	part(floor, "Subfloor", Vector3.new(1200, 2, 1960), CFrame.new(0, -1.6, 780), 0x3A2A1C, { shadow = false })
	local carpetVariant = nil -- the AI carpets came out garish; the built-in Carpet reads better
	local studs = nil -- a studded material for the safe ring; the AI ones came out as grids and bricks, so plain teal
	local bands = {
		Carpet = { color = 0x6A5BA0, material = Enum.Material.Carpet, variant = carpetVariant },
		Wood = { color = 0x9A7853, material = Enum.Material.WoodPlanks },
		Creaky = { color = 0x7A5A3C, material = Enum.Material.WoodPlanks },
	}
	local function band(name: string, x0: number, x1: number, z0: number, z1: number, top: number)
		local look = bands[name]
		local zone = nil
		for _, z in MapConfig.ZONES do
			if z.name == name then
				zone = z
			end
		end
		part(
			floor,
			name,
			Vector3.new(x1 - x0, 1, z1 - z0),
			CFrame.new((x0 + x1) / 2, top - 0.5, (z0 + z1) / 2),
			look.color,
			{
				material = look.material,
				variant = look.variant,
				shadow = false,
				attributes = { FloorType = name, Noise = if zone then zone.noise else 1 },
			}
		)
	end
	band("Carpet", -SX - 2, SX + 2, CZ, SZ, 0) -- under the shoulders (the walls hide what pokes out)
	band("Carpet", -HW - T / 2, HW + T / 2, SZ, MapConfig.ZONES[1].untilZ, 0)
	band("Wood", -HW - T / 2, HW + T / 2, MapConfig.ZONES[1].untilZ, MapConfig.ZONES[2].untilZ, 0)
	band("Creaky", -HW - T / 2, HW + T / 2, MapConfig.ZONES[2].untilZ, LEN + T, 0)

	local safeR, lineW = MapConfig.SAFE_RADIUS, MapConfig.SAFE_LINE
	Kit.disc(floor, "Safe", CR + 12, 1, CFrame.new(0, -0.15 - 0.5, CZ), 0x3FDCA6, {
		material = Enum.Material.Plastic,
		variant = studs,
		shadow = false,
		attributes = { FloorType = "Safe", Noise = 0 },
	})
	Kit.disc(floor, "SafeLine", safeR, 1, CFrame.new(0, -0.1 - 0.5, CZ), 0xFFFFFF, {
		shadow = false,
		attributes = { FloorType = "Safe", Noise = 0 },
	})
	Kit.disc(floor, "Carpet", safeR - lineW, 1, CFrame.new(0, -0.05 - 0.5, CZ), bands.Carpet.color, {
		material = Enum.Material.Carpet,
		variant = carpetVariant,
		shadow = false,
		attributes = { FloorType = "Carpet", Noise = 1 },
	})

	-- Tape lines across the run where the bands change
	local lines = Kit.folder(floor, "Lines")
	for k, z in { MapConfig.ZONES[1].untilZ, MapConfig.ZONES[2].untilZ } do
		part(
			lines,
			"Tape",
			Vector3.new(2 * HW, 0.2, 8),
			CFrame.new(0, 0.1, z),
			if k == 1 then 0xFFD43B else 0xFF5A5A,
			{ collide = false, shadow = false }
		)
	end

	-- Painted labels, lying flat and reading toward the far end (for players leaving home)
	local function floorLabel(text: string, x: number, z: number, width: number, color: number)
		local height = width * 0.16
		local p = part(
			lines,
			"Label",
			Vector3.new(height, 0.1, width), -- a Top-face SurfaceGui runs along the part's Z
			CFrame.new(x, 0.3, z) * CFrame.Angles(0, math.pi / 2, 0),
			0xFFFFFF,
			{ collide = false, transparency = 1, shadow = false }
		)
		Kit.text(p, text, {
			face = Enum.NormalId.Top,
			color = rgb(color),
			stroke = rgb(0x1A1430),
			pixelsPerStud = 6,
		})
	end
	floorLabel("CARPET · SMALL", 0, 560, 250, 0xE6DDFF)
	floorLabel("WOOD · MEDIUM · NOISE x2", 0, MapConfig.ZONES[1].untilZ + 50, 300, 0xFFE9A8)
	floorLabel("CREAKY · LARGE · NOISE x3", 90, MapConfig.ZONES[2].untilZ + 50, 300, 0xFFB0A8)

	-- Voxel floor tiles (MeshParts in ServerStorage.TinyToyHeistAssets.FloorTiles), laid on top when they exist.
	-- Their walkable top is at y = 0, so they sit flush with the bands they cover.
	local assets = game:GetService("ServerStorage"):FindFirstChild("TinyToyHeistAssets")
	local tileTemplates = assets and assets:FindFirstChild("FloorTiles")
	local tilesPlaced = 0
	if tileTemplates then
		local tiles = Kit.folder(floor, "Tiles")
		local turns = Random.new(1018) -- fixed seed, so rebuilding gives the same floor
		for _, tile in MapConfig.floorTiles() do
			local template = tileTemplates:FindFirstChild(tile.zone .. "Tile")
			if template and template:IsA("BasePart") then
				local t = template:Clone()
				t.Anchored = true
				t.CanCollide = false
				t.CanQuery = false
				t.CanTouch = false
				t.CastShadow = false
				local steps = if tile.zone == "Carpet" then turns:NextInteger(0, 3) else 2 * turns:NextInteger(0, 1)
				t.CFrame = CFrame.new(tile.position + Vector3.new(0, 0.02 - t.Size.Y / 2, 0))
					* CFrame.Angles(0, steps * math.pi / 2, 0)
				t.Parent = tiles
				tilesPlaced += 1
				Kit.batch()
			end
		end
	end

	---------------------------------------------------------------------------------------------------------------
	-- Walls. Every straight wall is a sage slab; its room side gets darker striped wallpaper up to a cream rail at
	-- 120, plain paint above, a cream crown at the top and a baseboard.
	local walls = Kit.folder(bedroom, "Walls")
	local paper = Kit.folder(walls, "Wallpaper")

	-- Dress the room face of a wall that runs from a to b (floor points on its inner face); `inward` points into
	-- the room. `fromY` lets the strip over a door start higher.
	local function dress(a: Vector3, b: Vector3, inward: Vector3, options: { stripes: boolean?, baseboard: boolean? }?)
		local opts = options or {}
		local length = (b - a).Magnitude
		local along = (b - a).Unit
		local function strip(
			name: string,
			depth: number,
			y0: number,
			y1: number,
			color: Color3,
			from: number?,
			to: number?
		)
			local s, e = from or 0, to or length
			local centre = a + along * (s + e) / 2 + inward * depth / 2 + Vector3.new(0, (y0 + y1) / 2, 0)
			local cf = CFrame.lookAt(centre, centre + along)
			return part(paper, name, Vector3.new(depth, y1 - y0, e - s), cf, color, { shadow = false })
		end
		strip("Paper", 0.4, 0, 120, PAPER)
		if opts.stripes ~= false then
			for s = 12, length - 24, 48 do
				local centre = a + along * (s + 12) + inward * 0.5 + Vector3.new(0, 60, 0)
				part(paper, "Stripe", Vector3.new(0.2, 120, 24), CFrame.lookAt(centre, centre + along), PAPER_STRIPE, {
					shadow = false,
				})
			end
		end
		strip("Rail", 1.6, 119, 124, CREAM)
		strip("Crown", 2, H - 7, H, CREAM)
		if opts.baseboard ~= false then
			strip("Baseboard", 3, 0, MapConfig.BASEBOARD_HEIGHT, BASEBOARD)
		end
	end

	-- A wall slab with its inner face on the line a-b, standing T thick on the outside.
	local function slab(
		name: string,
		a: Vector3,
		b: Vector3,
		inward: Vector3,
		extra: number?,
		height: number?,
		y0: number?
	)
		local along = (b - a).Unit
		local length = (b - a).Magnitude + 2 * (extra or 0)
		local h = height or H
		local centre = (a + b) / 2 - inward * T / 2 + Vector3.new(0, (y0 or 0) + h / 2, 0)
		return part(walls, name, Vector3.new(T, h, length), CFrame.lookAt(centre, centre + along), SAGE, {
			material = Enum.Material.SmoothPlastic,
		})
	end

	-- Long walls (x > 0 is the runner's LEFT)
	for _, side in { 1, -1 } do
		local name = if side > 0 then "LeftWall" else "RightWall"
		local a, b = Vector3.new(side * HW, 0, SZ), Vector3.new(side * HW, 0, LEN)
		slab(name, a, b, Vector3.new(-side, 0, 0), 6)
		dress(a, b, Vector3.new(-side, 0, 0))
	end

	-- Shoulders, from the wide start area in to the run
	for _, side in { 1, -1 } do
		local a, b = Vector3.new(side * SX, 0, CZ), Vector3.new(side * HW, 0, SZ)
		local along = (b - a).Unit
		local inward = Vector3.new(-along.Z, 0, along.X)
		if inward:Dot(Vector3.new(-side, 0, 0)) < 0 then
			inward = -inward
		end
		slab(if side > 0 then "LeftShoulder" else "RightShoulder", a, b, inward, 5)
		dress(a, b, inward)
	end

	-- The far wall with the hallway door straight ahead
	local far = Vector3.new(0, 0, -1)
	for _, side in { 1, -1 } do
		local a, b = Vector3.new(side * (HW + T), 0, LEN), Vector3.new(side * DOOR_W / 2, 0, LEN)
		slab(if side > 0 then "FarWallLeft" else "FarWallRight", a, b, far)
		dress(Vector3.new(side * HW, 0, LEN), b, far)
	end
	slab("FarWallTop", Vector3.new(-DOOR_W / 2, 0, LEN), Vector3.new(DOOR_W / 2, 0, LEN), far, 0, H - DOOR_H, DOOR_H)
	do -- crown over the door
		local centre = Vector3.new(0, H - 3.5, LEN - 1)
		part(paper, "Crown", Vector3.new(DOOR_W, 7, 2), CFrame.new(centre), CREAM, { shadow = false })
	end
	-- door frame trim
	for _, side in { -1, 1 } do
		block(walls, "DoorTrim", 9, DOOR_H + 9, 6, ORIGIN, side * (DOOR_W / 2 + 4.5), 0, LEN - 1, CREAM)
	end
	block(walls, "DoorTrim", DOOR_W + 18, 9, 6, ORIGIN, 0, DOOR_H, LEN - 1, CREAM)

	-- The door, swung 72 degrees open into the hallway, hinged on the runner's right
	local doorModel = Kit.model(walls, "Door")
	local hinge = CFrame.new(-DOOR_W / 2, 0, LEN + 2) * CFrame.Angles(0, -1.25, 0)
	block(doorModel, "Panel", DOOR_W - 4, DOOR_H - 4, 5, hinge, (DOOR_W - 4) / 2, 0, 0, 0x8A6240, {
		material = Enum.Material.Wood,
	})
	for _, inset in { { 40, 60 }, { 40, 160 }, { 92, 60 }, { 92, 160 } } do
		block(doorModel, "Inset", 36, 80, 1, hinge, inset[1] - 6, inset[2] - 40, 3, 0x9C7250, {
			material = Enum.Material.Wood,
		})
		block(doorModel, "Inset", 36, 80, 1, hinge, inset[1] - 6, inset[2] - 40, -3, 0x9C7250, {
			material = Enum.Material.Wood,
		})
	end
	Kit.ball(doorModel, "Knob", 4, (hinge * CFrame.new(DOOR_W - 16, 105, 4)).Position, 0xD9B44A, {
		material = Enum.Material.Metal,
	})

	-- The hallway: wood floor, purple-grey walls, a warm light at the far end, a sign over the door
	local hall = Kit.folder(bedroom, "Hallway")
	local HALL_W, HALL_L = MapConfig.HALLWAY_WIDTH, MapConfig.HALLWAY_LENGTH
	block(hall, "Floor", HALL_W + 20, 1, HALL_L, ORIGIN, 0, -1, LEN + T + HALL_L / 2 - 2, 0x7C5E3F, {
		material = Enum.Material.WoodPlanks,
		shadow = false,
		attributes = { FloorType = "Wood", Noise = 2 },
	})
	for _, side in { -1, 1 } do
		block(hall, "Wall", T, H, HALL_L, ORIGIN, side * (HALL_W / 2 + T / 2), 0, LEN + T + HALL_L / 2, 0x5A4A6E)
	end
	block(hall, "EndWall", HALL_W + 2 * T, H, T, ORIGIN, 0, 0, LEN + T + HALL_L + T / 2, 0x5A4A6E)
	part(
		hall,
		"Ceiling",
		Vector3.new(HALL_W + 2 * T, 4, HALL_L + T),
		CFrame.new(0, H + 2, LEN + T + HALL_L / 2),
		0x2A2440,
		{ shadow = false }
	)
	for k, z in { LEN + 140, LEN + 330 } do
		local bulb = Kit.ball(hall, "Bulb", 4, Vector3.new(0, H - 30, z), 0xFFE3B0, {
			material = Enum.Material.Neon,
			collide = false,
		})
		Kit.light(bulb, "PointLight", 0xFFC27A, if k == 2 then 1.6 else 1, 60, { Shadows = true })
		bulb:SetAttribute("LightRole", "Hallway")
	end
	-- Blocked until the next room exists: you can step into the hallway, past the door, but no further
	part(hall, "Blocker", Vector3.new(HALL_W, H, 2), CFrame.new(0, H / 2, LEN + 150), 0xFFFFFF, {
		transparency = 1,
		shadow = false,
	})
	local sign = part(
		hall,
		"Sign",
		Vector3.new(84, 11, 1),
		CFrame.new(0, DOOR_H + 30, LEN - 1.6) * CFrame.Angles(0, math.pi, 0),
		0x3A2A6E,
		{ shadow = false }
	)
	Kit.text(sign, "HALLWAY · NEXT ROOM SOON", {
		face = Enum.NormalId.Back,
		color = Color3.new(1, 1, 1),
		background = rgb(0x3A2A6E),
		pixelsPerStud = 12,
		glow = true,
	})

	---------------------------------------------------------------------------------------------------------------
	-- The curved wall: a solid wall between each pair of homes, from one home's front corner to the next, as deep as
	-- the homes; and an end wall from each end home to its shoulder.
	local curved = Kit.folder(walls, "CurvedWall")
	local D = MapConfig.HOME_WALL_DEPTH
	local function dressFront(a: Vector3, b: Vector3)
		-- the front edge of a wall between homes: wallpaper and a baseboard across its narrow face
		local along = (b - a).Unit
		local inward = Vector3.new(-along.Z, 0, along.X)
		if inward:Dot(Vector3.new(0, 0, CZ) - (a + b) / 2) < 0 then
			inward = -inward
		end
		dress(a, b, inward, { stripes = false })
	end
	for i = 1, MapConfig.HOLE_COUNT - 1 do
		local a, b = MapConfig.homeCorner(i, -1, 0), MapConfig.homeCorner(i + 1, 1, 0)
		local c, d = MapConfig.homeCorner(i + 1, 1, D), MapConfig.homeCorner(i, -1, D)
		Kit.quadWall(curved, "WallBetween" .. i, a, b, c, d, 0, H, SAGE)
		dressFront(a, b)
	end
	local first, last = 1, MapConfig.HOLE_COUNT
	local farOut = CR + D + 20
	Kit.quadWall(
		curved,
		"EndWallRight",
		Vector3.new(-SX, 0, CZ),
		MapConfig.homeCorner(first, 1, 0),
		MapConfig.homeCorner(first, 1, D),
		Vector3.new(-farOut, 0, CZ),
		0,
		H,
		SAGE
	)
	Kit.quadWall(
		curved,
		"EndWallLeft",
		MapConfig.homeCorner(last, -1, 0),
		Vector3.new(SX, 0, CZ),
		Vector3.new(farOut, 0, CZ),
		MapConfig.homeCorner(last, -1, D),
		0,
		H,
		SAGE
	)
	-- behind the end walls, fill down to the shoulders so there's no gap at the outer corners
	for _, side in { -1, 1 } do
		part(
			curved,
			"EndFill",
			Vector3.new(farOut - SX, H, 20),
			CFrame.new(side * (SX + farOut) / 2, H / 2, CZ + 10),
			SAGE
		)
	end

	---------------------------------------------------------------------------------------------------------------
	-- Ceiling: one slab over everything, dark navy at night (BedroomLighting turns it cream with the lights on).
	-- It doesn't cast shadows, so the moon still lights the room, as in Dylan's night photo.
	local ceiling = part(
		walls,
		"Ceiling",
		Vector3.new(1200, 4, 1960),
		CFrame.new(0, H + 2, 780),
		0x1B2142,
		{ shadow = false, material = Enum.Material.SmoothPlastic }
	)
	ceiling:SetAttribute("LightRole", "Ceiling")
	local stars = Kit.folder(walls, "Stars")
	for k = 0, 63 do
		local size = 10 + (k * 37 % 9) * 2
		local x = ((k * 263) % (2 * HW - 40)) - (HW - 20)
		local z = 120 + ((k * 421) % (LEN - 160))
		local s = part(
			stars,
			"Star",
			Vector3.new(size, 0.1, size),
			CFrame.new(x, H - 0.1, z) * CFrame.Angles(0, k, 0),
			0xDFFFB0,
			{ collide = false, transparency = 1, shadow = false }
		)
		Kit.text(s, "★", { face = Enum.NormalId.Bottom, color = rgb(0xDFFFB0), pixelsPerStud = 6, glow = true })
	end

	return { floorTiles = tilesPlaced }
end
