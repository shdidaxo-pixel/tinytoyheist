--!strict
-- The music: a calm night loop, and a chase layer that fades in while the lights are on (the Kid stirring or awake)
-- and a little while you carry a toy. Both are stems of the same APM cue ("Sneaky Schemes", 130 s), played in sync,
-- so the chase layer is the night tune with the drums in. Started by Sounds; mixed through the Music SoundGroup.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Music = {}

local CARRY_LAYER = 0.35 -- how much of the chase layer plays while you carry a toy
local FADE_UP, FADE_DOWN = 1.5, 4 -- seconds for a full fade

function Music.start(bedroom: Model, Sounds: any)
	local player = Players.LocalPlayer
	local kid = bedroom:WaitForChild("GiantKid")
	local night = Sounds.loop("MusicNight") :: Sound
	local chase = Sounds.loop("MusicChase") :: Sound
	local nightVolume, chaseVolume = night.Volume, chase.Volume
	chase.Volume = 0
	-- wait for both tracks, but not forever: one that never loads mustn't keep the other silent
	local deadline = os.clock() + 10
	while not (night.IsLoaded and chase.IsLoaded) and os.clock() < deadline do
		task.wait(0.2)
	end
	night:Play()
	chase:Play()

	local layer = 0
	RunService.Heartbeat:Connect(function(dt)
		local state = kid:GetAttribute("State")
		local target = if state == "Stirring" or state == "Awake"
			then 1
			elseif player:GetAttribute("Carrying") then CARRY_LAYER
			else 0
		local rate = if target > layer then 1 / FADE_UP else 1 / FADE_DOWN
		layer += math.clamp(target - layer, -rate * dt, rate * dt)
		-- equal-power crossfade: the full mix already has the night parts in it
		night.Volume = nightVolume * math.cos(layer * math.pi / 2)
		chase.Volume = chaseVolume * math.sin(layer * math.pi / 2)
	end)
	-- keep the two stems together (they can drift a little over a long session)
	task.spawn(function()
		while night.Parent do
			task.wait(2)
			local t = night.TimePosition
			if t > 0.5 and t < night.TimeLength - 1 and math.abs(chase.TimePosition - t) > 0.06 then
				chase.TimePosition = t
			end
		end
	end)
end

return Music
