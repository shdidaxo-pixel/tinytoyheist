--!strict
-- Sleeping toys, stolen toys, and dragging them home.
--   Every spot in Workspace.Bedroom.ToySpawns gets a sleeping toy: a blanket lump the size of the spot (S/M/L) hiding
--   a toy from the Bedroom set, its rarity rolled with the plan's odds for that size. Epic and up leak a glow.
--   Hold the prompt to grab it (Large ones need Strength 5): you drag the bundle behind you, slower and noisier the
--   bigger it is (noise counts the floor, so creaky boards are loud; Sneak makes it quieter, Strength makes Large
--   ones faster). Walk into your own home and it goes in your pen to wake up (Pens.bank).
--   A stolen toy (Raids) is dragged the same way; it becomes yours only when it crosses your door.
--   A hazard (DropCarried), or the Drop Toy button, drops it where you stand (Grip can save it); anyone can grab it
--   again. A dropped stolen toy slides back home after a while; an empty spot gets a new sleeping toy.
-- Walk speed is set here too: the base plus Speed trained on the wheel, times the carry slow-down.
-- The Player attributes Carrying (toy id) and CarrySize say what someone is dragging; the HUD and hazards read them.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MapConfig = require(Shared:WaitForChild("MapConfig")) :: any
local GameConfig = require(Shared:WaitForChild("GameConfig")) :: any
local Kit = require(ServerStorage:WaitForChild("TinyToyHeistTools"):WaitForChild("Bedroom"):WaitForChild("Kit")) :: any
local Events = require(script.Parent.Events)
local Knock = require(script.Parent.Knock)
local PlayerData = require(script.Parent.PlayerData)
local Pens = require(script.Parent.Pens)

local Carry = {}
Carry.SPEED = GameConfig.CARRY_SPEED -- walk speed while carrying
Carry.NOISE = GameConfig.CARRY_NOISE -- wake meter points a second while moving, before the floor's multiplier
Carry.HOLD = { S = 0.3, M = 0.6, L = 1 } -- seconds to hold the grab prompt
Carry.SCALE = { S = 1.15, M = 1.4, L = 1.9 } -- blanket size, as in the render
Carry.RESPAWN = 25 -- seconds before an empty spot gets a new toy
Carry.LOOSE_TIME = 90 -- a dropped toy left alone this long goes back to sleep somewhere else
-- Rarity odds by blanket size (Day 1 plan): Small, Medium, Large
Carry.ODDS = {
	S = { Common = 70, Uncommon = 24, Rare = 5, Epic = 0.9, Legendary = 0.1 },
	M = { Common = 45, Uncommon = 35, Rare = 15, Epic = 4, Legendary = 0.9, Mythic = 0.1 },
	L = { Common = 20, Uncommon = 35, Rare = 28, Epic = 13, Legendary = 3.5, Mythic = 0.5 },
}
local RARITY_ORDER = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" }

-- Called when a stolen toy reaches the thief's home: (thief, owner)
Carry.onStealBanked = nil :: ((thief: Player, owner: Player) -> ())?

-- Blanket colour pairs from the concept render
local PALETTE = {
	{ 0x4DA8FF, 0xFFFFFF },
	{ 0xFF7AA8, 0xFFFFFF },
	{ 0x3DDC97, 0xFFF6D5 },
	{ 0x9B7BFF, 0xFFE07A },
	{ 0xFF8A3D, 0xFFF1D6 },
	{ 0x2F6FB9, 0xFFD95A },
	{ 0xE04848, 0xFFFFFF },
	{ 0x7FD6E8, 0x2B5F8C },
	{ 0xF2C6E0, 0x9B4D7A },
	{ 0xFFD95A, 0xE04848 },
}

local rng = Random.new()
local ToyCatalog: any, ToyVFX: any = nil, nil
do
	local Toys = Shared:FindFirstChild("Toys")
	if Toys then
		pcall(function()
			ToyCatalog = require(Toys:WaitForChild("ToyCatalog") :: ModuleScript)
			ToyVFX = require(Toys:WaitForChild("ToyVFX") :: ModuleScript)
		end)
	end
end

-- Pick a toy for a blanket of this size: roll a rarity, then a Bedroom toy of that rarity (or the nearest one there is)
function Carry.pickToy(size: string): any?
	if not ToyCatalog then
		return nil
	end
	local odds = Carry.ODDS[size] or Carry.ODDS.S
	local total = 0
	for _, w in odds do
		total += w
	end
	local roll = rng:NextNumber() * total
	local rarity = "Common"
	for _, name in RARITY_ORDER do
		local w = odds[name]
		if w then
			roll -= w
			if roll <= 0 then
				rarity = name
				break
			end
		end
	end
	local index = table.find(RARITY_ORDER, rarity) or 1
	for step = 0, #RARITY_ORDER do
		for _, k in { index - step, index + step } do
			local name = RARITY_ORDER[k]
			if name then
				local options = ToyCatalog.inSet("Bedroom", name)
				if #options > 0 then
					return options[rng:NextInteger(1, #options)]
				end
			end
		end
	end
	return nil
end

-- A soft stepped lump of blanket, its bottom centre at `at`. Returns the model (PrimaryPart "Lump").
function Carry.makeBlanket(parent: Instance, size: string, at: CFrame): Model
	local scale = Carry.SCALE[size] or 1
	local pal = PALETTE[rng:NextInteger(1, #PALETTE)]
	local model = Kit.model(parent, "SleepingToy", { Size = size })
	local w = 7 * scale
	local soft = { material = Enum.Material.Fabric }
	local lump = Kit.block(model, "Lump", w, 2.2 * scale, w * 0.95, at, 0, 0, 0, pal[1], soft)
	Kit.block(model, "Fold", w * 0.8, 2 * scale, w * 0.75, at, 0, 2.2 * scale, 0, pal[1], soft)
	Kit.block(
		model,
		"Top",
		w * 0.5,
		1.6 * scale,
		w * 0.45,
		at * CFrame.Angles(0, 0.3, 0),
		0,
		4.2 * scale,
		0,
		pal[1],
		soft
	)
	-- a contrasting hem, so blankets read apart
	Kit.block(
		model,
		"Hem",
		w + 0.4,
		0.5 * scale,
		w * 0.95 + 0.4,
		at,
		0,
		0,
		0,
		pal[2],
		{ material = Enum.Material.Fabric }
	)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.CanCollide = false -- you walk through sleeping toys; the prompt is how you grab them
		end
	end
	model.PrimaryPart = lump
	return model
end
local makeBlanket = Carry.makeBlanket

type Carried = {
	model: Model, -- the blanket, or the stolen toy itself
	kind: string, -- "Sleeping" or "Stolen"
	data: any, -- toy data (ToyCatalog)
	size: string,
	weld: WeldConstraint?,
	owner: Player?, -- Stolen: whose toy it is
	uid: string?, -- Stolen: the toy's id in the owner's profile
}
local carrying: { [Player]: Carried } = {}
-- Stolen toys lying on the floor: model -> { owner, uid }
local loose: { [Model]: { owner: Player, uid: string, droppedAt: number } } = {}
local notice: RemoteEvent

function Carry.isCarrying(player: Player): boolean
	return carrying[player] ~= nil
end

-- Walk speed: the base plus trained Speed, slowed while dragging (Strength helps with Large toys)
function Carry.refreshSpeed(player: Player)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local p = PlayerData.get(player)
	local speed = GameConfig.SPEED_BASE + (if p then p.SpeedPoints else 0)
	local c = carrying[player]
	if c then
		local factor = Carry.SPEED[c.size] or 1
		if c.size == "L" and p then
			factor = math.min(0.95, factor * (1 + 0.05 * (p.Stats.Strength or 0)))
		end
		speed *= factor
	end
	if player:GetAttribute("Training") then
		speed = 0
	end
	humanoid.WalkSpeed = speed
end

local function setPrompt(model: Model, enabled: boolean)
	local prompt = model.PrimaryPart and model.PrimaryPart:FindFirstChild("GrabPrompt") :: ProximityPrompt?
	if prompt then
		prompt.Enabled = enabled
	end
end

-- Weld a model behind the player and start dragging it
local function attach(player: Player, c: Carried): boolean
	local root = Knock.root(player)
	if not root then
		return false
	end
	local model = c.model
	setPrompt(model, false)
	local main = model.PrimaryPart :: BasePart
	if c.kind == "Sleeping" then
		local scale = Carry.SCALE[c.size] or 1
		model:PivotTo(root.CFrame * CFrame.new(0, -3, 3 + 3.5 * scale))
	else
		local ext = model:GetExtentsSize()
		model:PivotTo(root.CFrame * CFrame.new(0, -3, 2 + math.max(ext.X, ext.Z) / 2))
	end
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.Massless = true
			p.CanCollide = false
		end
	end
	if c.kind == "Sleeping" then
		for _, p in model:GetDescendants() do
			if p:IsA("BasePart") and p ~= main and not p:FindFirstChildOfClass("WeldConstraint") then
				local w = Instance.new("WeldConstraint")
				w.Part0, w.Part1 = main, p
				w.Parent = p
			end
		end
	end
	local weld = Instance.new("WeldConstraint")
	weld.Name = "CarryWeld"
	weld.Part0, weld.Part1 = root, main
	weld.Parent = main
	c.weld = weld
	pcall(function()
		main:SetNetworkOwner(player)
	end)
	carrying[player] = c
	player:SetAttribute("Carrying", if c.data then c.data.Id else "Toy")
	player:SetAttribute("CarrySize", c.size)
	Carry.refreshSpeed(player)
	return true
end

local function release(player: Player): Carried?
	local c = carrying[player]
	if not c then
		return nil
	end
	carrying[player] = nil
	player:SetAttribute("Carrying", nil)
	player:SetAttribute("CarrySize", nil)
	if c.weld then
		c.weld:Destroy()
	end
	Carry.refreshSpeed(player)
	return c
end

local sleeping: Folder
local grab: (player: Player, model: Model) -> ()

-- A grab prompt on a blanket or a loose stolen toy
local function addGrabPrompt(model: Model, objectText: string, hold: number, distance: number)
	local main = model.PrimaryPart :: BasePart
	local prompt = main:FindFirstChild("GrabPrompt") :: ProximityPrompt?
	if not prompt then
		local made = Instance.new("ProximityPrompt")
		made.Name = "GrabPrompt"
		made.ActionText = "Grab"
		made.RequiresLineOfSight = false
		made.Parent = main
		made.Triggered:Connect(function(player)
			grab(player, model)
		end)
		prompt = made
	end
	local pr = prompt :: ProximityPrompt
	pr.ObjectText = objectText
	pr.HoldDuration = hold
	pr.MaxActivationDistance = distance
	pr.Enabled = true
end

-- Put a sleeping toy under a blanket at `at`, grabbable
local function sleepToy(at: CFrame, size: string, spawnPoint: BasePart?, data: any?): Model?
	local toy = data or Carry.pickToy(size)
	local blanket = makeBlanket(sleeping, size, at)
	blanket:SetAttribute("ToyId", if toy then toy.Id else "")
	blanket:SetAttribute("Rarity", if toy then toy.Rarity else "Common")
	if spawnPoint then
		blanket:SetAttribute("Spawn", spawnPoint.Name)
	end
	addGrabPrompt(
		blanket,
		({ S = "Small toy", M = "Medium toy", L = "Large toy" } :: any)[size] or "Toy",
		Carry.HOLD[size] or 0.5,
		12 + (Carry.SCALE[size] or 1) * 3
	)
	if toy and ToyVFX then
		pcall(ToyVFX.addGlowTell, blanket, toy.Rarity)
	end
	return blanket
end

-- A stolen toy goes back to its owner's pen
local function sendBack(model: Model)
	local info = loose[model]
	loose[model] = nil
	model:Destroy()
	if info and info.owner.Parent then
		Pens.restore(info.owner, info.uid)
	end
end

-- Drop it where the player is: it lies there, grabbable, until someone takes it (or it goes back)
local function drop(player: Player)
	local c = release(player)
	if not c then
		return
	end
	local root = Knock.root(player)
	local position = if root then root.Position else c.model:GetPivot().Position
	local at = CFrame.new(position.X, 0, position.Z) * CFrame.Angles(0, rng:NextNumber() * math.pi * 2, 0)
	local model = c.model
	if c.kind == "Stolen" and c.owner and c.uid then
		for _, p in model:GetDescendants() do
			if p:IsA("BasePart") then
				p.Massless = false
			end
		end
		local main = model.PrimaryPart :: BasePart
		main.Anchored = true
		model:PivotTo(at)
		model.Parent = sleeping
		local glow = model:FindFirstChild("StolenGlow") or Instance.new("Highlight")
		glow.Name = "StolenGlow"
		(glow :: Highlight).FillTransparency = 0.7
		(glow :: Highlight).OutlineColor = Color3.fromRGB(255, 77, 94);
		(glow :: Highlight).FillColor = Color3.fromRGB(255, 77, 94)
		glow.Parent = model
		local info = { owner = c.owner, uid = c.uid, droppedAt = os.clock() }
		loose[model] = info
		addGrabPrompt(model, (c.data and c.data.Name or "Toy") .. " (stolen)", 0.5, 14)
		task.delay(GameConfig.RAID.returnAfter, function()
			if loose[model] == info then
				sendBack(model)
			end
		end)
		return
	end
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.Massless = false
		end
	end
	model:PivotTo(at)
	model:SetAttribute("Spawn", nil)
	model:SetAttribute("DroppedAt", os.clock())
	setPrompt(model, true)
	task.delay(Carry.LOOSE_TIME, function()
		if
			model.Parent
			and not carrying[player]
			and model:GetAttribute("DroppedAt")
			and os.clock() - (model:GetAttribute("DroppedAt") :: number) >= Carry.LOOSE_TIME - 0.5
		then
			model:Destroy()
		end
	end)
end
Carry.drop = drop

grab = function(player: Player, model: Model)
	if carrying[player] or not model.Parent or not Knock.root(player) or not Knock.ready(player) then
		return
	end
	if player:GetAttribute("Training") then
		return
	end
	local info = loose[model]
	if info then
		-- a dropped stolen toy: its owner sends it straight home; anyone else drags it off
		if info.owner == player then
			sendBack(model)
			notice:FireClient(player, "Got it back! It's home again.", "good")
			return
		end
		loose[model] = nil
		local glow = model:FindFirstChild("StolenGlow")
		if glow then
			glow:Destroy()
		end
		local id = model:GetAttribute("ToyId") :: string?
		attach(player, {
			model = model,
			kind = "Stolen",
			data = if ToyCatalog and id then ToyCatalog.get(id) else nil,
			size = (model:GetAttribute("Size") :: string?) or "M",
			owner = info.owner,
			uid = info.uid,
		})
		return
	end
	local size = model:GetAttribute("Size") :: string
	local p = PlayerData.get(player)
	if size == "L" and p and (p.Stats.Strength or 0) < GameConfig.LARGE_STRENGTH then
		notice:FireClient(player, `You need Strength {GameConfig.LARGE_STRENGTH} to drag Large toys!`, "warn")
		return
	end
	local id = model:GetAttribute("ToyId") :: string
	local data = if ToyCatalog and id ~= "" then ToyCatalog.get(id) else nil
	model:SetAttribute("Spawn", nil)
	model:SetAttribute("DroppedAt", nil)
	if attach(player, { model = model, kind = "Sleeping", data = data, size = size }) then
		local root = Knock.root(player)
		Events.ToyGrabbed:Fire(player, if root then root.Position else model:GetPivot().Position)
	end
end

-- A raider takes a toy out of someone's pen (Raids has checked it's allowed)
function Carry.carryStolen(thief: Player, owner: Player, uid: string): boolean
	if carrying[thief] then
		return false
	end
	local model = Pens.take(owner, uid)
	if not model then
		return false
	end
	if ToyVFX then
		pcall(ToyVFX.removeRarity, model)
	end
	model.Parent = sleeping
	local id = model:GetAttribute("ToyId") :: string?
	local size = (model:GetAttribute("Size") :: string?) or "M"
	if size == "G" then
		size = "L"
	end
	local ok = attach(thief, {
		model = model,
		kind = "Stolen",
		data = if ToyCatalog and id then ToyCatalog.get(id) else nil,
		size = size,
		owner = owner,
		uid = uid,
	})
	if not ok then
		model:Destroy()
		Pens.restore(owner, uid)
	end
	return ok
end

-- Into your own home
local function bank(player: Player)
	local c = carrying[player]
	if not c then
		return
	end
	if Pens.isFull(player) then
		if not c.model:GetAttribute("FullWarned") then
			c.model:SetAttribute("FullWarned", true)
			notice:FireClient(player, "Your pen is full! Level up your home for more room.", "warn")
		end
		return
	end
	if c.kind == "Stolen" then
		local owner, uid = c.owner, c.uid
		release(player)
		c.model:Destroy()
		if not owner or not uid or not owner.Parent then
			return
		end
		local entry = Pens.remove(owner, uid)
		if entry and Pens.give(player, entry) then
			local name = if c.data then c.data.Name else "toy"
			local pd = PlayerData.get(player)
			if pd then
				pd.Stolen += 1
			end
			notice:FireClient(player, `You stole {owner.DisplayName}'s {name}!`, "good")
			notice:FireClient(owner, `{player.DisplayName} stole your {name}!`, "warn")
			if Carry.onStealBanked then
				Carry.onStealBanked(player, owner)
			end
		end
		return
	end
	local data = c.data
	if not data then
		release(player)
		c.model:Destroy()
		return
	end
	release(player)
	c.model:SetAttribute("FullWarned", nil)
	local entry = Pens.bank(player, data, c.size, c.model)
	if not entry then
		c.model:Destroy()
		return
	end
	notice:FireClient(player, "+1 toy! It's waking up...", "good")
end

function Carry.start(bedroom: Model)
	local spawns = bedroom:WaitForChild("ToySpawns")
	local holes = bedroom:WaitForChild("Holes")
	sleeping = Kit.folder(bedroom, "SleepingToys")
	local remotes = ReplicatedStorage:WaitForChild("BedroomRemotes")
	local dropRequest = remotes:FindFirstChild("DropRequest") or Instance.new("RemoteEvent")
	dropRequest.Name = "DropRequest"
	dropRequest.Parent = remotes
	notice = remotes:FindFirstChild("Notice") :: RemoteEvent
	if not notice then
		notice = Instance.new("RemoteEvent")
		notice.Name = "Notice"
		notice.Parent = remotes
	end
	Kit.yieldEvery = 0

	-- Fill (or refill) a spawn spot
	local function fill(point: BasePart)
		local size = point:GetAttribute("Size") :: string
		local at = CFrame.new(point.Position.X, 0, point.Position.Z)
			* CFrame.Angles(0, rng:NextNumber() * math.pi * 2, 0)
		sleepToy(at, size, point)
	end
	local function emptySpots(): { BasePart }
		local taken = {}
		for _, blanket in sleeping:GetChildren() do
			local s = blanket:GetAttribute("Spawn")
			if s then
				taken[s] = true
			end
		end
		local out = {}
		for _, point in spawns:GetChildren() do
			if point:IsA("BasePart") and not taken[point.Name] then
				table.insert(out, point)
			end
		end
		return out
	end
	for _, point in emptySpots() do
		fill(point)
	end

	Events.DropCarried.Event:Connect(function(player: Player, _reason: string?, sentHome: boolean?)
		if typeof(player) ~= "Instance" or not player:IsA("Player") or not carrying[player] then
			return
		end
		-- Grip: a chance to hold on, unless you're being carried off home
		local p = PlayerData.get(player)
		local grip = if p then p.Stats.Grip or 0 else 0
		if not sentHome and grip > 0 and rng:NextNumber() < 0.05 * grip then
			notice:FireClient(player, "Grip! You held on to your toy.", "good")
			return
		end
		drop(player)
	end)
	dropRequest.OnServerEvent:Connect(drop)

	local function onCharacter(player: Player)
		player.CharacterAdded:Connect(function(character)
			local c = release(player)
			if c then
				if c.kind == "Stolen" and c.owner and c.uid then
					c.model:Destroy()
					Pens.restore(c.owner, c.uid)
				else
					c.model:Destroy()
				end
			end
			character:WaitForChild("Humanoid", 10)
			Carry.refreshSpeed(player)
		end)
	end
	Players.PlayerAdded:Connect(onCharacter)
	for _, player in Players:GetPlayers() do
		onCharacter(player)
		Carry.refreshSpeed(player)
	end
	PlayerData.onLoaded(function(player)
		Carry.refreshSpeed(player)
	end)
	-- leaving: a thief's stolen toy goes home; an owner's stolen toys leave with them
	PlayerData.onLeaving(function(player)
		for thief, c in carrying do
			if c.kind == "Stolen" and c.owner == player then
				release(thief)
				c.model:Destroy()
				notice:FireClient(thief, "Its owner left, and took the toy with them.", "warn")
			end
		end
		for model, info in loose do
			if info.owner == player then
				loose[model] = nil
				model:Destroy()
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		local c = release(player)
		if c then
			c.model:Destroy()
			if c.kind == "Stolen" and c.owner and c.uid and c.owner.Parent then
				Pens.restore(c.owner, c.uid)
			end
		end
	end)

	-- Carry noise, banking, and refilling empty spots
	task.spawn(function()
		local refillAt: { [string]: number } = {}
		while sleeping.Parent do
			task.wait(0.5)
			for player, c in carrying do
				local root = Knock.root(player)
				if not root or not c.model.Parent then
					release(player)
					if c.kind == "Stolen" and c.owner and c.uid then
						c.model:Destroy()
						Pens.restore(c.owner, c.uid)
					end
					continue
				end
				local v = root.AssemblyLinearVelocity
				if Vector3.new(v.X, 0, v.Z).Magnitude > 2 then
					local p = PlayerData.get(player)
					local sneak = if p then p.Stats.Sneak or 0 else 0
					local points = (Carry.NOISE[c.size] or 1) * 0.5 * math.max(0, 1 - 0.03 * sneak)
					Events.MakeNoise:Fire(root.Position, points, "Drag")
				end
				local index = MapConfig.homeAt(root.Position)
				local hole = index and holes:FindFirstChild("Hole" .. index)
				if hole and hole:GetAttribute("Owner") == player.UserId then
					bank(player)
				end
			end
			local now = os.clock()
			for _, point in emptySpots() do
				local due = refillAt[point.Name]
				if not due then
					refillAt[point.Name] = now + Carry.RESPAWN
				elseif now >= due then
					refillAt[point.Name] = nil
					fill(point)
				end
			end
		end
	end)
end

-- A reward toy: a sleeping toy of `size` put straight into the player's pen to wake up
function Carry.giveSleeping(player: Player, size: string): boolean
	if Pens.isFull(player) then
		return false
	end
	local data = Carry.pickToy(size)
	local state = Pens.state(player)
	if not data or not state then
		return false
	end
	local blanket = makeBlanket(sleeping, size, CFrame.new())
	return Pens.bank(player, data, size, blanket) ~= nil
end

return Carry
