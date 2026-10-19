--!strict
-- Builds the Tiny Toy Heist UI in the Break and Steal an Egg style: the HUD plus the Shop, Daily Rewards, Playtime Rewards,
-- Settings and Your Toys panels. Numbers are placeholders until the game systems exist; the layout matches the
-- Figma page "In-game UI (Steal An Egg style)" at a 1280 x 720 reference size.
local Players = game:GetService("Players")

local UIKit = require(script.Parent:WaitForChild("UIKit"))
local P = UIKit.Palettes
local img, toy, hex = UIKit.image, UIKit.toy, UIKit.hex

local gui = UIKit.new("ScreenGui", {
	Name = "TinyToyHeistUI",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, Players.LocalPlayer:WaitForChild("PlayerGui"))
-- Keep everything clear of phone notches and rounded corners (the top bar is handled by the layout).
gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets

local function group(name: string, anchor: Vector2, position: UDim2, size: Vector2): Frame
	local g = UIKit.new("Frame", {
		Name = name,
		BackgroundTransparency = 1,
		AnchorPoint = anchor,
		Position = position,
		Size = UDim2.fromOffset(size.X, size.Y),
	}, gui)
	UIKit.fit(g)
	return g
end

local function list(parent: Instance, padding: number, align: Enum.HorizontalAlignment?)
	UIKit.new("UIListLayout", {
		Padding = UDim.new(0, padding),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
	}, parent)
end

-- A clipping layer inside a face, so spinning rays stay inside rounded tiles.
local function clip(face: Frame, radius: number): CanvasGroup
	local c = UIKit.new("CanvasGroup", {
		Name = "Clip",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
	}, face)
	UIKit.corner(c, radius)
	return c
end

local center = UDim2.fromScale(0.5, 0.5)
local mid = Vector2.new(0.5, 0.5)

---------------------------------------------------------------------------------------------------------------------
-- Panels (built first so the HUD buttons can open them).
local panels: { [string]: UIKit.Panel } = {}
local function open(name: string)
	for key, p in panels do
		if key == name and not p.root.Visible then
			UIKit.openPanel(p)
		else
			UIKit.closePanel(p)
		end
	end
end

-- Shop: a scrolling list like Break and Steal an Egg's: Featured, Game Passes, Speed Packs and Cash Packs.
do
	local p = UIKit.panel(gui, "Shop", P.lime, Vector2.new(760, 540))
	panels.Shop = p
	local scroll = UIKit.new("ScrollingFrame", {
		Name = "Scroll",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -16, 1, -80),
		Position = UDim2.fromOffset(8, 72),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = hex("8A8A96"),
		ZIndex = 4,
	}, p.body)
	UIKit.new("UIListLayout", {
		Padding = UDim.new(0, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	}, scroll)
	UIKit.new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 16) }, scroll)

	-- Small gift button + green Robux price button, used on every card.
	local function buyRow(
		parent: Instance,
		price: string,
		position: UDim2,
		width: number,
		palette: UIKit.Palette?
	): { Frame }
		local giftHolder, giftFace = UIKit.block(parent, {
			name = "Gift",
			size = UDim2.fromOffset(44, 44),
			position = position,
			palette = P.purple,
		})
		UIKit.icon(giftFace, img("Gift"), 30, center, mid)
		UIKit.clickable(giftHolder)
		local priceHolder = UIKit.button(parent, price, {
			palette = palette or P.green,
			icon = img("Robux3"),
			size = UDim2.fromOffset(width - 50, 44),
			position = position + UDim2.fromOffset(50, 0),
			textSize = 28,
			iconSize = 31,
			iconGap = 2,
		})
		return { giftHolder, priceHolder }
	end

	-- Featured: built like Break and Steal an Egg's featured egg. A painted night-bedroom background, a gold ornate
	-- frame, a big glowing mystery blanket spilling out of the top-left corner, a gold serif title, odds tiles that
	-- grow with rarity, and price buttons with their labels tucked into the bottom edge.
	local jump: { [string]: GuiObject } = {}
	jump.Featured = UIKit.section(scroll, "Featured", nil, 1)
	local card = UIKit.new("Frame", {
		Name = "Mystery Blanket",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(712, 344),
		LayoutOrder = 2,
	}, scroll)
	local art = UIKit.new("ImageLabel", {
		Name = "Art",
		BackgroundTransparency = 1,
		Image = img("Featured_bg"),
		ScaleType = Enum.ScaleType.Crop,
		Size = UDim2.new(1, -16, 1, -16),
		Position = UDim2.fromOffset(8, 8),
		ZIndex = 1,
	}, card)
	UIKit.corner(art, 6)
	UIKit.new("ImageLabel", {
		Name = "Frame",
		BackgroundTransparency = 1,
		Image = img("Featured_frame"),
		ScaleType = Enum.ScaleType.Stretch,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 7,
	}, card)
	local hero = UIKit.new("ImageLabel", {
		Name = "Hero",
		BackgroundTransparency = 1,
		Image = img("Featured_hero"),
		Size = UDim2.fromOffset(230, 230),
		Position = UDim2.fromOffset(-14, 8),
		ZIndex = 8,
	}, card)
	UIKit.bob(hero, 5, 1.2)
	local newTag = UIKit.new("Frame", {
		Name = "New",
		BackgroundColor3 = hex("E8202E"),
		Size = UDim2.fromOffset(84, 34),
		Position = UDim2.fromOffset(18, 22),
		Rotation = -6,
		ZIndex = 12,
	}, card)
	UIKit.corner(newTag, 4)
	UIKit.stroke(newTag, hex("2A0306"), 3, true)
	UIKit.text(newTag, "NEW!", 20, { position = center, anchor = mid, z = 13 })
	UIKit.pulse(newTag, 0.08, 0.6)
	-- gold serif title with a hard dark shadow
	local serif = Font.new("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Heavy)
	for _, layer in { { hex("2A1600"), 4 }, { UIKit.White, 0 } } do
		local t = UIKit.text(card, "MYSTERY BLANKET", 34, {
			font = serif,
			color = layer[1],
			stroke = 3,
			position = UDim2.fromOffset(196, 24 + layer[2]),
			align = Enum.TextXAlignment.Left,
			z = if layer[2] > 0 then 9 else 10,
		})
		local s = t:FindFirstChildOfClass("UIStroke")
		if s then
			s.Color = hex("2A1600")
		end
		if layer[2] == 0 then
			UIKit.new("UIGradient", {
				Rotation = 90,
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, hex("FFF3A8")),
					ColorSequenceKeypoint.new(0.5, hex("F2B533")),
					ColorSequenceKeypoint.new(1, hex("B9741A")),
				}),
			}, t)
		end
	end
	UIKit.text(card, "Limited Time!", 20, { position = UDim2.fromOffset(198, 66), z = 10 })
	UIKit.text(card, "5d 10h 46m 46s", 20, { position = UDim2.new(1, -30, 0, 30), anchor = Vector2.new(1, 0), z = 10 })
	-- odds tiles: small for common, big for rare, bottoms lined up, sitting over the art (and the hero's hem)
	local odds = {
		{ "Common", "45%", "duck", 72 },
		{ "Uncommon", "30%", "frog", 80 },
		{ "Rare", "15%", "jack", 90 },
		{ "Epic", "7%", "robodino", 100 },
		{ "Legendary", "2.5%", "cosmicteddy", 112 },
		{ "Mythic", "0.5%", "kingduck", 126 },
	}
	local x = 712 - 26
	for i = #odds, 1, -1 do
		x -= odds[i][4]
		odds[i][5] = x
		x -= 8
	end
	for _, o in odds do
		local px = o[4]
		local big = o[1] == "Mythic"
		local holder, t = UIKit.tile(card, {
			name = o[1],
			size = UDim2.fromOffset(px, px),
			position = UDim2.fromOffset(o[5], 240 - px),
			top = hex("2A1A4A"),
			bottom = hex("100822"),
			edge = UIKit.Rarity[o[1]],
			edgeWidth = if big then 4 else 3,
		})
		holder.ZIndex = 9
		t.BackgroundTransparency = 0.12
		if big then
			local stroke = t:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Color = UIKit.White
				UIKit.new("UIGradient", {
					Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, hex("FF4D5E")),
						ColorSequenceKeypoint.new(0.25, hex("FFD43B")),
						ColorSequenceKeypoint.new(0.5, hex("5BE36A")),
						ColorSequenceKeypoint.new(0.75, hex("3DA5FF")),
						ColorSequenceKeypoint.new(1, hex("B45CFF")),
					}),
					Rotation = 45,
				}, stroke)
			end
			UIKit.burst(clip(t, 4), center, 200, 0.18)
		else
			UIKit.backing(t, UDim2.fromScale(0.5, 0.46), px * 1.05, 0.3)
		end
		local pic = UIKit.icon(t, toy(o[3]), math.floor(px * 0.8), UDim2.fromScale(0.5, 0.46), mid)
		UIKit.hoverWiggle(t, pic)
		if big then
			UIKit.pulse(pic, 0.06, 0.9)
		end
		UIKit.text(t, o[2], if px >= 110 then 22 else 17, {
			color = if px >= 110 then UIKit.Yellow else UIKit.White,
			position = UDim2.new(1, -5, 1, -3),
			anchor = Vector2.new(1, 1),
		})
	end
	-- price row: gift + green price, label tucked into the bottom edge of the price button
	for i, buy in { { "3,499", "50 Toys" }, { "799", "10 Toys" }, { "249", "3 Toys" }, { "99", "1 Toy" } } do
		local gx = 24 + (i - 1) * 168 -- 4 groups of 160 + 8 gaps = 664, inside the gold frame
		for _, h in buyRow(card, buy[1], UDim2.fromOffset(gx, 252), 160) do
			h.ZIndex = 10
		end
		UIKit.text(card, buy[2], 15, {
			stroke = 2.5,
			position = UDim2.fromOffset(gx + 105, 302),
			anchor = Vector2.new(0.5, 0),
			z = 12,
		})
	end

	-- Game passes, like Break and Steal an Egg: a colour card with rays bursting from behind a big detailed gold coin
	-- badge, a bold title, a two-line description with the "2x" in green, and a wide lime price button. VIP is the
	-- special one: a rainbow card centred on its own row.
	jump.Passes = UIKit.section(scroll, "Game Passes", nil, 3)
	local passes = UIKit.new("Frame", {
		Name = "Game Passes",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(712, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 4,
	}, scroll)
	UIKit.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(350, 190),
		CellPadding = UDim2.fromOffset(12, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	}, passes)
	local green = '<font color="#5BF25A">2x</font>'
	local passList = {
		{ "x2 Speed", "Run " .. green .. " faster!", "PassSpeed3", "299", "Speed", "1250C8" },
		{ "x2 Cash", "Earn " .. green .. " money!", "PassCash3", "499", "Cash", "B8600A" },
		{ "x2 Luck", "Rarer toys under the blankets!", "PassLuck3", "399", "Luck", "17702A" },
		{ "VIP", "Chat tag and " .. green .. " offline cash!", "PassVIP3", "799", "VIP", "5418B8" },
	}
	for i, ps in passList do
		local cardFrame = UIKit.new("Frame", {
			Name = ps[1],
			BackgroundColor3 = UIKit.Ink,
			LayoutOrder = i,
		}, passes)
		UIKit.corner(cardFrame, 6)
		UIKit.stroke(cardFrame, hex("141018"), 4, true)
		local bg = UIKit.new("ImageLabel", {
			Name = "Background",
			BackgroundTransparency = 1,
			Image = img("PassCard_" .. ps[5]),
			ScaleType = Enum.ScaleType.Crop,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 1,
		}, cardFrame)
		UIKit.corner(bg, 6)
		-- a light inner edge so the card looks like a raised tile
		local rim = UIKit.new("Frame", {
			Name = "Rim",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -6, 1, -6),
			Position = UDim2.fromOffset(3, 3),
			ZIndex = 2,
		}, cardFrame)
		UIKit.corner(rim, 4)
		UIKit.new("UIStroke", { Color = UIKit.White, Transparency = 0.55, Thickness = 2 }, rim)
		local badge = UIKit.icon(cardFrame, img(ps[3]), 158, UDim2.fromOffset(84, 92), mid, 5)
		UIKit.hoverWiggle(cardFrame, badge)
		UIKit.pulse(badge, 0.04, 1.2 + i * 0.1)
		local title = UIKit.shadowText(cardFrame, ps[1], 32)
		title.AnchorPoint = Vector2.new(0.5, 0)
		title.Position = UDim2.fromOffset(258, 14)
		local d = UIKit.text(cardFrame, ps[2], 21, {
			position = UDim2.fromOffset(258, 56),
			anchor = Vector2.new(0.5, 0),
			size = UDim2.fromOffset(176, 52),
			stroke = 3,
			z = 6,
		})
		d.RichText = true
		d.TextWrapped = true
		d.TextYAlignment = Enum.TextYAlignment.Center
		local dStroke = d:FindFirstChildOfClass("UIStroke")
		if dStroke then
			dStroke.Color = hex(ps[6]):Lerp(Color3.new(0, 0, 0), 0.55)
		end
		for _, h in buyRow(cardFrame, ps[4], UDim2.fromOffset(160, 126), 182, P.lime) do
			h.ZIndex = 6
		end
	end

	-- Speed and cash packs, like Break and Steal an Egg: a bright card with rays, a big detailed picture (winged
	-- sneakers or banded cash, piling up, then a sack and a treasure chest for the big ones), the amount with the
	-- number in green, and a lime price button. The two biggest packs get wide cards on their own row.
	local function packCard(parent: Instance, pk: { any }, width: number, cardKind: string, layoutOrder: number)
		local cardFrame = UIKit.new("Frame", {
			Name = pk[1],
			BackgroundColor3 = UIKit.Ink,
			Size = UDim2.fromOffset(width, 210),
			LayoutOrder = layoutOrder,
		}, parent)
		UIKit.corner(cardFrame, 6)
		UIKit.stroke(cardFrame, UIKit.Ink, 4, true)
		local bg = UIKit.new("ImageLabel", {
			Name = "Background",
			BackgroundTransparency = 1,
			Image = img("PassCard_" .. cardKind),
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
		UIKit.new("UIStroke", { Color = UIKit.White, Transparency = 0.55, Thickness = 2 }, rim)
		local pic = UIKit.icon(cardFrame, img(pk[2] .. "v2"), 0, UDim2.fromOffset(width / 2, 74), mid, 5)
		pic.Size = if width > 300 then UDim2.fromOffset(240, 180) else UDim2.fromOffset(212, 159)
		if width > 300 then
			pic.Position = UDim2.fromOffset(width / 2, 80)
		end
		UIKit.hoverWiggle(cardFrame, pic)
		local amount = UIKit.text(cardFrame, pk[1], 27, {
			position = UDim2.fromOffset(width / 2, 124),
			anchor = Vector2.new(0.5, 0),
			stroke = 3.5,
			z = 6,
		})
		amount.RichText = true
		local priceWidth = math.min(width - 24, 230)
		for _, h in buyRow(cardFrame, pk[3], UDim2.fromOffset((width - priceWidth) / 2, 158), priceWidth, P.lime) do
			h.ZIndex = 6
		end
		if pk[4] then
			local ribbon = UIKit.text(cardFrame, pk[4], 20, {
				color = if pk[4] == "BEST DEAL!" then UIKit.Yellow else hex("8CFF3A"),
				position = UDim2.new(0.5, 0, 0, -14),
				anchor = Vector2.new(0.5, 0),
				stroke = 3.5,
				z = 30,
			})
			UIKit.pulse(ribbon, 0.08, 0.7)
		end
	end
	local function packs(titleText: string, color: Color3, order: number, cardKind: string, items: { { any } })
		jump[titleText] = UIKit.section(scroll, titleText, color, order)
		local small = UIKit.new("Frame", {
			Name = titleText,
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(712, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = order + 1,
		}, scroll)
		UIKit.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(229, 210),
			CellPadding = UDim2.fromOffset(12, 18),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}, small)
		UIKit.new("UIPadding", { PaddingTop = UDim.new(0, 14) }, small)
		local wide = UIKit.new("Frame", {
			Name = titleText .. " (big)",
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(712, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = order + 2,
		}, scroll)
		UIKit.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(350, 210),
			CellPadding = UDim2.fromOffset(12, 18),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}, wide)
		UIKit.new("UIPadding", { PaddingTop = UDim.new(0, 16) }, wide)
		for i, pk in items do
			if i <= 3 then
				packCard(small, pk, 229, cardKind, i)
			else
				packCard(wide, pk, 350, cardKind, i)
			end
		end
	end
	local g = function(s: string): string
		return '<font color="#7CFF5A">' .. s .. "</font>"
	end
	packs("Speed Packs", hex("6AD8FF"), 5, "SpeedPack", {
		{ g("+150K") .. " SPEED", "SpeedPack1", "59" },
		{ g("+1M") .. " SPEED", "SpeedPack2", "199", "BEST SELLING!" },
		{ g("+10M") .. " SPEED", "SpeedPack3", "459" },
		{ g("+50M") .. " SPEED", "SpeedPack4", "999" },
		{ g("+250M") .. " SPEED", "SpeedPack5", "1,999", "BEST DEAL!" },
	})
	packs("Cash Packs", hex("6AF26A"), 8, "CashPack", {
		{ g("+$100K"), "CashPack1", "59" },
		{ g("+$500K"), "CashPack2", "199", "BEST SELLING!" },
		{ g("+$2M"), "CashPack3", "459" },
		{ g("+$20M"), "CashPack4", "999" },
		{ g("+$100M"), "CashPack5", "1,999", "BEST DEAL!" },
	})
	UIKit.text(scroll, "Odds are shown on every random item.", 15, {
		font = UIKit.Fonts.body,
		color = hex("CFCFE0"),
		stroke = 0,
	}).LayoutOrder =
		99

	-- Category tabs down the right side of the panel jump to each section (like the Steal An Egg shops).
	local tabs = UIKit.new("Frame", {
		Name = "Tabs",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(84, 360),
		Position = UDim2.new(1, 10, 0, 70),
	}, p.pop)
	list(tabs, 10, Enum.HorizontalAlignment.Center)
	for i, tab in
		{
			{ "Featured", "Featured", img("Gift"), UIKit.Rarity.Mythic },
			{ "Passes", "Passes", img("Bolt"), UIKit.Yellow },
			{ "Speed", "Speed Packs", img("Shoe"), UIKit.Rarity.Rare },
			{ "Cash", "Cash Packs", img("Cash"), UIKit.CashGreen },
		} :: { { any } }
	do
		local holder = UIKit.new("Frame", {
			Name = tab[1],
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(84, 76),
			LayoutOrder = i,
		}, tabs)
		UIKit.icon(holder, tab[3], 52, UDim2.fromScale(0.5, 0), Vector2.new(0.5, 0))
		UIKit.text(
			holder,
			tab[1],
			17,
			{ color = tab[4], position = UDim2.fromOffset(42, 52), anchor = Vector2.new(0.5, 0) }
		)
		UIKit.clickable(holder, function()
			local target = jump[tab[2]]
			if target then
				local y = target.AbsolutePosition.Y - scroll.AbsolutePosition.Y + scroll.CanvasPosition.Y - 6
				UIKit.tween(scroll, 0.3, { CanvasPosition = Vector2.new(0, math.max(0, y)) })
			end
		end)
	end
end

-- Daily Rewards: a 7-day streak with a big Day 7 jackpot (from @hallodi.roblox).
do
	local p = UIKit.panel(gui, "DAILY REWARDS", P.magenta, Vector2.new(720, 500))
	panels.Daily = p
	local b = p.body
	UIKit.text(p.header, "STREAK 1/7", 20, { position = UDim2.new(1, -240, 0, 6) })
	local bar = UIKit.new("Frame", {
		BackgroundColor3 = hex("5A1450"),
		Size = UDim2.fromOffset(170, 16),
		Position = UDim2.new(1, -240, 0, 38),
		ZIndex = 8,
	}, p.header)
	UIKit.corner(bar, 8)
	UIKit.stroke(bar, UIKit.Ink, 2.5, true)
	local fill =
		UIKit.new("Frame", { BackgroundColor3 = hex("5BE36A"), Size = UDim2.fromScale(1 / 7, 1), ZIndex = 9 }, bar)
	UIKit.corner(fill, 8)
	local days = {
		{ "DAY 1!", "$2,500", img("Cash"), "4FD8F0", "1E8FD0", "CLAIMED" },
		{ "Tomorrow", "3 FLASHLIGHTS", img("Flashlight"), "FF5A5A", "C01828", "12:05:07" },
		{ "Day 3", "$6,000", img("Cash"), "7BEA5A", "2EA82A", "LOCKED" },
		{ "Day 4", "x2 SPEED 10m", img("Bolt"), "C77BFF", "7A2BD0", "LOCKED" },
		{ "Day 5", "3 DECOYS", img("Decoy"), "FF7AD0", "C42A9A", "LOCKED" },
		{ "Day 6", "LUCKY BLANKET", img("Gift"), "FFE45A", "E8A818", "LOCKED" },
	}
	for i = 1, 7 do
		local col = if i <= 4 then i - 1 elseif i == 5 then 0 elseif i == 6 then 1 else 2
		local row = if i <= 4 then 0 else 1
		local jackpot = i == 7
		local w = if jackpot then 334 else 160
		local d = if jackpot then { "Day 7", "JACKPOT!", "", "FFB04A", "F06A12", "LOCKED" } else days[i]
		local _, t = UIKit.tile(b, {
			name = "Day " .. i,
			size = UDim2.fromOffset(w, 180),
			position = UDim2.fromOffset(16 + col * 172, 78 + row * 192),
			top = hex(d[4]),
			bottom = hex(d[5]),
		})
		if i == 1 or jackpot then
			UIKit.burst(clip(t, 6), UDim2.new(0.5, 0, 0, 90), if jackpot then 320 else 200, 0.28)
		end
		if i == 1 then
			UIKit.text(
				t,
				"DAY 1!",
				28,
				{ color = UIKit.Yellow, position = UDim2.new(0.5, 0, 0, 6), anchor = Vector2.new(0.5, 0) }
			)
			UIKit.sparkle(t, UDim2.fromOffset(22, 50), 18)
			UIKit.sparkle(t, UDim2.fromOffset(140, 64), 14)
		else
			UIKit.text(t, d[1], 14, { stroke = 2, position = UDim2.new(0.5, 0, 0, 6), anchor = Vector2.new(0.5, 0) })
			UIKit.text(
				t,
				d[2],
				if jackpot then 26 else 18,
				{ position = UDim2.new(0.5, 0, 0, 24), anchor = Vector2.new(0.5, 0) }
			)
		end
		if jackpot then
			local prizes: { { any } } = {
				{ img("Cash"), "$15K", UIKit.CashGreen },
				{ toy("kingduck"), "Mythic toy", UIKit.White },
				{ img("Bolt"), "x3", UIKit.White },
			}
			for k, prize in prizes do
				local x = 62 + (k - 1) * 105
				UIKit.icon(t, prize[1], 58, UDim2.fromOffset(x, 86), mid)
				UIKit.text(
					t,
					prize[2],
					16,
					{ color = prize[3], position = UDim2.fromOffset(x, 114), anchor = Vector2.new(0.5, 0) }
				)
			end
			UIKit.sparkle(t, UDim2.fromOffset(30, 40), 18)
			UIKit.sparkle(t, UDim2.fromOffset(300, 46), 20)
		else
			if i ~= 1 then
				UIKit.backing(t, UDim2.fromOffset(80, 92), 110, 0.35)
			end
			UIKit.hoverWiggle(t, UIKit.icon(t, d[3], 64, UDim2.fromOffset(80, 92), mid))
		end
		local claimed = d[6] == "CLAIMED"
		local _, status = UIKit.block(t, {
			name = "Status",
			size = UDim2.new(1, -16, 0, 34),
			position = UDim2.new(0, 8, 1, -42),
			color = if claimed then hex("9AA0AE") else hex("D9DCE4"),
			edge = UIKit.Ink,
			radius = 4,
			lip = 0,
			strokeWidth = 3,
		})
		UIKit.text(status, d[6], 18, { position = center, anchor = mid })
	end
	UIKit.text(b, "NEXT REWARD IN 12:05:07", 20, { position = UDim2.new(0.5, 0, 1, -40), anchor = Vector2.new(0.5, 0) })
end

-- Playtime Rewards: ten gifts that unlock the longer you play (from @hallodi.roblox).
do
	local p = UIKit.panel(gui, "PLAYTIME REWARDS", P.orange, Vector2.new(760, 470))
	panels.Playtime = p
	local b = p.body
	UIKit.text(p.header, "CLAIMED 0/10", 18, { position = UDim2.new(1, -240, 0, 6) })
	local bar = UIKit.new("Frame", {
		BackgroundColor3 = hex("7A2A08"),
		Size = UDim2.fromOffset(170, 16),
		Position = UDim2.new(1, -240, 0, 38),
		ZIndex = 8,
	}, p.header)
	UIKit.corner(bar, 8)
	UIKit.stroke(bar, UIKit.Ink, 2.5, true)
	local gifts = {
		{ "1 MIN", "$1,000", img("Cash"), "READY" },
		{ "5 MIN", "x2", img("Flashlight"), "2:30" },
		{ "8 MIN", "$2,000", img("Cash"), "5:30" },
		{ "12 MIN", "x1", img("Decoy"), "9:30" },
		{ "15 MIN", "x3", img("Pencil"), "12:30" },
		{ "20 MIN", "$4,000", img("Cash"), "17:30" },
		{ "25 MIN", "5m", img("Bolt"), "22:30" },
		{ "30 MIN", "x1", img("Gift"), "27:30" },
		{ "40 MIN", "$8,000", img("Cash"), "37:30" },
		{ "50 MIN", "TOY", toy("teddyknight"), "47:30" },
	}
	local colors = {
		{ "5FE0F5", "1E9FD8" },
		{ "FFE45A", "F0A818" },
		{ "FF6A5A", "D02828" },
		{ "D07BFF", "8A2BD8" },
		{ "8BF06A", "2EB82A" },
	}
	for i, g in gifts do
		local c, r = (i - 1) % 5, (i - 1) // 5
		local x, y = 16 + c * 146, 78 + r * 186
		local ready = i == 1
		local _, t = UIKit.tile(b, {
			name = g[1],
			size = UDim2.fromOffset(136, 130),
			position = UDim2.fromOffset(x, y),
			top = hex(colors[c + 1][1]),
			bottom = hex(colors[c + 1][2]),
			edge = if ready then UIKit.Yellow else UIKit.Ink,
		})
		if ready then
			UIKit.burst(clip(t, 6), UDim2.fromOffset(68, 46), 190, 0.32)
			UIKit.sparkle(t, UDim2.fromOffset(18, 22), 16)
		else
			UIKit.backing(t, UDim2.fromOffset(68, 46), 100, 0.35)
		end
		UIKit.hoverWiggle(t, UIKit.icon(t, g[3], 62, UDim2.fromOffset(68, 46), mid))
		UIKit.text(t, g[1], 16, {
			color = if ready then UIKit.White else hex("FF4D5E"),
			stroke = 2.5,
			position = UDim2.fromOffset(68, 78),
			anchor = Vector2.new(0.5, 0),
		})
		UIKit.text(t, g[2], 18, { position = UDim2.new(1, -8, 1, -6), anchor = Vector2.new(1, 1) })
		local _, status = UIKit.block(b, {
			name = "Status",
			size = UDim2.fromOffset(136, 36),
			position = UDim2.fromOffset(x, y + 136),
			palette = if ready then P.green else P.light,
			radius = 4,
			lip = 0,
			strokeWidth = 3,
		})
		UIKit.text(status, if ready then "CLAIM!" else g[4], 18, { position = center, anchor = mid })
	end
	UIKit.text(
		b,
		"PLAYED TODAY 2:29   |   NEXT GIFT IN 2:30",
		20,
		{ position = UDim2.new(0.5, 0, 1, -38), anchor = Vector2.new(0.5, 0) }
	)
end

-- Settings: On / Off toggles (from @turiptoroblox).
do
	local p = UIKit.panel(gui, "Settings", P.blue, Vector2.new(560, 400))
	panels.Settings = p
	local rows: { { any } } = {
		{ "Music", "Background music", true },
		{ "Sound Effects", "Snores, squeaks and steps", true },
		{ "Performance Mode", "Fewer effects for weak devices", false },
		{ "Hide Players", "Hide other players near you", false },
	}
	for i, r in rows do
		local row = UIKit.new("Frame", {
			Name = r[1],
			BackgroundColor3 = hex("1E1B26"),
			BackgroundTransparency = 0.15,
			Size = UDim2.fromOffset(528, 68),
			Position = UDim2.fromOffset(16, 80 + (i - 1) * 78),
			ZIndex = 4,
		}, p.body)
		UIKit.corner(row, 8)
		UIKit.stroke(row, hex("0B0910"), 2.5, true)
		UIKit.text(row, r[1], 22, { position = UDim2.fromOffset(16, 8), align = Enum.TextXAlignment.Left })
		UIKit.text(row, r[2], 14, {
			font = UIKit.Fonts.body,
			color = hex("BDB8D0"),
			stroke = 0,
			position = UDim2.fromOffset(16, 40),
			align = Enum.TextXAlignment.Left,
		})
		local on = r[3] :: boolean
		local toggle: Frame? = nil
		local function draw()
			if toggle then
				toggle:Destroy()
			end
			toggle = UIKit.button(row, if on then "ON" else "OFF", {
				palette = if on then P.green else P.red,
				size = UDim2.fromOffset(96, 44),
				position = UDim2.new(1, -12, 0.5, 0),
				anchor = Vector2.new(1, 0.5),
				textSize = 22,
				onClick = function()
					on = not on
					task.defer(draw)
				end,
			})
		end
		draw()
	end
end

-- Your Toys: tabs, a grid with rarity borders and a detail card (like the ZeroDev UI Pack inventory).
do
	local p = UIKit.panel(gui, "Your Toys", P.violet, Vector2.new(860, 520))
	panels.Toys = p
	local b = p.body
	local _, cap = UIKit.block(p.header, {
		name = "Capacity",
		size = UDim2.fromOffset(96, 36),
		position = UDim2.new(1, -70, 0.5, 0),
		anchor = Vector2.new(1, 0.5),
		color = UIKit.Panel,
		edge = UIKit.Ink,
		lip = 0,
		gloss = false,
		strokeWidth = 3,
	})
	UIKit.text(cap, "12/20", 20, { position = center, anchor = mid })
	for i, name in { "All", "Small", "Medium", "Large" } do
		UIKit.button(b, name, {
			palette = if i == 1 then P.cyan else P.grey,
			size = UDim2.fromOffset(110, 40),
			position = UDim2.fromOffset(16 + (i - 1) * 118, 78),
			textSize = 20,
		})
	end
	local owned = {
		{ "cosmicteddy", "Legendary" },
		{ "robodino", "Epic" },
		{ "jack", "Rare" },
		{ "racer", "Rare" },
		{ "bunny", "Uncommon" },
		{ "soldier", "Uncommon" },
		{ "frog", "Uncommon" },
		{ "duck", "Common" },
		{ "sock", "Common" },
		{ "mouse", "Common" },
		{ "chicken", "Common" },
		{ "duck", "Common" },
	}
	for i = 1, 18 do
		local c, r = (i - 1) % 6, (i - 1) // 6
		local item = owned[i]
		local holder, s = UIKit.tile(b, {
			name = "Slot " .. i,
			size = UDim2.fromOffset(82, 82),
			position = UDim2.fromOffset(16 + c * 90, 132 + r * 92),
			top = if item then hex("3A3648") else hex("1E1B26"),
			bottom = if item then hex("2A2636") else hex("16131C"),
			edge = if item then UIKit.Rarity[item[2]] else hex("0B0910"),
		})
		if item then
			UIKit.backing(s, center, 80, 0.3)
			UIKit.hoverWiggle(s, UIKit.icon(s, toy(item[1]), 66, center, mid))
			UIKit.clickable(holder)
		end
		if i == 1 then
			UIKit.stroke(s, UIKit.White, 3, true)
		end
	end
	local _, det = UIKit.tile(b, {
		name = "Detail",
		size = UDim2.fromOffset(284, 424),
		position = UDim2.fromOffset(560, 80),
		top = hex("1E1B26"),
		bottom = hex("15121C"),
	})
	UIKit.burst(clip(det, 6), UDim2.fromOffset(142, 76), 230, 0.22)
	UIKit.hoverWiggle(det, UIKit.icon(det, toy("cosmicteddy"), 150, UDim2.fromOffset(142, 76), mid))
	UIKit.sparkle(det, UDim2.fromOffset(52, 40), 18)
	UIKit.sparkle(det, UDim2.fromOffset(232, 30), 14)
	UIKit.text(det, "Cosmic Teddy", 28, { position = UDim2.fromOffset(142, 150), anchor = Vector2.new(0.5, 0) })
	local tag = UIKit.new("Frame", {
		BackgroundColor3 = UIKit.Yellow,
		Size = UDim2.fromOffset(120, 30),
		Position = UDim2.fromOffset(82, 190),
		ZIndex = 5,
	}, det)
	UIKit.corner(tag, 6)
	UIKit.stroke(tag, hex("6A4A06"), 2.5, true)
	UIKit.text(tag, "Legendary", 17, { stroke = 2, position = center, anchor = mid, z = 6 })
	UIKit.text(det, "$1,500/s", 30, {
		font = UIKit.Fonts.number,
		color = UIKit.CashGreen,
		position = UDim2.fromOffset(142, 228),
		anchor = Vector2.new(0.5, 0),
	})
	UIKit.text(det, "Bedroom set", 15, {
		font = UIKit.Fonts.body,
		color = hex("BDB8D0"),
		stroke = 0,
		position = UDim2.fromOffset(142, 274),
		anchor = Vector2.new(0.5, 0),
	})
	UIKit.button(
		det,
		"Place in hole",
		{ palette = P.green, size = UDim2.fromOffset(252, 50), position = UDim2.fromOffset(16, 300), textSize = 22 }
	)
	UIKit.button(
		det,
		"Sell · $30K",
		{ palette = P.gold, size = UDim2.fromOffset(252, 50), position = UDim2.fromOffset(16, 360), textSize = 22 }
	)
end

---------------------------------------------------------------------------------------------------------------------
-- HUD, laid out like Break and Steal an Egg.
local hud: { [string]: any } = {}
do
	-- Quest banner across the top: white text on a dark band that fades out at both ends.
	local top = group("Quest", Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 8), Vector2.new(560, 120))
	local band = UIKit.new("Frame", {
		Name = "Band",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(560, 46),
	}, top)
	UIKit.new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.2, 0.2),
			NumberSequenceKeypoint.new(0.8, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, band)
	hud.quest = UIKit.text(band, "Grab a sleeping toy", 28, { position = center, anchor = mid, stroke = 3.5 })
	hud.zone = UIKit.text(top, "Recommended: 50 Speed", 20, {
		color = hex("6AD8FF"),
		position = UDim2.new(0.5, 0, 0, 50),
		anchor = Vector2.new(0.5, 0),
	})
	hud.zone.Visible = false
	-- RUN! banner, shown while you carry a toy.
	local runHolder, runFace = UIKit.block(top, {
		name = "RUN",
		size = UDim2.fromOffset(250, 70),
		position = UDim2.new(0.5, 0, 0, 52),
		anchor = Vector2.new(0.5, 0),
		palette = P.red,
		strokeWidth = 4,
	})
	UIKit.text(runFace, "RUN!", 52, { position = center, anchor = mid, stroke = 5 })
	UIKit.pulse(runHolder, 0.07, 0.35) -- the whole block (lip too) zooms in and out from its centre
	runHolder.Visible = false
	hud.run = runHolder

	-- Left menu: Shop, Index, Slow Mode, and the x2 Speed offer.
	local left = group("Menu", Vector2.new(0, 0.5), UDim2.new(0, 14, 0.5, 0), Vector2.new(190, 280))
	list(left, 10)
	local leftList = left:FindFirstChildOfClass("UIListLayout") :: UIListLayout
	leftList.VerticalAlignment = Enum.VerticalAlignment.Center
	local shopButton = UIKit.button(left, "Shop", {
		palette = P.lime,
		icon = img("Cart2"),
		size = UDim2.fromOffset(176, 54),
		layoutOrder = 1,
		onClick = function()
			open("Shop")
		end,
	})
	UIKit.button(left, "Index", {
		palette = P.cyan,
		icon = img("Book"),
		size = UDim2.fromOffset(176, 54),
		layoutOrder = 2,
		onClick = function()
			open("Toys")
		end,
	})
	-- Slow Mode: a slide switch. Off = red with the knob on the left; on = green with the knob on the right.
	local slow = UIKit.new("Frame", {
		Name = "Slow Mode",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		Size = UDim2.fromOffset(176, 38),
		LayoutOrder = 3,
	}, left)
	UIKit.corner(slow, 4)
	UIKit.stroke(slow, UIKit.Ink, 3, true)
	local OFF, ON = hex("E8202E"), hex("3ED83A")
	local track = UIKit.new("Frame", {
		Name = "Switch",
		BackgroundColor3 = OFF,
		Size = UDim2.fromOffset(46, 24),
		Position = UDim2.new(0, 6, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		ZIndex = 3,
	}, slow)
	UIKit.corner(track, 12)
	UIKit.stroke(track, UIKit.Ink, 2.5, true)
	UIKit.new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190)),
	}, track)
	local knob = UIKit.new("Frame", {
		Name = "Knob",
		BackgroundColor3 = UIKit.White,
		Size = UDim2.fromOffset(18, 18),
		Position = UDim2.new(0, 3, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		ZIndex = 4,
	}, track)
	UIKit.corner(knob, 9)
	UIKit.stroke(knob, UIKit.Ink, 2, true)
	UIKit.text(
		slow,
		"Slow Mode",
		18,
		{ position = UDim2.new(0, 60, 0.5, 0), anchor = Vector2.new(0, 0.5), stroke = 2.5 }
	)
	local slowOn = false
	local slowHit = UIKit.clickable(slow, function()
		slowOn = not slowOn
		local info = TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		game:GetService("TweenService")
			:Create(knob, info, {
				Position = if slowOn then UDim2.new(1, -3, 0.5, 0) else UDim2.new(0, 3, 0.5, 0),
				AnchorPoint = if slowOn then Vector2.new(1, 0.5) else Vector2.new(0, 0.5),
			})
			:Play()
		UIKit.tween(track, 0.18, { BackgroundColor3 = if slowOn then ON else OFF })
	end)
	slowHit.Name = "Toggle"

	-- x2 Speed offer (like Break and Steal an Egg's): a rainbow button with a bolt poking out of the top and
	-- "ONLY 3" in green underneath. Only shows while you're training on your hamster wheel (hud.setTraining).
	local promoHolder = UIKit.new("Frame", {
		Name = "x2 Speed",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(176, 110),
		LayoutOrder = 4,
		Visible = false,
	}, left)
	local rainbow = UIKit.new("Frame", {
		Name = "Button",
		BackgroundColor3 = UIKit.White,
		Size = UDim2.new(1, 0, 0, 58),
		Position = UDim2.fromOffset(0, 24),
		ZIndex = 2,
	}, promoHolder)
	UIKit.corner(rainbow, 4)
	UIKit.stroke(rainbow, UIKit.Ink, 4, true)
	UIKit.new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, hex("FF4D8A")),
			ColorSequenceKeypoint.new(0.2, hex("FFB21E")),
			ColorSequenceKeypoint.new(0.4, hex("FFF06A")),
			ColorSequenceKeypoint.new(0.6, hex("5BE36A")),
			ColorSequenceKeypoint.new(0.8, hex("3DC8FF")),
			ColorSequenceKeypoint.new(1, hex("A35CFF")),
		}),
	}, rainbow)
	UIKit.burst(clip(rainbow, 4), UDim2.fromScale(0.5, 0.5), 200, 0.5)
	local promoLabel = UIKit.shadowText(rainbow, "x2 Speed", 30)
	promoLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	promoLabel.Position = UDim2.new(0.5, 0, 0.5, -1)
	local bolt = UIKit.icon(promoHolder, img("Bolt"), 50, UDim2.new(0.5, 0, 0, -6), Vector2.new(0.5, 0), 6)
	bolt.Rotation = -10
	UIKit.bob(bolt, 4, 0.6)
	local only = UIKit.new("Frame", {
		Name = "Only",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 28),
		Position = UDim2.new(0.5, 0, 0, 86),
		AnchorPoint = Vector2.new(0.5, 0),
	}, promoHolder)
	UIKit.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 5),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, only)
	UIKit.text(only, "ONLY", 24, { color = hex("8CFF3A"), stroke = 3.5 }).LayoutOrder = 1
	UIKit.icon(only, img("Robux3"), 26).LayoutOrder = 2
	UIKit.text(only, "3", 24, { color = hex("8CFF3A"), stroke = 3.5 }).LayoutOrder = 3
	UIKit.clickable(promoHolder, function()
		open("Shop")
	end)
	local promoScale = UIKit.animScale(promoHolder)
	function hud.setTraining(on: boolean)
		if on and not promoHolder.Visible then
			promoScale.Scale = 0.4
			promoHolder.Visible = true
			UIKit.tween(promoScale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
		elseif not on and promoHolder.Visible then
			UIKit.tween(promoScale, 0.12, { Scale = 0.4 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In).Completed
				:Once(function()
					promoHolder.Visible = false
				end)
		end
	end

	-- Invite promo: fades in, rocks for a few seconds, fades away, and comes back now and then.
	local invite = group("Invite", Vector2.new(0, 0.5), UDim2.new(0, 236, 0.66, 0), Vector2.new(320, 80))
	local inviteFade = UIKit.new("CanvasGroup", {
		Name = "Fade",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		GroupTransparency = 1,
	}, invite)
	local inviteText = UIKit.text(inviteFade, "INVITE FRIENDS", 30, { color = UIKit.Yellow, stroke = 4 })
	UIKit.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(hex("FFF06A"), hex("FFB21E")) }, inviteText)
	UIKit.text(inviteFade, "Each Friend = +10% Cash", 20, {
		color = UIKit.CashGreen,
		font = UIKit.Fonts.number,
		position = UDim2.fromOffset(10, 40),
		stroke = 3,
	})
	UIKit.wobble(inviteFade, 3, 1.4)
	task.spawn(function()
		task.wait(3)
		while gui.Parent do
			UIKit.tween(inviteFade, 0.5, { GroupTransparency = 0 })
			task.wait(6)
			UIKit.tween(inviteFade, 0.8, { GroupTransparency = 1 })
			task.wait(40)
		end
	end)

	-- Right shortcuts: your toys, daily gift, playtime gifts, settings.
	local right = group("Shortcuts", Vector2.new(1, 0.5), UDim2.new(1, -24, 0.5, 0), Vector2.new(64, 300))
	list(right, 12, Enum.HorizontalAlignment.Right)
	local rightList = right:FindFirstChildOfClass("UIListLayout") :: UIListLayout
	rightList.VerticalAlignment = Enum.VerticalAlignment.Center
	UIKit.square(right, img("ToyChest"), P.red, 60, function()
		open("Toys")
	end).LayoutOrder = 1
	local rewards = UIKit.square(right, img("Gift"), P.orange, 60, function()
		open("Daily")
	end)
	rewards.LayoutOrder = 2
	local badge = UIKit.badge(rewards, "1", UDim2.new(1, -4, 0, 4)) -- top-right corner, clear of the button below
	UIKit.pulse(badge, 0.15, 0.5)
	UIKit.square(right, img("Clock"), P.pink, 60, function()
		open("Playtime")
	end).LayoutOrder = 3
	UIKit.square(right, img("Gear"), P.grey, 60, function()
		open("Settings")
	end).LayoutOrder = 4

	-- Pointer arrow that bobs over the Shop button (Break and Steal an Egg points at what to do next). It lives in
	-- the button, so it always moves with it.
	UIKit.bob(UIKit.icon(shopButton, img("Arrow"), 52, UDim2.fromOffset(64, -48), Vector2.new(0.5, 0), 30), 12, 0.45)

	-- Bottom-left stats: speed and cash, with "+$" pops floating off the cash.
	local statsGroup = group("Stats", Vector2.new(0, 1), UDim2.new(0, 14, 1, -14), Vector2.new(280, 110))
	local stats =
		UIKit.new("Frame", { Name = "Rows", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, statsGroup)
	list(stats, 2)
	local function stat(order: number, icon: string, value: string, color: Color3, iconPx: number, textPx: number)
		local row = UIKit.new("Frame", {
			Name = "Stat",
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.XY,
			LayoutOrder = order,
		}, stats)
		UIKit.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 6),
		}, row)
		local ic = UIKit.icon(row, icon, iconPx)
		local t = UIKit.text(row, value, textPx, { font = UIKit.Fonts.number, color = color, stroke = 3.5 })
		return ic, t
	end
	local shoe = stat(1, img("Shoe"), "10", UIKit.White, 46, 36)
	UIKit.icon(shoe, img("Plus"), 20, UDim2.new(1, -8, 1, -8), nil, 6)
	local _, cashText = stat(2, img("Cash"), "$150", UIKit.CashGreen, 54, 42)
	-- earning rate and speed multiplier sit beside the numbers, like "$147 +$14" and "200 (x2)"
	local rate =
		UIKit.text(cashText.Parent :: Instance, "+$3", 28, { font = UIKit.Fonts.number, color = UIKit.CashGreen })
	rate.LayoutOrder = 5
	local mult = UIKit.text(shoe.Parent :: Instance, "(x2)", 26, { font = UIKit.Fonts.number, color = hex("D9DCE4") })
	mult.LayoutOrder = 5
	hud.cash, hud.statsGroup = cashText, statsGroup

	-- Bottom-right: the Giant's wake meter and timer.
	local wake = group("Wake", Vector2.new(1, 1), UDim2.new(1, -14, 1, -14), Vector2.new(260, 70))
	list(wake, 6, Enum.HorizontalAlignment.Right)
	local meter = UIKit.new("Frame", {
		Name = "Wake meter",
		BackgroundColor3 = UIKit.Panel,
		Size = UDim2.fromOffset(210, 20),
		ClipsDescendants = true,
		LayoutOrder = 1,
	}, wake)
	UIKit.corner(meter, 10)
	UIKit.stroke(meter, UIKit.Ink, 3, true)
	local wakeFill =
		UIKit.new("Frame", { Name = "Fill", BackgroundColor3 = hex("FF9A2E"), Size = UDim2.fromScale(0.38, 1) }, meter)
	UIKit.corner(wakeFill, 10)
	UIKit.shade(wakeFill, hex("FF9A2E"))
	UIKit.new("Frame", {
		Name = "Wakes at 80",
		BackgroundColor3 = hex("E8202E"),
		BorderSizePixel = 0,
		Size = UDim2.new(0, 4, 1, 0),
		Position = UDim2.fromScale(0.8, 0),
	}, meter)
	hud.wakeFill = wakeFill
	local timer = UIKit.new("Frame", {
		Name = "Timer",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.XY,
		LayoutOrder = 2,
	}, wake)
	UIKit.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 6),
	}, timer)
	UIKit.icon(timer, img("Moon"), 42)
	hud.timer = UIKit.text(timer, "wakes in 2m 41s", 26, { font = UIKit.Fonts.number })

	-- Bottom centre: the big red action button (Break and Steal an Egg's "Auto Swing"), above the hotbar.
	local action = group("Action", Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -78), Vector2.new(330, 66))
	local dropHolder = UIKit.button(action, "Drop Toy", {
		palette = P.red,
		size = UDim2.fromOffset(330, 66),
		textSize = 34,
	})
	hud.drop = dropHolder
	hud.notify = group("Notify", Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -160), Vector2.new(600, 40))

	-- Touch screens: the thumbstick sits bottom-left and the jump button bottom-right, so the stats and the wake timer
	-- move to the top corners (below Roblox's top bar) and the action button sits a bit higher.
	UIKit.onLayout(function()
		if UIKit.isTouch() then
			statsGroup.AnchorPoint, statsGroup.Position = Vector2.new(0, 0), UDim2.fromOffset(14, 64)
			wake.AnchorPoint, wake.Position = Vector2.new(1, 0), UDim2.new(1, -14, 0, 64)
			action.Position = UDim2.new(0.5, 0, 1, -24)
		else
			statsGroup.AnchorPoint, statsGroup.Position = Vector2.new(0, 1), UDim2.new(0, 14, 1, -14)
			wake.AnchorPoint, wake.Position = Vector2.new(1, 1), UDim2.new(1, -14, 1, -14)
			action.Position = UDim2.new(0.5, 0, 1, -78)
		end
	end)
end

---------------------------------------------------------------------------------------------------------------------
-- Demo loop (placeholder until the game systems exist): cycles the quest, shows RUN! while "carrying", ticks the
-- cash with "+$" pops and posts notifications, so every animation can be seen in a playtest.
task.spawn(function()
	local cash, earned = 150, 0
	local steps = {
		{ "Carpet Zone", false },
		{ "Grab a sleeping toy", false },
		{ "Drag it to your hole", true },
		{ "Place it in your hole", false },
		{ "Train Speed on your wheel", false },
	}
	local step = 1
	local seconds, wakeIn = 0, 161
	while gui.Parent do
		task.wait(1)
		seconds += 1
		wakeIn = math.max(0, wakeIn - 1)
		hud.timer.Text = string.format("wakes in %dm %02ds", wakeIn // 60, wakeIn % 60)
		UIKit.tween(
			hud.wakeFill,
			1,
			{ Size = UDim2.fromScale(0.38 + 0.004 * seconds % 0.4, 1) },
			Enum.EasingStyle.Linear
		)
		if step <= #steps then
			if seconds % 4 == 0 then
				hud.quest.Text = steps[step][1]
				hud.run.Visible = steps[step][2]
				hud.zone.Visible = step == 1
				hud.setTraining(step == 5)
				UIKit.bump(hud.quest)
				if step == 4 then
					UIKit.floatUp(
						hud.notify,
						"Successfully placed Robot Dino!",
						24,
						UIKit.White,
						UDim2.fromScale(0.5, 1)
					)
				end
				step += 1
			end
		else
			hud.setTraining(false)
			local oldCash, oldEarned = cash, earned
			cash += 3
			earned = math.min(100, earned + 3)
			UIKit.countTo(hud.cash, oldCash, cash, 0.6, function(x)
				return "$" .. math.floor(x + 0.5)
			end)
			UIKit.countTo(hud.quest, oldEarned, earned, 0.6, function(x)
				return string.format("Earn $%d/$100", math.floor(x + 0.5))
			end)
			UIKit.floatUp(hud.statsGroup, "+$3", 32, UIKit.CashGreen, UDim2.fromOffset(300, 100), UIKit.Fonts.number)
			if earned >= 100 then
				step = 1
				earned = 0
			end
		end
	end
end)

UIKit.start()
