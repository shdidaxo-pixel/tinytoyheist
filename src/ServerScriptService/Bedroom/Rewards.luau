--!strict
-- Daily streak and playtime gifts (GameRemotes.Claim, a RemoteFunction: ("Daily") / ("Playtime", n) -> ok, message).
-- Rewards are cash, a x2 money boost, or a sleeping toy delivered to your pen (it wakes up like any other).
-- The daily streak counts UTC days: claim on the next day to keep it going; miss one and it starts again at Day 1.
-- Playtime gifts unlock by minutes played this session.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig")) :: any
local PlayerData = require(script.Parent.PlayerData)
local Carry = require(script.Parent.Carry)
local Pens = require(script.Parent.Pens)

local Rewards = {}
local notice: RemoteEvent

local function today(): number
	return os.time() // 86400
end
Rewards.today = today

-- Give one reward. Returns false (and why) if it can't be given now, so the claim isn't used up.
local function give(player: Player, r: any, boostMinutes: number?): (boolean, string)
	local p = PlayerData.get(player)
	if not p then
		return false, "Still loading..."
	end
	if r.kind == "Toy" and not Pens.canBank(player) then
		return false, "No room for another blanket: hatch yours first!"
	end
	local parts = {}
	if r.kind == "Cash" or r.cash then
		local amount = r.amount or r.cash
		PlayerData.addCash(player, amount)
		table.insert(parts, "+" .. GameConfig.money(amount))
	end
	if r.kind == "Boost" then
		local minutes = boostMinutes or r.minutes or 5
		p.BoostUntil = math.max(os.time(), p.BoostUntil) + minutes * 60
		table.insert(parts, `x2 money for {minutes} min`)
	end
	if r.kind == "Toy" then
		Carry.giveSleeping(player, r.size or "M")
		table.insert(parts, "a mystery blanket in your home")
	end
	PlayerData.changed(player)
	return true, table.concat(parts, " and ")
end

local function claim(player: Player, what: string, arg: any): (boolean, string)
	local p = PlayerData.get(player)
	local s = PlayerData.session(player)
	if not p or not s then
		return false, "Still loading..."
	end
	if what == "Daily" then
		local day = today()
		if p.Daily.Day == day then
			return false, "Come back tomorrow!"
		end
		local streak = if p.Daily.Day == day - 1 then p.Daily.Streak + 1 else 1
		if streak > #GameConfig.DAILY then
			streak = 1
		end
		local ok, message = give(player, GameConfig.DAILY[streak])
		if ok then
			p.Daily = { Streak = streak, Day = day }
			PlayerData.changed(player)
			return true, `Day {streak}: {message}!`
		end
		return false, message
	elseif what == "TestBlanket" then
		-- Studio only, until the shop has real products: the Featured buttons put Large blankets in your home
		if not RunService:IsStudio() then
			return false, "Coming soon!"
		end
		local given = 0
		for _ = 1, math.clamp(tonumber(arg) or 1, 1, 50) do
			if not Carry.giveSleeping(player, "L") then
				break
			end
			given += 1
		end
		local message = if given > 0
			then `Test: {given} Large blanket{if given == 1 then "" else "s"} in your home`
			else "No room for more blankets: hatch yours first!"
		notice:FireClient(player, message, if given > 0 then "good" else "warn")
		return given > 0, message
	elseif what == "Tutorial" then
		p.Tutorial = 1
		PlayerData.changed(player)
		return true, ""
	elseif what == "Playtime" then
		local n = tonumber(arg)
		local gift = n and GameConfig.PLAYTIME[n]
		if not n or not gift then
			return false, "?"
		end
		if s.playtimeClaimed[n] then
			return false, "Already claimed"
		end
		local played = (os.clock() - s.joinedAt) / 60
		if played < gift.minutes then
			return false, `Play {math.ceil(gift.minutes - played)} more min`
		end
		local ok, message = give(player, gift, gift.minutes2)
		if ok then
			s.playtimeClaimed[n] = true
			PlayerData.changed(player)
			return true, message .. "!"
		end
		return false, message
	end
	return false, "?"
end

function Rewards.start(_bedroom: Model)
	notice = ReplicatedStorage:WaitForChild("BedroomRemotes"):WaitForChild("Notice") :: RemoteEvent
	local claimRemote = PlayerData.remote("RemoteFunction", "Claim") :: RemoteFunction
	claimRemote.OnServerInvoke = function(player: Player, what: any, arg: any)
		if typeof(what) ~= "string" then
			return false, "?"
		end
		local ok, okClaim, message = pcall(claim, player, what, arg)
		if not ok then
			warn(`Rewards: {player.Name} {what}: {okClaim}`)
			return false, "Something went wrong"
		end
		return okClaim, message
	end
end

return Rewards
