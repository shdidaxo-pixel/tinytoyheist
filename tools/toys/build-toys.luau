--!strict
-- Studio tool: builds every toy into ServerStorage.TinyToyHeistAssets.Toys (one Model per toy, named by its Id,
-- with its rarity effects baked in). Run in Edit mode from the command bar or the Studio MCP:
--
--   require(game.ServerStorage.TinyToyHeistTools.BuildToys).run()
--   require(game.ServerStorage.TinyToyHeistTools.BuildToys).run({ only = { "RubberDuck", "BathShark" } })
--   require(game.ServerStorage.TinyToyHeistTools.BuildToys).showcase()   -- line them up in Workspace.ToyShowcase
--   require(game.ServerStorage.TinyToyHeistTools.BuildToys).clearShowcase()
--
-- It loads fresh copies of the toy modules each run, so edits Rojo just synced are picked up without restarting.
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local BuildToys = {}

local function freshModules()
	local src = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Toys")
	local old = ServerStorage:FindFirstChild("_ToyBuildModules")
	if old then
		old:Destroy()
	end
	local copy = src:Clone()
	copy.Name = "_ToyBuildModules"
	copy.Parent = ServerStorage
	return copy,
		{
			ToyCatalog = (require :: any)(copy:WaitForChild("ToyCatalog")),
			ToyBuilder = (require :: any)(copy:WaitForChild("ToyBuilder")),
			ToyVFX = (require :: any)(copy:WaitForChild("ToyVFX")),
			Mutations = (require :: any)(copy:WaitForChild("Mutations")),
		}
end

local function folderIn(parent: Instance, name: string): Folder
	local f = parent:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
	end
	return f :: Folder
end

function BuildToys.toysFolder(): Folder
	return folderIn(folderIn(ServerStorage, "TinyToyHeistAssets"), "Toys")
end

function BuildToys.run(options: { only: { string }? }?): string
	local copy, M = freshModules()
	local only: { [string]: boolean }? = nil
	if options and options.only then
		local set: { [string]: boolean } = {}
		for _, id in options.only do
			set[id] = true
		end
		only = set
	end
	local folder = BuildToys.toysFolder()
	local built, parts = 0, 0
	local known: { [string]: boolean } = {}
	for i, toy in M.ToyCatalog.list() do
		known[toy.Id] = true
		if not only or only[toy.Id] then
			local old = folder:FindFirstChild(toy.Id)
			if old then
				old:Destroy()
			end
			local model = M.ToyBuilder.build(toy)
			M.ToyVFX.applyRarity(model)
			model.Parent = folder
			built += 1
			parts += #(model:FindFirstChild("Blocks") :: Folder):GetChildren()
			if i % 4 == 0 then
				task.wait()
			end
		end
	end
	-- toys that were removed from the data
	local removed = 0
	if not only then
		for _, m in folder:GetChildren() do
			if not known[m.Name] then
				m:Destroy()
				removed += 1
			end
		end
	end
	copy:Destroy()
	return `built {built} toys ({parts} blocks, {built > 0 and math.round(parts / built) or 0} each), removed {removed}; {#folder:GetChildren()} in {folder:GetFullName()}`
end

-- Line every built toy up in Workspace.ToyShowcase (far from the map) for screenshots: one row per set, plus a
-- row of one toy in every mutation. Not part of the game; clearShowcase() removes it.
BuildToys.SHOWCASE_ORIGIN = Vector3.new(0, 0, -3000)

function BuildToys.showcase(mutationToy: string?): string
	local copy, M = freshModules()
	BuildToys.clearShowcase()
	local show = Instance.new("Model")
	show.Name = "ToyShowcase"
	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Anchored = true
	floor.Size = Vector3.new(700, 2, 420)
	floor.Color = Color3.fromHex("#3F4785")
	floor.Material = Enum.Material.SmoothPlastic
	floor.CFrame = CFrame.new(BuildToys.SHOWCASE_ORIGIN + Vector3.new(300, -1, 160))
	floor.Parent = show
	local folder = BuildToys.toysFolder()
	local z = 0
	for _, setId in M.ToyCatalog.SET_ORDER do
		local x = 0
		local tallest = 0
		for _, toy in M.ToyCatalog.inSet(setId) do
			local src = folder:FindFirstChild(toy.Id)
			if src then
				local m = src:Clone()
				local root = (m :: Model).PrimaryPart :: BasePart
				local w = math.max(root.Size.X, root.Size.Z)
				m:PivotTo(
					CFrame.new(BuildToys.SHOWCASE_ORIGIN + Vector3.new(x + w / 2, 0, z))
						* CFrame.Angles(0, math.rad(200), 0)
				)
				m.Parent = show
				x += w + 4
				tallest = math.max(tallest, root.Size.Z, root.Size.X)
			end
		end
		if x > 0 then
			z += tallest + 14
		end
	end
	local id = mutationToy or "TeddyKnight"
	local src = folder:FindFirstChild(id)
	if src then
		local x = 0
		for _, mut in { "None", table.unpack(M.Mutations.Data.Order) } do
			local m = src:Clone() :: Model
			if mut ~= "None" then
				M.Mutations.apply(m, mut)
			end
			local root = m.PrimaryPart :: BasePart
			local w = math.max(root.Size.X, root.Size.Z) * 1.4
			m:PivotTo(
				CFrame.new(BuildToys.SHOWCASE_ORIGIN + Vector3.new(x + w / 2, 0, z + 6))
					* CFrame.Angles(0, math.rad(200), 0)
			)
			m.Parent = show
			x += w + 4
		end
	end
	show.Parent = Workspace
	copy:Destroy()
	return `showcase: {#show:GetChildren() - 1} toys at {BuildToys.SHOWCASE_ORIGIN}`
end

function BuildToys.clearShowcase()
	local old = Workspace:FindFirstChild("ToyShowcase")
	if old then
		old:Destroy()
	end
end

return BuildToys
