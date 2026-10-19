--!strict
-- Money: every second, each player's awake toys at home pay straight into their cash (auto collect: Dylan, 19 Oct).
-- Income = the toys' money (base x mutation) x the rebirth bonus x a x2 boost while one runs. The home's sign and
-- the HUD show it (Player and home attribute Income).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig")) :: any
local PlayerData = require(script.Parent.PlayerData)
local Pens = require(script.Parent.Pens)
local Homes = require(script.Parent.Homes)

local Economy = {}

function Economy.multiplier(player: Player): number
	local p = PlayerData.get(player)
	if not p then
		return 1
	end
	local m = GameConfig.rebirthMultiplier(p.Rebirths)
	if p.BoostUntil > os.time() then
		m *= GameConfig.BOOST_MULTIPLIER
	end
	return m
end

function Economy.income(player: Player): number
	return Pens.income(player) * Economy.multiplier(player)
end

function Economy.start(_bedroom: Model)
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				local s = Pens.state(player)
				if not s or not PlayerData.get(player) then
					continue
				end
				local income = Economy.income(player)
				if income > 0 then
					PlayerData.addCash(player, income)
				end
				if player:GetAttribute("Income") ~= income then
					player:SetAttribute("Income", income)
				end
				if s.hole:GetAttribute("Income") ~= income then
					s.hole:SetAttribute("Income", income)
					Homes.refreshSign(s.hole)
				end
			end
		end
	end)
end

return Economy
