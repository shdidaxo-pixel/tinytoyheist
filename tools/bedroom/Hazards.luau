--!strict
-- Hazards on the run: the cat (a big voxel orange tabby; game code walks it), mouse traps by the walls, loose boards
-- on the creaky band, squeaky ducks, loose toy bricks, the baby monitor's noise zone and the RC car on its charger.
-- Game code finds these by name and attribute (MapConfig has their positions).
-- Build only the RC car and its charger into the built room (Edit mode, command bar), without rebuilding the map:
--   local T = game.ServerStorage.TinyToyHeistTools.Bedroom
--   local MC = require(game.ReplicatedStorage.Shared.MapConfig:Clone())
--   require(T.Hazards:Clone())(require(T.Kit:Clone()), MC.unscaled, workspace.Bedroom, { only = "RCCar", scale = MC.SCALE })

-- The RC car (Hazards.RCCar) and its charger (Hazards.RCDock): a red voxel buggy with big black wheels, a yellow
-- spoiler and a whip antenna, parked facing into the room. Local -Z is the front. Root (invisible, on the floor) is
-- the pivot game code moves; Wheel/Hub parts spin and the front ones steer, Headlight/Taillight glow while it drives.
local function buildRCCar(Kit: any, MapConfig: any, hazards: Instance): Model
	local part, block = Kit.part, Kit.block
	local at = CFrame.new(MapConfig.RC_CAR.dock) * CFrame.Angles(0, MapConfig.RC_CAR.turn, 0)
	local loose = { collide = false }

	-- the charger: a grey pad with yellow edges, a box against the wall with a charge light, a cable to the outlet
	local dock = Kit.model(hazards, "RCDock")
	local pad = block(dock, "Pad", 30, 1.2, 46, at, 0, 0, 0, 0x5A5668, loose)
	dock.PrimaryPart = pad
	for _, s in { -1, 1 } do
		block(dock, "Edge", 1.6, 1.4, 46, at, s * 15, 0, 0, 0xFFD43B, loose)
	end
	for k = 0, 3 do
		block(dock, "Chevron", 10, 1.3, 2, at, 0, 0, -16 + k * 6, 0xFFD43B, loose)
	end
	block(dock, "Charger", 12, 9, 6, at, 0, 0, 27, 0x2B2B33, loose)
	local light = block(dock, "ChargeLight", 4, 3, 0.6, at, 0, 4, 23.7, 0x3DFF7A, {
		material = Enum.Material.Neon,
		collide = false,
	})
	Kit.light(light, "PointLight", 0x3DFF7A, 0.8, 14)
	Kit.rod(
		dock,
		"Cable",
		(at * CFrame.new(0, 2, 30)).Position,
		(at * CFrame.new(0, 2, 34)).Position,
		0.5,
		0x1A1430,
		loose
	)

	-- the car
	local car = Kit.model(hazards, "RCCar", { State = "Docked" })
	local root = part(car, "Root", Vector3.new(4, 1, 4), at * CFrame.new(0, 0.5, 0), 0xFFFFFF, {
		collide = false,
		transparency = 1,
	})
	car.PrimaryPart = root
	local RED, DARK, BLACK, YELLOW, SILVER = 0xE8202E, 0x2B2B33, 0x1A1A1F, 0xFFD43B, 0xC8CCD6
	block(car, "Chassis", 20, 3, 34, at, 0, 4.5, 0, DARK, loose)
	block(car, "Body", 18, 6, 26, at, 0, 7.5, 0, RED, loose)
	block(car, "Hood", 16, 2, 9, at, 0, 13.5, -8, RED, loose)
	block(car, "Stripe", 4, 0.4, 9.2, at, 0, 15.5, -8, 0xFFFFFF, loose)
	block(car, "Stripe", 4, 0.4, 12, at, 0, 13.5, 6.5, 0xFFFFFF, loose)
	block(car, "Cabin", 14, 6, 10, at, 0, 13.5, 1.5, BLACK, loose)
	block(car, "Windshield", 12.4, 4.4, 0.6, at, 0, 14.3, -3.6, 0x7FD6FF, {
		material = Enum.Material.Glass,
		transparency = 0.15,
		collide = false,
	})
	-- roll bar and spoiler
	for _, s in { -1, 1 } do
		block(car, "RollBar", 1.4, 3, 1.4, at, s * 6.3, 19.5, 2, SILVER, loose)
		block(car, "SpoilerPost", 1.2, 4.5, 1.2, at, s * 6, 13.5, 12, BLACK, loose)
	end
	block(car, "RollBar", 14, 1.4, 1.4, at, 0, 22.3, 2, SILVER, loose)
	block(car, "Spoiler", 21, 1.4, 6, at, 0, 18, 12.5, YELLOW, loose)
	for _, s in { -1, 1 } do
		block(car, "SpoilerFin", 0.8, 4, 6, at, s * 10.5, 16.5, 12.5, YELLOW, loose)
	end
	-- bumpers, lights
	block(car, "Bumper", 22, 2.5, 2.5, at, 0, 4, -17.5, SILVER, loose)
	block(car, "Bumper", 22, 2.5, 2.5, at, 0, 4, 17.5, SILVER, loose)
	for _, s in { -1, 1 } do
		block(car, "Headlight", 3.5, 2.4, 0.6, at, s * 5.5, 9.5, -13.3, 0xFFF3B0, {
			material = Enum.Material.Neon,
			collide = false,
		})
		block(car, "Taillight", 3.5, 2, 0.6, at, s * 5.5, 10, 13.3, 0xFF3344, {
			material = Enum.Material.Neon,
			collide = false,
		})
	end
	local glow = part(car, "HeadlightGlow", Vector3.one, at * CFrame.new(0, 10, -14), 0xFFFFFF, {
		collide = false,
		transparency = 1,
	})
	Kit.light(glow, "SpotLight", 0xFFF3B0, 0, 50, { Angle = 70, Face = Enum.NormalId.Front })
	-- the racing number on each side
	for _, s in { -1, 1 } do
		local plate = block(car, "Number", 0.4, 5, 5, at, s * 9.2, 8, 2, 0xFFFFFF, loose)
		Kit.text(plate, "7", {
			face = if s < 0 then Enum.NormalId.Left else Enum.NormalId.Right,
			color = Color3.fromRGB(26, 20, 48),
			pixelsPerStud = 12,
		})
	end
	-- the whip antenna with a red tip
	local tip = (at * CFrame.new(-6.5, 32, 15)).Position
	Kit.rod(car, "Antenna", (at * CFrame.new(-6.5, 13.5, 10)).Position, tip, 0.35, BLACK, loose)
	Kit.ball(car, "AntennaTip", 1.1, tip, RED, loose)
	-- big chunky wheels (cylinders run along X: across the car) with yellow hubs and voxel treads
	for _, w in { { -1, -11 }, { 1, -11 }, { -1, 11 }, { 1, 11 } } do
		local cf = at * CFrame.new(w[1] * 12.5, 6.5, w[2])
		part(car, "Wheel", Vector3.new(5.5, 13, 13), cf, BLACK, { shape = Enum.PartType.Cylinder, collide = false })
		part(car, "Hub", Vector3.new(6, 5.5, 5.5), cf, YELLOW, { shape = Enum.PartType.Cylinder, collide = false })
		for k = 0, 7 do
			local a = k / 8 * 2 * math.pi
			part(
				car,
				"Tread",
				Vector3.new(5.7, 1.4, 3),
				cf * CFrame.Angles(a, 0, 0) * CFrame.new(0, 6.2, 0),
				0x34343C,
				loose
			)
		end
	end
	return car
end

return function(Kit: any, MapConfig: any, bedroom: Model, build: { only: string?, scale: number? }?)
	local part, block = Kit.part, Kit.block
	if build and build.only == "RCCar" then
		-- just the RC car and its charger, into the room as it stands (built full size, then shrunk about the
		-- origin like the whole room)
		local folder = bedroom:WaitForChild("Hazards")
		for _, name in { "RCCar", "RCDock" } do
			local old = folder:FindFirstChild(name)
			if old then
				old:Destroy()
			end
		end
		local holder = Instance.new("Model")
		local car = buildRCCar(Kit, MapConfig, holder)
		holder.WorldPivot = CFrame.new()
		holder:ScaleTo(build.scale or 1)
		for _, child in holder:GetChildren() do
			child.Parent = folder
		end
		holder:Destroy()
		return car
	end
	local hazards = Kit.folder(bedroom, "Hazards")

	---------------------------------------------------------------------------------------------------------------
	-- The cat, crouched on the wood band. Local +X is where it faces. Root is the pivot game code moves.
	local catModel = Kit.model(hazards, "Cat", { State = "Patrol", Aggressive = false })
	local home = MapConfig.CAT.home
	local catAt = CFrame.new(home) * CFrame.Angles(0, 0.4, 0)
	local FUR, DARK, CREAM = 0xF28C28, 0xC4601A, 0xFFE3C2
	local soft = { material = Enum.Material.Fabric, collide = false }
	local function c(
		name: string,
		w: number,
		h: number,
		d: number,
		x: number,
		y: number,
		z: number,
		color: number,
		options: any?
	)
		return block(catModel, name, w, h, d, catAt, x, y, z, color, options or soft)
	end
	local root = part(catModel, "Root", Vector3.new(4, 1, 4), catAt * CFrame.new(0, 0.5, 0), 0xFFFFFF, {
		collide = false,
		transparency = 1,
	})
	catModel.PrimaryPart = root
	c("Body", 70, 28, 32, 0, 16, 0, FUR)
	for _, sx in { -22, -6, 10, 26 } do
		c("Stripe", 6, 28.4, 32.4, sx, 15.8, 0, DARK)
	end
	c("Belly", 40, 4, 26, 6, 14, 0, CREAM)
	for _, leg in { { -26, -11 }, { -26, 11 }, { 24, -11 }, { 24, 11 } } do
		c("Leg", 10, 16, 10, leg[1], 0, leg[2], FUR)
		c("Paw", 11, 4, 11, leg[1] + 1, 0, leg[2], CREAM)
	end
	-- head
	local headAt = catAt * CFrame.new(44, 34, 0)
	local function h(
		name: string,
		w: number,
		hh: number,
		d: number,
		x: number,
		y: number,
		z: number,
		color: number,
		options: any?
	)
		return block(catModel, name, w, hh, d, headAt, x, y, z, color, options or soft)
	end
	h("Head", 28, 26, 28, 0, 0, 0, FUR)
	h("Muzzle", 10, 9, 16, 14, 3, 0, CREAM)
	h("Nose", 2, 3, 4, 19.2, 7.5, 0, 0xFF8FA8)
	for _, s in { -1, 1 } do
		Kit.part(
			catModel,
			"Ear",
			Vector3.new(4, 12, 10),
			headAt * CFrame.new(-2, 32, s * 8) * CFrame.Angles(0, math.pi / 2, 0),
			FUR,
			{ class = "WedgePart", material = Enum.Material.Fabric, collide = false }
		)
		h("Eye", 1, 7, 6, 14.2, 12.5, s * 6.5, 0xD8FF5A, { material = Enum.Material.Neon, collide = false })
		h("Pupil", 1.2, 6, 1.6, 14.5, 13, s * 6.5, 0x111111, { collide = false })
		for k = 0, 2 do
			Kit.part(
				catModel,
				"Whisker",
				Vector3.new(0.4, 0.4, 14),
				headAt * CFrame.new(17, 8 + k * 1.6, s * 12) * CFrame.Angles(s * (k - 1) * 0.2, 0, 0),
				0xFFFFFF,
				{ collide = false }
			)
		end
	end
	-- collar and bell
	c("Collar", 4, 5, 34, 30, 36, 0, 0xE04848)
	Kit.ball(catModel, "Bell", 4, (catAt * CFrame.new(34, 33, 0)).Position, 0xFFD43B, {
		material = Enum.Material.Metal,
		collide = false,
	})
	-- the tail: a chain of blocks curling up behind
	for k = 0, 5 do
		local x = -38 - k * 6.5
		local y = 30 + k * 2.5 + (k * k) * 0.6
		Kit.part(
			catModel,
			"Tail",
			Vector3.new(8, 6, 6),
			catAt * CFrame.new(x, y, 0) * CFrame.Angles(0, 0, -0.18 - k * 0.08),
			if k % 2 == 1 then DARK else FUR,
			soft
		)
	end
	-- the red "!" when it's hunting (shown by game code)
	local alert = Instance.new("BillboardGui")
	alert.Name = "Alert"
	alert.Size = UDim2.fromScale(14, 14)
	alert.StudsOffsetWorldSpace = Vector3.new(0, 30, 0)
	alert.LightInfluence = 0
	alert.Enabled = false
	alert.Parent = catModel:FindFirstChild("Head")
	local bang = Instance.new("TextLabel")
	bang.Size = UDim2.fromScale(1, 1)
	bang.BackgroundColor3 = Color3.fromRGB(255, 77, 94)
	bang.Text = "!"
	bang.TextScaled = true
	bang.Font = Enum.Font.GothamBlack
	bang.TextColor3 = Color3.new(1, 1, 1)
	bang.Parent = alert
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = bang

	---------------------------------------------------------------------------------------------------------------
	-- Mouse traps by the walls: a VICTOR trap with the bail cocked and cheese on the trigger. SNAP = drop your toy.
	local traps = Kit.folder(hazards, "Traps")
	local STEEL = 0xD7DCE6
	for k, t in MapConfig.TRAPS do
		local at = CFrame.new(t.position) * CFrame.Angles(0, t.turn, 0)
		local trap = Kit.model(traps, "Trap" .. k, { Armed = true })
		local base = block(trap, "Base", 30, 2.4, 14, at, 0, 0, 0, 0xD2A86E, { material = Enum.Material.Wood })
		trap.PrimaryPart = base
		local stamp = part(
			trap,
			"Stamp",
			Vector3.new(6, 0.05, 16),
			at * CFrame.new(-3, 2.43, 0) * CFrame.Angles(0, math.pi / 2, 0),
			0xFFFFFF,
			{
				collide = false,
				transparency = 1,
			}
		)
		Kit.text(stamp, "VICTOR", {
			face = Enum.NormalId.Top,
			color = Color3.fromRGB(178, 34, 34),
			pixelsPerStud = 8,
		})
		local metal = { material = Enum.Material.Metal, collide = false }
		block(trap, "Bail", 0.9, 0.9, 12, at, -9, 2.8, 0, STEEL, metal)
		block(trap, "Bail", 0.9, 0.9, 12, at, 6, 2.8, 0, STEEL, metal)
		for _, s in { -1, 1 } do
			block(trap, "Bail", 15, 0.9, 0.9, at, -1.5, 2.8, s * 5.6, STEEL, metal)
			Kit.part(trap, "Spring", Vector3.new(0.9, 2.8, 2.8), at * CFrame.new(6, 3.4, s * 3), STEEL, {
				shape = Enum.PartType.Cylinder,
				material = Enum.Material.Metal,
				collide = false,
			})
		end
		block(trap, "Trigger", 9, 0.5, 7, at, 9, 2.4, 0, 0xC88A3A, metal)
		Kit.part(
			trap,
			"Cheese",
			Vector3.new(6, 3.6, 7),
			at * CFrame.new(9.5, 4.7, 0) * CFrame.Angles(0, 0.4, 0),
			0xFFD43B,
			{ class = "WedgePart", collide = false }
		)
		local glow = part(trap, "Glow", Vector3.one, at * CFrame.new(0, 4, 0), 0xFF4D5E, {
			collide = false,
			transparency = 1,
		})
		Kit.light(glow, "PointLight", 0xFF4D5E, 0.8, 14)
	end

	---------------------------------------------------------------------------------------------------------------
	-- Loose boards on the creaky band, lifted at one end: step on one and it creaks (a big noise spike)
	local boards = Kit.folder(hazards, "LooseBoards")
	for k, p in MapConfig.LOOSE_BOARDS do
		local at = CFrame.new(p) * CFrame.Angles(0, ((k - 1) % 3 - 1) * 0.3, 0)
		local board = Kit.model(boards, "Board" .. k, { Noise = 15 })
		block(board, "Gap", 34, 1.3, 7.5, at, 0, -0.3, 0, 0x3A2818, { shadow = false })
		local plank = Kit.part(
			board,
			"Plank",
			Vector3.new(32, 1.3, 6.8),
			at * CFrame.new(0, 1.4, 0) * CFrame.Angles(0, 0, 0.07 + ((k - 1) % 3) * 0.02),
			0x9A7853,
			{ material = Enum.Material.WoodPlanks }
		)
		board.PrimaryPart = plank
		for nail = 0, 1 do
			Kit.disc(board, "Nail", 0.5, 0.4, at * CFrame.new(-12 + nail * 2, 2.4, 0), 0xB8BFC8, {
				material = Enum.Material.Metal,
				collide = false,
			})
		end
	end

	-- Squeaky ducks near the Large toys
	local ducks = Kit.folder(hazards, "Ducks")
	for k, d in MapConfig.DUCKS do
		local at = CFrame.new(d.position) * CFrame.Angles(0, d.turn, 0)
		local duck = Kit.model(ducks, "Duck" .. k, { Noise = 8 })
		local body = part(duck, "Body", Vector3.new(12.5, 8.5, 10), at * CFrame.new(0, 4.2, 0), 0xFFD43B, {
			material = Enum.Material.Plastic,
		})
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = body
		duck.PrimaryPart = body
		Kit.ball(duck, "Head", 3.2, (at * CFrame.new(3.8, 9.6, 0)).Position, 0xFFD43B, {
			material = Enum.Material.Plastic,
		})
		Kit.part(
			duck,
			"Beak",
			Vector3.new(2.4, 1.4, 3),
			at * CFrame.new(7.4, 9.2, 0) * CFrame.Angles(0, -math.pi / 2, 0),
			0xFF8A3D,
			{
				class = "WedgePart",
				collide = false,
			}
		)
		for _, s in { -1, 1 } do
			Kit.ball(duck, "Eye", 0.55, (at * CFrame.new(6, 10.6, s * 1.6)).Position, 0x1A1430, { collide = false })
		end
	end

	-- Loose toy bricks: solid, they clack when you bump them
	local bricks = Kit.folder(hazards, "Bricks")
	local brickColors = { 0xE04848, 0xFFC93C, 0x4DA8FF, 0x3DDC97 }
	local count = 0
	local function brick(position: Vector3, color: number, turn: number, y: number)
		count += 1
		local at = CFrame.new(position + Vector3.new(0, y, 0)) * CFrame.Angles(0, turn, 0)
		local b = Kit.model(bricks, "Brick" .. count, { Noise = 5 })
		local body = block(b, "Body", 10.7, 3.8, 5.3, at, 0, 0, 0, color, { material = Enum.Material.Plastic })
		b.PrimaryPart = body
		for i = 0, 3 do
			for k = 0, 1 do
				Kit.disc(b, "Stud", 0.85, 0.9, at * CFrame.new(-4 + i * 2.67, 4.25, -1.33 + k * 2.67), color, {
					material = Enum.Material.Plastic,
					collide = false,
				})
			end
		end
	end
	for k, p in MapConfig.BRICKS do
		brick(p, brickColors[(k - 1) % 4 + 1], (k - 1) * 0.9, 0)
		if k % 2 == 1 then
			brick(p + Vector3.new(1.5, 0, 0.8), brickColors[(k + 1) % 4 + 1], (k - 1) * 0.9 + 0.4, 3.8)
		end
	end

	---------------------------------------------------------------------------------------------------------------
	-- The baby monitor's zone in front of the bed: noise counts double inside the green circle
	local m = MapConfig.MONITOR_ZONE
	local zone =
		Kit.disc(hazards, "MonitorZone", m.radius, 0.1, CFrame.new(m.center + Vector3.new(0, 0.12, 0)), 0x3DFF7A, {
			material = Enum.Material.Neon,
			collide = false,
			transparency = 0.93,
			attributes = { NoiseMultiplier = m.noise },
		})
	local edges = 48
	for k = 0, edges - 1 do
		local a0, a1 = k / edges * 2 * math.pi, (k + 1) / edges * 2 * math.pi
		Kit.rod(
			zone,
			"Edge",
			m.center + Vector3.new(math.cos(a0) * m.radius, 0.2, math.sin(a0) * m.radius),
			m.center + Vector3.new(math.cos(a1) * m.radius, 0.2, math.sin(a1) * m.radius),
			0.35,
			0x3DFF7A,
			{ material = Enum.Material.Neon, collide = false, transparency = 0.4 }
		)
	end
	local tag = part(
		zone,
		"Tag",
		Vector3.new(6.5, 0.1, 26),
		CFrame.new(m.center + Vector3.new(0, 0.3, m.radius + 6)) * CFrame.Angles(0, math.pi / 2, 0),
		0xFFFFFF,
		{
			collide = false,
			transparency = 1,
		}
	)
	Kit.text(tag, "NOISE x2", {
		face = Enum.NormalId.Top,
		color = Color3.fromRGB(14, 42, 24),
		background = Color3.fromRGB(61, 255, 122),
		pixelsPerStud = 8,
		glow = true,
	})

	buildRCCar(Kit, MapConfig, hazards)

	return catModel
end
