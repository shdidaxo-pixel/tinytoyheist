--!strict
-- Moves the cat smoothly toward where the server says it is (its "Pose" attribute) and animates it:
--   Prowling (Patrol): the legs walk in diagonal pairs as fast as it's moving, the body bobs and rolls a little at
--     the shoulders, the tail sways and curls from its base, the head looks about, an ear flicks now and then.
--   Stalking: low to the floor, head locked forward, tail tip twitching, and the butt wiggles before it pounces.
--   Pounce: front legs reach forward and back legs kick out in the air; it lands in a crouch with a puff of dust.
--   Grooming (Rest after a pounce, and Groom now and then on patrol): crouched, one front paw up, licking it, now and
--     then rubbing it over an ear, the tail curled round.
--   Lights on (Aggressive): ears flat back, tail up and bristling, and the red "!".
-- Every part is placed from its rest offset each frame (relative to the cat's Root), so nothing drifts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MapConfig = require(Shared:WaitForChild("MapConfig")) :: any

local CatView = {}
local S = MapConfig.SCALE -- the cat was built full size and shrunk with the room

-- Joints in the cat's own space (Root at the origin, +X forward, +Y up), from the builder's sizes
local HIPS = {
	{ x = -26 * S, z = -11 * S, phase = 0 },
	{ x = -26 * S, z = 11 * S, phase = math.pi },
	{ x = 24 * S, z = -11 * S, phase = math.pi },
	{ x = 24 * S, z = 11 * S, phase = 0 },
}
local HIP_Y = 15.5 * S
local NECK = CFrame.new(30 * S, 39.5 * S, 0)
local TAIL_BASE = CFrame.new(-34 * S, 29.5 * S, 0)
local BACK_HIP = CFrame.new(-26 * S, HIP_Y, 0)
local FRONT_HIP = CFrame.new(24 * S, HIP_Y, 0)
local HEAD_PARTS = { Head = true, Muzzle = true, Nose = true, Eye = true, Pupil = true, Whisker = true }
local GROOM_PAW = 4 -- the front leg it licks

-- The VFX session's effects library, if it's there (the landing puff)
local VFX: any = nil
task.spawn(function()
	local m = Shared:WaitForChild("VFX", 30)
	if m and m:IsA("ModuleScript") then
		local ok, lib = pcall(require, m)
		if ok then
			VFX = lib
		end
	end
end)

type Piece = { part: BasePart, offset: CFrame, kind: string, index: number, base: CFrame? }

function CatView.start(bedroom: Model)
	local cat = bedroom:WaitForChild("Hazards"):WaitForChild("Cat") :: Model
	local head = cat:WaitForChild("Head")
	local alert = head:WaitForChild("Alert") :: BillboardGui
	local pivot = cat:GetPivot()

	local pieces: { Piece } = {}
	local tailLinks = {}
	for _, p in cat:GetChildren() do
		if not p:IsA("BasePart") or p.Name == "Root" then
			continue
		end
		local offset = pivot:ToObjectSpace(p.CFrame)
		local kind, index = "Body", 0
		local base: CFrame? = nil
		if p.Name == "Leg" or p.Name == "Paw" then
			kind = "Leg"
			local best = math.huge
			for k, hip in HIPS do
				local d = (Vector3.new(hip.x, 0, hip.z) - Vector3.new(offset.X, 0, offset.Z)).Magnitude
				if d < best then
					best, index = d, k
				end
			end
		elseif p.Name == "Ear" then
			kind = "Ear"
			-- turns about its base
			base = CFrame.new(offset.X, offset.Y - p.Size.Y / 2, offset.Z)
			index = if offset.Z < 0 then -1 else 1
		elseif HEAD_PARTS[p.Name] then
			kind = "Head"
		elseif p.Name == "Tail" then
			kind = "Tail"
			table.insert(tailLinks, offset.X)
		elseif p.Name == "Bell" or p.Name == "Collar" then
			kind = "Collar"
		end
		table.insert(pieces, { part = p, offset = offset, kind = kind, index = index, base = base })
	end
	-- number the tail links from the base outward
	table.sort(tailLinks, function(a, b)
		return a > b
	end)
	for _, piece in pieces do
		if piece.kind == "Tail" then
			piece.index = table.find(tailLinks, piece.offset.X) or 1
		end
	end

	local current = pivot
	local lastPosition = pivot.Position
	local speed, stride, lookYaw = 0, 0, 0
	local crouch, crouchV = 0, 0
	local groom, angry, air = 0, 0, 0
	local lastState: any = nil
	local flickAt, nextFlick = -100, os.clock() + 3
	RunService.RenderStepped:Connect(function(dt)
		dt = math.min(dt, 0.1)
		local pose = cat:GetAttribute("Pose")
		if typeof(pose) == "CFrame" then
			current = current:Lerp(pose, 1 - math.exp(-dt * 12))
		end
		local moved = (Vector3.new(current.X, 0, current.Z) - Vector3.new(lastPosition.X, 0, lastPosition.Z)).Magnitude
		lastPosition = current.Position
		speed += (moved / math.max(dt, 1e-3) - speed) * math.min(1, dt * 8)
		stride += dt * (1.5 + speed * 0.35 / S)
		local t = os.clock()
		local state = cat:GetAttribute("State")
		local hunting = state == "Stalk" or state == "Pounce"
		local walking = math.clamp(speed / (10 * S), 0, 1)

		-- landing a pounce: a deep crouch that springs back, and a puff
		if lastState == "Pounce" and state ~= "Pounce" then
			crouchV += 9
			if VFX then
				pcall(VFX.burst, "Poof", current.Position - Vector3.new(0, current.Y, 0), { scale = 2.5 })
			end
		end
		lastState = state

		-- crouch low while stalking, spring up on the pounce (a spring, so the landing bounces)
		local wantCrouch = if state == "Stalk" then 1 elseif state == "Pounce" then -0.5 else 0
		crouchV += ((wantCrouch - crouch) * 90 - crouchV * 11) * dt
		crouch += crouchV * dt
		local wantGroom = if (state == "Rest" or state == "Groom") and walking < 0.3 then 1 else 0
		groom += (wantGroom - groom) * math.min(1, dt * 5)
		angry += ((if cat:GetAttribute("Aggressive") == true then 1 else 0) - angry) * math.min(1, dt * 4)
		air += ((if state == "Pounce" then 1 else 0) - air) * math.min(1, dt * 14)

		local bob = (math.abs(math.sin(stride * 2)) * 1.2 * walking - crouch * 4 - groom * 2.5) * S
		local breathe = math.sin(t * 2) * 0.4 * S
		local body = current * CFrame.new(0, bob + breathe * (1 - walking), 0)
		-- prowl: the shoulders roll as it walks
		body *= FRONT_HIP * CFrame.Angles(math.sin(stride) * 0.05 * walking, 0, 0) * FRONT_HIP:Inverse()
		-- stalking and nearly still: the butt wiggle
		if state == "Stalk" then
			local wiggle = math.sin(t * 13) * 0.07 * (1 - walking * 0.7)
			body *= FRONT_HIP * CFrame.Angles(0, wiggle, 0) * FRONT_HIP:Inverse()
		end
		-- grooming: the front dips toward the paw
		body *= BACK_HIP * CFrame.Angles(0, 0, -0.15 * groom) * BACK_HIP:Inverse()

		-- the head: looks around on patrol, locks forward when hunting, licks the paw while grooming
		local wantYaw = if hunting then 0 else math.sin(t * 0.7) * 0.35
		lookYaw += (wantYaw - lookYaw) * math.min(1, dt * 4)
		local rub = math.max(0, math.sin(t * 0.9)) ^ 4 -- now and then the paw goes over the ear
		local lick = math.sin(t * 11) * 0.1
		local neck = NECK
			* CFrame.Angles(0, lookYaw * (1 - groom) + 0.35 * groom, math.sin(stride * 2) * 0.04 * walking)
			* CFrame.Angles(0.35 * rub * groom, 0, (-0.6 + lick) * groom - 0.12 * crouch)
			* NECK:Inverse()

		-- an ear flick now and then
		if t >= nextFlick then
			flickAt = t
			nextFlick = t + 2 + math.random() * 5
		end
		local flick = math.sin(math.clamp((t - flickAt) / 0.25, 0, 1) * math.pi)

		for _, piece in pieces do
			local cf
			if piece.kind == "Leg" then
				local hip = HIPS[piece.index]
				local swing = math.sin(stride + hip.phase) * 0.55 * walking
				local front = hip.x > 0
				-- in the air: front legs reach forward, back legs kick back
				swing += (if front then 0.9 else -0.8) * air
				-- landing crouch: legs splay a little
				swing += (if front then -0.25 else 0.25) * math.max(0, crouch - 1)
				if piece.index == GROOM_PAW then
					swing += (2.3 + 0.4 * rub + 0.12 * math.sin(t * 11)) * groom
				end
				local joint = CFrame.new(hip.x, HIP_Y, hip.z)
				-- legs stay on the floor while the body bobs: hang them from the un-bobbed frame
				cf = current * joint * CFrame.Angles(0, 0, swing) * joint:Inverse() * piece.offset
			elseif piece.kind == "Head" then
				cf = body * neck * piece.offset
			elseif piece.kind == "Ear" then
				local b = piece.base :: CFrame
				-- flat back when the lights are on; a flick otherwise
				local back = 0.9 * angry + 0.5 * flick * (if piece.index > 0 then 1 else 0) * (1 - angry)
				cf = body * neck * b * CFrame.Angles(piece.index * 0.2 * angry, 0, back) * b:Inverse() * piece.offset
			elseif piece.kind == "Tail" then
				-- each link adds a little more bend, so the tail curls from its base
				local k = piece.index
				local sway = math.sin(t * (if hunting then 5 else 2.2) - k * 0.55) * (0.09 + k * 0.035)
				-- stalking: only the tip twitches; angry: straight up and bristling; grooming: curled round
				if state == "Stalk" then
					sway = math.sin(t * 9 - k) * 0.03 * k
				end
				sway += math.sin(t * 40 + k) * 0.02 * angry + 0.12 * groom
				local lift = 0.05 * k + (if hunting then 0.12 else 0) + 0.12 * angry - 0.06 * groom
				cf = body * TAIL_BASE * CFrame.Angles(0, sway * k * 0.6, lift) * TAIL_BASE:Inverse() * piece.offset
			elseif piece.kind == "Collar" then
				cf = body * neck * piece.offset * CFrame.new(0, math.sin(t * 6) * 0.3 * walking, 0)
			else
				cf = body * piece.offset
			end
			piece.part.CFrame = cf
		end
		(cat.PrimaryPart :: BasePart).CFrame = current

		alert.Enabled = cat:GetAttribute("Aggressive") == true or hunting
	end)
end

return CatView
