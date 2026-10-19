--!strict
-- The Kid's Bedroom on each player's screen: the lights following the Kid's state, the Kid sitting up with his
-- flashlight, the train on its loop, the cat, toys roaming their pens, the Speed wheels, the floating home signs,
-- getting knocked over, noise ripples, the little hazard animations, and the game in the world (wake-up timers, reveal
-- bursts, income tags, training). The server decides what happens
-- (ServerScriptService.Bedroom); this only shows it.

local Workspace = game:GetService("Workspace")

local bedroom = Workspace:WaitForChild("Bedroom") :: Model

for _, name in { "Lights", "KidView", "TrainView", "CatView", "HomeView", "Effects", "Sounds", "GameView" } do
	task.spawn(function()
		local ok, err = pcall(function()
			local view = require(script.Parent:WaitForChild(name)) :: any
			view.start(bedroom)
		end)
		if not ok then
			warn(`Bedroom: {name} didn't start: {err}`)
		end
	end)
end
