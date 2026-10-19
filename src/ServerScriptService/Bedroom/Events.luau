--!strict
-- The bedroom's hooks for other game code, and its remotes.
--   ServerStorage.BedroomEvents.DropCarried  (BindableEvent) fired with (player, reason) when a hazard makes a player
--                                            drop what they carry: the carry system listens and drops the toy.
--   ServerStorage.BedroomEvents.MakeNoise    (BindableEvent) fire with (position, points, kind) to make noise: kind
--                                            "Drag" or "Step" counts the floor under it (MapConfig.noiseAt); any other
--                                            kind ("Spike", "Board", "Duck", ...) only the baby monitor's zone.
--   ReplicatedStorage.BedroomRemotes.Knocked     server -> client: (push: Vector3, stun: number, message: string)
--   ReplicatedStorage.BedroomRemotes.NoiseRipple server -> clients: (position: Vector3, points: number)
-- Whether a player is carrying is read from the Player attribute "Carrying" (truthy = carrying).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local function child(parent: Instance, className: string, name: string): Instance
	local found = parent:FindFirstChild(name)
	if found and found.ClassName == className then
		return found
	end
	local made = Instance.new(className :: any)
	made.Name = name
	made.Parent = parent
	return made
end

local bindables = child(ServerStorage, "Folder", "BedroomEvents")
local remotes = child(ReplicatedStorage, "Folder", "BedroomRemotes")

return {
	DropCarried = child(bindables, "BindableEvent", "DropCarried") :: BindableEvent,
	MakeNoise = child(bindables, "BindableEvent", "MakeNoise") :: BindableEvent,
	Knocked = child(remotes, "RemoteEvent", "Knocked") :: RemoteEvent,
	NoiseRipple = child(remotes, "RemoteEvent", "NoiseRipple") :: RemoteEvent,
}
