--!strict
-- Steal An Egg-style UI pieces for Tiny Toy Heist. Matches the Figma page "In-game UI (Steal An Egg style)" and the
-- vault note Roblox UI.md: small studded blocks with a darker outline and lip, white Fredoka One text with a black
-- outline, heavy italic numbers, and rays + glow + sparkles behind special rewards.
-- Everything is laid out at a 1280 x 720 reference size; each top-level group gets a UIScale (UIKit.fit) so the
-- whole UI keeps its shape on phones, tablets and PCs.
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local UIKit = {}

UIKit.REF = Vector2.new(1280, 720)

-- Local preview images live in Studio's content folder (copied from assets/ui/). Before publishing, upload
-- assets/ui/*.png and replace this prefix with the uploaded rbxassetid:// ids.
local ASSET = "rbxasset://textures/TTH2/" -- bump the folder name when pictures change; Studio caches by path
function UIKit.image(name: string): string
	return ASSET .. name .. ".png"
end
function UIKit.toy(id: string): string
	return ASSET .. "toys/" .. id .. ".png"
end

local function hex(h: string): Color3
	return Color3.fromHex(h)
end
UIKit.hex = hex
UIKit.Ink = hex("141018")
UIKit.Panel = hex("2F2F36") -- neutral charcoal, like Break and Steal an Egg
UIKit.White = Color3.new(1, 1, 1)
UIKit.CashGreen = hex("5BF25A")
UIKit.Yellow = hex("FFD43B")

-- Button colours: face colour and a much darker outline in the same hue.
export type Palette = { face: Color3, edge: Color3 }
local function pal(face: string, edge: string): Palette
	return { face = hex(face), edge = hex(edge) }
end
UIKit.Palettes = {
	green = pal("3ED83A", "0C4A12"),
	lime = pal("8CEB1E", "1F4A06"),
	cyan = pal("2FC9F5", "12306E"),
	red = pal("E8202E", "4E0610"),
	orange = pal("F7922A", "6A3206"),
	purple = pal("B32BE0", "3E0A5E"),
	violet = pal("9B5CFF", "2E1466"),
	blue = pal("3DA5FF", "0B2F66"),
	magenta = pal("E62EC8", "4E0846"),
	gold = pal("FFC21E", "6A4A06"),
	grey = pal("5A5668", "1E1B26"),
	light = pal("D9DCE4", "141018"),
	pink = pal("FF6FC1", "6A0E4A"),
}
UIKit.Rarity = (
	{
		Common = hex("B8BCC6"),
		Uncommon = hex("5BE36A"),
		Rare = hex("3DA5FF"),
		Epic = hex("B45CFF"),
		Legendary = hex("FFD43B"),
		Mythic = hex("FF4D5E"),
	}
) :: { [string]: Color3 }

UIKit.Fonts = {
	-- Montserrat Black, the thick Gotham-style face Break and Steal an Egg uses on "Shop" and "Index"; italic for
	-- cash and speed numbers. (Luckiest Guy, Fredoka One, Builder Sans and Nunito were tried and dropped.)
	label = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy),
	number = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic),
	body = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy),
}

local function lighten(c: Color3, k: number): Color3
	return c:Lerp(Color3.new(1, 1, 1), k)
end
local function darken(c: Color3, k: number): Color3
	return c:Lerp(Color3.new(0, 0, 0), k)
end
UIKit.lighten, UIKit.darken = lighten, darken

-- Create an instance, set its properties, then parent it last.
function UIKit.new(className: string, props: { [string]: any }, parent: Instance?): any
	local inst = Instance.new(className) :: any
	for k, v in props do
		inst[k] = v
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end
local new = UIKit.new

function UIKit.corner(parent: Instance, px: number)
	new("UICorner", { CornerRadius = UDim.new(0, px) }, parent)
end

function UIKit.stroke(parent: Instance, color: Color3, thickness: number, border: boolean?)
	new("UIStroke", {
		Color = color,
		Thickness = thickness,
		LineJoinMode = Enum.LineJoinMode.Round,
		ApplyStrokeMode = if border then Enum.ApplyStrokeMode.Border else Enum.ApplyStrokeMode.Contextual,
	}, parent)
end

-- Vertical shade: lighter at the top, darker at the bottom. UIGradient multiplies with the frame colour, so the
-- frame itself goes white and the gradient carries the real colours.
function UIKit.shade(parent: Instance, face: Color3)
	(parent :: any).BackgroundColor3 = Color3.new(1, 1, 1)
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, lighten(face, 0.35)),
			ColorSequenceKeypoint.new(0.5, face),
			ColorSequenceKeypoint.new(1, darken(face, 0.22)),
		}),
	}, parent)
end

export type TextOptions = {
	color: Color3?,
	font: Font?,
	stroke: number?,
	position: UDim2?,
	anchor: Vector2?,
	align: Enum.TextXAlignment?,
	size: UDim2?,
	z: number?,
	name: string?,
}
-- White text with a black outline that sizes itself to its content.
function UIKit.text(parent: Instance, text: string, textSize: number, o: TextOptions?): TextLabel
	local opts: TextOptions = o or {}
	local label = new("TextLabel", {
		Name = opts.name or "Text",
		BackgroundTransparency = 1,
		Text = text,
		TextSize = textSize,
		FontFace = opts.font or UIKit.Fonts.label,
		TextColor3 = opts.color or UIKit.White,
		AutomaticSize = if opts.size then Enum.AutomaticSize.None else Enum.AutomaticSize.XY,
		Size = opts.size or UDim2.new(),
		Position = opts.position or UDim2.new(),
		AnchorPoint = opts.anchor or Vector2.zero,
		TextXAlignment = opts.align or Enum.TextXAlignment.Center,
		ZIndex = opts.z or 5,
	}, parent)
	if (opts.stroke or 3) > 0 then
		UIKit.stroke(label, UIKit.Ink, opts.stroke or 3)
	end
	return label
end

function UIKit.icon(
	parent: Instance,
	image: string,
	px: number,
	position: UDim2?,
	anchor: Vector2?,
	z: number?
): ImageLabel
	return new("ImageLabel", {
		Name = "Icon",
		BackgroundTransparency = 1,
		Image = image,
		Size = UDim2.fromOffset(px, px),
		Position = position or UDim2.new(),
		AnchorPoint = anchor or Vector2.zero,
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = z or 4,
	}, parent)
end

export type BlockOptions = {
	name: string?,
	size: UDim2,
	position: UDim2?,
	anchor: Vector2?,
	palette: Palette?,
	color: Color3?,
	edge: Color3?,
	radius: number?,
	studs: boolean?,
	gloss: boolean?,
	lip: number?,
	strokeWidth: number?,
	layoutOrder: number?,
}
-- A raised block: a darker lip underneath, a shaded face with a stud texture, a shiny top and a dark outline.
-- Returns the holder (position/size it) and the face (put content in it).
function UIKit.block(parent: Instance, o: BlockOptions): (Frame, Frame)
	local face = o.color or (o.palette and o.palette.face) or UIKit.Panel
	local edge = o.edge or (o.palette and o.palette.edge) or UIKit.Ink
	-- Break and Steal an Egg look: flat blocks with tiny corners, a thin near-black outline and no lip.
	local radius = o.radius or 4
	local lip = o.lip or 0
	local holder = new("Frame", {
		Name = o.name or "Block",
		BackgroundTransparency = 1,
		Size = o.size,
		Position = o.position or UDim2.new(),
		AnchorPoint = o.anchor or Vector2.zero,
		LayoutOrder = o.layoutOrder or 0,
	}, parent)
	if lip > 0 then
		local under = new("Frame", {
			Name = "Lip",
			BackgroundColor3 = darken(edge, 0.15),
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromOffset(0, lip),
			ZIndex = 1,
		}, holder)
		UIKit.corner(under, radius)
	end
	local f = new("Frame", {
		Name = "Face",
		BackgroundColor3 = face,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
		ClipsDescendants = false,
	}, holder)
	UIKit.corner(f, radius)
	UIKit.shade(f, face)
	UIKit.stroke(f, darken(edge, 0.35), o.strokeWidth or 3, true)
	if o.studs == true then -- the stud dots are off by default (taken out of the look on 2026-10-18)
		local studs = new("ImageLabel", {
			Name = "Studs",
			BackgroundTransparency = 1,
			Image = UIKit.image("Studs"),
			ScaleType = Enum.ScaleType.Tile,
			TileSize = UDim2.fromOffset(16, 16),
			Size = UDim2.fromScale(1, 1),
			ZIndex = -2, -- under everything in the face, so it never covers tiles, pictures or text
		}, f)
		UIKit.corner(studs, radius)
	end
	if o.gloss == true then
		local g = new("Frame", {
			Name = "Gloss",
			BackgroundColor3 = UIKit.White,
			Size = UDim2.new(1, -10, 0.38, 0),
			Position = UDim2.fromOffset(5, 4),
			ZIndex = -1,
		}, f)
		UIKit.corner(g, math.max(2, radius - 2))
		new("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.45),
				NumberSequenceKeypoint.new(1, 0.92),
			}),
		}, g)
	end
	return holder, f
end

-- Hover grows a button a little and pressing squashes it (1.05 and 0.94), like the TikTok tutorials.
local function bounce(holder: GuiObject, hit: GuiButton)
	local scale = new("UIScale", { Name = "Bounce" }, holder)
	local info = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local function to(v: number)
		TweenService:Create(scale, info, { Scale = v }):Play()
	end
	hit.MouseEnter:Connect(function()
		to(1.05)
	end)
	hit.MouseLeave:Connect(function()
		to(1)
	end)
	hit.MouseButton1Down:Connect(function()
		to(0.94)
	end)
	hit.MouseButton1Up:Connect(function()
		to(1.05)
	end)
end

-- An invisible button over a block, so the whole block is clickable.
function UIKit.clickable(holder: Frame, onClick: (() -> ())?): TextButton
	local hit = new("TextButton", {
		Name = "Hit",
		BackgroundTransparency = 1,
		Text = "",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 20,
	}, holder)
	bounce(holder, hit)
	if onClick then
		hit.Activated:Connect(onClick)
	end
	return hit
end

export type ButtonOptions = {
	palette: Palette,
	icon: string?,
	iconSize: number?,
	iconGap: number?,
	size: UDim2?,
	position: UDim2?,
	anchor: Vector2?,
	textSize: number?,
	layoutOrder: number?,
	onClick: (() -> ())?,
}
-- Outlined button label. The text box is exactly the
-- text's height, so it sits dead centre in a list row.
function UIKit.shadowText(parent: Instance, text: string, textSize: number, layoutOrder: number?): Frame
	local box = new("Frame", {
		Name = "Label",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, textSize),
		LayoutOrder = layoutOrder or 0,
		ZIndex = 5,
	}, parent)
	-- one white label with a thick outline, the same look as the panel titles (the offset shadow read as doubled)
	for _, layer in { { "Text", UIKit.White, 0, 6 } } do
		local l = new("TextLabel", {
			Name = layer[1],
			BackgroundTransparency = 1,
			Text = text,
			TextSize = textSize,
			FontFace = UIKit.Fonts.label,
			TextColor3 = layer[2],
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromScale(0, 1),
			Position = UDim2.fromOffset(0, layer[3]),
			TextYAlignment = Enum.TextYAlignment.Center,
			ZIndex = layer[4],
		}, box)
		UIKit.stroke(l, UIKit.Ink, 4)
	end
	return box
end

-- Rectangle button: picture on the left, outlined label on the right, with a darker lip underneath and a shine on
-- top so it looks raised, like the Break and Steal an Egg buttons.
function UIKit.button(parent: Instance, label: string, o: ButtonOptions): Frame
	local size = o.size or UDim2.fromOffset(156, 50)
	local holder, face = UIKit.block(parent, {
		name = label,
		size = size,
		position = o.position,
		anchor = o.anchor,
		palette = o.palette,
		layoutOrder = o.layoutOrder,
		lip = 5,
		gloss = true,
	})
	local row = new("Frame", {
		Name = "Row",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 4,
	}, face)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, o.iconGap or 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, row)
	if o.icon then
		-- a big picture, but never taller than the button
		local px = o.iconSize or math.min(46, size.Y.Offset - 8)
		local ic = UIKit.icon(row, o.icon, px)
		ic.LayoutOrder = 1
	end
	UIKit.shadowText(row, label, o.textSize or 28, 2)
	UIKit.clickable(holder, o.onClick)
	return holder
end

-- Hovering the target makes the picture bob and wiggle; it settles back when the mouse leaves.
function UIKit.hoverWiggle(target: GuiObject, pic: GuiObject)
	local basePos, baseRot = pic.Position, pic.Rotation
	local playing: { Tween } = {}
	local function stop()
		for _, t in playing do
			t:Cancel()
		end
		table.clear(playing)
	end
	target.MouseEnter:Connect(function()
		stop()
		pic.Rotation = baseRot - 8
		local bob = TweenService:Create(
			pic,
			TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Position = basePos + UDim2.fromOffset(0, -6) }
		)
		local rock = TweenService:Create(
			pic,
			TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Rotation = baseRot + 8 }
		)
		bob:Play()
		rock:Play()
		table.insert(playing, bob)
		table.insert(playing, rock)
	end)
	target.MouseLeave:Connect(function()
		stop()
		TweenService:Create(pic, TweenInfo.new(0.2, Enum.EasingStyle.Back), {
			Position = basePos,
			Rotation = baseRot,
		}):Play()
	end)
end

-- Small studded square with a picture and no word (the right-edge shortcuts).
function UIKit.square(parent: Instance, image: string, palette: Palette, px: number, onClick: (() -> ())?): Frame
	local holder, face = UIKit.block(
		parent,
		{ name = "Square", size = UDim2.fromOffset(px, px), palette = palette, lip = 5, gloss = true }
	)
	UIKit.hoverWiggle(
		face,
		UIKit.icon(face, image, math.floor(px * 0.86), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	)
	UIKit.clickable(holder, onClick)
	return holder
end

-- A small round badge (notification counts).
function UIKit.badge(parent: Instance, text: string, position: UDim2): Frame
	local b = new("Frame", {
		Name = "Badge",
		BackgroundColor3 = hex("3ED83A"),
		Size = UDim2.fromOffset(26, 26),
		Position = position,
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 30,
	}, parent)
	UIKit.corner(b, 13)
	UIKit.stroke(b, hex("0C4A12"), 3, true)
	UIKit.text(
		b,
		text,
		15,
		{ position = UDim2.fromScale(0.5, 0.5), anchor = Vector2.new(0.5, 0.5), stroke = 2, z = 31 }
	)
	return b
end

-- Rays + glow behind a special reward. Rays spin slowly (registered below).
local spinning: { ImageLabel } = {}
function UIKit.burst(parent: Instance, center: UDim2, px: number, raysOpacity: number?): ImageLabel
	new("ImageLabel", {
		Name = "Glow",
		BackgroundTransparency = 1,
		Image = UIKit.image("Glow"),
		ImageTransparency = 0.62, -- soft: a strong glow washes out the picture in front of it
		Size = UDim2.fromOffset(px * 0.9, px * 0.9),
		Position = center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 2,
	}, parent)
	local rays = new("ImageLabel", {
		Name = "Rays",
		BackgroundTransparency = 1,
		Image = UIKit.image("Rays"),
		ImageTransparency = 1 - (raysOpacity or 0.35),
		Size = UDim2.fromOffset(px, px),
		Position = center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 2,
	}, parent)
	table.insert(spinning, rays)
	return rays
end

function UIKit.sparkle(parent: Instance, position: UDim2, px: number)
	UIKit.icon(parent, UIKit.image("Sparkle"), px, position, Vector2.new(0.5, 0.5), 25).Name = "Sparkle"
end

-- Soft light spot behind an item picture, so the tile colour doesn't crowd it.
function UIKit.backing(parent: Instance, center: UDim2, px: number, opacity: number?)
	new("ImageLabel", {
		Name = "Backing",
		BackgroundTransparency = 1,
		Image = UIKit.image("Glow"),
		ImageTransparency = 1 - (opacity or 0.4),
		Size = UDim2.fromOffset(px, px),
		Position = center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 3,
	}, parent)
end

-- An item tile: a colour block with no stud texture (so pictures stay clean) and a backing spot.
export type TileOptions = {
	name: string?,
	size: UDim2,
	position: UDim2?,
	top: Color3,
	bottom: Color3?,
	edge: Color3?,
	edgeWidth: number?,
	lip: number?,
	layoutOrder: number?,
}
function UIKit.tile(parent: Instance, o: TileOptions): (Frame, Frame)
	local holder, face = UIKit.block(parent, {
		name = o.name,
		size = o.size,
		position = o.position,
		color = o.top,
		edge = o.edge or UIKit.Ink,
		studs = false,
		gloss = false,
		strokeWidth = o.edgeWidth or 4,
		lip = o.lip,
		layoutOrder = o.layoutOrder,
	})
	if o.bottom then
		local shade = face:FindFirstChildOfClass("UIGradient")
		if shade then
			shade:Destroy()
		end
		face.BackgroundColor3 = Color3.new(1, 1, 1)
		new("UIGradient", {
			Rotation = 45,
			Color = ColorSequence.new(o.top, o.bottom),
		}, face)
	end
	return holder, face
end

---------------------------------------------------------------------------------------------------------------------
-- Animation helpers

local function tween(
	inst: Instance,
	seconds: number,
	props: { [string]: any },
	style: Enum.EasingStyle?,
	dir: Enum.EasingDirection?
): Tween
	local t = TweenService:Create(
		inst,
		TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
		props
	)
	t:Play()
	return t
end
UIKit.tween = tween

-- A UIScale used only for animation (separate from the screen-fit scale).
function UIKit.animScale(gui: GuiObject): UIScale
	local existing = gui:FindFirstChild("Anim")
	if existing and existing:IsA("UIScale") then
		return existing
	end
	return new("UIScale", { Name = "Anim" }, gui)
end

-- Gentle repeating pulse (RUN! banner, badges, featured pictures).
-- UIScale grows a thing from its AnchorPoint, so re-pin it at its centre (same spot on screen) to make it zoom in
-- and out from the middle instead of stretching from a corner. Skipped for auto-sized text, which has no fixed size.
local function pinCentre(gui: GuiObject)
	local a = gui.AnchorPoint
	if (a.X == 0.5 and a.Y == 0.5) or gui.AutomaticSize ~= Enum.AutomaticSize.None then
		return
	end
	local s = gui.Size
	gui.Position = gui.Position
		+ UDim2.new(
			s.X.Scale * (0.5 - a.X),
			s.X.Offset * (0.5 - a.X),
			s.Y.Scale * (0.5 - a.Y),
			s.Y.Offset * (0.5 - a.Y)
		)
	gui.AnchorPoint = Vector2.new(0.5, 0.5)
end
UIKit.pinCentre = pinCentre

function UIKit.pulse(gui: GuiObject, amount: number, seconds: number)
	pinCentre(gui)
	local s = UIKit.animScale(gui)
	TweenService:Create(
		s,
		TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Scale = 1 + amount }
	):Play()
end

-- Bob up and down (pointer arrows, promo text).
function UIKit.bob(gui: GuiObject, pixels: number, seconds: number)
	local p = gui.Position
	TweenService:Create(
		gui,
		TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Position = p + UDim2.fromOffset(0, -pixels) }
	):Play()
end

-- Rock side to side (the "INVITE FRIEND" promo).
function UIKit.wobble(gui: GuiObject, degrees: number, seconds: number)
	gui.Rotation = -degrees
	TweenService:Create(
		gui,
		TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Rotation = degrees }
	):Play()
end

-- A quick "boing" when something changes (quest text, counters).
function UIKit.bump(gui: GuiObject)
	pinCentre(gui)
	local s = UIKit.animScale(gui)
	s.Scale = 1.18
	tween(s, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
end

-- Text that floats up and fades away ("+$44", "Successfully placed Cat!").
function UIKit.floatUp(parent: Instance, text: string, textSize: number, color: Color3, position: UDim2, font: Font?)
	local label = UIKit.text(parent, text, textSize, {
		color = color,
		font = font,
		position = position,
		anchor = Vector2.new(0.5, 1),
		z = 40,
	})
	local stroke = label:FindFirstChildOfClass("UIStroke")
	-- rise with a soft ease-out, and only start fading once it has mostly risen
	TweenService:Create(label, TweenInfo.new(1.1, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		Position = position + UDim2.fromOffset(0, -52),
	}):Play()
	local fade = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.5)
	TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
	if stroke then
		TweenService:Create(stroke, fade, { Transparency = 1 }):Play()
	end
	local s = UIKit.animScale(label)
	s.Scale = 0.6
	tween(s, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(1.15, function()
		label:Destroy()
	end)
end

-- Roll a number smoothly instead of jumping (cash, quest counters). Updates every rendered frame.
function UIKit.countTo(label: TextLabel, from: number, to: number, seconds: number, format: (number) -> string)
	local v = Instance.new("NumberValue")
	v.Value = from
	local conn = v.Changed:Connect(function(x: number)
		label.Text = format(x)
	end)
	tween(v, seconds, { Value = to }, Enum.EasingStyle.Quart).Completed:Once(function()
		conn:Disconnect()
		v:Destroy()
		label.Text = format(to)
	end)
end

---------------------------------------------------------------------------------------------------------------------
-- Diagonal shine stripes, like the panel headers in Break and Steal an Egg.
function UIKit.stripes(face: Frame, radius: number)
	local c = new("CanvasGroup", {
		Name = "Stripes",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 1,
	}, face)
	UIKit.corner(c, radius)
	for _, s in { { 0.62, 70 }, { 0.74, 30 }, { 0.82, 14 } } do
		new("Frame", {
			Name = "Stripe",
			BackgroundColor3 = UIKit.White,
			BackgroundTransparency = 0.72,
			BorderSizePixel = 0,
			Size = UDim2.new(0, s[2], 2, 0),
			Position = UDim2.fromScale(s[1], -0.5),
			Rotation = 30,
		}, c)
	end
end

-- "~ Featured ~" style section title: yellow-to-orange text with a black outline.
function UIKit.section(parent: Instance, text: string, color: Color3?, layoutOrder: number?): TextLabel
	local t = UIKit.text(parent, "~ " .. text .. " ~", 30, { stroke = 3.5 })
	t.LayoutOrder = layoutOrder or 0
	local top = color or hex("FFF06A")
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(top, if color then darken(color, 0.25) else hex("FFB21E")),
	}, t)
	return t
end

export type Panel = { root: Frame, pop: Frame, body: Frame, header: Frame, close: Frame }
-- A popup panel: bright striped header with the title and a red X, over a charcoal body.
-- Opens with a quick pop (UIKit.openPanel) and shrinks away when closed.
function UIKit.panel(parent: Instance, title: string, headPalette: Palette, size: Vector2): Panel
	local root = new("Frame", {
		Name = title,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size.X, size.Y),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Visible = false,
		ZIndex = 50, -- panels sit above the HUD
	}, parent)
	UIKit.fit(root, size + Vector2.new(110, 30)) -- room for the side tabs; panels shrink to fit small screens
	local pop = new("Frame", {
		Name = "Pop",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, root)
	UIKit.animScale(pop)
	local _, body = UIKit.block(pop, {
		name = "Body",
		size = UDim2.fromScale(1, 1),
		color = UIKit.Panel,
		edge = UIKit.Ink,
		radius = 8,
		strokeWidth = 4,
	})
	local bodyShade = body:FindFirstChildOfClass("UIGradient")
	if bodyShade then
		bodyShade:Destroy()
	end
	body.BackgroundColor3 = UIKit.Panel -- plain charcoal body (shade turned it white for its gradient)
	local headHolder, head = UIKit.block(body, {
		name = "Header",
		size = UDim2.new(1, 0, 0, 64),
		palette = headPalette,
		radius = 8,
		strokeWidth = 4,
	})
	headHolder.ZIndex = 6
	UIKit.stripes(head, 8)
	UIKit.text(head, title, 34, {
		position = UDim2.new(0, 20, 0.5, 0),
		anchor = Vector2.new(0, 0.5),
		stroke = 4,
		align = Enum.TextXAlignment.Left,
		z = 8,
	})
	local closeHolder, closeFace = UIKit.block(head, {
		name = "Close",
		size = UDim2.fromOffset(46, 46),
		position = UDim2.new(1, -10, 0.5, 0),
		anchor = Vector2.new(1, 0.5),
		palette = UIKit.Palettes.red,
	})
	closeHolder.ZIndex = 9
	UIKit.text(closeFace, "X", 30, { position = UDim2.fromScale(0.5, 0.5), anchor = Vector2.new(0.5, 0.5), z = 10 })
	local panel: Panel = { root = root, pop = pop, body = body, header = head, close = closeHolder }
	UIKit.clickable(closeHolder, function()
		UIKit.closePanel(panel)
	end)
	return panel
end

function UIKit.openPanel(p: Panel)
	local s = UIKit.animScale(p.pop)
	s.Scale = 0.6
	p.root.Visible = true
	tween(s, 0.22, { Scale = 1 }, Enum.EasingStyle.Back)
end

function UIKit.closePanel(p: Panel)
	if not p.root.Visible then
		return
	end
	local s = UIKit.animScale(p.pop)
	tween(s, 0.1, { Scale = 0.6 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In).Completed:Once(function()
		p.root.Visible = false
	end)
end

-- Devices. Phones and tablets with no keyboard get the touch layout (bigger UI, nothing under the thumbstick or
-- jump button). Set workspace attribute TTH_TouchLayout = true in Studio to preview it on a PC.
local UserInputService = game:GetService("UserInputService")
function UIKit.isTouch(): boolean
	return (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled)
		or workspace:GetAttribute("TTH_TouchLayout") == true
end

-- Scale a group drawn at the 1280 x 720 reference to the current screen. On touch screens everything is 20%
-- bigger so fingers can hit it; a group given a fitSize (panels) also shrinks to stay fully on screen.
type Fitted = { scale: UIScale, fitSize: Vector2? }
local scaled: { Fitted } = {}
local function viewSize(): Vector2
	local camera = workspace.CurrentCamera
	return if camera then camera.ViewportSize else UIKit.REF
end
local function screenScale(fitSize: Vector2?): number
	local view = viewSize()
	local s = math.min(view.X / UIKit.REF.X, view.Y / UIKit.REF.Y)
	if UIKit.isTouch() then
		s *= 1.2
	end
	s = math.clamp(s, 0.55, 1.5)
	if fitSize then
		s = math.min(s, (view.X - 24) / fitSize.X, (view.Y - 24) / fitSize.Y)
	end
	return s
end
function UIKit.fit(group: GuiObject, fitSize: Vector2?)
	local s = new("UIScale", { Name = "Fit", Scale = screenScale(fitSize) }, group)
	table.insert(scaled, { scale = s, fitSize = fitSize })
end

local layoutCallbacks: { () -> () } = {}
-- Run a function now and whenever the screen size or device layout changes.
function UIKit.onLayout(fn: () -> ())
	table.insert(layoutCallbacks, fn)
	fn()
end

function UIKit.start()
	local function refresh()
		for _, f in scaled do
			f.scale.Scale = screenScale(f.fitSize)
		end
		for _, fn in layoutCallbacks do
			fn()
		end
	end
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(refresh)
	end
	workspace:GetAttributeChangedSignal("TTH_TouchLayout"):Connect(refresh)
	UserInputService.LastInputTypeChanged:Connect(refresh)
	refresh()
	RunService.RenderStepped:Connect(function(dt)
		for _, r in spinning do
			r.Rotation = (r.Rotation + 20 * dt) % 360
		end
	end)
end

return UIKit
