--!strict
-- Each player's saved game: cash, toys, home level, stats, the Index, rebirths and rewards. The profile table is the
-- truth; the world (pens, levels, walk speed) is rebuilt from it.
--   Saved in the DataStore "TinyToyHeist_v1" (key "p_<UserId>") on join, every minute and on leave, with a session
--   lock so the same player in two servers can't duplicate toys. In an unpublished place (or with Studio API access
--   off) it can't reach DataStores: the profile then lives only for the session (Player attribute DataOffline).
--   Numbers are mirrored to Player attributes for the HUD; the owner's client gets the full profile through the
--   GameRemotes.Data remote whenever it changes.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig")) :: any

local PlayerData = {}
PlayerData.STORE = "TinyToyHeist_v1"
PlayerData.AUTOSAVE = 60
PlayerData.LOCK_STALE = 150 -- a lock older than this (seconds) belongs to a server that died

export type Toy = { u: string, id: string, m: string?, s: string? } -- s: the blanket size it woke up at
export type Profile = {
	Version: number,
	Cash: number,
	Earned: number,
	HomeLevel: number,
	Stats: { [string]: number },
	SpeedPoints: number,
	SpeedProgress: number,
	Toys: { Toy },
	Index: { [string]: { [string]: boolean } },
	Sets: { [string]: boolean }, -- room sets completed (reward paid)
	Rebirths: number,
	Banked: number, -- toys ever banked
	Stolen: number,
	PlaySeconds: number, -- total time played
	Daily: { Streak: number, Day: number }, -- Day = the UTC day number of the last claim
	BoostUntil: number, -- os.time() when x2 money runs out
	Tutorial: number,
}

local function defaults(): Profile
	return {
		Version = 1,
		Cash = GameConfig.START_CASH,
		Earned = 0,
		HomeLevel = 1,
		Stats = { Strength = 0, Sneak = 0, Grip = 0 },
		SpeedPoints = 0,
		SpeedProgress = 0,
		Toys = {},
		Index = {},
		Sets = {},
		Rebirths = 0,
		Banked = 0,
		Stolen = 0,
		PlaySeconds = 0,
		Daily = { Streak = 0, Day = 0 },
		BoostUntil = 0,
		Tutorial = 0,
	}
end
PlayerData.defaults = defaults

-- fill in any field a profile saved by an older version is missing
local function reconcile(data: any): Profile
	local base = defaults() :: any
	for k, v in base do
		if data[k] == nil then
			data[k] = v
		elseif type(v) == "table" and type(data[k]) == "table" and #v == 0 then
			for k2, v2 in v do
				if data[k][k2] == nil then
					data[k][k2] = v2
				end
			end
		end
	end
	return data
end

local store: DataStore? = nil
if game.PlaceId ~= 0 then
	pcall(function()
		store = DataStoreService:GetDataStore(PlayerData.STORE)
	end)
end

type Session = {
	profile: Profile,
	offline: boolean,
	joinedAt: number, -- os.clock() when this session started
	countedAt: number, -- os.clock() up to which PlaySeconds has been counted
	playtimeClaimed: { [number]: boolean },
	dirty: boolean,
}
local sessions: { [Player]: Session } = {}
local loadedCallbacks: { (Player, Profile) -> () } = {}
local leavingCallbacks: { (Player, Profile) -> () } = {}

local remotes = ReplicatedStorage:FindFirstChild("GameRemotes") or Instance.new("Folder")
remotes.Name = "GameRemotes"
remotes.Parent = ReplicatedStorage
local function remote(className: string, name: string): any
	local r = remotes:FindFirstChild(name)
	if not r then
		r = Instance.new(className)
		r.Name = name
		r.Parent = remotes
	end
	return r
end
PlayerData.remote = remote
local dataRemote = remote("RemoteEvent", "Data") :: RemoteEvent

function PlayerData.get(player: Player): Profile?
	local s = sessions[player]
	return s and s.profile
end

function PlayerData.session(player: Player): Session?
	return sessions[player]
end

-- Yields until the player's profile is loaded (nil if they left first)
function PlayerData.wait(player: Player): Profile?
	while player.Parent and not sessions[player] do
		task.wait(0.1)
	end
	return PlayerData.get(player)
end

function PlayerData.onLoaded(fn: (Player, Profile) -> ())
	table.insert(loadedCallbacks, fn)
	for player, s in sessions do
		task.spawn(fn, player, s.profile)
	end
end

function PlayerData.onLeaving(fn: (Player, Profile) -> ())
	table.insert(leavingCallbacks, fn)
end

function PlayerData.newUid(): string
	return string.sub(string.gsub(HttpService:GenerateGUID(false), "-", ""), 1, 12)
end

function PlayerData.playSeconds(player: Player): number
	local s = sessions[player]
	if not s then
		return 0
	end
	return s.profile.PlaySeconds + (os.clock() - s.countedAt)
end

-- The numbers the HUD shows, as Player attributes
local function mirror(player: Player, p: Profile)
	player:SetAttribute("Cash", p.Cash)
	player:SetAttribute("HomeLevel", p.HomeLevel)
	player:SetAttribute("SpeedPoints", p.SpeedPoints)
	player:SetAttribute("Rebirths", p.Rebirths)
	player:SetAttribute("ToyCount", #p.Toys)
	for stat, level in p.Stats do
		player:SetAttribute(stat, level)
	end
	player:SetAttribute("BoostUntil", p.BoostUntil)
end

-- Something in the profile changed: refresh the attributes now and send the owner a copy soon
function PlayerData.changed(player: Player)
	local s = sessions[player]
	if not s then
		return
	end
	mirror(player, s.profile)
	if s.dirty then
		return
	end
	s.dirty = true
	task.delay(0.2, function()
		local now = sessions[player]
		if now then
			now.dirty = false
			local claimed = {}
			for k in now.playtimeClaimed do
				table.insert(claimed, k)
			end
			dataRemote:FireClient(player, now.profile, {
				offline = now.offline,
				sessionStart = os.time() - (os.clock() - now.joinedAt),
				playtimeClaimed = claimed,
			})
		end
	end)
end

function PlayerData.addCash(player: Player, amount: number)
	local p = PlayerData.get(player)
	if not p then
		return
	end
	p.Cash += amount
	if amount > 0 then
		p.Earned += amount
	end
	player:SetAttribute("Cash", p.Cash) -- every second for income: skip the full sync
end

-- Spend cash if they have it
function PlayerData.spend(player: Player, amount: number): boolean
	local p = PlayerData.get(player)
	if not p or p.Cash < amount then
		return false
	end
	p.Cash -= amount
	PlayerData.changed(player)
	return true
end

---------------------------------------------------------------------------------------------------------------------
-- Loading and saving

local function key(player: Player): string
	return "p_" .. player.UserId
end

-- Load with the session lock. Returns the profile and whether it came from the store.
local function load(player: Player): (Profile?, boolean)
	if not store then
		return defaults(), false
	end
	local ds = store :: DataStore
	for attempt = 1, 6 do
		local blocked = false
		local ok, result = pcall(function()
			return ds:UpdateAsync(key(player), function(old: any)
				if
					type(old) == "table"
					and type(old.Lock) == "table"
					and old.Lock.Job ~= game.JobId
					and os.time() - (old.Lock.Time or 0) < PlayerData.LOCK_STALE
					and attempt < 6 -- the last try takes the lock anyway
				then
					blocked = true
					return nil
				end
				local data = if type(old) == "table" then old else defaults()
				data.Lock = { Job = game.JobId, Time = os.time() }
				return data
			end)
		end)
		if ok and not blocked and type(result) == "table" then
			return reconcile(result), true
		elseif not ok then
			warn(`PlayerData: couldn't load {player.Name} (try {attempt}): {result}`)
		end
		if not player.Parent then
			return nil, false
		end
		task.wait(if blocked then 6 else 3)
	end
	return nil, false
end

local function save(player: Player, release: boolean)
	local s = sessions[player]
	if not s or s.offline or not store then
		return
	end
	local ds = store :: DataStore
	s.profile.PlaySeconds = PlayerData.playSeconds(player)
	s.countedAt = os.clock()
	local copy = table.clone(s.profile) :: any
	local ok, err = pcall(function()
		ds:UpdateAsync(key(player), function(old: any)
			if type(old) == "table" and type(old.Lock) == "table" and old.Lock.Job ~= game.JobId then
				return nil -- another server has taken over this player: don't overwrite its data
			end
			copy.Lock = if release then nil else { Job = game.JobId, Time = os.time() }
			return copy
		end)
	end)
	if not ok then
		warn(`PlayerData: couldn't save {player.Name}: {err}`)
	end
end
PlayerData.save = save

local function join(player: Player)
	local profile, fromStore = load(player)
	if not player.Parent then
		if profile and fromStore then
			-- they left while it loaded: hand the lock straight back
			sessions[player] = {
				profile = profile,
				offline = false,
				joinedAt = os.clock(),
				countedAt = os.clock(),
				playtimeClaimed = {},
				dirty = false,
			}
			save(player, true)
			sessions[player] = nil
		end
		return
	end
	local offline = not fromStore
	if not profile then
		-- the store is there but failing: play on a fresh profile and never save it over the real one
		profile = defaults()
		offline = true
	end
	sessions[player] = {
		profile = profile :: Profile,
		offline = offline,
		joinedAt = os.clock(),
		countedAt = os.clock(),
		playtimeClaimed = {},
		dirty = false,
	}
	player:SetAttribute("DataOffline", offline)
	mirror(player, profile :: Profile)
	player:SetAttribute("DataReady", true)
	if offline and not RunService:IsStudio() then
		warn(`PlayerData: {player.Name} is playing without saving`)
	end
	for _, fn in loadedCallbacks do
		task.spawn(fn, player, profile :: Profile)
	end
	PlayerData.changed(player)
end

local function leave(player: Player)
	local s = sessions[player]
	if not s then
		return
	end
	for _, fn in leavingCallbacks do
		pcall(fn, player, s.profile)
	end
	save(player, true)
	sessions[player] = nil
end

function PlayerData.start()
	Players.PlayerAdded:Connect(join)
	for _, player in Players:GetPlayers() do
		task.spawn(join, player)
	end
	Players.PlayerRemoving:Connect(leave)
	game:BindToClose(function()
		local waiting = 0
		for player in sessions do
			waiting += 1
			task.spawn(function()
				leave(player)
				waiting -= 1
			end)
		end
		local deadline = os.clock() + 25
		while waiting > 0 and os.clock() < deadline do
			task.wait(0.2)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(PlayerData.AUTOSAVE)
			for player in sessions do
				task.spawn(save, player, false)
			end
		end
	end)
end

return PlayerData
