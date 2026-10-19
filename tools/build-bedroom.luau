--!strict
-- Studio EDIT mode only. Rebuilds Workspace.Bedroom: the Kid's Bedroom, concept v6 (handoff.md section 6).
-- One long run: the 8 homes in a curved wall at the start (open fronts, open tops, the framing showing), the teal
-- safe ring in front of them, then carpet, wood and creaky bands down the room to the bed on the runner's right and
-- the open hallway door straight ahead. The block tower, the winding train, the cat, traps, loose boards, ducks,
-- bricks and the baby monitor zone. Every number comes from ReplicatedStorage.Shared.MapConfig; the pieces are built
-- by the modules in ServerStorage.TinyToyHeistTools.Bedroom (tools/bedroom/). Night lighting at the end.
-- Run it from the command bar:
--   local m = game.ServerStorage.TinyToyHeistTools.BuildBedroom:Clone(); print(require(m)); m:Destroy()
local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
assert(not game:GetService("RunService"):IsRunning(), "Build the bedroom in Edit mode")

-- A fresh copy of a module every run, so changes synced by Rojo are picked up without restarting Studio
local function fresh(module: Instance): any
	local copy = module:Clone()
	return (require :: any)(copy)
end

local Shared = ReplicatedStorage:WaitForChild("Shared")
local pieces = ServerStorage:WaitForChild("TinyToyHeistTools"):WaitForChild("Bedroom")
local MapConfig = fresh(Shared:WaitForChild("MapConfig"))
local BedroomLighting = fresh(Shared:WaitForChild("BedroomLighting"))
local Kit = fresh(pieces:WaitForChild("Kit"))
local started = os.clock()

local old = Workspace:FindFirstChild("Bedroom")
if old then
	old:Destroy()
end
local bedroom = Instance.new("Model")
bedroom.Name = "Bedroom"
bedroom.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- one room you can see end to end
bedroom.Parent = Workspace

local room = fresh(pieces:WaitForChild("Room"))(Kit, MapConfig, bedroom)

local Homes = fresh(pieces:WaitForChild("Homes"))
local holes = Kit.folder(bedroom, "Holes")
for i = 1, MapConfig.HOLE_COUNT do
	Homes.build(Kit, MapConfig, holes, i, MapConfig.SHOWCASE_LEVELS[i])
end

fresh(pieces:WaitForChild("Furniture"))(Kit, MapConfig, bedroom)
local landmarks = fresh(pieces:WaitForChild("Landmarks"))(Kit, MapConfig, bedroom)
fresh(pieces:WaitForChild("Hazards"))(Kit, MapConfig, bedroom)

-- Sleeping-toy spawn points (invisible). Game code puts a blanket toy of the right size on each.
local spawns = Kit.folder(bedroom, "ToySpawns")
local counts = { S = 0, M = 0, L = 0 }
for _, point in MapConfig.toySpawns() do
	counts[point.size] += 1
	Kit.part(
		spawns,
		string.format("%s%02d", point.size, counts[point.size]),
		Vector3.new(4, 1, 4),
		CFrame.new(point.position + Vector3.new(0, 0.5, 0)),
		0xFFC93C,
		{ collide = false, transparency = 1, attributes = { Size = point.size } }
	)
end

BedroomLighting.apply(BedroomLighting.Night, 0)

local parts, lights = 0, 0
for _, d in bedroom:GetDescendants() do
	if d:IsA("BasePart") then
		parts += 1
	elseif d:IsA("Light") then
		lights += 1
	end
end
return {
	parts = parts,
	lights = lights,
	homes = #holes:GetChildren(),
	toySpawns = string.format("%d S, %d M, %d L", counts.S, counts.M, counts.L),
	floorTiles = room.floorTiles,
	trackPieces = landmarks.trackPieces,
	seconds = math.floor((os.clock() - started) * 10) / 10,
}
