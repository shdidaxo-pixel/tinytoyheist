--!strict
-- The homes, alive: toys roam their pens (ReplicatedStorage.Shared.PenRoam, on the server clock), the Speed wheels
-- spin faster with the level, the fairy lights twinkle, and the floating signs bob. Your own home's sign reads
-- YOUR HOME in gold with an arrow over it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MapConfig = require(Shared:WaitForChild("MapConfig")) :: any
local PenRoam = require(Shared:WaitForChild("PenRoam")) :: any

local HomeView = {}
HomeView.NEAR = 600 -- only animate homes this close to the camera (the whole curve from the safe zone)

local GOLD = Color3.fromRGB(255, 201, 60)

local function seedOf(toy: Instance): number
	local seed = toy:GetAttribute("RoamSeed")
	if typeof(seed) == "number" then
		return seed
	end
	local h = 0
	for i = 1, #toy.Name do
		h = (h * 31 + string.byte(toy.Name, i)) % 100003
	end
	return h
end

-- Toys keep out of each other's way: each one walks its PenRoam path, plus a sideways nudge (on this screen only)
-- when it is about to bump into another toy. It looks LOOK seconds ahead, so toys step round each other instead of
-- walking through and then sliding apart. The nudge stays within NUDGE studs (plus half its Reach), well inside the
-- server's steal reach (30 + Reach).
HomeView.NUDGE = 10
HomeView.LOOK = 0.6
HomeView.NUDGE_SPEED = 6 -- studs a second the nudge can change by (on top of the walk), so nothing jumps
HomeView.TURN_RATE = 8 -- radians a second a toy turns at most
local nudges: { [Model]: Vector3 } = setmetatable({}, { __mode = "k" }) :: any
local facings: { [Model]: Vector3 } = setmetatable({}, { __mode = "k" }) :: any
type Roamer = {
	toy: Model,
	p: Vector3,
	q: Vector3,
	dir: Vector3,
	speed: number,
	r: number,
	reach: number?,
	push: Vector3,
}

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function roamPen(frame: CFrame, pen: BasePart, toys: Instance, t: number, dt: number)
	local penMin = pen:GetAttribute("PenMin") :: Vector3
	local penMax = pen:GetAttribute("PenMax") :: Vector3
	local top = (pen:GetAttribute("PenTop") :: number?) or 0.8
	local list: { Roamer } = {}
	for _, toy in toys:GetChildren() do
		if toy:IsA("Model") then
			local size = toy:GetAttribute("Size")
			local reach = toy:GetAttribute("Reach")
			local r = if typeof(reach) == "number" then reach else nil
			local s = if typeof(size) == "string" then size else "M"
			local seed = seedOf(toy)
			local p, dir, speed = PenRoam.pose(seed, t, penMin, penMax, s, r)
			local q = PenRoam.pose(seed, t + HomeView.LOOK, penMin, penMax, s, r)
			local n = nudges[toy] or Vector3.zero
			table.insert(list, {
				toy = toy,
				p = p,
				q = flat(q + n),
				dir = dir,
				speed = speed,
				r = math.max(r or 3, 2),
				reach = r,
				push = Vector3.zero,
			})
		end
	end
	-- pairs that are (or are about to be) too close push apart, mostly sideways to the way they walk
	for i = 1, #list do
		local a = list[i]
		local pa = flat(a.p + (nudges[a.toy] or Vector3.zero))
		for j = i + 1, #list do
			local b = list[j]
			local gap = (a.r + b.r) * 0.9
			local now = pa - flat(b.p + (nudges[b.toy] or Vector3.zero))
			local soon = a.q - b.q
			local d = if soon.Magnitude < now.Magnitude then soon else now
			local dist = d.Magnitude
			if dist < gap then
				local n = if dist > 1e-3 then d / dist else Vector3.new(1, 0, 0)
				local side = Vector3.new(-a.dir.Z, 0, a.dir.X)
				if side:Dot(n) < 0 then
					side = -side
				end
				local push = (n + side).Unit * (gap - dist) * 0.5
				a.push += push
				b.push -= push
			end
		end
	end
	local ease = math.min(1, dt * 8)
	for _, e in list do
		local nudge = nudges[e.toy] or Vector3.zero
		-- step into the push, drift back onto the path when clear
		local step = e.push * ease - nudge * math.min(1, dt * 0.6)
		if step.Magnitude > HomeView.NUDGE_SPEED * dt then
			step = step.Unit * HomeView.NUDGE_SPEED * dt
		end
		local old = nudge
		nudge += step
		-- a big toy (Huge, Giant) may step further aside: it's wider, and the server allows 30 + Reach
		local cap = HomeView.NUDGE + e.r * 0.5
		if nudge.Magnitude > cap then
			nudge = nudge.Unit * cap
		end
		nudges[e.toy] = nudge
		local box = PenRoam.box(penMin, penMax, e.reach)
		local x = math.clamp(e.p.X + nudge.X, box.x0, box.x1)
		local z = math.clamp(e.p.Z + nudge.Z, box.z0, box.z1)
		local at = (frame * CFrame.new(x, top + e.p.Y, z)).Position
		-- face the way it really goes (the walk plus a bit of any sidestep), turning at most TURN_RATE
		local want = e.dir
		if e.speed > 0.5 and dt > 0 then
			local v = e.dir * math.max(e.speed, 2) + (nudge - old) / dt * 0.5
			if v.Magnitude > 0.5 then
				want = v.Unit
			end
		end
		local heading = facings[e.toy] or want
		local a0, a1 = math.atan2(heading.X, heading.Z), math.atan2(want.X, want.Z)
		local da = (a1 - a0 + math.pi) % (2 * math.pi) - math.pi
		local a = a0 + math.clamp(da, -HomeView.TURN_RATE * dt, HomeView.TURN_RATE * dt)
		heading = Vector3.new(math.sin(a), 0, math.cos(a))
		facings[e.toy] = heading
		local facing = frame:VectorToWorldSpace(heading)
		e.toy:PivotTo(CFrame.lookAt(at, at + facing))
	end
end

function HomeView.start(bedroom: Model)
	local holes = bedroom:WaitForChild("Holes")
	local me = Players.LocalPlayer
	local homes = {}
	for _, hole in holes:GetChildren() do
		local index = hole:GetAttribute("HoleIndex")
		if hole:IsA("Model") and typeof(index) == "number" then
			local sign = hole:WaitForChild("Sign") :: BasePart
			table.insert(homes, {
				hole = hole,
				index = index,
				frame = MapConfig.homeFrame(index),
				sign = sign,
				signRest = sign.CFrame,
				wheel = nil :: Model?,
				wheelRest = CFrame.new(),
				angle = 0,
			})
		end
	end

	-- your home's sign: YOUR HOME in gold, and a bobbing arrow
	local arrow = Instance.new("BillboardGui")
	arrow.Name = "YourHomeArrow"
	arrow.Size = UDim2.fromScale(12, 12)
	arrow.StudsOffset = Vector3.new(0, 24, 0)
	arrow.LightInfluence = 0
	arrow.MaxDistance = 1200
	local arrowText = Instance.new("TextLabel")
	arrowText.Size = UDim2.fromScale(1, 1)
	arrowText.BackgroundTransparency = 1
	arrowText.Text = "▼"
	arrowText.TextScaled = true
	arrowText.Font = Enum.Font.GothamBlack
	arrowText.TextColor3 = GOLD
	arrowText.Parent = arrow
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(26, 20, 48)
	stroke.Parent = arrowText
	local function markMine()
		for _, h in homes do
			local gui = h.sign:FindFirstChild("SignGui")
			local title = gui and gui:FindFirstChild("Title") :: TextLabel?
			if h.hole:GetAttribute("Owner") == me.UserId then
				arrow.Parent = h.sign
				if title then
					title.Text = "YOUR HOME"
					title.TextColor3 = GOLD
				end
			end
		end
	end
	for _, h in homes do
		h.hole:GetAttributeChangedSignal("Owner"):Connect(markMine)
		local gui = h.sign:WaitForChild("SignGui", 10)
		local title = gui and gui:FindFirstChild("Title") :: TextLabel?
		if title then
			title:GetPropertyChangedSignal("Text"):Connect(function()
				if h.hole:GetAttribute("Owner") == me.UserId and title.Text ~= "YOUR HOME" then
					markMine()
				end
			end)
		end
	end
	markMine()

	RunService.RenderStepped:Connect(function(dt)
		local t = Workspace:GetServerTimeNow()
		local camera = Workspace.CurrentCamera
		local eye = if camera then camera.CFrame.Position else Vector3.zero
		for _, h in homes do
			-- the sign bobs gently
			h.sign.CFrame = h.signRest * CFrame.new(0, math.sin(t * 1.6 + h.index) * 1.2, 0)
			if (eye - h.frame.Position).Magnitude > HomeView.NEAR then
				continue
			end
			local hole = h.hole
			-- toys roaming the pen
			local pen = hole:FindFirstChild("Pen") :: BasePart?
			local toys = hole:FindFirstChild("PenToys")
			if pen and toys then
				roamPen(h.frame, pen, toys, t, dt)
			end
			-- the Speed wheel (rebuilt on level up, so look it up each time)
			local holder = hole:FindFirstChild("TrainingWheel")
			local wheel = holder and holder:FindFirstChild("Wheel") :: Model?
			if wheel and wheel ~= h.wheel then
				h.wheel = wheel
				h.wheelRest = wheel:GetPivot()
				h.angle = 0
			end
			if wheel then
				h.angle -= ((wheel:GetAttribute("Spin") :: number?) or 1.5) * dt
				wheel:PivotTo(h.wheelRest * CFrame.Angles(h.angle, 0, 0))
			end
			-- fairy lights twinkle
			local fairy = hole:FindFirstChild("FairyLight")
			if fairy then
				for k, bulb in fairy:GetChildren() do
					if bulb:IsA("BasePart") and bulb.Name == "Bulb" then
						bulb.Transparency = 0.25 + 0.25 * math.sin(t * 2 + k * 1.3 + h.index)
					end
				end
			end
		end
	end)
end

return HomeView
