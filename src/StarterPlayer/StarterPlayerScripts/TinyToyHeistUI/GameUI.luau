--!strict
-- The game's panels and HUD numbers, from the real game state: your cash and $/s, the quest banner, the reveal card
-- when a toy wakes up, and the Upgrades, Your Toys, Index, Daily Rewards and Playtime Rewards panels.
-- The server sends your profile through GameRemotes.Data whenever it changes (PlayerData.luau); cash, income and
-- stats also arrive as Player attributes. Hud.client.luau builds the HUD and calls GameUI.start with it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local UIKit = require(script.Parent:WaitForChild("UIKit"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig")) :: any
local MapConfig = require(Shared:WaitForChild("MapConfig")) :: any
local Toys = Shared:WaitForChild("Toys")
local ToyCatalog = require(Toys:WaitForChild("ToyCatalog")) :: any
local MutationData = require(Toys:WaitForChild("MutationData")) :: any
local ToySize = require(Toys:WaitForChild("ToySize")) :: any
local VFX = require(Shared:WaitForChild("VFX")) :: any

local P = UIKit.Palettes
local img, toyImage, hex = UIKit.image, UIKit.toy, UIKit.hex
local center = UDim2.fromScale(0.5, 0.5)
local mid = Vector2.new(0.5, 0.5)
local GREY_TEXT = hex("BDB8D0")
local ORANGE = hex("FF9A2E")

local me = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("GameRemotes")

local GameUI = {}

export type Ctx = {
	gui: ScreenGui,
	panels: { [string]: UIKit.Panel },
	open: (string) -> (),
	hud: { [string]: any },
}

-- The latest profile from the server
local profile: any = nil
local meta: any = {}
local function attr(name: string): number
	local v = me:GetAttribute(name)
	return if typeof(v) == "number" then v else 0
end

local THEMES = {
	Cardboard = "Cardboard",
	SockLined = "Sock-lined",
	ToyBricks = "Toy Bricks",
	CosyCabin = "Cosy Cabin",
	CandyLand = "Candy Land",
	ArcadeNeon = "Arcade Neon",
	GoldenVault = "Golden Vault",
}
local SIZE_NAME = { S = "Small", M = "Medium", L = "Large", G = "Giant" }

local function rarityColor(rarity: string): Color3
	return UIKit.Rarity[rarity] or UIKit.White
end
local function mutationColor(id: string): Color3
	local m = MutationData.List[id]
	return if m then Color3.fromHex(m.Color) else UIKit.White
end
local function perSecond(entry: any): number
	local data = ToyCatalog.get(entry.id)
	local m = entry.m and MutationData.List[entry.m]
	return (if data then data.Money else 0) * (if m then m.Multiplier else 1) * ToySize.money(entry.z)
end

-- Your home
local function myHome(): Instance?
	local bedroom = Workspace:FindFirstChild("Bedroom")
	local holes = bedroom and bedroom:FindFirstChild("Holes")
	if not holes then
		return nil
	end
	for _, h in holes:GetChildren() do
		if h:GetAttribute("Owner") == me.UserId then
			return h
		end
	end
	return nil
end

-- A short message over the action button
local hudRef: { [string]: any } = {}
local function toast(text: string, ok: boolean)
	if hudRef.notify then
		UIKit.floatUp(hudRef.notify, text, 24, if ok then UIKit.White else ORANGE, UDim2.fromScale(0.5, 1))
	end
end

local function call(remote: string, ...: any)
	local args = table.pack(...)
	task.spawn(function()
		local r = remotes:FindFirstChild(remote) :: RemoteFunction?
		if not r then
			return
		end
		local ok, okCall, message = pcall(function()
			return r:InvokeServer(table.unpack(args, 1, args.n))
		end)
		if ok and message then
			toast(message, okCall == true)
		end
	end)
end

-- Countdown labels that change every second without redrawing their panel, per panel part
local tickers: { [Instance]: { () -> () } } = {}
local function tick(part: Instance, fn: () -> ())
	tickers[part] = tickers[part] or {}
	table.insert(tickers[part], fn)
	fn()
end
local function buttonText(holder: Instance): TextLabel?
	return holder:FindFirstChild("Text", true) :: TextLabel?
end

-- A content frame inside a panel that is thrown away and rebuilt on every refresh
local function content(parent: Instance, name: string): Frame
	tickers[parent] = {}
	local old = parent:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	return UIKit.new("Frame", {
		Name = name,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
	}, parent)
end

local function label(parent: Instance, text: string, size: number, x: number, y: number, o: any?): TextLabel
	local opts = o or {}
	opts.position = UDim2.fromOffset(x, y)
	opts.align = opts.align or Enum.TextXAlignment.Left
	opts.z = opts.z or 6
	return UIKit.text(parent, text, size, opts)
end

local function bar(parent: Instance, fraction: number, size: Vector2, position: UDim2, color: Color3): Frame
	local back = UIKit.new("Frame", {
		Name = "Bar",
		BackgroundColor3 = hex("16131C"),
		Size = UDim2.fromOffset(size.X, size.Y),
		Position = position,
		ZIndex = 6,
	}, parent)
	UIKit.corner(back, size.Y // 2)
	UIKit.stroke(back, UIKit.Ink, 2.5, true)
	local fill = UIKit.new("Frame", {
		Name = "Fill",
		BackgroundColor3 = color,
		Size = UDim2.fromScale(math.clamp(fraction, 0.03, 1), 1),
		ZIndex = 7,
	}, back)
	UIKit.corner(fill, size.Y // 2)
	UIKit.shade(fill, color)
	return back
end

---------------------------------------------------------------------------------------------------------------------
-- Upgrades: your home level (slots and look), your Speed wheel's level (how fast you train), and your Speed.
-- The home and the wheel are separate upgrades, so either can come first (Dylan, 19 Oct).
local function buildUpgrades(ctx: Ctx)
	local p = UIKit.panel(ctx.gui, "Upgrades", P.green, Vector2.new(760, 470))
	ctx.panels.Upgrades = p
	local function draw()
		local c = content(p.body, "Content")
		if not profile then
			label(c, "Loading...", 24, 20, 90)
			return
		end
		local cash = attr("Cash")

		-- Home
		local level = profile.HomeLevel
		local info = MapConfig.HOLE_LEVELS[level]
		local _, home = UIKit.tile(c, {
			name = "Home",
			size = UDim2.fromOffset(360, 180),
			position = UDim2.fromOffset(16, 78),
			top = hex("3A3648"),
			bottom = hex("2A2636"),
		})
		label(home, "YOUR HOME", 24, 16, 12, { color = UIKit.Yellow })
		label(home, `Level {level} · {THEMES[info.theme] or info.theme}`, 20, 16, 44)
		label(home, `{info.slots} toy slots`, 15, 16, 72, { font = UIKit.Fonts.body, stroke = 0 })
		local cost = GameConfig.HOME_COST[level + 1]
		if cost then
			local nextInfo = MapConfig.HOLE_LEVELS[level + 1]
			label(home, `Next: {THEMES[nextInfo.theme] or nextInfo.theme} · {nextInfo.slots} slots`, 14, 16, 94, {
				font = UIKit.Fonts.body,
				stroke = 0,
				color = GREY_TEXT,
			})
			UIKit.button(home, `Level up · {GameConfig.money(cost)}`, {
				palette = if cash >= cost then P.green else P.grey,
				size = UDim2.fromOffset(328, 50),
				position = UDim2.fromOffset(16, 118),
				textSize = 22,
				onClick = function()
					call("Buy", "Home")
				end,
			})
		else
			label(home, "MAX LEVEL!", 26, 16, 124, { color = UIKit.Yellow })
		end

		-- Speed wheel
		local wheel = profile.WheelLevel or 1
		local _, wh = UIKit.tile(c, {
			name = "Wheel",
			size = UDim2.fromOffset(360, 180),
			position = UDim2.fromOffset(16, 270),
			top = hex("23405E"),
			bottom = hex("1A2C44"),
		})
		label(wh, "SPEED WHEEL", 24, 16, 12, { color = hex("7FD8FF") })
		label(wh, `Lv {wheel} · {GameConfig.wheelName(wheel)}`, 20, 16, 44)
		label(wh, `+{GameConfig.speedText(GameConfig.wheelGain(wheel))} Speed a second`, 15, 16, 70, {
			font = UIKit.Fonts.body,
			stroke = 0,
			color = hex("7FD8FF"),
		})
		local wheelCost = GameConfig.WHEEL_COST[wheel + 1]
		if wheelCost then
			local nextGain = GameConfig.speedText(GameConfig.wheelGain(wheel + 1))
			label(wh, `Next: {GameConfig.wheelName(wheel + 1)} · +{nextGain}/s`, 14, 16, 92, {
				font = UIKit.Fonts.body,
				stroke = 0,
				color = GREY_TEXT,
			})
			UIKit.button(wh, `Upgrade · {GameConfig.money(wheelCost)}`, {
				palette = if cash >= wheelCost then P.cyan else P.grey,
				size = UDim2.fromOffset(328, 50),
				position = UDim2.fromOffset(16, 118),
				textSize = 22,
				onClick = function()
					call("Buy", "Wheel")
				end,
			})
		else
			label(wh, "MAX LEVEL!", 26, 16, 124, { color = UIKit.Yellow })
		end

		-- Speed: the big number, ticking up live while you train
		local _, sp = UIKit.tile(c, {
			name = "Speed",
			size = UDim2.fromOffset(352, 372),
			position = UDim2.fromOffset(392, 78),
			top = hex("3A3648"),
			bottom = hex("2A2636"),
		})
		UIKit.burst(sp, UDim2.fromOffset(176, 108), 220, 0.18)
		UIKit.icon(sp, img("Shoe"), 96, UDim2.fromOffset(176, 70), mid, 5)
		UIKit.text(sp, "SPEED", 22, { position = UDim2.fromOffset(176, 124), anchor = Vector2.new(0.5, 0), z = 6 })
		local speedLabel = UIKit.text(sp, "", 56, {
			font = UIKit.Fonts.number,
			position = UDim2.fromOffset(176, 148),
			anchor = Vector2.new(0.5, 0),
			stroke = 4,
			z = 6,
		})
		tick(p.body, function()
			speedLabel.Text = GameConfig.speedText(attr("Speed"))
		end)
		label(sp, `+{GameConfig.speedText(GameConfig.wheelGain(wheel))} Speed a second`, 20, 24, 236, {
			color = hex("7FD8FF"),
		})
		label(sp, "Hop on the wheel in your home and run!", 15, 24, 276, { font = UIKit.Fonts.body, stroke = 0 })
		label(sp, "No limit! A better wheel trains faster.", 13, 24, 302, {
			font = UIKit.Fonts.body,
			stroke = 0,
			color = GREY_TEXT,
		})
	end
	draw()
	-- redraw when a price becomes affordable (or not) or the training bar moves
	local function sig(): string
		if not profile then
			return ""
		end
		local cash = attr("Cash")
		local cost = GameConfig.HOME_COST[profile.HomeLevel + 1]
		local wheelCost = GameConfig.WHEEL_COST[(profile.WheelLevel or 1) + 1]
		return table.concat({
			tostring(cost ~= nil and cash >= cost),
			tostring(wheelCost ~= nil and cash >= wheelCost),
		}, ",")
	end
	return p, draw, sig
end

---------------------------------------------------------------------------------------------------------------------
-- Your Toys: your inventory. Equipped toys are in your pen earning (as many as your home's slots); the rest wait
-- here. Equip / unequip, Equip Best, lock (Sell skips locked toys), sell one, or Sell Mode to pick many at once.
local function buildToys(ctx: Ctx)
	local p = UIKit.panel(ctx.gui, "Your Toys", P.violet, Vector2.new(860, 520))
	ctx.panels.Toys = p
	local filter = "All"
	local selected: string? = nil
	local selling = false
	local picked: { [string]: boolean } = {}
	local draw: () -> ()
	draw = function()
		local c = content(p.body, "Content")
		local h = content(p.header, "HeaderInfo")
		h.ZIndex = 8
		if not profile then
			label(c, "Loading...", 24, 20, 90)
			return
		end
		local capacity = MapConfig.HOLE_LEVELS[profile.HomeLevel].slots
		local equipped = 0
		for _, t in profile.Toys do
			if t.e ~= false then
				equipped += 1
			end
		end
		local _, cap = UIKit.block(h, {
			name = "Capacity",
			size = UDim2.fromOffset(190, 36),
			position = UDim2.new(1, -70, 0.5, 0),
			anchor = Vector2.new(1, 0.5),
			color = UIKit.Panel,
			edge = UIKit.Ink,
			strokeWidth = 3,
		})
		UIKit.text(cap, `In pen {equipped}/{capacity}`, 18, { position = center, anchor = mid })

		-- filters, then the actions
		for i, name in { "All", "Equipped", "Inventory" } do
			UIKit.button(c, name, {
				palette = if name == filter then P.cyan else P.grey,
				size = UDim2.fromOffset(98, 40),
				position = UDim2.fromOffset(16 + (i - 1) * 104, 78),
				textSize = 16,
				onClick = function()
					filter = name
					task.defer(draw)
				end,
			})
		end
		UIKit.button(c, "Equip Best", {
			palette = P.green,
			size = UDim2.fromOffset(106, 40),
			position = UDim2.fromOffset(330, 78),
			textSize = 16,
			onClick = function()
				call("Buy", "EquipBest")
			end,
		})
		UIKit.button(c, if selling then "Cancel" else "Sell Mode", {
			palette = if selling then P.grey else P.red,
			size = UDim2.fromOffset(106, 40),
			position = UDim2.fromOffset(442, 78),
			textSize = 16,
			onClick = function()
				selling = not selling
				table.clear(picked)
				task.defer(draw)
			end,
		})

		local list = {}
		for _, entry in profile.Toys do
			local on = entry.e ~= false
			if filter == "All" or (filter == "Equipped" and on) or (filter == "Inventory" and not on) then
				table.insert(list, entry)
			end
		end
		table.sort(list, function(a, b)
			local ea, eb = a.e ~= false, b.e ~= false
			if ea ~= eb then
				return ea
			end
			return perSecond(a) > perSecond(b)
		end)
		local scroll = UIKit.new("ScrollingFrame", {
			Name = "Grid",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(536, if selling then 318 else 376),
			Position = UDim2.fromOffset(12, 128),
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 6,
			ZIndex = 4,
		}, c)
		UIKit.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(82, 82),
			CellPadding = UDim2.fromOffset(8, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, scroll)
		UIKit.new("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingTop = UDim.new(0, 4) }, scroll)
		if #list == 0 then
			label(c, "No toys here yet! Grab a sleeping toy and drag it home.", 18, 24, 150, {
				font = UIKit.Fonts.body,
			})
		end
		local stillThere = false
		for _, e in list do
			if e.u == selected then
				stillThere = true
			end
		end
		if not stillThere then
			selected = list[1] and list[1].u
		end
		local chosen: any = nil
		for i, entry in list do
			local data = ToyCatalog.get(entry.id)
			if entry.u == selected then
				chosen = entry
			end
			local on = entry.e ~= false
			local holder, s = UIKit.tile(scroll, {
				name = "Toy " .. i,
				size = UDim2.fromOffset(82, 82),
				top = if picked[entry.u] then hex("6A2232") else hex("3A3648"),
				bottom = if picked[entry.u] then hex("4A1622") else hex("2A2636"),
				edge = rarityColor(data and data.Rarity or "Common"),
				layoutOrder = i,
			})
			UIKit.backing(s, center, 80, 0.3)
			UIKit.hoverWiggle(s, UIKit.icon(s, toyImage(entry.id), 64, UDim2.fromScale(0.5, 0.45), mid))
			UIKit.text(s, GameConfig.money(perSecond(entry)) .. "/s", 13, {
				color = UIKit.CashGreen,
				font = UIKit.Fonts.number,
				position = UDim2.new(0.5, 0, 1, -3),
				anchor = Vector2.new(0.5, 1),
				stroke = 2,
				z = 7,
			})
			if on then
				UIKit.icon(s, img("Check"), 22, UDim2.new(1, -3, 0, 3), Vector2.new(1, 0), 8)
			if ToySize.isBig(entry.z) then
				UIKit.text(s, string.upper(entry.z), 11, {
					color = ToySize.color(entry.z),
					position = UDim2.new(0.5, 0, 0, 2),
					anchor = Vector2.new(0.5, 0),
					stroke = 2,
					z = 8,
				})
			end
			end
			if entry.l then
				UIKit.icon(s, img("Lock"), 20, UDim2.fromOffset(3, 3), nil, 8)
			elseif entry.m then
				local dot = UIKit.new("Frame", {
					BackgroundColor3 = mutationColor(entry.m),
					Size = UDim2.fromOffset(14, 14),
					Position = UDim2.fromOffset(5, 5),
					ZIndex = 7,
				}, s)
				UIKit.corner(dot, 7)
				UIKit.stroke(dot, UIKit.Ink, 2, true)
			end
			if entry.u == selected and not selling then
				UIKit.stroke(s, UIKit.White, 3, true)
			end
			UIKit.clickable(holder, function()
				if selling then
					if not entry.l then
						picked[entry.u] = if picked[entry.u] then nil else true
					else
						toast("That toy is locked", false)
					end
				else
					selected = entry.u
				end
				task.defer(draw)
			end)
		end

		-- Sell Mode: the bar under the grid
		if selling then
			local n, total = 0, 0
			for uid in picked do
				for _, e in profile.Toys do
					if e.u == uid then
						n += 1
						total += math.floor(perSecond(e) * GameConfig.SELL_SECONDS)
					end
				end
			end
			UIKit.button(c, "Pick all in inventory", {
				palette = P.grey,
				size = UDim2.fromOffset(220, 46),
				position = UDim2.fromOffset(16, 458),
				textSize = 18,
				onClick = function()
					for _, e in profile.Toys do
						if e.e == false and not e.l then
							picked[e.u] = true
						end
					end
					task.defer(draw)
				end,
			})
			UIKit.button(c, if n > 0 then `Sell {n} · {GameConfig.money(total)}` else "Pick toys to sell", {
				palette = if n > 0 then P.gold else P.grey,
				size = UDim2.fromOffset(300, 46),
				position = UDim2.fromOffset(244, 458),
				textSize = 20,
				onClick = function()
					if n == 0 then
						return
					end
					local uids = {}
					for uid in picked do
						table.insert(uids, uid)
					end
					call("Buy", "Sell", uids)
					table.clear(picked)
					selling = false
				end,
			})
		end

		-- the detail card
		local _, det = UIKit.tile(c, {
			name = "Detail",
			size = UDim2.fromOffset(284, 424),
			position = UDim2.fromOffset(560, 80),
			top = hex("1E1B26"),
			bottom = hex("15121C"),
		})
		if not chosen then
			UIKit.text(det, "Pick a toy", 22, { position = center, anchor = mid, color = GREY_TEXT })
			return
		end
		local data = ToyCatalog.get(chosen.id)
		local rarity = data and data.Rarity or "Common"
		UIKit.burst(det, UDim2.fromOffset(142, 76), 230, 0.22)
		UIKit.hoverWiggle(det, UIKit.icon(det, toyImage(chosen.id), 140, UDim2.fromOffset(142, 74), mid))
		UIKit.text(det, if data then data.Name else chosen.id, 24, {
			position = UDim2.fromOffset(142, 146),
			anchor = Vector2.new(0.5, 0),
		})
		local tag = UIKit.new("Frame", {
			BackgroundColor3 = rarityColor(rarity),
			Size = UDim2.fromOffset(130, 28),
			Position = UDim2.fromOffset(142, 178),
			AnchorPoint = Vector2.new(0.5, 0),
			ZIndex = 5,
		}, det)
		UIKit.corner(tag, 6)
		UIKit.stroke(tag, UIKit.Ink, 2.5, true)
		UIKit.text(tag, rarity, 17, { stroke = 2, position = center, anchor = mid, z = 6 })
		if chosen.m or ToySize.isBig(chosen.z) then
			-- "Huge x4 · Gold x2"
			local parts = {}
			if ToySize.isBig(chosen.z) then
				table.insert(parts, `{chosen.z} x{ToySize.money(chosen.z)}`)
			end
			if chosen.m then
				local m = MutationData.List[chosen.m]
				table.insert(parts, `{chosen.m} x{m and m.Multiplier or 1}`)
			end
			UIKit.text(det, table.concat(parts, " · "), 18, {
				color = if chosen.m then mutationColor(chosen.m) else ToySize.color(chosen.z),
				position = UDim2.fromOffset(142, 210),
				anchor = Vector2.new(0.5, 0),
			})
		end
		UIKit.text(det, GameConfig.money(perSecond(chosen)) .. "/s", 28, {
			font = UIKit.Fonts.number,
			color = UIKit.CashGreen,
			position = UDim2.fromOffset(142, 234),
			anchor = Vector2.new(0.5, 0),
		})
		UIKit.text(
			det,
			`{SIZE_NAME[chosen.s or (data and data.Size) or ""] or ""} · {data and data.SetName or ""} set`,
			14,
			{
				font = UIKit.Fonts.body,
				color = GREY_TEXT,
				stroke = 0,
				position = UDim2.fromOffset(142, 272),
				anchor = Vector2.new(0.5, 0),
			}
		)
		local on = chosen.e ~= false
		UIKit.button(det, if on then "Unequip" else "Equip", {
			palette = if on then P.grey else P.green,
			size = UDim2.fromOffset(252, 48),
			position = UDim2.fromOffset(16, 304),
			textSize = 22,
			onClick = function()
				call("Buy", if on then "Unequip" else "Equip", chosen.u)
			end,
		})
		UIKit.button(det, if chosen.l then "Unlock" else "Lock", {
			palette = if chosen.l then P.orange else P.light,
			icon = img("Lock"),
			iconSize = 22,
			size = UDim2.fromOffset(120, 48),
			position = UDim2.fromOffset(16, 362),
			textSize = 18,
			onClick = function()
				call("Buy", if chosen.l then "Unlock" else "Lock", chosen.u)
			end,
		})
		local price = math.floor(perSecond(chosen) * GameConfig.SELL_SECONDS)
		UIKit.button(det, "Sell " .. GameConfig.money(price), {
			palette = if chosen.l then P.grey else P.gold,
			size = UDim2.fromOffset(124, 48),
			position = UDim2.fromOffset(144, 362),
			textSize = 18,
			onClick = function()
				if chosen.l then
					toast("Unlock it first to sell it", false)
					return
				end
				call("Buy", "Sell", chosen.u)
			end,
		})
	end
	draw()
	return p, draw
end

---------------------------------------------------------------------------------------------------------------------
-- Index: every toy in every set, found or not, and which mutations you've found of each.
local function buildIndex(ctx: Ctx)
	local p = UIKit.panel(ctx.gui, "Toy Index", P.cyan, Vector2.new(860, 520))
	ctx.panels.Index = p
	local setIndex = 1
	local draw: () -> ()
	draw = function()
		local c = content(p.body, "Content")
		local h = content(p.header, "HeaderInfo")
		h.ZIndex = 8
		local index = if profile then profile.Index else {}
		local found, total = 0, 0
		for _, t in ToyCatalog.list() do
			total += 1
			if index[t.Id] then
				found += 1
			end
		end
		UIKit.text(h, `FOUND {found}/{total}`, 22, {
			position = UDim2.new(1, -74, 0.5, 0),
			anchor = Vector2.new(1, 0.5),
			z = 9,
		})
		local setId = ToyCatalog.SET_ORDER[setIndex]
		local toys = ToyCatalog.inSet(setId)
		local inSet = 0
		for _, t in toys do
			if index[t.Id] then
				inSet += 1
			end
		end
		local function step(d: number)
			setIndex = (setIndex - 1 + d) % #ToyCatalog.SET_ORDER + 1
			task.defer(draw)
		end
		UIKit.button(c, "<", {
			palette = P.grey,
			size = UDim2.fromOffset(52, 44),
			position = UDim2.fromOffset(16, 76),
			textSize = 26,
			onClick = function()
				step(-1)
			end,
		})
		UIKit.button(c, ">", {
			palette = P.grey,
			size = UDim2.fromOffset(52, 44),
			position = UDim2.new(1, -16, 0, 76),
			anchor = Vector2.new(1, 0),
			textSize = 26,
			onClick = function()
				step(1)
			end,
		})
		UIKit.text(c, `{ToyCatalog.setName(setId)}  ·  {inSet}/{#toys}`, 26, {
			position = UDim2.new(0.5, 0, 0, 98),
			anchor = mid,
			z = 6,
		})
		local grid = UIKit.new("ScrollingFrame", {
			Name = "Grid",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, -24, 0, 330),
			Position = UDim2.fromOffset(12, 128),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
			ScrollBarThickness = 6,
			ZIndex = 4,
		}, c)
		UIKit.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(110, 156),
			CellPadding = UDim2.fromOffset(9, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}, grid)
		UIKit.new("UIPadding", { PaddingTop = UDim.new(0, 4) }, grid)
		for i, t in toys do
			local got = index[t.Id]
			local _, s = UIKit.tile(grid, {
				name = t.Id,
				size = UDim2.fromOffset(110, 156),
				top = if got then hex("3A3648") else hex("1E1B26"),
				bottom = if got then hex("2A2636") else hex("16131C"),
				edge = if got then rarityColor(t.Rarity) else hex("0B0910"),
				layoutOrder = i,
			})
			local pic = UIKit.icon(s, toyImage(t.Id), 80, UDim2.fromOffset(55, 50), mid)
			if not got then
				pic.ImageColor3 = Color3.new(0, 0, 0)
				pic.ImageTransparency = 0.25
			else
				UIKit.hoverWiggle(s, pic)
			end
			UIKit.text(s, if got then t.Name else "???", 12, {
				position = UDim2.fromOffset(55, 96),
				anchor = Vector2.new(0.5, 0),
				size = UDim2.fromOffset(104, 30),
				stroke = 2,
				z = 6,
			}).TextWrapped =
				true
			-- one dot per mutation (event ones too), lit when you've found it on this toy
			local dots = UIKit.new("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(100, 10),
				Position = UDim2.fromOffset(5, 136),
				ZIndex = 6,
			}, s)
			UIKit.new("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, 2),
			}, dots)
			for _, mid2 in MutationData.Order do
				local lit = got and got[mid2]
				local dot = UIKit.new("Frame", {
					BackgroundColor3 = if lit then mutationColor(mid2) else hex("0B0910"),
					Size = UDim2.fromOffset(8, 8),
					ZIndex = 7,
				}, dots)
				UIKit.corner(dot, 4)
			end
		end
		local reward = GameConfig.SET_REWARD[setId]
		local done = profile and profile.Sets[setId]
		local footer = if not reward
			then "Event and special toys: collect them all!"
			elseif done then "SET COMPLETE! +2% luck on mutations"
			else `Find all {#toys}: {GameConfig.money(reward)} and +2% luck on mutations`
		UIKit.text(c, footer, 18, {
			color = if done then UIKit.Yellow else UIKit.White,
			position = UDim2.new(0.5, 0, 1, -32),
			anchor = mid,
			z = 6,
		})
	end
	draw()
	return p, draw
end

---------------------------------------------------------------------------------------------------------------------
-- Reward cards (Daily and Playtime): a ray background in the card's colour, a light inner rim and a dark border.
local function rewardCard(parent: Instance, name: string, size: Vector2, position: UDim2, colour: string): Frame
	local cardFrame = UIKit.new("Frame", {
		Name = name,
		BackgroundColor3 = UIKit.Ink,
		Size = UDim2.fromOffset(size.X, size.Y),
		Position = position,
		ZIndex = 3,
	}, parent)
	UIKit.corner(cardFrame, 6)
	UIKit.stroke(cardFrame, UIKit.Ink, 4, true)
	local bg = UIKit.new("ImageLabel", {
		Name = "Background",
		BackgroundTransparency = 1,
		Image = img("PassCard_Reward" .. colour),
		ScaleType = Enum.ScaleType.Crop,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 1,
	}, cardFrame)
	UIKit.corner(bg, 6)
	local rim = UIKit.new("Frame", {
		Name = "Rim",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -6, 1, -6),
		Position = UDim2.fromOffset(3, 3),
		ZIndex = 2,
	}, cardFrame)
	UIKit.corner(rim, 4)
	UIKit.new("UIStroke", { Color = UIKit.White, Transparency = 0.5, Thickness = 2 }, rim)
	return cardFrame
end

-- A small dark pill at the top of a card ("DAY 3", "5 MIN").
local function chip(parent: Instance, text: string, y: number, color: Color3?): TextLabel
	local t = UIKit.text(parent, text, 14, {
		color = color,
		stroke = 0,
		position = UDim2.new(0.5, 0, 0, y),
		anchor = Vector2.new(0.5, 0),
		z = 6,
	})
	t.BackgroundColor3 = UIKit.Ink
	t.BackgroundTransparency = 0.4
	UIKit.corner(t, 10)
	UIKit.new("UIPadding", {
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
		PaddingTop = UDim.new(0, 3),
		PaddingBottom = UDim.new(0, 3),
	}, t)
	return t
end

-- The bar under a reward: CLAIMED (green + tick), CLAIM! (green, pulsing), a countdown (dark + clock) or LOCKED.
local function rewardStatus(
	parent: Instance,
	state: string,
	text: string,
	size: Vector2,
	position: UDim2,
	onClick: (() -> ())?
): Frame
	local holder = UIKit.button(parent, text, {
		palette = if state == "claimed" or state == "ready"
			then P.green
			elseif state == "timer" then P.grey
			else P.light,
		icon = if state == "claimed"
			then img("Check")
			elseif state == "timer" then img("Clock")
			elseif state == "locked" then img("Lock")
			else nil,
		size = UDim2.fromOffset(size.X, size.Y),
		position = position,
		textSize = 18,
		iconSize = 22,
		iconGap = 5,
		onClick = onClick,
	})
	holder.ZIndex = 4
	if state == "ready" then
		UIKit.pulse(holder:FindFirstChild("Face") :: Frame, 0.06, 0.6)
	end
	return holder
end

local function goldRing(cardFrame: Frame)
	local s = cardFrame:FindFirstChildOfClass("UIStroke")
	if s then
		s.Color = UIKit.Yellow
		s.Thickness = 4
	end
end

-- What a reward is, for its card: text, picture, text colour
local CASH_PICS = { "CashPack1v2", "CashPack2v2", "CashPack3v2", "CashPack4v2" }
local function describe(r: any, boostMinutes: number?, k: number): (string, string, Color3)
	if r.kind == "Cash" then
		return GameConfig.money(r.amount), img(CASH_PICS[math.clamp(k, 1, #CASH_PICS)]), UIKit.CashGreen
	elseif r.kind == "Boost" then
		return `x2 CASH {boostMinutes or r.minutes}m`, img("BoltBig"), UIKit.White
	end
	return `{string.upper(SIZE_NAME[r.size] or "")} TOY`, img("Gift"), UIKit.White
end

local function clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	if seconds >= 3600 then
		return string.format("%d:%02d:%02d", seconds // 3600, (seconds // 60) % 60, seconds % 60)
	end
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

-- Daily Rewards: a 7-day streak with a big Day 7 jackpot.
local function buildDaily(ctx: Ctx)
	local p = UIKit.panel(ctx.gui, "DAILY REWARDS", P.magenta, Vector2.new(720, 500))
	ctx.panels.Daily = p
	local function draw()
		local c = content(p.body, "Content")
		local h = content(p.header, "HeaderInfo")
		h.ZIndex = 8
		local now = Workspace:GetServerTimeNow()
		local today = math.floor(now / 86400)
		local daily = if profile then profile.Daily else { Streak = 0, Day = 0 }
		local claimedToday = daily.Day == today
		local nextDay = if claimedToday then daily.Streak + 1 elseif daily.Day == today - 1 then daily.Streak + 1 else 1
		if nextDay > #GameConfig.DAILY then
			nextDay = 1
		end
		local streak = if claimedToday or daily.Day == today - 1 then daily.Streak else 0
		UIKit.text(h, `STREAK {streak}/7`, 20, { position = UDim2.new(1, -240, 0, 6), z = 9 })
		bar(h, streak / 7, Vector2.new(170, 16), UDim2.new(1, -240, 0, 38), hex("5BE36A"))
		local function untilTomorrow(): number
			return (today + 1) * 86400 - Workspace:GetServerTimeNow()
		end
		for i = 1, 7 do
			local r = GameConfig.DAILY[i]
			local state = if i < nextDay or (claimedToday and i == daily.Streak)
				then "claimed"
				elseif i == nextDay and not claimedToday then "ready"
				elseif i == nextDay then "timer"
				else "locked"
			local text = if state == "claimed"
				then "CLAIMED"
				elseif state == "ready" then "CLAIM!"
				elseif state == "timer" then clock(untilTomorrow())
				else "LOCKED"
			local onClick = if state == "ready"
				then function()
					call("Claim", "Daily")
				end
				else nil
			if i < 7 then
				local col = if i <= 4 then i - 1 else i - 5
				local row = if i <= 4 then 0 else 1
				local colours = { "Blue", "Red", "Green", "Purple", "Pink", "Gold" }
				local t = rewardCard(
					c,
					"Day " .. i,
					Vector2.new(160, 180),
					UDim2.fromOffset(16 + col * 172, 78 + row * 192),
					colours[i]
				)
				local words, pic, colour = describe(r, nil, i)
				chip(
					t,
					if state == "ready" then "TODAY!" else "DAY " .. i,
					8,
					if state == "ready" then UIKit.Yellow else nil
				)
				UIKit.text(t, words, 16, {
					color = colour,
					stroke = 3,
					position = UDim2.new(0.5, 0, 0, 32),
					anchor = Vector2.new(0.5, 0),
					z = 6,
				})
				UIKit.hoverWiggle(t, UIKit.icon(t, pic, 92, UDim2.fromOffset(80, 94), mid, 5))
				if state == "ready" then
					goldRing(t)
					UIKit.sparkle(t, UDim2.fromOffset(24, 70), 16)
					UIKit.sparkle(t, UDim2.fromOffset(138, 84), 13)
				end
				local holder = rewardStatus(t, state, text, Vector2.new(144, 34), UDim2.fromOffset(8, 136), onClick)
				if state == "timer" then
					tick(p.body, function()
						local l = buttonText(holder)
						if l then
							l.Text = clock(untilTomorrow())
						end
					end)
				end
			else
				local jp =
					rewardCard(c, "Day 7", Vector2.new(334, 180), UDim2.fromOffset(16 + 2 * 172, 78 + 192), "Jackpot")
				chip(jp, "DAY 7", 8)
				UIKit.text(
					jp,
					"JACKPOT!",
					28,
					{ stroke = 4, position = UDim2.fromOffset(167, 47), anchor = mid, z = 6 }
				)
				local prizes = {
					{ img("CashPack3v2"), GameConfig.money(r.cash or 0), UIKit.CashGreen },
					{ img("Gift"), `{string.upper(SIZE_NAME[r.size] or "")} TOY`, UIKit.White },
				}
				for k, prize in prizes do
					local x = 100 + (k - 1) * 134
					UIKit.hoverWiggle(jp, UIKit.icon(jp, prize[1], 70, UDim2.fromOffset(x, 88), mid, 5))
					chip(jp, prize[2], 112, prize[3]).Position = UDim2.fromOffset(x, 112)
				end
				UIKit.sparkle(jp, UDim2.fromOffset(28, 40), 18)
				UIKit.sparkle(jp, UDim2.fromOffset(306, 44), 20)
				local holder = rewardStatus(jp, state, text, Vector2.new(318, 34), UDim2.fromOffset(8, 136), onClick)
				if state == "timer" then
					tick(p.body, function()
						local l = buttonText(holder)
						if l then
							l.Text = clock(untilTomorrow())
						end
					end)
				end
			end
		end
		local footer = UIKit.text(c, "YOUR REWARD IS READY!", 20, {
			position = UDim2.new(0.5, 0, 1, -40),
			anchor = Vector2.new(0.5, 0),
		})
		if claimedToday then
			tick(p.body, function()
				footer.Text = `NEXT REWARD IN {clock(untilTomorrow())}`
			end)
		end
	end
	draw()
	local function sig(): string
		local day = if profile then profile.Daily.Day else 0
		return `{day}:{math.floor(Workspace:GetServerTimeNow() / 86400)}`
	end
	return p, draw, sig
end

-- Playtime Rewards: ten gifts that unlock the longer you play this session.
local function playedNow(): number
	return Workspace:GetServerTimeNow() - (meta.sessionStart or Workspace:GetServerTimeNow())
end

local function buildPlaytime(ctx: Ctx)
	local p = UIKit.panel(ctx.gui, "PLAYTIME REWARDS", P.orange, Vector2.new(760, 496))
	ctx.panels.Playtime = p
	local function draw()
		local c = content(p.body, "Content")
		local h = content(p.header, "HeaderInfo")
		h.ZIndex = 8
		local claimed: { [number]: boolean } = {}
		for _, k in meta.playtimeClaimed or {} do
			claimed[k] = true
		end
		local count = 0
		for _ in claimed do
			count += 1
		end
		local played = playedNow()
		UIKit.text(h, `CLAIMED {count}/{#GameConfig.PLAYTIME}`, 18, { position = UDim2.new(1, -240, 0, 6), z = 9 })
		bar(h, count / #GameConfig.PLAYTIME, Vector2.new(170, 16), UDim2.new(1, -240, 0, 38), hex("FFD43B"))
		local colours = { "Blue", "Gold", "Red", "Purple", "Green" }
		local nextIn: number? = nil
		for i, g in GameConfig.PLAYTIME do
			local col, row = (i - 1) % 5, (i - 1) // 5
			local x, y = 16 + col * 146, 78 + row * 186
			local left = g.minutes * 60 - played
			local state = if claimed[i] then "claimed" elseif left <= 0 then "ready" else "timer"
			if state == "timer" and (not nextIn or left < nextIn) then
				nextIn = left
			end
			local t =
				rewardCard(c, g.minutes .. " MIN", Vector2.new(136, 130), UDim2.fromOffset(x, y), colours[col + 1])
			chip(t, g.minutes .. " MIN", 6)
			local words, pic, colour = describe(g, g.minutes2, (i + 1) // 2)
			UIKit.hoverWiggle(t, UIKit.icon(t, pic, 80, UDim2.fromOffset(68, 64), mid, 5))
			UIKit.text(t, words, 16, {
				color = colour,
				stroke = 3,
				position = UDim2.new(1, -8, 1, -5),
				anchor = Vector2.new(1, 1),
				z = 6,
			})
			if state == "ready" then
				goldRing(t)
				UIKit.sparkle(t, UDim2.fromOffset(18, 36), 16)
			end
			local holder = rewardStatus(
				c,
				state,
				if state == "claimed" then "CLAIMED" elseif state == "ready" then "CLAIM!" else clock(left),
				Vector2.new(136, 34),
				UDim2.fromOffset(x, y + 138),
				if state == "ready"
					then function()
						call("Claim", "Playtime", i)
					end
					else nil
			)
			if state == "timer" then
				tick(p.body, function()
					local l = buttonText(holder)
					if l then
						l.Text = clock(g.minutes * 60 - playedNow())
					end
				end)
			end
		end
		local footer = UIKit.text(c, "", 20, { position = UDim2.new(0.5, 0, 1, -36), anchor = Vector2.new(0.5, 0) })
		local gap = if nextIn then nextIn + played else nil
		tick(p.body, function()
			local now = playedNow()
			footer.Text = `PLAYED {clock(now)}` .. (if gap then `   |   NEXT GIFT IN {clock(gap - now)}` else "")
		end)
	end
	draw()
	-- redraw when a gift becomes ready or is claimed
	local function sig(): string
		local ready = 0
		for _, g in GameConfig.PLAYTIME do
			if g.minutes * 60 <= playedNow() then
				ready += 1
			end
		end
		return `{ready}:{#(meta.playtimeClaimed or {})}`
	end
	return p, draw, sig
end

---------------------------------------------------------------------------------------------------------------------
-- The reveal card: pops up in the middle when one of your toys wakes up.
local function showReveal(ctx: Ctx, info: any)
	local old = ctx.gui:FindFirstChild("Reveal")
	if old then
		old:Destroy()
	end
	local root = UIKit.new("Frame", {
		Name = "Reveal",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(420, 300),
		Position = UDim2.fromScale(0.5, 0.42),
		AnchorPoint = mid,
		ZIndex = 60,
	}, ctx.gui)
	UIKit.fit(root, Vector2.new(440, 320))
	local pop = UIKit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, root)
	local s = UIKit.animScale(pop)
	s.Scale = 0.3
	UIKit.tween(s, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	local color = rarityColor(info.rarity)
	UIKit.burst(pop, UDim2.fromOffset(210, 120), 360, 0.45)
	UIKit.text(pop, "NEW TOY!", 34, { position = UDim2.fromOffset(210, 0), anchor = Vector2.new(0.5, 0), stroke = 4 })
	-- a bigger toy shows bigger on the card
	local picSize = 150 * (1 + (ToySize.scale(info.sizeTier) - 1) * 0.15)
	local pic = UIKit.icon(pop, toyImage(info.id), picSize, UDim2.fromOffset(210, 120), mid, 6)
	UIKit.bob(pic, 6, 0.8)
	UIKit.sparkle(pop, UDim2.fromOffset(110, 70), 22)
	-- the size roll: a tilted BIG / HUGE / GIANT stamp that punches in just after the card
	if ToySize.isBig(info.sizeTier) then
		local stamp = UIKit.text(
			pop,
			`{string.upper(info.sizeTier)}!  x{ToySize.money(info.sizeTier)}`,
			26 + ToySize.scale(info.sizeTier) * 2,
			{
				color = ToySize.color(info.sizeTier),
				position = UDim2.fromOffset(318, 64),
				anchor = mid,
				stroke = 4,
				z = 9,
			}
		)
		stamp.Rotation = 12
		local punch = UIKit.animScale(stamp)
		punch.Scale = 0
		task.delay(0.4, function()
			punch.Scale = 2.6
			UIKit.tween(punch, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
		end)
	end
	UIKit.sparkle(pop, UDim2.fromOffset(312, 96), 18)
	UIKit.text(pop, info.name, 30, { position = UDim2.fromOffset(210, 196), anchor = Vector2.new(0.5, 0), stroke = 4 })
	local line = info.rarity .. (if info.mutation then "  ·  " .. string.upper(info.mutation) .. "!" else "")
	local rarityLabel = UIKit.text(pop, line, 22, {
		color = if info.mutation then mutationColor(info.mutation) else color,
		position = UDim2.fromOffset(210, 232),
		anchor = Vector2.new(0.5, 0),
		stroke = 3.5,
	})
	local cashLabel = UIKit.text(pop, "+" .. GameConfig.money(info.perSecond) .. "/s", 28, {
		font = UIKit.Fonts.number,
		color = UIKit.CashGreen,
		position = UDim2.fromOffset(210, 262),
		anchor = Vector2.new(0.5, 0),
		stroke = 3.5,
	})
	UIKit.text(
		pop,
		(SIZE_NAME[info.size or ""] or "") .. (if info.equipped then " · in your pen" else " · in your inventory"),
		15,
		{
			font = UIKit.Fonts.body,
			color = GREY_TEXT,
			position = UDim2.fromOffset(210, 298),
			anchor = Vector2.new(0.5, 0),
			stroke = 2,
		}
	)
	local hit = UIKit.new("TextButton", {
		BackgroundTransparency = 1,
		Text = "",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 70,
	}, root)
	local function close()
		if root.Parent then
			UIKit.tween(s, 0.15, { Scale = 0.3 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In).Completed
				:Once(function()
					root:Destroy()
				end)
		end
	end
	hit.Activated:Connect(close)
	-- rays, shine, the rarity line bouncing in, the $/s counting up (VFX)
	pcall(VFX.revealCard, pop, info, { rarityLabel = rarityLabel, cashLabel = cashLabel })
	task.delay(4 + math.max(0, VFX.tier(info.rarity).n - 4) * 0.5, close)
end

-- Rewards ready to claim right now: the daily gift (0 or 1) and the playtime gifts (a badge on each button)
local function readyRewards(): (number, number)
	if not profile then
		return 0, 0
	end
	local daily = if profile.Daily.Day ~= math.floor(Workspace:GetServerTimeNow() / 86400) then 1 else 0
	local claimed: { [number]: boolean } = {}
	for _, k in meta.playtimeClaimed or {} do
		claimed[k] = true
	end
	local playtime = 0
	for i, g in GameConfig.PLAYTIME do
		if not claimed[i] and g.minutes * 60 <= playedNow() then
			playtime += 1
		end
	end
	return daily, playtime
end

local function setBadge(badge: Frame?, n: number)
	if not badge then
		return
	end
	badge.Visible = n > 0
	local t = badge:FindFirstChildWhichIsA("TextLabel", true)
	if t then
		t.Text = tostring(n)
	end
end

---------------------------------------------------------------------------------------------------------------------
-- Your blankets: the ones waiting in your home, on the right edge, with their timers ("READY!" when you can hatch).
local BLANKET_COLOUR = { S = hex("4DA8FF"), M = hex("9B7BFF"), L = hex("FF8A3D") } :: { [string]: Color3 }
local function drawBlankets(holder: Frame)
	holder:ClearAllChildren()
	local list = if profile then profile.Blankets or {} else {}
	if #list == 0 then
		return
	end
	UIKit.new("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}, holder)
	local title = UIKit.text(holder, `BLANKETS {#list}/{GameConfig.MAX_BLANKETS}`, 16, { stroke = 3 })
	title.LayoutOrder = 0
	local sorted = table.clone(list)
	table.sort(sorted, function(a, b)
		return a.w < b.w
	end)
	local now = Workspace:GetServerTimeNow()
	for i, b in sorted do
		local left = b.w - now
		local ready = left <= 0
		local _, face = UIKit.block(holder, {
			name = "Blanket " .. i,
			size = UDim2.fromOffset(190, 38),
			color = if ready then hex("2E7D32") else hex("2F2F36"),
			edge = UIKit.Ink,
			strokeWidth = 2.5,
			layoutOrder = i,
		})
		local chipFrame = UIKit.new("Frame", {
			BackgroundColor3 = BLANKET_COLOUR[b.s] or UIKit.White,
			Size = UDim2.fromOffset(26, 26),
			Position = UDim2.new(0, 6, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			ZIndex = 4,
		}, face)
		UIKit.corner(chipFrame, 6)
		UIKit.stroke(chipFrame, UIKit.Ink, 2, true)
		UIKit.text(chipFrame, b.s, 15, { position = center, anchor = mid, stroke = 2, z = 5 })
		UIKit.text(face, (SIZE_NAME[b.s] or "") .. " toy", 15, {
			position = UDim2.new(0, 40, 0.5, 0),
			anchor = Vector2.new(0, 0.5),
			align = Enum.TextXAlignment.Left,
			z = 5,
		})
		UIKit.text(face, if ready then "READY!" else clock(left), 15, {
			font = UIKit.Fonts.number,
			color = if ready then UIKit.Yellow else UIKit.White,
			position = UDim2.new(1, -8, 0.5, 0),
			anchor = Vector2.new(1, 0.5),
			z = 5,
		})
	end
	local hint = UIKit.text(holder, "Hold E on a ready one at home", 12, { font = UIKit.Fonts.body, stroke = 2 })
	hint.LayoutOrder = 99
end

---------------------------------------------------------------------------------------------------------------------
-- The first-time tutorial (Dylan, 19 Oct: short, like Steal an Egg, and only once): grab a toy, bring it home, hatch
-- it, done. A line from you and an arrow show the way. After that the banner stays hidden.
type Pointer = { beam: Beam, from: Attachment, to: Attachment, arrow: BillboardGui }
local pointer: Pointer? = nil
local function point(target: BasePart?)
	local root = me.Character and me.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not target or not root then
		if pointer then
			pointer.beam:Destroy()
			pointer.from:Destroy()
			pointer.to:Destroy()
			pointer.arrow:Destroy()
			pointer = nil
		end
		return
	end
	if not pointer or pointer.from.Parent ~= root then
		point(nil)
		local from = Instance.new("Attachment")
		from.Name = "TutorialFrom"
		from.Position = Vector3.new(0, -2.6, 0)
		from.Parent = root
		local to = Instance.new("Attachment")
		to.Name = "TutorialTo"
		local beam = Instance.new("Beam")
		beam.Attachment0, beam.Attachment1 = from, to
		beam.Color = ColorSequence.new(UIKit.Yellow)
		beam.Width0, beam.Width1 = 1.2, 1.2
		beam.FaceCamera = true
		beam.LightEmission = 1
		beam.Transparency = NumberSequence.new(0.25)
		beam.Segments = 2
		beam.Parent = root
		local arrow = Instance.new("BillboardGui")
		arrow.Name = "TutorialArrow"
		arrow.Size = UDim2.fromOffset(60, 60)
		arrow.StudsOffsetWorldSpace = Vector3.new(0, 10, 0)
		arrow.AlwaysOnTop = true
		arrow.LightInfluence = 0
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.Text = "▼"
		t.TextScaled = true
		t.Font = Enum.Font.GothamBlack
		t.TextColor3 = UIKit.Yellow
		local s = Instance.new("UIStroke")
		s.Thickness = 3
		s.Color = UIKit.Ink
		s.Parent = t
		t.Parent = arrow
		arrow.Parent = me:WaitForChild("PlayerGui")
		pointer = { beam = beam, from = from, to = to, arrow = arrow }
	end
	local p = pointer :: Pointer
	if p.to.Parent ~= target then
		p.to.Parent = target
	end
	p.arrow.Adornee = target
end

-- What the tutorial says now, and what it points at
local function tutorialStep(): (string?, BasePart?)
	if not profile or profile.Tutorial == 1 then
		return nil, nil
	end
	local home = myHome()
	if me:GetAttribute("Carrying") then
		local sign = home and home:FindFirstChild("Sign") :: BasePart?
		return "Bring it home!", sign
	end
	local waking = home and home:FindFirstChild("Waking")
	if waking and #waking:GetChildren() > 0 then
		for _, b in waking:GetChildren() do
			if b:IsA("Model") and b:GetAttribute("Ready") then
				return "Hold E on your blanket to hatch it!", b.PrimaryPart
			end
		end
		local b = waking:GetChildren()[1] :: Model
		return "Your toy is waking up...", b.PrimaryPart
	end
	if #profile.Toys == 0 then
		-- the nearest sleeping toy
		local root = me.Character and me.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local bedroom = Workspace:FindFirstChild("Bedroom")
		local sleeping = bedroom and bedroom:FindFirstChild("SleepingToys")
		local best, bestDistance = nil, math.huge
		if root and sleeping then
			for _, s in sleeping:GetChildren() do
				if s:IsA("Model") and s.PrimaryPart and s:GetAttribute("Spawn") then
					local d = (s.PrimaryPart.Position - root.Position).Magnitude
					if d < bestDistance then
						best, bestDistance = s.PrimaryPart, d
					end
				end
			end
		end
		return "Grab a sleeping toy!", best
	end
	return "Your toys make cash every second!", nil
end

function GameUI.start(ctx: Ctx)
	hudRef = ctx.hud
	local hud = ctx.hud
	-- the hotbar: your inventory toys, to hold and show off (Hotbar.luau)
	local Hotbar = require(script.Parent:WaitForChild("Hotbar")) :: any
	Hotbar.start(ctx)
	type View = { panel: UIKit.Panel, draw: () -> (), sig: (() -> string)?, last: string? }
	local views: { View } = {}
	for _, build in { buildUpgrades, buildToys, buildIndex, buildDaily, buildPlaytime } :: { any } do
		local panel, draw, sig = build(ctx)
		table.insert(views, { panel = panel, draw = draw, sig = sig })
	end
	local function redraw(v: View)
		v.last = if v.sig then v.sig() else nil
		v.draw()
	end
	-- live: once a second, redraw a panel whose state changed, otherwise just tick its countdowns
	local function live()
		for _, v in views do
			if not v.panel.root.Visible then
				continue
			end
			if v.sig and v.sig() ~= v.last then
				redraw(v)
			else
				for _, part in { v.panel.body, v.panel.header } do
					for _, fn in tickers[part] or {} do
						fn()
					end
				end
			end
		end
	end
	-- draw a panel fresh each time it opens
	for _, v in views do
		v.panel.root:GetPropertyChangedSignal("Visible"):Connect(function()
			if v.panel.root.Visible then
				redraw(v)
			end
		end)
	end
	(remotes:WaitForChild("Data") :: RemoteEvent).OnClientEvent:Connect(function(p: any, m: any)
		profile = p
		meta = m or {}
		for _, v in views do
			if v.panel.root.Visible then
				redraw(v)
			end
		end
		if hud.blankets then
			drawBlankets(hud.blankets)
		end
		Hotbar.update(p)
	end);
	(remotes:WaitForChild("Reveal") :: RemoteEvent).OnClientEvent:Connect(function(info: any)
		VFX.afterHatch(function() -- after the hatch charge-up and burst (VFX), if there is one
			showReveal(ctx, info)
		end)
	end)
	-- the Index stand in your home opens the Index
	game:GetService("ProximityPromptService").PromptTriggered:Connect(function(prompt)
		if prompt.Name == "IndexPrompt" then
			ctx.open("Index")
		end
	end)

	-- cash, $/s and speed
	local shown = attr("Cash")
	hud.cash.Text = GameConfig.money(shown)
	local function rate()
		local income = attr("Income")
		local boosted = attr("BoostUntil") > Workspace:GetServerTimeNow()
		hud.rate.Text = "+" .. GameConfig.money(income) .. "/s" .. (if boosted then " (x2)" else "")
		hud.rate.Visible = income > 0
	end
	me:GetAttributeChangedSignal("Cash"):Connect(function()
		local cash = attr("Cash")
		local delta = cash - shown
		UIKit.countTo(hud.cash, shown, cash, 0.6, GameConfig.money)
		-- the counter bounces: a nudge for the per-second tick, a real boing for a big payout
		local income = math.max(1, attr("Income"))
		VFX.uiPop(hud.cash, if delta > income * 4 then 0.25 elseif delta > 0 then 0.06 else 0)
		shown = cash
		if delta > 0 then
			UIKit.floatUp(
				hud.statsGroup,
				"+" .. GameConfig.money(delta),
				28,
				UIKit.CashGreen,
				UDim2.fromOffset(150, 50),
				UIKit.Fonts.number
			)
		end
	end)
	me:GetAttributeChangedSignal("Income"):Connect(rate)
	me:GetAttributeChangedSignal("BoostUntil"):Connect(rate)
	rate()
	local function speed()
		hud.speed.Text = GameConfig.speedText(attr("Speed"))
	end
	me:GetAttributeChangedSignal("Speed"):Connect(speed)
	speed()
	hud.mult.Visible = false
	hud.zone.Visible = false
	me:GetAttributeChangedSignal("Training"):Connect(function()
		hud.setTraining(me:GetAttribute("Training") == true)
	end)

	-- the tutorial banner, badges, blankets and the live panels, once a second
	local band = hud.quest.Parent :: GuiObject
	local lastQuest = ""
	local doneAt: number? = nil
	task.spawn(function()
		while ctx.gui.Parent do
			local q, target = tutorialStep()
			band.Visible = q ~= nil
			if q and q ~= lastQuest then
				hud.quest.Text = q
				UIKit.bump(hud.quest)
				lastQuest = q
			end
			point(target)
			-- the last step shows for a few seconds, then the tutorial is done for good
			if q == "Your toys make cash every second!" then
				doneAt = doneAt or os.clock()
				if os.clock() - (doneAt :: number) > 5 and profile then
					profile.Tutorial = 1
					call("Claim", "Tutorial")
				end
			end
			live()
			local daily, playtime = readyRewards()
			setBadge(hud.dailyBadge, daily)
			setBadge(hud.playtimeBadge, playtime)
			if hud.blankets then
				drawBlankets(hud.blankets)
			end
			task.wait(1)
		end
	end)
end

return GameUI
