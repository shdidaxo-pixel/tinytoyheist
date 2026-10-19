--!strict
-- Client: the sleeping toys under their blankets look alive.
--   Lying on the floor (or waking up in a home): the blanket breathes, slowly rising and falling, and every so often
--   the toy under it turns over (a shimmy and a bulge). A blanket in a home tosses more as its wake-up gets close.
--   Being dragged: the toy struggles under it (squirming, kicking, twisting). The real blanket is welded to the
--   player, so on each screen a copy is drawn on top of it, moving, and the real one is hidden.
-- Only the look changes, and only on this screen: the server's blanket (its Lump, prompt and glow tell) stays put.
--
--   BlanketAnimator.watch()   animate every blanket (a Model named "SleepingToy" with a "Lump") in Workspace.Bedroom

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BlanketAnimator = {}
BlanketAnimator.NEAR = 150 -- studs from the camera: every frame
BlanketAnimator.FAR = 260 -- further than NEAR: every third frame; past FAR not at all

local TAU = math.pi * 2

type Piece = { part: BasePart, offset: CFrame, h: number }
type Blanket = {
	model: Model,
	lump: BasePart,
	pieces: { Piece }?, -- nil until (re)read; parts can stream in late
	known: { [BasePart]: Piece },
	seed: number,
	toss: number, -- os.clock a turn-over started (0 = none)
	nextToss: number,
	copies: { BasePart }?, -- while dragged: the moving copy
	hidden: { BasePart }?,
	skip: number,
	conns: { RBXScriptConnection },
}

local blankets: { [Model]: Blanket } = {}
local fxFolder: Folder? = nil

local function bump(u: number): number
	return math.sin(math.pi * math.clamp(u, 0, 1))
end

-- The blanket's visible parts and where they sit on the Lump. A part's place is read once, the first time it's seen
-- (as the server built it), so reading again (parts streaming in) never picks up the breathing.
local function readPieces(b: Blanket): { Piece }
	local lump = b.lump
	local H = lump.Size.Y
	local pieces = {}
	local known = {}
	for _, p in b.model:GetDescendants() do
		if p:IsA("BasePart") and p ~= lump and p.Name ~= "Shadow" then
			local piece = b.known[p]
			if not piece then
				local offset = lump.CFrame:ToObjectSpace(p.CFrame)
				piece = { part = p, offset = offset, h = math.clamp((offset.Y + H / 2) / H, 0, 1) }
			end
			known[p] = piece
			table.insert(pieces, piece :: Piece)
		end
	end
	b.known = known
	return pieces
end

local function dropCopies(b: Blanket)
	if b.copies then
		for _, c in b.copies do
			c:Destroy()
		end
		b.copies = nil
	end
	if b.hidden then
		for _, p in b.hidden do
			p.LocalTransparencyModifier = 0
		end
		b.hidden = nil
	end
end

local function makeCopies(b: Blanket, pieces: { Piece })
	if not fxFolder then
		local f = Instance.new("Folder")
		f.Name = "BlanketCopies"
		f.Parent = Workspace
		fxFolder = f
	end
	local copies, hidden = {}, {}
	for _, piece in pieces do
		local c = piece.part:Clone()
		for _, d in c:GetChildren() do
			if d:IsA("JointInstance") or d:IsA("WeldConstraint") or d:IsA("Attachment") or d:IsA("ProximityPrompt") then
				d:Destroy()
			end
		end
		c.Anchored = true
		c.CanCollide = false
		c.CanQuery = false
		c.CanTouch = false
		c.Parent = fxFolder
		table.insert(copies, c)
		table.insert(hidden, piece.part)
		piece.part.LocalTransparencyModifier = 1
	end
	b.copies, b.hidden = copies, hidden
end

local function forget(model: Model)
	local b = blankets[model]
	if not b then
		return
	end
	blankets[model] = nil
	dropCopies(b)
	for _, c in b.conns do
		c:Disconnect()
	end
end

local function add(model: Model)
	if blankets[model] then
		return
	end
	local lump = model:FindFirstChild("Lump")
	if not lump or not lump:IsA("BasePart") then
		return
	end
	local now = os.clock()
	local b: Blanket = {
		model = model,
		lump = lump,
		pieces = nil,
		known = {},
		seed = math.random() * 100,
		toss = 0,
		nextToss = now + 3 + math.random() * 10,
		copies = nil,
		hidden = nil,
		skip = math.random(0, 2),
		conns = {},
	}
	local function dirty(d: Instance)
		-- parts streamed in or out: read them again next time it's lying still
		if d:IsA("BasePart") and not b.copies then
			b.pieces = nil
		end
	end
	table.insert(b.conns, model.DescendantAdded:Connect(dirty))
	table.insert(b.conns, model.DescendantRemoving:Connect(dirty))
	table.insert(
		b.conns,
		model.AncestryChanged:Connect(function()
			if not model:IsDescendantOf(Workspace) then
				forget(model)
			end
		end)
	)
	blankets[model] = b
end

local parts: { BasePart } = {}
local cframes: { CFrame } = {}

local function step()
	local now = os.clock()
	local cam = Workspace.CurrentCamera
	local eye = if cam then cam.CFrame.Position else Vector3.zero
	local serverNow = Workspace:GetServerTimeNow()
	table.clear(parts)
	table.clear(cframes)
	for model, b in blankets do
		local lump = b.lump
		if not lump.Parent then
			forget(model)
			continue
		end
		local distance = (lump.Position - eye).Magnitude
		local dragged = not lump.Anchored and lump:FindFirstChild("CarryWeld") ~= nil
		if not dragged and b.copies then
			dropCopies(b)
			b.pieces = nil -- read again now it's lying still
		end
		if distance > BlanketAnimator.FAR then
			continue
		end
		if distance > BlanketAnimator.NEAR then
			b.skip = (b.skip + 1) % 3
			if b.skip ~= 0 then
				continue
			end
		end
		if not dragged and not lump.Anchored then
			continue -- in between (being picked up or put down)
		end
		if not b.pieces then
			if dragged then
				continue -- never read it mid-drag; it's already moved
			end
			b.pieces = readPieces(b)
		end
		local pieces = b.pieces :: { Piece }
		local H = lump.Size.Y
		local W = math.max(lump.Size.X, lump.Size.Z) / 1.1
		local t = now + b.seed
		local base = lump.CFrame

		local stretch, swayX, swayZ, twist, lift = 0, 0, 0, 0, 0
		if dragged then
			if not b.copies then
				makeCopies(b, pieces)
			end
			-- the toy fights to get out: squirms, kicks the sides out, twists, bucks
			local buck = math.max(0, math.sin(t * 2.1)) ^ 5
			stretch = 0.07 * math.abs(math.sin(t * 7.5)) + 0.12 * buck
			swayX = W * (0.07 * math.sin(t * 9) + 0.04 * math.sin(t * 15.7))
			swayZ = W * 0.04 * math.sin(t * 6.3)
			twist = 0.14 * math.sin(t * 4.7) + 0.1 * buck * math.sin(t * 11)
			lift = H * 0.04 * math.abs(math.sin(t * 13))
		else
			-- asleep: slow breathing
			stretch = 0.035 * math.sin(t * 1.9)
			-- waking up in a home: it tosses more as the time gets close
			local wakeAt = model:GetAttribute("WakeAt")
			local restless = if typeof(wakeAt) == "number" then math.clamp(1 - (wakeAt - serverNow) / 8, 0, 1) else 0
			if b.toss == 0 and now >= b.nextToss then
				b.toss = now
				b.nextToss = now + (7 + math.random() * 9) * (1 - restless * 0.8)
			end
			if b.toss > 0 then
				-- turning over: a shimmy one way and back, and the middle bulges
				local k = (now - b.toss) / 1.3
				if k >= 1 then
					b.toss = 0
				else
					local e = bump(k)
					swayX = W * 0.06 * math.sin(k * TAU * 2) * e
					stretch += 0.06 * e
					twist = 0.08 * math.sin(k * TAU) * e
				end
			end
		end

		local half = H / 2
		local turn = CFrame.Angles(0, twist, 0)
		for i, piece in pieces do
			local o = piece.offset
			local h = piece.h
			-- stretch upward from the floor; the top sways the most
			local p = o.Position
			local y = (p.Y + half) * (1 + stretch) - half + lift
			local sway = h * h
			local at = turn * CFrame.new(p.X + swayX * sway, y, p.Z + swayZ * sway)
			local cf = base * at * o.Rotation
			if b.copies then
				local c = b.copies[i]
				if c then
					table.insert(parts, c)
					table.insert(cframes, cf)
				end
			elseif piece.part.Parent then
				table.insert(parts, piece.part)
				table.insert(cframes, cf)
			end
		end
	end
	if #parts > 0 then
		Workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

function BlanketAnimator.watch()
	local bedroom = Workspace:WaitForChild("Bedroom")
	local function consider(d: Instance)
		if d.Name == "Lump" and d.Parent and d.Parent:IsA("Model") and d.Parent.Name == "SleepingToy" then
			add(d.Parent :: Model)
		end
	end
	bedroom.DescendantAdded:Connect(function(d)
		if d.Name == "Lump" then
			task.defer(consider, d)
		end
	end)
	for _, d in bedroom:GetDescendants() do
		if d.Name == "Lump" then
			consider(d)
		end
	end
	RunService.PreRender:Connect(step)
end

return BlanketAnimator
