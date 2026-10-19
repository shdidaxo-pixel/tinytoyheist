--!strict
-- Spending and the inventory (GameRemotes.Buy, a RemoteFunction -> ok, message): ("Home") and ("Wheel") level up
-- your home and your Speed wheel (separate upgrades), ("Sell", uid or {uids}), ("Equip" | "Unequip", uid),
-- ("EquipBest"), ("Lock" | "Unlock", uid), and ("Rebirth") while rebirths are switched on (GameConfig.SHOW_REBIRTH).
-- Speed is trained on your home's wheel: press Train Speed and you run in it (anchored on its RunPoint) gaining
-- Speed points, faster on a better wheel, until you jump off or move (GameRemotes.StopTraining).

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig")) :: any
local MapConfig = require(Shared:WaitForChild("MapConfig")) :: any
local PlayerData = require(script.Parent.PlayerData)
local Pens = require(script.Parent.Pens)
local Carry = require(script.Parent.Carry)
local Knock = require(script.Parent.Knock)

local Upgrades = {}

local notice: RemoteEvent

local function stopTraining(player: Player)
	if not player:GetAttribute("Training") then
		return
	end
	player:SetAttribute("Training", nil)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		root.Anchored = false
	end
	Carry.refreshSpeed(player)
end
Upgrades.stopTraining = stopTraining

local function startTraining(player: Player, hole: Model)
	if player:GetAttribute("Training") or Carry.isCarrying(player) then
		return
	end
	local wheel = hole:FindFirstChild("TrainingWheel")
	local runPoint = wheel and wheel:FindFirstChild("RunPoint") :: BasePart?
	local root = Knock.root(player)
	local p = PlayerData.get(player)
	if not runPoint or not root or not p then
		return
	end
	if p.SpeedPoints >= GameConfig.SPEED_MAX_POINTS then
		notice:FireClient(player, "Your Speed is maxed out!", "good")
		return
	end
	player:SetAttribute("Training", true)
	-- stand in the bottom of the wheel, running along it
	local character = player.Character :: Model
	character:PivotTo(runPoint.CFrame * CFrame.new(0, 3, 0))
	root.Anchored = true
	Carry.refreshSpeed(player)
end

local function buy(player: Player, what: string, arg: any): (boolean, string)
	local p = PlayerData.get(player)
	if not p then
		return false, "Still loading..."
	end
	if what == "Home" then
		local nextLevel = p.HomeLevel + 1
		local cost = GameConfig.HOME_COST[nextLevel]
		if not cost then
			return false, "Your home is max level!"
		end
		local needRebirth = GameConfig.HOME_REBIRTH[nextLevel]
		if needRebirth and p.Rebirths < needRebirth then
			return false, `Level {nextLevel} needs Rebirth {needRebirth}`
		end
		if not PlayerData.spend(player, cost) then
			return false, "Not enough cash"
		end
		p.HomeLevel = nextLevel
		Pens.setLevel(player, nextLevel)
		Pens.fillFree(player)
		PlayerData.changed(player)
		return true, `Home level {nextLevel}! Room for {MapConfig.HOLE_LEVELS[nextLevel].slots} toys`
	elseif what == "Wheel" then
		local nextLevel = p.WheelLevel + 1
		local cost = GameConfig.WHEEL_COST[nextLevel]
		if not cost then
			return false, "Your Speed wheel is max level!"
		end
		if not PlayerData.spend(player, cost) then
			return false, "Not enough cash"
		end
		p.WheelLevel = nextLevel
		Pens.setWheel(player, nextLevel)
		PlayerData.changed(player)
		return true, `Speed wheel level {nextLevel}! Trains x{GameConfig.trainRate(nextLevel)} as fast`
	elseif what == "Rebirth" then
		if not GameConfig.SHOW_REBIRTH then
			return false, "Rebirths aren't open yet"
		end
		local n = p.Rebirths + 1
		if n > GameConfig.MAX_REBIRTHS then
			return false, "No more rebirths (for now)!"
		end
		local cost = GameConfig.rebirthCost(n)
		if p.Cash < cost then
			return false, `Rebirth {n} needs {GameConfig.money(cost)}`
		end
		stopTraining(player)
		p.Rebirths = n
		p.Cash = 0
		p.SpeedPoints = 0
		p.SpeedProgress = 0
		p.HomeLevel = 1
		p.WheelLevel = 1
		Pens.setLevel(player, 1)
		Pens.setWheel(player, 1)
		Pens.equipBest(player)
		PlayerData.changed(player)
		Carry.refreshSpeed(player)
		local mult = GameConfig.rebirthMultiplier(n)
		for _, other in Players:GetPlayers() do
			notice:FireClient(other, `{player.DisplayName} reached Rebirth {n}!`, "good")
		end
		return true, `Rebirth {n}! You now earn x{mult} money`
	elseif what == "Sell" then
		-- one toy (uid) or many ({uid, ...}); locked toys and ones being stolen are skipped
		local uids = if typeof(arg) == "string" then { arg } elseif typeof(arg) == "table" then arg else {}
		local state = Pens.state(player)
		local total, count = 0, 0
		for _, uid in uids do
			local entry = typeof(uid) == "string" and Pens.find(player, uid)
			if entry and state and not state.out[uid] and not entry.l then
				total += math.floor(Pens.perSecond(entry) * GameConfig.SELL_SECONDS)
				count += 1
				Pens.remove(player, uid)
			end
		end
		if count == 0 then
			return false, "Nothing to sell (locked toys are kept)"
		end
		PlayerData.addCash(player, total)
		PlayerData.changed(player)
		return true,
			if count == 1
				then `Sold for {GameConfig.money(total)}`
				else `Sold {count} toys for {GameConfig.money(total)}`
	elseif what == "Equip" or what == "Unequip" then
		if typeof(arg) ~= "string" then
			return false, "?"
		end
		return Pens.equip(player, arg, what == "Equip")
	elseif what == "EquipBest" then
		return Pens.equipBest(player)
	elseif what == "Lock" or what == "Unlock" then
		if typeof(arg) ~= "string" then
			return false, "?"
		end
		return Pens.setLock(player, arg, what == "Lock")
	end
	return false, "?"
end

function Upgrades.start(_bedroom: Model)
	local remotes = ReplicatedStorage:WaitForChild("BedroomRemotes")
	notice = remotes:WaitForChild("Notice") :: RemoteEvent
	local buyRemote = PlayerData.remote("RemoteFunction", "Buy") :: RemoteFunction
	local stopRemote = PlayerData.remote("RemoteEvent", "StopTraining") :: RemoteEvent
	local busy: { [Player]: boolean } = {}
	buyRemote.OnServerInvoke = function(player: Player, what: any, arg: any)
		if busy[player] or typeof(what) ~= "string" then
			return false, "..."
		end
		busy[player] = true
		local ok, okBuy, message = pcall(buy, player, what, arg)
		busy[player] = nil
		if not ok then
			warn(`Upgrades: {player.Name} {what}: {okBuy}`)
			return false, "Something went wrong"
		end
		return okBuy, message
	end
	stopRemote.OnServerEvent:Connect(stopTraining)

	-- the Train Speed prompt on every home's wheel (the wheel is rebuilt on level up, so listen for any of them)
	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		if prompt.Name ~= "TrainPrompt" then
			return
		end
		local hole: Instance? = prompt.Parent
		while hole and not hole:GetAttribute("HoleIndex") do
			hole = hole.Parent
		end
		if not hole or not hole:IsA("Model") then
			return
		end
		if hole:GetAttribute("Owner") ~= player.UserId then
			notice:FireClient(player, "Train on your own wheel!", "warn")
			return
		end
		if player:GetAttribute("Training") then
			stopTraining(player)
		else
			startTraining(player, hole)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		busy[player] = nil
	end)

	-- training ticks
	task.spawn(function()
		while true do
			task.wait(0.5)
			for _, player in Players:GetPlayers() do
				if not player:GetAttribute("Training") then
					continue
				end
				local p = PlayerData.get(player)
				local root = Knock.root(player)
				if not p or not root then
					stopTraining(player)
					continue
				end
				p.SpeedProgress += 0.5 * GameConfig.trainRate(p.WheelLevel)
				local gained = false
				while
					p.SpeedPoints < GameConfig.SPEED_MAX_POINTS
					and p.SpeedProgress >= GameConfig.trainSeconds(p.SpeedPoints)
				do
					p.SpeedProgress -= GameConfig.trainSeconds(p.SpeedPoints)
					p.SpeedPoints += 1
					gained = true
				end
				player:SetAttribute(
					"TrainProgress",
					p.SpeedProgress / GameConfig.trainSeconds(math.min(p.SpeedPoints, GameConfig.SPEED_MAX_POINTS - 1))
				)
				if gained then
					PlayerData.changed(player)
					if p.SpeedPoints >= GameConfig.SPEED_MAX_POINTS then
						notice:FireClient(player, "Speed maxed out!", "good")
						stopTraining(player)
					end
				end
			end
		end
	end)
end

return Upgrades
