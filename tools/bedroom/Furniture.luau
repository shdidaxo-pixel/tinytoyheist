--!strict
-- The big furniture, all against the walls: the bed along the runner's right-hand wall with the voxel Giant Kid asleep
-- in it (and his sitting-up pose with the flashlight, hidden until he wakes), the nightstand with the lamp, clock and
-- baby monitor, the desk with the old computer and the chair, the window with its blinds over the desk, and the
-- night-light by the door. Sizes come from the render's first-draft (v3) units, scaled by MapConfig.FURNITURE_SCALE.

local function face(part: BasePart, normal: Enum.NormalId, kind: string)
	-- A cartoon face drawn with frames: "sleep" (closed eyes, rosy cheeks, open mouth, drool) or "angry".
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Face"
	gui.Face = normal
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 8
	gui.LightInfluence = 1
	gui.MaxDistance = 1500
	gui.Parent = part
	local root = Instance.new("Frame")
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundTransparency = 1
	root.Parent = gui
	local brown = Color3.fromRGB(58, 36, 24)
	local function shape(
		x: number,
		y: number,
		w: number,
		h: number,
		color: Color3,
		round: number?,
		rotation: number?,
		alpha: number?
	)
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale(x, y)
		f.Size = UDim2.fromScale(w, h)
		f.BackgroundColor3 = color
		f.BackgroundTransparency = alpha or 0
		f.BorderSizePixel = 0
		f.Rotation = rotation or 0
		if round then
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(round, 0)
			c.Parent = f
		end
		f.Parent = root
		return f
	end
	if kind == "sleep" then
		for _, x in { 0.3, 0.7 } do
			-- a closed eye: a shallow U from three short strokes
			shape(x, 0.42, 0.1, 0.035, brown, 1)
			shape(x - 0.065, 0.405, 0.06, 0.03, brown, 1, -35)
			shape(x + 0.065, 0.405, 0.06, 0.03, brown, 1, 35)
			shape(x, 0.25, 0.14, 0.03, brown, 1, if x < 0.5 then -6 else 6) -- brow
			shape(if x < 0.5 then 0.2 else 0.8, 0.56, 0.16, 0.1, Color3.fromRGB(255, 120, 140), 1, 0, 0.5) -- cheek
		end
		shape(0.52, 0.72, 0.2, 0.16, Color3.fromRGB(90, 30, 34), 1) -- open mouth, mid-snore
		shape(0.52, 0.77, 0.12, 0.07, Color3.fromRGB(228, 106, 120), 1)
		shape(0.615, 0.87, 0.025, 0.2, Color3.fromRGB(190, 225, 255), 1, -6, 0.15) -- drool
	else
		for _, x in { 0.3, 0.7 } do
			shape(x, 0.42, 0.14, 0.09, brown, 1)
			shape(x, 0.3, 0.2, 0.045, brown, 1, if x < 0.5 then 20 else -20) -- angry brows
		end
		shape(0.5, 0.74, 0.26, 0.04, brown, 1, 0)
		shape(0.38, 0.76, 0.06, 0.04, brown, 1, 30)
		shape(0.62, 0.76, 0.06, 0.04, brown, 1, -30)
	end
	return gui
end

return function(Kit: any, MapConfig: any, bedroom: Model)
	local rgb, part, block = Kit.rgb, Kit.part, Kit.block
	local S = MapConfig.FURNITURE_SCALE
	local LEN, HW = MapConfig.LENGTH, MapConfig.HALF_WIDTH
	local furniture = Kit.folder(bedroom, "Furniture")

	local WOOD, WOOD_DARK = 0x7A5233, 0x5C3D25
	local DUVET, DUVET_DARK, DUVET_LIGHT = 0x2F6FB9, 0x285FA0, 0x3878C4
	local SKIN, HAIR = 0xF2C9A0, 0x5A3A22
	local PJ_BLUE = 0x7FB6F0

	---------------------------------------------------------------------------------------------------------------
	-- The bed: in the render's v3 units, scaled, at MapConfig.BED, turned so the headboard is toward the far wall.
	local bedAt = CFrame.new(MapConfig.BED.position) * CFrame.Angles(0, math.rad(MapConfig.BED.turn), 0)
	local function big(
		parent: Instance,
		name: string,
		w: number,
		h: number,
		d: number,
		x: number,
		y: number,
		z: number,
		color: number,
		options: any?
	): BasePart
		return block(parent, name, w * S, h * S, d * S, bedAt, x * S, y * S, z * S, color, options)
	end
	local wood = { material = Enum.Material.Wood }
	local fabric = { material = Enum.Material.Fabric }

	local bed = Kit.model(furniture, "Bed")
	big(bed, "Headboard", 150, 86, 10, 0, 0, 5, WOOD, wood)
	big(bed, "HeadboardStep", 126, 8, 10, 0, 86, 5, WOOD, wood)
	big(bed, "HeadboardStep", 92, 8, 10, 0, 94, 5, WOOD, wood)
	big(bed, "HeadboardStep", 46, 8, 10, 0, 102, 5, WOOD, wood)
	big(bed, "HeadboardBand", 152, 4, 11, 0, 40, 5, WOOD_DARK, wood)
	for _, s in { -1, 1 } do
		-- the wall-side post is nudged in a stud so it doesn't sit in the wall
		local x = s * 80 + (if s > 0 then -1 else 0)
		big(bed, "Post", 14, 112, 14, x, 0, 6, WOOD_DARK, wood)
		big(bed, "PostCap", 18, 6, 18, x, 112, 6, WOOD, wood)
		big(bed, "PostTop", 10, 4, 10, x, 118, 6, WOOD_DARK, wood)
	end
	for _, star in { { -42, 62, 16 }, { 0, 74, 20 }, { 42, 62, 16 } } do
		local sticker = part(
			bed,
			"Star",
			Vector3.new(star[3] * S, star[3] * S, 0.2),
			bedAt * CFrame.new(star[1] * S, star[2] * S, 10.4 * S),
			0xDFFFB0,
			{ collide = false, transparency = 1 }
		)
		Kit.text(sticker, "★", { face = Enum.NormalId.Back, color = rgb(0xDFFFB0), pixelsPerStud = 8, glow = true })
	end
	for _, leg in { { -74, 22 }, { 74, 22 }, { -74, 258 }, { 74, 258 } } do
		big(bed, "Leg", 16, 10, 16, leg[1], 0, leg[2], WOOD_DARK, wood)
		big(bed, "LegCap", 18, 2, 18, leg[1], 10, leg[2], WOOD, wood)
	end
	big(bed, "Frame", 158, 24, 250, 0, 12, 140, WOOD, wood)
	big(bed, "FrameBand", 160, 3, 252, 0, 30, 140, WOOD_DARK, wood)
	big(bed, "Mattress", 150, 20, 240, 0, 36, 140, 0xEDEFF5, fabric)
	big(bed, "MattressSeam", 151, 1.5, 241, 0, 45, 140, 0xC9CED8, fabric)
	big(bed, "Pillow", 92, 10, 40, 0, 56, 48, 0xFFFFFF, fabric)
	big(bed, "PillowTop", 84, 4, 32, 0, 66, 48, 0xF4F6FA, fabric)
	-- the quilted duvet: 3 x 3 squares in two blues with white stitching between them
	for i = 0, 2 do
		for k = 0, 2 do
			local w, d = 158 / 3, 175 / 3
			big(
				bed,
				"Quilt",
				w,
				10,
				d,
				-79 + (i + 0.5) * w,
				54,
				172 - 87.5 + (k + 0.5) * d,
				if (i + k) % 2 == 1 then DUVET else DUVET_LIGHT,
				fabric
			)
		end
	end
	for k = 1, 2 do
		big(bed, "Stitch", 0.6, 0.2, 175, -79 + k * 158 / 3, 64, 172, 0xFFFFFF, { collide = false, transparency = 0.3 })
		big(
			bed,
			"Stitch",
			158,
			0.2,
			0.6,
			0,
			64,
			172 - 87.5 + k * 175 / 3,
			0xFFFFFF,
			{ collide = false, transparency = 0.3 }
		)
	end
	for _, s in { -1, 1 } do
		big(bed, "Drape", 4, 22.2, 175, s * 80 + (if s > 0 then -1 else 0), 42, 172, DUVET, fabric)
		big(bed, "DrapeLow", 4, 22, 171, s * 82 + (if s > 0 then -2.5 else 0), 22, 172, DUVET_DARK, fabric)
	end
	big(bed, "DrapeFoot", 158, 22.2, 4, 0, 42, 261, DUVET, fabric)
	big(bed, "DrapeFootLow", 154, 20, 4, 0, 22, 264.5, DUVET_DARK, fabric)
	block(
		bed,
		"FoldedCorner",
		34 * S,
		1.6 * S,
		34 * S,
		bedAt * CFrame.new(54 * S, 0, 236 * S) * CFrame.Angles(0, math.pi / 4, 0),
		0,
		64.2 * S,
		0,
		0xF4F6FA,
		fabric
	)
	-- a voxel teddy keeping him company on the pillow
	local tedAt = bedAt * CFrame.new(44 * S, 62 * S, 42 * S) * CFrame.Angles(0, -0.5, 0)
	local teddy = Kit.model(bed, "Teddy")
	local function ted(name: string, w: number, h: number, d: number, x: number, y: number, z: number, color: number)
		block(teddy, name, w * S, h * S, d * S, tedAt, x * S, y * S, z * S, color, fabric)
	end
	ted("Body", 12, 13, 9, 0, 0, 0, 0xA8743F)
	ted("Head", 11, 10, 9, 0, 13, 0, 0xA8743F)
	ted("Ear", 4, 4, 3, -4.5, 22, 0, 0xA8743F)
	ted("Ear", 4, 4, 3, 4.5, 22, 0, 0xA8743F)
	ted("Muzzle", 5, 4, 2, 0, 15, 4.5, 0xE8C79A)
	ted("Arm", 4, 8, 4, -8, 4, 0, 0xA8743F)
	ted("Arm", 4, 8, 4, 8, 4, 0, 0xA8743F)
	ted("Eye", 1.4, 1.4, 1, -2.5, 19, 4.6, 0x1A1430)
	ted("Eye", 1.4, 1.4, 1, 2.5, 19, 4.6, 0x1A1430)

	---------------------------------------------------------------------------------------------------------------
	-- The Giant Kid. Asleep parts show by default; the SitUp parts (and the flashlight) are hidden until game code
	-- shows them. Every hideable part keeps its visible transparency in a "Shown" attribute.
	local giant = Kit.model(bedroom, "GiantKid", { State = "Asleep" })
	local asleep = Kit.folder(giant, "Asleep")
	local sitUp = Kit.folder(giant, "SitUp")
	local function kid(
		parent: Instance,
		name: string,
		w: number,
		h: number,
		d: number,
		x: number,
		y: number,
		z: number,
		color: number,
		options: any?
	): BasePart
		local p = big(parent, name, w, h, d, x, y, z, color, options)
		p:SetAttribute("Shown", p.Transparency)
		if parent == sitUp then
			p.Transparency = 1
			p.CanCollide = false
		end
		return p
	end
	local function stripes(
		parent: Instance,
		name: string,
		w: number,
		h: number,
		d: number,
		x: number,
		y: number,
		z: number
	)
		-- striped pyjama fabric, in bands 7.5 tall
		local n = math.max(1, math.floor(h / 7.5 + 0.5))
		for k = 0, n - 1 do
			kid(parent, name, w, h / n, d, x, y + k * h / n, z, if k % 2 == 0 then PJ_BLUE else 0xFFFFFF, fabric)
		end
	end
	kid(asleep, "BodyLower", 74, 14, 124, 0, 62, 165, DUVET, fabric)
	kid(asleep, "BodyUpper", 58, 10, 106, 0, 76, 165, DUVET_LIGHT, fabric)
	local head = kid(asleep, "Head", 44, 40, 38, 0, 58, 52, SKIN)
	face(head, Enum.NormalId.Back, "sleep")
	kid(asleep, "Hair", 48, 10, 42, 0, 94, 52, HAIR)
	for _, tuft in
		{ { -14, 104, 52, 10 }, { 6, 104, 44, 9 }, { 16, 102, 62, 8 }, { -4, 103, 63, 9 }, { -20, 100, 40, 7 } }
	do
		kid(asleep, "Tuft", tuft[4], 6, tuft[4], tuft[1], tuft[2], tuft[3], HAIR)
	end
	-- his arm hanging off the bed onto the floor: striped sleeve, forearm, a hand with fingers
	stripes(asleep, "Sleeve", 16, 30, 16, -84, 34, 120)
	kid(asleep, "Forearm", 13, 28, 13, -84, 7, 120, SKIN)
	kid(asleep, "Hand", 18, 7, 20, -86, 0, 125, SKIN)
	for k = 0, 3 do
		kid(asleep, "Finger", 3.6, 3.6, 8, -79.5 - k * 4.3, 0, 138, SKIN)
	end
	kid(asleep, "Thumb", 4, 4, 7, -96, 1, 124, SKIN)
	-- a snot bubble (game code grows and pops it) and the Zs drifting up
	local bubble = Kit.ball(
		asleep,
		"Bubble",
		1.2,
		(bedAt * CFrame.new(-6 * S, 70 * S, 72 * S)).Position,
		0xBFE6FF,
		{ collide = false, transparency = 0.45, reflectance = 0.2 }
	)
	bubble:SetAttribute("Shown", 0.45)
	local zAnchor = part(asleep, "Zzz", Vector3.one, bedAt * CFrame.new(0, 125 * S, 52 * S), 0xFFFFFF, {
		collide = false,
		transparency = 1,
	})
	zAnchor:SetAttribute("Shown", 1)
	for k = 1, 3 do
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "Z" .. k
		billboard.Size = UDim2.fromScale(14 + k * 5, 14 + k * 5)
		billboard.StudsOffset = Vector3.new(k * 6, k * 22, 0)
		billboard.LightInfluence = 0
		billboard.MaxDistance = 1800
		billboard.Parent = zAnchor
		local z = Instance.new("TextLabel")
		z.Size = UDim2.fromScale(1, 1)
		z.BackgroundTransparency = 1
		z.Text = "Z"
		z.TextScaled = true
		z.Font = Enum.Font.FredokaOne
		z.TextColor3 = rgb(0xC9D2FF)
		z.TextTransparency = 0.15 * k
		z.Parent = billboard
	end
	giant.PrimaryPart = head

	-- Sitting up: pyjama torso, head with an angry face, an arm out in front holding a flashlight
	stripes(sitUp, "Torso", 62, 58, 36, 0, 60, 66)
	local angry = kid(sitUp, "Head", 44, 40, 38, 0, 118, 70, SKIN)
	face(angry, Enum.NormalId.Back, "angry").Enabled = false
	kid(sitUp, "Hair", 48, 10, 42, 0, 156, 70, HAIR)
	stripes(sitUp, "Arm", 14, 14, 46, 34, 96, 104)
	kid(sitUp, "Hand", 14, 14, 12, 34, 96, 132, SKIN)
	-- the flashlight: game code aims it (its PrimaryPart's front, -Z, is the beam) at MapConfig.flashlightTarget
	local flashlight = Kit.model(sitUp, "Flashlight")
	local lensAt = bedAt * CFrame.new(34 * S, 103 * S, 140 * S) * CFrame.Angles(0, math.pi, 0)
	local function torch(name: string, size: Vector3, offset: number, color: number, options: any)
		local p = part(
			flashlight,
			name,
			size,
			lensAt * CFrame.new(0, 0, offset) * CFrame.Angles(0, math.pi / 2, 0),
			color,
			options
		)
		p:SetAttribute("Shown", p.Transparency)
		p.Transparency = 1
		return p
	end
	local body = torch("Body", Vector3.new(22 * S, 8 * S, 8 * S), 11 * S, 0x3DA5FF, {
		shape = Enum.PartType.Cylinder,
		collide = false,
	})
	torch("Head", Vector3.new(8 * S, 13 * S, 13 * S), 0, 0xC9D0DE, {
		shape = Enum.PartType.Cylinder,
		material = Enum.Material.Metal,
		collide = false,
	})
	local lens = torch("Lens", Vector3.new(0.5, 12 * S, 12 * S), -4.2 * S, 0xFFF6C0, {
		shape = Enum.PartType.Cylinder,
		material = Enum.Material.Neon,
		collide = false,
	})
	lens.CFrame = lensAt * CFrame.new(0, 0, -4.2 * S) * CFrame.Angles(0, math.pi / 2, 0)
	flashlight.PrimaryPart = body
	local beamStart = Instance.new("Attachment")
	beamStart.Name = "BeamStart"
	beamStart.Parent = lens
	-- where the beam lands: a pool of light on the floor with a spotlight over it (Roblox lights reach 60 studs)
	local target = MapConfig.flashlightTarget(0)
	local pool = Kit.disc(sitUp, "BeamPool", 34, 0.2, CFrame.new(target + Vector3.new(0, 0.35, 0)), 0xFFF2B0, {
		material = Enum.Material.Neon,
		collide = false,
		transparency = 1,
	})
	pool:SetAttribute("Shown", 0.82)
	local beamEnd = Instance.new("Attachment")
	beamEnd.Name = "BeamEnd"
	beamEnd.Parent = pool
	local beam = Instance.new("Beam")
	beam.Name = "Beam"
	beam.Attachment0 = beamStart
	beam.Attachment1 = beamEnd
	beam.Width0 = 8
	beam.Width1 = 70
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Color = ColorSequence.new(rgb(0xFFF2B0))
	beam.Transparency = NumberSequence.new(0.72, 0.9)
	beam.Segments = 1
	beam.Enabled = false
	beam.Parent = pool
	local poolLight = part(sitUp, "BeamLight", Vector3.one, CFrame.new(target + Vector3.new(0, 45, 0)), 0xFFFFFF, {
		collide = false,
		transparency = 1,
	})
	poolLight:SetAttribute("Shown", 1)
	Kit.light(poolLight, "SpotLight", 0xFFF2B0, 6, 60, { Face = Enum.NormalId.Bottom, Angle = 70, Enabled = false })

	---------------------------------------------------------------------------------------------------------------
	-- Nightstand by the head of the bed: stepped lamp, red alarm clock reading 2:00, the baby monitor
	local stand = Kit.model(furniture, "Nightstand")
	local nsAt = CFrame.new(MapConfig.NIGHTSTAND)
	block(stand, "Body", 72, 78, 72, nsAt, 0, 0, 0, 0x8E6440, wood)
	block(stand, "Top", 78, 6, 78, nsAt, 0, 78, 0, 0x7A5233, wood)
	for _, y in { 12, 42 } do
		block(stand, "Drawer", 1.5, 24, 60, nsAt, 36.6, y, 0, 0xA77A50, wood)
		block(stand, "Knob", 2, 6, 7, nsAt, 37.8, y + 9, 0, 0xD9B44A, { material = Enum.Material.Metal })
	end
	block(stand, "LampBase", 20, 6, 20, nsAt, -8, 84, -10, 0x5C3D25, wood)
	block(stand, "LampStem", 4, 14, 4, nsAt, -8, 90, -10, 0xD9B44A, { material = Enum.Material.Metal })
	for _, shade in { { 38, 9, 104 }, { 31, 9, 113 }, { 22, 8, 122 } } do
		block(stand, "Shade", shade[1], shade[2], shade[1], nsAt, -8, shade[3], -10, 0xFFE2B0, {
			material = Enum.Material.Neon,
		})
	end
	local lamp = part(stand, "LampLight", Vector3.one, nsAt * CFrame.new(-8, 138, -10), 0xFFFFFF, {
		collide = false,
		transparency = 1,
	})
	lamp:SetAttribute("LightRole", "Lamp")
	Kit.light(lamp, "PointLight", 0xFFA552, 2.4, 60, { Shadows = true })
	local clock = block(stand, "Clock", 22, 15, 12, nsAt, 16, 84, 18, 0xE04848)
	Kit.text(clock, "2:00", {
		face = Enum.NormalId.Right,
		color = rgb(0xFF4040),
		background = rgb(0x200808),
		font = Enum.Font.Code,
		pixelsPerStud = 10,
		glow = true,
	})
	local monitor = Kit.model(stand, "BabyMonitor")
	local mAt = CFrame.new(MapConfig.MONITOR) * CFrame.Angles(0, 1.2, 0)
	block(monitor, "Body", 14, 20, 7, mAt, 0, 0, 0, 0xF4F6FA)
	block(monitor, "Screen", 10, 7, 1, mAt, 0, 10, 3.6, 0x1A2A20)
	Kit.disc(monitor, "Antenna", 0.8, 14, mAt * CFrame.new(5, 27, 0), 0xB8BFC8, { material = Enum.Material.Metal })
	Kit.ball(monitor, "Led", 1.2, (mAt * CFrame.new(-4, 5, 3.8)).Position, 0x3DFF7A, {
		material = Enum.Material.Neon,
		collide = false,
	})
	for k = 1, 3 do
		local r = 2 + k * 2.2
		for _, s in { -1, 1 } do
			Kit.part(
				monitor,
				"Signal",
				Vector3.new(0.7, r * 0.9, 0.7),
				mAt * CFrame.new(5 + s * r * 0.55, 34 + r * 0.5, 0) * CFrame.Angles(0, 0, -s * 0.6),
				0x3DFF7A,
				{ material = Enum.Material.Neon, collide = false, transparency = 0.3 }
			)
		end
	end

	---------------------------------------------------------------------------------------------------------------
	-- Desk on the left wall in the creaky band, turned so its front faces the room, with the old computer
	local desk = Kit.model(furniture, "Desk")
	local dAt = CFrame.new(MapConfig.DESK.position) * CFrame.Angles(0, math.rad(MapConfig.DESK.turn), 0)
	local deskWood = 0xB7895C
	block(desk, "Top", 180, 9, 105, dAt, 0, 108, 0, deskWood, wood)
	block(desk, "TopBand", 182, 3, 107, dAt, 0, 105, 0, 0x8E6440, wood)
	for _, leg in { { -80, -44 }, { 80, -44 }, { -80, 44 }, { 80, 44 } } do
		block(desk, "Leg", 12, 105, 12, dAt, leg[1], 0, leg[2], 0xA27A4F, wood)
	end
	block(desk, "Drawers", 40, 58, 96, dAt, 60, 47, 0, 0xA27A4F, wood)
	block(desk, "Computer", 56, 46, 44, dAt, 0, 117, -22, 0xE8DEC8)
	local screen = block(desk, "Screen", 40, 30, 0.4, dAt, 0, 127, 0.1, 0x062A0E, { collide = false })
	local lines = Kit.text(screen, "> TINY TOY OS\n> 3 TOYS FOUND\n> ZZZ...\n> _", {
		face = Enum.NormalId.Back,
		color = rgb(0x6BFF7A),
		background = rgb(0x062A0E),
		font = Enum.Font.Code,
		pixelsPerStud = 12,
		glow = true,
		xAlign = Enum.TextXAlignment.Left,
	})
	lines.TextScaled = false
	lines.TextSize = 44
	lines.TextYAlignment = Enum.TextYAlignment.Top
	local glow = part(desk, "MonitorLight", Vector3.one, dAt * CFrame.new(0, 142, 18), 0xFFFFFF, {
		collide = false,
		transparency = 1,
	})
	glow:SetAttribute("LightRole", "Monitor")
	Kit.light(glow, "PointLight", 0x6BFF7A, 1, 40)
	block(desk, "Keyboard", 70, 4, 24, dAt, -4, 117, 32, 0xDCD2BC)
	local chairAt = dAt * CFrame.new(0, 0, 82) * CFrame.Angles(0, 0.2, 0)
	local chair = Kit.model(desk, "Chair")
	block(chair, "Seat", 66, 6, 66, chairAt, 0, 63, 0, 0xE04848)
	for _, leg in { { -27, -27 }, { 27, -27 }, { -27, 27 }, { 27, 27 } } do
		block(chair, "Leg", 8, 63, 8, chairAt, leg[1], 0, leg[2], 0x9C2F2F)
	end
	block(chair, "Back", 66, 64, 8, chairAt, 0, 69, 31, 0xE04848)

	---------------------------------------------------------------------------------------------------------------
	-- Window above the desk: warm streetlight between the slats of the blinds, stripes of it on the floor
	local window = Kit.model(furniture, "Window")
	local W = MapConfig.WINDOW
	local wz, wy = (W.z0 + W.z1) / 2, (W.y0 + W.y1) / 2
	local glass =
		part(window, "Light", Vector3.new(0.4, W.y1 - W.y0, W.z1 - W.z0), CFrame.new(HW - 0.3, wy, wz), 0xFFE6BC, {
			material = Enum.Material.Neon,
			collide = false,
		})
	glass:SetAttribute("LightRole", "Window")
	Kit.light(glass, "SurfaceLight", 0xFFD9A0, 1.4, 60, { Face = Enum.NormalId.Left, Angle = 75, Shadows = true })
	for y = W.y0 + 3, W.y1 - 1, 7.5 do
		part(window, "Slat", Vector3.new(2.2, 4.2, W.z1 - W.z0), CFrame.new(HW - 3, y + 2.1, wz), 0xF4EEE2, {
			shadow = false,
		})
	end
	local trim = 0xEDE6D6
	part(window, "Frame", Vector3.new(4, 10, W.z1 - W.z0 + 20), CFrame.new(HW - 2, W.y0 - 5, wz), trim)
	part(window, "Frame", Vector3.new(4, 10, W.z1 - W.z0 + 20), CFrame.new(HW - 2, W.y1 + 5, wz), trim)
	part(window, "Frame", Vector3.new(4, W.y1 - W.y0, 10), CFrame.new(HW - 2, wy, W.z0 - 5), trim)
	part(window, "Frame", Vector3.new(4, W.y1 - W.y0, 10), CFrame.new(HW - 2, wy, W.z1 + 5), trim)
	local floorStripes = Kit.folder(window, "FloorStripes")
	for y = W.y0 + 7, W.y1 - 2, 7.5 do
		local x = HW - 0.6 - y / 1.7
		local stripe = part(
			floorStripes,
			"Stripe",
			Vector3.new(1.8, 0.05, W.z1 - W.z0),
			CFrame.new(x, 0.26, wz + 0.035 * y),
			0xFFCF8A,
			{ material = Enum.Material.Neon, collide = false, transparency = 0.9 }
		)
		stripe:SetAttribute("LightRole", "WindowStripe")
	end

	-- Night-light in the outlet on the far wall, left of the door
	local nl = MapConfig.NIGHT_LIGHT
	part(furniture, "NightLightPlate", Vector3.new(16, 24, 2), CFrame.new(nl.X, 18, LEN - 1), 0xF4F1E8)
	local dome = Kit.ball(furniture, "NightLight", 6, Vector3.new(nl.X, nl.Y, LEN - 2.5), 0xFFE9A0, {
		material = Enum.Material.Neon,
		collide = false,
	})
	dome:SetAttribute("LightRole", "NightLight")
	Kit.light(dome, "PointLight", 0xFFD27A, 1.2, 36, { Shadows = true })

	return giant
end
