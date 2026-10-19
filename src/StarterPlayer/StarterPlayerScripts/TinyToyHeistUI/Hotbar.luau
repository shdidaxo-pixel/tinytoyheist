--!strict
-- The hotbar, copied from Break and Steal an Egg's: a row of small dark slots at the bottom of the screen, each with
-- its key number, the toy's picture and name. Only toys waiting in your inventory are on it (a pen toy has to be
-- unequipped first; Dylan, 19 Oct). Press 1-9 or tap a slot to hold that toy in front of you, so everyone can see
-- it with its name, $/s and rarity; press or tap it again to put it away. Holding is just for show (Hold.luau on the
-- server). A toy that lands on the bar pops in as a big card that drops into its slot. The bar hides while you drag
-- a blanket or a stolen toy (the Drop Toy button takes its place), and Roblox's own backpack bar stays off.
-- GameUI.start calls Hotbar.start(ctx) and Hotbar.update(profile) with every profile from the server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local UIKit = require(script.Parent:WaitForChild("UIKit"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Toys = Shared:WaitForChild("Toys")
local ToyCatalog = require(Toys:WaitForChild("ToyCatalog")) :: any
local MutationData = require(Toys:WaitForChild("MutationData")) :: any
local ToySize = require(Toys:WaitForChild("ToySize")) :: any
local VFX = require(Shared:WaitForChild("VFX")) :: any
local Moments = require(Shared:WaitForChild("VFX"):WaitForChild("Moments")) :: any

local me = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local hex = UIKit.hex

local Hotbar = {}
Hotbar.SLOT = 64 -- px at the 1280 x 720 reference
Hotbar.GAP = 6
Hotbar.MAX = 9 -- slots with a key (1-9); more toys show as a "+N" slot that opens Your Toys
Hotbar.MAX_TOUCH = 6 -- fewer on phones, so the bar stays between the thumbstick and the jump button

local KEYS = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
	[Enum.KeyCode.Six] = 6,
	[Enum.KeyCode.Seven] = 7,
	[Enum.KeyCode.Eight] = 8,
	[Enum.KeyCode.Nine] = 9,
	[Enum.KeyCode.KeypadOne] = 1,
	[Enum.KeyCode.KeypadTwo] = 2,
	[Enum.KeyCode.KeypadThree] = 3,
	[Enum.KeyCode.KeypadFour] = 4,
	[Enum.KeyCode.KeypadFive] = 5,
	[Enum.KeyCode.KeypadSix] = 6,
	[Enum.KeyCode.KeypadSeven] = 7,
	[Enum.KeyCode.KeypadEight] = 8,
	[Enum.KeyCode.KeypadNine] = 9,
}
local SLOT_FACE = hex("2A3A2C") -- Steal an Egg's dark green-grey, a little see-through
local SLOT_PICKED = hex("3E5A40")

type Ctx = { gui: ScreenGui, open: (string) -> (), hud: { [string]: any } }

local ctx: Ctx
local bar: Frame
local row: Frame
local entries: { [string]: any } = {} -- inventory toys by uid
local order: { string } = {} -- slot order: the toys already on the bar keep their place, new ones go on the end
local loaded = false
local slots: { [string]: Frame } = {}
local lastDrawn = ""

local function rarityOf(entry: any): string
	local data = ToyCatalog.get(entry.id)
	return data and data.Rarity or "Common"
end
local function perSecond(entry: any): number
	local data = ToyCatalog.get(entry.id)
	local m = entry.m and MutationData.List[entry.m]
	return (if data then data.Money else 0) * (if m then m.Multiplier else 1) * ToySize.money(entry.z)
end
local function maxSlots(): number
	return if UIKit.isTouch() then Hotbar.MAX_TOUCH else Hotbar.MAX
end

local holdRemote: RemoteEvent? = nil
local function ask(uid: string?)
	holdRemote = holdRemote or remotes:FindFirstChild("Hold") :: RemoteEvent?
	if holdRemote then
		holdRemote:FireServer(uid)
	end
end

-- Hold the toy in slot i, or put it away if it's the one in your hands
local function press(i: number)
	local uid = order[i]
	if not uid or not bar.Visible then
		return
	end
	if me:GetAttribute("Holding") == uid then
		ask(nil)
	else
		ask(uid)
	end
end

local function chip(parent: Instance, text: string, color: Color3, y: number)
	local c = UIKit.new("Frame", {
		Name = "Chip",
		BackgroundColor3 = color,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 13),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 3, 0, y),
		ZIndex = 8,
	}, parent)
	UIKit.corner(c, 4)
	UIKit.stroke(c, UIKit.Ink, 1.5, true)
	UIKit.new("UIPadding", { PaddingLeft = UDim.new(0, 3), PaddingRight = UDim.new(0, 3) }, c)
	UIKit.text(c, text, 9, {
		font = UIKit.Fonts.label,
		stroke = 1,
		size = UDim2.fromScale(0, 1),
		z = 9,
	}).AutomaticSize =
		Enum.AutomaticSize.X
end

-- One slot: key number, picture, name, a rarity outline, chips for the look mutation and a big size
local function slot(i: number, entry: any): Frame
	local S = Hotbar.SLOT
	local holder = UIKit.new("Frame", {
		Name = "Slot" .. i,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(S, S),
		LayoutOrder = i,
	}, row)
	local face = UIKit.new("Frame", {
		Name = "Face",
		BackgroundColor3 = SLOT_FACE,
		BackgroundTransparency = 0.18,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
	}, holder)
	UIKit.corner(face, 6)
	local rarity = UIKit.Rarity[rarityOf(entry)] or UIKit.White
	UIKit.new("UIStroke", {
		Name = "Edge",
		Color = rarity,
		Thickness = 2.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, face)
	UIKit.icon(face, UIKit.toy(entry.id), S - 10, UDim2.new(0.5, 0, 0.5, -4), Vector2.new(0.5, 0.5), 4)
	UIKit.text(face, tostring(i), 15, { position = UDim2.fromOffset(5, 2), stroke = 2, z = 7 })
	local data = ToyCatalog.get(entry.id)
	local name = UIKit.text(face, data and data.Name or "Toy", 10, {
		font = UIKit.Fonts.label,
		stroke = 1.5,
		size = UDim2.new(1, -4, 0, 12),
		position = UDim2.new(0.5, 0, 1, -2),
		anchor = Vector2.new(0.5, 1),
		z = 7,
	})
	name.TextTruncate = Enum.TextTruncate.AtEnd
	local y = -3
	local m = entry.m and MutationData.List[entry.m]
	if m then
		chip(face, string.upper(m.Name), Color3.fromHex(m.Color), y)
		y += 15
	end
	if ToySize.isBig(entry.z) then
		chip(face, string.upper(ToySize.name(entry.z)), ToySize.color(entry.z), y)
	end
	UIKit.clickable(holder, function()
		press(i)
	end)
	return holder
end

-- The "+N" slot when there are more inventory toys than slots: opens Your Toys
local function more(n: number)
	local S = Hotbar.SLOT
	local holder = UIKit.new("Frame", {
		Name = "More",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(S * 0.7, S),
		LayoutOrder = 100,
	}, row)
	local face = UIKit.new("Frame", {
		Name = "Face",
		BackgroundColor3 = SLOT_FACE,
		BackgroundTransparency = 0.18,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
	}, holder)
	UIKit.corner(face, 6)
	UIKit.stroke(face, UIKit.Ink, 2, true)
	UIKit.text(face, "+" .. n, 18, {
		font = UIKit.Fonts.number,
		position = UDim2.new(0.5, 0, 0.5, -7),
		anchor = Vector2.new(0.5, 0.5),
		z = 7,
	})
	UIKit.text(face, "Toys", 10, {
		position = UDim2.new(0.5, 0, 1, -3),
		anchor = Vector2.new(0.5, 1),
		stroke = 1.5,
		z = 7,
	})
	UIKit.clickable(holder, function()
		ctx.open("Toys")
	end)
end

-- Show which slot is in your hands: a white outline, lifted a little
local function showPicked()
	local holding = me:GetAttribute("Holding")
	for uid, holder in slots do
		local face = holder:FindFirstChild("Face") :: Frame?
		if not face then
			continue
		end
		local picked = uid == holding
		local edge = face:FindFirstChild("Edge") :: UIStroke?
		local entry = entries[uid]
		if edge and entry then
			edge.Color = if picked then UIKit.White else (UIKit.Rarity[rarityOf(entry)] or UIKit.White)
			edge.Thickness = if picked then 3.5 else 2.5
		end
		face.BackgroundColor3 = if picked then SLOT_PICKED else SLOT_FACE
		UIKit.tween(face, 0.12, { Position = UDim2.fromOffset(0, if picked then -8 else 0) })
	end
end

-- A toy that just landed on the bar: a big card over its slot that drops in and shrinks into it
local function arrive(uid: string)
	local holder = slots[uid]
	local entry = entries[uid]
	if not holder or not entry then
		return
	end
	local data = ToyCatalog.get(entry.id)
	local cardHolder, card = UIKit.block(holder, {
		name = "Arrive",
		size = UDim2.fromOffset(92, 92),
		position = UDim2.new(0.5, 0, 0, -16),
		anchor = Vector2.new(0.5, 1),
		palette = UIKit.Palettes.cyan,
		radius = 6,
	})
	cardHolder.ZIndex = 30
	UIKit.icon(card, UIKit.toy(entry.id), 72, UDim2.new(0.5, 0, 0.5, -8), Vector2.new(0.5, 0.5), 32)
	UIKit.text(card, data and data.Name or "Toy", 14, {
		position = UDim2.new(0.5, 0, 1, -4),
		anchor = Vector2.new(0.5, 1),
		size = UDim2.new(1, -6, 0, 16),
		z = 33,
	}).TextTruncate =
		Enum.TextTruncate.AtEnd
	local s = UIKit.animScale(cardHolder)
	s.Scale = 0.2
	UIKit.tween(s, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(1.1, function()
		if not cardHolder.Parent then
			return
		end
		UIKit.tween(
			cardHolder,
			0.22,
			{ Position = UDim2.fromScale(0.5, 1) },
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.In
		)
		UIKit.tween(s, 0.22, { Scale = 0.6 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.wait(0.22)
		cardHolder:Destroy()
		local face = holder:FindFirstChild("Face") :: GuiObject?
		if face then
			VFX.uiPop(face, 0.2)
		end
	end)
end

local function draw()
	local n = maxSlots()
	local sig = table.concat(order, ",", 1, math.min(#order, n)) .. "|" .. #order .. "|" .. n
	if sig == lastDrawn then
		showPicked()
		return
	end
	lastDrawn = sig
	for _, c in row:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	slots = {}
	for i = 1, math.min(#order, n) do
		slots[order[i]] = slot(i, entries[order[i]])
	end
	if #order > n then
		more(#order - n)
	end
	showPicked()
end

local function refreshVisible()
	bar.Visible = #order > 0 and me:GetAttribute("Carrying") == nil
end

-- A new profile from the server: the toys in your inventory (not in the pen) are the bar
function Hotbar.update(profile: any)
	if not profile or not bar then
		return
	end
	local now: { [string]: any } = {}
	local fresh: { any } = {}
	for _, t in profile.Toys do
		if t.e == false then
			now[t.u] = t
			if not entries[t.u] then
				table.insert(fresh, t)
			end
		end
	end
	-- keep the order; the first time, best earners first
	local kept = {}
	for _, uid in order do
		if now[uid] then
			table.insert(kept, uid)
		end
	end
	table.sort(fresh, function(a, b)
		local pa, pb = perSecond(a), perSecond(b)
		if pa ~= pb then
			return pa > pb
		end
		return a.u < b.u
	end)
	for _, t in fresh do
		table.insert(kept, t.u)
	end
	order = kept
	entries = now
	draw()
	refreshVisible()
	if loaded then
		for _, t in fresh do
			arrive(t.u)
		end
	end
	loaded = true
end

-- Everyone's held toy pops into their hands with a sparkle in its rarity colour (and a moment for the sounds)
local function watchHolder(player: Player)
	player:GetAttributeChangedSignal("Holding"):Connect(function()
		if player == me then
			showPicked()
		end
		if player:GetAttribute("Holding") == nil then
			return
		end
		local folder = Workspace:WaitForChild("HeldToys", 5)
		local model = folder and folder:WaitForChild("Held_" .. player.UserId, 3)
		if model and model:IsA("Model") then
			local rarity = model:GetAttribute("Rarity")
			local color = if typeof(rarity) == "string" then UIKit.Rarity[rarity] else nil
			pcall(VFX.burst, "Sparkle", model, { color = color or UIKit.White, scale = 0.6 })
			pcall(Moments.fire, "HoldToy", { toy = model, mine = player == me })
		end
	end)
end

function Hotbar.start(c: Ctx)
	ctx = c
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)
	local width = Hotbar.MAX * (Hotbar.SLOT + Hotbar.GAP) + Hotbar.SLOT
	bar = UIKit.new("Frame", {
		Name = "Hotbar",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.fromOffset(width, Hotbar.SLOT),
		Visible = false,
	}, c.gui)
	UIKit.fit(bar)
	row = UIKit.new("Frame", {
		Name = "Row",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, bar)
	UIKit.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, Hotbar.GAP),
	}, row)
	UIKit.onLayout(function()
		bar.Position = UDim2.new(0.5, 0, 1, if UIKit.isTouch() then -10 else -12)
		if loaded then
			draw()
		end
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		local i = KEYS[input.KeyCode]
		if i then
			press(i)
		end
	end)
	me:GetAttributeChangedSignal("Carrying"):Connect(refreshVisible)
	Players.PlayerAdded:Connect(watchHolder)
	for _, p in Players:GetPlayers() do
		watchHolder(p)
	end
end

return Hotbar
