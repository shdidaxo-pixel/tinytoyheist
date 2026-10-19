--!strict
-- Money: every second, each player's awake toys at home pay straight into their cash (auto collect: Dylan, 19 Oct).
-- Income = the toys' money (base x mutation) x the rebirth bonus x a x2 boost while one runs. The home's sign and
-- the HUD show it (Player and home attribute Income), and so does the player list (leaderstats Cash and Per Sec;
-- Dylan, 19 Oct: put the cash/s on the base names or the leaderboard instead of a cash pile).

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

-- The player list: Cash and Per Sec, in short money ("$1.5K"), and Speed ("16,000", "2.4M")
local function leaderstats(player: Player): (StringValue, StringValue, StringValue)
	local folder = player:FindFirstChild("leaderstats")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "leaderstats"
		folder.Parent = player
	end
	local function stat(name: string): StringValue
		local v = (folder :: Instance):FindFirstChild(name) :: StringValue?
		if not v then
			local made = Instance.new("StringValue")
			made.Name = name
			made.Parent = folder
			v = made
		end
		return v :: StringValue
	end
	return stat("Cash"), stat("Per Sec"), stat("Speed")
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
				local cash, perSec, speed = leaderstats(player)
				cash.Value = GameConfig.money(player:GetAttribute("Cash") :: number? or 0)
				perSec.Value = GameConfig.money(income) .. "/s"
				speed.Value = GameConfig.speedText(player:GetAttribute("Speed") :: number? or GameConfig.SPEED_START)
				if s.hole:GetAttribute("Income") ~= income then
					s.hole:SetAttribute("Income", income)
					Homes.refreshSign(s.hole)
				end
			end
		end
	end)
end

return Economy
