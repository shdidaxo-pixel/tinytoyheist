--!strict
-- The hotbar, copied from Break and Steal an Egg's: a row of small dark slots at the bottom of the screen, each with
-- its key number, the toy's picture and name. On it: toys waiting in your inventory (a pen toy has to be unequipped
-- first; Dylan, 19 Oct) and blankets waiting at home to be hatched ("blankets that arent being opened should be in the
-- hotbar"), shown as a little 3D copy with its wake-up timer, never the toy inside. Press 1-9 or tap a slot to hold
-- it in front of you, so everyone can see it (a toy with its name, $/s and rarity; a blanket with its timer); press
-- or tap it again to put it away. Holding is just for show (Hold.luau on the server). Something that lands on the bar
-- pops in as a big card that drops into its slot. The bar hides while you drag
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
local BLANKET_COLOUR = { S = hex("4DA8FF"), M = hex("9B7BFF"), L = hex("FF8A3D") } :: { [string]: Color3 } -- as the HUD list
local SIZE_NAME = { S = "Small", M = "Medium", L = "Large" } :: { [string]: string }

type Ctx = { gui: ScreenGui, open: (string) -> (), hud: { [string]: any } }

local ctx: Ctx
local bar: Frame
local row: Frame
local entries: { [string]: any } = {} -- inventory toys by uid
local order: { string } = {} -- slot order: the toys already on the bar keep their place, new ones go on the end
local loaded = false
local slots: { [string]: Frame } = {}
local lastDrawn = ""
local missingPicture = false -- a blanket slot is showing its size chip until the blanket streams in

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

-- Blankets waiting at home are on the bar too (a saved blanket has a wake-up time `w`; a toy doesn't)
local function isBlanket(entry: any): boolean
	return entry.w ~= nil
end
local function edgeColor(entry: any): Color3
	if isBlanket(entry) then
		return BLANKET_COLOUR[entry.s] or UIKit.White
	end
	return UIKit.Rarity[rarityOf(entry)] or UIKit.White
end
local function title(entry: any): string
	if isBlanket(entry) then
		return SIZE_NAME[entry.s] or "Blanket"
	end
	local data = ToyCatalog.get(entry.id)
	return data and data.Name or "Toy"
end
local function wakeText(entry: any): (string, Color3)
	local left = math.ceil(entry.w - Workspace:GetServerTimeNow())
	if left <= 0 then
		return "READY", UIKit.Yellow
	end
	return string.format("%d:%02d", left // 60, left % 60), UIKit.White
end

-- A blanket's picture is a little 3D copy of the real one in your home (so it has the same colour and pattern),
-- kept once seen so it still shows while that one is in your hands.
local blanketCopies: { [string]: Model } = {}
local function homeBlanket(uid: string): Model?
	if blanketCopies[uid] then
		return blanketCopies[uid]
	end
	local bedroom = Workspace:FindFirstChild("Bedroom")
	local holes = bedroom and bedroom:FindFirstChild("Holes")
	for _, h in if holes then holes:GetChildren() else {} do
		local waking = h:GetAttribute("Owner") == me.UserId and h:FindFirstChild("Waking")
		for _, m in if waking then waking:GetChildren() else {} do
			if m:IsA("Model") and m:GetAttribute("Uid") == uid and m.PrimaryPart then
				local copy = m:Clone()
				for _, d in copy:GetDescendants() do
					if d:IsA("ProximityPrompt") or d:IsA("BillboardGui") or d:IsA("Script") then
						d:Destroy()
					end
				end
				copy:PivotTo(CFrame.new())
				blanketCopies[uid] = copy
				return copy
			end
		end
	end
	return nil
end

-- The picture in a slot or card: the toy's icon, or the blanket in a ViewportFrame (a size chip until it streams in)
local function picture(parent: Instance, entry: any, px: number, position: UDim2, z: number): boolean
	if not isBlanket(entry) then
		UIKit.icon(parent, UIKit.toy(entry.id), px, position, Vector2.new(0.5, 0.5), z)
		return true
	end
	local source = homeBlanket(entry.u)
	if not source then
		local c = UIKit.new("Frame", {
			Name = "Icon",
			BackgroundColor3 = BLANKET_COLOUR[entry.s] or UIKit.White,
			Size = UDim2.fromOffset(px * 0.6, px * 0.6),
			Position = position,
			AnchorPoint = Vector2.new(0.5, 0.5),
			ZIndex = z,
		}, parent)
		UIKit.corner(c, 6)
		UIKit.stroke(c, UIKit.Ink, 2, true)
		UIKit.text(
			c,
			entry.s,
			px * 0.3,
			{ position = UDim2.fromScale(0.5, 0.5), anchor = Vector2.new(0.5, 0.5), z = z + 1 }
		)
		return false
	end
	local view = UIKit.new("ViewportFrame", {
		Name = "Icon",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(px, px),
		Position = position,
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = z,
		Ambient = Color3.fromRGB(190, 185, 200),
		LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(-0.5, -1, -0.6),
	}, parent)
	local copy = source:Clone()
	copy.Parent = view
	local ext = copy:GetExtentsSize()
	local r = math.max(ext.X, ext.Z, ext.Y)
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	cam.CFrame = CFrame.lookAt(Vector3.new(0, ext.Y * 0.5 + r * 0.9, r * 1.75), Vector3.new(0, ext.Y * 0.35, 0))
	cam.Parent = view
	view.CurrentCamera = cam
	return true
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
	UIKit.new("UIStroke", {
		Name = "Edge",
		Color = edgeColor(entry),
		Thickness = 2.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, face)
	if not picture(face, entry, S - 10, UDim2.new(0.5, 0, 0.5, -4), 4) then
		missingPicture = true
	end
	UIKit.text(face, tostring(i), 15, { position = UDim2.fromOffset(5, 2), stroke = 2, z = 7 })
	if isBlanket(entry) then
		-- its wake-up timer, top right (ticks once a second)
		local text, color = wakeText(entry)
		UIKit.text(face, text, 11, {
			name = "Timer",
			font = UIKit.Fonts.number,
			color = color,
			stroke = 1.5,
			position = UDim2.new(1, -4, 0, 3),
			anchor = Vector2.new(1, 0),
			z = 8,
		})
	end
	local name = UIKit.text(face, title(entry), 10, {
		font = UIKit.Fonts.label,
		stroke = 1.5,
		size = UDim2.new(1, -4, 0, 12),
		position = UDim2.new(0.5, 0, 1, -2),
		anchor = Vector2.new(0.5, 1),
		z = 7,
	})
	name.TextTruncate = Enum.TextTruncate.AtEnd
	local y = -3
	-- (a blanket keeps its toy, and the look rolled for it, a secret)
	local m = not isBlanket(entry) and entry.m and MutationData.List[entry.m]
	if m then
		chip(face, string.upper(m.Name), Color3.fromHex(m.Color), y)
		y += 15
	end
	if not isBlanket(entry) and ToySize.isBig(entry.z) then
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
			edge.Color = if picked then UIKit.White else edgeColor(entry)
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
	local cardHolder, card = UIKit.block(holder, {
		name = "Arrive",
		size = UDim2.fromOffset(92, 92),
		position = UDim2.new(0.5, 0, 0, -16),
		anchor = Vector2.new(0.5, 1),
		palette = UIKit.Palettes.cyan,
		radius = 6,
	})
	cardHolder.ZIndex = 30
	picture(card, entry, 72, UDim2.new(0.5, 0, 0.5, -8), 32)
	UIKit.text(card, title(entry), 14, {
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
	missingPicture = false
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

-- A new profile from the server: the toys in your inventory (not in the pen) and the blankets waiting at home are
-- the bar
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
	for _, b in profile.Blankets or {} do
		now[b.u] = b
		if not entries[b.u] then
			table.insert(fresh, b)
		end
	end
	-- keep the order; the first time, best earners first, then the blankets that wake first
	local kept = {}
	for _, uid in order do
		if now[uid] then
			table.insert(kept, uid)
		end
	end
	table.sort(fresh, function(a, b)
		if isBlanket(a) ~= isBlanket(b) then
			return isBlanket(b)
		elseif isBlanket(a) then
			return a.w < b.w
		end
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
	-- blanket timers tick, and a blanket that has just streamed in gets its picture
	task.spawn(function()
		while bar.Parent do
			task.wait(1)
			for uid, holder in slots do
				local entry = entries[uid]
				local timer = entry and isBlanket(entry) and holder:FindFirstChild("Timer", true) :: TextLabel?
				if timer then
					timer.Text, timer.TextColor3 = wakeText(entry)
				end
				if missingPicture and entry and isBlanket(entry) and not blanketCopies[uid] and homeBlanket(uid) then
					lastDrawn = ""
				end
			end
			if lastDrawn == "" and loaded then
				draw()
			end
		end
	end)
	Players.PlayerAdded:Connect(watchHolder)
	for _, p in Players:GetPlayers() do
		watchHolder(p)
	end
end

return Hotbar
