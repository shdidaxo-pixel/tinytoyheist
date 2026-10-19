--!strict
-- Your toys and your home, built from your saved profile (PlayerData).
--   Inventory: every toy you own is in profile.Toys. Equipped toys (e ~= false) roam your pen, earn money and can be
--   stolen; the pen holds as many as the home level's slots. New toys equip themselves when there's a free slot
--   (Dylan, 19 Oct: "auto equip it so the players don't have to"); otherwise they wait in the inventory. Locked
--   toys (l = true) are skipped by Sell.
--   Blankets: a sleeping toy you carry home lies in your home with a wake-up timer (by blanket size and rarity,
--   10 s to 10 min: GameConfig.WAKE_SECONDS; saved in profile.Blankets so it keeps counting while you're away).
--   When it's ready you have to be there and hold E to hatch it: then the toy, its rarity and its mutation (rolled
--   at banking, so rejoining can't re-roll them) pop out and go into your inventory, with a size tier (Normal, Big,
--   Huge, Giant: ToySize) rolled right then.
--   The Index (toy x mutation found) and the room-set rewards are kept here too.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MapConfig = require(Shared:WaitForChild("MapConfig")) :: any
local GameConfig = require(Shared:WaitForChild("GameConfig")) :: any
local Toys = Shared:WaitForChild("Toys")
local ToyCatalog = require(Toys:WaitForChild("ToyCatalog")) :: any
local Mutations = require(Toys:WaitForChild("Mutations")) :: any
local ToySize = require(Toys:WaitForChild("ToySize")) :: any
local SIZE_TARGET = (require(Toys:WaitForChild("ToyBuilder")) :: any).SIZE_TARGET :: { [string]: number }
local PlayerData = require(script.Parent.PlayerData)
local Homes = require(script.Parent.Homes)

local Pens = {}
-- Builds a blanket model (set by Carry, which owns the blanket look): (parent, size, at) -> Model
Pens.makeBlanket = nil :: ((parent: Instance, size: string, at: CFrame) -> Model)?

type Toy = PlayerData.Toy
type Blanket = PlayerData.Blanket
type State = {
	hole: Model,
	models: { [string]: Model }, -- equipped toys in the pen, by uid
	blankets: { [string]: Model }, -- blankets waking up or ready to hatch, by uid
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

local function isEquipped(t: Toy): boolean
	return t.e ~= false
end
Pens.isEquipped = isEquipped

-- Which player's pen a toy is roaming, and its model
function Pens.findToy(uid: string): (Player?, Model?)
	for player, s in states do
		if s.models[uid] then
			return player, s.models[uid]
		end
	end
	return nil, nil
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

local function findBlanket(player: Player, uid: string): (Blanket?, number?)
	local p = PlayerData.get(player)
	if not p then
		return nil, nil
	end
	for i, b in p.Blankets do
		if b.u == uid then
			return b, i
		end
	end
	return nil, nil
end

-- Money a toy earns a second (before rebirth and boosts): its base money x mutation x size tier
function Pens.perSecond(entry: Toy): number
	local data = ToyCatalog.get(entry.id)
	return (if data then data.Money else 0) * Mutations.multiplier(entry.m) * ToySize.money(entry.z)
end

-- How many toys the pen holds (the home level's slots)
-- Room in the inventory for one more awake toy (a stolen one)
function Pens.hasRoom(player: Player): (boolean, string?)
	local p = PlayerData.get(player)
	if not p or not states[player] then
		return false, "Still loading..."
	end
	if #p.Toys + #p.Blankets >= GameConfig.INVENTORY_MAX then
		return false, "Your inventory is full! Sell some toys."
	end
	return true, nil
end

function Pens.capacity(player: Player): number
	local p = PlayerData.get(player)
	local level = if p then p.HomeLevel else 1
	return MapConfig.HOLE_LEVELS[math.clamp(level, 1, #MapConfig.HOLE_LEVELS)].slots
end

function Pens.equippedCount(player: Player): number
	local p = PlayerData.get(player)
	local n = 0
	if p then
		for _, t in p.Toys do
			if isEquipped(t) then
				n += 1
			end
		end
	end
	return n
end

-- Can this player take another toy home? (false and why if not)
function Pens.canBank(player: Player): (boolean, string?)
	local p = PlayerData.get(player)
	if not p or not states[player] then
		return false, "Still loading..."
	end
	if #p.Blankets >= GameConfig.MAX_BLANKETS then
		return false, "Hatch your blankets first! (hold E on them at home)"
	end
	if #p.Toys + #p.Blankets >= GameConfig.INVENTORY_MAX then
		return false, "Your inventory is full! Sell some toys."
	end
	return true, nil
end

-- What every equipped toy at home earns a second, before multipliers
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

-- A toy model for a saved toy: the prebuilt voxel model with its mutation, at its blanket's size
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
	-- it wakes up at the size of the blanket it came out of (a Large blanket gives a big one); money stays the toy's
	local natural = toy:GetAttribute("Size") :: string?
	local target = SIZE_TARGET[entry.s or ""]
	if entry.s and natural and entry.s ~= natural and target and SIZE_TARGET[natural] then
		local k = target / SIZE_TARGET[natural]
		toy:ScaleTo(toy:GetScale() * k)
		toy:SetAttribute("Size", entry.s)
		local height = toy:GetAttribute("Height") :: number?
		if height then
			toy:SetAttribute("Height", height * k)
		end
	end
	-- then its size tier on top (Big x1.5, Huge x2, Giant x3); sets Reach so it roams inside the pen
	ToySize.apply(toy, entry.z)
	toy:SetAttribute("Uid", entry.u)
	toy:SetAttribute("RoamSeed", hash(entry.u))
	toy:SetAttribute("PerSecond", Pens.perSecond(entry))
	return toy
end

-- A small "HUGE" tag floating over a Big, Huge or Giant toy in a pen, in the tier's colour
local function sizeTag(toy: Model, root: BasePart, tier: string)
	local gui = Instance.new("BillboardGui")
	gui.Name = "SizeTag"
	gui.Size = UDim2.fromOffset(110, 30)
	gui.StudsOffsetWorldSpace = Vector3.new(0, ((toy:GetAttribute("Height") :: number?) or 8) * 0.55 + 2, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 120
	gui.Adornee = root
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Text = string.upper(tier)
	label.TextColor3 = ToySize.color(tier)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2.5
	stroke.Color = Color3.fromRGB(26, 20, 48)
	stroke.Parent = label
	label.Parent = gui
	gui.Parent = root
end

-- Put an equipped toy in its owner's pen
local function show(player: Player, entry: Toy, at: CFrame?): Model?
	local s = states[player]
	if not s or s.models[entry.u] then
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
		prompt.ObjectText = (if ToySize.isBig(entry.z) then ToySize.name(entry.z) .. " " else "")
			.. (if data then data.Name else "Toy")
		prompt.HoldDuration = GameConfig.RAID.hold
		-- reach: a Huge or Giant toy is wide, so you can grab it from its side
		prompt.MaxActivationDistance = 10
			+ (toy:GetAttribute("Height") :: number? or 8) * 0.3
			+ (toy:GetAttribute("Reach") :: number? or 4) * 0.6
		prompt.RequiresLineOfSight = false
		-- the toy roams only on the clients, so the server would refuse this prompt on distance: the client sends
		-- GameRemotes.Steal instead and Raids checks the distance against PenRoam
		prompt.Parent = root
		if ToySize.isBig(entry.z) then
			sizeTag(toy, root, entry.z :: string)
		end
	end
	s.models[entry.u] = toy
	toy.Parent = s.hole:FindFirstChild("PenToys")
	return toy
end

local function hide(player: Player, uid: string)
	local s = states[player]
	if s and s.models[uid] then
		s.models[uid]:Destroy()
		s.models[uid] = nil
	end
end

local function sync(player: Player)
	PlayerData.changed(player)
	if states[player] then
		player:SetAttribute("BaseIncome", Pens.income(player))
		player:SetAttribute("Equipped", Pens.equippedCount(player))
		player:SetAttribute("Slots", Pens.capacity(player))
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

-- Add a toy to the inventory, equipping it if the pen has room. Returns whether it was equipped.
local function addToy(player: Player, entry: Toy, at: CFrame?): boolean
	local p = PlayerData.get(player)
	if not p then
		return false
	end
	entry.e = Pens.equippedCount(player) < Pens.capacity(player)
	table.insert(p.Toys, entry)
	discover(player, entry)
	if entry.e then
		local toy = show(player, entry, at)
		if toy then
			toy:SetAttribute("RevealedAt", Workspace:GetServerTimeNow())
		end
	end
	return entry.e == true
end

-- A blanket lying in a home: counting down, then waiting to be hatched (the owner holds E on it)
local function placeBlanket(player: Player, b: Blanket, model: Model?)
	local s = states[player]
	if not s then
		return
	end
	local blanket = model
	if not blanket then
		if not Pens.makeBlanket then
			return
		end
		blanket = (Pens.makeBlanket :: any)(s.hole, b.s, CFrame.new())
	end
	local m = blanket :: Model
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.Massless = false
		elseif d:IsA("WeldConstraint") or d:IsA("ProximityPrompt") then
			d:Destroy()
		end
	end
	local waking = s.hole:FindFirstChild("Waking") or Instance.new("Folder")
	waking.Name = "Waking"
	waking.Parent = s.hole
	-- blankets lie along the front of the pen, the first ones in the middle
	local k = #waking:GetChildren()
	local u = 0.5 + (if k % 2 == 0 then 1 else -1) * (k + 1) // 2 * 0.16
	m:PivotTo(penPoint(s.hole, math.clamp(u, 0.08, 0.92), 0.08) * CFrame.Angles(0, rng:NextNumber() * 0.6 - 0.3, 0))
	local left = math.max(0, b.w - os.time())
	local data = ToyCatalog.get(b.id)
	local wake = math.max(b.t or ToySize.wakeSeconds(b.s, data and data.Rarity), left, 1)
	m:SetAttribute("Uid", b.u)
	m:SetAttribute("Owner", player.UserId)
	m:SetAttribute("Size", b.s)
	m:SetAttribute("WakeAt", Workspace:GetServerTimeNow() + left)
	m:SetAttribute("WakeSeconds", wake)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "HatchPrompt"
	prompt.ActionText = "Hatch"
	prompt.ObjectText = ({ S = "Small toy", M = "Medium toy", L = "Large toy" } :: any)[b.s] or "Toy"
	prompt.HoldDuration = 0.8
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Enabled = left <= 0
	prompt.Parent = m.PrimaryPart
	prompt.Triggered:Connect(function(who)
		if who == player then
			Pens.hatch(player, b.u)
		end
	end)
	m.Name = "Blanket"
	m.Parent = waking
	s.blankets[b.u] = m
	if left > 0 then
		task.delay(left, function()
			if prompt.Parent then
				prompt.Enabled = true
				m:SetAttribute("Ready", true)
			end
		end)
	else
		m:SetAttribute("Ready", true)
	end
end

-- A sleeping toy carried home (or a reward toy): it lies in your home as a blanket until you hatch it.
-- `blanket` is the carried blanket model, if any; `size` the blanket's size.
function Pens.bank(player: Player, data: any, size: string, blanket: Model?): Blanket?
	local p = PlayerData.get(player)
	if not p or not states[player] or not Pens.canBank(player) then
		return nil
	end
	if p.Banked == 0 and ToyCatalog.get(GameConfig.FIRST_TOY) then
		data = ToyCatalog.get(GameConfig.FIRST_TOY) -- the first toy is always the Plush Bunny
	end
	local mutation = if p.Banked == 0
		then nil
		else Mutations.roll(rng, { NightmareNight = false, Halloween = false }, Pens.luck(player))
	-- bigger blankets and rarer toys take longer to wake; the first toy ever is quick (the tutorial)
	local wake = ToySize.wakeSeconds(size, data.Rarity, p.Banked == 0)
	local b: Blanket = {
		u = PlayerData.newUid(),
		id = data.Id,
		m = mutation,
		s = size,
		w = os.time() + wake,
		t = wake,
	}
	table.insert(p.Blankets, b)
	p.Banked += 1
	placeBlanket(player, b, blanket)
	sync(player)
	return b
end

-- Studio tests: set the Player attribute DebugSizeTier ("Big", "Huge", "Giant" or "Normal") on the server and the
-- next hatch comes out that size instead of rolling
local function debugSize(player: Player): string?
	local want = player:GetAttribute("DebugSizeTier")
	if not RunService:IsStudio() or typeof(want) ~= "string" then
		return nil
	end
	player:SetAttribute("DebugSizeTier", nil)
	return if ToySize.name(want) == want then want else nil
end

-- Hold E on a ready blanket: the toy pops out into your inventory (and your pen, if there's room)
function Pens.hatch(player: Player, uid: string): boolean
	local p = PlayerData.get(player)
	local s = states[player]
	local b, i = findBlanket(player, uid)
	if not p or not s or not b or not i then
		return false
	end
	if os.time() < b.w then
		return false
	end
	table.remove(p.Blankets, i)
	local model = s.blankets[uid]
	s.blankets[uid] = nil
	local at = if model then CFrame.new(model:GetPivot().Position) else nil
	if model then
		model:Destroy()
	end
	-- the size roll happens now, at hatch (Big / Huge / Giant, or nil for Normal), on top of the mutation
	local z = debugSize(player) or ToySize.roll(rng)
	local entry: Toy = { u = b.u, id = b.id, m = b.m, s = b.s, z = if ToySize.isBig(z) then z else nil }
	local equipped = addToy(player, entry, at)
	local data = ToyCatalog.get(entry.id)
	revealRemote:FireClient(player, {
		id = entry.id,
		name = if data then data.Name else entry.id,
		rarity = if data then data.Rarity else "Common",
		mutation = entry.m,
		size = entry.s,
		sizeTier = entry.z, -- nil = Normal
		sizeMult = ToySize.scale(entry.z), -- the VFX hatch burst grows with it
		perSecond = Pens.perSecond(entry),
		equipped = equipped,
	})
	if not equipped then
		notice:FireClient(player, "Your pen is full, so it went in your inventory.", "warn")
	end
	if data and (data.Rarity == "Mythic" or data.Rarity == "Secret") then
		for _, other in Players:GetPlayers() do
			notice:FireClient(other, `{player.DisplayName} found a {data.Rarity} {data.Name}!`, "good")
		end
	end
	sync(player)
	return true
end

-- Equip (into the pen) or unequip (back to the inventory) a toy
function Pens.equip(player: Player, uid: string, on: boolean): (boolean, string)
	local s = states[player]
	local entry = Pens.find(player, uid)
	if not s or not entry then
		return false, "?"
	end
	if s.out[uid] then
		return false, "Someone is stealing that toy!"
	end
	if on and not isEquipped(entry) then
		if Pens.equippedCount(player) >= Pens.capacity(player) then
			return false, "Your pen is full! Level up your home for more slots."
		end
		entry.e = true
		show(player, entry)
	elseif not on and isEquipped(entry) then
		entry.e = false
		hide(player, uid)
	end
	sync(player)
	return true, if on then "Equipped" else "Unequipped"
end

-- Fill the pen with your best-earning toys
function Pens.equipBest(player: Player): (boolean, string)
	local p = PlayerData.get(player)
	local s = states[player]
	if not p or not s then
		return false, "?"
	end
	local list = {}
	for _, t in p.Toys do
		if not s.out[t.u] then
			table.insert(list, t)
		end
	end
	table.sort(list, function(a, b)
		return Pens.perSecond(a) > Pens.perSecond(b)
	end)
	local slots = Pens.capacity(player)
	-- out toys keep their slot
	for _ in s.out do
		slots -= 1
	end
	for i, t in list do
		local want = i <= slots
		if want ~= isEquipped(t) then
			t.e = want
			if want then
				show(player, t)
			else
				hide(player, t.u)
			end
		end
	end
	sync(player)
	return true, "Equipped your best toys"
end

-- Put your best unequipped toys into any free pen slots (after a home level up)
function Pens.fillFree(player: Player)
	local p = PlayerData.get(player)
	local s = states[player]
	if not p or not s then
		return
	end
	local waiting = {}
	for _, t in p.Toys do
		if not isEquipped(t) then
			table.insert(waiting, t)
		end
	end
	table.sort(waiting, function(a, b)
		return Pens.perSecond(a) > Pens.perSecond(b)
	end)
	for _, t in waiting do
		if Pens.equippedCount(player) >= Pens.capacity(player) then
			break
		end
		t.e = true
		show(player, t)
	end
	sync(player)
end

function Pens.setLock(player: Player, uid: string, on: boolean): (boolean, string)
	local entry = Pens.find(player, uid)
	if not entry then
		return false, "?"
	end
	entry.l = if on then true else nil
	sync(player)
	return true, if on then "Locked" else "Unlocked"
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
	if entry and isEquipped(entry) and not s.models[uid] then
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
		hide(player, uid)
	end
	sync(player)
	return entry
end

-- Give a toy that already woke up somewhere else (a stolen one) to a player: into the inventory, equipped if room
function Pens.give(player: Player, entry: Toy): boolean
	if not PlayerData.get(player) or not states[player] then
		return false
	end
	addToy(player, { u = PlayerData.newUid(), id = entry.id, m = entry.m, s = entry.s, z = entry.z })
	sync(player)
	return true
end

-- Build a player's home from their profile: equipped toys in the pen and their blankets
local function fill(player: Player)
	local p = PlayerData.get(player)
	local s = states[player]
	if not p or not s then
		return
	end
	-- older saves had no equip flag: equip up to the pen's slots
	local equipped = 0
	for _, entry in p.Toys do
		if entry.e == nil then
			entry.e = equipped < Pens.capacity(player)
		end
		if isEquipped(entry) then
			equipped += 1
			if not s.out[entry.u] then
				show(player, entry)
			end
		end
	end
	for _, b in p.Blankets do
		if not s.blankets[b.u] then
			placeBlanket(player, b)
		end
	end
end

local function wipeWorld(s: State)
	for _, m in s.models do
		m:Destroy()
	end
	for _, b in s.blankets do
		b:Destroy()
	end
	local waking = s.hole:FindFirstChild("Waking")
	if waking then
		waking:ClearAllChildren()
	end
end

-- Throw away the home's toys and build them again from the profile (after a save wipe)
function Pens.reload(player: Player)
	local p = PlayerData.get(player)
	local s = states[player]
	if not p or not s then
		return
	end
	wipeWorld(s)
	s.models, s.blankets, s.out = {}, {}, {}
	s.hole:SetAttribute("Level", p.HomeLevel)
	s.hole:SetAttribute("WheelLevel", p.WheelLevel)
	fill(player)
	sync(player)
end

function Pens.setLevel(player: Player, level: number)
	local s = states[player]
	if s then
		s.hole:SetAttribute("Level", level)
	end
	sync(player)
end

function Pens.setWheel(player: Player, level: number)
	local s = states[player]
	if s then
		s.hole:SetAttribute("WheelLevel", level)
	end
end

local function clear(player: Player)
	local s = states[player]
	if not s then
		return
	end
	states[player] = nil
	wipeWorld(s)
	s.hole:SetAttribute("Income", 0)
	if s.hole:GetAttribute("Level") ~= 1 then
		s.hole:SetAttribute("Level", 1)
	end
	if s.hole:GetAttribute("WheelLevel") ~= 1 then
		s.hole:SetAttribute("WheelLevel", 1)
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
		states[player] = { hole = hole :: Model, models = {}, blankets = {}, out = {} }
		(hole :: Model):SetAttribute("Level", profile.HomeLevel);
		(hole :: Model):SetAttribute("WheelLevel", profile.WheelLevel)
		fill(player)
		sync(player)
	end)
	PlayerData.onLeaving(clear)
end

return Pens
