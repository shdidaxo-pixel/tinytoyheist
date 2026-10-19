--!strict
-- How the mice move, on top of the normal Roblox animations (procedural: each R15 joint gets an extra turn after the
-- Animator has posed it, so nothing needs uploading). Every player's character is posed on every screen, from things
-- everyone can see (player attributes, the humanoid's state, toys appearing in pens):
--   Dragging a blanket or a stolen toy (Carrying): leaning into the pull, both arms reaching back to the load, head
--     up, a tug with every step; heavier toys pull harder. A quick yank when you first get hold of it.
--   Holding E (your own screen): crouching and reaching for it, tugging harder as the hold fills; a Steal is sneaky
--     (looking about), a Hatch pats the blanket.
--   Knocked over: arms and legs flailing while you tumble, then dizzy for a moment when you get up.
--   Celebrating: arms up and two hops after a hatch in your home, a smaller one when you get a toy home.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local me = Players.LocalPlayer
local TAU = math.pi * 2
local NEAR = 160 -- only pose characters this close to the camera

local JOINTS = {
	"Root",
	"Waist",
	"Neck",
	"LeftShoulder",
	"RightShoulder",
	"LeftElbow",
	"RightElbow",
	"LeftHip",
	"RightHip",
	"LeftKnee",
	"RightKnee",
}
local PULL = { S = 0.65, M = 0.85, L = 1 } -- how hard each blanket size pulls
local RARE = { Rare = true, Epic = true, Legendary = true, Mythic = true, Secret = true }
local FALLEN = {
	[Enum.HumanoidStateType.PlatformStanding] = true,
	[Enum.HumanoidStateType.Physics] = true,
	[Enum.HumanoidStateType.FallingDown] = true,
	[Enum.HumanoidStateType.Ragdoll] = true,
}

type Rig = {
	player: Player,
	character: Model,
	humanoid: Humanoid,
	root: BasePart,
	joints: { [string]: Motor6D },
	written: { [Motor6D]: CFrame }, -- what we last wrote, and the extra turn in it
	extra: { [Motor6D]: CFrame },
	drag: number, -- pose weights, eased
	reach: number,
	tumble: number,
	dizzyUntil: number,
	cheerAt: number,
	cheerSize: number,
	yankAt: number,
	walk: number,
	lastPos: Vector3,
	speed: number,
	pull: number,
}

local rigs: { [Player]: Rig } = {}

-- your own hold on a prompt
local hold: { prompt: ProximityPrompt, at: number }? = nil

local function bump(u: number): number
	return math.sin(math.pi * math.clamp(u, 0, 1))
end

local function setup(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not humanoid or not root or humanoid.RigType ~= Enum.HumanoidRigType.R15 then
		return
	end
	local joints: { [string]: Motor6D } = {}
	for _, name in JOINTS do
		local found: Motor6D? = nil
		for _, d in character:GetDescendants() do
			if d:IsA("Motor6D") and d.Name == name then
				found = d
				break
			end
		end
		if not found then
			-- R15 parts arrive one by one; wait a little for the rest
			for _ = 1, 50 do
				task.wait(0.1)
				for _, d in character:GetDescendants() do
					if d:IsA("Motor6D") and d.Name == name then
						found = d
						break
					end
				end
				if found then
					break
				end
			end
		end
		if found then
			joints[name] = found
		end
	end
	if character.Parent == nil then
		return
	end
	rigs[player] = {
		player = player,
		character = character,
		humanoid = humanoid,
		root = root,
		joints = joints,
		written = {},
		extra = {},
		drag = 0,
		reach = 0,
		tumble = 0,
		dizzyUntil = 0,
		cheerAt = -100,
		cheerSize = 1,
		yankAt = -100,
		walk = 0,
		lastPos = root.Position,
		speed = 0,
		pull = 0.8,
	}
end

local function cheer(player: Player?, size: number)
	local rig = player and rigs[player]
	if rig and os.clock() - rig.cheerAt > 1 then
		rig.cheerAt = os.clock()
		rig.cheerSize = size
	end
end

-- An extra turn for each joint this frame (CFrames in the joint's own space: +X the character's right, +Y up,
-- -Z forward; for the shoulders and hips a +X turn swings the limb forward, a +Z turn swings the right one out)
local pose: { [string]: CFrame } = {}
local function add(name: string, cf: CFrame)
	local old = pose[name]
	pose[name] = if old then old * cf else cf
end

local function build(rig: Rig, now: number, dt: number)
	table.clear(pose)
	local t = now
	-- moving?
	local pos = rig.root.Position
	local flat = Vector3.new(pos.X - rig.lastPos.X, 0, pos.Z - rig.lastPos.Z).Magnitude / math.max(dt, 1 / 240)
	rig.lastPos = pos
	rig.speed += (flat - rig.speed) * math.min(1, dt * 8)
	local moving = math.clamp(rig.speed / 8, 0, 1)
	rig.walk += dt * (2 + rig.speed * 0.9)

	local state = rig.humanoid:GetState()
	local fallen = FALLEN[state] == true or rig.humanoid.PlatformStand
	local carrying = rig.player:GetAttribute("Carrying") ~= nil
	local size = rig.player:GetAttribute("CarrySize")
	rig.pull = PULL[if typeof(size) == "string" then size else "M"] or 0.85
	local holding = rig.player == me and hold ~= nil and not carrying

	local function ease(current: number, goal: number, rate: number): number
		return current + (goal - current) * math.min(1, dt * rate)
	end
	if rig.tumble > 0.5 and not fallen then
		rig.dizzyUntil = now + 1.3
	end
	rig.drag = ease(rig.drag, if carrying and not fallen then rig.pull else 0, 6)
	rig.reach = ease(rig.reach, if holding and not fallen then 1 else 0, 10)
	rig.tumble = ease(rig.tumble, if fallen then 1 else 0, 12)

	-- dragging: lean into it, arms back to the load, head up, a tug every step
	local w = rig.drag
	if w > 0.01 then
		local step = math.sin(rig.walk * 2)
		local lean = (0.22 + 0.16 * moving) * w
		add("Root", CFrame.new(0, -0.15 * w + 0.06 * math.abs(step) * moving * w, 0) * CFrame.Angles(-lean, 0, 0))
		add("Waist", CFrame.Angles(-0.1 * w, 0.08 * step * moving * w, 0))
		add("Neck", CFrame.Angles((0.28 + 0.1 * moving) * w, 0, 0))
		local tug = 0.15 * step * moving
		add("RightShoulder", CFrame.Angles((-1.05 + tug) * w, 0, 0.3 * w))
		add("LeftShoulder", CFrame.Angles((-1.05 - tug) * w, 0, -0.3 * w))
		add("RightElbow", CFrame.Angles(0.3 * w, 0, 0))
		add("LeftElbow", CFrame.Angles(0.3 * w, 0, 0))
	end

	-- just got hold of it: a yank back
	local yu = (now - rig.yankAt) / 0.45
	if yu >= 0 and yu < 1 then
		local e = bump(yu)
		add("Root", CFrame.Angles(0.22 * e, 0, 0))
		add("RightShoulder", CFrame.Angles(0.9 * e, 0, 0))
		add("LeftShoulder", CFrame.Angles(0.9 * e, 0, 0))
	end

	-- holding E: crouch and reach (your own screen)
	w = rig.reach
	if w > 0.01 then
		local h = hold
		local name = h and h.prompt.Name or ""
		local progress = 0
		if h and h.prompt.HoldDuration > 0 then
			progress = math.clamp((now - h.at) / h.prompt.HoldDuration, 0, 1)
		end
		local shake = math.sin(t * 28) * (0.04 + 0.12 * progress)
		add("Root", CFrame.new(0, -0.45 * w, 0))
		add("Waist", CFrame.Angles(-0.45 * w, 0, shake * w))
		add("RightHip", CFrame.Angles(0.55 * w, 0, 0))
		add("LeftHip", CFrame.Angles(0.55 * w, 0, 0))
		add("RightKnee", CFrame.Angles(-0.9 * w, 0, 0))
		add("LeftKnee", CFrame.Angles(-0.9 * w, 0, 0))
		local arm = 1.05
		if name == "HatchPrompt" then
			arm = 0.95 + 0.3 * math.abs(math.sin(t * 9)) -- pat pat
		else
			arm += shake * 2
		end
		add("RightShoulder", CFrame.Angles(arm * w, 0, 0.12 * w))
		add("LeftShoulder", CFrame.Angles(arm * w, 0, -0.12 * w))
		add("RightElbow", CFrame.Angles(0.25 * w, 0, 0))
		add("LeftElbow", CFrame.Angles(0.25 * w, 0, 0))
		if name == "StealPrompt" then
			-- sneaky: glancing over the shoulder
			add("Neck", CFrame.Angles(0.2 * w, math.sin(t * 2.6) * 0.7 * w, 0))
		else
			add("Neck", CFrame.Angles(-0.15 * w, 0, 0))
		end
	end

	-- knocked over: flailing
	w = rig.tumble
	if w > 0.01 then
		add("RightShoulder", CFrame.Angles(0.5 * math.sin(t * 13), 0, (1.5 + 0.35 * math.sin(t * 17)) * w))
		add("LeftShoulder", CFrame.Angles(0.5 * math.sin(t * 11 + 1), 0, -(1.5 + 0.35 * math.sin(t * 15)) * w))
		add("RightElbow", CFrame.Angles((0.6 + 0.4 * math.sin(t * 19)) * w, 0, 0))
		add("LeftElbow", CFrame.Angles((0.6 + 0.4 * math.sin(t * 21)) * w, 0, 0))
		add("RightHip", CFrame.Angles(0.4 * math.sin(t * 12) * w, 0, 0.45 * w))
		add("LeftHip", CFrame.Angles(0.4 * math.sin(t * 12 + math.pi) * w, 0, -0.45 * w))
		add("RightKnee", CFrame.Angles((-0.5 + 0.35 * math.sin(t * 14)) * w, 0, 0))
		add("LeftKnee", CFrame.Angles((-0.5 + 0.35 * math.sin(t * 16)) * w, 0, 0))
		add("Neck", CFrame.Angles(0.3 * math.sin(t * 7) * w, 0.35 * math.sin(t * 5) * w, 0))
	end
	-- back up, dizzy: the head goes round and he wobbles
	local dizzy = math.clamp((rig.dizzyUntil - now) / 1.3, 0, 1)
	if dizzy > 0 then
		local e = dizzy * (1 - w)
		add("Neck", CFrame.Angles(0.2 * math.sin(t * 9) * e, 0, 0.2 * math.cos(t * 9) * e))
		add("Root", CFrame.Angles(0, 0, 0.09 * math.sin(t * 6) * e))
		add("Waist", CFrame.Angles(0.06 * math.cos(t * 6) * e, 0, 0))
	end

	-- celebrating: arms up, two hops, a wiggle
	local cu = (now - rig.cheerAt) / (1.1 + 0.6 * rig.cheerSize)
	if cu >= 0 and cu < 1 then
		local e = math.min(1, cu * 8) * math.min(1, (1 - cu) * 5)
		local hops = if rig.cheerSize > 0.5 then 2 else 1
		local hop = math.abs(math.sin(cu * math.pi * hops)) * (0.6 + 0.6 * rig.cheerSize) * (1 - moving)
		local pump = math.sin(cu * TAU * 4)
		add("Root", CFrame.new(0, hop, 0))
		add("Waist", CFrame.Angles(-0.1 * e, 0.22 * math.sin(cu * TAU * 2) * e, 0))
		add("Neck", CFrame.Angles(0.3 * e, 0, 0))
		add("RightShoulder", CFrame.Angles(0.25 * pump * e, 0, (2.55 + 0.2 * pump) * e))
		add("LeftShoulder", CFrame.Angles(-0.25 * pump * e, 0, -(2.55 + 0.2 * pump) * e))
		add("RightElbow", CFrame.Angles(0.35 * e, 0, 0))
		add("LeftElbow", CFrame.Angles(0.35 * e, 0, 0))
		add("RightHip", CFrame.Angles(0.3 * hop, 0, 0))
		add("LeftHip", CFrame.Angles(0.3 * hop, 0, 0))
		add("RightKnee", CFrame.Angles(-0.5 * hop, 0, 0))
		add("LeftKnee", CFrame.Angles(-0.5 * hop, 0, 0))
	end
end

-- Put this frame's extras on the joints. The Animator rewrites a joint every frame it animates it; if it didn't
-- (nothing playing on that joint), take our last extra back off first so it never piles up.
local function apply(rig: Rig)
	for name, j in rig.joints do
		local extra = pose[name]
		local written = rig.written[j]
		if not extra and not written then
			continue
		end
		local base = j.Transform
		if written and base == written then
			base = base * (rig.extra[j] :: CFrame):Inverse()
		end
		if extra then
			local out = base * extra
			j.Transform = out
			rig.written[j] = out
			rig.extra[j] = extra
		else
			j.Transform = base
			rig.written[j] = nil
			rig.extra[j] = nil
		end
	end
end

local function watchPlayer(player: Player)
	if player.Character then
		task.spawn(setup, player, player.Character)
	end
	player.CharacterAdded:Connect(function(character)
		rigs[player] = nil
		setup(player, character)
	end)
	player.CharacterRemoving:Connect(function()
		rigs[player] = nil
	end)
	-- got hold of a toy: a yank; let go of it at home (not knocked over): a little cheer
	local was = player:GetAttribute("Carrying") ~= nil
	player:GetAttributeChangedSignal("Carrying"):Connect(function()
		local now = player:GetAttribute("Carrying") ~= nil
		local rig = rigs[player]
		if now and not was and rig then
			rig.yankAt = os.clock()
		elseif was and not now and rig and rig.tumble < 0.2 and not FALLEN[rig.humanoid:GetState()] then
			-- home? (their hole is the one they own; the drop button elsewhere doesn't count)
			local bedroom = Workspace:FindFirstChild("Bedroom")
			local holes = bedroom and bedroom:FindFirstChild("Holes")
			if holes then
				for _, hole in holes:GetChildren() do
					local pen = hole:FindFirstChild("Pen") :: BasePart?
					if hole:GetAttribute("Owner") == player.UserId and pen then
						if (pen.Position - rig.root.Position).Magnitude < 60 then
							cheer(player, 0.4)
						end
					end
				end
			end
		end
		was = now
	end)
end

-- A toy hatched into someone's pen: they cheer (bigger for Rare and up)
local function watchHomes()
	local bedroom = Workspace:WaitForChild("Bedroom")
	local holes = bedroom:WaitForChild("Holes")
	local function watchHole(hole: Instance)
		local penToys = hole:WaitForChild("PenToys", 30)
		if not penToys then
			return
		end
		penToys.ChildAdded:Connect(function(toy)
			task.defer(function()
				local at = toy:GetAttribute("RevealedAt")
				if typeof(at) == "number" and Workspace:GetServerTimeNow() - at < 4 then
					local owner = hole:GetAttribute("Owner")
					if typeof(owner) == "number" then
						local rarity = toy:GetAttribute("Rarity")
						-- after the toy's own hatch jump has started
						task.delay(0.5, cheer, Players:GetPlayerByUserId(owner), if RARE[rarity] then 1 else 0.7)
					end
				end
			end)
		end)
	end
	for _, hole in holes:GetChildren() do
		task.spawn(watchHole, hole)
	end
	holes.ChildAdded:Connect(watchHole)
end

for _, player in Players:GetPlayers() do
	watchPlayer(player)
end
Players.PlayerAdded:Connect(watchPlayer)
Players.PlayerRemoving:Connect(function(player)
	rigs[player] = nil
end)
task.spawn(watchHomes)

ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt)
	hold = { prompt = prompt, at = os.clock() }
end)
ProximityPromptService.PromptButtonHoldEnded:Connect(function()
	hold = nil
end)
ProximityPromptService.PromptTriggered:Connect(function()
	hold = nil
end)

-- Studio only, for captures: LocalPlayer:SetAttribute("AnimTest", "cheer" | "smallcheer" | "yank" | "dizzy")
if RunService:IsStudio() then
	me:GetAttributeChangedSignal("AnimTest"):Connect(function()
		local test = me:GetAttribute("AnimTest")
		local rig = rigs[me]
		if rig then
			if test == "cheer" or test == "smallcheer" then
				rig.cheerAt = -100
				cheer(me, if test == "cheer" then 1 else 0.4)
			elseif test == "yank" then
				rig.yankAt = os.clock()
			elseif test == "dizzy" then
				rig.dizzyUntil = os.clock() + 1.3
			end
		end
		me:SetAttribute("AnimTest", nil)
	end)
end

local last = os.clock()
RunService.PreSimulation:Connect(function()
	local now = os.clock()
	local dt = math.min(now - last, 0.1)
	last = now
	local cam = Workspace.CurrentCamera
	local eye = if cam then cam.CFrame.Position else Vector3.zero
	for player, rig in rigs do
		if not rig.character.Parent then
			rigs[player] = nil
			continue
		end
		if (rig.root.Position - eye).Magnitude > NEAR then
			continue
		end
		build(rig, now, dt)
		apply(rig)
	end
end)
