--!strict
-- Big moments for the players' screens (VFX and SFX play on them): Moments.fire(player | "all", kind, data).
-- Arrives on the client as ReplicatedStorage.Shared.VFX.Moments.on(kind, fn). Kinds: design/notes/vfx.md.
local Players = game:GetService("Players")
local PlayerData = require(script.Parent.PlayerData)

local Moments = {}

local remote = PlayerData.remote("RemoteEvent", "Moment") :: RemoteEvent

function Moments.fire(to: Player | string, kind: string, data: { [string]: any }?)
	if to == "all" then
		remote:FireAllClients(kind, data or {})
	elseif typeof(to) == "Instance" and to:IsA("Player") and to.Parent == Players then
		remote:FireClient(to, kind, data or {})
	end
end

return Moments
