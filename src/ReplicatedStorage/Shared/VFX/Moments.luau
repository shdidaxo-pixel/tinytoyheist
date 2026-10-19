--!strict
-- The game's big moments on each player's screen, as one event bus that VFX and SFX both listen to.
--   Moments.on(kind, fn(data)) -> connection     Moments.fire(kind, data)   (client)
-- Server code sends a moment with ServerScriptService.Bedroom.Moments (GameRemotes.Moment); the client side picks
-- it up here. Kinds and their data are listed in design/notes/vfx.md.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Moments = {}

type Listener = (data: any) -> ()
local listeners: { [string]: { Listener } } = {}

function Moments.on(kind: string, fn: Listener): { Disconnect: () -> () }
	local list = listeners[kind] or {}
	listeners[kind] = list
	table.insert(list, fn)
	return {
		Disconnect = function()
			local i = table.find(list, fn)
			if i then
				table.remove(list, i)
			end
		end,
	}
end

function Moments.fire(kind: string, data: any?)
	for _, fn in table.clone(listeners[kind] or {}) do
		task.spawn(function()
			local ok, err = pcall(fn, data or {})
			if not ok then
				warn(`Moments: {kind} listener failed: {err}`)
			end
		end)
	end
end

-- moments from the server
if RunService:IsClient() then
	task.spawn(function()
		local remotes = ReplicatedStorage:WaitForChild("GameRemotes")
		local remote = remotes:WaitForChild("Moment", 60) :: RemoteEvent?
		if remote then
			remote.OnClientEvent:Connect(function(kind: string, data: any)
				if typeof(kind) == "string" then
					Moments.fire(kind, data)
				end
			end)
		end
	end)
end

return Moments
