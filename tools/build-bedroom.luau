--!strict
-- Studio EDIT mode only. Rebuilds Workspace.Bedroom: the Kid's Bedroom from the sketch, 1.5x the first draft.
-- Flat back wall with the bed and the sleeping Giant Kid, three floor rings (creaky boards, wood, carpet), and a
-- curved front wall with 8 arched mouse holes. Each hole leads through the wall into a burrow: the player's base,
-- with 20 toy slots (6 shown at Level 1), a cash pile, a Door Lock button, the Toy Index book, a Speed training
-- wheel and a spawn. Voxel floor tiles are laid on top when ServerStorage.TinyToyHeistAssets.FloorTiles exists.
-- Every number comes from ReplicatedStorage.Shared.MapConfig. Run it from the command bar:
--   local m = game.ServerStorage.TinyToyHeistTools.BuildBedroom:Clone(); print(require(m)); m:Destroy()
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
assert(not game:GetService("RunService"):IsRunning(), "Build the bedroom in Edit mode")

local MapConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MapConfig")) :: any

local HW, R, CZ = MapConfig.HALF_WIDTH, MapConfig.CURVE_RADIUS, MapConfig.CURVE_CENTER_Z
local H, T = MapConfig.WALL_HEIGHT, MapConfig.WALL_THICKNESS
local DOOR_W, DOOR_SIDE = MapConfig.DOOR_WIDTH, MapConfig.DOOR_SIDE_HEIGHT
local DOOR_R = DOOR_W / 2
local DOOR_H = DOOR_SIDE + DOOR_R
local BW, BD, BH = MapConfig.BURROW_WIDTH, MapConfig.BURROW_DEPTH, MapConfig.BURROW_HEIGHT
local LIFT = MapConfig.BURROW_FLOOR_LIFT
local S = MapConfig.SCALE

local function rgb(hex: number): Color3
	return Color3.fromRGB(bit32.rshift(hex, 16), bit32.band(bit32.rshift(hex, 8), 255), bit32.band(hex, 255))
end

local WALL = rgb(0x4E5A88) -- lighter than the render's 0x39456E: Roblox has no moonlight through the ceiling
local BASEBOARD = rgb(0xE6E1D6)
local TRIM = rgb(0xF1EBDD)
local TUNNEL = rgb(0x3A2618)
local CARDBOARD = rgb(0xC49A6C)
local CARDBOARD_WALL = rgb(0xB9895A)

local count = 0
local function batch()
	count += 1
	if count % 150 == 0 then
		task.wait()
	end
end

type PartOptions = {
	material: Enum.Material?,
	shape: Enum.PartType?,
	collide: boolean?,
	transparency: number?,
	attributes: { [string]: any }?,
}

local function place(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	options: PartOptions?
): Part
	local opts: PartOptions = options or {}
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = opts.material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if opts.shape then
		p.Shape = opts.shape
	end
	if opts.collide == false then
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
	end
	if opts.transparency then
		p.Transparency = opts.transparency
	end
	for key, value in opts.attributes or {} do
		p:SetAttribute(key, value)
	end
	p.Parent = parent
	batch()
	return p
end

local function folder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- A box from the first-draft render: size w x h x d with its bottom at y, scaled 1.5x.
local function draftBox(
	parent: Instance,
	name: string,
	w: number,
	h: number,
	d: number,
	x: number,
	y: number,
	z: number,
	color: number,
	material: Enum.Material?
): Part
	return place(
		parent,
		name,
		Vector3.new(w, h, d) * S,
		CFrame.new(x * S, (y + h / 2) * S, z * S),
		rgb(color),
		{ material = material }
	)
end

-- An upright cylinder (Roblox cylinders run along X, so turn it to stand on Y).
local function disc(
	parent: Instance,
	name: string,
	radius: number,
	height: number,
	cf: CFrame,
	color: Color3,
	options: PartOptions?
): Part
	local opts: PartOptions = options or {}
	opts.shape = Enum.PartType.Cylinder
	return place(
		parent,
		name,
		Vector3.new(height, radius * 2, radius * 2),
		cf * CFrame.Angles(0, 0, math.pi / 2),
		color,
		opts
	)
end

local function label(part: BasePart, text: string, textColor: Color3, background: Color3): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	gui.Parent = part
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundColor3 = background
	t.TextColor3 = textColor
	t.TextScaled = true
	t.Font = Enum.Font.FredokaOne
	t.Text = text
	t.Parent = gui
	return t
end

local old = Workspace:FindFirstChild("Bedroom")
if old then
	old:Destroy()
end
local bedroom = Instance.new("Model")
bedroom.Name = "Bedroom"
bedroom.Parent = Workspace -- CSG needs the parts in the world

---------------------------------------------------------------------------------------------------------------------
-- Floor: three rings around the bed. Each top sits 0.05 above the one under it so they don't flicker.
-- CSG trims each disc to the room (behind the back wall and past the side walls); if that fails the disc stays whole.
local floors = folder(bedroom, "Floor")
local function trimToRoom(slab: Part, top: number): BasePart
	local cutters = {
		place(floors, "Cut", Vector3.new(4 * R, 10, 2 * R), CFrame.new(0, top - 1, -R), TUNNEL),
		place(floors, "Cut", Vector3.new(2 * R, 10, 4 * R), CFrame.new(-(HW + R), top - 1, CZ), TUNNEL),
		place(floors, "Cut", Vector3.new(2 * R, 10, 4 * R), CFrame.new(HW + R, top - 1, CZ), TUNNEL),
	}
	local ok, union = pcall(function()
		return slab:SubtractAsync(cutters, Enum.CollisionFidelity.PreciseConvexDecomposition)
	end)
	for _, c in cutters do
		c:Destroy()
	end
	if not (ok and union) then
		return slab
	end
	union.Name = slab.Name
	union.Anchored = true
	union.UsePartColor = true
	union.Color = slab.Color
	union.Material = slab.Material
	for key, value in slab:GetAttributes() do
		union:SetAttribute(key, value)
	end
	union.Parent = floors
	slab:Destroy()
	return union
end
local ringColors = { Creaky = 0x6B4F35, Wood = 0x8A6A48, Carpet = 0x6A5BA0 }
local ringMaterials = {
	Creaky = Enum.Material.WoodPlanks,
	Wood = Enum.Material.WoodPlanks,
	Carpet = Enum.Material.Fabric,
}
-- Voxel floor tiles (MeshParts imported into ServerStorage.TinyToyHeistAssets.FloorTiles), when they exist. Their
-- walkable top is at y = 0, so the rings drop 0.15 below it: the tiles show, and the rings still fill any gap.
local assets = game:GetService("ServerStorage"):FindFirstChild("TinyToyHeistAssets")
local tileTemplates = assets and assets:FindFirstChild("FloorTiles")
local ringDrop = if tileTemplates then 0.15 else 0

for index, ring in MapConfig.RINGS do
	local top = (#MapConfig.RINGS - index) * 0.05 - ringDrop
	local radius = if ring.name == "Carpet" then R + T / 2 + 2 else ring.outer
	local d = disc(floors, ring.name, radius, 2, CFrame.new(0, top - 1, CZ), rgb(ringColors[ring.name]), {
		material = ringMaterials[ring.name],
		attributes = { FloorType = ring.name, Noise = ring.noise },
	})
	trimToRoom(d, top)
end

local tilesPlaced = 0
if tileTemplates then
	local tiles = folder(floors, "Tiles")
	local turns = Random.new(1018) -- fixed seed, so rebuilding gives the same floor
	for _, tile in MapConfig.floorTiles() do
		local template = tileTemplates:FindFirstChild(tile.ring .. "Tile")
		if template and template:IsA("BasePart") then
			local t = template:Clone()
			t.Anchored = true
			t.CanCollide = false
			t.CanQuery = false
			t.CanTouch = false
			t.CastShadow = false
			t.CFrame = CFrame.new(tile.position + Vector3.new(0, -1 + t.Size.Y / 2, 0))
				* CFrame.Angles(0, turns:NextInteger(0, 3) * math.pi / 2, 0)
			t.Parent = tiles
			tilesPlaced += 1
			batch()
		end
	end
end

---------------------------------------------------------------------------------------------------------------------
-- Walls: the back wall, two side walls and the curved front wall, plus baseboards and a ceiling.
local walls = folder(bedroom, "Walls")
local sideLength = MapConfig.sideWallLength()
place(walls, "BackWall", Vector3.new(2 * HW + 16, H, 8), CFrame.new(0, H / 2, -4), WALL)
place(walls, "BackBaseboard", Vector3.new(2 * HW, 15, 3), CFrame.new(0, 7.5, 1.5), BASEBOARD)
for _, side in { -1, 1 } do
	local name = if side < 0 then "Left" else "Right"
	place(
		walls,
		name .. "Wall",
		Vector3.new(8, H, sideLength),
		CFrame.new(side * (HW + 4), H / 2, sideLength / 2),
		WALL
	)
	place(
		walls,
		name .. "Baseboard",
		Vector3.new(3, 15, sideLength),
		CFrame.new(side * (HW - 1.5), 7.5, sideLength / 2),
		BASEBOARD
	)
end
local ceiling = place(
	walls,
	"Ceiling",
	Vector3.new(2 * HW + 16, 4, R + CZ + 140),
	CFrame.new(0, H + 2, (R + CZ + 140) / 2 - 8),
	rgb(0x232A48)
)
ceiling.CastShadow = false -- let the moon light the room, as in the render (which has no ceiling)

-- A wall of the given size and centre with an arched doorway cut through its bottom middle. CSG when Studio allows
-- it (the cut faces keep the dark tunnel colour), otherwise a square opening of the same height from three parts.
local unionsMade, unionsFailed = 0, 0
local function archWall(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?
)
	local panel = place(parent, name, size, cf, color, { material = material })
	local doorBottom = -size.Y / 2
	local box = place(
		parent,
		"Cut",
		Vector3.new(DOOR_W, DOOR_SIDE + 0.5, size.Z + 4),
		cf * CFrame.new(0, doorBottom + (DOOR_SIDE + 0.5) / 2 - 0.25, 0),
		TUNNEL
	)
	local round = place(
		parent,
		"Cut",
		Vector3.new(size.Z + 4, DOOR_W, DOOR_W),
		cf * CFrame.new(0, doorBottom + DOOR_SIDE, 0) * CFrame.Angles(0, math.pi / 2, 0),
		TUNNEL,
		{ shape = Enum.PartType.Cylinder }
	)
	local ok, union = pcall(function()
		return panel:SubtractAsync({ box, round }, Enum.CollisionFidelity.PreciseConvexDecomposition)
	end)
	box:Destroy()
	round:Destroy()
	if ok and union then
		union.Name = name
		union.Anchored = true
		union.UsePartColor = false
		union.Parent = parent
		panel:Destroy()
		unionsMade += 1
		return
	end
	unionsFailed += 1
	panel:Destroy()
	local opts = { material = material }
	local side = (size.X - DOOR_W) / 2
	for _, s in { -1, 1 } do
		place(
			parent,
			name .. "Side",
			Vector3.new(side, size.Y, size.Z),
			cf * CFrame.new(s * (DOOR_W / 2 + side / 2), 0, 0),
			color,
			opts
		)
	end
	place(
		parent,
		name .. "Top",
		Vector3.new(DOOR_W, size.Y - DOOR_H, size.Z),
		cf * CFrame.new(0, doorBottom + DOOR_H + (size.Y - DOOR_H) / 2, 0),
		color,
		opts
	)
end

-- Cream trim round the arch on the room side: two side strips and 12 short pieces round the half circle.
local function archTrim(parent: Instance, cf: CFrame)
	for _, s in { -1, 1 } do
		place(
			parent,
			"Trim",
			Vector3.new(3, DOOR_SIDE, 1.2),
			cf * CFrame.new(s * (DOOR_W / 2 + 1.5), DOOR_SIDE / 2, 0),
			TRIM
		)
	end
	local pieces = 12
	for k = 0, pieces - 1 do
		local a = math.pi * (k + 0.5) / pieces
		local mid = DOOR_R + 1.5
		local length = 2 * (DOOR_R + 3) * math.sin(math.pi / pieces / 2) + 0.6
		place(
			parent,
			"Trim",
			Vector3.new(length, 3, 1.2),
			cf * CFrame.new(math.cos(a) * mid, DOOR_SIDE + math.sin(a) * mid, 0) * CFrame.Angles(0, 0, a - math.pi / 2),
			TRIM
		)
	end
end

-- The Speed training wheel: a hamster wheel made from a cardboard spool on a stand. cf sits on the burrow floor with
-- burrow axes, so the axle runs along x and you run toward +Z. Game code spins the "Wheel" model about its axle
-- and puts the runner at RunPoint (facing +Z).
local function buildTrainingWheel(parent: Instance, cf: CFrame)
	local WR, WW = MapConfig.WHEEL_RADIUS, MapConfig.WHEEL_WIDTH
	local axleY = 1 + 0.5 + WR -- base plate, a small gap, then the wheel
	local model = Instance.new("Model")
	model.Name = "TrainingWheel"
	model:SetAttribute("Stat", "Speed")
	model.Parent = parent
	local cardboard = { material = Enum.Material.Cardboard }
	place(model, "Base", Vector3.new(WW + 5, 1, 2 * WR + 1), cf * CFrame.new(0, 0.5, 0), CARDBOARD_WALL, cardboard)
	for _, s in { -1, 1 } do
		place(
			model,
			"Post",
			Vector3.new(1, axleY, 2),
			cf * CFrame.new(s * (WW / 2 + 1.5), 1 + axleY / 2, 0),
			CARDBOARD_WALL,
			cardboard
		)
	end

	local wheel = Instance.new("Model")
	wheel.Name = "Wheel"
	wheel.Parent = model
	local hub = cf * CFrame.new(0, axleY, 0)
	local free = { collide = false, material = Enum.Material.Cardboard, shape = Enum.PartType.Cylinder }
	for _, s in { -1, 1 } do
		place(
			wheel,
			"Spool",
			Vector3.new(1, 2 * WR, 2 * WR),
			hub * CFrame.new(s * (WW / 2 + 0.5), 0, 0),
			CARDBOARD,
			free
		)
	end
	local rungs = 12
	for k = 0, rungs - 1 do
		local a = 2 * math.pi * k / rungs
		place(
			wheel,
			"Rung",
			Vector3.new(WW, 0.6, 0.6),
			hub * CFrame.new(0, math.sin(a) * (WR - 0.7), math.cos(a) * (WR - 0.7)),
			rgb(0xE6C79C),
			{ collide = false, material = Enum.Material.Wood }
		)
	end
	local axle = place(
		wheel,
		"Axle",
		Vector3.new(WW + 4, 1.2, 1.2),
		hub,
		rgb(0x8A5A34),
		{ collide = false, shape = Enum.PartType.Cylinder }
	)
	wheel.PrimaryPart = axle
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Train Speed"
	prompt.ObjectText = "Hamster wheel"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = axle
	place(
		model,
		"RunPoint",
		Vector3.new(1, 1, 1),
		cf * CFrame.new(0, axleY - WR + 1, 0) * CFrame.Angles(0, math.pi, 0),
		rgb(0x3DDC97),
		{ collide = false, transparency = 1 }
	)
end

-- The curve is cut into equal panels; every 4th one is centred on a mouse hole.
local curve = folder(walls, "CurvedWall")
local step = MapConfig.HOLE_SPREAD / ((MapConfig.HOLE_COUNT - 1) * 4)
for j = -1, (MapConfig.HOLE_COUNT - 1) * 4 + 1 do
	local angle = MapConfig.HOLE_FIRST_ANGLE + j * step
	local length = 2 * (R + T / 2) * math.sin(math.rad(step / 2)) + 2
	local mid = MapConfig.curveFrame(R + T / 2, angle, H / 2)
	local inner = MapConfig.curveFrame(R, angle) -- floor level, on the room-side face
	local holeIndex = if j >= 0 and j % 4 == 0 then j // 4 + 1 else nil
	if holeIndex then
		archWall(curve, "HolePanel" .. holeIndex, Vector3.new(length, H, T), mid, WALL)
		archTrim(curve, inner * CFrame.new(0, 0, -0.6))
		local side = (length - DOOR_W) / 2 - 3
		for _, s in { -1, 1 } do
			place(
				curve,
				"Baseboard",
				Vector3.new(side, 15, 3),
				inner * CFrame.new(s * (DOOR_W / 2 + 3 + side / 2), 7.5, -1.5),
				BASEBOARD
			)
		end
	else
		place(curve, "Panel", Vector3.new(length, H, T), mid, WALL)
		place(curve, "Baseboard", Vector3.new(length, 15, 3), inner * CFrame.new(0, 7.5, -1.5), BASEBOARD)
	end
end

---------------------------------------------------------------------------------------------------------------------
-- Mouse holes. Burrow space: origin on the floor where the tunnel opens, +Z deeper into the burrow, x across.
local holes = folder(bedroom, "Holes")
local CAP_COLORS = { rgb(0xE04848), rgb(0x4DA8FF), rgb(0x3DDC97) }
for i = 1, MapConfig.HOLE_COUNT do
	local angle = MapConfig.holeAngle(i)
	local bf = MapConfig.burrowFrame(i)
	local hole = Instance.new("Model")
	hole.Name = "Hole" .. i
	hole:SetAttribute("HoleIndex", i)
	hole:SetAttribute("Owner", 0) -- UserId, 0 = free
	hole:SetAttribute("Level", 1)
	hole:SetAttribute("Locked", false)
	hole.Parent = holes

	local shell = folder(hole, "Shell")
	local floor = place(
		shell,
		"Floor",
		Vector3.new(BW, 1, BD),
		bf * CFrame.new(0, LIFT - 0.5, BD / 2),
		CARDBOARD,
		{ material = Enum.Material.Cardboard }
	)
	floor:SetAttribute("FloorType", "Burrow")
	floor:SetAttribute("Noise", 1)
	-- top at 0.7, so carpet-tile tufts reaching under the wall don't poke through
	place(shell, "TunnelFloor", Vector3.new(DOOR_W, 1, T + 2), bf * CFrame.new(0, 0.2, -T / 2), TUNNEL)
	place(
		shell,
		"BackWall",
		Vector3.new(BW + 4, BH, 2),
		bf * CFrame.new(0, BH / 2, BD + 1),
		CARDBOARD_WALL,
		{ material = Enum.Material.Cardboard }
	)
	for _, s in { -1, 1 } do
		place(
			shell,
			"SideWall",
			Vector3.new(2, BH, BD + 2),
			bf * CFrame.new(s * (BW / 2 + 1), BH / 2, BD / 2),
			CARDBOARD_WALL,
			{ material = Enum.Material.Cardboard }
		)
	end
	archWall(
		shell,
		"FrontWall",
		Vector3.new(BW, BH, 2),
		bf * CFrame.new(0, BH / 2, 1),
		CARDBOARD_WALL,
		Enum.Material.Cardboard
	)
	place(shell, "Ceiling", Vector3.new(BW + 4, 2, BD + 4), bf * CFrame.new(0, BH + 1, BD / 2), rgb(0x2A1C12))
	local bulb = place(shell, "Lamp", Vector3.new(4, 4, 4), bf * CFrame.new(0, BH - 4, BD / 2), rgb(0xFFE7B0), {
		material = Enum.Material.Neon,
		shape = Enum.PartType.Ball,
		collide = false,
	})
	local light = Instance.new("PointLight")
	light.Color = rgb(0xFFC27A)
	light.Range = 60
	light.Brightness = 1.6
	light.Parent = bulb

	-- 20 slots; Level 1 shows the first 6 as bottle caps. Game code shows more as the hole levels up.
	local slots = folder(hole, "Slots")
	for k, offset in MapConfig.slotOffsets() do
		local shown = k <= MapConfig.HOLE_LEVELS[1].slots
		disc(
			slots,
			"Slot" .. k,
			6,
			1.2,
			bf * CFrame.new(offset + Vector3.new(0, LIFT + 0.6, 0)),
			CAP_COLORS[(k - 1) % 3 + 1],
			{
				material = Enum.Material.Metal,
				collide = shown,
				transparency = if shown then 0 else 1,
				attributes = { SlotIndex = k },
			}
		)
	end

	-- Cash pile (grows with earnings; walk over it to collect), Door Lock button, Toy Index book, Speed training
	-- wheel and spawn, at the spots in MapConfig.BURROW_LAYOUT.
	local layout = MapConfig.BURROW_LAYOUT
	local function at(prop: string, y: number): CFrame
		return bf * CFrame.new(layout[prop].position + Vector3.new(0, LIFT + y, 0))
	end
	local cash = place(hole, "CashPile", Vector3.new(10, 3, 10), at("CashPile", 1.5), rgb(0xF2C94C), {
		material = Enum.Material.Foil,
		attributes = { Cash = 0 },
	})
	local mound = Instance.new("SpecialMesh")
	mound.MeshType = Enum.MeshType.Sphere
	mound.Parent = cash
	local lockButton = disc(hole, "LockButton", 4.5, 1.6, at("LockButton", 0.8), rgb(0xFF4D5E))
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Lock door"
	prompt.ObjectText = "Door Lock (45 s)"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.Parent = lockButton
	place(hole, "IndexStand", Vector3.new(8, 6, 6), at("ToyIndex", 3), rgb(0x8A5A34))
	place(hole, "IndexBook", Vector3.new(9, 1.6, 7), at("ToyIndex", 6.8), rgb(0x9246D4))
	buildTrainingWheel(hole, at("TrainingWheel", 0))
	local spawnPad = Instance.new("SpawnLocation")
	spawnPad.Name = "Spawn"
	spawnPad.Anchored = true
	spawnPad.Size = Vector3.new(10, 1, 10)
	spawnPad.CFrame = at("Spawn", -0.3)
	spawnPad.Color = rgb(0x3DDC97)
	spawnPad.Material = Enum.Material.SmoothPlastic
	spawnPad.Transparency = 0.4
	spawnPad.Duration = 0
	spawnPad.Neutral = true
	spawnPad.Parent = hole

	-- The door: an invisible barrier and red bars, both switched on while the door is locked.
	local inner = MapConfig.curveFrame(R, angle)
	place(hole, "DoorBarrier", Vector3.new(DOOR_W, DOOR_H, 2), inner * CFrame.new(0, DOOR_H / 2, 1), rgb(0xFF4D5E), {
		collide = false,
		transparency = 1,
	})
	local bars = folder(hole, "LockBars")
	for k = 0, 4 do
		place(
			bars,
			"Bar",
			Vector3.new(1.6, DOOR_H - 2, 1.6),
			inner * CFrame.new(-10 + k * 5, (DOOR_H - 2) / 2, 0.5),
			rgb(0xFF4D5E),
			{
				material = Enum.Material.Neon,
				collide = false,
				transparency = 1,
			}
		)
	end

	-- Name sign over the door, facing into the room.
	local sign =
		place(hole, "Sign", Vector3.new(30, 7, 1), MapConfig.curveFrame(R - 1, angle, DOOR_H + 12), rgb(0x1A1430))
	label(sign, "Free hole", Color3.new(1, 1, 1), rgb(0x1A1430))
	local plate = place(
		hole,
		"LevelPlate",
		Vector3.new(28, 3.6, 1),
		MapConfig.curveFrame(R - 1, angle, DOOR_H + 6.5),
		Color3.new(1, 1, 1)
	)
	label(plate, "Lv 1 · Cardboard", rgb(0x1A1430), Color3.new(1, 1, 1))
end

---------------------------------------------------------------------------------------------------------------------
-- Bed, the Giant Kid and furniture: the first-draft blocks, scaled 1.5x (draftBox applies the scale).
local furniture = folder(bedroom, "Furniture")
local WOOD = 0x7A5233
draftBox(furniture, "Headboard", 170, 110, 10, 0, 0, 10, WOOD, Enum.Material.Wood)
for _, leg in { { -74, 22 }, { 74, 22 }, { -74, 258 }, { 74, 258 } } do
	draftBox(furniture, "BedLeg", 10, 12, 10, leg[1], 0, leg[2], WOOD, Enum.Material.Wood)
end
draftBox(furniture, "BedFrame", 160, 24, 250, 0, 12, 140, WOOD, Enum.Material.Wood)
draftBox(furniture, "Mattress", 150, 20, 240, 0, 36, 140, 0xEDEFF5, Enum.Material.Fabric)
draftBox(furniture, "Pillow", 92, 12, 40, 0, 56, 48, 0xFFFFFF, Enum.Material.Fabric)
draftBox(furniture, "Duvet", 158, 10, 175, 0, 54, 172, 0x2F6FB9, Enum.Material.Fabric)
for _, s in { -1, 1 } do
	draftBox(furniture, "DuvetSide", 4, 40, 175, s * 80, 24, 172, 0x2F6FB9, Enum.Material.Fabric)
end
draftBox(furniture, "DuvetFoot", 158, 30, 4, 0, 34, 261, 0x2F6FB9, Enum.Material.Fabric)
for _, s in { -1, 1 } do
	draftBox(furniture, "Nightstand", 48, 52, 48, s * 118, 0, 46, 0x8E6440, Enum.Material.Wood)
end
local shade = disc(furniture, "LampShade", 12 * S, 18 * S, CFrame.new(-118 * S, 72 * S, 46 * S), rgb(0xFFE2B0), {
	material = Enum.Material.Neon,
})
local lampLight = Instance.new("PointLight")
lampLight.Color = rgb(0xFFB36B)
lampLight.Range = 60
lampLight.Brightness = 2
lampLight.Parent = shade
draftBox(furniture, "ToyChest", 100, 45, 60, -330, 0, 50, 0xC0523E)
draftBox(furniture, "ToyChestLid", 104, 8, 64, -330, 45, 50, 0xD9B44A)
draftBox(furniture, "DeskTop", 120, 6, 70, 320, 72, 55, 0xB7895C, Enum.Material.Wood)
for _, leg in { { -56, -30 }, { 56, -30 }, { -56, 30 }, { 56, 30 } } do
	draftBox(furniture, "DeskLeg", 5, 72, 5, 320 + leg[1], 0, 55 + leg[2], 0xB7895C, Enum.Material.Wood)
end
draftBox(furniture, "ChairSeat", 44, 4, 44, 310, 42, 120, 0xE04848)
for _, leg in { { -18, -18 }, { 18, -18 }, { -18, 18 }, { 18, 18 } } do
	draftBox(furniture, "ChairLeg", 4, 42, 4, 310 + leg[1], 0, 120 + leg[2], 0x9C2F2F)
end
draftBox(furniture, "ChairBack", 44, 46, 4, 310, 46, 140, 0xE04848)
draftBox(furniture, "Bookshelf", 40, 140, 130, -380, 0, 330, 0x6E4E35, Enum.Material.Wood)
local BOOK_COLORS = { 0xE04848, 0x4DA8FF, 0x3DDC97, 0xFFC93C, 0x9246D4 }
for row = 0, 2 do
	for k = 0, 6 do
		draftBox(
			furniture,
			"Book",
			14,
			26,
			10 + (k * 7) % 6,
			-372,
			8 + row * 44,
			280 + k * 16,
			BOOK_COLORS[(k + row) % 5 + 1]
		)
	end
end
local beanbag =
	place(furniture, "Beanbag", Vector3.new(96, 52, 80) * S, CFrame.new(-190 * S, 22 * S, 400 * S), rgb(0xE2793B), {
		material = Enum.Material.Fabric,
	})
local beanMesh = Instance.new("SpecialMesh")
beanMesh.MeshType = Enum.MeshType.Sphere
beanMesh.Parent = beanbag
draftBox(furniture, "Box", 70, 60, 60, 200, 0, 420, 0xC9A36A, Enum.Material.Cardboard)
draftBox(furniture, "Box", 50, 40, 50, 250, 0, 470, 0xC9A36A, Enum.Material.Cardboard)
local window =
	place(furniture, "Window", Vector3.new(1, 90, 130) * S, CFrame.new(HW - 1, 150 * S, 230 * S), rgb(0xA9BEFF), {
		material = Enum.Material.Neon,
	})
local moon = Instance.new("SurfaceLight")
moon.Face = Enum.NormalId.Left
moon.Color = rgb(0xB9CCFF)
moon.Range = 60
moon.Angle = 120
moon.Brightness = 3
moon.Parent = window
draftBox(furniture, "LockedDoor", 4, 150, 80, -399, 0, 220, 0x6B4A30, Enum.Material.Wood)
draftBox(furniture, "DoorKnob", 5, 6, 6, -396, 70, 198, 0xD9B44A)

-- The Giant Kid, asleep. Game code animates breathing and drives him when he wakes.
local giant = Instance.new("Model")
giant.Name = "GiantKid"
giant:SetAttribute("State", "Asleep")
giant.Parent = bedroom
draftBox(giant, "Body", 70, 26, 120, 0, 62, 165, 0x2F6FB9, Enum.Material.Fabric)
local head = draftBox(giant, "Head", 44, 40, 38, 0, 58, 52, 0xF2C9A0)
draftBox(giant, "Hair", 48, 10, 42, 0, 94, 52, 0x5A3A22)
draftBox(giant, "Arm", 14, 58, 14, 84, 6, 120, 0xF2C9A0)
draftBox(giant, "Hand", 18, 8, 20, 88, 0, 124, 0xF2C9A0)
giant.PrimaryPart = head

---------------------------------------------------------------------------------------------------------------------
-- Sleeping-toy spawn points (invisible). Game code puts a blanket toy of the right size on each.
local spawns = folder(bedroom, "ToySpawns")
for k, point in MapConfig.toySpawns() do
	place(
		spawns,
		string.format("%s%02d", point.size, k),
		Vector3.new(4, 1, 4),
		CFrame.new(point.position + Vector3.new(0, 0.5, 0)),
		rgb(0xFFC93C),
		{
			collide = false,
			transparency = 1,
			attributes = { Size = point.size },
		}
	)
end

---------------------------------------------------------------------------------------------------------------------
-- Night lighting. The ceiling keeps most moonlight out, so a bright, slightly blue ambient does the render's
-- moonlight job, and a thin haze stands in for its fog (which starts 1100 studs out).
Lighting.ClockTime = 0
Lighting.Brightness = 2
Lighting.ExposureCompensation = 0.3
Lighting.Ambient = rgb(0xB4B8DC)
Lighting.OutdoorAmbient = rgb(0xB4B8DC)
Lighting.EnvironmentDiffuseScale = 0.4
Lighting.EnvironmentSpecularScale = 0.2
local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
atmosphere.Density = 0.1
atmosphere.Offset = 0
atmosphere.Color = rgb(0x2A2850)
atmosphere.Decay = rgb(0x141230)
atmosphere.Glare = 0
atmosphere.Haze = 0
atmosphere.Parent = Lighting

local parts = 0
for _, d in bedroom:GetDescendants() do
	if d:IsA("BasePart") then
		parts += 1
	end
end
return {
	parts = parts,
	holes = #holes:GetChildren(),
	toySpawns = #spawns:GetChildren(),
	archUnions = unionsMade,
	archFallbacks = unionsFailed,
	floorTiles = tilesPlaced,
}
