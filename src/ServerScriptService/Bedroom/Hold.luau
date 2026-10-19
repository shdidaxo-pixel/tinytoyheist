--!strict
-- Holding a toy to show it off (the hotbar, like Break and Steal an Egg's). Only toys waiting in your inventory can be
-- held: a pen toy has to be unequipped first (Dylan, 19 Oct: "you cant equip pen toys in ur hotbar, they stay in the
-- inventory"). Holding is just for show: an inventory toy earns nothing and can't be stolen, held or not.
--   The client fires GameRemotes.Hold(uid) to hold a toy, or Hold(nil) to put it away.
--   The held toy is a copy of the toy at hand size, welded in front of the chest ("HoldWeld"), with a tag over it:
--   name, $/s and rarity, so other players can admire it. Everyone sees it.
--   Player attributes: Holding = the toy's uid (nil when not holding), HoldHeight = its height in studs.
--   It goes away by itself when you start dragging a blanket or a stolen toy, train on the wheel, die, equip or sell
--   it, or leave.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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
Hold.AHEAD = 1.2 -- studs between the chest and the toy's back
Hold.CHEST = 0.1 -- the toy's middle, above the HumanoidRootPart's centre
Hold.COOLDOWN = 0.25 -- seconds between requests

type Held = { uid: string, model: Model }
local held: { [Player]: Held } = {}
local lastAsk: { [Player]: number } = {}

local folder = Workspace:FindFirstChild("HeldToys") or Instance.new("Folder")
folder.Name = "HeldToys"
folder.Parent = Workspace

local function hexColor(h: string?): Color3
	return if h then Color3.fromHex(h) else Color3.new(1, 1, 1)
end

-- The tag over a held toy: its name (with the size and look in front), $/s and rarity
local function tag(entry: PlayerData.Toy, root: BasePart, height: number)
	local data = ToyCatalog.get(entry.id)
	local rarity = data and data.Rarity or "Common"
	local mutation = entry.m and MutationData.List[entry.m]
	local name = (if ToySize.isBig(entry.z) then ToySize.name(entry.z) .. " " else "")
		.. (if mutation then mutation.Name .. " " else "")
		.. (if data then data.Name else "Toy")

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
	local function line(text: string, color: Color3, px: number, order: number)
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.new(1, 0, 0, px + 2)
		label.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)
		label.TextSize = px
		label.Text = text
		label.TextColor3 = color
		label.LayoutOrder = order
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Color = Color3.fromRGB(20, 16, 24)
		stroke.Parent = label
		label.Parent = gui
	end
	line(name, if mutation then hexColor(mutation.Color) else Color3.new(1, 1, 1), 17, 1)
	line(GameConfig.money(Pens.perSecond(entry)) .. "/s", Color3.fromHex("5BF25A"), 21, 2)
	line(rarity, hexColor(ToyRarities.Colors[rarity]), 16, 3)
	gui.Parent = root
end

local function putAway(player: Player)
	local h = held[player]
	held[player] = nil
	if h then
		h.model:Destroy()
	end
	if player.Parent then
		player:SetAttribute("Holding", nil)
		player:SetAttribute("HoldHeight", nil)
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

local function holdable(player: Player, uid: string): PlayerData.Toy?
	local entry = Pens.find(player, uid)
	if entry and not Pens.isEquipped(entry) then
		return entry
	end
	return nil
end

function Hold.hold(player: Player, uid: string): boolean
	local entry = holdable(player, uid)
	local root = Knock.root(player)
	if not entry or not root or blocked(player) then
		return false
	end
	if held[player] and held[player].uid == uid then
		return true
	end
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
	toy:SetAttribute("HeldBy", player.UserId)

	local main = toy.PrimaryPart :: BasePart
	toy:PivotTo(root.CFrame * CFrame.new(0, Hold.CHEST - height * 0.5, -(Hold.AHEAD + reach * k)))
	for _, d in toy:GetDescendants() do
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
	tag(entry, main, height)
	toy.Name = "Held_" .. player.UserId
	toy.Parent = folder
	pcall(function()
		main:SetNetworkOwner(player)
	end)
	held[player] = { uid = uid, model = toy }
	player:SetAttribute("HoldHeight", height)
	player:SetAttribute("Holding", uid)
	return true
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

	-- and when the toy is equipped into the pen, sold or gone, or the player died
	task.spawn(function()
		while true do
			task.wait(0.3)
			for player, h in held do
				if blocked(player) or not holdable(player, h.uid) or not h.model.Parent then
					putAway(player)
				end
			end
		end
	end)
end

return Hold
