--!strict
-- Studio EDIT mode only. A model showcase far from the bedroom (Workspace.Showcase, around x = 4000), so Dylan can
-- look over every model in one place: all 7 Speed wheel levels, every blanket (3 sizes x 10 colours), all 105 toys
-- plain (a row per set) and the 10 mutations on the 14 Bedroom toys. Plain baseplate, labelled rows, game sizes.
-- In Play mode the toys animate on their own (ToyAnimator) and the showcase teleport button (Studio, or the place's
-- owner) takes you there and back and spins the wheels (StarterPlayerScripts.Bedroom.ShowcaseTeleport).
-- Command bar:
--   require(game.ServerStorage.TinyToyHeistTools.Bedroom.Showcase:Clone()).build()
--   require(game.ServerStorage.TinyToyHeistTools.Bedroom.Showcase:Clone()).clear()
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Showcase = {}

Showcase.ORIGIN = Vector3.new(4000, 0, 0) -- the middle of the front edge; rows run back along +z
Showcase.ARRIVE = CFrame.lookAt(Vector3.new(4000, 4, -30), Vector3.new(4000, 4, 40)) -- where the teleport lands you

local WIDTH, DEPTH = 420, 1000
local INK = 0x1A1430

-- A fresh copy of a module every run, so changes synced by Rojo are picked up without restarting Studio
local function fresh(module: Instance): any
	return (require :: any)(module:Clone())
end

function Showcase.clear()
	local old = Workspace:FindFirstChild("Showcase")
	if old then
		old:Destroy()
	end
end

function Showcase.build(): { [string]: any }
	assert(not game:GetService("RunService"):IsRunning(), "Build the showcase in Edit mode")
	local started = os.clock()
	local pieces = ServerStorage:WaitForChild("TinyToyHeistTools"):WaitForChild("Bedroom")
	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local Toys = Shared:WaitForChild("Toys")
	local Kit = fresh(pieces:WaitForChild("Kit"))
	local Homes = fresh(pieces:WaitForChild("Homes"))
	local Blanket = fresh(pieces:WaitForChild("Blanket"))
	local MapConfig = fresh(Shared:WaitForChild("MapConfig"))
	local ToyCatalog = require(Toys:WaitForChild("ToyCatalog")) :: any
	local Mutations = require(Toys:WaitForChild("Mutations")) :: any
	local MutationData = require(Toys:WaitForChild("MutationData")) :: any
	local models = ServerStorage:WaitForChild("TinyToyHeistAssets"):WaitForChild("Toys")

	Showcase.clear()
	local root = Instance.new("Model")
	root.Name = "Showcase"
	root.Parent = Workspace
	local O = Showcase.ORIGIN
	-- x runs left to right for someone standing at the front looking down the rows (+z)
	local function at(x: number, z: number): CFrame
		return CFrame.new(O + Vector3.new(-x, 0, z))
	end

	-- the baseplate, with a grid so distances read
	local floor = Kit.block(root, "Baseplate", WIDTH, 2, DEPTH, at(0, DEPTH / 2 - 40), 0, -2, 0, 0xE9E4F2, {
		material = Enum.Material.SmoothPlastic,
	})
	floor.TopSurface = Enum.SurfaceType.Studs
	for x = -WIDTH / 2 + 20, WIDTH / 2 - 20, 40 do
		Kit.block(root, "Grid", 0.3, 0.05, DEPTH, at(x, DEPTH / 2 - 40), 0, 0, 0, 0xD6CFE6, { collide = false })
	end

	-- Flat labels on the floor (they never hide a model): a big dark banner for a section, a white tag for a model
	local function label(parent: Instance, text: string, x: number, z: number, width: number?, big: boolean?)
		local plate = Kit.part(
			parent,
			if big then "Sign" else "Label",
			Vector3.new(if big then 8 else 3.2, 0.2, width or 16),
			at(x, z) * CFrame.new(0, 0.1, 0) * CFrame.Angles(0, math.pi / 2, 0), -- a Top-face SurfaceGui runs along z
			if big then INK else 0xFFFFFF,
			{ collide = false }
		)
		Kit.text(plate, text, {
			face = Enum.NormalId.Top,
			color = if big then Color3.fromRGB(255, 228, 120) else Color3.fromRGB(26, 20, 48),
			pixelsPerStud = if big then 12 else 24,
			glow = big,
		})
	end
	local function sign(text: string, x: number, z: number, width: number?)
		label(root, text, x, z, width or 70, true)
	end

	-- 1. Speed wheels, Lv 1 to 7, side on, at game size
	local z = 0
	sign("SPEED WHEELS", 0, z - 12)
	local wheels = Kit.folder(root, "Wheels")
	local p = MapConfig.unscaled.BURROW_LAYOUT.TrainingWheel.position
	for level = 1, 7 do
		local x = (level - 4) * 26
		local holder = Kit.model(wheels, "Wheel" .. level, { Level = level })
		holder.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- streams in whole, so it spins as one
		local target = at(x, z + 10) * CFrame.Angles(0, math.pi / 2, 0)
		Homes.buildWheel(Kit, MapConfig.unscaled, holder, target * CFrame.new(-p.X, 0, -p.Z), level)
		holder.WorldPivot = target
		holder:ScaleTo(MapConfig.SCALE)
		label(root, "Lv " .. level, x, z - 2, 12)
	end

	-- 2. Blankets: a row per size, a column per colour
	z = 60
	sign("BLANKETS", 0, z - 14)
	local blankets = Kit.folder(root, "Blankets")
	for row, size in { "S", "M", "L" } do
		local rz = z + (row - 1) * 24
		label(root, size, -112, rz, 8)
		for colour = 1, #Blanket.COLOURS do
			local x = -90 + (colour - 1) * 20
			Blanket.build(Kit, blankets, size, at(x, rz) * CFrame.Angles(0, math.pi, 0), colour)
			if row == 1 then
				label(root, colour .. " · " .. Blanket.PATTERNS[(colour - 1) % #Blanket.PATTERNS + 1], x, z - 8, 16)
			end
		end
	end

	-- 3. Every toy, plain, a row per set
	z = 170
	sign("ALL 105 TOYS", 0, z - 16)
	local toyFolder = Kit.folder(root, "Toys")
	local count = 0
	for _, setId in ToyCatalog.SET_ORDER do
		local list = ToyCatalog.inSet(setId)
		if #list > 0 then
			local tall = 0
			for _, toy in list do
				tall = math.max(tall, if toy.Size == "G" then 25 elseif toy.Size == "L" then 17 else 12)
			end
			label(root, ToyCatalog.setName(setId) .. " (" .. #list .. ")", -190, z, 30)
			for k, toy in list do
				local model = models:FindFirstChild(toy.Id)
				local x = -160 + (k - 1) * 22
				if model then
					local copy = model:Clone()
					copy:PivotTo(at(x, z + 6))
					copy.Parent = toyFolder
					count += 1
				end
				label(root, toy.Name, x, z - 6, 20)
			end
			z += math.max(34, tall + 20)
			task.wait()
		end
	end

	-- 4. The 10 mutations on the 14 Bedroom toys: a row per mutation
	z += 30
	sign("MUTATIONS (BEDROOM SET)", 0, z - 16, 100)
	local mutFolder = Kit.folder(root, "Mutations")
	local bedroom = ToyCatalog.inSet("Bedroom")
	for k, toy in bedroom do
		label(root, toy.Name, -160 + (k - 1) * 22, z - 6, 20)
	end
	for _, id in MutationData.Order do
		label(root, id, -190, z + 6, 30)
		for k, toy in bedroom do
			local model = models:FindFirstChild(toy.Id)
			if model then
				local copy = model:Clone()
				Mutations.apply(copy, id)
				copy:PivotTo(at(-160 + (k - 1) * 22, z + 6))
				copy.Parent = mutFolder
				count += 1
			end
		end
		z += 34
		task.wait()
	end

	local parts = 0
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
		end
	end
	return {
		toys = count,
		parts = parts,
		depth = z,
		seconds = math.floor((os.clock() - started) * 10) / 10,
	}
end

return Showcase
