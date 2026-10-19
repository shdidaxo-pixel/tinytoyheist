--!strict
-- Toy effects that aren't mutations:
--   ToyVFX.applyRarity(model)            rarity glow on an awake toy (floor ring, sparkles, aura, embers, light).
--                                        The build tool bakes this into every toy in TinyToyHeistAssets.Toys.
--   ToyVFX.removeRarity(model)           take it off (e.g. while the toy is carried, or for a UI viewport).
--   ToyVFX.addGlowTell(target, rarity)   on a sleeping toy's blanket (a Part or a Model): Epic and up leak their
--                                        colour for about 1 s every 8 s. Server or client; the client script makes
--                                        it flicker. Commons to Rares get nothing.
--   ToyVFX.revealBurst(model)            client: the wake-up burst (shockwave ring, confetti, sparkles, flash).
--   ToyVFX.popIn(model, seconds?)        client: the toy pops in from small with a little overshoot.
-- Effect strengths per rarity live in ToyRarities.Fx; sizes scale with the toy's height.
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local ToyBuilder = require(script.Parent.ToyBuilder)
local ToyRarities = require(script.Parent.ToyRarities)

local ToyVFX = {}
ToyVFX.GLOW_TELL_TAG = "ToyGlowTell"

local TEX = ToyBuilder.TEXTURES
local seq = ToyBuilder.seq

function ToyVFX.rarityColor(rarity: string): Color3
	return Color3.fromHex(ToyRarities.Colors[rarity] or "#FFFFFF")
end

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 77, 94)),
	ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 176, 32)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(91, 227, 106)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(61, 165, 255)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(180, 92, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 77, 94)),
})
ToyVFX.RAINBOW = RAINBOW

local function heightOf(model: Model): number
	local h = model:GetAttribute("Height")
	return (type(h) == "number" and h or 10) * model:GetScale()
end

local function footprint(model: Model): number
	local root = model.PrimaryPart
	if not root then
		return 6
	end
	return math.max(root.Size.X, root.Size.Z)
end

-- A flat invisible part on the floor under the toy, welded to the Root so it follows it around.
local function floorPart(model: Model, name: string, width: number, parent: Instance): Part
	local root = model.PrimaryPart :: BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Size = Vector3.new(width, 0.05, width)
	p.CFrame = root.CFrame * CFrame.new(0, -root.Size.Y / 2 + 0.06, 0)
	p.Transparency = 1
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Massless = true
	p.Anchored = false
	local w = Instance.new("Weld")
	w.Part0 = root
	w.Part1 = p
	w.C0 = root.CFrame:ToObjectSpace(p.CFrame)
	w.Parent = p
	p.Parent = parent
	return p
end
ToyVFX.floorPart = floorPart

-- A glowing picture lying on top of a part (a SurfaceGui that ignores lighting, so it glows at night).
local function floorImage(part: BasePart, image: string, color: Color3, transparency: number, scale: number): ImageLabel
	local gui = part:FindFirstChildOfClass("SurfaceGui")
	if not gui then
		local g = Instance.new("SurfaceGui")
		g.Name = "Glow"
		g.Face = Enum.NormalId.Top
		g.LightInfluence = 0
		g.Brightness = 1.6
		g.CanvasSize = Vector2.new(256, 256)
		g.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		g.Parent = part
		gui = g
	end
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.AnchorPoint = Vector2.new(0.5, 0.5)
	img.Position = UDim2.fromScale(0.5, 0.5)
	img.Size = UDim2.fromScale(scale, scale)
	img.Image = image
	img.ImageColor3 = color
	img.ImageTransparency = transparency
	img.Parent = gui
	return img
end
ToyVFX.floorImage = floorImage

-- Some rarity effects live on the Root (an emitter shapes itself to the part it's on); the RarityFx folder holds
-- ObjectValues pointing at them so they can be removed together.
function ToyVFX.removeRarity(model: Model)
	local f = model:FindFirstChild("RarityFx")
	if f then
		for _, ref in f:GetChildren() do
			if ref:IsA("ObjectValue") and ref.Value then
				ref.Value:Destroy()
			end
		end
		f:Destroy()
	end
end

function ToyVFX.applyRarity(model: Model)
	ToyVFX.removeRarity(model)
	local rarity = model:GetAttribute("Rarity") :: string?
	local fx = rarity and ToyRarities.Fx[rarity]
	local root = model.PrimaryPart
	if not fx or not root or not rarity then
		return
	end
	local H = heightOf(model)
	local unit = H / 10
	local color = ToyVFX.rarityColor(rarity)
	local secret = rarity == "Secret"
	local folder = Instance.new("Folder")
	folder.Name = "RarityFx"
	local any = false

	if fx.Ring > 0 or fx.Embers > 0 then
		local size = footprint(model) * 1.5 + H * 0.35
		local ring = floorPart(model, "Ring", size * 1.25, folder)
		if fx.Ring > 0 then
			floorImage(ring, TEX.Glow, color, 1 - fx.Ring * 0.75, 1).Name = "Disc"
			floorImage(ring, TEX.Ring, color, 1 - fx.Ring, 0.8).Name = "Ring"
		end
		if fx.Embers > 0 then
			local e = Instance.new("ParticleEmitter")
			e.Name = "Embers"
			e.Texture = TEX.Glow
			e.Color = secret and RAINBOW or ColorSequence.new(color, Color3.fromRGB(255, 227, 168))
			e.Rate = fx.Embers
			e.Lifetime = NumberRange.new(1, 1.6)
			e.Speed = NumberRange.new(1.6 * unit, 2.4 * unit)
			e.SpreadAngle = Vector2.new(12, 12)
			e.Size = seq({ { 0, 0.32 * unit, 0.08 * unit }, { 1, 0.1 * unit } })
			e.Transparency = seq({ { 0, 0.1 }, { 1, 1 } })
			e.LightEmission = 1
			e.LightInfluence = 0
			e.Shape = Enum.ParticleEmitterShape.Box
			e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
			e.EmissionDirection = Enum.NormalId.Top
			e.Parent = ring
		end
		any = true
	end
	if fx.Sparkle > 0 then
		local e = Instance.new("ParticleEmitter")
		e.Name = "RaritySparkles"
		e.Texture = TEX.Sparkle
		e.Color = secret and RAINBOW or ColorSequence.new(color, Color3.new(1, 1, 1))
		e.Rate = fx.Sparkle
		e.Lifetime = NumberRange.new(1.1, 1.9)
		e.Speed = NumberRange.new(0.2 * unit, 0.6 * unit)
		e.Acceleration = Vector3.new(0, 0.3 * unit, 0)
		e.Size = seq({ { 0, 0 }, { 0.5, 0.95 * unit, 0.25 * unit }, { 1, 0 } })
		e.Transparency = seq({ { 0, 1 }, { 0.5, 0 }, { 1, 1 } })
		e.LightEmission = 1
		e.LightInfluence = 0
		e.Shape = Enum.ParticleEmitterShape.Box
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
		e.Parent = root
		local ref = Instance.new("ObjectValue")
		ref.Name = "RaritySparkles"
		ref.Value = e
		ref.Parent = folder
		any = true
	end
	if fx.Aura > 0 then
		local att = Instance.new("Attachment")
		att.Name = "RarityAura"
		att.Parent = root
		local e = Instance.new("ParticleEmitter")
		e.Name = "Aura"
		e.Texture = TEX.Glow
		e.Color = secret and RAINBOW or ColorSequence.new(color)
		e.Rate = 2.5
		e.Lifetime = NumberRange.new(1.2)
		e.Speed = NumberRange.new(0)
		e.LockedToPart = true
		e.Size = seq({ { 0, H * 0.85 }, { 0.5, H * 1 }, { 1, H * 1.05 } })
		e.Transparency = seq({ { 0, 1 }, { 0.45, 1 - fx.Aura }, { 1, 1 } })
		e.LightEmission = 1
		e.LightInfluence = 0
		e.ZOffset = -H * 0.6
		e.Parent = att
		local ref = Instance.new("ObjectValue")
		ref.Name = "RarityAura"
		ref.Value = att
		ref.Parent = folder
		any = true
	end
	if fx.Light > 0 then
		local l = Instance.new("PointLight")
		l.Name = "RarityLight"
		l.Color = color
		l.Brightness = fx.Light
		l.Range = math.min(60, H * 2.2)
		l.Shadows = false
		l.Parent = root
		local ref = Instance.new("ObjectValue")
		ref.Name = "RarityLight"
		ref.Value = l
		ref.Parent = folder
		any = true
	end
	if any then
		folder.Parent = model
	else
		folder:Destroy()
	end
end

-- Client: the moving parts of a rarity effect (Secret's rainbow ring and light). Returns nil if nothing moves.
function ToyVFX.animateRarity(model: Model): ((t: number, dt: number) -> ())?
	if model:GetAttribute("Rarity") ~= "Secret" then
		return nil
	end
	local folder = model:FindFirstChild("RarityFx")
	if not folder then
		return nil
	end
	local images: { ImageLabel } = {}
	for _, d in folder:GetDescendants() do
		if d:IsA("ImageLabel") then
			table.insert(images, d)
		end
	end
	local lightRef = folder:FindFirstChild("RarityLight") :: ObjectValue?
	local light = lightRef and lightRef.Value :: PointLight?
	return function(t: number)
		for i, img in images do
			img.ImageColor3 = Color3.fromHSV((t * 0.15 + i * 0.3) % 1, 0.75, 1)
		end
		if light then
			light.Color = Color3.fromHSV((t * 0.15) % 1, 0.75, 1)
		end
	end
end

------------------------------------------------------------------------------------------------------------------
-- Glow tell (sleeping toys)

local function tellPart(target: Instance): BasePart?
	if target:IsA("BasePart") then
		return target
	elseif target:IsA("Model") then
		return target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

function ToyVFX.addGlowTell(target: Instance, rarity: string)
	local fx = ToyRarities.Fx[rarity]
	local part = tellPart(target)
	if not fx or not fx.Tell or not part then
		return
	end
	local old = part:FindFirstChild("GlowTell")
	if old then
		old:Destroy()
	end
	local color = ToyVFX.rarityColor(rarity)
	local size = part.Size
	local H = math.max(size.Y, 4)
	local att = Instance.new("Attachment")
	att.Name = "GlowTell"
	att.Position = Vector3.new(0, -size.Y / 2 + H * 0.4, 0)
	local light = Instance.new("PointLight")
	light.Name = "Light"
	light.Color = color
	light.Brightness = 0
	light.Range = math.min(40, math.max(size.X, size.Z) * 1.8 + 6)
	light.Shadows = false
	light.Parent = att
	local glow = Instance.new("ParticleEmitter")
	glow.Name = "Glow"
	glow.Texture = TEX.Glow
	glow.Color = rarity == "Secret" and RAINBOW or ColorSequence.new(color)
	glow.Enabled = false
	glow.LockedToPart = true
	glow.Lifetime = NumberRange.new(1)
	glow.Speed = NumberRange.new(0)
	glow.Size = seq({ { 0, math.max(size.X, size.Z) * 1.3 }, { 1, math.max(size.X, size.Z) * 1.6 } })
	glow.Transparency = seq({ { 0, 1 }, { 0.35, 0.35 }, { 1, 1 } })
	glow.LightEmission = 1
	glow.LightInfluence = 0
	glow.Parent = att
	local spark = Instance.new("ParticleEmitter")
	spark.Name = "Sparkles"
	spark.Texture = TEX.Sparkle
	spark.Color = rarity == "Secret" and RAINBOW or ColorSequence.new(color, Color3.new(1, 1, 1))
	spark.Enabled = false
	spark.Lifetime = NumberRange.new(0.8, 1.2)
	spark.Speed = NumberRange.new(H * 0.15, H * 0.3)
	spark.SpreadAngle = Vector2.new(50, 50)
	spark.Size = seq({ { 0, 0 }, { 0.5, H * 0.12 }, { 1, 0 } })
	spark.LightEmission = 1
	spark.LightInfluence = 0
	spark.Parent = att
	att.Parent = part
	target:SetAttribute("TellRarity", rarity)
	CollectionService:AddTag(target, ToyVFX.GLOW_TELL_TAG)
end

function ToyVFX.removeGlowTell(target: Instance)
	CollectionService:RemoveTag(target, ToyVFX.GLOW_TELL_TAG)
	local part = tellPart(target)
	local att = part and part:FindFirstChild("GlowTell")
	if att then
		att:Destroy()
	end
end

-- Client: flicker every glow tell (1 s on, about every 8 s, each on its own clock).
function ToyVFX.watchGlowTells(): RBXScriptConnection
	local phases: { [Instance]: number } = {}
	local fired: { [Instance]: boolean } = {}
	return RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for _, target in CollectionService:GetTagged(ToyVFX.GLOW_TELL_TAG) do
			local part = tellPart(target)
			local att = part and part:FindFirstChild("GlowTell")
			if att then
				local ph = phases[target]
				if not ph then
					ph = math.random() * 8
					phases[target] = ph
				end
				local u = (now + ph) % 8
				local e = u < 1 and math.sin(math.pi * u) or 0
				local light = att:FindFirstChild("Light") :: PointLight?
				if light then
					light.Brightness = e * 2.2
					if target:GetAttribute("TellRarity") == "Secret" then
						light.Color = Color3.fromHSV((now * 0.3) % 1, 0.75, 1)
					end
				end
				if u < 0.1 and not fired[target] then
					fired[target] = true
					local glow = att:FindFirstChild("Glow") :: ParticleEmitter?
					local spark = att:FindFirstChild("Sparkles") :: ParticleEmitter?
					if glow then
						glow:Emit(1)
					end
					if spark then
						spark:Emit(4)
					end
				elseif u >= 0.1 then
					fired[target] = nil
				end
			end
		end
	end)
end

------------------------------------------------------------------------------------------------------------------
-- Reveal (client)

local CONFETTI = { Common = 14, Uncommon = 20, Rare = 28, Epic = 38, Legendary = 52, Mythic = 66, Secret = 84 }

function ToyVFX.revealBurst(model: Model)
	local root = model.PrimaryPart
	local rarity = (model:GetAttribute("Rarity") :: string?) or "Common"
	if not root then
		return
	end
	local H = heightOf(model)
	local unit = H / 10
	local color = ToyVFX.rarityColor(rarity)
	local secret = rarity == "Secret"
	local folder = Instance.new("Folder")
	folder.Name = "RevealFx"

	local att = Instance.new("Attachment")
	att.Name = "RevealBurst"
	att.Parent = root
	local confetti = Instance.new("ParticleEmitter")
	confetti.Texture = TEX.Square
	confetti.Color = secret and RAINBOW or ColorSequence.new(color, Color3.new(1, 1, 1))
	confetti.Enabled = false
	confetti.Lifetime = NumberRange.new(1.2, 1.8)
	confetti.Speed = NumberRange.new(3 * unit, 6 * unit)
	confetti.SpreadAngle = Vector2.new(70, 70)
	confetti.Acceleration = Vector3.new(0, -9 * unit, 0)
	confetti.Drag = 1
	confetti.Size = seq({ { 0, 0.5 * unit, 0.15 * unit }, { 1, 0.35 * unit } })
	confetti.Transparency = seq({ { 0, 0 }, { 0.8, 0 }, { 1, 1 } })
	confetti.Rotation = NumberRange.new(0, 360)
	confetti.RotSpeed = NumberRange.new(-300, 300)
	confetti.LightInfluence = 0.5
	confetti.Parent = att
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Texture = TEX.Sparkle
	sparkle.Color = secret and RAINBOW or ColorSequence.new(color, Color3.new(1, 1, 1))
	sparkle.Enabled = false
	sparkle.Lifetime = NumberRange.new(0.6, 1)
	sparkle.Speed = NumberRange.new(2 * unit, 4 * unit)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Drag = 3
	sparkle.Size = seq({ { 0, 0 }, { 0.3, 1.4 * unit, 0.3 * unit }, { 1, 0 } })
	sparkle.LightEmission = 1
	sparkle.LightInfluence = 0
	sparkle.Parent = att
	local flash = Instance.new("ParticleEmitter")
	flash.Texture = TEX.Glow
	flash.Color = ColorSequence.new(color)
	flash.Enabled = false
	flash.Lifetime = NumberRange.new(0.45)
	flash.Speed = NumberRange.new(0)
	flash.LockedToPart = true
	flash.Size = seq({ { 0, H * 1.5 }, { 1, H * 3.2 } })
	flash.Transparency = seq({ { 0, 0.1 }, { 1, 1 } })
	flash.LightEmission = 1
	flash.LightInfluence = 0
	flash.Parent = att
	local n = CONFETTI[rarity] or 20
	confetti:Emit(n)
	sparkle:Emit(math.ceil(n / 3))
	flash:Emit(1)

	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = 6
	light.Range = math.min(60, H * 4)
	light.Shadows = false
	light.Parent = att
	TweenService:Create(light, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0 })
		:Play()

	-- shockwave ring on the floor
	local base = footprint(model) + 4
	local ring = floorPart(model, "Shockwave", base, folder)
	local img = floorImage(ring, TEX.Ring, color, 0, 1)
	folder.Parent = model
	TweenService:Create(
		ring,
		TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(base * 4, 0.05, base * 4) }
	):Play()
	TweenService:Create(img, TweenInfo.new(0.7), { ImageTransparency = 1 }):Play()
	Debris:AddItem(att, 2.5)
	Debris:AddItem(folder, 2.5)
end

function ToyVFX.popIn(model: Model, seconds: number?)
	local total = seconds or 0.45
	local base = model:GetScale()
	local t0 = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function()
		local p = (os.clock() - t0) / total
		if p >= 1 or not model.Parent then
			conn:Disconnect()
			if model.Parent then
				model:ScaleTo(base)
			end
			return
		end
		-- ease out with a little overshoot
		local k = 1 + 2.2 * (p - 1) ^ 3 + 1.2 * (p - 1) ^ 2
		model:ScaleTo(base * math.max(0.2, 0.2 + 0.8 * k))
	end)
end

return ToyVFX
