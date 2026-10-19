--!strict
-- Moves the cat smoothly toward where the server says it is (its "Pose" attribute) and animates it: the legs walk in
-- diagonal pairs as fast as it's moving, the body bobs, the tail sways and curls from its base, the head looks about
-- while it patrols and locks on while it hunts, and it crouches as it lands a pounce. Shows the red "!" when hunting.
-- Every part is placed from its rest offset each frame (relative to the cat's Root), so nothing drifts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MapConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MapConfig")) :: any

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
local HEAD_PARTS = { Head = true, Muzzle = true, Nose = true, Ear = true, Eye = true, Pupil = true, Whisker = true }

type Piece = { part: BasePart, offset: CFrame, kind: string, index: number }

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
		if p.Name == "Leg" or p.Name == "Paw" then
			kind = "Leg"
			local best = math.huge
			for k, hip in HIPS do
				local d = (Vector3.new(hip.x, 0, hip.z) - Vector3.new(offset.X, 0, offset.Z)).Magnitude
				if d < best then
					best, index = d, k
				end
			end
		elseif HEAD_PARTS[p.Name] then
			kind = "Head"
		elseif p.Name == "Tail" then
			kind = "Tail"
			table.insert(tailLinks, offset.X)
		elseif p.Name == "Bell" or p.Name == "Collar" then
			kind = "Collar"
		end
		table.insert(pieces, { part = p, offset = offset, kind = kind, index = index })
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
	local crouch = 0
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

		-- crouch low while stalking, spring up on the pounce
		local wantCrouch = if state == "Stalk" then 1 elseif state == "Pounce" then -0.5 else 0
		crouch += (wantCrouch - crouch) * math.min(1, dt * 6)
		local bob = (math.abs(math.sin(stride * 2)) * 1.2 * walking - crouch * 4) * S
		local breathe = math.sin(t * 2) * 0.4 * S
		local body = current * CFrame.new(0, bob + breathe * (1 - walking), 0)

		-- the head: looks around on patrol, locks forward when hunting
		local wantYaw = if hunting then 0 else math.sin(t * 0.7) * 0.35
		lookYaw += (wantYaw - lookYaw) * math.min(1, dt * 4)
		local neck = NECK * CFrame.Angles(0, lookYaw, math.sin(stride * 2) * 0.04 * walking) * NECK:Inverse()

		for _, piece in pieces do
			local cf
			if piece.kind == "Leg" then
				local hip = HIPS[piece.index]
				local swing = math.sin(stride + hip.phase) * 0.55 * walking
				local joint = CFrame.new(hip.x, HIP_Y, hip.z)
				-- legs stay on the floor while the body bobs: hang them from the un-bobbed frame
				cf = current * joint * CFrame.Angles(0, 0, swing) * joint:Inverse() * piece.offset
			elseif piece.kind == "Head" then
				cf = body * neck * piece.offset
			elseif piece.kind == "Tail" then
				-- each link adds a little more bend, so the tail curls from its base
				local k = piece.index
				local sway = math.sin(t * (if hunting then 5 else 2.2) - k * 0.55) * (0.09 + k * 0.035)
				local lift = 0.05 * k + (if hunting then 0.12 else 0)
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
