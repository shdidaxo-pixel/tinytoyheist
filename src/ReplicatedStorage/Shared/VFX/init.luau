--!strict
-- Tiny Toy Heist VFX: the big, loud moments (client only). API and moment names: design/notes/vfx.md.
--   VFX.burst(kind, at, opts?)            world bursts: Hatch, LevelUp, Cash, Steal, Stolen, Recovered, Poof,
--                                         Sparkle, Shockwave
--   VFX.hatchCharge(blanket, rarity, s)   the build-up before a hatch (shakes, glows, sucks light in), then calls
--                                         back; VFX.burst("Hatch") is the pay-off
--   VFX.popText(text, at, opts?)          "+$120" popping up (world or screen)
--   VFX.shake / flash / vignette / beams / confetti / fovPunch
--   VFX.uiPop / uiPress / shine / countTo / revealCard   UI juice
-- Everything scales with the thing it's on and tones itself down in Performance Mode (VFX.quality() == "low").
-- Idle looks (rarity glow, mutation auras) are in ToyVFX / Mutations and stay soft; this is for moments.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Assets = require(script:WaitForChild("Assets"))
local Moments = require(script:WaitForChild("Moments"))
local Shared = script.Parent
local Toys = Shared:WaitForChild("Toys")
local ToyRarities = require(Toys:WaitForChild("ToyRarities")) :: any
local MutationData = require(Toys:WaitForChild("MutationData")) :: any

local VFX = {}
VFX.Assets = Assets

local me = Players.LocalPlayer
local WHITE = Color3.new(1, 1, 1)
local INK = Color3.fromRGB(26, 20, 48)
local GOLD = Color3.fromRGB(255, 201, 60)
local RED = Color3.fromRGB(255, 61, 82)
local GREEN = Color3.fromRGB(91, 227, 106)

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 77, 94)),
	ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 176, 32)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(91, 227, 106)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(61, 165, 255)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(180, 92, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 77, 94)),
})
VFX.RAINBOW = RAINBOW
local CONFETTI_COLORS = {
	Color3.fromRGB(255, 77, 94),
	Color3.fromRGB(255, 201, 60),
	Color3.fromRGB(91, 227, 106),
	Color3.fromRGB(61, 165, 255),
	Color3.fromRGB(180, 92, 255),
	Color3.fromRGB(255, 143, 208),
}

-- How hard each rarity hits. build = seconds of charge-up before the burst.
type Tier = {
	n: number, -- 1..7
	beams: number,
	sparks: number,
	confetti: number,
	screenConfetti: number,
	shake: number,
	flash: number,
	rings: number,
	build: number,
	rays: boolean,
	lightning: boolean,
}
local TIERS: { [string]: Tier } = {
	Common = {
		n = 1,
		beams = 0,
		sparks = 10,
		confetti = 0,
		screenConfetti = 0,
		shake = 0.08,
		flash = 0.12,
		rings = 1,
		build = 0.6,
		rays = false,
		lightning = false,
	},
	Uncommon = {
		n = 2,
		beams = 3,
		sparks = 16,
		confetti = 12,
		screenConfetti = 0,
		shake = 0.12,
		flash = 0.18,
		rings = 1,
		build = 0.8,
		rays = false,
		lightning = false,
	},
	Rare = {
		n = 3,
		beams = 5,
		sparks = 24,
		confetti = 24,
		screenConfetti = 0,
		shake = 0.2,
		flash = 0.25,
		rings = 2,
		build = 1.1,
		rays = false,
		lightning = false,
	},
	Epic = {
		n = 4,
		beams = 7,
		sparks = 32,
		confetti = 40,
		screenConfetti = 50,
		shake = 0.32,
		flash = 0.35,
		rings = 2,
		build = 1.4,
		rays = true,
		lightning = false,
	},
	Legendary = {
		n = 5,
		beams = 9,
		sparks = 40,
		confetti = 56,
		screenConfetti = 80,
		shake = 0.45,
		flash = 0.5,
		rings = 3,
		build = 1.8,
		rays = true,
		lightning = false,
	},
	Mythic = {
		n = 6,
		beams = 12,
		sparks = 48,
		confetti = 72,
		screenConfetti = 110,
		shake = 0.7,
		flash = 0.65,
		rings = 3,
		build = 2.4,
		rays = true,
		lightning = true,
	},
	Secret = {
		n = 7,
		beams = 16,
		sparks = 56,
		confetti = 90,
		screenConfetti = 150,
		shake = 0.9,
		flash = 0.8,
		rings = 4,
		build = 3.0,
		rays = true,
		lightning = true,
	},
}
VFX.TIERS = TIERS

function VFX.tier(rarity: string?): Tier
	return TIERS[rarity or "Common"] or TIERS.Common
end

function VFX.rarityColor(rarity: string?): Color3
	return Color3.fromHex(ToyRarities.Colors[rarity or "Common"] or "#FFFFFF")
end

function VFX.mutationColor(id: string?): Color3
	local m = id and MutationData.List[id]
	return if m then Color3.fromHex(m.Color) else WHITE
end

-- Performance Mode (Settings) -> "low": fewer particles, no camera shake, shorter flashes.
function VFX.quality(): string
	return if me and me:GetAttribute("SettingPerformanceMode") == true then "low" else "full"
end
local function low(): boolean
	return VFX.quality() == "low"
end
-- particle count for this quality
local function count(n: number): number
	return math.max(1, math.floor(n * (if low() then 0.3 else 1) + 0.5))
end

local function seq(points: { { number } }): NumberSequence
	local kps = {}
	for _, p in points do
		table.insert(kps, NumberSequenceKeypoint.new(p[1], p[2], p[3] or 0))
	end
	return NumberSequence.new(kps)
end
VFX.seq = seq

------------------------------------------------------------------------------------------------------------------
-- frame loop: one Heartbeat for every running effect. fn(p, dt) gets 0..1 and returns nothing; done() at the end.

type Job = { t0: number, d: number, fn: (p: number, dt: number) -> (), done: (() -> ())? }
local jobs: { Job } = {}
local loop: RBXScriptConnection? = nil
local function animate(seconds: number, fn: (p: number, dt: number) -> (), done: (() -> ())?)
	table.insert(jobs, { t0 = os.clock(), d = math.max(seconds, 1e-3), fn = fn, done = done })
	if loop then
		return
	end
	loop = RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		if VFX.frozen then
			for _, j in jobs do
				j.t0 += dt -- held still (VFX.freeze, for captures)
			end
		end
		local i = 1
		while i <= #jobs do
			local j = jobs[i]
			local p = math.min(1, (now - j.t0) / j.d)
			local ok, err = pcall(j.fn, p, dt)
			if not ok then
				warn("VFX:", err)
				p = 1
			end
			if p >= 1 then
				table.remove(jobs, i)
				if j.done then
					task.spawn(j.done)
				end
			else
				i += 1
			end
		end
		if #jobs == 0 and loop then
			loop:Disconnect()
			loop = nil
		end
	end)
end
VFX.animate = animate

-- For captures: hold every running effect still (particles and frame jobs), then let go.
VFX.frozen = false
function VFX.freeze(on: boolean)
	VFX.frozen = on
	for _, d in Workspace:GetDescendants() do
		if d:IsA("ParticleEmitter") and d:FindFirstAncestor("VFX") then
			d.TimeScale = if on then 0 else 1
		end
	end
end

local function easeOut(p: number, k: number?): number
	return 1 - (1 - p) ^ (k or 3)
end

------------------------------------------------------------------------------------------------------------------
-- world helpers

local folder: Folder? = nil
local function fxFolder(): Folder
	if folder and folder.Parent then
		return folder
	end
	local f = Instance.new("Folder")
	f.Name = "VFX"
	f.Parent = Workspace
	folder = f
	return f
end

-- where to put an effect: a point, a part's centre or a model's pivot; plus a size hint (height in studs)
local function where(at: any): (Vector3, number)
	if typeof(at) == "Vector3" then
		return at, 5
	elseif typeof(at) == "CFrame" then
		return at.Position, 5
	elseif typeof(at) == "Instance" then
		if at:IsA("Model") then
			local h = at:GetAttribute("Height")
			local height = if type(h) == "number" then h * at:GetScale() else at:GetExtentsSize().Y
			return at:GetPivot().Position, height
		elseif at:IsA("BasePart") then
			return at.Position, at.Size.Y
		elseif at:IsA("Attachment") then
			return at.WorldPosition, 5
		end
	end
	return Vector3.zero, 5
end

-- the floor under a point (so rings lie flat on it)
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local function floorAt(p: Vector3): Vector3
	local ignore: { Instance } = { fxFolder() }
	if me and me.Character then
		table.insert(ignore, me.Character)
	end
	rayParams.FilterDescendantsInstances = ignore
	local hit = Workspace:Raycast(p + Vector3.new(0, 3, 0), Vector3.new(0, -60, 0), rayParams)
	return if hit then hit.Position else p
end

-- an invisible anchored part to hang emitters on (sized for Shape emitters), cleaned up after `life`
local function anchor(pos: Vector3, size: number?, life: number?): Part
	local p = Instance.new("Part")
	p.Name = "VfxAnchor"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = Vector3.one * (size or 1)
	p.Shape = Enum.PartType.Ball
	p.CFrame = CFrame.new(pos)
	p.Parent = fxFolder()
	-- cleaned up by the frame loop (not Debris) so VFX.freeze holds it too
	animate(life or 4, function() end, function()
		p:Destroy()
	end)
	return p
end

-- a particle emitter that only fires by :Emit (Enabled = false). props override the defaults.
local function emitter(parent: Instance, tex: string, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.Texture = Assets.get(tex)
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Rate = 0
	if Assets.isSheet(tex) then
		e.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		e.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	end
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = parent
	return e
end
VFX.emitter = emitter

local function colorSeq(c: Color3 | ColorSequence, toWhite: boolean?): ColorSequence
	if typeof(c) == "ColorSequence" then
		return c
	end
	return if toWhite then ColorSequence.new(c, c:Lerp(WHITE, 0.6)) else ColorSequence.new(c)
end

local function pointLight(parent: Instance, color: Color3, brightness: number, range: number, seconds: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Brightness = brightness
	l.Range = math.min(60, range)
	l.Shadows = false
	l.Parent = parent
	TweenService:Create(l, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0 })
		:Play()
	return l
end

-- A glowing picture lying flat on the floor that grows and fades (shockwave rings, magic circles)
local function floorDecal(
	pos: Vector3,
	tex: string,
	color: Color3,
	fromSize: number,
	toSize: number,
	seconds: number,
	opts: { alpha: number?, spin: number?, delay: number?, rainbow: boolean? }?
)
	local o = opts or {}
	local p = Instance.new("Part")
	p.Name = "VfxFloor"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = Vector3.new(fromSize, 0.05, fromSize)
	p.CFrame = CFrame.new(floorAt(pos) + Vector3.new(0, 0.12, 0))
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Top
	g.LightInfluence = 0
	g.Brightness = 2
	g.CanvasSize = Vector2.new(256, 256)
	g.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	g.Parent = p
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromScale(1, 1)
	img.Image = Assets.get(tex)
	img.ImageColor3 = color
	img.ImageTransparency = 1
	img.Parent = g
	if Assets.isSheet(tex) then
		img.ImageRectSize = Vector2.new(256, 256) -- first frame; animated below
	end
	local alpha = o.alpha or 0
	local base = p.CFrame
	task.delay(o.delay or 0, function()
		p.Parent = fxFolder()
		animate(seconds, function(t)
			local e = easeOut(t, 2.5)
			local s = fromSize + (toSize - fromSize) * e
			p.Size = Vector3.new(s, 0.05, s)
			p.CFrame = base * CFrame.Angles(0, (o.spin or 0) * t, 0)
			img.ImageTransparency = alpha + (1 - alpha) * t ^ 1.5
			if Assets.isSheet(tex) then
				local f = math.min(15, math.floor(t * 16))
				img.ImageRectOffset = Vector2.new(f % 4, f // 4) * 256
			end
			if o.rainbow then
				img.ImageColor3 = Color3.fromHSV((os.clock() * 0.8) % 1, 0.7, 1)
			end
		end, function()
			p:Destroy()
		end)
	end)
end
VFX.floorDecal = floorDecal

------------------------------------------------------------------------------------------------------------------
-- beams: light pillars shooting up out of a point, fanned out, then fading

function VFX.beams(at: any, color: Color3 | ColorSequence, n: number, seconds: number?, height: number?)
	local pos, h = where(at)
	local base = floorAt(pos)
	local life = seconds or 1.4
	local tall = height or math.max(30, h * 5)
	n = if low() then math.min(n, 3) else n
	if n <= 0 then
		return
	end
	local holder = anchor(base, 1, life + 0.5)
	local list = {}
	for i = 1, n do
		local a0 = Instance.new("Attachment")
		a0.Parent = holder
		local a1 = Instance.new("Attachment")
		a1.Parent = holder
		local beam = Instance.new("Beam")
		beam.Attachment0 = a0
		beam.Attachment1 = a1
		beam.Texture = Assets.get("Beam")
		beam.TextureMode = Enum.TextureMode.Stretch
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.FaceCamera = true
		beam.Segments = 1
		beam.Color = colorSeq(color)
		beam.Transparency = seq({ { 0, 0 }, { 0.75, 0.2 }, { 1, 1 } })
		beam.Brightness = 2
		beam.Width0 = 0
		beam.Width1 = 0
		beam.Parent = holder
		local angle = (i / n) * math.pi * 2 + math.random() * 0.4
		local tilt = 0.12 + math.random() * 0.35
		table.insert(list, { beam = beam, a1 = a1, angle = angle, tilt = tilt, w = h * (0.5 + math.random() * 0.5) })
	end
	animate(life, function(t)
		local grow = easeOut(math.min(1, t * 4), 3)
		local fade = if t > 0.55 then 1 - (t - 0.55) / 0.45 else 1
		for _, b in list do
			local a = b.angle + t * 0.8
			local dir = Vector3.new(math.cos(a) * b.tilt, 1, math.sin(a) * b.tilt).Unit
			b.a1.Position = dir * tall * grow
			b.beam.Width0 = b.w * 0.6 * fade
			b.beam.Width1 = b.w * 1.6 * fade
		end
	end)
end

------------------------------------------------------------------------------------------------------------------
-- screen layers: Under (flash, vignette; below the HUD) and Over (confetti, screen text; above it)

local screens: { [string]: ScreenGui } = {}
local function screen(name: string): ScreenGui
	local s = screens[name]
	if s and s.Parent then
		return s
	end
	local g = Instance.new("ScreenGui")
	g.Name = "VFX" .. name
	g.IgnoreGuiInset = true
	g.ResetOnSpawn = false
	g.DisplayOrder = if name == "Under" then -1 else 20
	g.Parent = me:WaitForChild("PlayerGui")
	screens[name] = g
	return g
end

function VFX.flash(color: Color3?, alpha: number?, seconds: number?)
	local f = Instance.new("Frame")
	f.Name = "Flash"
	f.BorderSizePixel = 0
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = color or WHITE
	local a = math.clamp((alpha or 0.5) * (if low() then 0.6 else 1), 0, 1)
	f.BackgroundTransparency = 1 - a
	f.Parent = screen("Under")
	local t = TweenService:Create(
		f,
		TweenInfo.new(seconds or 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundTransparency = 1 }
	)
	t.Completed:Once(function()
		f:Destroy()
	end)
	t:Play()
end

-- Coloured screen edges. seconds = a pulse that fades; nil = stays (pulsing gently) until VFX.vignette(nil).
local held: ImageLabel? = nil
function VFX.vignette(color: Color3?, alpha: number?, seconds: number?)
	if color == nil then
		if held then
			local h = held
			held = nil
			TweenService:Create(h, TweenInfo.new(0.6), { ImageTransparency = 1 }):Play()
			Debris:AddItem(h, 0.7)
		end
		return
	end
	local img = Instance.new("ImageLabel")
	img.Name = "Vignette"
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromScale(1, 1)
	img.Image = Assets.get("Vignette")
	img.ImageColor3 = color
	img.ImageTransparency = 1
	img.Parent = screen("Under")
	local a = alpha or 0.5
	if seconds then
		animate(seconds, function(t)
			local k = if t < 0.2 then t / 0.2 else 1 - (t - 0.2) / 0.8
			img.ImageTransparency = 1 - a * k
		end, function()
			img:Destroy()
		end)
	else
		if held then
			held:Destroy()
		end
		held = img
		task.spawn(function()
			local t0 = os.clock()
			while held == img and img.Parent do
				local t = os.clock() - t0
				-- heartbeat: two quick thumps a second
				local beat = math.max(0, math.sin(t * 7.5)) ^ 6
				img.ImageTransparency = 1 - math.min(1, t * 3) * a * (0.65 + 0.35 * beat)
				RunService.RenderStepped:Wait()
			end
		end)
	end
end

-- Camera shake ("trauma": the strongest recent shake wins, then it settles). strength 0..1.
local trauma = 0
local traumaDecay = 1
local shakeBound = false
function VFX.shake(strength: number, seconds: number?)
	if low() then
		return
	end
	trauma = math.min(1, math.max(trauma, strength))
	traumaDecay = 1 / math.max(0.1, seconds or 0.5)
	if shakeBound then
		return
	end
	shakeBound = true
	local RunServiceAny = RunService :: any
	RunServiceAny:BindToRenderStep("VFXShake", Enum.RenderPriority.Camera.Value + 1, function(dt: number)
		local cam = Workspace.CurrentCamera
		if trauma <= 0 or not cam then
			RunServiceAny:UnbindFromRenderStep("VFXShake")
			shakeBound = false
			return
		end
		local s = trauma * trauma
		local t = os.clock() * 24
		local rx = math.noise(t, 0.3) * 0.045 * s
		local ry = math.noise(t, 7.1) * 0.045 * s
		local rz = math.noise(t, 13.7) * 0.06 * s
		cam.CFrame = cam.CFrame * CFrame.Angles(rx, ry, rz)
		trauma = math.max(0, trauma - traumaDecay * dt)
	end)
end

-- a quick zoom-in punch (field of view dips and springs back)
local punching = false
function VFX.fovPunch(amount: number?, seconds: number?)
	local cam = Workspace.CurrentCamera
	if not cam or punching or low() then
		return
	end
	punching = true
	local base = cam.FieldOfView
	local a = amount or 8
	animate(seconds or 0.5, function(t)
		local k = if t < 0.15 then easeOut(t / 0.15, 2) else 1 - easeOut((t - 0.15) / 0.85, 2)
		cam.FieldOfView = base - a * k
	end, function()
		cam.FieldOfView = base
		punching = false
	end)
end

-- Screen confetti: paper bits and stars falling across the screen
function VFX.confetti(n: number, colors: { Color3 }?)
	n = math.min(160, count(n))
	local layer = screen("Over")
	local holder = Instance.new("Frame")
	holder.Name = "Confetti"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = layer
	local size = layer.AbsoluteSize
	local scale = math.clamp(math.min(size.X, size.Y) / 720, 0.5, 1.4)
	local bits = {}
	local cols = colors or CONFETTI_COLORS
	for i = 1, n do
		local star = i % 5 == 0
		local f: GuiObject
		if star then
			local img = Instance.new("ImageLabel")
			img.BackgroundTransparency = 1
			img.Image = Assets.get("Star")
			img.ImageColor3 = cols[math.random(1, #cols)]
			local px = math.random(14, 22) * scale
			img.Size = UDim2.fromOffset(px, px)
			f = img
		else
			local fr = Instance.new("Frame")
			fr.BorderSizePixel = 0
			fr.BackgroundColor3 = cols[math.random(1, #cols)]
			fr.Size = UDim2.fromOffset(math.random(8, 13) * scale, math.random(14, 22) * scale)
			f = fr
		end
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Parent = holder
		-- burst up from the bottom corners and the top, then flutter down
		local fromSide = i % 3
		local x, y, vx, vy
		if fromSide == 0 then
			x, y = math.random() * size.X, -20
			vx, vy = (math.random() - 0.5) * 200, math.random(60, 240)
		else
			x = if fromSide == 1 then -10 else size.X + 10
			y = size.Y * (0.55 + math.random() * 0.35)
			vx = (if fromSide == 1 then 1 else -1) * math.random(250, 650) * scale
			vy = -math.random(500, 1000) * scale
		end
		table.insert(bits, {
			f = f,
			x = x,
			y = y,
			vx = vx,
			vy = vy,
			rot = math.random() * 360,
			vr = (math.random() - 0.5) * 720,
			wob = math.random() * 6,
		})
	end
	animate(3.2, function(t, dt)
		dt = math.min(dt, 1 / 20)
		for _, b in bits do
			b.vy += 900 * scale * dt
			b.vx *= 1 - 1.6 * dt
			b.vy = math.min(b.vy, 260 * scale)
			b.x += (b.vx + math.sin(os.clock() * 5 + b.wob) * 60) * dt
			b.y += b.vy * dt
			b.rot += b.vr * dt
			b.f.Position = UDim2.fromOffset(b.x, b.y)
			b.f.Rotation = b.rot
			if t > 0.75 then
				local k = (t - 0.75) / 0.25
				if b.f:IsA("Frame") then
					b.f.BackgroundTransparency = k
				else
					(b.f :: ImageLabel).ImageTransparency = k
				end
			end
		end
	end, function()
		holder:Destroy()
	end)
end

------------------------------------------------------------------------------------------------------------------
-- pop text

export type TextOpts = {
	color: Color3?,
	size: number?,
	rise: number?,
	duration: number?,
	stroke: Color3?,
	font: Enum.Font?,
	gradient: ColorSequence?,
}

local function styleLabel(l: TextLabel, text: string, o: TextOpts)
	l.BackgroundTransparency = 1
	l.Text = text
	l.Font = o.font or Enum.Font.FredokaOne
	l.TextColor3 = o.color or WHITE
	l.TextScaled = true
	l.Size = UDim2.fromScale(1, 1)
	local s = Instance.new("UIStroke")
	s.Thickness = math.max(2, (o.size or 30) / 9)
	s.Color = o.stroke or INK
	s.Parent = l
	if o.gradient then
		local g = Instance.new("UIGradient")
		g.Color = o.gradient
		g.Parent = l
		task.spawn(function()
			while g.Parent do
				g.Offset = Vector2.new(math.sin(os.clock() * 3) * 0.5, 0)
				task.wait()
			end
		end)
	end
end

function VFX.popText(text: string, at: any, opts: TextOpts?): Instance?
	local o = opts or {}
	local px = o.size or 30
	local life = o.duration or 1.2
	if typeof(at) == "UDim2" or (typeof(at) == "Instance" and at:IsA("GuiObject")) then
		-- on the screen
		local pos: UDim2
		if typeof(at) == "UDim2" then
			pos = at
		else
			local g = at :: GuiObject
			local c = g.AbsolutePosition + g.AbsoluteSize / 2
			pos = UDim2.fromOffset(c.X, c.Y)
		end
		local holder = Instance.new("Frame")
		holder.BackgroundTransparency = 1
		holder.AnchorPoint = Vector2.new(0.5, 0.5)
		holder.Size = UDim2.fromOffset(px * math.max(3, #text * 0.62), px * 1.2)
		holder.Position = pos
		holder.Parent = screen("Over")
		local l = Instance.new("TextLabel")
		styleLabel(l, text, o)
		l.Parent = holder
		local sc = Instance.new("UIScale")
		sc.Parent = holder
		local rise = o.rise or 60
		animate(life, function(t)
			sc.Scale = if t < 0.15
				then easeOut(t / 0.15, 2) * 1.3
				else 1.3 - 0.3 * easeOut(math.min(1, (t - 0.15) / 0.2))
			holder.Position = pos + UDim2.fromOffset(0, -rise * easeOut(t, 3))
			local fade = math.max(0, (t - 0.65) / 0.35)
			l.TextTransparency = fade
			local st = l:FindFirstChildOfClass("UIStroke")
			if st then
				st.Transparency = fade
			end
		end, function()
			holder:Destroy()
		end)
		return holder
	end
	local pos, h = where(at)
	local holder = anchor(pos + Vector3.new(0, h * 0.6, 0), 0.1, life + 0.2)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(px * math.max(3, #text * 0.62), px * 1.2)
	bb.LightInfluence = 0
	bb.MaxDistance = 200
	bb.AlwaysOnTop = false -- (AlwaysOnTop text doesn't show in Studio captures)
	bb.Parent = holder
	local l = Instance.new("TextLabel")
	styleLabel(l, text, o)
	l.Parent = bb
	local sc = Instance.new("UIScale")
	sc.Parent = l
	local rise = o.rise or math.max(4, h * 0.6)
	local drift = (math.random() - 0.5) * 2
	animate(life, function(t)
		sc.Scale = if t < 0.15
			then easeOut(t / 0.15, 2) * 1.35
			else 1.35 - 0.35 * easeOut(math.min(1, (t - 0.15) / 0.2))
		bb.StudsOffsetWorldSpace = Vector3.new(drift * t, rise * easeOut(t, 3), 0)
		local fade = math.max(0, (t - 0.65) / 0.35)
		l.TextTransparency = fade
		local st = l:FindFirstChildOfClass("UIStroke")
		if st then
			st.Transparency = fade
		end
	end)
	return bb
end

------------------------------------------------------------------------------------------------------------------
-- bursts

export type BurstOpts = {
	rarity: string?,
	mutation: string?,
	color: Color3?,
	scale: number?,
	sizeMult: number?,
	amount: number?,
	mine: boolean?,
}

-- The flipbook starburst + glow ball + sparks + light that every burst starts with
-- A neon ball that blows up and fades: the cartoon "pop" every burst starts with
local function orb(pos: Vector3, from: number, to: number, color: Color3, seconds: number)
	local p = Instance.new("Part")
	p.Name = "VfxOrb"
	p.Shape = Enum.PartType.Ball
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = Vector3.one * from
	p.CFrame = CFrame.new(pos)
	p.Transparency = 0.15
	p.Parent = fxFolder()
	animate(seconds, function(t)
		local e = easeOut(t, 3)
		p.Size = Vector3.one * (from + (to - from) * e)
		p.Transparency = 0.15 + 0.85 * t ^ 0.7
	end, function()
		p:Destroy()
	end)
end
VFX.orb = orb

-- The pop every burst starts with: neon orb, flipbook starburst, glow, speed-line sparks shooting out, sparkles, light
local function core(pos: Vector3, h: number, color: Color3 | ColorSequence, power: number, life: number?): Part
	local holder = anchor(pos, h * 0.8, life or 4)
	local c3 = if typeof(color) == "Color3" then color else Color3.fromRGB(255, 120, 200)
	orb(pos, h * 0.4, h * (1.6 + power * 0.45), c3, 0.3 + power * 0.03)
	emitter(holder, "Burst", {
		Color = colorSeq(color),
		LightEmission = 0.25,
		Brightness = 1.6,
		Lifetime = NumberRange.new(0.5),
		FlipbookFramerate = NumberRange.new(16 / 0.5),
		Speed = NumberRange.new(0),
		LockedToPart = true,
		Size = NumberSequence.new(h * (2.2 + power * 0.7)),
		Rotation = NumberRange.new(0, 360),
		ZOffset = h * 0.6,
	}):Emit(1)
	emitter(holder, "Burst", {
		Color = ColorSequence.new(WHITE),
		Lifetime = NumberRange.new(0.35),
		FlipbookFramerate = NumberRange.new(16 / 0.35),
		Speed = NumberRange.new(0),
		LockedToPart = true,
		Size = NumberSequence.new(h * (0.9 + power * 0.2)),
		Rotation = NumberRange.new(0, 360),
		ZOffset = h * 0.7,
	}):Emit(1)
	emitter(holder, "Glow", {
		Color = colorSeq(color),
		Lifetime = NumberRange.new(0.6),
		Speed = NumberRange.new(0),
		LockedToPart = true,
		Size = seq({ { 0, h * 1.2 }, { 1, h * (2 + power * 0.6) } }),
		Transparency = seq({ { 0, 0.6 }, { 1, 1 } }),
		ZOffset = h * 0.4,
	}):Emit(1)
	-- speed lines: stretched glows flying out along their velocity
	emitter(holder, "Glow", {
		Color = colorSeq(color),
		LightEmission = 0.5,
		Brightness = 2,
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		Squash = NumberSequence.new(2.6),
		Lifetime = NumberRange.new(0.3, 0.5),
		Speed = NumberRange.new(h * 6, h * (9 + power * 2)),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 5,
		Size = seq({ { 0, h * 0.45 }, { 1, h * 0.1 } }),
	}):Emit(count(10 + power * 6))
	emitter(holder, "Sparkle", {
		Color = colorSeq(color, true),
		Brightness = 1.5,
		Lifetime = NumberRange.new(0.6, 1.1),
		Speed = NumberRange.new(h * 2, h * (4 + power)),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 4,
		Size = seq({ { 0, h * 0.6, h * 0.2 }, { 1, 0 } }),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-180, 180),
	}):Emit(count(8 + power * 6))
	pointLight(holder, c3, 3 + power * 2, h * 5, 0.7 + power * 0.15)
	return holder
end

local function puff(pos: Vector3, h: number, n: number, color: Color3?)
	local holder = anchor(floorAt(pos) + Vector3.new(0, h * 0.15, 0), h * 0.9, 3)
	holder.Shape = Enum.PartType.Cylinder
	emitter(holder, "Puff", {
		Color = ColorSequence.new(color or Color3.fromRGB(235, 228, 255)),
		LightEmission = 0,
		LightInfluence = 0.6,
		Lifetime = NumberRange.new(0.6, 0.9),
		FlipbookFramerate = NumberRange.new(16 / 0.75),
		Speed = NumberRange.new(h * 0.6, h * 1.4),
		SpreadAngle = Vector2.new(80, 10),
		EmissionDirection = Enum.NormalId.Top,
		Drag = 3,
		Size = seq({ { 0, h * 0.5, h * 0.1 }, { 1, h * 0.9 } }),
		Rotation = NumberRange.new(0, 360),
		Acceleration = Vector3.new(0, h * 0.4, 0),
	}):Emit(count(n))
end

local function lightning(pos: Vector3, h: number, color: Color3, n: number, seconds: number)
	local holder = anchor(pos, h * 1.6, seconds + 1)
	holder.Shape = Enum.PartType.Ball
	local e = emitter(holder, "Electric", {
		Color = colorSeq(color, true),
		Lifetime = NumberRange.new(0.12, 0.2),
		FlipbookMode = Enum.ParticleFlipbookMode.Random,
		Speed = NumberRange.new(0),
		Size = NumberSequence.new(h * 1.5),
		Rotation = NumberRange.new(0, 360),
		Shape = Enum.ParticleEmitterShape.Sphere,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
	})
	local total = count(n)
	task.spawn(function()
		for _ = 1, total do
			e:Emit(1)
			task.wait(seconds / total)
		end
	end)
end

local function rays(pos: Vector3, h: number, color: Color3 | ColorSequence, seconds: number)
	local holder = anchor(pos, 1, seconds + 1)
	emitter(holder, "Rays", {
		Color = colorSeq(color),
		Lifetime = NumberRange.new(seconds),
		Speed = NumberRange.new(0),
		LockedToPart = true,
		Size = seq({ { 0, h * 1 }, { 0.15, h * 4.5 }, { 1, h * 5 } }),
		LightEmission = 0.4,
		Transparency = seq({ { 0, 1 }, { 0.1, 0.45 }, { 0.7, 0.6 }, { 1, 1 } }),
		RotSpeed = NumberRange.new(40),
		Rotation = NumberRange.new(0, 360),
		ZOffset = -h,
	}):Emit(1)
end

-- World confetti: paper squares, stars and hearts, each emitter its own colour (a particle's Color is over its
-- life, not per particle), so it's a real mix: the rarity colour plus the party colours
local function confettiWorld(pos: Vector3, h: number, n: number, color: Color3?)
	local holder = anchor(pos + Vector3.new(0, h * 0.4, 0), 1, 4)
	local palette = table.clone(CONFETTI_COLORS)
	if color then
		table.insert(palette, color)
		table.insert(palette, color)
	end
	local per = math.max(1, math.floor(count(n) / #palette + 0.5))
	for i, c in palette do
		local tex = if i % 3 == 0 then "Star" elseif i % 5 == 0 then "Heart" else "Square"
		emitter(holder, if tex == "Square" then "Glow" else tex, {
			Texture = if tex == "Square" then "rbxasset://textures/particles/SquareParticle.png" else nil,
			Color = ColorSequence.new(c),
			LightEmission = 0.2,
			LightInfluence = 0.4,
			Lifetime = NumberRange.new(1.6, 2.4),
			Speed = NumberRange.new(h * 2.5, h * 4.5),
			SpreadAngle = Vector2.new(60, 60),
			EmissionDirection = Enum.NormalId.Top,
			Acceleration = Vector3.new(0, -h * 2.2, 0),
			Drag = 1.5,
			Size = NumberSequence.new(h * (if tex == "Square" then 0.17 else 0.3)),
			Transparency = seq({ { 0, 0 }, { 0.8, 0 }, { 1, 1 } }),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-400, 400),
		}):Emit(per)
	end
end

local function coins(pos: Vector3, h: number, n: number)
	local holder = anchor(pos + Vector3.new(0, h * 0.3, 0), 1, 3)
	emitter(holder, "Coin", {
		LightEmission = 0.15,
		LightInfluence = 0.4,
		FlipbookMode = Enum.ParticleFlipbookMode.Loop,
		FlipbookFramerate = NumberRange.new(24, 36),
		FlipbookStartRandom = true,
		Lifetime = NumberRange.new(0.9, 1.3),
		Speed = NumberRange.new(h * 1.6, h * 2.8),
		SpreadAngle = Vector2.new(35, 35),
		EmissionDirection = Enum.NormalId.Top,
		Acceleration = Vector3.new(0, -h * 5, 0),
		Size = NumberSequence.new(h * 0.28),
		Transparency = seq({ { 0, 0 }, { 0.85, 0 }, { 1, 1 } }),
	}):Emit(count(n))
end
VFX.coins = coins

-- the special particle of each mutation, for its burst
local MUTATION_BITS: { [string]: { tex: string, n: number, up: boolean? } } = {
	Gold = { tex = "Coin", n = 14 },
	Candy = { tex = "Heart", n = 16 },
	Glitter = { tex = "Twinkle", n = 26 },
	Bubble = { tex = "Bubble", n = 16, up = true },
	Shadow = { tex = "Swirl", n = 6 },
	Frozen = { tex = "Snowflake", n = 18 },
	Rainbow = { tex = "Star", n = 24 },
	Cosmic = { tex = "Star", n = 20 },
	Glow = { tex = "Glow", n = 14, up = true },
	Haunted = { tex = "Flame", n = 10, up = true },
}

local function mutationBurst(pos: Vector3, h: number, id: string, mine: boolean)
	local color = VFX.mutationColor(id)
	local rainbow = id == "Rainbow"
	local c: Color3 | ColorSequence = if rainbow then RAINBOW else color
	local holder = core(pos, h, c, 2)
	local bits = MUTATION_BITS[id]
	if bits then
		local sheet = Assets.isSheet(bits.tex)
		emitter(holder, bits.tex, {
			Color = if bits.tex == "Coin" then ColorSequence.new(WHITE) else colorSeq(c, true),
			LightEmission = if bits.tex == "Coin" then 0.2 else 1,
			FlipbookMode = if sheet then Enum.ParticleFlipbookMode.Loop else nil,
			FlipbookFramerate = if sheet then NumberRange.new(20, 30) else nil,
			Lifetime = NumberRange.new(1, 1.6),
			Speed = NumberRange.new(h * 1.2, h * 2.6),
			SpreadAngle = if bits.up then Vector2.new(40, 40) else Vector2.new(180, 180),
			EmissionDirection = Enum.NormalId.Top,
			Drag = 2,
			Acceleration = Vector3.new(0, if bits.up then h * 0.8 else -h * 0.6, 0),
			Size = seq({ { 0, h * 0.3 }, { 0.8, h * 0.4 }, { 1, 0 } }),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-120, 120),
		}):Emit(count(bits.n))
	end
	if id == "Shadow" or id == "Cosmic" then
		lightning(
			pos,
			h,
			if id == "Shadow" then Color3.fromRGB(155, 92, 255) else Color3.fromRGB(255, 240, 168),
			8,
			0.6
		)
		floorDecal(pos, "Swirl", color, h * 1.5, h * 5, 1.2, { spin = 4, alpha = 0.2 })
	end
	floorDecal(pos, "Shock", color, h, h * 6, 0.8, { rainbow = rainbow })
	local name = (MutationData.List[id] and MutationData.List[id].Name or id):upper() .. "!"
	VFX.popText(name, pos + Vector3.new(0, h * 0.6, 0), {
		color = color,
		size = 46,
		duration = 1.8,
		gradient = if rainbow then RAINBOW else nil,
	})
	if mine then
		VFX.flash(color, 0.35, 0.5)
		VFX.shake(0.4, 0.4)
	end
end

local BURSTS: { [string]: (pos: Vector3, h: number, o: BurstOpts) -> () } = {}

-- The hatch pay-off: everything at once, scaled by rarity, then the mutation and the size on top
BURSTS.Hatch = function(pos, h, o)
	local rarity = o.rarity or "Common"
	local tier = VFX.tier(rarity)
	local secret = rarity == "Secret"
	local color = VFX.rarityColor(rarity)
	local c: Color3 | ColorSequence = if secret then RAINBOW else color
	local big = (o.sizeMult or 1)
	h = math.max(h, 4)
	local power = tier.n / 2 + (big - 1)
	local mid = pos + Vector3.new(0, h * 0.45, 0)
	core(mid, h, c, power)
	puff(pos, h, 6 + tier.n)
	for i = 1, tier.rings do
		floorDecal(pos, if i == 1 then "Shock" else "Ring", color, h, h * (4 + i * 2.2 + big), 0.7 + i * 0.15, {
			delay = (i - 1) * 0.12,
			rainbow = secret,
		})
	end
	if tier.beams > 0 then
		VFX.beams(pos, c, tier.beams, 1.2 + tier.n * 0.15, h * (3 + tier.n * 0.8))
	end
	if tier.confetti > 0 then
		confettiWorld(mid, h, tier.confetti, if secret then nil else color)
	end
	if tier.rays then
		rays(mid, h, c, 1.4 + tier.n * 0.2)
	end
	if tier.lightning then
		lightning(mid, h, color, 10 + (tier.n - 5) * 6, 1.2)
		-- a second wave a beat later
		task.delay(0.35, function()
			orb(mid, h * 0.5, h * (3 + power * 0.6), color, 0.4)
			floorDecal(pos, "Shock", color, h * 2, h * 10, 1, { rainbow = secret })
		end)
		-- a pillar that stays a moment
		VFX.beams(pos, c, 1, 2.6, h * 14)
	end
	if o.mutation then
		task.delay(0.45, function()
			mutationBurst(mid, h, o.mutation :: string, o.mine == true)
		end)
	end
	if big > 1.15 then
		task.delay(0.25, function()
			floorDecal(pos, "Shock", WHITE, h * 2, h * (8 + big * 3), 0.9)
			puff(pos, h * big, 12)
			VFX.popText(if big >= 2 then "GIANT!" elseif big >= 1.5 then "HUGE!" else "BIG!", mid, {
				color = GOLD,
				size = 40 + 10 * big,
				duration = 1.6,
			})
			if o.mine then
				VFX.shake(math.min(1, 0.3 + big * 0.25), 0.6)
			end
		end)
	end
end

BURSTS.LevelUp = function(pos, h, o)
	local color = o.color or GOLD
	local mid = pos + Vector3.new(0, h * 0.4, 0)
	core(mid, h, color, 3)
	VFX.beams(pos, color, 8, 1.8, h * 4)
	floorDecal(pos, "Shock", color, h, h * 7, 0.8)
	floorDecal(pos, "Ring", WHITE, h * 0.5, h * 5, 1, { delay = 0.15 })
	confettiWorld(mid, h, 60)
	rays(mid, h, color, 1.6)
	puff(pos, h, 10)
end

BURSTS.Cash = function(pos, h, o)
	local n = math.clamp(math.floor(math.log10(math.max(10, o.amount or 100)) * 3), 3, 16)
	coins(pos, h, n)
	local holder = anchor(pos + Vector3.new(0, h * 0.4, 0), 1, 2)
	emitter(holder, "Twinkle", {
		Color = ColorSequence.new(GOLD, WHITE),
		Lifetime = NumberRange.new(0.4, 0.7),
		FlipbookFramerate = NumberRange.new(16 / 0.55),
		Speed = NumberRange.new(h * 0.8, h * 1.6),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 3,
		Size = NumberSequence.new(h * 0.35),
	}):Emit(count(6))
end

BURSTS.Steal = function(pos, h, o)
	local color = o.color or Color3.fromRGB(255, 140, 40)
	core(pos + Vector3.new(0, h * 0.4, 0), h, color, 1.5)
	puff(pos, h, 8)
	floorDecal(pos, "Shock", color, h, h * 4, 0.6)
end

BURSTS.Stolen = function(pos, h, o)
	local color = o.color or RED
	local mid = pos + Vector3.new(0, h * 0.4, 0)
	core(mid, h, color, 3)
	lightning(mid, h, color, 8, 0.6)
	floorDecal(pos, "Shock", color, h, h * 8, 0.9)
	floorDecal(pos, "Ring", color, h * 0.5, h * 6, 1.1, { delay = 0.15 })
	VFX.beams(pos, color, 6, 1.4, h * 4)
end

BURSTS.Recovered = function(pos, h, o)
	local color = o.color or GREEN
	core(pos + Vector3.new(0, h * 0.4, 0), h, color, 2)
	floorDecal(pos, "Shock", color, h, h * 5, 0.7)
	VFX.beams(pos, color, 4, 1.2, h * 3)
	confettiWorld(pos, h, 24, color)
end

BURSTS.Poof = function(pos, h, o)
	puff(pos, h, 8, o.color)
end

BURSTS.Sparkle = function(pos, h, o)
	local holder = anchor(pos, h * 0.6, 2)
	emitter(holder, "Twinkle", {
		Color = colorSeq(o.color or WHITE, true),
		Lifetime = NumberRange.new(0.5, 0.8),
		FlipbookFramerate = NumberRange.new(16 / 0.65),
		Speed = NumberRange.new(h * 0.4, h),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 2,
		Size = NumberSequence.new(h * 0.45),
		Shape = Enum.ParticleEmitterShape.Sphere,
	}):Emit(count(8))
end

BURSTS.Shockwave = function(pos, h, o)
	floorDecal(pos, "Shock", o.color or WHITE, h, h * 5 * (o.scale or 1), 0.7)
end

function VFX.burst(kind: string, at: any, opts: BurstOpts?)
	local fn = BURSTS[kind]
	if not fn then
		warn("VFX.burst: no burst called", kind)
		return
	end
	local o = opts or {}
	local pos, h = where(at)
	h = h * (o.scale or 1)
	local ok, err = pcall(fn, pos, math.max(h, 2), o)
	if not ok then
		warn("VFX.burst", kind, err)
	end
end

------------------------------------------------------------------------------------------------------------------
-- The hatch build-up (pass a local copy of the blanket; it's destroyed at the end): it shakes harder and harder, glows white then the rarity colour,
-- sucks sparkles in, light beams creep out, the screen edges close in; then `done` (where the burst goes).

function VFX.hatchCharge(blanket: Model, rarity: string?, done: (at: Vector3, height: number) -> ())
	local tier = VFX.tier(rarity)
	local seconds = tier.build * (if low() then 0.6 else 1)
	local color = VFX.rarityColor(rarity)
	local secret = rarity == "Secret"
	local copy = blanket
	for _, d in copy:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		elseif d:IsA("ProximityPrompt") or d:IsA("BillboardGui") or d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		end
	end
	local rest = copy:GetPivot()
	local _, size = copy:GetBoundingBox()
	local h = math.max(3, size.Y)
	local center = rest.Position + Vector3.new(0, h * 0.5, 0)
	copy.Name = "HatchingBlanket"
	copy.Parent = fxFolder()
	VFX.hatchBegin()
	local baseScale = copy:GetScale()

	-- sparkles pulled in from a sphere around it
	local suck = anchor(center, h * 3.2, seconds + 1)
	local pull = emitter(suck, "Twinkle", {
		Color = ColorSequence.new(WHITE),
		Lifetime = NumberRange.new(0.45),
		FlipbookMode = Enum.ParticleFlipbookMode.Loop,
		FlipbookFramerate = NumberRange.new(30),
		Speed = NumberRange.new(h * 3.2),
		Shape = Enum.ParticleEmitterShape.Sphere,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
		Size = seq({ { 0, h * 0.15 }, { 1, h * 0.35 } }),
		Transparency = seq({ { 0, 1 }, { 0.3, 0 }, { 1, 0.2 } }),
	})
	pull.Enabled = true
	local glow = emitter(suck, "Glow", {
		Color = ColorSequence.new(WHITE),
		Lifetime = NumberRange.new(0.25),
		Speed = NumberRange.new(0),
		LockedToPart = true,
		Size = NumberSequence.new(h * 1.6),
		Transparency = seq({ { 0, 0.6 }, { 1, 1 } }),
		ZOffset = h,
	})
	glow.Enabled = true
	glow.Rate = 0
	local light = Instance.new("PointLight")
	light.Range = math.min(60, h * 6)
	light.Shadows = false
	light.Brightness = 0
	light.Parent = suck
	floorDecal(rest.Position, "Ring", color, h * 5, h * 1.2, seconds, { alpha = 0.3, spin = 3, rainbow = secret })

	local beams = {}
	if tier.beams > 0 and not low() then
		local holder = anchor(rest.Position, 1, seconds + 1)
		for i = 1, math.min(6, tier.beams) do
			local a0 = Instance.new("Attachment")
			a0.Parent = holder
			local a1 = Instance.new("Attachment")
			local ang = i / math.min(6, tier.beams) * math.pi * 2
			a1.Position = Vector3.new(math.cos(ang) * 0.3, 1, math.sin(ang) * 0.3).Unit * h * 4
			a1.Parent = holder
			local b = Instance.new("Beam")
			b.Attachment0 = a0
			b.Attachment1 = a1
			b.Texture = Assets.get("Beam")
			b.LightEmission = 1
			b.LightInfluence = 0
			b.FaceCamera = true
			b.Color = ColorSequence.new(WHITE)
			b.Transparency = seq({ { 0, 0.2 }, { 1, 1 } })
			b.Width0 = 0
			b.Width1 = 0
			b.Parent = holder
			table.insert(beams, { b = b, at = (i - 1) / math.min(6, tier.beams) })
		end
	end

	if tier.n >= 3 then
		VFX.vignette(color, 0.25 + tier.n * 0.05, seconds + 0.3)
	end
	animate(seconds, function(p)
		local k = p * p
		local now = os.clock()
		-- shake: faster and wider, little hops near the end
		local amp = h * (0.03 + 0.12 * k)
		local hop = if p > 0.6 then math.abs(math.sin(now * 22)) * h * 0.12 * (p - 0.6) / 0.4 else 0
		copy:PivotTo(
			rest
				* CFrame.new(math.noise(now * 30, 1) * amp, hop, math.noise(now * 30, 5) * amp)
				* CFrame.Angles(math.noise(now * 25, 9) * 0.25 * k, 0, math.noise(now * 25, 13) * 0.25 * k)
		)
		copy:ScaleTo(baseScale * (1 + 0.18 * k + 0.04 * math.sin(now * 40) * k))
		-- white, then the rarity colour shows through (the tease)
		local c = if secret then Color3.fromHSV((now * 1.5) % 1, 0.7, 1) else WHITE:Lerp(color, math.min(1, p * 1.6))
		pull.Color = ColorSequence.new(c)
		pull.Rate = 20 + 120 * k * (if low() then 0.3 else 1)
		glow.Color = ColorSequence.new(c)
		glow.Rate = 4 + 30 * k
		light.Color = c
		light.Brightness = 1 + 6 * k
		for _, b in beams do
			local on = math.clamp((p - b.at * 0.6) / 0.25, 0, 1)
			b.b.Width0 = h * 0.15 * on
			b.b.Width1 = h * 0.5 * on
			b.b.Color = ColorSequence.new(c)
		end
		if tier.n >= 2 then
			VFX.shake(0.05 + 0.25 * k * tier.n / 7, 0.2)
		end
	end, function()
		copy:Destroy()
		pull.Enabled = false
		glow.Enabled = false
		suck:Destroy()
		done(rest.Position, h)
	end)
	return seconds
end

------------------------------------------------------------------------------------------------------------------
-- Your own hatch, start to finish: VfxClient starts it when the Hatch prompt fires, and while it charges up the new
-- pen toy (ToyVFX.revealBurst -> VFX.holdReveal) and the reveal card (GameUI -> VFX.afterHatch) wait for the burst.

local hatch = { active = false, t = 0, toys = {} :: { { model: Model, scale: number } }, cards = {} :: { () -> () } }

function VFX.hatchBegin()
	hatch.active = true
	hatch.t = os.clock()
end

function VFX.hatching(): boolean
	return hatch.active and os.clock() - hatch.t < 8
end

-- a toy that just woke up in a pen: if it's ours and we're charging, hide it until the burst. true = held back.
function VFX.holdReveal(model: Model): boolean
	if not VFX.hatching() or model:GetAttribute("Owner") ~= me.UserId then
		return false
	end
	local scale = model:GetScale()
	table.insert(hatch.toys, { model = model, scale = scale })
	model:ScaleTo(scale * 0.01)
	return true
end

-- run fn when our hatch bursts (or now, if we aren't hatching)
function VFX.afterHatch(fn: () -> ())
	if VFX.hatching() then
		table.insert(hatch.cards, fn)
	else
		task.spawn(fn)
	end
end

-- the burst: show the held toys again (returned, to pop in) and the card
function VFX.hatchEnd(): { Model }
	hatch.active = false
	local toys = {}
	for _, t in hatch.toys do
		if t.model.Parent then
			t.model:ScaleTo(t.scale)
			table.insert(toys, t.model)
		end
	end
	for _, t in toys do
		t:SetAttribute("VfxHeld", nil)
	end
	hatch.toys = {}
	local cards = hatch.cards
	hatch.cards = {}
	for _, fn in cards do
		task.spawn(fn)
	end
	return toys
end

------------------------------------------------------------------------------------------------------------------
-- UI juice

local function uiScale(g: GuiObject): UIScale
	local s = g:FindFirstChild("VfxPop")
	if s and s:IsA("UIScale") then
		return s
	end
	local n = Instance.new("UIScale")
	n.Name = "VfxPop"
	n.Parent = g
	return n
end

-- a bounce: up to 1 + amount and spring back
function VFX.uiPop(g: GuiObject, amount: number?)
	local s = uiScale(g)
	local a = amount or 0.15
	s.Scale = 1 + a
	TweenService:Create(s, TweenInfo.new(0.45, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
end

-- a white shine that sweeps across a frame (reveal card, bought upgrade, claimable reward)
function VFX.shine(g: GuiObject, seconds: number?)
	local f = Instance.new("Frame")
	f.Name = "VfxShine"
	f.BackgroundColor3 = WHITE
	f.BorderSizePixel = 0
	f.Size = UDim2.fromScale(1, 1)
	f.ZIndex = g.ZIndex + 5
	local corner = g:FindFirstChildOfClass("UICorner")
	if corner then
		corner:Clone().Parent = f
	end
	local grad = Instance.new("UIGradient")
	grad.Rotation = 25
	grad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.42, 1),
		NumberSequenceKeypoint.new(0.5, 0.35),
		NumberSequenceKeypoint.new(0.58, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	grad.Offset = Vector2.new(-1, 0)
	grad.Parent = f
	f.Parent = g
	local t = TweenService:Create(
		grad,
		TweenInfo.new(seconds or 0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
		{ Offset = Vector2.new(1, 0) }
	)
	t.Completed:Once(function()
		f:Destroy()
	end)
	t:Play()
end

-- squash on press, pop on release, a sparkle where you clicked (UIKit already grows buttons on hover)
local pressed = setmetatable({}, { __mode = "k" }) :: any
function VFX.uiPress(button: GuiButton, holder: GuiObject?)
	if pressed[button] then
		return
	end
	pressed[button] = true
	local target = holder or button
	button.Activated:Connect(function(input: InputObject?)
		VFX.uiPop(target, 0.1)
		local p = if input and input.Position then input.Position else nil
		local c = if p then Vector2.new(p.X, p.Y) else target.AbsolutePosition + target.AbsoluteSize / 2
		VFX.uiSparks(UDim2.fromOffset(c.X, c.Y), 6)
		Moments.fire("UIClick", { button = button })
	end)
end

-- little stars that spray out of a point on the screen
function VFX.uiSparks(at: UDim2, n: number?, color: Color3?)
	local layer = screen("Over")
	local list = {}
	for _ = 1, count(n or 6) do
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Image = Assets.get("Sparkle")
		img.ImageColor3 = color or Color3.fromRGB(255, 240, 160)
		img.AnchorPoint = Vector2.new(0.5, 0.5)
		img.Size = UDim2.fromOffset(22, 22)
		img.Position = at
		img.Parent = layer
		local a = math.random() * math.pi * 2
		table.insert(list, { img = img, v = Vector2.new(math.cos(a), math.sin(a)) * math.random(60, 140) })
	end
	animate(0.45, function(t)
		for _, s in list do
			local d = s.v * easeOut(t, 2)
			s.img.Position = at + UDim2.fromOffset(d.X, d.Y)
			s.img.ImageTransparency = t
			s.img.Size = UDim2.fromOffset(22 * (1 - t * 0.6), 22 * (1 - t * 0.6))
		end
	end, function()
		for _, s in list do
			s.img:Destroy()
		end
	end)
end

-- count a number up, then bounce it
function VFX.countTo(label: TextLabel, from: number, to: number, seconds: number, format: (number) -> string)
	animate(seconds, function(t)
		label.Text = format(from + (to - from) * easeOut(t, 4))
	end, function()
		label.Text = format(to)
		VFX.uiPop(label, 0.18)
	end)
end

-- The reveal card's extra juice: spinning rarity rays behind it, a punch, a shine sweep, the rarity line
-- bouncing in, and for Mythic/Secret a shake and a rainbow line. card = the card's content frame.
function VFX.revealCard(card: GuiObject, info: any, parts: { rarityLabel: TextLabel?, cashLabel: TextLabel? }?)
	local rarity = info.rarity or "Common"
	local tier = VFX.tier(rarity)
	local color = VFX.rarityColor(rarity)
	local p = parts or {}
	-- big rarity rays behind everything, spinning
	local rayImg = Instance.new("ImageLabel")
	rayImg.Name = "VfxRays"
	rayImg.BackgroundTransparency = 1
	rayImg.Image = Assets.get("Rays")
	rayImg.ImageColor3 = color
	rayImg.ImageTransparency = 1
	rayImg.AnchorPoint = Vector2.new(0.5, 0.5)
	rayImg.Position = UDim2.fromOffset(210, 120)
	rayImg.Size = UDim2.fromOffset(300 + tier.n * 50, 300 + tier.n * 50)
	rayImg.ZIndex = 1
	rayImg.Parent = card
	local glow = rayImg:Clone()
	glow.Name = "VfxGlow"
	glow.Image = Assets.get("Glow")
	glow.Size = UDim2.fromOffset(260 + tier.n * 30, 260 + tier.n * 30)
	glow.Parent = card
	local secret = rarity == "Secret"
	task.spawn(function()
		local t0 = os.clock()
		while rayImg.Parent do
			local t = os.clock() - t0
			rayImg.Rotation = t * (25 + tier.n * 8)
			rayImg.ImageTransparency = 1 - math.min(1, t * 4) * (0.25 + tier.n * 0.06)
			glow.ImageTransparency = 1 - math.min(1, t * 4) * 0.45
			if secret then
				local c = Color3.fromHSV((t * 0.5) % 1, 0.7, 1)
				rayImg.ImageColor3 = c
				glow.ImageColor3 = c
			end
			RunService.RenderStepped:Wait()
		end
	end)
	task.delay(0.3, function()
		VFX.shine(card, 0.7)
	end)
	if p.rarityLabel then
		local l = p.rarityLabel
		local s = uiScale(l)
		s.Scale = 0
		task.delay(0.25, function()
			TweenService
				:Create(s, TweenInfo.new(0.5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { Scale = 1 })
				:Play()
		end)
		if secret or info.mutation == "Rainbow" then
			local g = Instance.new("UIGradient")
			g.Color = RAINBOW
			g.Parent = l
			task.spawn(function()
				while g.Parent do
					g.Offset = Vector2.new(math.sin(os.clock() * 2) * 0.5, 0)
					RunService.RenderStepped:Wait()
				end
			end)
		end
	end
	if p.cashLabel then
		local l = p.cashLabel
		local final = l.Text
		local target = info.perSecond or 0
		task.delay(0.35, function()
			if l.Parent then
				VFX.countTo(l, 0, target, 0.6, function(v)
					return "+" .. VFX.money(v) .. "/s"
				end)
				task.delay(0.65, function()
					l.Text = final
				end)
			end
		end)
	end
	if tier.n >= 6 then
		-- the card itself shudders for a moment
		local base = card.Position
		animate(0.6, function(t)
			local a = (1 - t) * 8
			card.Position = base + UDim2.fromOffset(math.noise(t * 40, 1) * a, math.noise(t * 40, 4) * a)
		end, function()
			card.Position = base
		end)
	end
	if tier.n >= 4 then
		local c = card.AbsolutePosition + card.AbsoluteSize / 2
		for i = 1, 3 do
			task.delay(0.1 * i, function()
				VFX.uiSparks(UDim2.fromOffset(c.X + math.random(-150, 150), c.Y + math.random(-80, 80)), 8, color)
			end)
		end
	end
end

-- "$1.2K" (the same short money format as GameConfig.money, kept here so VFX doesn't need GameConfig)
function VFX.money(n: number): string
	local ok, GameConfig = pcall(require, Shared:FindFirstChild("GameConfig") :: ModuleScript)
	if ok and GameConfig and (GameConfig :: any).money then
		return (GameConfig :: any).money(n)
	end
	return "$" .. tostring(math.floor(n))
end

return VFX
