--!strict
-- Money: every second, each player's awake toys at home pay straight into their cash (auto collect: Dylan, 19 Oct).
-- Income = the toys' money (base x mutation) x the rebirth bonus x a x2 boost while one runs. The home's sign and
-- the HUD show it (Player and home attribute Income), and so does the player list (leaderstats Cash and Per Sec;
-- Dylan, 19 Oct: put the cash/s on the base names or the leaderboard instead of a cash pile).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig")) :: any
local Monetization = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Monetization")) :: any
local PlayerData = require(script.Parent.PlayerData)
local Pens = require(script.Parent.Pens)
local Homes = require(script.Parent.Homes)

local Economy = {}

-- Friends in the same server: +10% cash each (the HUD's "Each Friend = +10% Cash"), up to FRIEND_MAX friends.
-- IsFriendsWith is a web call, so each pair is asked once and remembered.
Economy.FRIEND_BONUS = 0.1
Economy.FRIEND_MAX = 5
local friendCache: { [string]: boolean } = {}
local friendCount: { [Player]: number } = {}

local function areFriends(a: Player, b: Player): boolean
	local low, high = math.min(a.UserId, b.UserId), math.max(a.UserId, b.UserId)
	local k = `{low}_{high}`
	local known = friendCache[k]
	if known == nil then
		local ok, result = pcall(function()
			return a:IsFriendsWith(b.UserId)
		end)
		known = ok and result == true
		if ok then
			friendCache[k] = known
		end
	end
	return known :: boolean
end

local function countFriends()
	for _, player in Players:GetPlayers() do
		local n = 0
		for _, other in Players:GetPlayers() do
			if other ~= player and other.UserId > 0 and player.UserId > 0 and areFriends(player, other) then
				n += 1
			end
		end
		n = math.min(n, Economy.FRIEND_MAX)
		friendCount[player] = n
		player:SetAttribute("Friends", n)
	end
end

function Economy.multiplier(player: Player): number
	local p = PlayerData.get(player)
	if not p then
		return 1
	end
	local m = GameConfig.rebirthMultiplier(p.Rebirths)
	if p.BoostUntil > os.time() then
		m *= GameConfig.BOOST_MULTIPLIER
	end
	if player:GetAttribute("PassCash") then
		m *= Monetization.CASH_PASS
	end
	if player:GetAttribute("PassVIP") then
		m *= Monetization.VIP_CASH
	end
	m *= 1 + Economy.FRIEND_BONUS * (friendCount[player] or 0)
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
	Players.PlayerAdded:Connect(function()
		task.spawn(countFriends)
	end)
	Players.PlayerRemoving:Connect(function(player)
		friendCount[player] = nil
		task.delay(1, countFriends)
	end)
	task.spawn(countFriends)
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				local s = Pens.state(player)
				if not s or not PlayerData.get(player) then
					continue
				end
				-- one player's error must never stop everyone's income
				local ok, err = pcall(Economy.pay, player, s)
				if not ok then
					warn(`Economy: {player.Name}: {err}`)
				end
			end
		end
	end)
end

-- One second of income for one player, and the numbers that show it (player list, home sign)
function Economy.pay(player: Player, s: any)
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

return Economy
