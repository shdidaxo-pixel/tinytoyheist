--!strict
-- The Giant Kid: the shared Wake Meter, his sleep cycle and his flashlight.
--   Asleep   about 4 minutes. The meter drains 2 a second; noise fills it. At 80 he sits up with his flashlight and
--            sweeps it down the run (until the meter falls back under 60). At 100 he wakes early.
--   Stirring 10 s warning: he sits up and the lights come on.
--   Awake    60 s: lights on, the cat turns aggressive, the flashlight sweeps the run.
-- Anyone caught in the beam while carrying a toy drops it. Everything is on GiantKid's attributes, so clients (the
-- lights, the HUD) follow along: State, WakeMeter (0..100), Flashlight (bool), WakesAt (server time of the next
-- natural wake-up), StateEndsAt.
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
Giant.BEAM_RADIUS = 34 -- the pool of light on the floor

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
					kid:SetAttribute("WakesAt", now() + Giant.SLEEP)
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
			if state == "Asleep" and not kid:GetAttribute("Flashlight") then
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
end

return Giant
