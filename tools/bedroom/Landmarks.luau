--!strict
-- Landmarks on the run: the block tower (four letter blocks you can climb by a spiral of toy-brick steps, a lookout on
-- top), the fallen letter block by the right-hand wall, the wooden train track (a winding loop that crosses the run
-- twice) and the 5-car train. Game code moves the train along MapConfig.trackPath(); here it sits where it is at t = 0.

local BRICK_COLORS = { 0xE04848, 0xFFC93C, 0x4DA8FF, 0x3DDC97, 0xFF7AA8 }

-- A letter on every side of a block: a white inset frame and the letter in white on the block's colour
local function letterFaces(block: BasePart, letter: string)
	for _, normal in { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = normal
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 8
		gui.MaxDistance = 1500
		gui.Parent = block
		local frame = Instance.new("Frame")
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.Position = UDim2.fromScale(0.5, 0.5)
		frame.Size = UDim2.fromScale(0.82, 0.82)
		frame.BackgroundTransparency = 1
		frame.Parent = gui
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.new(1, 1, 1)
		stroke.Thickness = 10
		stroke.Transparency = 0.1
		stroke.Parent = frame
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(0.8, 0.8)
		text.Position = UDim2.fromScale(0.1, 0.1)
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.FredokaOne
		text.Text = letter
		text.TextScaled = true
		text.TextColor3 = Color3.new(1, 1, 1)
		text.Parent = frame
	end
end

return function(Kit: any, MapConfig: any, bedroom: Model)
	local part, block = Kit.part, Kit.block
	local landmarks = Kit.folder(bedroom, "Landmarks")

	---------------------------------------------------------------------------------------------------------------
	-- The block tower on the left side of the carpet band
	local tower = Kit.model(landmarks, "Tower")
	local T = MapConfig.TOWER
	local B = MapConfig.TOWER_BLOCK
	local blocks = {
		{ "A", 0xE04848, 0, 0, 0.1 },
		{ "B", 0x4DA8FF, 1.5, -1, -0.06 },
		{ "C", 0xFFC93C, -1, 1.5, 0.1 },
		{ "D", 0x3DDC97, 1.5, 0, -0.04 },
	}
	for k, b in blocks do
		local at = CFrame.new(T + Vector3.new(b[3], (k - 1) * B, b[4])) * CFrame.Angles(0, b[5], 0)
		local p = block(tower, "Block" .. b[1], B, B, B, at, 0, 0, 0, b[2], { material = Enum.Material.SmoothPlastic })
		letterFaces(p, b[1])
		if k == #blocks then
			-- studs on the lookout
			for ix = -2, 2 do
				for iz = -2, 2 do
					Kit.disc(tower, "Stud", 2, 1.2, at * CFrame.new(ix * 5.6, B + 0.6, iz * 5.6), b[2], {
						material = Enum.Material.Plastic,
						collide = false,
					})
				end
			end
		end
	end
	-- the spiral of toy-brick steps, each an easy hop above the last
	local steps = MapConfig.TOWER_STEPS
	for k = 1, steps.count do
		local angle = math.rad(steps.firstAngle + (k - 1) * steps.angleStep)
		local top = k * steps.rise - 0.05
		local centre = T + Vector3.new(math.cos(angle) * steps.radius, top - 2, math.sin(angle) * steps.radius)
		local along = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local at = CFrame.lookAt(centre, centre + along) -- the step's long side runs out from the tower
		local color = BRICK_COLORS[(k - 1) % #BRICK_COLORS + 1]
		part(tower, "Step", Vector3.new(13, 4, 22), at, color, { material = Enum.Material.Plastic })
		for _, s in { { -3.2, -5 }, { 3.2, -5 }, { -3.2, 5 }, { 3.2, 5 } } do
			Kit.disc(tower, "Stud", 1.6, 0.8, at * CFrame.new(s[1], 2.4, s[2]), color, {
				material = Enum.Material.Plastic,
				collide = false,
			})
		end
	end

	-- the fallen block by the right-hand wall: a hiding spot
	local fb = MapConfig.FALLEN_BLOCK
	local fallen = block(
		landmarks,
		"FallenBlock",
		B,
		B,
		B,
		CFrame.new(fb.position) * CFrame.Angles(0, fb.turn, 0),
		0,
		0,
		0,
		0x9246D4,
		{ material = Enum.Material.SmoothPlastic }
	)
	letterFaces(fallen, "E")

	---------------------------------------------------------------------------------------------------------------
	-- The track: straight pieces fitted to the curve (each as long as the curve allows within a fraction of a stud),
	-- a wooden bed with two dark grooves. It's 1.6 tall, so you step over it.
	local train = Kit.model(bedroom, "Train")
	local track = Kit.folder(train, "Track")
	local points = MapConfig.trackPoints(2)
	local n = #points
	local wide, tall = MapConfig.TRACK_WIDTH, MapConfig.TRACK_HEIGHT
	local pieces = 0
	local function wrap(k: number): Vector3
		return points[(k - 1) % n + 1]
	end
	local i = 1
	while i <= n do
		-- grow the piece from point i to point e while every point between stays within 0.25 of the chord
		local e = i + 1
		while e - i < 20 and e <= n do
			local a, b = points[i], wrap(e + 1)
			local along = (b - a).Unit
			local ok = true
			for k = i + 1, e do
				local p = wrap(k)
				if ((p - a) - along * (p - a):Dot(along)).Magnitude > 0.25 then
					ok = false
					break
				end
			end
			if not ok then
				break
			end
			e += 1
		end
		local a, b = points[i], wrap(e)
		local length = (b - a).Magnitude + 1.2 -- a little overlap hides the joints on the bends
		local at = CFrame.lookAt((a + b) / 2, b)
		part(track, "Bed", Vector3.new(wide, tall, length), at * CFrame.new(0, tall / 2, 0), 0xD2A86E, {
			shadow = false,
		})
		for _, o in { -2.4, 2.4 } do
			part(track, "Groove", Vector3.new(1, 0.25, length), at * CFrame.new(o, tall + 0.12, 0), 0x8A6236, {
				collide = false,
			})
		end
		pieces += 1
		i = e
	end

	-- The train: an engine and four wagons, the render's toy train scaled up
	local cars = Kit.folder(train, "Cars")
	local path = MapConfig.trackPath()
	local SC = MapConfig.TRAIN_SCALE
	local carColors = { 0xE04848, 0x4DA8FF, 0x3DDC97, 0xFFC93C, 0x9B7BFF }
	for k = 1, MapConfig.TRAIN_CARS do
		local car = Kit.model(cars, "Car" .. k, { Car = k })
		local position, direction = MapConfig.trackPose(path, MapConfig.trainCarDistance(0, k))
		-- local +X is forward along the track
		local at = CFrame.lookAt(position + Vector3.new(0, tall, 0), position + Vector3.new(0, tall, 0) + direction)
			* CFrame.Angles(0, math.pi / 2, 0)
		local function box(
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
			return block(
				car,
				name,
				w * SC,
				h * SC,
				d * SC,
				at,
				x * SC,
				y * SC,
				z * SC,
				color,
				options or { collide = false }
			)
		end
		local root = part(car, "Root", Vector3.new(18 * SC, 1, 10 * SC), at * CFrame.new(0, 0.5, 0), 0xFFFFFF, {
			collide = false,
			transparency = 1,
		})
		car.PrimaryPart = root
		local c = carColors[k]
		box("Body", 18, 6, 10, 0, 3, 0, c, { collide = false, material = Enum.Material.Plastic })
		for _, x in { -6, 6 } do
			for _, z in { -5.4, 5.4 } do
				Kit.part(
					car,
					"Wheel",
					Vector3.new(1.4 * SC, 4.8 * SC, 4.8 * SC),
					at * CFrame.new(x * SC, 2.8 * SC, z * SC) * CFrame.Angles(0, math.pi / 2, 0),
					0x1A1430,
					{ collide = false, shape = Enum.PartType.Cylinder }
				)
			end
		end
		if k == 1 then
			box("Cab", 7, 10, 10, -5, 9, 0, c, { collide = false, material = Enum.Material.Plastic })
			box("Roof", 8, 2, 11, -5, 19, 0, 0x1A1430)
			Kit.disc(
				car,
				"Chimney",
				2.2 * SC,
				6 * SC,
				at * CFrame.new(5 * SC, 12 * SC, 0),
				0x1A1430,
				{ collide = false }
			)
			local lamp = box("Lamp", 2, 4, 6, 9.5, 5, 0, 0xFFC93C, { collide = false, material = Enum.Material.Neon })
			Kit.light(lamp, "SpotLight", 0xFFE6A0, 2, 50, { Face = Enum.NormalId.Right, Angle = 50 })
		else
			local cargo = { 0xFFC93C, 0xFF7AA8, 0x4DA8FF, 0x3DDC97 }
			local small = { 0x9246D4, 0xFFC93C, 0xE04848, 0xFF7AA8 }
			box("Cargo", 8, 8, 8, -3, 9, 0, cargo[k - 1], { collide = false, material = Enum.Material.Plastic })
			box("Cargo", 6, 6, 6, 4, 9, 0, small[k - 1], { collide = false, material = Enum.Material.Plastic })
		end
	end

	return { trackPieces = pieces }
end
