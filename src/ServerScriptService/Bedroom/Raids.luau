--!strict
-- Raids: hold Steal (2 s) on a toy roaming someone else's pen and you drag it off. It's only yours once it crosses
-- your own door (Carry banks it); if you're knocked over it drops, and after 15 s alone it slides back home.
-- The anti-grief rules from the plan: players with fewer than 3 toys can't be raided; new players are shielded for
-- their first 10 minutes unless they own 5 toys; and you can't steal from the same player again for 90 s.
-- A locked home pushes strangers out (Homes), so the lock is the defence.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MapConfig = require(Shared:WaitForChild("MapConfig")) :: any
local GameConfig = require(Shared:WaitForChild("GameConfig")) :: any
local PenRoam = require(Shared:WaitForChild("PenRoam")) :: any
local PlayerData = require(script.Parent.PlayerData)
local Pens = require(script.Parent.Pens)
local Carry = require(script.Parent.Carry)
local Knock = require(script.Parent.Knock)

local Raids = {}

local lastSteal: { [Player]: { [number]: number } } = {} -- thief -> owner UserId -> os.clock()
local notice: RemoteEvent

-- Where a roaming toy is right now, in the world (the clients move it from the same seed and clock)
local function toyPosition(owner: Player, model: Model): Vector3?
	local s = Pens.state(owner)
	local pen = s and s.hole:FindFirstChild("Pen") :: BasePart?
	if not s or not pen then
		return nil
	end
	local seed = model:GetAttribute("RoamSeed") :: number?
	local size = model:GetAttribute("Size") :: string?
	if not seed then
		return model:GetPivot().Position
	end
	local p = PenRoam.pose(
		seed,
		Workspace:GetServerTimeNow(),
		pen:GetAttribute("PenMin") :: Vector3,
		pen:GetAttribute("PenMax") :: Vector3,
		size or "M"
	)
	local frame = MapConfig.homeFrame(s.hole:GetAttribute("HoleIndex") :: number)
	return (frame * CFrame.new(p.X, (pen:GetAttribute("PenTop") :: number?) or 0, p.Z)).Position
end

-- Why a steal isn't allowed, or nil if it is
function Raids.blocked(thief: Player, owner: Player): string?
	local mine = PlayerData.get(thief)
	local theirs = PlayerData.get(owner)
	if not mine or not theirs then
		return "Still loading..."
	end
	if Carry.isCarrying(thief) then
		return "You're already carrying a toy!"
	end
	if not Pens.hasRoom(thief) then
		return "Your inventory is full! Sell some toys first."
	end
	if #theirs.Toys < GameConfig.RAID.minToys then
		return `{owner.DisplayName}'s home is too small to raid`
	end
	local played = PlayerData.playSeconds(owner)
	local shield = GameConfig.RAID.shieldMinutes * 60
	if played < shield and #theirs.Toys < GameConfig.RAID.shieldToys then
		return `{owner.DisplayName} is new: their home is shielded for {math.ceil((shield - played) / 60)} min`
	end
	local last = lastSteal[thief] and lastSteal[thief][owner.UserId]
	if last and os.clock() - last < GameConfig.RAID.cooldown then
		local wait = math.ceil(GameConfig.RAID.cooldown - (os.clock() - last))
		return `Give {owner.DisplayName} a break: steal again in {wait}s`
	end
	return nil
end

function Raids.start(_bedroom: Model)
	notice = ReplicatedStorage:WaitForChild("BedroomRemotes"):WaitForChild("Notice") :: RemoteEvent
	-- the thief's client finished holding Steal on a toy (GameRemotes.Steal, uid)
	local stealRemote = PlayerData.remote("RemoteEvent", "Steal") :: RemoteEvent
	stealRemote.OnServerEvent:Connect(function(thief: Player, uid: any)
		if typeof(uid) ~= "string" then
			return
		end
		local owner, model = Pens.findToy(uid)
		if not owner or not model or owner == thief then
			return
		end
		local why = Raids.blocked(thief, owner)
		if why then
			notice:FireClient(thief, why, "warn")
			return
		end
		local root = Knock.root(thief)
		local at = toyPosition(owner, model)
		if not root or not at or (root.Position - at).Magnitude > 30 then
			return
		end
		if Carry.carryStolen(thief, owner, uid) then
			local id = model:GetAttribute("ToyName") or "toy"
			notice:FireClient(owner, `{thief.DisplayName} is stealing your {id}! Stop them!`, "warn")
			notice:FireClient(thief, "Got it! Drag it to your home!", "good")
		end
	end)
	Carry.onStealBanked = function(thief: Player, owner: Player)
		lastSteal[thief] = lastSteal[thief] or {}
		lastSteal[thief][owner.UserId] = os.clock()
	end
	PlayerData.onLeaving(function(player)
		lastSteal[player] = nil
	end)
end

return Raids
