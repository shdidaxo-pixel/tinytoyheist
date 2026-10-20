--!strict
-- The 8 homes at runtime: each player who joins gets a free home (its Owner attribute), spawns on its matchbox bed and
-- sees their name float over it. The push-pin locks the door for a while (strangers who walk in are pushed back
-- out). Changing a home's Level attribute rebuilds its dressing and Speed wheel.
-- Empty homes stay at Level 1 with nothing in them.
-- The look of a home is built by ServerStorage.TinyToyHeistTools.Bedroom.Homes (the same code as the map builder).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MapConfig = require(Shared:WaitForChild("MapConfig")) :: any
local GameConfig = require(Shared:WaitForChild("GameConfig")) :: any
local pieces = ServerStorage:WaitForChild("TinyToyHeistTools"):WaitForChild("Bedroom")
local Kit = require(pieces:WaitForChild("Kit")) :: any
local HomeLook = require(pieces:WaitForChild("Homes")) :: any
local Knock = require(script.Parent.Knock)

Kit.yieldEvery = 0 -- rebuilds at runtime are small; do them in one go

local Homes = {}
Homes.LOCK_TIME = 45
Homes.LOCK_COOLDOWN = 20 -- seconds after a lock runs out before it can be locked again (no locking forever)
Homes.CLAIM_ORDER = { 4, 5, 3, 6, 2, 7, 1, 8 } -- the middle of the curve first

local holes: Folder

local function homeOf(player: Player): Model?
	for _, hole in holes:GetChildren() do
		if hole:GetAttribute("Owner") == player.UserId then
			return hole :: Model
		end
	end
	return nil
end
Homes.homeOf = homeOf

-- Build part of a home's look at the map's full size (like the map builder does), then shrink the new parts about
-- the room's start by MapConfig.SCALE, so they land in the scaled world.
local function scaledBuild(hole: Model, build: () -> ())
	local before = {}
	for _, c in hole:GetChildren() do
		before[c] = true
	end
	build()
	local holder = Instance.new("Model")
	for _, c in hole:GetChildren() do
		if not before[c] then
			c.Parent = holder
		end
	end
	holder.Parent = Workspace
	holder.WorldPivot = CFrame.new()
	holder:ScaleTo(MapConfig.SCALE)
	for _, c in holder:GetChildren() do
		c.Parent = hole
	end
	holder:Destroy()
end

-- The Speed wheel has its own level (bought apart from the home): rebuild it at the home's WheelLevel
function Homes.rewheel(hole: Model, level: number)
	local old = hole:FindFirstChild("TrainingWheel")
	if old then
		old:Destroy()
	end
	level = math.clamp(level, 1, #HomeLook.WHEEL_LOOK)
	scaledBuild(hole, function()
		local index = hole:GetAttribute("HoleIndex") :: number
		HomeLook.buildWheel(Kit, MapConfig.unscaled, hole, MapConfig.unscaled.homeFrame(index), level)
	end)
end

-- Rebuild a home's level dressing, then its wheel at the wheel's own level
function Homes.relevel(hole: Model, level: number)
	scaledBuild(hole, function()
		HomeLook.applyLevel(Kit, MapConfig.unscaled, hole, level)
	end)
	Homes.rewheel(hole, (hole:GetAttribute("WheelLevel") :: number?) or 1)
end

local function refreshSign(hole: Model)
	local sign = hole:FindFirstChild("Sign") :: BasePart?
	if not sign then
		return
	end
	local owner = Players:GetPlayerByUserId(hole:GetAttribute("Owner") :: number)
	local level = hole:GetAttribute("Level") :: number
	if hole:GetAttribute("Locked") then
		local left = math.max(0, math.ceil((hole:GetAttribute("LockedUntil") :: number) - Workspace:GetServerTimeNow()))
		HomeLook.setSign(
			sign,
			if owner then owner.DisplayName else "EMPTY HOME",
			string.format("LOCKED %d:%02d", left // 60, left % 60),
			nil,
			0xFF4D5E
		)
	else
		local income = (hole:GetAttribute("Income") :: number?) or 0
		HomeLook.setSign(
			sign,
			if owner then owner.DisplayName else "EMPTY HOME",
			if owner then "Lv " .. level .. " · " .. GameConfig.money(income) .. "/s" else "Lv " .. level
		)
	end
end
Homes.refreshSign = refreshSign

-- Put a player on their home's matchbox bed, facing the room
function Homes.sendHome(player: Player)
	local hole = homeOf(player)
	local character = player.Character
	if not hole or not character then
		return
	end
	local spawnPad = hole:FindFirstChild("Spawn") :: BasePart?
	if spawnPad then
		character:PivotTo(spawnPad.CFrame * CFrame.new(0, spawnPad.Size.Y / 2 + 3.2, 0))
	end
end

local function claim(player: Player)
	if homeOf(player) then
		return
	end
	for _, index in Homes.CLAIM_ORDER do
		local hole = holes:FindFirstChild("Hole" .. index)
		if hole and hole:GetAttribute("Owner") == 0 then
			hole:SetAttribute("Owner", player.UserId)
			local spawnPad = hole:FindFirstChild("Spawn")
			if spawnPad and spawnPad:IsA("SpawnLocation") then
				player.RespawnLocation = spawnPad
			end
			refreshSign(hole :: Model)
			if player.Character then
				-- already spawned somewhere else (joined before the homes were ready)
				Homes.sendHome(player)
			end
			return
		end
	end
end

local function release(player: Player)
	local hole = homeOf(player)
	if hole then
		hole:SetAttribute("Owner", 0)
		hole:SetAttribute("Locked", false)
		hole:SetAttribute("LockReadyAt", nil)
		HomeLook.setLocked(hole, false)
		refreshSign(hole)
		-- someone who joined a full server gets the free home
		task.defer(function()
			for _, other in Players:GetPlayers() do
				if other ~= player then
					claim(other)
				end
			end
		end)
	end
end

-- The push-pin: the owner locks the door; while it's locked, anyone else who walks in is put back outside
local function lock(hole: Model, player: Player)
	if hole:GetAttribute("Locked") then
		return
	end
	local readyAt = (hole:GetAttribute("LockReadyAt") :: number?) or 0
	local wait = math.ceil(readyAt - Workspace:GetServerTimeNow())
	if wait > 0 then
		local remotes = ReplicatedStorage:FindFirstChild("BedroomRemotes")
		local notice = remotes and remotes:FindFirstChild("Notice") :: RemoteEvent?
		if notice then
			notice:FireClient(player, `The lock is resetting: lock again in {wait}s`, "warn")
		end
		return
	end
	hole:SetAttribute("LockedUntil", Workspace:GetServerTimeNow() + Homes.LOCK_TIME)
	HomeLook.setLocked(hole, true)
	task.spawn(function()
		while hole.Parent and hole:GetAttribute("Locked") do
			refreshSign(hole)
			if Workspace:GetServerTimeNow() >= (hole:GetAttribute("LockedUntil") :: number) then
				HomeLook.setLocked(hole, false)
				hole:SetAttribute("LockReadyAt", Workspace:GetServerTimeNow() + Homes.LOCK_COOLDOWN)
			end
			task.wait(0.5)
		end
		refreshSign(hole)
	end)
end

function Homes.start(bedroom: Model)
	holes = bedroom:WaitForChild("Holes") :: Folder
	Knock.sendHome = Homes.sendHome
	for _, hole in holes:GetChildren() do
		if not hole:IsA("Model") then
			continue
		end
		hole:SetAttribute("Owner", 0)
		hole:SetAttribute("Locked", false)
		if hole:GetAttribute("Level") ~= 1 or hole:GetAttribute("WheelLevel") ~= 1 then
			-- the map is saved with every theme on show; a server starts every home empty at Level 1 (Dylan: "why do
			-- the other plots have stuff but there isn't even players in it")
			hole:SetAttribute("Level", 1)
			hole:SetAttribute("WheelLevel", 1)
			Homes.relevel(hole, 1)
		end
		refreshSign(hole)
		hole:GetAttributeChangedSignal("Level"):Connect(function()
			local level = math.clamp(hole:GetAttribute("Level") :: number, 1, #MapConfig.HOLE_LEVELS)
			Homes.relevel(hole, level)
			refreshSign(hole)
		end)
		hole:GetAttributeChangedSignal("WheelLevel"):Connect(function()
			Homes.rewheel(hole, (hole:GetAttribute("WheelLevel") :: number?) or 1)
		end)
		local pin = hole:FindFirstChild("LockButton")
		local prompt = pin and pin:FindFirstChild("LockPrompt") :: ProximityPrompt?
		if prompt then
			prompt.Triggered:Connect(function(player)
				if hole:GetAttribute("Owner") == player.UserId then
					lock(hole, player)
				end
			end)
		end
	end

	Players.PlayerAdded:Connect(claim)
	for _, player in Players:GetPlayers() do
		claim(player)
	end
	Players.PlayerRemoving:Connect(release)

	-- Strangers in a locked home are put back outside it
	task.spawn(function()
		while holes.Parent do
			task.wait(0.25)
			for _, player in Players:GetPlayers() do
				local root = Knock.root(player)
				local index = root and MapConfig.homeAt(root.Position)
				local hole = index and holes:FindFirstChild("Hole" .. index)
				if root and hole and hole:GetAttribute("Locked") and hole:GetAttribute("Owner") ~= player.UserId then
					local outside = MapConfig.homeFrame(index) * CFrame.new(0, 4, -14);
					(player.Character :: Model):PivotTo(
						CFrame.lookAt(outside.Position, outside.Position + outside.LookVector)
					)
				end
			end
		end
	end)
end

return Homes
