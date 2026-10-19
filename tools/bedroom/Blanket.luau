--!strict
-- A sleeping toy's blanket, built from blocks to match the concept renders (design/blanket-test.html, the
-- "hand-sculpted cartoon" option): a tall soft bell with a flared skirt, shallow steps up to a rounded top, drape
-- folds down to the hem, a rolled lip in the trim colour, a pattern, and the shape of the toy poking up under it (a
-- duck's head on Small, bunny ears on Medium, a dino's head and tail on Large). Under 40 parts; nothing collides.
--
--   Blanket.build(Kit, parent, size, at, colour?, pattern?) -> Model
--     size     "S" | "M" | "L" (8, 9.8 and 13.3 studs wide in the world)
--     at       the bottom centre, on the floor (the model's pivot is there too, so model:PivotTo(at) puts it back)
--     colour   1..10, an index into Blanket.COLOURS; nil picks one at random
--     pattern  one of Blanket.PATTERNS; nil picks one (from the colour when one is given)
--   The PrimaryPart is "Lump", an invisible box over the whole blanket: put the grab prompt and the glow tell on it.
--   Attributes on the model: Size, Colour, Pattern.

local Blanket = {}

-- Main colour and trim colour, from the concept render
Blanket.COLOURS = {
	{ 0x4DA8FF, 0xFFFFFF },
	{ 0xFF7AA8, 0xFFFFFF },
	{ 0x3DDC97, 0xFFF6D5 },
	{ 0x9B7BFF, 0xFFE07A },
	{ 0xFF8A3D, 0xFFF1D6 },
	{ 0x2F6FB9, 0xFFD95A },
	{ 0xE04848, 0xFFFFFF },
	{ 0x7FD6E8, 0x2B5F8C },
	{ 0xF2C6E0, 0x9B4D7A },
	{ 0xFFD95A, 0xE04848 },
}
Blanket.PATTERNS = { "plain", "dots", "stars", "checks", "stripe" }

-- Width and height in studs, per size
Blanket.SIZE = {
	S = { width = 8, height = 7.6 },
	M = { width = 9.8, height = 9.4 },
	L = { width = 13.3, height = 12.2 },
}

-- The bell, tier by tier: bottom (x height), height (x height) and half width (x width)
local TIERS = {
	{ 0, 0.1, 0.5 },
	{ 0.1, 0.15, 0.43 },
	{ 0.25, 0.15, 0.39 },
	{ 0.4, 0.14, 0.345 },
	{ 0.54, 0.13, 0.295 },
	{ 0.67, 0.12, 0.235 },
	{ 0.79, 0.09, 0.16 },
}
local CROSS = 0.66 -- each tier is two crossed boxes, w x w*CROSS and w*CROSS x w, so it reads round
local PATTERN_TIERS = { 3, 5 } -- the pattern goes on the four sides of these tiers
local OUTLINE = 0x1A1430

local rng = Random.new()

local function shade(color: Color3, amount: number): Color3
	return if amount >= 0
		then color:Lerp(Color3.new(1, 1, 1), amount)
		else color:Lerp(Color3.fromRGB(26, 20, 48), -amount)
end

function Blanket.build(Kit: any, parent: Instance, size: string, at: CFrame, colour: number?, pattern: string?): Model
	local dims = Blanket.SIZE[size] or Blanket.SIZE.M
	local W, H = dims.width, dims.height
	local index = colour or rng:NextInteger(1, #Blanket.COLOURS)
	local pair = Blanket.COLOURS[(index - 1) % #Blanket.COLOURS + 1]
	local main, trim = Kit.rgb(pair[1]), Kit.rgb(pair[2])
	local kind = pattern
		or (if colour then Blanket.PATTERNS[(index - 1) % #Blanket.PATTERNS + 1] else nil)
		or Blanket.PATTERNS[rng:NextInteger(1, #Blanket.PATTERNS)]
	local model = Kit.model(parent, "SleepingToy", { Size = size, Colour = index, Pattern = kind })
	local soft = { material = Enum.Material.Fabric, collide = false }
	local smooth = { material = Enum.Material.SmoothPlastic, collide = false }

	-- the invisible Lump over the whole blanket (grab prompt, glow tell); the model pivots at its bottom centre
	local lump = Kit.part(model, "Lump", Vector3.new(W * 1.1, H, W * 1.1), at * CFrame.new(0, H / 2, 0), main, {
		transparency = 1,
		shadow = false,
	})
	lump.CanCollide = false
	lump.PivotOffset = CFrame.new(0, -H / 2, 0)

	-- a soft dark shadow under it, so it sits on the carpet
	Kit.disc(model, "Shadow", W * 0.62, 0.05, at * CFrame.new(0, 0.03, 0), OUTLINE, {
		collide = false,
		transparency = 0.45,
		shadow = false,
	})

	-- The bell: the upper tiers lean a little toward the toy's head and twist a little, like cloth over a shape
	local lean = rng:NextNumber(-1, 1) * 0.05 * W
	local tierFrames = {}
	for k, tier in TIERS do
		local y, h, hw = tier[1] * H, tier[2] * H, tier[3] * W
		local t = (k - 1) / (#TIERS - 1)
		local frame = at
			* CFrame.new(lean * t * t, 0, 0)
			* CFrame.Angles(0, if k == 1 then 0 else rng:NextNumber(-0.06, 0.06), 0)
		tierFrames[k] = frame
		local color = shade(main, -0.1 + t * 0.22) -- darker at the hem, lighter on top (toon shading)
		if kind == "stripe" and k == 4 then
			color = trim
		end
		Kit.block(model, "Tier", 2 * hw, h, 2 * hw * CROSS, frame, 0, y, 0, color, soft)
		Kit.block(model, "Tier", 2 * hw * CROSS, h, 2 * hw, frame, 0, y, 0, color, soft)
	end

	-- What's under it, poking up through the top
	local top = (TIERS[#TIERS][1] + TIERS[#TIERS][2]) * H
	local topFrame = tierFrames[#TIERS]
	local bumpColor = shade(main, 0.14)
	if size == "S" then
		-- a duck's head, off to one side
		Kit.block(model, "Bump", 0.24 * W, 0.12 * H, 0.22 * W, topFrame, 0.05 * W, top - 0.03 * H, 0, bumpColor, soft)
	elseif size == "M" then
		-- two bunny ears, leaning apart
		for _, s in { -1, 1 } do
			Kit.part(
				model,
				"Bump",
				Vector3.new(0.11 * W, 0.26 * H, 0.14 * W),
				topFrame * CFrame.new(s * 0.07 * W, top + 0.08 * H, 0) * CFrame.Angles(0, 0, -s * 0.25),
				bumpColor,
				soft
			)
		end
	else
		-- a dino: a head on top and a tail dragging out at the hem
		Kit.block(model, "Bump", 0.22 * W, 0.11 * H, 0.2 * W, topFrame, 0.05 * W, top - 0.03 * H, 0, bumpColor, soft)
		Kit.part(
			model,
			"Bump",
			Vector3.new(0.26 * W, 0.08 * H, 0.12 * W),
			at * CFrame.new(-0.55 * W, 0.05 * H, 0.08 * W) * CFrame.Angles(0, 0.2, 0.2),
			shade(main, -0.08),
			soft
		)
	end

	-- Drape folds: low ridges from the middle of the bell down to the hem, over the steps
	local foldColor = shade(main, -0.12)
	local r0, y0, r1, y1 = 0.52 * W, 0.03 * H, 0.37 * W, 0.46 * H
	local angles = {}
	for k = 0, 7 do
		table.insert(angles, k * math.pi / 4 + rng:NextNumber(-0.1, 0.1))
	end
	for _ = 1, 3 do
		table.remove(angles, rng:NextInteger(1, #angles)) -- 5 folds, never in the same places twice
	end
	for _, a in angles do
		local out = Vector3.new(math.cos(a), 0, math.sin(a))
		local p0 = (at * CFrame.new(out * r0 + Vector3.new(0, y0, 0))).Position
		local p1 = (at * CFrame.new(out * r1 + Vector3.new(0, y1, 0))).Position
		local outward = at:VectorToWorldSpace(out)
		Kit.part(
			model,
			"Fold",
			Vector3.new(0.1 * W, 0.06 * W, (p1 - p0).Magnitude),
			CFrame.lookAt((p0 + p1) / 2, p1, outward),
			foldColor,
			soft
		)
	end

	-- The rolled lip round the hem: eight bars in the trim colour, bobbing up and down like a wavy hem
	local apothem, bar = 0.53 * W, 0.09 * W
	local side = 2 * (apothem + bar / 2) * math.tan(math.pi / 8) + bar * 0.4
	for k = 0, 7 do
		local a = k * math.pi / 4
		local lift = if k % 2 == 0 then 0 else 0.025 * W
		Kit.part(
			model,
			"Lip",
			Vector3.new(side, bar, bar),
			at
				* CFrame.Angles(0, -a, 0)
				* CFrame.new(0, bar / 2 + lift, -apothem)
				* CFrame.Angles(if k % 2 == 0 then 0.1 else -0.1, 0, 0),
			trim,
			smooth
		)
	end

	-- The pattern, on the four sides of two tiers
	if kind == "dots" or kind == "stars" or kind == "checks" then
		for n, k in PATTERN_TIERS do
			local tier = TIERS[k]
			local hw, y, h = tier[3] * W, (tier[1] + tier[2] / 2) * H, tier[2] * H
			for f = 0, 3 do
				local shift = (if (f + n) % 2 == 0 then 1 else -1) * 0.3 * hw
				local face = tierFrames[k] * CFrame.Angles(0, f * math.pi / 2, 0) * CFrame.new(shift, y, -hw)
				if kind == "dots" then
					Kit.part(model, "Dot", Vector3.new(0.1 * W, 0.1 * W, 0.04), face, trim, smooth)
				elseif kind == "checks" then
					Kit.part(
						model,
						"Check",
						Vector3.new(0.5 * hw, h * 0.5, 0.04),
						face * CFrame.new(0, (if n == 1 then -1 else 1) * h * 0.25, 0),
						trim,
						{ material = Enum.Material.Fabric, collide = false, transparency = 0.2 }
					)
				else
					-- a little star: a diamond with a twist
					Kit.part(
						model,
						"Star",
						Vector3.new(0.4 * hw, 0.4 * hw, 0.04),
						face * CFrame.Angles(0, 0, math.pi / 4),
						trim,
						smooth
					)
				end
			end
		end
	end

	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.CanCollide = false -- you walk through sleeping toys; the prompt is how you grab them
		end
	end
	model.PrimaryPart = lump
	return model
end

return Blanket
