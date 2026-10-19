--!strict
-- Starts the Kid's Bedroom: homes, the Giant's wake meter and flashlight, the train, the cat and the small hazards.
-- The map itself (Workspace.Bedroom) is built in Edit mode by tools/build-bedroom.luau.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local bedroom = Workspace:WaitForChild("Bedroom") :: Model
local BedroomLighting = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BedroomLighting")) :: any

BedroomLighting.apply(BedroomLighting.Night, 0)

for _, name in { "Homes", "Carry", "Giant", "Train", "Cat", "Hazards" } do
	local ok, err = pcall(function()
		local system = require(script.Parent:WaitForChild(name)) :: any
		system.start(bedroom)
	end)
	if not ok then
		warn(`Bedroom: {name} didn't start: {err}`)
	end
end
