--!strict
-- Mutations: rolled once at wake-up, one per toy. They multiply money and change the toy's look.
--   Mutations.roll(rng?, events?, luck?) -> a mutation id, or nil for none.
--                                          events: which events are on, e.g. { NightmareNight = true }.
--   Mutations.multiplier(id)            -> money multiplier (1 for none).
--   Mutations.apply(model, id)          -> recolour the toy and add its effect (server or client). Replaces any
--                                          mutation it already had; sets the model's "Mutation" attribute.
--   Mutations.remove(model)             -> back to plain.
--   Mutations.animate(model)            -> client (ToyAnimator calls it): the moving part of the look, if any, as
--                                          (effect(t, dt)?, lift(t)?) where lift raises the toy, in studs.
-- Chances, multipliers and descriptions are in MutationData.luau. Looks are simple but known at a glance.
local MutationData = require(script.Parent.MutationData)
local ToyBuilder = require(script.Parent.ToyBuilder)
local ToyVFX = require(script.Parent.ToyVFX)

local Mutations = {}
Mutations.Data = MutationData

local TEX = ToyBuilder.TEXTURES
local seq = ToyBuilder.seq

-- rarest first, so a roll lands on the rare ones before the common ones
local BY_RARITY = table.clone(MutationData.Order)
table.sort(BY_RARITY, function(a, b)
	return MutationData.List[a].Chance < MutationData.List[b].Chance
end)

function Mutations.roll(rng: Random?, events: { [string]: boolean }?, luck: number?): string?
	local r = (rng or Random.new()):NextNumber()
	local acc = 0
	for _, id in BY_RARITY do
		local m = MutationData.List[id]
		if m.Event == nil or (events and events[m.Event]) then
			acc += m.Chance * (luck or 1)
			if r < acc then
				return id
			end
		end
	end
	return nil
end

function Mutations.multiplier(id: string?): number
	local m = id and MutationData.List[id]
	return m and m.Multiplier or 1
end

------------------------------------------------------------------------------------------------------------------
-- helpers

local function blocksOf(model: Model): { BasePart }
	local f = model:FindFirstChild("Blocks")
	local out = {}
	if f then
		for _, p in f:GetChildren() do
			if p:IsA("BasePart") then
				table.insert(out, p)
			end
		end
	end
	return out
end

-- Remember each block's own look the first time it's mutated, so remove() can put it back.
local function remember(p: BasePart)
	if p:GetAttribute("BaseColor") == nil then
		p:SetAttribute("BaseColor", p.Color)
		p:SetAttribute("BaseMaterial", p.Material.Name)
		p:SetAttribute("BaseTransparency", p.Transparency)
		p:SetAttribute("BaseReflectance", p.Reflectance)
	end
end

local function restore(p: BasePart)
	local c = p:GetAttribute("BaseColor")
	if typeof(c) == "Color3" then
		p.Color = c
		local m = p:GetAttribute("BaseMaterial")
		if type(m) == "string" then
			p.Material = (Enum.Material :: any)[m]
		end
		p.Transparency = p:GetAttribute("BaseTransparency") :: number
		p.Reflectance = p:GetAttribute("BaseReflectance") :: number
	end
end

local function lum(c: Color3): number
	return 0.299 * c.R + 0.587 * c.G + 0.114 * c.B
end
local function isDark(c: Color3): boolean
	return lum(c) < 0.13
end
local function hex(h: string): Color3
	return Color3.fromHex(h)
end

local function heightOf(model: Model): number
	local h = model:GetAttribute("Height")
	return (type(h) == "number" and h or 10) * model:GetScale()
end

-- block centre relative to the toy's feet, in studs, in the model's own axes
local function localPos(model: Model, p: BasePart): Vector3
	return model:GetPivot():PointToObjectSpace(p.Position)
end

type Ctx = { model: Model, root: BasePart, folder: Folder, H: number, unit: number, blocks: { BasePart } }

-- An emitter on the Root: Shape Box makes it emit from the toy's box (Surface) or inside it (Volume).
local function rootEmitter(ctx: Ctx, name: string, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	e.Rotation = NumberRange.new(0, 360)
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = ctx.root
	local ref = Instance.new("ObjectValue")
	ref.Name = name
	ref.Value = e
	ref.Parent = ctx.folder
	return e
end

local function twinkle(size: number): NumberSequence
	return seq({ { 0, 0 }, { 0.5, size, size * 0.3 }, { 1, 0 } })
end
local TWINKLE_T = seq({ { 0, 1 }, { 0.5, 0 }, { 1, 1 } })

local function rootLight(ctx: Ctx, color: Color3, brightness: number)
	local l = Instance.new("PointLight")
	l.Name = "MutationLight"
	l.Color = color
	l.Brightness = brightness
	l.Range = math.min(60, ctx.H * 2.4)
	l.Shadows = false
	l.Parent = ctx.root
	local ref = Instance.new("ObjectValue")
	ref.Name = "MutationLight"
	ref.Value = l
	ref.Parent = ctx.folder
end

-- A part welded to a rig part (Body follows the idle animation; Root doesn't).
local function fxPart(ctx: Ctx, name: string, attachTo: BasePart, cf: CFrame, size: Vector3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Massless = true
	p.Anchored = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	local w = Instance.new("Weld")
	w.Part0 = attachTo
	w.Part1 = p
	w.C0 = attachTo.CFrame:ToObjectSpace(cf)
	w.Parent = p
	p.Parent = ctx.folder
	return p
end

------------------------------------------------------------------------------------------------------------------
-- the looks

local LOOKS: { [string]: (ctx: Ctx) -> () } = {}

LOOKS.Gold = function(ctx)
	for _, p in ctx.blocks do
		local c = p.Color
		if not isDark(c) then
			local l = lum(c)
			p.Color = Color3.fromHSV(0.115, 0.86 - 0.25 * l, 0.72 + 0.28 * l)
			p.Material = Enum.Material.SmoothPlastic
			p.Reflectance = 0.12
			p.Transparency = 0
		end
	end
	rootEmitter(ctx, "GoldGlints", {
		Texture = TEX.Sparkle,
		Color = ColorSequence.new(hex("#FFF6C8"), Color3.new(1, 1, 1)),
		Rate = 4,
		Lifetime = NumberRange.new(0.6, 1),
		Speed = NumberRange.new(0),
		Size = twinkle(1.1 * ctx.unit),
		Transparency = TWINKLE_T,
		LightEmission = 1,
		LightInfluence = 0,
		LockedToPart = true,
	})
end

LOOKS.Candy = function(ctx)
	local step = ctx.H * 0.11
	for _, p in ctx.blocks do
		if not isDark(p.Color) then
			local q = localPos(ctx.model, p)
			local band = math.floor((q.Y + q.X * 0.6 + q.Z * 0.6) / step) % 2
			p.Color = band == 0 and hex("#FF6FBF") or hex("#FFF5FA")
			p.Material = Enum.Material.SmoothPlastic
			p.Reflectance = 0.15
			p.Transparency = 0
		end
	end
	for i, c in { "#FF4D9A", "#FFD23F", "#4FD8F0", "#8BD43A" } do
		rootEmitter(ctx, `Sprinkles{i}`, {
			Texture = TEX.Square,
			Color = ColorSequence.new(hex(c)),
			Rate = 2,
			Lifetime = NumberRange.new(1, 1.6),
			Speed = NumberRange.new(0.3 * ctx.unit, 0.8 * ctx.unit),
			Acceleration = Vector3.new(0, -4 * ctx.unit, 0),
			Size = NumberSequence.new(0.32 * ctx.unit),
			Transparency = seq({ { 0, 0 }, { 0.85, 0 }, { 1, 1 } }),
			RotSpeed = NumberRange.new(-200, 200),
			LightInfluence = 0.6,
		})
	end
end

LOOKS.Glitter = function(ctx)
	for _, p in ctx.blocks do
		p.Reflectance = math.max(p.Reflectance, 0.08)
	end
	rootEmitter(ctx, "Glitter", {
		Texture = TEX.Sparkle,
		Color = ColorSequence.new(Color3.new(1, 1, 1)),
		Rate = 9,
		Lifetime = NumberRange.new(0.5, 0.9),
		Speed = NumberRange.new(0),
		Size = twinkle(1 * ctx.unit),
		Transparency = TWINKLE_T,
		LightEmission = 1,
		LightInfluence = 0,
		LockedToPart = true,
	})
	rootEmitter(ctx, "GlitterColour", {
		Texture = TEX.Sparkle,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, hex("#FFB3F0")),
			ColorSequenceKeypoint.new(0.5, hex("#B3F4FF")),
			ColorSequenceKeypoint.new(1, hex("#FFF1A8")),
		}),
		Rate = 7,
		Lifetime = NumberRange.new(0.5, 0.9),
		Speed = NumberRange.new(0),
		Size = twinkle(0.85 * ctx.unit),
		Transparency = TWINKLE_T,
		LightEmission = 1,
		LightInfluence = 0,
		LockedToPart = true,
	})
end

LOOKS.Bubble = function(ctx)
	local root = ctx.root
	local body = ctx.model:FindFirstChild("Rig") and (ctx.model.Rig :: any):FindFirstChild("Body") :: BasePart?
	local size = root.Size
	local r = math.max(size.X, size.Y, size.Z) * 0.62
	local center = root.CFrame -- the Root is centred on the toy
	local ball = fxPart(ctx, "Bubble", body or root, center, Vector3.one * r * 2)
	ball.Shape = Enum.PartType.Ball
	ball.Material = Enum.Material.ForceField
	ball.Color = hex("#9FE6FF")
	ball.Transparency = 0
	local shine = fxPart(
		ctx,
		"BubbleShine",
		body or root,
		center * CFrame.new(-r * 0.4, r * 0.45, -r * 0.35),
		Vector3.one * r * 0.18
	)
	shine.Shape = Enum.PartType.Ball
	shine.Material = Enum.Material.Neon
	shine.Color = Color3.new(1, 1, 1)
	shine.Transparency = 0.35
	rootEmitter(ctx, "Bubbles", {
		Texture = TEX.Ring,
		Color = ColorSequence.new(hex("#E6FBFF")),
		Rate = 3,
		Lifetime = NumberRange.new(1.8, 2.6),
		Speed = NumberRange.new(0.8 * ctx.unit, 1.3 * ctx.unit),
		EmissionDirection = Enum.NormalId.Top,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		Size = seq({ { 0, 0.4 * ctx.unit, 0.15 * ctx.unit }, { 1, 0.7 * ctx.unit, 0.2 * ctx.unit } }),
		Transparency = seq({ { 0, 1 }, { 0.15, 0.2 }, { 0.8, 0.3 }, { 1, 1 } }),
		LightEmission = 0.4,
	})
end

LOOKS.Shadow = function(ctx)
	local dark = hex("#1A1024")
	for _, p in ctx.blocks do
		p.Color = p.Color:Lerp(dark, 0.86)
		p.Material = Enum.Material.SmoothPlastic
		p.Reflectance = 0
	end
	local h = Instance.new("Highlight")
	h.Name = "ShadowOutline"
	h.FillColor = hex("#12081C")
	h.FillTransparency = 0.7
	h.OutlineColor = hex("#9B5CFF")
	h.OutlineTransparency = 0
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Adornee = ctx.model
	h.Parent = ctx.folder
	rootEmitter(ctx, "ShadowSmoke", {
		Texture = TEX.Smoke,
		Color = ColorSequence.new(hex("#2B1745"), hex("#140B22")),
		Rate = 8,
		Lifetime = NumberRange.new(1.4, 2.2),
		Speed = NumberRange.new(0.3 * ctx.unit, 0.7 * ctx.unit),
		Acceleration = Vector3.new(0, 0.4 * ctx.unit, 0),
		Size = seq({ { 0, 1.1 * ctx.unit, 0.3 * ctx.unit }, { 1, 2.4 * ctx.unit } }),
		Transparency = seq({ { 0, 1 }, { 0.25, 0.35 }, { 1, 1 } }),
		RotSpeed = NumberRange.new(-30, 30),
	})
end

LOOKS.Frozen = function(ctx)
	local ice = hex("#A8E4FF")
	for _, p in ctx.blocks do
		local c = p.Color
		p.Color = c:Lerp(ice, isDark(c) and 0.35 or 0.64)
		p.Material = Enum.Material.Ice
		p.Reflectance = 0.15
		p.Transparency = 0
	end
	rootEmitter(ctx, "Frost", {
		Texture = TEX.Sparkle,
		Color = ColorSequence.new(Color3.new(1, 1, 1), hex("#BFEFFF")),
		Rate = 4,
		Lifetime = NumberRange.new(0.7, 1.1),
		Speed = NumberRange.new(0),
		Size = twinkle(0.9 * ctx.unit),
		Transparency = TWINKLE_T,
		LightEmission = 1,
		LightInfluence = 0,
		LockedToPart = true,
	})
	local mist = ToyVFX.floorPart(ctx.model, "FrozenMist", math.max(ctx.root.Size.X, ctx.root.Size.Z) * 1.2, ctx.folder)
	local e = Instance.new("ParticleEmitter")
	e.Name = "Mist"
	e.Texture = TEX.Smoke
	e.Color = ColorSequence.new(hex("#EAF9FF"))
	e.Rate = 3
	e.Lifetime = NumberRange.new(1.8, 2.6)
	e.Speed = NumberRange.new(0.1 * ctx.unit, 0.3 * ctx.unit)
	e.Size = seq({ { 0, 1.4 * ctx.unit, 0.4 * ctx.unit }, { 1, 3 * ctx.unit } })
	e.Transparency = seq({ { 0, 1 }, { 0.3, 0.6 }, { 1, 1 } })
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.EmissionDirection = Enum.NormalId.Top
	e.Parent = mist
end

LOOKS.Rainbow = function(ctx)
	for _, p in ctx.blocks do
		if not isDark(p.Color) then
			p.Material = Enum.Material.SmoothPlastic
			p.Reflectance = 0.1
			p.Transparency = 0
		end
	end
	rootEmitter(ctx, "RainbowSparkles", {
		Texture = TEX.Sparkle,
		Color = ToyVFX.RAINBOW,
		Rate = 4,
		Lifetime = NumberRange.new(1, 1.4),
		Speed = NumberRange.new(0.2 * ctx.unit, 0.5 * ctx.unit),
		Size = twinkle(1 * ctx.unit),
		Transparency = TWINKLE_T,
		LightEmission = 1,
		LightInfluence = 0,
	})
end

LOOKS.Cosmic = function(ctx)
	local lo, mid, hi = hex("#1B1450"), hex("#4A2490"), hex("#B23AC8")
	for _, p in ctx.blocks do
		if not isDark(p.Color) then
			local f = math.clamp(localPos(ctx.model, p).Y / ctx.H, 0, 1)
			local c = f < 0.5 and lo:Lerp(mid, f * 2) or mid:Lerp(hi, (f - 0.5) * 2)
			p.Color = c:Lerp(p.Color, 0.1)
			p.Material = Enum.Material.SmoothPlastic
			p.Reflectance = 0.1
			p.Transparency = 0
		end
	end
	rootEmitter(ctx, "Starfield", {
		Texture = TEX.Sparkle,
		Color = ColorSequence.new(Color3.new(1, 1, 1), hex("#FFF2A8")),
		Rate = 14,
		Lifetime = NumberRange.new(2, 3),
		Speed = NumberRange.new(0),
		Size = twinkle(0.6 * ctx.unit),
		Transparency = TWINKLE_T,
		LightEmission = 1,
		LightInfluence = 0,
		LockedToPart = true,
	})
	-- three sparkles orbiting on a ring; ToyAnimator spins the "CosmicOrbit" joint
	local root = ctx.root
	local radius = math.max(root.Size.X, root.Size.Z) * 0.6 + ctx.H * 0.12
	local pivot = fxPart(ctx, "CosmicOrbit", root, root.CFrame * CFrame.new(0, ctx.H * 0.05, 0), Vector3.one * 0.05)
	pivot.Transparency = 1
	local weld = pivot:FindFirstChildOfClass("Weld")
	if weld then
		local joint = Instance.new("Motor6D")
		joint.Name = "Joint"
		joint.Part0 = weld.Part0
		joint.Part1 = pivot
		joint.C0 = weld.C0
		joint.Parent = pivot
		weld:Destroy()
	end
	for i = 1, 3 do
		local a = (i - 1) * math.pi * 2 / 3
		local y = ctx.H * (-0.2 + 0.2 * (i - 1))
		local cf = pivot.CFrame * CFrame.new(math.cos(a) * radius, y, math.sin(a) * radius)
		local star = fxPart(ctx, `Orbiter{i}`, pivot, cf, Vector3.one * ctx.H * 0.07)
		star.Shape = Enum.PartType.Ball
		star.Material = Enum.Material.Neon
		star.Color = hex("#FFF4C8")
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0, ctx.H * 0.025, 0)
		a0.Parent = star
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, -ctx.H * 0.025, 0)
		a1.Parent = star
		local trail = Instance.new("Trail")
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Lifetime = 0.35
		trail.Color = ColorSequence.new(hex("#FFF4C8"), hex("#9B5CFF"))
		trail.Transparency = seq({ { 0, 0.1 }, { 1, 1 } })
		trail.LightEmission = 1
		trail.LightInfluence = 0
		trail.FaceCamera = true
		trail.Parent = star
	end
	rootLight(ctx, hex("#8A5CFF"), 1.2)
end

LOOKS.Glow = function(ctx)
	local glow = hex("#2FC46A")
	for _, p in ctx.blocks do
		if not isDark(p.Color) then
			p.Color = p.Color:Lerp(glow, 0.7)
			p.Material = Enum.Material.Neon
			p.Transparency = 0
			p.Reflectance = 0
		end
	end
	rootLight(ctx, hex("#7CFF9A"), 1.6)
	rootEmitter(ctx, "GlowMotes", {
		Texture = TEX.Glow,
		Color = ColorSequence.new(hex("#B8FFC8"), hex("#E6FFD0")),
		Rate = 3,
		Lifetime = NumberRange.new(1.2, 2),
		Speed = NumberRange.new(0.3 * ctx.unit, 0.7 * ctx.unit),
		EmissionDirection = Enum.NormalId.Top,
		Size = twinkle(0.35 * ctx.unit),
		Transparency = TWINKLE_T,
		LightEmission = 1,
		LightInfluence = 0,
	})
end

LOOKS.Haunted = function(ctx)
	local ghost = hex("#CFFFF2")
	for _, p in ctx.blocks do
		p.Color = p.Color:Lerp(ghost, 0.62)
		p.Material = Enum.Material.SmoothPlastic
		p.Transparency = math.max(p.Transparency, 0.45)
		p.Reflectance = 0
	end
	rootEmitter(ctx, "Wisps", {
		Texture = TEX.Smoke,
		Color = ColorSequence.new(hex("#CFF6FF"), hex("#A8E8FF")),
		Rate = 10,
		Lifetime = NumberRange.new(1.2, 2),
		Speed = NumberRange.new(0.1 * ctx.unit, 0.3 * ctx.unit),
		Drag = 2,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		Size = seq({ { 0, 0.9 * ctx.unit, 0.3 * ctx.unit }, { 1, 1.9 * ctx.unit } }),
		Transparency = seq({ { 0, 1 }, { 0.2, 0.55 }, { 1, 1 } }),
		LightEmission = 0.5,
		LockedToPart = false, -- left behind as the toy roams: the ghostly trail
	})
	rootLight(ctx, hex("#7FFFE0"), 0.8)
end

------------------------------------------------------------------------------------------------------------------

function Mutations.remove(model: Model)
	local f = model:FindFirstChild("MutationFx")
	if f then
		for _, ref in f:GetChildren() do
			if ref:IsA("ObjectValue") and ref.Value then
				ref.Value:Destroy()
			end
		end
		f:Destroy()
	end
	for _, p in blocksOf(model) do
		restore(p)
	end
	model:SetAttribute("Mutation", nil)
end

function Mutations.apply(model: Model, id: string?)
	Mutations.remove(model)
	if not id or not LOOKS[id] then
		return
	end
	local root = model.PrimaryPart
	if not root then
		return
	end
	local blocks = blocksOf(model)
	for _, p in blocks do
		remember(p)
	end
	local folder = Instance.new("Folder")
	folder.Name = "MutationFx"
	local H = heightOf(model)
	LOOKS[id]({ model = model, root = root, folder = folder, H = H, unit = H / 10, blocks = blocks })
	folder.Parent = model
	model:SetAttribute("Mutation", id)
end

-- Client: the moving part of a mutation's look. Effects are cheap: no per-frame instance creation.
function Mutations.animate(model: Model): (((t: number, dt: number) -> ())?, ((t: number) -> number)?)
	local id = model:GetAttribute("Mutation")
	local H = heightOf(model)
	if id == "Rainbow" then
		local list = {}
		for _, p in blocksOf(model) do
			local base = p:GetAttribute("BaseColor")
			if typeof(base) == "Color3" and not isDark(base) then
				local q = localPos(model, p)
				table.insert(list, { p, (q.Y * 0.045 + q.X * 0.025) })
			end
		end
		local last = -1
		return function(t)
			if t - last < 1 / 20 then
				return -- 20 colour updates a second is plenty
			end
			last = t
			for _, e in list do
				(e[1] :: BasePart).Color = Color3.fromHSV((t * 0.25 + e[2]) % 1, 0.78, 1)
			end
		end,
			nil
	elseif id == "Cosmic" then
		local f = model:FindFirstChild("MutationFx")
		local pivot = f and f:FindFirstChild("CosmicOrbit")
		local joint = pivot and pivot:FindFirstChild("Joint") :: Motor6D?
		if joint then
			return function(t)
				joint.Transform = CFrame.Angles(0, t * 1.8, 0)
			end, nil
		end
	elseif id == "Bubble" then
		return nil, function(t)
			return H * (0.16 + 0.04 * math.sin(t * 1.6))
		end
	elseif id == "Haunted" then
		return nil, function(t)
			return H * (0.06 + 0.035 * math.sin(t * 1.3))
		end
	end
	return nil, nil
end

return Mutations
