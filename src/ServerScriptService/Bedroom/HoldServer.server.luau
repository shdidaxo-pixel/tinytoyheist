--!strict
-- Starts holding toys to show them off (Hold.luau, the hotbar's server side). Its own script so it needs no line in
-- BedroomServer; it only listens to remotes and player attributes, so it doesn't matter which starts first.
local bedroom = workspace:WaitForChild("Bedroom") :: Model
local Hold = require(script.Parent:WaitForChild("Hold")) :: any
Hold.start(bedroom)
