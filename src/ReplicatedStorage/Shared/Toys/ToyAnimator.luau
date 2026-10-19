--!strict
-- Client: plays every awake toy's idle animation, plus the moving parts of its rarity and mutation effects.
-- One loop drives all toys; toys far from the camera update less often, and past MAX_DISTANCE not at all.
--
--   ToyAnimator.start(model)  animate one toy (a built toy model with a ToyId attribute, anywhere in Workspace)
--   ToyAnimator.stop(model)   stop and put it back to its rest pose
--   ToyAnimator.play(model, move)  play a one-off move now ("Hatch", "Hop", "Spin", "Flip", "Wiggle", "Stretch",
--                             "Twirl", "Glitch")
--   ToyAnimator.watch()       animate every model tagged "TinyToy" that's in Workspace, as they come and go.
--                             TinyToyHeistToys/ToyClient calls this, so a toy cloned into Workspace just animates.
--
-- Two layers, added together on each group's Motor6D ("Rig.<Group>.Joint"):
--   1. The idle tracks from the toy's data (Idle = { { target, channel, amp, speed, wave, phase, duty } }, see
--      tools/toys/README.md): the toy's own little loop.
--   2. Personality, the same for every toy: it breathes, leans into its walk and waddles, eases round when it turns,
--      squashes when it lands a hop (the head and ears sink into the body, then spring back), looks around while it
--      stands still, and now and then does a move. Rarer toys do more, and fancier ones: Common hops and stretches,
--      Rare spins, Legendary flips, Mythic twirls in the air, Secret glitches. A fresh hatch (RevealedAt) plays a big
--      happy jump. Carried off by a thief it struggles and flails; dropped (StolenGlow) it shivers and looks about.
-- Everything is in studs from the toy's Root size, so it works at any Model:ScaleTo scale. Moving the toy around
-- (roaming a pen) is separate: move the model with PivotTo; the animation plays on top.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Mutations = require(script.Parent.Mutations)
local ToyCatalog = require(script.Parent.ToyCatalog)
local ToyVFX = require(script.Parent.ToyVFX)

local ToyAnimator = {}
ToyAnimator.TAG = "TinyToy"
ToyAnimator.MAX_DISTANCE = 220 -- studs from the camera
ToyAnimator.NEAR_DISTANCE = 90 -- closer than this: every frame; further: every third frame

local TAU = math.pi * 2

-- The VFX session's effects library, if it's there (puffs when a toy lands its hatch jump)
local VFX: any = nil
task.spawn(function()
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local m = shared and shared:WaitForChild("VFX", 30)
	if m and m:IsA("ModuleScript") then
		local ok, lib = pcall(require, m)
		if ok then
			VFX = lib
		end
	end
end)

-- The same wave maths as the review page (design/toy-turntables.html).
local function wave(kind: string, a: number, sp: number, ph: number, duty: number, t: number): number
	local x = sp * t + ph
	if kind == "Sin" then
		return a * math.sin(x)
	elseif kind == "Abs" then
		return a * math.abs(math.sin(x))
	elseif kind == "Pos" then
		return a * math.max(0, math.sin(x))
	elseif kind == "Lift" then
		return a * (1 - math.cos(x)) / 2
	elseif kind == "Spin" then
		return a * x
	elseif kind == "Const" then
		return a
	elseif kind == "Pulse" then
		local u = (x / TAU) % 1
		return u < duty and a * math.sin(math.pi * u / duty) or 0
	elseif kind == "Turn" then
		local u = (x / TAU) % 1
		if u < duty then
			local k = u / duty
			return a * TAU * k * k * (3 - 2 * k)
		end
		return 0
	elseif kind == "Step" then
		return math.sin(x) >= 0 and a or 0
	elseif kind == "Wobble" then
		return a * (0.6 * math.sin(x) + 0.4 * math.sin(2.3 * x + 1.1))
	end
	return a * math.sin(x)
end
ToyAnimator.wave = wave

------------------------------------------------------------------------------------------------------------------
-- Moves. Each takes u (0..1 through the move) and the toy's seed and gives, as fractions of the toy's height where
-- it's a distance: y lift, rx / ry / rz turns, cy (the height it turns about), sq (squash: + squash, - stretch),
-- arms (raise, radians) and x (sideways shift).

local function smooth(u: number): number
	u = math.clamp(u, 0, 1)
	return u * u * (3 - 2 * u)
end
local function bump(u: number): number
	return math.sin(math.pi * math.clamp(u, 0, 1))
end

type Move = (u: number, seed: number) -> (number, number, number, number, number, number, number, number)
local MOVES: { [string]: { seconds: number, fn: Move } } = {
	-- a little hop on the spot: crouch, up, land with a squash
	Hop = {
		seconds = 0.75,
		fn = function(u)
			if u < 0.2 then
				return 0, 0, 0, 0, 0, 0.16 * bump(u / 0.2), 0, 0
			elseif u < 0.8 then
				local k = (u - 0.2) / 0.6
				return 0.22 * bump(k), 0, 0, 0, 0, -0.1 * bump(k), 0.6 * bump(k), 0
			end
			return 0, 0, 0, 0, 0, 0.18 * bump((u - 0.8) / 0.2), 0, 0
		end,
	},
	-- a big stretch, arms up, then a shake
	Stretch = {
		seconds = 1.8,
		fn = function(u)
			if u < 0.7 then
				local s = bump(u / 0.7)
				return 0.02 * s, 0.1 * s, 0, 0, 0, -0.12 * s, 1.8 * s, 0
			end
			local k = (u - 0.7) / 0.3
			return 0, 0, 0, 0.07 * math.sin(k * 40) * (1 - k), 0, 0.04 * bump(k), 0, 0
		end,
	},
	-- a happy side-to-side wiggle
	Wiggle = {
		seconds = 1.5,
		fn = function(u)
			local e = bump(u)
			local w = u * TAU * 3
			return 0.05 * math.abs(math.sin(w)) * e,
				0,
				0.25 * math.sin(u * TAU * 1.5) * e,
				0.2 * math.sin(w) * e,
				0,
				0.06 * math.sin(w * 2) * e,
				0.9 * e + 0.4 * math.sin(w * 2) * e,
				0
		end,
	},
	-- a hop with a full turn in the air
	Spin = {
		seconds = 1,
		fn = function(u)
			if u < 0.18 then
				return 0, 0, 0, 0, 0, 0.18 * bump(u / 0.18), 0, 0
			elseif u < 0.82 then
				local k = (u - 0.18) / 0.64
				return 0.3 * bump(k), 0, TAU * smooth(k), 0, 0, -0.12 * bump(k), 1.2 * bump(k), 0
			end
			return 0, 0, 0, 0, 0, 0.2 * bump((u - 0.82) / 0.18), 0, 0
		end,
	},
	-- a front flip
	Flip = {
		seconds = 1.15,
		fn = function(u)
			if u < 0.18 then
				return 0, 0, 0, 0, 0, 0.22 * bump(u / 0.18), 0, 0
			elseif u < 0.82 then
				local k = (u - 0.18) / 0.64
				return 0.55 * bump(k), -TAU * smooth(k), 0, 0, 0.5, -0.08 * bump(k), 1.4 * bump(k), 0
			end
			return 0, 0, 0, 0, 0, 0.24 * bump((u - 0.82) / 0.18), 0, 0
		end,
	},
	-- floats up and twirls twice, arms out
	Twirl = {
		seconds = 2.4,
		fn = function(u)
			local e = bump(u)
			return 0.28 * e + 0.03 * math.sin(u * TAU * 4) * e,
				0,
				2 * TAU * smooth(u),
				0.12 * math.sin(u * TAU * 2) * e,
				0.5,
				-0.06 * e,
				1.3 * e,
				0
		end,
	},
	-- jumps between poses like a bad video signal
	Glitch = {
		seconds = 0.9,
		fn = function(u, seed)
			local step = math.floor(u * 12)
			if step % 3 == 2 then
				return 0, 0, 0, 0, 0, 0, 0, 0
			end
			local n = function(k: number): number
				return math.noise(step * 1.37 + k, seed * 0.11, k * 2.3) * 2
			end
			return math.abs(n(1)) * 0.06, 0, n(2) * 0.9, n(3) * 0.25, 0.5, n(4) * 0.15, n(5) * 1.5, n(6) * 0.12
		end,
	},
	-- a fresh hatch: squashed small, a big jump with a spin, land, two cheering hops
	Hatch = {
		seconds = 2,
		fn = function(u)
			if u < 0.12 then
				return 0, 0, 0, 0, 0, 0.28, 0, 0
			elseif u < 0.55 then
				local k = (u - 0.12) / 0.43
				return 0.7 * bump(k), 0, TAU * smooth(k), 0, 0, -0.18 * bump(k), 1.6 * bump(k), 0
			elseif u < 0.65 then
				return 0, 0, 0, 0, 0, 0.28 * bump((u - 0.55) / 0.1), 0.4, 0
			end
			local k = (u - 0.65) / 0.35
			return 0.14 * math.abs(math.sin(k * TAU)),
				0,
				0,
				0.08 * math.sin(k * TAU * 2),
				0,
				-0.05,
				(1.7 + 0.3 * math.sin(k * TAU * 4)) * (1 - k ^ 4),
				0
		end,
	},
}
ToyAnimator.MOVES = MOVES

-- How often each rarity does a move while standing still (seconds, min and max), and which moves
local PERSONALITY: { [string]: { every: { number }, moves: { string }, look: number } } = {
	Common = { every = { 8, 13 }, moves = { "Hop", "Stretch", "Hop" }, look = 1 },
	Uncommon = { every = { 6.5, 11 }, moves = { "Hop", "Stretch", "Wiggle" }, look = 1.1 },
	Rare = { every = { 5.5, 9 }, moves = { "Hop", "Wiggle", "Spin" }, look = 1.2 },
	Epic = { every = { 4.5, 8 }, moves = { "Wiggle", "Spin", "Hop", "Spin" }, look = 1.3 },
	Legendary = { every = { 4, 7 }, moves = { "Spin", "Flip", "Wiggle", "Flip" }, look = 1.4 },
	Mythic = { every = { 3.5, 6 }, moves = { "Twirl", "Flip", "Spin" }, look = 1.5 },
	Secret = { every = { 3, 5.5 }, moves = { "Glitch", "Twirl", "Flip", "Glitch" }, look = 1.6 },
}

------------------------------------------------------------------------------------------------------------------

type Track = { joint: string, chan: string, a: number, sp: number, wave: string, ph: number, duty: number }
type Pose = { px: number, py: number, pz: number, rx: number, ry: number, rz: number, fade: number }
-- A joint's rest frame in the toy's own space (+X side, +Y up, -Z forward), for the personality layer
type JointInfo = {
	joint: Motor6D,
	rest: CFrame, -- the joint's turn relative to the toy (rotation only)
	restInv: CFrame,
	h: number, -- height above the feet, as a fraction of the toy's height
	side: number, -- -1 / 1: which side of the toy it's on
	role: string, -- "Body", "Head", "Arm", "Leg", "Flop" (ears, tail, hat: they lag behind) or "Other"
	child: boolean, -- hangs straight off the Body (squash moves it)
}
type State = {
	model: Model,
	root: BasePart,
	joints: { [string]: Motor6D },
	info: { [string]: JointInfo },
	tracks: { Track },
	poses: { [string]: Pose },
	fadeParts: { [string]: { BasePart } },
	voxel: number,
	t0: number,
	skip: number,
	effects: { (t: number, dt: number) -> () },
	lift: ((t: number) -> number)?,
	conns: { RBXScriptConnection },
	-- personality
	seed: number,
	rarity: string,
	last: number, -- os.clock of the last update
	lastPos: Vector3?,
	vy: number,
	speed: number,
	still: number, -- seconds standing still
	walk: number, -- waddle phase
	yaw: number?, -- the eased facing
	sq: number,
	sqv: number,
	look: number,
	lookTilt: number,
	lookGoal: number,
	tiltGoal: number,
	nextLook: number,
	move: string?,
	moveAt: number,
	nextMove: number,
	landed: boolean,
}

local active: { [Model]: State } = {}
local ensureLoop: () -> ()

local ARM = { "^Arm", "^Wing", "^Hand", "^Mitten", "^Fin" }
local LEG = { "^Leg", "^Foot" }
local FLOP = { "^Ear", "^Tail", "^Hat", "^Antenna", "^Tuft", "^Scarf", "^Bow", "^Horn" }
local function matches(name: string, patterns: { string }): boolean
	for _, p in patterns do
		if string.match(name, p) then
			return true
		end
	end
	return false
end

local function refreshEffects(st: State)
	local effects = {}
	local mutEffect, lift = Mutations.animate(st.model)
	if mutEffect then
		table.insert(effects, mutEffect)
	end
	local rarityEffect = ToyVFX.animateRarity(st.model)
	if rarityEffect then
		table.insert(effects, rarityEffect)
	end
	st.effects = effects
	st.lift = lift
end

local function startMove(st: State, move: string, at: number?)
	if MOVES[move] then
		st.move = move
		st.moveAt = at or os.clock()
		st.landed = false
	end
end

local function scheduleMove(st: State, now: number)
	local p = PERSONALITY[st.rarity] or PERSONALITY.Common
	st.nextMove = now + p.every[1] + math.random() * (p.every[2] - p.every[1])
end

local function checkHatch(st: State)
	local at = st.model:GetAttribute("RevealedAt")
	if typeof(at) == "number" then
		local age = Workspace:GetServerTimeNow() - at
		if age >= 0 and age < 1.5 then
			startMove(st, "Hatch", os.clock() - age)
		end
	end
end

function ToyAnimator.start(model: Model)
	if active[model] then
		return
	end
	ensureLoop()
	local id = model:GetAttribute("ToyId")
	local toy = type(id) == "string" and ToyCatalog.get(id) or nil
	local root = model.PrimaryPart
	local rig = model:FindFirstChild("Rig")
	if not toy or not root or not rig then
		return
	end
	local joints: { [string]: Motor6D } = {}
	local parentOf: { [string]: string } = {}
	for _, pivot in rig:GetChildren() do
		local j = pivot:FindFirstChild("Joint")
		if j and j:IsA("Motor6D") then
			joints[pivot.Name] = j
		end
		local pg = pivot:GetAttribute("ParentGroup")
		if type(pg) == "string" then
			parentOf[pivot.Name] = pg
		end
	end
	-- every joint's rest frame in the toy's space (read with all transforms cleared)
	local info: { [string]: JointInfo } = {}
	local rootCf = root.CFrame
	local height = math.max(root.Size.Y, 0.1)
	for _, j in joints do
		j.Transform = CFrame.identity
	end
	for name, j in joints do
		local part0 = j.Part0
		if not part0 then
			continue
		end
		local world = part0.CFrame * j.C0
		local rel = rootCf:ToObjectSpace(world)
		local rot = rel.Rotation
		local role = if name == "Body"
			then "Body"
			elseif name == "Head" then "Head"
			elseif matches(name, ARM) then "Arm"
			elseif matches(name, LEG) then "Leg"
			elseif matches(name, FLOP) then "Flop"
			else "Other"
		info[name] = {
			joint = j,
			rest = rot,
			restInv = rot:Inverse(),
			h = (rel.Position.Y + height / 2) / height,
			side = if rel.Position.X < -0.01 then -1 else 1,
			role = role,
			child = parentOf[name] == "Body",
		}
	end

	local tracks: { Track } = {}
	local poses: { [string]: Pose } = {}
	local fadeGroups: { [string]: boolean } = {}
	for _, tr in toy.Idle or {} do
		local target, chan = tr[1], tr[2]
		if joints[target] then
			table.insert(tracks, {
				joint = target,
				chan = chan,
				a = tr[3],
				sp = tr[4],
				wave = tr[5] or "Sin",
				ph = tr[6] or 0,
				duty = tr[7] or 0.3,
			})
			poses[target] = { px = 0, py = 0, pz = 0, rx = 0, ry = 0, rz = 0, fade = 0 }
			if chan == "Fade" then
				fadeGroups[target] = true
			end
		end
	end
	-- the blocks a Fade track hides: its group and every group nested inside it
	local fadeParts: { [string]: { BasePart } } = {}
	local blocks = model:FindFirstChild("Blocks")
	if next(fadeGroups) and blocks then
		for _, p in blocks:GetChildren() do
			local g = p:GetAttribute("Group")
			while type(g) == "string" do
				if fadeGroups[g] then
					fadeParts[g] = fadeParts[g] or {}
					table.insert(fadeParts[g], p :: BasePart)
					break
				end
				g = parentOf[g]
			end
		end
	end
	local scale = model:GetAttribute("VoxelScale")
	local now = os.clock()
	local st: State = {
		model = model,
		root = root,
		joints = joints,
		info = info,
		tracks = tracks,
		poses = poses,
		fadeParts = fadeParts,
		voxel = type(scale) == "number" and scale or 1,
		t0 = now - math.random() * 20,
		skip = math.random(0, 2),
		effects = {},
		lift = nil,
		conns = {},
		seed = math.random() * 1000,
		rarity = toy.Rarity or "Common",
		last = now,
		lastPos = nil,
		vy = 0,
		speed = 0,
		still = 0,
		walk = 0,
		yaw = nil,
		sq = 0,
		sqv = 0,
		look = 0,
		lookTilt = 0,
		lookGoal = 0,
		tiltGoal = 0,
		nextLook = now + math.random() * 2,
		move = nil,
		moveAt = 0,
		nextMove = 0,
		landed = false,
	}
	scheduleMove(st, now)
	st.nextMove -= math.random() * 4 -- not everyone in step
	refreshEffects(st)
	checkHatch(st)
	table.insert(
		st.conns,
		model:GetAttributeChangedSignal("Mutation"):Connect(function()
			task.defer(refreshEffects, st)
		end)
	)
	table.insert(
		st.conns,
		model:GetAttributeChangedSignal("RevealedAt"):Connect(function()
			checkHatch(st)
		end)
	)
	table.insert(
		st.conns,
		model.AncestryChanged:Connect(function()
			if not model:IsDescendantOf(Workspace) then
				ToyAnimator.stop(model)
			end
		end)
	)
	active[model] = st
end

function ToyAnimator.stop(model: Model)
	local st = active[model]
	if not st then
		return
	end
	active[model] = nil
	for _, c in st.conns do
		c:Disconnect()
	end
	for _, j in st.joints do
		j.Transform = CFrame.identity
	end
	for _, parts in st.fadeParts do
		for _, p in parts do
			p.LocalTransparencyModifier = 0
		end
	end
end

function ToyAnimator.play(model: Model, move: string)
	local st = active[model]
	if st then
		startMove(st, move)
	end
end

local function angleDiff(a: number, b: number): number
	return (a - b + math.pi) % TAU - math.pi
end

-- The personality layer for one frame: an extra turn for each joint, in the toy's own space, about the joint.
type Layer = {
	body: CFrame,
	sq: number,
	arms: number,
	flail: number,
	flop: number,
	look: number,
	tilt: number,
	t: number,
}
local layer: Layer = { body = CFrame.identity, sq = 0, arms = 0, flail = 0, flop = 0, look = 0, tilt = 0, t = 0 }

local function personality(st: State, now: number, dt: number): Layer
	local root = st.root
	local H = math.max(root.Size.Y, 0.1)
	local cf = root.CFrame
	local pos = cf.Position
	local carried = root:FindFirstChild("CarryWeld") ~= nil
	local loose = not carried and st.model:FindFirstChild("StolenGlow") ~= nil

	-- how it's moving (the pen roam moves the model; we just watch)
	local last = st.lastPos or pos
	st.lastPos = pos
	local d = pos - last
	if d.Magnitude > H * 4 then -- teleported (respawned, moved pens): don't count it
		d = Vector3.zero
		st.yaw = nil
	end
	local inv = 1 / math.max(dt, 1 / 240)
	local vy = d.Y * inv
	local flat = Vector3.new(d.X, 0, d.Z).Magnitude * inv
	st.speed += (flat - st.speed) * math.min(1, dt * 10)
	-- landing a hop: the head sinks in, then springs back
	if st.vy < -0.6 and vy >= -0.05 and not carried then
		st.sqv += math.min(-st.vy * 0.06, 0.45) * 8
	end
	st.vy = vy
	local k, damp = 260, 13
	st.sqv += (-k * st.sq - damp * st.sqv) * dt
	st.sq += st.sqv * dt
	st.sq = math.clamp(st.sq, -0.3, 0.35)

	-- ease round when its facing jumps (the roam turns it on the spot at the start of each walk)
	local look = cf.LookVector
	local yaw = math.atan2(-look.X, -look.Z)
	st.yaw = st.yaw or yaw
	st.yaw = (st.yaw :: number) + angleDiff(yaw, st.yaw :: number) * math.min(1, dt * 7)
	local turnLag = math.clamp(angleDiff(st.yaw :: number, yaw), -1.4, 1.4)

	local walking = st.speed > H * 0.05
	if walking then
		st.still = 0
	else
		st.still += dt
	end
	local walkAmount = math.clamp(st.speed / (H * 0.4), 0, 1)
	st.walk += flat * dt / (H * 0.3) * math.pi

	local t = now - st.t0
	local p = PERSONALITY[st.rarity] or PERSONALITY.Common
	local y, rx, ry, rz, cy, sq, arms, x = 0, 0, 0, 0, 0, 0, 0, 0
	local flail, flop = 0, 0

	if carried then
		-- struggling: kicking, twisting, flailing, every now and then a big buck
		local buck = math.max(0, math.sin(t * 2.3 + st.seed)) ^ 6
		rz = 0.22 * math.sin(t * 17 + st.seed) + 0.1 * math.sin(t * 29) + 0.25 * buck * math.sin(t * 9)
		rx = 0.15 * math.sin(t * 11) - 0.2 * buck
		ry = 0.2 * math.sin(t * 5.3)
		y = 0.05 * math.abs(math.sin(t * 9)) + 0.12 * buck
		sq = 0.08 * math.sin(t * 18)
		arms = 0.9 + 0.5 * math.sin(t * 21)
		flail = 1
		flop = 0.5 * math.sin(t * 15)
		st.move = nil
	elseif loose then
		-- dropped in the open: shivering, looking about for help, a nervous hop now and then
		rz = 0.035 * math.sin(t * 43)
		y = 0.08 * math.max(0, math.sin(t * 3.1 + st.seed)) ^ 8
		arms = 0.25 + 0.1 * math.sin(t * 37)
		if now >= st.nextLook then
			st.lookGoal = (math.random() * 2 - 1) * 1.1
			st.tiltGoal = (math.random() * 2 - 1) * 0.15
			st.nextLook = now + 0.4 + math.random() * 0.6
		end
	else
		-- walking: lean in and waddle
		rx = -0.16 * walkAmount
		rz = 0.07 * math.sin(st.walk) * walkAmount
		-- breathing (the head rises and falls a little)
		sq = 0.025 * math.sin(t * 2.2 + st.seed)
		-- standing still: look around
		if st.still > 0.4 and now >= st.nextLook then
			if math.random() < 0.35 then
				st.lookGoal, st.tiltGoal = 0, 0
			else
				st.lookGoal = (math.random() * 2 - 1) * 0.8 * p.look
				st.tiltGoal = (math.random() * 2 - 1) * 0.18
			end
			st.nextLook = now + (1.2 + math.random() * 2) / p.look
		elseif walking then
			st.lookGoal, st.tiltGoal = 0, 0
		end
		-- and now and then a move
		if not st.move and st.still > 0.5 and now >= st.nextMove then
			startMove(st, p.moves[math.random(1, #p.moves)])
			scheduleMove(st, now)
		end
	end
	st.look += (st.lookGoal - st.look) * math.min(1, dt * 6)
	st.lookTilt += (st.tiltGoal - st.lookTilt) * math.min(1, dt * 6)

	-- a move plays on top
	local move = st.move
	if move then
		local m = MOVES[move]
		local u = (now - st.moveAt) / m.seconds
		if u >= 1 then
			st.move = nil
		elseif u >= 0 then
			local my, mrx, mry, mrz, mcy, msq, marms, mx = m.fn(u, st.seed)
			y += my
			rx += mrx
			ry += mry
			rz += mrz
			cy = math.max(cy, mcy)
			sq += msq
			arms += marms
			x += mx
			-- the hatch jump lands with a puff
			if move == "Hatch" and u >= 0.55 and not st.landed then
				st.landed = true
				if VFX then
					pcall(VFX.burst, "Poof", pos - Vector3.new(0, H / 2, 0), { scale = H / 6 })
				end
			end
		end
	end

	local lift = st.lift and st.lift(t) or 0
	local c = cy * H
	layer.body = CFrame.new(x * H, y * H + lift, 0)
		* CFrame.new(0, c, 0)
		* CFrame.Angles(0, ry + turnLag, 0)
		* CFrame.Angles(rx, 0, rz)
		* CFrame.new(0, -c, 0)
	layer.sq = sq + st.sq
	layer.arms = arms - layer.sq * 2 -- arms splay out as it squashes
	layer.flail = flail
	layer.flop = flop + st.sq * 2.5 + st.sqv * 0.08
	layer.look = st.look
	layer.tilt = st.lookTilt
	layer.t = t
	return layer
end

-- An extra turn in the toy's own space, made into the joint's own frame
local function inJoint(info: JointInfo, extra: CFrame): CFrame
	return info.restInv * extra * info.rest
end

local function pose(st: State, t: number, now: number, dt: number)
	for _, p in st.poses do
		p.px, p.py, p.pz, p.rx, p.ry, p.rz, p.fade = 0, 0, 0, 0, 0, 0, 0
	end
	for _, tr in st.tracks do
		local v = wave(tr.wave, tr.a, tr.sp, tr.ph, tr.duty, t)
		local p = st.poses[tr.joint]
		local c = tr.chan
		if c == "PosY" then
			p.py += v
		elseif c == "RotZ" then
			p.rz += v
		elseif c == "RotX" then
			p.rx += v
		elseif c == "RotY" then
			p.ry += v
		elseif c == "PosX" then
			p.px += v
		elseif c == "PosZ" then
			p.pz += v
		elseif c == "Fade" then
			p.fade += v
		end
	end
	local u = st.voxel * st.model:GetScale()
	local L = personality(st, now, dt)
	local H = st.root.Size.Y
	for name, j in st.joints do
		local p = st.poses[name]
		local base = if p
			then CFrame.new(p.px * u, p.py * u, p.pz * u) * CFrame.Angles(p.rx, p.ry, p.rz)
			else CFrame.identity
		local info = st.info[name]
		if info then
			local extra: CFrame? = nil
			local role = info.role
			if role == "Body" then
				extra = L.body
			else
				local e = CFrame.identity
				if info.child then
					e = CFrame.new(0, -L.sq * info.h * H, 0)
				end
				if role == "Head" then
					e *= CFrame.Angles(0, L.look, 0) * CFrame.Angles(0, 0, L.tilt)
				elseif role == "Arm" then
					local a = L.arms + L.flail * 0.7 * math.sin(L.t * 21 + info.side * 1.3)
					e *= CFrame.Angles(L.flail * 0.5 * math.sin(L.t * 17 + info.side), 0, a * info.side * 0.6)
				elseif role == "Leg" then
					e *= CFrame.Angles(L.flail * 0.6 * math.sin(L.t * 19 + info.side * math.pi), 0, 0)
				elseif role == "Flop" then
					e *= CFrame.Angles(L.flop * 0.5, 0, 0)
				end
				if e ~= CFrame.identity then
					extra = e
				end
			end
			if extra then
				j.Transform = inJoint(info, extra) * base
				continue
			end
		end
		j.Transform = base
	end
	for name, parts in st.fadeParts do
		local p = st.poses[name]
		if p then
			local f = math.clamp(p.fade, 0, 1)
			for _, part in parts do
				part.LocalTransparencyModifier = f
			end
		end
	end
end
ToyAnimator.pose = pose

local lastClock = os.clock()
local function step()
	local now = os.clock()
	local dt = now - lastClock
	lastClock = now
	local cam = Workspace.CurrentCamera
	local camPos = cam and cam.CFrame.Position or Vector3.zero
	for _, st in active do
		local d = (st.root.Position - camPos).Magnitude
		if d > ToyAnimator.MAX_DISTANCE then
			st.last = now
			st.lastPos = nil
			continue
		end
		if d > ToyAnimator.NEAR_DISTANCE then
			st.skip = (st.skip + 1) % 3
			if st.skip ~= 0 then
				continue
			end
		end
		local sdt = math.min(now - st.last, 0.1)
		st.last = now
		local t = now - st.t0
		pose(st, t, now, sdt)
		for _, fx in st.effects do
			fx(t, dt)
		end
	end
end

local stepConn: RBXScriptConnection? = nil
function ensureLoop()
	if not stepConn then
		stepConn = (if RunService:IsClient() then RunService.PreRender else RunService.Heartbeat):Connect(step)
	end
end

function ToyAnimator.watch()
	local function consider(inst: Instance)
		if inst:IsA("Model") and inst:IsDescendantOf(Workspace) then
			ToyAnimator.start(inst)
		end
	end
	for _, inst in CollectionService:GetTagged(ToyAnimator.TAG) do
		consider(inst)
	end
	CollectionService:GetInstanceAddedSignal(ToyAnimator.TAG):Connect(function(inst)
		-- a clone arrives before its descendants on the client; give it a moment
		task.defer(consider, inst)
	end)
	CollectionService:GetInstanceRemovedSignal(ToyAnimator.TAG):Connect(function(inst)
		if inst:IsA("Model") then
			ToyAnimator.stop(inst)
		end
	end)
end

return ToyAnimator
