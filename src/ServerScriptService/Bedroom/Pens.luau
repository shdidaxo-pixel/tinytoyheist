--!strict
-- The toys in each player's home, built from their saved profile (PlayerData). When a player's data loads, their
-- home gets its level and every toy they own roams the pen; when they leave, the pen is cleared.
--   Banking a sleeping toy: the blanket lies in your pen with a wake-up timer over it (Small 5 s, Medium 20 s,
--   Large 60 s). Then it pops open: the toy, its rarity and its mutation (rolled at banking, so leaving early or
--   rejoining can't re-roll it). Waking toys don't earn yet.
--   Every toy in a pen carries a Steal prompt; Raids decides who may use it (the owner's client hides their own).
--   The Index (toy x mutation found) is kept here too, with the room-set rewards.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MapConfig = require(Shared:WaitForChild("MapConfig")) :: any
local GameConfig = require(Shared:WaitForChild("GameConfig")) :: any
local Toys = Shared:WaitForChild("Toys")
local ToyCatalog = require(Toys:WaitForChild("ToyCatalog")) :: any
local Mutations = require(Toys:WaitForChild("Mutations")) :: any
local PlayerData = require(script.Parent.PlayerData)
local Homes = require(script.Parent.Homes)

local Pens = {}
Pens.onSteal = nil :: ((thief: Player, owner: Player, uid: string, model: Model) -> ())?

type Toy = PlayerData.Toy
type State = {
	hole: Model,
	models: { [string]: Model }, -- awake toys in the pen, by uid
	waking: { [string]: Model }, -- blankets waking up, by uid
	out: { [string]: boolean }, -- being stolen right now (carried or dropped by a raider)
}
local states: { [Player]: State } = {}
local rng = Random.new()
local revealRemote: RemoteEvent
local notice: RemoteEvent

local function hash(s: string): number
	local h = 7
	for i = 1, #s do
		h = (h * 31 + string.byte(s, i)) % 999983
	end
	return h + 1
end

function Pens.state(player: Player): State?
	return states[player]
end

function Pens.find(player: Player, uid: string): (Toy?, number?)
	local p = PlayerData.get(player)
	if not p then
		return nil, nil
	end
	for i, t in p.Toys do
		if t.u == uid then
			return t, i
		end
	end
	return nil, nil
end

-- Money a toy earns a second (before rebirth and boosts)
function Pens.perSecond(entry: Toy): number
	local data = ToyCatalog.get(entry.id)
	return (if data then data.Money else 0) * Mutations.multiplier(entry.m)
end

function Pens.capacity(player: Player): number
	local p = PlayerData.get(player)
	local level = if p then p.HomeLevel else 1
	return MapConfig.HOLE_LEVELS[math.clamp(level, 1, #MapConfig.HOLE_LEVELS)].slots
end

function Pens.isFull(player: Player): boolean
	local p = PlayerData.get(player)
	return p == nil or #p.Toys >= Pens.capacity(player)
end

-- What every awake toy at home earns a second, before multipliers
function Pens.income(player: Player): number
	local p = PlayerData.get(player)
	local s = states[player]
	if not p or not s then
		return 0
	end
	local total = 0
	for _, t in p.Toys do
		if s.models[t.u] and not s.out[t.u] then
			total += Pens.perSecond(t)
		end
	end
	return total
end

-- Mutation luck: +2% for every room set finished in the Index
function Pens.luck(player: Player): number
	local p = PlayerData.get(player)
	local sets = 0
	if p then
		for _ in p.Sets do
			sets += 1
		end
	end
	return 1 + GameConfig.SET_LUCK * sets
end

local function penPoint(hole: Model, u: number?, v: number?): CFrame
	local pen = hole:FindFirstChild("Pen") :: BasePart
	local index = hole:GetAttribute("HoleIndex") :: number
	local penMin = pen:GetAttribute("PenMin") :: Vector3
	local penMax = pen:GetAttribute("PenMax") :: Vector3
	local x = penMin.X + (penMax.X - penMin.X) * (u or rng:NextNumber())
	local z = penMin.Z + (penMax.Z - penMin.Z) * (v or rng:NextNumber())
	return MapConfig.homeFrame(index) * CFrame.new(x, pen:GetAttribute("PenTop") :: number, z)
end
Pens.penPoint = penPoint

-- A toy model for a saved toy: the prebuilt voxel model with its mutation, ready for a pen
function Pens.buildToy(entry: Toy): Model?
	local assets = ServerStorage:FindFirstChild("TinyToyHeistAssets")
	local folder = assets and assets:FindFirstChild("Toys")
	local prebuilt = folder and folder:FindFirstChild(entry.id)
	local model: Model? = nil
	if prebuilt and prebuilt:IsA("Model") then
		model = prebuilt:Clone()
	else
		local data = ToyCatalog.get(entry.id)
		if data then
			pcall(function()
				local ToyBuilder = require(Toys:FindFirstChild("ToyBuilder") :: ModuleScript) :: any
				model = ToyBuilder.build(data)
			end)
		end
	end
	if not model then
		return nil
	end
	local toy = model :: Model
	if entry.m then
		pcall(Mutations.apply, toy, entry.m)
	end
	toy:SetAttribute("Uid", entry.u)
	toy:SetAttribute("RoamSeed", hash(entry.u))
	toy:SetAttribute("PerSecond", Pens.perSecond(entry))
	return toy
end

-- Put an awake toy in its owner's pen
local function show(player: Player, entry: Toy, at: CFrame?): Model?
	local s = states[player]
	if not s then
		return nil
	end
	local toy = Pens.buildToy(entry)
	if not toy then
		return nil
	end
	toy:SetAttribute("Owner", player.UserId)
	local spot = at or penPoint(s.hole)
	toy:PivotTo(spot * CFrame.Angles(0, rng:NextNumber() * math.pi * 2, 0))
	local root = toy.PrimaryPart
	if root then
		local data = ToyCatalog.get(entry.id)
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "StealPrompt"
		prompt.ActionText = "Steal"
		prompt.ObjectText = if data then data.Name else "Toy"
		prompt.HoldDuration = GameConfig.RAID.hold
		prompt.MaxActivationDistance = 10 + (toy:GetAttribute("Height") :: number? or 8) * 0.3
		prompt.RequiresLineOfSight = false
		prompt.Parent = root
		prompt.Triggered:Connect(function(thief)
			local model = s.models[entry.u]
			if Pens.onSteal and thief ~= player and model then
				Pens.onSteal(thief, player, entry.u, model)
			end
		end)
	end
	s.models[entry.u] = toy
	toy.Parent = s.hole:FindFirstChild("PenToys")
	return toy
end

local function sync(player: Player)
	PlayerData.changed(player)
	local s = states[player]
	if s then
		local income = Pens.income(player)
		player:SetAttribute("BaseIncome", income)
	end
end

-- Record a find in the Index; a finished room set pays out once
local function discover(player: Player, entry: Toy)
	local p = PlayerData.get(player)
	if not p then
		return
	end
	local found = p.Index[entry.id] or {}
	found[entry.m or "None"] = true
	p.Index[entry.id] = found
	local data = ToyCatalog.get(entry.id)
	local set = data and data.Set
	if set and GameConfig.SET_REWARD[set] and not p.Sets[set] then
		for _, t in ToyCatalog.inSet(set) do
			if not p.Index[t.Id] then
				return
			end
		end
		p.Sets[set] = true
		local reward = GameConfig.SET_REWARD[set]
		PlayerData.addCash(player, reward)
		notice:FireClient(
			player,
			`{ToyCatalog.setName(set)} set complete! +{GameConfig.money(reward)} and +2% luck`,
			"good"
		)
	end
end

-- The wake-up: the blanket pops and the toy comes out
local function reveal(player: Player, entry: Toy)
	local s = states[player]
	if not s then
		return
	end
	local blanket = s.waking[entry.u]
	s.waking[entry.u] = nil
	local at = if blanket then CFrame.new(blanket:GetPivot().Position) else nil
	if blanket then
		blanket:Destroy()
	end
	if not Pens.find(player, entry.u) then
		return -- sold or gone meanwhile
	end
	local toy = show(player, entry, at)
	if toy then
		toy:SetAttribute("RevealedAt", Workspace:GetServerTimeNow())
	end
	local data = ToyCatalog.get(entry.id)
	revealRemote:FireClient(player, {
		id = entry.id,
		name = if data then data.Name else entry.id,
		rarity = if data then data.Rarity else "Common",
		mutation = entry.m,
		perSecond = Pens.perSecond(entry),
	})
	if data and (data.Rarity == "Mythic" or data.Rarity == "Secret") then
		for _, other in Players:GetPlayers() do
			notice:FireClient(other, `{player.DisplayName} found a {data.Rarity} {data.Name}!`, "good")
		end
	end
	sync(player)
end

-- A sleeping toy carried home (or a reward toy): it goes in the profile now, and wakes up in the pen after its
-- timer. `blanket` is the carried blanket (it lies in the pen while the toy wakes); `size` the blanket's size.
function Pens.bank(player: Player, data: any, size: string, blanket: Model?): Toy?
	local p = PlayerData.get(player)
	local s = states[player]
	if not p or not s or Pens.isFull(player) then
		return nil
	end
	if p.Banked == 0 and ToyCatalog.get(GameConfig.FIRST_TOY) then
		data = ToyCatalog.get(GameConfig.FIRST_TOY) -- the first toy is always the Plush Bunny
	end
	local mutation = if p.Banked == 0
		then nil
		else Mutations.roll(rng, { NightmareNight = false, Halloween = false }, Pens.luck(player))
	local entry: Toy = { u = PlayerData.newUid(), id = data.Id, m = mutation }
	table.insert(p.Toys, entry)
	p.Banked += 1
	discover(player, entry)
	local wake = GameConfig.WAKE_SECONDS[size] or 5
	if blanket then
		for _, d in blanket:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
			elseif d:IsA("WeldConstraint") or d:IsA("ProximityPrompt") then
				d:Destroy()
			end
		end
		local waking = s.hole:FindFirstChild("Waking") or Instance.new("Folder")
		waking.Name = "Waking"
		waking.Parent = s.hole
		blanket:PivotTo(penPoint(s.hole, rng:NextNumber(0.2, 0.8), rng:NextNumber(0.1, 0.5)))
		blanket:SetAttribute("Uid", entry.u)
		blanket:SetAttribute("Owner", player.UserId)
		blanket:SetAttribute("WakeAt", Workspace:GetServerTimeNow() + wake)
		blanket:SetAttribute("WakeSeconds", wake)
		blanket.Parent = waking
		s.waking[entry.u] = blanket
		task.delay(wake, reveal, player, entry)
	else
		reveal(player, entry)
	end
	sync(player)
	return entry
end

-- Take a toy out of the pen for a raider (it stays in the owner's profile until it reaches the thief's home)
function Pens.take(player: Player, uid: string): Model?
	local s = states[player]
	local model = s and s.models[uid]
	if not s or not model then
		return nil
	end
	s.models[uid] = nil
	s.out[uid] = true
	local prompt = model.PrimaryPart and model.PrimaryPart:FindFirstChild("StealPrompt")
	if prompt then
		prompt:Destroy()
	end
	sync(player)
	return model
end

-- A stolen toy comes home (dropped and left alone, or the thief was stopped)
function Pens.restore(player: Player, uid: string)
	local s = states[player]
	if not s then
		return
	end
	s.out[uid] = nil
	local entry = Pens.find(player, uid)
	if entry and not s.models[uid] then
		show(player, entry)
	end
	sync(player)
end

-- Remove a toy from a player for good (sold, or stolen). Returns its saved entry.
function Pens.remove(player: Player, uid: string): Toy?
	local p = PlayerData.get(player)
	local s = states[player]
	local entry, i = Pens.find(player, uid)
	if not p or not entry or not i then
		return nil
	end
	table.remove(p.Toys, i)
	if s then
		s.out[uid] = nil
		if s.models[uid] then
			s.models[uid]:Destroy()
			s.models[uid] = nil
		end
		if s.waking[uid] then
			s.waking[uid]:Destroy()
			s.waking[uid] = nil
		end
	end
	sync(player)
	return entry
end

-- Give a toy that already woke up somewhere else (a stolen one) to a player: straight into the pen, awake
function Pens.give(player: Player, entry: Toy): boolean
	local p = PlayerData.get(player)
	if not p or not states[player] then
		return false
	end
	local copy: Toy = { u = PlayerData.newUid(), id = entry.id, m = entry.m }
	table.insert(p.Toys, copy)
	discover(player, copy)
	local toy = show(player, copy)
	if toy then
		toy:SetAttribute("RevealedAt", Workspace:GetServerTimeNow())
	end
	sync(player)
	return true
end

-- Rebuild a player's pen from their profile (after a rebirth or a level change it stays the same)
local function fill(player: Player)
	local p = PlayerData.get(player)
	local s = states[player]
	if not p or not s then
		return
	end
	for _, entry in p.Toys do
		if not s.models[entry.u] and not s.waking[entry.u] and not s.out[entry.u] then
			show(player, entry)
		end
	end
end

function Pens.setLevel(player: Player, level: number)
	local s = states[player]
	if s then
		s.hole:SetAttribute("Level", level)
	end
end

local function clear(player: Player)
	local s = states[player]
	if not s then
		return
	end
	states[player] = nil
	for _, m in s.models do
		m:Destroy()
	end
	for _, b in s.waking do
		b:Destroy()
	end
	s.hole:SetAttribute("Income", 0)
	if s.hole:GetAttribute("Level") ~= 1 then
		s.hole:SetAttribute("Level", 1)
	end
end

function Pens.start(_bedroom: Model)
	revealRemote = PlayerData.remote("RemoteEvent", "Reveal")
	local remotes = ReplicatedStorage:WaitForChild("BedroomRemotes")
	notice = remotes:FindFirstChild("Notice") :: RemoteEvent
	if not notice then
		notice = Instance.new("RemoteEvent")
		notice.Name = "Notice"
		notice.Parent = remotes
	end
	PlayerData.onLoaded(function(player, profile)
		local hole: Model? = nil
		for _ = 1, 100 do
			hole = Homes.homeOf(player)
			if hole or not player.Parent then
				break
			end
			task.wait(0.1)
		end
		if not hole or not player.Parent then
			return
		end
		states[player] = { hole = hole :: Model, models = {}, waking = {}, out = {} }
		(hole :: Model):SetAttribute("Level", profile.HomeLevel)
		fill(player)
		sync(player)
	end)
	PlayerData.onLeaving(clear)
end

return Pens
