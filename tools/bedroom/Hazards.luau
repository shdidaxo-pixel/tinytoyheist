--!strict
-- Hazards on the run: the cat (a big voxel orange tabby; game code walks it), mouse traps by the walls, loose boards
-- on the creaky band, squeaky ducks, loose toy bricks and the baby monitor's noise zone. Game code finds these by
-- name and attribute (MapConfig has their positions).

return function(Kit: any, MapConfig: any, bedroom: Model)
	local part, block = Kit.part, Kit.block
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

	return catModel
end
