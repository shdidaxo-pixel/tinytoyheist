--!strict
-- The Giant Kid: the shared Wake Meter, his sleep cycle and his flashlight.
--   Asleep   about 4 minutes. The meter drains 2 a second; noise fills it. At 80 he sits up with his flashlight and
--            sweeps it down the run (until the meter falls back under 60). At 100 he wakes early.
--   Stirring 10 s warning: he sits up and the lights come on.
--   Awake    60 s: lights on, the cat turns aggressive, and he gets out of bed and walks toward the loudest noise
--            of the last 5 s (or the nearest mouse in the run). Anyone he reaches is grabbed: they drop their toy
--            and land back home after a 3 s stun. He never comes into the safe zone or the homes.
--   BackToBed up to 12 s: he walks back to bed and lies down; then Asleep again.
-- Anyone caught in the beam while carrying a toy drops it. Everything is on GiantKid's attributes, so clients (the
-- lights, the HUD) follow along: State, WakeMeter (0..100), Flashlight (bool), WakesAt (server time of the next
-- natural wake-up), StateEndsAt, Walking (bool), WalkerPose (the walking Kid's Root CFrame) and GrabAt (server time of
-- his last grab).
-- To test from the command bar while playing (Server): workspace.Bedroom.GiantKid:SetAttribute("WakeMeter", 100)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local MapConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MapConfig")) :: any
local Events = require(script.Parent.Events)
local Knock = require(script.Parent.Knock)

local Giant = {}
Giant.SLEEP = 240
Giant.STIR = 10
Giant.AWAKE = 60
Giant.DRAIN = 2 -- meter points a second while asleep
Giant.FLASHLIGHT_ON = 80
Giant.FLASHLIGHT_OFF = 60
Giant.BEAM_RADIUS = 34 * MapConfig.SCALE -- the pool of light on the floor
Giant.BACK_TO_BED = 12
Giant.WALK_SPEED = 13 -- a little slower than a mouse, faster than one dragging a Medium or Large toy
Giant.REACH = 34 * MapConfig.SCALE + 4
Giant.HEARING = 5 -- seconds of noise he remembers when choosing where to go
Giant.heard = {} :: { { position: Vector3, points: number, at: number } }

local function now(): number
	return Workspace:GetServerTimeNow()
end

function Giant.start(bedroom: Model)
	local kid = bedroom:WaitForChild("GiantKid") :: Model
	local function setState(state: string, duration: number?)
		kid:SetAttribute("State", state)
		kid:SetAttribute("StateEndsAt", if duration then now() + duration else 0)
	end
	kid:SetAttribute("WakeMeter", 0)
	kid:SetAttribute("Flashlight", false)
	kid:SetAttribute("WakesAt", now() + Giant.SLEEP)
	setState("Asleep")

	-- Noise from anywhere in the game
	Events.MakeNoise.Event:Connect(function(position: Vector3, points: number, kind: string?)
		if typeof(position) ~= "Vector3" or typeof(points) ~= "number" then
			return
		end
		local multiplier
		if kind == "Drag" or kind == "Step" then
			multiplier = MapConfig.noiseAt(position)
		else
			local m = MapConfig.MONITOR_ZONE
			local flat = Vector3.new(position.X, 0, position.Z)
			multiplier = if (flat - m.center).Magnitude <= m.radius then m.noise else 1
		end
		local added = points * multiplier
		if added <= 0 then
			return
		end
		if kid:GetAttribute("State") == "Asleep" then
			kid:SetAttribute("WakeMeter", math.min(100, (kid:GetAttribute("WakeMeter") :: number) + added))
		end
		table.insert(Giant.heard, { position = position, points = added, at = os.clock() })
		Events.NoiseRipple:FireAllClients(position, added)
	end)

	-- The sleep cycle, ten times a second
	task.spawn(function()
		local last = os.clock()
		while kid.Parent do
			task.wait(0.1)
			local dt = os.clock() - last
			last = os.clock()
			local state = kid:GetAttribute("State")
			local meter = kid:GetAttribute("WakeMeter") :: number
			if state == "Asleep" then
				local full = meter >= 100 -- checked before draining, so a full meter always wakes him
				meter = math.max(0, meter - Giant.DRAIN * dt)
				kid:SetAttribute("WakeMeter", meter)
				local flashlight = kid:GetAttribute("Flashlight")
				if not flashlight and meter >= Giant.FLASHLIGHT_ON then
					kid:SetAttribute("Flashlight", true)
				elseif flashlight and meter < Giant.FLASHLIGHT_OFF then
					kid:SetAttribute("Flashlight", false)
				end
				if full or now() >= (kid:GetAttribute("WakesAt") :: number) then
					setState("Stirring", Giant.STIR)
				end
			elseif state == "Stirring" then
				if now() >= (kid:GetAttribute("StateEndsAt") :: number) then
					setState("Awake", Giant.AWAKE)
				end
			elseif state == "Awake" then
				if now() >= (kid:GetAttribute("StateEndsAt") :: number) then
					kid:SetAttribute("WakeMeter", 0)
					kid:SetAttribute("Flashlight", false)
					kid:SetAttribute("WakesAt", now() + Giant.SLEEP + Giant.BACK_TO_BED)
					setState("BackToBed", Giant.BACK_TO_BED)
				end
			elseif state == "BackToBed" then
				if now() >= (kid:GetAttribute("StateEndsAt") :: number) or not kid:GetAttribute("Walking") then
					kid:SetAttribute("Walking", false)
					setState("Asleep")
				end
			end
		end
	end)

	-- The flashlight: anyone in the pool of light carrying a toy drops it
	task.spawn(function()
		while kid.Parent do
			task.wait(0.2)
			local state = kid:GetAttribute("State")
			if
				(state == "Asleep" and not kid:GetAttribute("Flashlight"))
				or kid:GetAttribute("Walking")
				or state == "BackToBed"
			then
				continue
			end
			local target = MapConfig.flashlightTarget(now())
			for _, player in Players:GetPlayers() do
				local root = Knock.root(player)
				if root and player:GetAttribute("Carrying") then
					local flat = Vector3.new(root.Position.X, 0, root.Position.Z)
					if (flat - target).Magnitude <= Giant.BEAM_RADIUS and root.Position.Y < 40 then
						Knock.hit(player, target, {
							message = "Caught in the flashlight!",
							push = 30,
							stun = 1,
						})
					end
				end
			end
		end
	end)
	-- Out of bed: walk toward the loudest recent noise (or the nearest mouse in the run) and grab whoever he reaches
	local walker = kid:WaitForChild("Walker") :: Model
	local home = (walker.PrimaryPart :: BasePart).CFrame
	local rootY = home.Position.Y
	local position = Vector3.new(home.Position.X, 0, home.Position.Z)
	local facing = Vector3.new(0, 0, -1)
	local function allowed(p: Vector3): Vector3
		local S = MapConfig.SCALE
		local edge = MapConfig.HALF_WIDTH - 40 * S
		local x = math.clamp(p.X, -edge, edge)
		local z = math.clamp(p.Z, 640 * S, MapConfig.LENGTH - 60 * S)
		for _, f in MapConfig.FOOTPRINTS do
			local x0, z0, x1, z1 = f[1] - 36 * S, f[2] - 36 * S, f[3] + 36 * S, f[4] + 36 * S
			if x > x0 and x < x1 and z > z0 and z < z1 then
				local options = { { x0 - x, 0 }, { x1 - x, 0 }, { 0, z0 - z }, { 0, z1 - z } }
				table.sort(options, function(a, b)
					return math.abs(a[1]) + math.abs(a[2]) < math.abs(b[1]) + math.abs(b[2])
				end)
				x += options[1][1]
				z += options[1][2]
			end
		end
		return Vector3.new(x, 0, z)
	end
	-- He gets out at the foot of the bed (the end facing the run). Pushing his lying spot out of the bed's footprint
	-- the shortest way left him boxed in by the bed, the chair and the desk, so he never reached the run.
	local start = allowed(position)
	for _, f in MapConfig.FOOTPRINTS do
		if position.X > f[1] and position.X < f[3] and position.Z > f[2] and position.Z < f[4] then
			start = allowed(Vector3.new((f[1] + f[3]) / 2, 0, f[2] - 44 * MapConfig.SCALE))
			break
		end
	end
	local function inRun(p: Vector3): boolean
		return MapConfig.inRoom(p) and not MapConfig.inSafeZone(p) and p.Z >= 560 * MapConfig.SCALE
	end
	local function setPose()
		local yaw = math.atan2(-facing.X, -facing.Z)
		kid:SetAttribute("WalkerPose", CFrame.new(position.X, rootY, position.Z) * CFrame.Angles(0, yaw, 0))
	end
	setPose()
	task.spawn(function()
		local last = os.clock()
		while kid.Parent do
			task.wait(1 / 20)
			local dt = math.min(os.clock() - last, 0.2)
			last = os.clock()
			local state = kid:GetAttribute("State")
			local cutoff = os.clock() - Giant.HEARING
			for i = #Giant.heard, 1, -1 do
				if Giant.heard[i].at < cutoff then
					table.remove(Giant.heard, i)
				end
			end
			if state == "Awake" then
				if not kid:GetAttribute("Walking") then
					kid:SetAttribute("Walking", true)
					position = start
				end
				-- where to go: the loudest noise he heard in the run, else the nearest mouse, else the middle
				local goal, loudest = nil, 0
				for _, n in Giant.heard do
					if n.points > loudest and inRun(n.position) then
						goal, loudest = n.position, n.points
					end
				end
				local best = math.huge
				for _, player in Players:GetPlayers() do
					local root = Knock.root(player)
					if root and inRun(root.Position) then
						local flat = Vector3.new(root.Position.X, 0, root.Position.Z)
						local d = (flat - position).Magnitude
						if not goal and d < best then
							best = d
							goal = flat
						end
						if d <= Giant.REACH and root.Position.Y < 80 * MapConfig.SCALE + 6 then
							local caught = Knock.hit(player, position, {
								message = "The Giant caught you!",
								push = 90,
								stun = 3,
								home = true,
							})
							if caught then
								kid:SetAttribute("GrabAt", now()) -- clients play his scoop (KidView)
							end
						end
					end
				end
				goal = goal or Vector3.new(0, 0, MapConfig.LENGTH * 0.55) -- nobody about: the middle of the room
				local d = Vector3.new(goal.X - position.X, 0, goal.Z - position.Z)
				if d.Magnitude > 4 * MapConfig.SCALE then
					position = allowed(position + d.Unit * math.min(d.Magnitude, Giant.WALK_SPEED * dt))
					facing = facing:Lerp(d.Unit, math.min(1, dt * 3)).Unit
				end
				setPose()
			elseif state == "BackToBed" and kid:GetAttribute("Walking") then
				local d = start - position
				if d.Magnitude < 6 * MapConfig.SCALE then
					kid:SetAttribute("Walking", false)
				else
					position = allowed(position + d.Unit * math.min(d.Magnitude, Giant.WALK_SPEED * 1.6 * dt))
					facing = facing:Lerp(d.Unit, math.min(1, dt * 3)).Unit
				end
				setPose()
			end
		end
	end)
end

return Giant
