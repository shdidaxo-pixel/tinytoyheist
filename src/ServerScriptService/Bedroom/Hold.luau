--!strict
-- Holding a toy or a blanket to show it off (the hotbar, like Break and Steal an Egg's). What can be held:
--   toys waiting in your inventory: a pen toy has to be unequipped first (Dylan, 19 Oct: "you cant equip pen toys in
--   ur hotbar, they stay in the inventory"). An inventory toy earns nothing and can't be stolen, held or not.
--   blankets waiting in your home to be hatched (Dylan, 19 Oct: "blankets that arent being opened should be in the
--   hotbar"). While you hold one, the one in your home is put away (so it never shows twice and can't be hatched
--   mid-hold); it comes back when you put it down. Its timer keeps counting (it's saved as a time).
-- Holding is just for show.
--   The client fires GameRemotes.Hold(uid) to hold something, or Hold(nil) to put it away.
--   The held thing is a copy at hand size, welded in front of the chest ("HoldWeld"), with a tag over it so other
--   players can admire it: a toy's name, $/s and rarity; a blanket's size and its wake-up timer (never the toy).
--   Player attributes: Holding = the uid (nil when not holding), HoldHeight = its height in studs,
--   HoldKind = "Toy" or "Blanket".
--   It goes away by itself when you start dragging a blanket or a stolen toy, train on the wheel, die, equip, sell or
--   hatch it, or leave.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig")) :: any
local Toys = Shared:WaitForChild("Toys")
local ToyCatalog = require(Toys:WaitForChild("ToyCatalog")) :: any
local ToyRarities = require(Toys:WaitForChild("ToyRarities")) :: any
local MutationData = require(Toys:WaitForChild("MutationData")) :: any
local ToySize = require(Toys:WaitForChild("ToySize")) :: any
local PlayerData = require(script.Parent.PlayerData)
local Pens = require(script.Parent.Pens)
local Knock = require(script.Parent.Knock)

local Hold = {}
Hold.HEIGHT = 3 -- a held toy is about this tall (a player is 5), whatever its real size
Hold.WIDTH = 3.4 -- and no wider than this
Hold.BLANKET_WIDTH = 3.6 -- a held blanket is about this wide
Hold.AHEAD = 1.2 -- studs between the chest and the toy's back
Hold.CHEST = 0.1 -- the toy's middle, above the HumanoidRootPart's centre
Hold.COOLDOWN = 0.25 -- seconds between requests

local BLANKET_NAME = { S = "Small Blanket", M = "Medium Blanket", L = "Large Blanket" } :: { [string]: string }

type Held = {
	uid: string,
	model: Model,
	home: Model?, -- a held blanket: the real one from the home, put away until you put this down
	timer: TextLabel?, -- a held blanket: its wake-up line
	wakeAt: number?, -- os.time()
}
local held: { [Player]: Held } = {}
local lastAsk: { [Player]: number } = {}

local folder = Workspace:FindFirstChild("HeldToys") or Instance.new("Folder")
folder.Name = "HeldToys"
folder.Parent = Workspace
-- home blankets wait here while their owner holds them
local parked = ServerStorage:FindFirstChild("HeldBlankets") or Instance.new("Folder")
parked.Name = "HeldBlankets"
parked.Parent = ServerStorage

local function hexColor(h: string?): Color3
	return if h then Color3.fromHex(h) else Color3.new(1, 1, 1)
end

-- A floating tag over the held thing, a few lines of outlined text; returns the labels
local function tag(
	root: BasePart,
	height: number,
	lines: { { text: string, color: Color3, px: number } }
): { TextLabel }
	local gui = Instance.new("BillboardGui")
	gui.Name = "HoldTag"
	gui.Size = UDim2.fromOffset(220, 66)
	gui.StudsOffsetWorldSpace = Vector3.new(0, height * 0.5 + 1.9, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 90
	gui.Adornee = root
	local list = Instance.new("UIListLayout")
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Bottom
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = gui
	local labels = {}
	for i, l in lines do
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.new(1, 0, 0, l.px + 2)
		label.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)
		label.TextSize = l.px
		label.Text = l.text
		label.TextColor3 = l.color
		label.LayoutOrder = i
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Color = Color3.fromRGB(20, 16, 24)
		stroke.Parent = label
		label.Parent = gui
		table.insert(labels, label)
	end
	gui.Parent = root
	return labels
end

-- A toy's tag: its name (with the size and look in front), $/s and rarity
local function toyTag(entry: PlayerData.Toy, root: BasePart, height: number)
	local data = ToyCatalog.get(entry.id)
	local rarity = data and data.Rarity or "Common"
	local mutation = entry.m and MutationData.List[entry.m]
	local name = (if ToySize.isBig(entry.z) then ToySize.name(entry.z) .. " " else "")
		.. (if mutation then mutation.Name .. " " else "")
		.. (if data then data.Name else "Toy")
	tag(root, height, {
		{ text = name, color = if mutation then hexColor(mutation.Color) else Color3.new(1, 1, 1), px = 17 },
		{ text = GameConfig.money(Pens.perSecond(entry)) .. "/s", color = Color3.fromHex("5BF25A"), px = 21 },
		{ text = rarity, color = hexColor(ToyRarities.Colors[rarity]), px = 16 },
	})
end

local function wakeText(wakeAt: number): (string, Color3)
	local left = wakeAt - os.time()
	if left <= 0 then
		return "Ready to hatch!", Color3.fromHex("FFD43B")
	end
	return string.format("wakes in %d:%02d", left // 60, left % 60), Color3.new(1, 1, 1)
end

local function putAway(player: Player)
	local h = held[player]
	held[player] = nil
	if h then
		h.model:Destroy()
		-- the real blanket goes back in the home, unless the home was rebuilt meanwhile
		local home = h.home
		local s = Pens.state(player)
		if home and s and s.blankets[h.uid] == home and home.Parent == parked then
			local waking = s.hole:FindFirstChild("Waking")
			pcall(function()
				home.Parent = waking or s.hole
			end)
		end
	end
	if player.Parent then
		player:SetAttribute("Holding", nil)
		player:SetAttribute("HoldHeight", nil)
		player:SetAttribute("HoldKind", nil)
	end
end
Hold.putAway = putAway

-- Why this player can't hold anything right now, or nil
local function blocked(player: Player): string?
	if player:GetAttribute("Carrying") ~= nil then
		return "carrying"
	elseif player:GetAttribute("Training") then
		return "training"
	elseif not Knock.root(player) then
		return "no character"
	end
	return nil
end

-- What this uid is, if it can be held: an inventory toy or a blanket waiting at home
local function holdable(player: Player, uid: string): (PlayerData.Toy?, PlayerData.Blanket?)
	local entry = Pens.find(player, uid)
	if entry then
		return if Pens.isEquipped(entry) then nil else entry, nil
	end
	local p = PlayerData.get(player)
	if p then
		for _, b in p.Blankets do
			if b.u == uid then
				return nil, b
			end
		end
	end
	return nil, nil
end

-- Weld a copy in front of the chest; everything about it is for looking at only
local function attach(player: Player, model: Model, root: BasePart, height: number, depth: number)
	local main = model.PrimaryPart :: BasePart
	model:PivotTo(root.CFrame * CFrame.new(0, Hold.CHEST - height * 0.5, -(Hold.AHEAD + depth * 0.5)))
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.Massless = true
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
		elseif d:IsA("ProximityPrompt") then
			d:Destroy()
		end
	end
	local weld = Instance.new("WeldConstraint")
	weld.Name = "HoldWeld"
	weld.Part0, weld.Part1 = root, main
	weld.Parent = main
	model:SetAttribute("HeldBy", player.UserId)
	model.Name = "Held_" .. player.UserId
	model.Parent = folder
	pcall(function()
		main:SetNetworkOwner(player)
	end)
end

local function holdToy(player: Player, entry: PlayerData.Toy, root: BasePart): boolean
	local toy = Pens.buildToy(entry)
	if not toy or not toy.PrimaryPart then
		if toy then
			toy:Destroy()
		end
		return false
	end
	putAway(player)
	-- hand size: about Hold.HEIGHT tall, never wider than Hold.WIDTH
	local height = (toy:GetAttribute("Height") :: number?) or toy:GetExtentsSize().Y
	local reach = ToySize.reach(toy)
	local k = math.min(Hold.HEIGHT / math.max(height, 0.1), Hold.WIDTH * 0.5 / math.max(reach, 0.1))
	toy:ScaleTo(toy:GetScale() * k)
	height *= k
	toy:SetAttribute("Height", height)
	attach(player, toy, root, height, reach * k * 2)
	toyTag(entry, toy.PrimaryPart :: BasePart, height)
	held[player] = { uid = entry.u, model = toy }
	player:SetAttribute("HoldKind", "Toy")
	player:SetAttribute("HoldHeight", height)
	player:SetAttribute("Holding", entry.u)
	return true
end

local function holdBlanket(player: Player, b: PlayerData.Blanket, root: BasePart): boolean
	local s = Pens.state(player)
	local home = s and s.blankets[b.u]
	-- a copy of the very blanket in your home (same colour and pattern), or a new one if it isn't built
	local blanket: Model? = nil
	if home then
		blanket = home:Clone()
	elseif Pens.makeBlanket then
		blanket = (Pens.makeBlanket :: any)(parked, b.s, CFrame.new())
	end
	if not blanket or not blanket.PrimaryPart then
		if blanket then
			blanket:Destroy()
		end
		return false
	end
	local model = blanket :: Model
	putAway(player)
	for _, key in { "Uid", "Owner", "Ready" } do
		model:SetAttribute(key, nil)
	end
	-- hand size: about Hold.BLANKET_WIDTH across (the model pivots at its bottom centre)
	local ext = model:GetExtentsSize()
	local k = math.min(Hold.BLANKET_WIDTH / math.max(ext.X, ext.Z, 0.1), Hold.HEIGHT / math.max(ext.Y, 0.1))
	model:ScaleTo(model:GetScale() * k)
	local height = ext.Y * k
	local main = model.PrimaryPart :: BasePart
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= main then
			local w = Instance.new("WeldConstraint")
			w.Part0, w.Part1 = main, d
			w.Parent = d
		end
	end
	attach(player, model, root, height, math.max(ext.X, ext.Z) * k)
	local text, color = wakeText(b.w)
	local labels = tag(main, height, {
		{ text = BLANKET_NAME[b.s] or "Blanket", color = Color3.new(1, 1, 1), px = 17 },
		{ text = text, color = color, px = 19 },
	})
	-- the real one waits in ServerStorage until this one is put down
	if home then
		home.Parent = parked
	end
	held[player] = { uid = b.u, model = model, home = home, timer = labels[2], wakeAt = b.w }
	player:SetAttribute("HoldKind", "Blanket")
	player:SetAttribute("HoldHeight", height)
	player:SetAttribute("Holding", b.u)
	return true
end

function Hold.hold(player: Player, uid: string): boolean
	local entry, blanket = holdable(player, uid)
	local root = Knock.root(player)
	if not (entry or blanket) or not root or blocked(player) then
		return false
	end
	if held[player] and held[player].uid == uid then
		return true
	end
	if entry then
		return holdToy(player, entry, root)
	end
	return holdBlanket(player, blanket :: PlayerData.Blanket, root)
end

function Hold.start(_bedroom: Model)
	local remote = PlayerData.remote("RemoteEvent", "Hold") :: RemoteEvent
	remote.OnServerEvent:Connect(function(player: Player, uid: any)
		local now = os.clock()
		if now - (lastAsk[player] or -math.huge) < Hold.COOLDOWN then
			return
		end
		lastAsk[player] = now
		if typeof(uid) == "string" and #uid < 64 then
			Hold.hold(player, uid)
		else
			putAway(player)
		end
	end)

	local function watch(player: Player)
		-- start dragging something: the held toy goes away at once (Carry sets Carrying)
		player:GetAttributeChangedSignal("Carrying"):Connect(function()
			if player:GetAttribute("Carrying") ~= nil then
				putAway(player)
			end
		end)
		player:GetAttributeChangedSignal("Training"):Connect(function()
			if player:GetAttribute("Training") then
				putAway(player)
			end
		end)
		player.CharacterRemoving:Connect(function()
			putAway(player)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, p in Players:GetPlayers() do
		watch(p)
	end
	Players.PlayerRemoving:Connect(function(player)
		putAway(player)
		lastAsk[player] = nil
	end)

	-- and when the toy is equipped into the pen, sold or gone, the blanket hatched or its home rebuilt, or the player
	-- died; a held blanket's timer ticks here too
	task.spawn(function()
		while true do
			task.wait(0.3)
			for player, h in held do
				local entry, blanket = holdable(player, h.uid)
				local s = Pens.state(player)
				local homeGone = h.home ~= nil and (not s or s.blankets[h.uid] ~= h.home)
				if blocked(player) or not (entry or blanket) or not h.model.Parent or homeGone then
					putAway(player)
				elseif h.timer and h.wakeAt then
					h.timer.Text, h.timer.TextColor3 = wakeText(h.wakeAt)
				end
			end
		end
	end)
end

return Hold
