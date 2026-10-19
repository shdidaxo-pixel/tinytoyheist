--!strict
-- Builds a voxel toy Model from its data in Sets/*.luau (format: tools/toys/README.md). The review page
-- (design/toy-turntables.html) does the same expansion in JavaScript, so keep the two in step.
--
-- A built toy:
--   Model <Id>                PrimaryPart = Root; pivot at the centre of its feet, on the floor; faces -Z (LookVector)
--     Root                    invisible anchored hitbox the size of the toy (CanQuery on, for grabbing)
--     Rig (Folder)            one tiny invisible part per group ("Body", "Head", ...), each with a Motor6D "Joint"
--                             to its parent group (Body's joint goes to Root). ToyAnimator drives Joint.Transform.
--     Blocks (Folder)         the coloured boxes, each welded to its group's rig part
--     Fx (Folder)             the toy's own particles (Fx presets) on attachments
-- Attributes on the Model: ToyId, ToyName, Set, Rarity, Money, Size, VoxelScale (studs per voxel unit), Height.
-- Blocks have a "Group" attribute; rig parts have "ParentGroup".
local CollectionService = game:GetService("CollectionService")

local ToyPalette = require(script.Parent.ToyPalette)

local ToyBuilder = {}

-- Studs for each size class: the toy's height, or 0.75 of its length if that's bigger. A player is 5 studs.
ToyBuilder.SIZE_TARGET = { S = 8, M = 12, L = 17, G = 25 } :: { [string]: number }

-- Built-in Roblox particle textures (they ship with every client, so they work on phones and need no upload).
ToyBuilder.TEXTURES = {
	Smoke = "rbxasset://textures/particles/smoke_main.dds",
	Sparkle = "rbxasset://textures/particles/sparkles_main.dds",
	Fire = "rbxasset://textures/particles/fire_main.dds",
	Ring = "rbxasset://textures/particles/explosion01_shockwave_main.dds",
	Square = "rbxasset://textures/particles/SquareParticle.png",
	Glow = "rbxasset://textures/particles/forcefield_glow_main.dds",
	Snow = "rbxasset://textures/particles/sparkles_main.dds",
} :: { [string]: string }

export type Box = {
	x: number,
	y: number,
	z: number,
	w: number,
	h: number,
	d: number,
	color: Color3,
	flags: string,
	rot: { number }?,
}
export type Node = { name: string, pivot: { number }, boxes: { Box }, children: { Node } }
export type Shape = {
	root: Node,
	byName: { [string]: Node },
	count: number,
	scale: number,
	size: Vector3, -- studs, authoring axes (x = length, z = width)
}

local function colorOf(c: any, id: string): Color3
	if type(c) == "string" then
		if string.sub(c, 1, 1) == "#" then
			return Color3.fromHex(c)
		end
		local hex = ToyPalette.Colors[c]
		if hex then
			return Color3.fromHex(hex)
		end
	end
	warn(`ToyBuilder: {id} uses an unknown colour {tostring(c)}`)
	return Color3.fromRGB(255, 0, 255)
end

local function expand(parts: { any }, slots: { [string]: any }?, node: Node, byName: { [string]: Node }, id: string)
	for _, p in parts do
		if p[1] ~= nil then
			local col: any, flags: string = p[7], p[8] or ""
			if type(col) == "string" and string.sub(col, 1, 1) == "$" then
				local v = slots and slots[string.sub(col, 2)]
				if type(v) == "table" then
					col = v[1]
					flags ..= (v[2] or "")
				else
					col = v
				end
			end
			local box: Box = {
				x = p[1],
				y = p[2],
				z = p[3],
				w = p[4],
				h = p[5],
				d = p[6],
				color = colorOf(col, id),
				flags = flags,
				rot = p[9],
			}
			table.insert(node.boxes, box)
			if string.find(flags, "m", 1, true) then
				local rot = box.rot
				table.insert(node.boxes, {
					x = box.x,
					y = box.y,
					z = -(box.z + box.d),
					w = box.w,
					h = box.h,
					d = box.d,
					color = box.color,
					flags = flags,
					rot = rot and { -rot[1], -rot[2], rot[3] } or nil,
				})
			end
		elseif p.Kit then
			local kit = ToyPalette.Kits[p.Kit]
			if kit then
				expand(kit, p.Colors, node, byName, id)
			else
				warn(`ToyBuilder: {id} uses an unknown kit {p.Kit}`)
			end
		elseif p.Group then
			local g = byName[p.Group]
			if not g then
				g = { name = p.Group, pivot = p.Pivot or { 0, 0, 0 }, boxes = {}, children = {} }
				table.insert(node.children, g)
				byName[p.Group] = g
			end
			expand(p.Parts or {}, slots, g, byName, id)
		end
	end
end

-- Expand a toy's parts into a tree of groups and work out its scale. Pure maths, no instances.
function ToyBuilder.shape(toy: any): Shape
	local root: Node = { name = "Body", pivot = { 0, 0, 0 }, boxes = {}, children = {} }
	local byName = { Body = root }
	expand(toy.Parts or {}, nil, root, byName, toy.Id)
	local mn = { math.huge, math.huge, math.huge }
	local mx = { -math.huge, -math.huge, -math.huge }
	local count = 0
	local function walk(n: Node)
		for _, b in n.boxes do
			count += 1
			local lo, hi = { b.x, b.y, b.z }, { b.x + b.w, b.y + b.h, b.z + b.d }
			for i = 1, 3 do
				mn[i] = math.min(mn[i], lo[i])
				mx[i] = math.max(mx[i], hi[i])
			end
		end
		for _, c in n.children do
			walk(c)
		end
	end
	walk(root)
	local w, h, d = mx[1] - mn[1], mx[2] - mn[2], mx[3] - mn[3]
	local metric = math.max(h, 0.75 * math.max(w, d))
	local scale = (ToyBuilder.SIZE_TARGET[toy.Size] or 12) / metric
	root.pivot = { (mn[1] + mx[1]) / 2, mn[2], (mn[3] + mx[3]) / 2 }
	return { root = root, byName = byName, count = count, scale = scale, size = Vector3.new(w, h, d) * scale }
end

local function material(flags: string): (Enum.Material, number, number)
	-- material, transparency, reflectance
	if string.find(flags, "N", 1, true) then
		return Enum.Material.Neon, 0, 0
	elseif string.find(flags, "G", 1, true) then
		return Enum.Material.Glass, 0.45, 0.1
	elseif string.find(flags, "M", 1, true) then
		return Enum.Material.SmoothPlastic, 0, 0.3
	elseif string.find(flags, "F", 1, true) then
		return Enum.Material.Fabric, 0, 0
	end
	return Enum.Material.SmoothPlastic, 0, 0
end

local function invisiblePart(name: string, size: Vector3, cf: CFrame): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Transparency = 1
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Massless = true
	p.Anchored = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

local function seq(points: { { number } }): NumberSequence
	local kps = {}
	for _, k in points do
		table.insert(kps, NumberSequenceKeypoint.new(k[1], k[2], k[3] or 0))
	end
	return NumberSequence.new(kps)
end
ToyBuilder.seq = seq

local function colorSeq(colors: { any }): ColorSequence
	if #colors == 1 then
		return ColorSequence.new(colorOf(colors[1], "fx"))
	end
	local kps = {}
	for i, c in colors do
		table.insert(kps, ColorSequenceKeypoint.new((i - 1) / (#colors - 1), colorOf(c, "fx")))
	end
	return ColorSequence.new(kps)
end
ToyBuilder.colorSeq = colorSeq

-- A ParticleEmitter from a preset table (ToyPalette.Fx format). unit = studs per "tenth of the toy's height".
function ToyBuilder.emitter(preset: any, unit: number, rate: number?): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = "Emitter"
	e.Texture = ToyBuilder.TEXTURES[preset.Texture] or ToyBuilder.TEXTURES.Sparkle
	e.Color = colorSeq(preset.Colors)
	e.Rate = rate or preset.Rate
	e.Lifetime = NumberRange.new(preset.Life * 0.75, preset.Life * 1.25)
	local a, b = preset.Size[1] * unit, preset.Size[2] * unit
	local mid, env = (a + b) / 2, (b - a) / 2
	local grow = 1 + (preset.Grow or 0)
	local fade = preset.Fade or "InOut"
	if fade == "Twinkle" then
		e.Size = seq({ { 0, 0 }, { 0.5, mid, env }, { 1, 0 } })
	else
		e.Size = seq({ { 0, mid, env }, { 1, math.max(0, mid * grow), env } })
	end
	local alpha = 1 - (preset.Alpha or 1)
	if fade == "Twinkle" then
		e.Transparency = seq({ { 0, 1 }, { 0.5, alpha }, { 1, 1 } })
	elseif fade == "Out" then
		e.Transparency = seq({ { 0, alpha }, { 1, 1 } })
	elseif fade == "In" then
		e.Transparency = seq({ { 0, 1 }, { 1, alpha } })
	else
		e.Transparency = seq({ { 0, 1 }, { 0.2, alpha }, { 0.6, alpha }, { 1, 1 } })
	end
	local v = Vector3.new(table.unpack(preset.Velocity or { 0, 0, 0 })) * unit
	local spread = (preset.Spread or 0) * unit
	local speed = v.Magnitude
	if speed < 1e-3 then
		e.Speed = NumberRange.new(0, spread * 0.5)
		e.SpreadAngle = Vector2.new(180, 180)
	else
		e.Speed = NumberRange.new(speed * 0.85, speed * 1.15)
		local ang = math.deg(math.atan(spread / speed))
		e.SpreadAngle = Vector2.new(ang, ang)
	end
	e.EmissionDirection = Enum.NormalId.Top
	e.Acceleration = Vector3.new(0, (preset.Accel or 0) * unit, 0)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-60, 60)
	e.LightEmission = preset.Glow and 1 or 0
	e.LightInfluence = preset.Glow and 0 or 1
	return e
end

-- An attachment whose +Y points along dir (EmissionDirection Top), at pos in the parent part's space.
function ToyBuilder.aim(pos: Vector3, dir: Vector3): CFrame
	if dir.Magnitude < 1e-3 then
		return CFrame.new(pos)
	end
	local up = dir.Unit
	local right = up:Cross(Vector3.zAxis)
	if right.Magnitude < 1e-3 then
		right = up:Cross(Vector3.xAxis)
	end
	right = right.Unit
	return CFrame.fromMatrix(pos, right, up)
end

-- Build one toy. Returns a Model at the origin (feet on y = 0, facing -Z), not parented.
function ToyBuilder.build(toy: any): Model
	local shape = ToyBuilder.shape(toy)
	local s = shape.scale
	local rootPivot = shape.root.pivot
	local function world(x: number, y: number, z: number): Vector3
		-- voxel units -> studs, with the feet at the origin, still facing +X (turned at the end)
		return Vector3.new((x - rootPivot[1]) * s, (y - rootPivot[2]) * s, (z - rootPivot[3]) * s)
	end

	local model = Instance.new("Model")
	model.Name = toy.Id
	local size = shape.size
	local root = invisiblePart(
		"Root",
		Vector3.new(size.Z, size.Y, size.X),
		CFrame.new(0, size.Y / 2, 0) * CFrame.Angles(0, -math.pi / 2, 0)
	)
	root.Anchored = true
	root.CanQuery = true
	root.PivotOffset = CFrame.new(0, -size.Y / 2, 0)
	root.Parent = model
	model.PrimaryPart = root

	local rig = Instance.new("Folder")
	rig.Name = "Rig"
	rig.Parent = model
	local blocks = Instance.new("Folder")
	blocks.Name = "Blocks"
	blocks.Parent = model
	local pivots: { [string]: BasePart } = {}
	local unit = size.Y / 10

	local function make(node: Node, parentPart: BasePart, parentName: string?)
		local pv = node.pivot
		local pivot = invisiblePart(node.name, Vector3.one * 0.05, CFrame.new(world(pv[1], pv[2], pv[3])))
		pivot:SetAttribute("ParentGroup", parentName)
		pivot.Parent = rig
		pivots[node.name] = pivot
		local joint = Instance.new("Motor6D")
		joint.Name = "Joint"
		joint.Part0 = parentPart
		joint.Part1 = pivot
		joint.C0 = parentPart.CFrame:ToObjectSpace(pivot.CFrame)
		joint.C1 = CFrame.identity
		joint.Parent = pivot
		for _, b in node.boxes do
			local p = Instance.new("Part")
			p.Name = "Block"
			p.Size = Vector3.new(math.max(0.05, b.w * s), math.max(0.05, b.h * s), math.max(0.05, b.d * s))
			local cf = CFrame.new(world(b.x + b.w / 2, b.y + b.h / 2, b.z + b.d / 2))
			if b.rot then
				cf *= CFrame.Angles(math.rad(b.rot[1]), math.rad(b.rot[2]), math.rad(b.rot[3]))
			end
			p.CFrame = cf
			p.Color = b.color
			local mat, tr, refl = material(b.flags)
			p.Material = mat
			p.Transparency = tr
			p.Reflectance = refl
			p.TopSurface = Enum.SurfaceType.Smooth
			p.BottomSurface = Enum.SurfaceType.Smooth
			p.CanCollide = false
			p.CanTouch = false
			p.CanQuery = false
			p.Massless = true
			p.Anchored = false
			p.CastShadow = math.min(p.Size.X, p.Size.Y, p.Size.Z) > 0.3 and p.Size.Magnitude > 1.5
			p:SetAttribute("Group", node.name)
			local weld = Instance.new("Weld")
			weld.Part0 = pivot
			weld.Part1 = p
			weld.C0 = pivot.CFrame:ToObjectSpace(cf)
			weld.Parent = p
			p.Parent = blocks
		end
		for _, c in node.children do
			make(c, pivot, node.name)
		end
	end
	make(shape.root, root, nil)

	-- the toy's own particles
	if toy.Fx and #toy.Fx > 0 then
		local fx = Instance.new("Folder")
		fx.Name = "Fx"
		fx.Parent = model
		for i, f in toy.Fx do
			local preset = ToyPalette.Fx[f[1]]
			local pivot = pivots[f[3] or "Body"] or pivots.Body
			if preset and pivot then
				local pt = world(f[2][1], f[2][2], f[2][3])
				local att = Instance.new("Attachment")
				att.Name = `Fx{i}_{f[1]}`
				att.CFrame = ToyBuilder.aim(
					pivot.CFrame:PointToObjectSpace(pt),
					Vector3.new(table.unpack(preset.Velocity or { 0, 1, 0 }))
				)
				att.Parent = pivot
				local e = ToyBuilder.emitter(preset, unit, f[4])
				e.Parent = att
				local ref = Instance.new("ObjectValue")
				ref.Name = att.Name
				ref.Value = att
				ref.Parent = fx
			end
		end
	end

	model:SetAttribute("ToyId", toy.Id)
	model:SetAttribute("ToyName", toy.Name)
	model:SetAttribute("Set", toy.Set)
	model:SetAttribute("Rarity", toy.Rarity)
	model:SetAttribute("Money", toy.Money)
	model:SetAttribute("Size", toy.Size)
	model:SetAttribute("VoxelScale", s)
	model:SetAttribute("Height", size.Y)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	CollectionService:AddTag(model, "TinyToy")
	-- turn it so the toy's front (+X while building) is the model's front (-Z)
	model:PivotTo(CFrame.identity)
	return model
end

return ToyBuilder
