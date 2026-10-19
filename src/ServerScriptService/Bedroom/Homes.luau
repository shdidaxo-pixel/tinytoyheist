--!strict
-- The 8 homes at runtime: each player who joins gets a free home (its Owner attribute), spawns on its matchbox bed and
-- sees their name float over it. The push-pin locks the door for a while (strangers who walk in are pushed back
-- out). Changing a home's Level attribute rebuilds its dressing and Speed wheel. In Studio, empty pens get a few
-- demo toys so the roaming can be seen.
-- The look of a home is built by ServerStorage.TinyToyHeistTools.Bedroom.Homes (the same code as the map builder).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MapConfig = require(Shared:WaitForChild("MapConfig")) :: any
local pieces = ServerStorage:WaitForChild("TinyToyHeistTools"):WaitForChild("Bedroom")
local Kit = require(pieces:WaitForChild("Kit")) :: any
local HomeLook = require(pieces:WaitForChild("Homes")) :: any
local Knock = require(script.Parent.Knock)

Kit.yieldEvery = 0 -- rebuilds at runtime are small; do them in one go

local Homes = {}
Homes.LOCK_TIME = 45
Homes.CLAIM_ORDER = { 4, 5, 3, 6, 2, 7, 1, 8 } -- the middle of the curve first
Homes.DEMO_TOYS = { 9, 3, 12, 5, 17, 10, 2, 14 } -- as in the concept render

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

-- Rebuild a home's level dressing and wheel. The look is built at the map's full size (like the map builder does)
-- and the new parts are then shrunk about the room's start by MapConfig.SCALE, so they land in the scaled world.
function Homes.relevel(hole: Model, level: number)
	local before = {}
	for _, c in hole:GetChildren() do
		before[c] = true
	end
	HomeLook.applyLevel(Kit, MapConfig.unscaled, hole, level)
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
			if owner then string.format("Lv %d · $%d/s", level, income) else "Lv " .. level
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
			-- your pen starts with only your own toys
			for _, toy in (hole:FindFirstChild("PenToys") :: Instance):GetChildren() do
				if toy:GetAttribute("Demo") then
					toy:Destroy()
				end
			end
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
		HomeLook.setLocked(hole, false)
		refreshSign(hole)
	end
end

-- The push-pin: the owner locks the door; while it's locked, anyone else who walks in is put back outside
local function lock(hole: Model)
	if hole:GetAttribute("Locked") then
		return
	end
	hole:SetAttribute("LockedUntil", Workspace:GetServerTimeNow() + Homes.LOCK_TIME)
	HomeLook.setLocked(hole, true)
	task.spawn(function()
		while hole.Parent and hole:GetAttribute("Locked") do
			refreshSign(hole)
			if Workspace:GetServerTimeNow() >= (hole:GetAttribute("LockedUntil") :: number) then
				HomeLook.setLocked(hole, false)
			end
			task.wait(0.5)
		end
		refreshSign(hole)
	end)
end

-- Demo toys for the pens (Studio only): real voxel toys (ServerStorage.TinyToyHeistAssets.Toys, or built from the
-- toy data) when the place has them, otherwise little placeholder figures.
local function demoToy(index: number, k: number, rng: Random): Model?
	local size = if k % 5 == 4 then "L" elseif k % 2 == 1 then "M" else "S"
	local ok, toy = pcall(function()
		local Toys = Shared:FindFirstChild("Toys")
		if not Toys then
			return nil
		end
		local ToyCatalog = require(Toys:FindFirstChild("ToyCatalog") :: ModuleScript) :: any
		local ToyBuilder = require(Toys:FindFirstChild("ToyBuilder") :: ModuleScript) :: any
		local choices = {}
		for _, data in ToyCatalog.inSet("Bedroom") do
			if data.Size == size then
				table.insert(choices, data)
			end
		end
		if #choices == 0 then
			choices = ToyCatalog.list()
		end
		local data = choices[rng:NextInteger(1, #choices)]
		-- the prebuilt model when the toy session has exported it, otherwise build it now
		local assets = ServerStorage:FindFirstChild("TinyToyHeistAssets")
		local prebuilt = assets and assets:FindFirstChild("Toys") and assets.Toys:FindFirstChild(data.Id)
		if prebuilt and prebuilt:IsA("Model") then
			return prebuilt:Clone()
		end
		return ToyBuilder.build(data)
	end)
	if ok and toy then
		toy:SetAttribute("Size", toy:GetAttribute("Size") or size)
		return toy
	end
	-- placeholder: a little block figure with two eyes
	local colors = { 0xFFD43B, 0xF45B5B, 0x3D7BFF, 0xFF7AC8, 0xF6E7CF, 0xD8FF7A, 0x9B7BFF, 0x3DDC97 }
	local model = Instance.new("Model")
	model.Name = "PlaceholderToy"
	local scale = ({ S = 1, M = 1.4, L = 2 } :: any)[size]
	local color = colors[(index * 3 + k) % #colors + 1]
	local root = Kit.part(model, "Root", Vector3.new(4, 4, 4) * scale, CFrame.new(0, 2 * scale, 0), color, {
		material = Enum.Material.SmoothPlastic,
	})
	Kit.part(model, "Head", Vector3.new(3, 3, 3) * scale, CFrame.new(0, 5.5 * scale, -0.3 * scale), color, {})
	for _, x in { -0.7, 0.7 } do
		Kit.part(
			model,
			"Eye",
			Vector3.new(0.5, 0.8, 0.3) * scale,
			CFrame.new(x * scale, 6 * scale, -1.85 * scale),
			0x1A1430,
			{
				collide = false,
			}
		)
	end
	model.PrimaryPart = root
	model.WorldPivot = CFrame.new()
	model:SetAttribute("Size", size)
	return model
end

local function fillDemoPen(hole: Model)
	local pen = hole:FindFirstChild("Pen") :: BasePart?
	local toys = hole:FindFirstChild("PenToys")
	if not pen or not toys or #toys:GetChildren() > 0 then
		return
	end
	local index = hole:GetAttribute("HoleIndex") :: number
	local level = hole:GetAttribute("Level") :: number
	local count = math.min(Homes.DEMO_TOYS[index] or 4, MapConfig.HOLE_LEVELS[level].slots)
	local rng = Random.new(index * 101)
	for k = 0, count - 1 do
		local toy = demoToy(index, k, rng)
		if toy then
			toy:SetAttribute("RoamSeed", index * 1000 + k * 37)
			toy:SetAttribute("Demo", true)
			local frame = MapConfig.homeFrame(index)
			local penMin = pen:GetAttribute("PenMin") :: Vector3
			local penMax = pen:GetAttribute("PenMax") :: Vector3
			local p = penMin:Lerp(penMax, rng:NextNumber())
			toy:PivotTo(frame * CFrame.new(p.X, pen:GetAttribute("PenTop") :: number, p.Z))
			for _, d in toy:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored = true
				end
			end
			if hole:GetAttribute("Owner") ~= 0 then
				-- someone moved in while the demo toys were being made
				toy:Destroy()
				break
			end
			toy.Parent = toys
		end
	end
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
		refreshSign(hole)
		hole:GetAttributeChangedSignal("Level"):Connect(function()
			local level = math.clamp(hole:GetAttribute("Level") :: number, 1, #MapConfig.HOLE_LEVELS)
			Homes.relevel(hole, level)
			refreshSign(hole)
		end)
		local pin = hole:FindFirstChild("LockButton")
		local prompt = pin and pin:FindFirstChild("LockPrompt") :: ProximityPrompt?
		if prompt then
			prompt.Triggered:Connect(function(player)
				if hole:GetAttribute("Owner") == player.UserId then
					lock(hole)
				end
			end)
		end
		if RunService:IsStudio() then
			task.spawn(fillDemoPen, hole)
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
