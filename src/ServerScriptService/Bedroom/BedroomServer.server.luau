--!strict
-- Starts the Kid's Bedroom: the game (saving, homes and pens, money, upgrades, raids, rewards), the Giant's wake
-- meter and flashlight, the train, the cat and the small hazards.
-- The map itself (Workspace.Bedroom) is built in Edit mode by tools/build-bedroom.luau.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local bedroom = Workspace:WaitForChild("Bedroom") :: Model
local BedroomLighting = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BedroomLighting")) :: any

BedroomLighting.apply(BedroomLighting.Night, 0)

-- Game systems first (they hook into PlayerData), then the hazards; PlayerData starts last so every system is
-- listening before the first profile loads.
for _, name in
	{ "Homes", "Pens", "Carry", "Economy", "Upgrades", "Raids", "Rewards", "Giant", "Train", "Cat", "RCCar", "Hazards" }
do
	local ok, err = pcall(function()
		local system = require(script.Parent:WaitForChild(name)) :: any
		system.start(bedroom)
	end)
	if not ok then
		warn(`Bedroom: {name} didn't start: {err}`)
	end
end

local PlayerData = require(script.Parent:WaitForChild("PlayerData")) :: any
PlayerData.start()

-- Studio only: ServerStorage.GameDebug (BindableFunction) lets the command bar and test tools poke the game,
-- e.g. GameDebug:Invoke("cash", player, 1e6), ("give", player, "M"), ("ready", player), ("profile", player),
-- ("wipe", player).
if game:GetService("RunService"):IsStudio() then
	local debug = Instance.new("BindableFunction")
	debug.Name = "GameDebug"
	debug.OnInvoke = function(command: string, player: Player, arg: any): any
		local Carry = require(script.Parent.Carry) :: any
		local profile = PlayerData.get(player)
		if command == "cash" and profile then
			PlayerData.addCash(player, arg)
			PlayerData.changed(player)
		elseif command == "give" then
			return Carry.giveSleeping(player, arg or "S")
		elseif command == "profile" then
			return game:GetService("HttpService"):JSONEncode(profile)
		elseif command == "wipe" and profile then
			-- start this player's (real) save again from nothing: cash, toys, levels, stats, Index, streak
			if Carry.isCarrying(player) then
				Carry.drop(player)
			end
			local Upgrades = require(script.Parent.Upgrades) :: any
			Upgrades.stopTraining(player)
			PlayerData.wipe(player)
			local Pens = require(script.Parent.Pens) :: any
			Pens.reload(player)
			Carry.refreshSpeed(player)
		elseif command == "ready" and profile then
			-- every blanket waiting at home can be hatched now (it's rebuilt as ready)
			for _, b in profile.Blankets do
				b.w = os.time()
			end
			local Pens = require(script.Parent.Pens) :: any
			Pens.reload(player)
		elseif command == "set" and profile then
			for k, v in arg do
				(profile :: any)[k] = v
			end
			PlayerData.changed(player)
		end
		return true
	end
	debug.Parent = game:GetService("ServerStorage")
end
