--!strict
-- Client: plays every awake toy's idle animation, plus the moving parts of its rarity and mutation effects.
-- One loop drives all toys; toys far from the camera update less often, and past MAX_DISTANCE not at all.
--
--   ToyAnimator.start(model)  animate one toy (a built toy model with a ToyId attribute, anywhere in Workspace)
--   ToyAnimator.stop(model)   stop and put it back to its rest pose
--   ToyAnimator.watch()       animate every model tagged "TinyToy" that's in Workspace, as they come and go.
--                             TinyToyHeistToys/ToyClient calls this, so a toy cloned into Workspace just animates.
--
-- Idle tracks come from the toy's data (Idle = { { target, channel, amp, speed, wave, phase, duty } }, see
-- tools/toys/README.md) and set the Transform of each group's Motor6D ("Rig.<Group>.Joint"). Moving the toy around
-- (roaming a pen) is separate: move the model with PivotTo; the animation plays on top.
local CollectionService = game:GetService("CollectionService")
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

type Track = { joint: string, chan: string, a: number, sp: number, wave: string, ph: number, duty: number }
type Pose = { px: number, py: number, pz: number, rx: number, ry: number, rz: number, fade: number }
type State = {
	model: Model,
	root: BasePart,
	joints: { [string]: Motor6D },
	tracks: { Track },
	poses: { [string]: Pose },
	fadeParts: { [string]: { BasePart } },
	unit: number,
	t0: number,
	skip: number,
	effects: { (t: number, dt: number) -> () },
	lift: ((t: number) -> number)?,
	conns: { RBXScriptConnection },
}

local active: { [Model]: State } = {}
local ensureLoop: () -> ()

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
	-- Bubble and Haunted lift the Body even if the toy's idle doesn't move it
	if lift and not st.poses.Body and st.joints.Body then
		st.poses.Body = { px = 0, py = 0, pz = 0, rx = 0, ry = 0, rz = 0, fade = 0 }
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
	local st: State = {
		model = model,
		root = root,
		joints = joints,
		tracks = tracks,
		poses = poses,
		fadeParts = fadeParts,
		unit = (type(scale) == "number" and scale or 1) * model:GetScale(),
		t0 = os.clock() - math.random() * 20,
		skip = math.random(0, 2),
		effects = {},
		lift = nil,
		conns = {},
	}
	refreshEffects(st)
	table.insert(
		st.conns,
		model:GetAttributeChangedSignal("Mutation"):Connect(function()
			task.defer(refreshEffects, st)
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

local function pose(st: State, t: number)
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
	local u = st.unit
	local lift = st.lift and st.lift(t) or 0
	for name, p in st.poses do
		local j = st.joints[name]
		local y = p.py * u + (name == "Body" and lift or 0)
		j.Transform = CFrame.new(p.px * u, y, p.pz * u) * CFrame.Angles(p.rx, p.ry, p.rz)
		local parts = st.fadeParts[name]
		if parts then
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
			continue
		end
		if d > ToyAnimator.NEAR_DISTANCE then
			st.skip = (st.skip + 1) % 3
			if st.skip ~= 0 then
				continue
			end
		end
		local t = now - st.t0
		pose(st, t)
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
