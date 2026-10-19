--!strict
-- Part helpers for the bedroom builder (tools/build-bedroom.luau) and the game code that rebuilds bits of the map at
-- runtime (a home's level dressing and Speed wheel). Everything is anchored; small parts don't cast shadows.

local Kit = {}

function Kit.rgb(hex: number): Color3
	return Color3.fromRGB(bit32.rshift(hex, 16), bit32.band(bit32.rshift(hex, 8), 255), bit32.band(hex, 255))
end

-- Yield every so often so a long build doesn't freeze Studio. Off at runtime (rebuilds are small).
Kit.yieldEvery = 150
local count = 0
function Kit.batch()
	count += 1
	if Kit.yieldEvery > 0 and count % Kit.yieldEvery == 0 then
		task.wait()
	end
end

export type PartOptions = {
	material: Enum.Material?,
	variant: string?, -- a MaterialVariant name (MaterialService)
	shape: Enum.PartType?,
	collide: boolean?, -- false: no collisions, queries or touches
	query: boolean?, -- false: still solid, but raycasts pass through
	transparency: number?,
	reflectance: number?,
	shadow: boolean?,
	attributes: { [string]: any }?,
	class: string?, -- "Part" (default), "WedgePart" or "CornerWedgePart"
}

function Kit.part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3 | number,
	options: PartOptions?
): BasePart
	local opts: PartOptions = options or {}
	local p = Instance.new((opts.class or "Part") :: any) :: BasePart
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = if typeof(color) == "number" then Kit.rgb(color) else color
	p.Material = opts.material or Enum.Material.SmoothPlastic
	if opts.variant then
		p.MaterialVariant = opts.variant
	end
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if opts.shape and p:IsA("Part") then
		p.Shape = opts.shape
	end
	if opts.collide == false then
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
	elseif opts.query == false then
		p.CanQuery = false
	end
	if opts.transparency then
		p.Transparency = opts.transparency
	end
	if opts.reflectance then
		p.Reflectance = opts.reflectance
	end
	-- thin or small parts don't need shadows (and they cost the most)
	local smallest = math.min(size.X, size.Y, size.Z)
	local largest = math.max(size.X, size.Y, size.Z)
	if opts.shadow == false or (opts.shadow == nil and (largest < 6 or smallest < 0.5)) then
		p.CastShadow = false
	end
	for key, value in opts.attributes or {} do
		p:SetAttribute(key, value)
	end
	p.Parent = parent
	Kit.batch()
	return p
end

-- A box of size (w, h, d) whose BOTTOM is at y in the frame `at` (x, z are the box's centre).
function Kit.block(
	parent: Instance,
	name: string,
	w: number,
	h: number,
	d: number,
	at: CFrame,
	x: number,
	y: number,
	z: number,
	color: Color3 | number,
	options: PartOptions?
): BasePart
	return Kit.part(parent, name, Vector3.new(w, h, d), at * CFrame.new(x, y + h / 2, z), color, options)
end

-- An upright cylinder (Roblox cylinders run along X, so turn it to stand on Y), centred at cf.
function Kit.disc(
	parent: Instance,
	name: string,
	radius: number,
	height: number,
	cf: CFrame,
	color: Color3 | number,
	options: PartOptions?
): BasePart
	local opts: PartOptions = table.clone(options or {})
	opts.shape = Enum.PartType.Cylinder
	return Kit.part(
		parent,
		name,
		Vector3.new(height, radius * 2, radius * 2),
		cf * CFrame.Angles(0, 0, math.pi / 2),
		color,
		opts
	)
end

-- A cylinder from a to b (a cable, a bar, a rung).
function Kit.rod(
	parent: Instance,
	name: string,
	a: Vector3,
	b: Vector3,
	radius: number,
	color: Color3 | number,
	options: PartOptions?
): BasePart
	local opts: PartOptions = table.clone(options or {})
	opts.shape = Enum.PartType.Cylinder
	local length = (b - a).Magnitude
	local cf = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.pi / 2, 0)
	return Kit.part(parent, name, Vector3.new(length, radius * 2, radius * 2), cf, color, opts)
end

function Kit.ball(
	parent: Instance,
	name: string,
	radius: number,
	position: Vector3,
	color: Color3 | number,
	options: PartOptions?
): BasePart
	local opts: PartOptions = table.clone(options or {})
	opts.shape = Enum.PartType.Ball
	return Kit.part(parent, name, Vector3.one * radius * 2, CFrame.new(position), color, opts)
end

function Kit.folder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

function Kit.model(parent: Instance, name: string, attributes: { [string]: any }?): Model
	local m = Instance.new("Model")
	m.Name = name
	for key, value in attributes or {} do
		m:SetAttribute(key, value)
	end
	m.Parent = parent
	return m
end

export type TextOptions = {
	face: Enum.NormalId?,
	color: Color3?,
	background: Color3?,
	backgroundTransparency: number?,
	stroke: Color3?,
	font: Enum.Font?,
	pixelsPerStud: number?,
	glow: boolean?, -- ignore the lighting, so it reads at night
	xAlign: Enum.TextXAlignment?,
	rotation: number?,
}

-- Text on one face of a part, filling it.
function Kit.text(part: BasePart, text: string, options: TextOptions?): TextLabel
	local opts: TextOptions = options or {}
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Text"
	gui.Face = opts.face or Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = opts.pixelsPerStud or 20
	gui.LightInfluence = if opts.glow then 0 else 1
	gui.Brightness = if opts.glow then 1.2 else 1
	gui.MaxDistance = 1000
	gui.Parent = part
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundColor3 = opts.background or Color3.new(0, 0, 0)
	t.BackgroundTransparency = if opts.background then (opts.backgroundTransparency or 0) else 1
	t.BorderSizePixel = 0
	t.TextColor3 = opts.color or Color3.new(1, 1, 1)
	t.TextScaled = true
	t.Font = opts.font or Enum.Font.GothamBlack
	t.TextXAlignment = opts.xAlign or Enum.TextXAlignment.Center
	t.Rotation = opts.rotation or 0
	t.Text = text
	if opts.stroke then
		local s = Instance.new("UIStroke")
		s.Color = opts.stroke
		s.Thickness = 3
		s.Parent = t
	end
	t.Parent = gui
	return t
end

function Kit.light(
	parent: Instance,
	class: string,
	color: Color3 | number,
	brightness: number,
	range: number,
	extra: { [string]: any }?
): Light
	local l = Instance.new(class :: any) :: Light
	l.Color = if typeof(color) == "number" then Kit.rgb(color) else color
	l.Brightness = brightness;
	(l :: any).Range = math.min(range, 60)
	for key, value in extra or {} do
		(l :: any)[key] = value
	end
	l.Parent = parent
	return l
end

-- A solid prism `height` tall standing on the floor triangle a, b, c (y ignored), from two right-angled WedgeParts
-- (the usual split at the foot of the altitude onto the longest side).
local function triangle(
	parent: Instance,
	name: string,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	y0: number,
	height: number,
	color: Color3 | number,
	options: PartOptions?
)
	a, b, c = Vector3.new(a.X, 0, a.Z), Vector3.new(b.X, 0, b.Z), Vector3.new(c.X, 0, c.Z)
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local normal = ac:Cross(ab)
	if normal.Magnitude < 1e-6 then
		return
	end
	local right = normal.Unit -- straight up or down: the wedges' thickness axis
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local across = math.abs(ab:Dot(up))
	local lift = Vector3.new(0, y0 + height / 2, 0)
	local opts: PartOptions = table.clone(options or {})
	opts.class = "WedgePart"
	local d1, d2 = math.abs(ab:Dot(back)), math.abs(ac:Dot(back))
	if across > 0.05 and d1 > 0.05 then
		Kit.part(
			parent,
			name,
			Vector3.new(height, across, d1),
			CFrame.fromMatrix((a + b) / 2 + lift, right, up, back),
			color,
			opts
		)
	end
	if across > 0.05 and d2 > 0.05 then
		Kit.part(
			parent,
			name,
			Vector3.new(height, across, d2),
			CFrame.fromMatrix((a + c) / 2 + lift, -right, up, -back),
			color,
			opts
		)
	end
end

-- A wall standing on the floor over the quad a, b, c, d (corners in order). Exact outline, any shape of quad.
function Kit.quadWall(
	parent: Instance,
	name: string,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	d: Vector3,
	y0: number,
	height: number,
	color: Color3 | number,
	options: PartOptions?
)
	triangle(parent, name, a, b, c, y0, height, color, options)
	triangle(parent, name, a, c, d, y0, height, color, options)
end

return Kit
