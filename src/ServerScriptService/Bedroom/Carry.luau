--!strict
-- Sleeping toys and carrying them home.
--   Every spot in Workspace.Bedroom.ToySpawns gets a sleeping toy: a blanket lump the size of the spot (S/M/L) hiding
--   a toy from the Bedroom set, its rarity rolled with the plan's odds for that size. Epic and up leak a glow.
--   Hold the prompt to grab it: you drag the bundle behind you, slower and noisier the bigger it is (noise counts the
--   floor, so creaky boards are loud). Walk into your own home and the toy wakes up in your pen.
--   A hazard (DropCarried), or the Drop Toy button, drops it where you stand; anyone can grab it again. An empty spot
--   gets a new toy after a while.
-- The Player attributes Carrying (toy id) and CarrySize say what someone is dragging; the HUD and hazards read them.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MapConfig = require(Shared:WaitForChild("MapConfig")) :: any
local Kit = require(ServerStorage:WaitForChild("TinyToyHeistTools"):WaitForChild("Bedroom"):WaitForChild("Kit")) :: any
local Events = require(script.Parent.Events)
local Knock = require(script.Parent.Knock)

local Carry = {}
Carry.SPEED = { S = 0.95, M = 0.8, L = 0.6 } -- walk speed while carrying
Carry.NOISE = { S = 0.5, M = 1, L = 2 } -- wake meter points a second while moving, before the floor's multiplier
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
local function pickToy(size: string): any?
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
local function makeBlanket(parent: Instance, size: string, at: CFrame): Model
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

function Carry.start(bedroom: Model)
	local spawns = bedroom:WaitForChild("ToySpawns")
	local holes = bedroom:WaitForChild("Holes")
	local sleeping = Kit.folder(bedroom, "SleepingToys")
	local remotes = ReplicatedStorage:WaitForChild("BedroomRemotes")
	local dropRequest = remotes:FindFirstChild("DropRequest") or Instance.new("RemoteEvent")
	dropRequest.Name = "DropRequest"
	dropRequest.Parent = remotes
	local notice = remotes:FindFirstChild("Notice") or Instance.new("RemoteEvent")
	notice.Name = "Notice"
	notice.Parent = remotes
	Kit.yieldEvery = 0

	type Carried = { blanket: Model, data: any, size: string, weld: WeldConstraint?, baseSpeed: number }
	local carrying: { [Player]: Carried } = {}

	local function setPrompt(blanket: Model, enabled: boolean)
		local prompt = blanket.PrimaryPart and blanket.PrimaryPart:FindFirstChild("GrabPrompt") :: ProximityPrompt?
		if prompt then
			prompt.Enabled = enabled
		end
	end

	local grab: (player: Player, blanket: Model) -> ()

	-- Put a sleeping toy under a blanket at `at`, grabbable
	local function sleepToy(at: CFrame, size: string, spawnPoint: BasePart?, data: any?): Model?
		local toy = data or pickToy(size)
		local blanket = makeBlanket(sleeping, size, at)
		blanket:SetAttribute("ToyId", if toy then toy.Id else "")
		blanket:SetAttribute("Rarity", if toy then toy.Rarity else "Common")
		if spawnPoint then
			blanket:SetAttribute("Spawn", spawnPoint.Name)
		end
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "GrabPrompt"
		prompt.ActionText = "Grab"
		prompt.ObjectText = ({ S = "Small toy", M = "Medium toy", L = "Large toy" } :: any)[size] or "Toy"
		prompt.HoldDuration = Carry.HOLD[size] or 0.5
		prompt.MaxActivationDistance = 12 + (Carry.SCALE[size] or 1) * 3
		prompt.RequiresLineOfSight = false
		prompt.Parent = blanket.PrimaryPart
		prompt.Triggered:Connect(function(player)
			grab(player, blanket)
		end)
		if toy and ToyVFX then
			pcall(ToyVFX.addGlowTell, blanket, toy.Rarity)
		end
		return blanket
	end

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
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = c.baseSpeed
		end
		return c
	end

	-- Drop it where the player is: it lies there, grabbable, until someone takes it or it goes back to sleep
	local function drop(player: Player)
		local c = release(player)
		if not c then
			return
		end
		local root = Knock.root(player)
		local position = if root then root.Position else c.blanket:GetPivot().Position
		local at = CFrame.new(position.X, 0, position.Z)
		for _, p in c.blanket:GetDescendants() do
			if p:IsA("BasePart") then
				p.Anchored = true
				p.Massless = false
			end
		end
		c.blanket:PivotTo(at * CFrame.Angles(0, rng:NextNumber() * math.pi * 2, 0))
		c.blanket:SetAttribute("Spawn", nil)
		c.blanket:SetAttribute("DroppedAt", os.clock())
		setPrompt(c.blanket, true)
		local blanket = c.blanket
		task.delay(Carry.LOOSE_TIME, function()
			if
				blanket.Parent
				and blanket:GetAttribute("DroppedAt")
				and os.clock() - (blanket:GetAttribute("DroppedAt") :: number) >= Carry.LOOSE_TIME - 0.5
			then
				blanket:Destroy()
			end
		end)
	end

	grab = function(player: Player, blanket: Model)
		if carrying[player] or not blanket.Parent then
			return
		end
		local character = player.Character
		local root = Knock.root(player)
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not root or not humanoid or not Knock.ready(player) then
			return
		end
		local size = blanket:GetAttribute("Size") :: string
		local id = blanket:GetAttribute("ToyId") :: string
		local data = if ToyCatalog and id ~= "" then ToyCatalog.get(id) else nil
		setPrompt(blanket, false)
		blanket:SetAttribute("Spawn", nil)
		blanket:SetAttribute("DroppedAt", nil)
		-- drag it along the floor behind you
		local scale = Carry.SCALE[size] or 1
		blanket:PivotTo(root.CFrame * CFrame.new(0, -3, 3 + 3.5 * scale))
		for _, p in blanket:GetDescendants() do
			if p:IsA("BasePart") then
				p.Anchored = false
				p.Massless = true
				p.CanCollide = false
			end
		end
		local lump = blanket.PrimaryPart :: BasePart
		for _, p in blanket:GetDescendants() do
			if p:IsA("BasePart") and p ~= lump then
				local w = Instance.new("WeldConstraint")
				w.Part0, w.Part1 = lump, p
				w.Parent = lump
			end
		end
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = root, lump
		weld.Parent = lump
		pcall(function()
			lump:SetNetworkOwner(player)
		end)
		local base = humanoid.WalkSpeed
		humanoid.WalkSpeed = base * (Carry.SPEED[size] or 1)
		carrying[player] = { blanket = blanket, data = data, size = size, weld = weld, baseSpeed = base }
		player:SetAttribute("Carrying", if id ~= "" then id else "Toy")
		player:SetAttribute("CarrySize", size)
	end

	-- Into your own home: the toy wakes up in your pen
	local function bank(player: Player, hole: Instance)
		local c = carrying[player]
		if not c then
			return
		end
		local level = hole:GetAttribute("Level") :: number
		local toys = hole:FindFirstChild("PenToys")
		local capacity = MapConfig.HOLE_LEVELS[level].slots
		local count = 0
		for _, t in (toys :: Instance):GetChildren() do
			if not t:GetAttribute("Demo") then
				count += 1
			end
		end
		if count >= capacity then
			if not c.blanket:GetAttribute("FullWarned") then
				c.blanket:SetAttribute("FullWarned", true)
				notice:FireClient(player, "Your pen is full! Level up your home for more room.", "warn")
			end
			return
		end
		release(player)
		c.blanket:Destroy()
		local data = c.data
		local model: Model? = nil
		if data then
			local assets = ServerStorage:FindFirstChild("TinyToyHeistAssets")
			local folder = assets and assets:FindFirstChild("Toys")
			local prebuilt = folder and folder:FindFirstChild(data.Id)
			if prebuilt and prebuilt:IsA("Model") then
				model = prebuilt:Clone()
			else
				pcall(function()
					local ToyBuilder = require(Shared.Toys:FindFirstChild("ToyBuilder") :: ModuleScript) :: any
					model = ToyBuilder.build(data)
				end)
			end
		end
		if not model then
			return
		end
		local toy = model :: Model
		local index = hole:GetAttribute("HoleIndex") :: number
		local pen = hole:FindFirstChild("Pen") :: BasePart
		local frame = MapConfig.homeFrame(index)
		local p = (pen:GetAttribute("PenMin") :: Vector3):Lerp(pen:GetAttribute("PenMax") :: Vector3, 0.5)
		toy:PivotTo(frame * CFrame.new(p.X, pen:GetAttribute("PenTop") :: number, p.Z))
		toy:SetAttribute("RoamSeed", rng:NextInteger(1, 1e6))
		toy:SetAttribute("Size", data.Size)
		toy:SetAttribute("Owner", player.UserId)
		toy.Parent = toys
		notice:FireClient(player, "Placed " .. (data.Name or data.Id) .. " in your home!", "good")
	end

	Events.DropCarried.Event:Connect(function(player: Player)
		if typeof(player) == "Instance" and player:IsA("Player") then
			drop(player)
		end
	end)
	dropRequest.OnServerEvent:Connect(drop)
	Players.PlayerRemoving:Connect(function(player)
		local c = release(player)
		if c then
			c.blanket:Destroy()
		end
	end)

	-- Carry noise, banking, and refilling empty spots
	task.spawn(function()
		local refillAt: { [string]: number } = {}
		while sleeping.Parent do
			task.wait(0.5)
			for player, c in carrying do
				local root = Knock.root(player)
				if not root or not c.blanket.Parent then
					release(player)
					continue
				end
				local v = root.AssemblyLinearVelocity
				if Vector3.new(v.X, 0, v.Z).Magnitude > 2 then
					Events.MakeNoise:Fire(root.Position, (Carry.NOISE[c.size] or 1) * 0.5, "Drag")
				end
				local index = MapConfig.homeAt(root.Position)
				local hole = index and holes:FindFirstChild("Hole" .. index)
				if hole and hole:GetAttribute("Owner") == player.UserId then
					bank(player, hole)
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

return Carry
