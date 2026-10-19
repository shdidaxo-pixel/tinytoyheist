--!strict
-- The home upgrade build-up (Dylan picked it from the bases renders, 19 Oct): when a home's Level goes up, its old toy
-- fence pops up and tumbles away piece by piece from the front to the back, the new fence drops in with a bounce in the
-- same order, the new dressing drops into place, and the corner posts land last with a ring on the floor. About 1.3 s.
-- Everyone nearby sees it, not just the owner.
--
-- Client only: the server swaps the parts at once (Homes.relevel). This keeps a local copy of each home's fence to
-- throw away, and moves the new parts on this screen only (pieces carry U, 0 at the front to 1 at the back, 1.1 for the
-- corner posts; tools/bedroom/Homes.luau buildFence).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MapConfig = require(Shared:WaitForChild("MapConfig")) :: any
local VFX = require(Shared:WaitForChild("VFX")) :: any

local S = MapConfig.SCALE
local GOLD = Color3.fromRGB(255, 214, 80)
local holes = Workspace:WaitForChild("Bedroom"):WaitForChild("Holes")
local debris = Instance.new("Folder")
debris.Name = "UpgradeDebris"
debris.Parent = Workspace

local POP_SPREAD, POP_TIME = 0.3, 0.38 -- the old pieces leave over 0.3 s, front first
local DROP_START, DROP_SPREAD, DROP_TIME = 0.4, 0.5, 0.28 -- the new ones land from 0.4 s, front first
local POST_START, POST_TIME = 0.92, 0.33 -- the corner posts land last, at 1.25 s
local DRESS_START = 1.0 -- the new dressing drops in just before the posts
local DONE = 1.6

local function ease(p: number): number
	return 1 - (1 - p) ^ 3
end

local function bounce(p: number): number
	local n, d = 7.5625, 2.75
	if p < 1 / d then
		return n * p * p
	elseif p < 2 / d then
		p -= 1.5 / d
		return n * p * p + 0.75
	elseif p < 2.5 / d then
		p -= 2.25 / d
		return n * p * p + 0.9375
	end
	p -= 2.625 / d
	return n * p * p + 0.984375
end

local function parts(root: Instance): { BasePart }
	local out = {}
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(out, d)
		end
	end
	return out
end

-- The fence and dressing as they are now, once the server has finished building them (they arrive in pieces)
local function settled(hole: Instance, name: string): Instance?
	local last, steady = -1, 0
	for _ = 1, 40 do
		local folder = hole:FindFirstChild(name)
		local count = if folder then #parts(folder) else -1
		if count > 0 and count == last then
			steady += 1
			if steady >= 2 then
				return folder
			end
		else
			steady = 0
		end
		last = count
		task.wait(0.05)
	end
	return hole:FindFirstChild(name)
end

type Piece = {
	part: BasePart,
	cf: CFrame,
	size: Vector3,
	transparency: number,
	start: number,
	time: number,
	drop: number,
	spin: Vector3?,
}

local function play(hole: Instance, oldFence: Instance?, newFence: Instance, dressing: Instance?)
	local pieces: { Piece } = {}
	local rng = Random.new()
	-- the old fence: a local copy, thrown up and away
	if oldFence then
		oldFence.Parent = debris
		for _, p in parts(oldFence) do
			local u = math.min((p:GetAttribute("U") :: number?) or 0.5, 1.1)
			local spin = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1))
			table.insert(pieces, {
				part = p,
				cf = p.CFrame,
				size = p.Size,
				transparency = p.Transparency,
				start = POP_SPREAD * u,
				time = POP_TIME,
				drop = 0,
				spin = spin,
			})
		end
	end
	-- the new fence and dressing: hidden, then dropped into place
	local function drop(p: BasePart, start: number, time: number, height: number)
		table.insert(pieces, {
			part = p,
			cf = p.CFrame,
			size = p.Size,
			transparency = p.Transparency,
			start = start,
			time = time,
			drop = height,
		})
		p.LocalTransparencyModifier = 1
	end
	for _, p in parts(newFence) do
		local u = (p:GetAttribute("U") :: number?) or 0.5
		if u > 1 then
			drop(p, POST_START, POST_TIME, 70 * S)
		else
			drop(p, DROP_START + DROP_SPREAD * u, DROP_TIME, 42 * S)
		end
	end
	if dressing then
		for _, p in parts(dressing) do
			drop(p, DRESS_START, 0.3, 30 * S)
		end
	end

	local t0 = os.clock()
	local landed = false
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		-- Workspace attribute UpgradeSlowMo (Studio captures): play it that many times slower
		local slow = Workspace:GetAttribute("UpgradeSlowMo")
		local t = (os.clock() - t0) / (if typeof(slow) == "number" and slow > 0 then slow else 1)
		for _, piece in pieces do
			local p = piece.part
			if not p.Parent then
				continue
			end
			local k = math.clamp((t - piece.start) / piece.time, 0, 1)
			if piece.spin then
				-- popping off: up and out, spinning, shrinking away
				local spin = piece.spin :: Vector3
				local lift = math.sin(k * math.pi * 0.9) * 20 * S + k * 6 * S
				p.CFrame = CFrame.new(spin.X * 14 * S * k, lift, spin.Z * 10 * S * k)
					* piece.cf
					* CFrame.Angles(spin.X * 6 * k, spin.Y * 6 * k, spin.Z * 6 * k)
				p.Size = piece.size * math.max(0.05, 1 - k * k * k)
				p.Transparency = if k >= 1 then 1 else piece.transparency
			else
				-- dropping in with a bounce, growing to full size
				p.LocalTransparencyModifier = if t < piece.start then 1 else 0
				p.CFrame = CFrame.new(0, (1 - bounce(k)) * piece.drop, 0) * piece.cf
				p.Size = piece.size * (0.55 + 0.45 * ease(k))
			end
		end
		if not landed and t >= POST_START + POST_TIME then
			landed = true
			local frame = MapConfig.homeFrame(hole:GetAttribute("HoleIndex") :: number)
			pcall(VFX.burst, "Shockwave", (frame * CFrame.new(0, 0.5, 60 * S)).Position, { color = GOLD, scale = 3 })
			for _, p in parts(newFence) do
				if ((p:GetAttribute("U") :: number?) or 0) > 1 and p.Name == "Post" then
					pcall(VFX.burst, "Poof", p.Position - Vector3.new(0, p.Size.Y / 2, 0), { scale = 1.5 })
				end
			end
		end
		if t >= DONE then
			connection:Disconnect()
			for _, piece in pieces do
				if not piece.spin and piece.part.Parent then
					piece.part.CFrame = piece.cf
					piece.part.Size = piece.size
					piece.part.LocalTransparencyModifier = 0
				end
			end
			if oldFence then
				oldFence:Destroy()
			end
		end
	end)
end

local function watch(hole: Instance)
	local cached: Instance? = nil -- a copy of the fence as it stands, to throw away on the next level up
	local level = hole:GetAttribute("Level")
	task.spawn(function()
		local fence = settled(hole, "Fence")
		if fence and not cached then
			cached = fence:Clone()
		end
	end)
	hole:GetAttributeChangedSignal("Level"):Connect(function()
		local new, old = hole:GetAttribute("Level"), level
		level = new
		local oldFence = cached
		cached = nil
		task.wait(0.1) -- let the rebuild start
		local fence = settled(hole, "Fence")
		if not fence then
			return
		end
		cached = fence:Clone()
		if typeof(new) == "number" and typeof(old) == "number" and new > old then
			play(hole, oldFence, fence, hole:FindFirstChild("Dressing"))
		elseif oldFence then
			oldFence:Destroy()
		end
	end)
end

for _, hole in holes:GetChildren() do
	watch(hole)
end
holes.ChildAdded:Connect(watch)
