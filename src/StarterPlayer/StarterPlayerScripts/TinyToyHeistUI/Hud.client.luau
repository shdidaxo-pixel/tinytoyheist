--!strict
-- Builds the Tiny Toy Heist UI in the Break and Steal an Egg style: the HUD plus the Shop, Daily Rewards, Playtime Rewards,
-- Settings and Your Toys panels. Numbers are placeholders until the game systems exist; the layout matches the
-- Figma page "In-game UI (Steal An Egg style)" at a 1280 x 720 reference size.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

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

	-- Small gift button + green Robux price button, used on every card. Like Break and Steal an Egg: the gift is a
	-- plain white present on purple. Optional extras: a taller button with a small label ("50 Toys") tucked into
	-- its bottom edge, and a rainbow face for the biggest deal.
	type BuyExtras = { height: number?, label: string?, rainbow: boolean?, textSize: number? }
	local function buyRow(
		parent: Instance,
		price: string,
		position: UDim2,
		width: number,
		palette: UIKit.Palette?,
		extras: BuyExtras?
	): { Frame }
		local x: BuyExtras = extras or {}
		local h = x.height or 44
		local gw = math.min(h, 44) -- the gift stays a 44 px column even when the price button is taller
		local giftHolder, giftFace = UIKit.block(parent, {
			name = "Gift",
			size = UDim2.fromOffset(gw, h),
			position = position,
			palette = P.purple,
			lip = 5,
			gloss = true,
		})
		UIKit.icon(giftFace, img("GiftWhite"), math.floor(gw * 0.74), center, mid, 4)
		UIKit.clickable(giftHolder)
		local priceHolder = UIKit.button(parent, price, {
			palette = palette or P.green,
			icon = img("Robux3"),
			size = UDim2.fromOffset(width - gw - 6, h),
			position = position + UDim2.fromOffset(gw + 6, 0),
			textSize = x.textSize or 28,
			iconSize = math.floor((x.textSize or 28) * 1.1),
			iconGap = 2,
		})
		local face = priceHolder:FindFirstChild("Face") :: Frame
		if x.label then
			-- price in the top part, the label straddling the bottom edge (half on the button, half below it)
			local row = face:FindFirstChild("Row") :: Frame
			row.Size = UDim2.new(1, 0, 1, -8)
			UIKit.text(face, x.label, 18, {
				font = UIKit.Fonts.body,
				position = UDim2.new(0.5, 0, 1, 3),
				anchor = Vector2.new(0.5, 0.5),
				stroke = 3,
				z = 6,
			})
		end
		if x.rainbow then
			local g = face:FindFirstChildOfClass("UIGradient")
			if g then
				g.Rotation = 0
				g.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, hex("E8202E")),
					ColorSequenceKeypoint.new(0.3, hex("C02BE0")),
					ColorSequenceKeypoint.new(0.55, hex("2F7BF5")),
					ColorSequenceKeypoint.new(0.8, hex("3ED83A")),
					ColorSequenceKeypoint.new(1, hex("FFD21E")),
				})
			end
		end
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
	-- price row: gift + price with its label inside the button's bottom edge; the 50 pack is the rainbow best deal
	for i, buy in { { "3499", "50 Toys" }, { "799", "10 Toys" }, { "249", "3 Toys" }, { "99", "1 Toy" } } do
		local gx = 24 + (i - 1) * 168 -- 4 groups of 160 + 8 gaps = 664, inside the gold frame
		local row = buyRow(
			card,
			buy[1],
			UDim2.fromOffset(gx, 252),
			160,
			nil,
			{ height = 56, label = buy[2], rainbow = i == 1, textSize = 27 }
		)
		for _, h in row do
			h.ZIndex = 10
		end
		-- testing (Studio only, no Robux yet): the button puts that many Large blankets in your home
		local count = ({ 50, 10, 3, 1 } :: { number })[i]
		local hit = row[2]:FindFirstChild("Hit") :: TextButton?
		if hit then
			hit.Activated:Connect(function()
				local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("GameRemotes")
				local claim = remotes and remotes:FindFirstChild("Claim") :: RemoteFunction?
				if claim then
					task.spawn(function()
						claim:InvokeServer("TestBlanket", count)
					end)
				end
			end)
		end
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
	-- "DOUBLE Your Speed": a wide sunny banner above the speed packs, like Break and Steal an Egg's. A big gold bolt
	-- in the ray burst on the left; the title, "x1 > x2" and the price row centred in the space to its right.
	local function doubleBanner(order: number)
		local cardFrame = UIKit.new("Frame", {
			Name = "Double Speed",
			BackgroundColor3 = UIKit.Ink,
			Size = UDim2.fromOffset(712, 160),
			LayoutOrder = order,
		}, scroll)
		UIKit.corner(cardFrame, 6)
		UIKit.stroke(cardFrame, UIKit.Ink, 4, true)
		local bg = UIKit.new("ImageLabel", {
			Name = "Background",
			BackgroundTransparency = 1,
			Image = img("PassCard_Double"),
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
		UIKit.new("UIStroke", { Color = UIKit.White, Transparency = 0.45, Thickness = 2 }, rim)
		local bolt = UIKit.icon(cardFrame, img("BoltBig"), 148, UDim2.fromOffset(96, 80), mid, 5)
		UIKit.hoverWiggle(cardFrame, bolt)
		UIKit.pulse(bolt, 0.04, 1.1)
		local cx = 440 -- centre of the space right of the bolt
		local title = UIKit.text(cardFrame, '<font color="#5BF25A">DOUBLE</font> Your Speed', 36, {
			position = UDim2.fromOffset(cx, 6),
			anchor = Vector2.new(0.5, 0),
			stroke = 4,
			z = 6,
		})
		title.RichText = true
		local row = UIKit.new("Frame", {
			Name = "Multiplier",
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 48),
			Position = UDim2.fromOffset(cx, 52),
			AnchorPoint = Vector2.new(0.5, 0),
			ZIndex = 6,
		}, cardFrame)
		UIKit.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 18),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}, row)
		UIKit.text(row, "x1", 44, { font = UIKit.Fonts.label, stroke = 4, z = 6 }).LayoutOrder = 1
		UIKit.icon(row, img("PlayArrow"), 40, nil, nil, 6).LayoutOrder = 2
		-- fixed-size slot so the green "x2" can pulse from its centre without nudging the row
		local x2Holder = UIKit.new("Frame", {
			Name = "x2",
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(72, 48),
			LayoutOrder = 3,
			ZIndex = 6,
		}, row)
		local x2 = UIKit.text(x2Holder, "x2", 44, {
			font = UIKit.Fonts.label,
			color = hex("5BF25A"),
			stroke = 4,
			position = center,
			anchor = mid,
			z = 6,
		})
		UIKit.pulse(x2, 0.08, 0.8)
		for _, h in buyRow(cardFrame, "3", UDim2.fromOffset(cx - 150, 104), 300, P.lime) do
			h.ZIndex = 6
		end
	end

	local function packs(
		titleText: string,
		color: Color3,
		order: number,
		cardKind: string,
		items: { { any } },
		banner: ((number) -> ())?
	)
		jump[titleText] = UIKit.section(scroll, titleText, color, order)
		if banner then
			banner(order + 1)
		end
		local small = UIKit.new("Frame", {
			Name = titleText,
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(712, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = order + 2,
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
			LayoutOrder = order + 3,
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
	}, doubleBanner)
	packs("Cash Packs", hex("6AF26A"), 9, "CashPack", {
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

	-- Category tabs down the right side of the panel jump to each section (like the Steal An Egg shops). Each is a
	-- chunky colour tile with rays behind a detailed picture and its name tucked into the bottom. The tab for the
	-- section you're looking at grows, lights up with a white ring and gets a bobbing arrow pointing into the shop;
	-- the others dim a little. It follows the scroll, so the tabs double as a "you are here".
	local tabs = UIKit.new("Frame", {
		Name = "Tabs",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(92, 440),
		Position = UDim2.new(1, 14, 0, 74),
	}, p.pop)
	list(tabs, 18, Enum.HorizontalAlignment.Center)
	type Tab = { key: string, tile: Frame, dim: Frame, ring: UIStroke, arrow: ImageLabel }
	local tabList: { Tab } = {}
	-- no resizing: scaling a tile re-draws its ray clip every frame (a flash) and slides the face over its outline,
	-- so the chosen tile slides out toward the shop instead
	local quick = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local current: string? = nil
	local function selectTab(key: string)
		if key == current then
			return
		end
		current = key
		for _, t in tabList do
			local on = t.key == key
			TweenService:Create(t.tile, quick, { Position = UDim2.fromOffset(if on then -8 else 0, 0) }):Play()
			TweenService:Create(t.dim, quick, { BackgroundTransparency = if on then 1 else 0.8 }):Play()
			TweenService:Create(t.ring, quick, { Transparency = if on then 0 else 1 }):Play()
			t.arrow.Visible = on
		end
	end
	for i, tab in
		{
			{ "Featured", "Featured", img("Gift"), P.red, 60 },
			{ "Passes", "Passes", img("BoltBig"), P.gold, 68 },
			{ "Speed", "Speed Packs", img("SpeedPack1v2"), P.blue, 84 },
			{ "Cash", "Cash Packs", img("CashPack1v2"), P.green, 84 },
		} :: { { any } }
	do
		-- a fixed slot in the column, so the tile inside can slide without the list pulling it back
		local slot = UIKit.new("Frame", {
			Name = tab[1],
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(88, 92),
			LayoutOrder = i,
		}, tabs)
		local holder, face = UIKit.block(slot, {
			name = "Tile",
			size = UDim2.fromScale(1, 1),
			palette = tab[4],
			lip = 5,
			gloss = true,
		})
		UIKit.burst(clip(face, 4), UDim2.fromScale(0.5, 0.4), 130, 0.28)
		local pic = UIKit.icon(face, tab[3], tab[5], UDim2.fromScale(0.5, 0.4), mid, 5)
		UIKit.hoverWiggle(face, pic)
		UIKit.text(face, tab[1], 16, {
			position = UDim2.new(0.5, 0, 1, -4),
			anchor = Vector2.new(0.5, 1),
			stroke = 3,
			z = 7,
		})
		local dim = UIKit.new("Frame", {
			Name = "Dim",
			BackgroundColor3 = UIKit.Ink,
			BackgroundTransparency = 0.8,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 8,
		}, face)
		UIKit.corner(dim, 4)
		local ring = UIKit.new("UIStroke", {
			Name = "Ring",
			Color = UIKit.White,
			Thickness = 3,
			Transparency = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}, dim)
		-- the down arrow turned to point left, into the shop
		local arrow = UIKit.icon(holder, img("Arrow"), 30, UDim2.new(0, -20, 0.5, 0), mid, 9)
		arrow.Rotation = 90
		arrow.Visible = false
		TweenService:Create(
			arrow,
			TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Position = UDim2.new(0, -26, 0.5, 0) }
		):Play()
		table.insert(tabList, { key = tab[2], tile = holder, dim = dim, ring = ring, arrow = arrow })
		-- a plain hit area (no hover grow, for the same reason as above); hovering nudges the tile out a little
		local hit = UIKit.new("TextButton", {
			Name = "Hit",
			BackgroundTransparency = 1,
			Text = "",
			Size = UDim2.fromScale(1, 1),
			ZIndex = 20,
		}, slot)
		hit.MouseEnter:Connect(function()
			if current ~= tab[2] then
				TweenService:Create(holder, quick, { Position = UDim2.fromOffset(-4, 0) }):Play()
			end
		end)
		hit.MouseLeave:Connect(function()
			if current ~= tab[2] then
				TweenService:Create(holder, quick, { Position = UDim2.new() }):Play()
			end
		end)
		hit.Activated:Connect(function()
			local target = jump[tab[2]]
			if target then
				selectTab(tab[2])
				local y = target.AbsolutePosition.Y - scroll.AbsolutePosition.Y + scroll.CanvasPosition.Y - 6
				UIKit.tween(scroll, 0.3, { CanvasPosition = Vector2.new(0, math.max(0, y)) })
			end
		end)
	end
	-- follow the scroll: the active tab is the last section whose title has passed the middle of the list
	scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		local top = scroll.AbsolutePosition.Y + scroll.AbsoluteSize.Y * 0.45
		local key = tabList[1].key
		for _, t in tabList do
			local target = jump[t.key]
			if target and target.AbsolutePosition.Y <= top then
				key = t.key
			end
		end
		if scroll.CanvasPosition.Y >= scroll.AbsoluteCanvasSize.Y - scroll.AbsoluteWindowSize.Y - 2 then
			key = tabList[#tabList].key
		end
		selectTab(key)
	end)
	selectTab(tabList[1].key)
end

-- Settings: On / Off toggles (from @turiptoroblox). Each one is a LocalPlayer attribute ("SettingMusic",
-- "SettingSoundEffects", "SettingPerformanceMode", "SettingHidePlayers"); GameView applies Performance Mode and Hide
-- Players, and the sound code reads Music and Sound Effects.
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
		local key = "Setting" .. string.gsub(r[1], " ", "")
		Players.LocalPlayer:SetAttribute(key, on)
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
					Players.LocalPlayer:SetAttribute(key, on)
					task.defer(draw)
				end,
			})
		end
		draw()
	end
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

	-- Left menu: Shop, Index, Upgrades, Slow Mode, and the x2 Speed offer.
	local left = group("Menu", Vector2.new(0, 0.5), UDim2.new(0, 14, 0.5, 0), Vector2.new(190, 360))
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
			open("Index")
		end,
	})
	UIKit.button(left, "Upgrades", {
		palette = P.green,
		icon = img("Bolt"),
		size = UDim2.fromOffset(176, 54),
		textSize = 24,
		layoutOrder = 3,
		onClick = function()
			open("Upgrades")
		end,
	})
	-- Slow Mode: a slide switch. Off = red with the knob on the left; on = green with the knob on the right.
	local slow = UIKit.new("Frame", {
		Name = "Slow Mode",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		Size = UDim2.fromOffset(176, 38),
		LayoutOrder = 4,
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
		-- Slow Mode: walk at half speed and drag toys at half the noise
		local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("GameRemotes")
		local slowRemote = remotes and remotes:FindFirstChild("SlowMode")
		if slowRemote then
			(slowRemote :: RemoteEvent):FireServer(slowOn)
		end
	end)
	slowHit.Name = "Toggle"

	-- x2 Speed offer (like Break and Steal an Egg's): a rainbow button with a bolt poking out of the top and
	-- "ONLY 3" in green underneath. Only shows while you're training on your hamster wheel (hud.setTraining).
	local promoHolder = UIKit.new("Frame", {
		Name = "x2 Speed",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(176, 110),
		LayoutOrder = 5,
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

	-- Top-right: small buttons for your toys, the daily gift, playtime gifts and settings, each with its own badge,
	-- so the right edge is free for your blankets (Dylan, 19 Oct).
	local corner = group("Corner", Vector2.new(1, 0), UDim2.new(1, -14, 0, 64), Vector2.new(220, 52))
	UIKit.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, corner)
	local function cornerButton(name: string, image: string, palette: UIKit.Palette, order: number, panel: string)
		local b = UIKit.square(corner, image, palette, 46, function()
			open(panel)
		end)
		b.Name = name
		b.LayoutOrder = order
		return b
	end
	cornerButton("ToysButton", img("ToyChest"), P.red, 1, "Toys")
	local daily = cornerButton("DailyButton", img("Gift"), P.orange, 2, "Daily")
	local playtime = cornerButton("PlaytimeButton", img("Clock"), P.pink, 3, "Playtime")
	cornerButton("SettingsButton", img("Gear"), P.grey, 4, "Settings")
	hud.dailyBadge = UIKit.badge(daily, "1", UDim2.new(1, -2, 0, 2))
	hud.playtimeBadge = UIKit.badge(playtime, "1", UDim2.new(1, -2, 0, 2))
	hud.dailyBadge.Visible, hud.playtimeBadge.Visible = false, false

	-- Right edge: the blankets waiting in your home (GameUI fills it)
	hud.blankets = group("Blankets", Vector2.new(1, 0.5), UDim2.new(1, -14, 0.5, 0), Vector2.new(200, 320))

	-- Pointer arrow that bobs over the Shop button (Break and Steal an Egg points at what to do next). It lives in
	-- the button, so it always moves with it, and fades away after a little while.
	local shopArrow = UIKit.icon(shopButton, img("Arrow"), 52, UDim2.fromOffset(64, -48), Vector2.new(0.5, 0), 30)
	UIKit.bob(shopArrow, 12, 0.45)
	task.delay(12, function()
		UIKit.tween(shopArrow, 0.6, { ImageTransparency = 1 })
		task.wait(0.6)
		shopArrow.Visible = false
	end)

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
	local shoe, speedText = stat(1, img("Shoe"), "16,000", UIKit.White, 46, 36)
	local _, cashText = stat(2, img("Cash"), "$150", UIKit.CashGreen, 54, 42)
	-- earning rate and speed multiplier sit beside the numbers, like "$147 +$14" and "200 (x2)"
	local rate =
		UIKit.text(cashText.Parent :: Instance, "+$3", 28, { font = UIKit.Fonts.number, color = UIKit.CashGreen })
	rate.LayoutOrder = 5
	local mult = UIKit.text(shoe.Parent :: Instance, "(x2)", 26, { font = UIKit.Fonts.number, color = hex("D9DCE4") })
	mult.LayoutOrder = 5
	hud.cash, hud.statsGroup = cashText, statsGroup
	hud.rate, hud.speed, hud.mult = rate, speedText, mult

	-- Bottom-right: the Giant's wake meter and timer.
	local wake = group("Wake", Vector2.new(1, 1), UDim2.new(1, -14, 1, -14), Vector2.new(260, 70))
	list(wake, 6, Enum.HorizontalAlignment.Right)
	-- a dark track with the fill clipped inside its rounded inner edge, so the fill never pokes out of the bar
	local meter = UIKit.new("Frame", {
		Name = "Wake meter",
		BackgroundColor3 = hex("1E1B26"),
		Size = UDim2.fromOffset(210, 22),
		LayoutOrder = 1,
	}, wake)
	UIKit.corner(meter, 11)
	UIKit.stroke(meter, UIKit.Ink, 3, true)
	local inner = UIKit.new("CanvasGroup", {
		Name = "Inner",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -6, 1, -6),
		Position = UDim2.fromOffset(3, 3),
	}, meter)
	UIKit.corner(inner, 8)
	local wakeFill =
		UIKit.new("Frame", { Name = "Fill", BackgroundColor3 = hex("FF9A2E"), Size = UDim2.fromScale(0, 1) }, inner)
	UIKit.corner(wakeFill, 8)
	UIKit.shade(wakeFill, hex("FF9A2E"))
	UIKit.new("Frame", {
		Name = "Wakes at 80",
		BackgroundColor3 = UIKit.White,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 3, 1, 0),
		Position = UDim2.fromScale(0.8, 0),
		ZIndex = 3,
	}, inner)
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
		onClick = function()
			local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("BedroomRemotes")
			local drop = remotes and remotes:FindFirstChild("DropRequest")
			if drop then
				(drop :: RemoteEvent):FireServer()
			end
		end,
	})
	hud.drop = dropHolder
	hud.action = action
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
-- The Giant's wake meter and timer, and RUN! and the Drop Toy button while you're dragging a toy, from the
-- bedroom's game state (Workspace.Bedroom.GiantKid attributes and the Player's Carrying attribute).
task.spawn(function()
	local Workspace = game:GetService("Workspace")
	local player = Players.LocalPlayer
	local kid: Instance? = nil
	while gui.Parent do
		local bedroom = Workspace:FindFirstChild("Bedroom")
		kid = kid or (bedroom and bedroom:FindFirstChild("GiantKid"))
		local carrying = player:GetAttribute("Carrying") ~= nil
		hud.run.Visible = carrying
		hud.action.Visible = carrying
		if kid then
			local meter = ((kid:GetAttribute("WakeMeter") :: number?) or 0) / 100
			UIKit.tween(hud.wakeFill, 0.25, {
				Size = UDim2.fromScale(math.clamp(meter, 0, 1), 1),
				BackgroundColor3 = if meter >= 0.8 then hex("E8202E") else hex("FF9A2E"),
			}, Enum.EasingStyle.Linear)
			local state = kid:GetAttribute("State")
			local now = Workspace:GetServerTimeNow()
			if state == "Stirring" then
				hud.timer.Text = "HE'S WAKING UP!"
			elseif state == "Awake" then
				local left = math.max(0, math.ceil(((kid:GetAttribute("StateEndsAt") :: number?) or now) - now))
				hud.timer.Text = string.format("awake · sleeps in %ds", left)
			else
				local left = math.max(0, math.ceil(((kid:GetAttribute("WakesAt") :: number?) or now) - now))
				hud.timer.Text = string.format("wakes in %dm %02ds", left // 60, left % 60)
			end
		end
		task.wait(0.25)
	end
end)

-- The game itself: cash, income, the quest, the reveal card and the Upgrades, Your Toys, Index, Daily and Playtime
-- panels (GameUI.luau), from the real game state.
require(script.Parent:WaitForChild("GameUI")).start({ gui = gui, panels = panels, open = open, hud = hud })

UIKit.start()
