--!strict
-- Night while the Kid sleeps; the lights snap on (0.4 s) when he stirs, and fade back to night (3 s) when he's back
-- asleep. Lighting changes on the client only affect this player's screen, which is what we want.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BedroomLighting = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BedroomLighting")) :: any

local Lights = {}

function Lights.start(bedroom: Model)
	local kid = bedroom:WaitForChild("GiantKid")
	local lit: boolean? = nil
	local function update(instant: boolean)
		local state = kid:GetAttribute("State")
		local on = state == "Stirring" or state == "Awake"
		if on == lit then
			return
		end
		lit = on
		local seconds = if instant then 0 elseif on then 0.4 else 3
		BedroomLighting.apply(if on then BedroomLighting.LightsOn else BedroomLighting.Night, seconds)
	end
	update(true)
	kid:GetAttributeChangedSignal("State"):Connect(function()
		update(false)
	end)
end

return Lights
