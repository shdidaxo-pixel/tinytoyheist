--!strict
-- The Giant Kid, on each screen. The server decides what he does (ServerScriptService.Bedroom.Giant); this shows it.
--   Asleep: he breathes, a snot bubble grows and pops, Zs drift up, his arm dangles off the bed. The fuller the wake
--     meter, the more restless he gets: the arm swings more and now and then he tosses.
--   Sitting up (flashlight at 80 on the meter, or Stirring / Awake): he springs up from the pillow, yawns if he's
--     waking, then sweeps the flashlight down the run (aimed where the server checks it, MapConfig.flashlightTarget
--     on the server clock): his arm points the torch, his head and shoulders turn to follow the beam.
--   Out of bed (Walking): he pushes himself up, stomps (the floor shakes near you, dust at his feet), looks at the
--     nearest mouse, and when he grabs someone (GrabAt) he bends down, scoops, and lifts.
--   Back to bed: he lies back down before the sleeping pose comes back.
-- Every moving part is placed from its rest position each frame, so nothing drifts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MapConfig = require(Shared:WaitForChild("MapConfig")) :: any

local KidView = {}
local S = MapConfig.SCALE -- the Kid was built full size and shrunk with the room

-- the lying-down parts that hide when he sits up (the lump under the duvet stays: his legs)
local LYING = {
	Head = true,
	Hair = true,
	Tuft = true,
	Sleeve = true,
	Forearm = true,
	Hand = true,
	Finger = true,
	Thumb = true,
	Bubble = true,
	Zzz = true,
}
local DANGLE = { Sleeve = true, Forearm = true, Hand = true, Finger = true, Thumb = true }
local SLEEP_HEAD = { Head = true, Hair = true, Tuft = true }
local RECLINE = 0.95 -- how far back he lies when he starts to sit up (radians)
local RISE = 0.75 -- seconds to sit up
local LIE = 0.8 -- seconds to lie back down
local GET_UP = 1 -- seconds to push himself up out of bed
local GRAB = 1.3 -- seconds of the grab

-- The VFX session's effects library, if it's there (stomps)
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

local function setShown(part: Instance, visible: boolean)
	if part:IsA("BasePart") then
		if part:GetAttribute("Solid") == nil then
			part:SetAttribute("Solid", part.CanCollide)
		end
		local shown = (part:GetAttribute("Shown") :: number?) or 0
		part.Transparency = if visible then shown else 1
		part.CanCollide = visible and (part:GetAttribute("Solid") :: boolean)
	end
	for _, d in part:GetDescendants() do
		if d:IsA("SurfaceGui") or d:IsA("BillboardGui") then
			d.Enabled = visible
		elseif d:IsA("BasePart") then
			setShown(d, visible)
		end
	end
end

local function smooth(u: number): number
	u = math.clamp(u, 0, 1)
	return u * u * (3 - 2 * u)
end
local function bump(u: number): number
	return math.sin(math.pi * math.clamp(u, 0, 1))
end
-- ease out with a little overshoot (0 -> 1)
local function backOut(u: number): number
	u = math.clamp(u, 0, 1) - 1
	return 1 + 2.4 * u * u * u + 1.4 * u * u
end

type Rest = { part: BasePart, rest: CFrame }

function KidView.start(bedroom: Model)
	local kid = bedroom:WaitForChild("GiantKid") :: Model
	local asleep = kid:WaitForChild("Asleep")
	local sitUp = kid:WaitForChild("SitUp")
	local flashlight = sitUp:WaitForChild("Flashlight") :: Model
	local pool = sitUp:WaitForChild("BeamPool") :: BasePart
	local poolLight = sitUp:WaitForChild("BeamLight") :: BasePart
	local beam = pool:WaitForChild("Beam") :: Beam
	local spot = poolLight:FindFirstChildOfClass("SpotLight")
	local upper = asleep:WaitForChild("BodyUpper") :: BasePart
	local bubble = asleep:WaitForChild("Bubble") :: BasePart
	local zzz = asleep:WaitForChild("Zzz") :: BasePart

	local upperRest = upper.CFrame
	local bubbleRest = bubble.CFrame
	local flashRest = flashlight:GetPivot()
	local poolTurn = pool.CFrame - pool.CFrame.Position

	-- the sleeping arm that dangles off the bed, and the sleeping head
	local dangle: { Rest } = {}
	local sleepHead: { Rest } = {}
	local dangleTop = -math.huge
	local dangleAt = Vector3.zero
	for _, p in asleep:GetChildren() do
		if p:IsA("BasePart") and DANGLE[p.Name] then
			table.insert(dangle, { part = p, rest = p.CFrame })
			if p.Position.Y + p.Size.Y / 2 > dangleTop then
				dangleTop = p.Position.Y + p.Size.Y / 2
				dangleAt = p.Position
			end
		elseif p:IsA("BasePart") and SLEEP_HEAD[p.Name] then
			table.insert(sleepHead, { part = p, rest = p.CFrame })
		end
	end
	local shoulderAsleep = Vector3.new(dangleAt.X, dangleTop, dangleAt.Z)

	-- the sitting-up body: torso, head, the arm with the torch; and the joints they turn about
	local sitBody: { Rest } = {}
	local sitHead: { Rest } = {}
	local sitArm: { Rest } = {}
	local torsoLow, torsoHigh = math.huge, -math.huge
	local torsoAt = Vector3.zero
	local armPart: BasePart? = nil
	local handPart: BasePart? = nil
	for _, p in sitUp:GetChildren() do
		if not p:IsA("BasePart") or p == pool or p == poolLight then
			continue
		end
		if p.Name == "Torso" then
			torsoLow = math.min(torsoLow, p.Position.Y - p.Size.Y / 2)
			torsoHigh = math.max(torsoHigh, p.Position.Y + p.Size.Y / 2)
			torsoAt = p.Position
			table.insert(sitBody, { part = p, rest = p.CFrame })
		elseif p.Name == "Head" or p.Name == "Hair" then
			table.insert(sitHead, { part = p, rest = p.CFrame })
		elseif p.Name == "Arm" or p.Name == "Hand" then
			table.insert(sitArm, { part = p, rest = p.CFrame })
			if p.Name == "Arm" then
				armPart = p
			else
				handPart = p
			end
		else
			table.insert(sitBody, { part = p, rest = p.CFrame })
		end
	end
	local hip = Vector3.new(torsoAt.X, torsoLow, torsoAt.Z)
	local neck = Vector3.new(torsoAt.X, torsoHigh, torsoAt.Z)
	local shoulder = neck
	if armPart and handPart then
		local along = armPart.Position - handPart.Position
		along = Vector3.new(along.X, 0, along.Z)
		local half = math.max(armPart.Size.X, armPart.Size.Z) / 2
		shoulder = armPart.Position + (if along.Magnitude > 0.01 then along.Unit * half else Vector3.zero)
	end

	-- the walking Kid's parts, with their rest offsets from his Root and which bit they are
	local walker = kid:WaitForChild("Walker") :: Model
	local walkerRoot = walker.PrimaryPart :: BasePart
	local lumps = { asleep:WaitForChild("BodyLower"), upper }
	local limbs: { { part: BasePart, offset: CFrame, kind: string, side: number } } = {}
	for _, p in walker:GetChildren() do
		if p:IsA("BasePart") and p ~= walkerRoot then
			local offset = walkerRoot.CFrame:ToObjectSpace(p.CFrame)
			local kind = if p.Name == "Leg" or p.Name == "Foot"
				then "Leg"
				elseif p.Name == "Arm" or p.Name == "Hand" then "Arm"
				elseif p.Name == "Head" or p.Name == "Hair" or p.Name == "Tuft" then "Head"
				else "Body"
			table.insert(limbs, { part = p, offset = offset, kind = kind, side = if offset.X < 0 then -1 else 1 })
		end
	end
	local HIP_Y, SHOULDER_Y, NECK_Y = 86 * S, 156 * S, 166 * S
	local walkerCurrent = walkerRoot.CFrame
	local lastWalker = walkerCurrent.Position
	local stride, speed = 0, 0
	local lastStep = 0
	local headYaw = 0

	-- what's showing: "lying", "rising", "sitting", "lowering" or "walking"
	local mode = "lying"
	local modeAt = 0
	local lowerFrom = 0 -- the recline when he started to lie down
	local wakeAt = -100 -- when he started stirring (for the yawn)
	local lastState: any = nil
	local walkAt = -100
	local tossAt = -100
	local nextToss = os.clock() + 8
	local look, lookPitch, twist = 0, 0, 0

	local function showLying()
		for _, p in sitUp:GetChildren() do
			setShown(p, false)
		end
		for _, p in asleep:GetChildren() do
			if LYING[p.Name] then
				setShown(p, true)
			end
		end
		for _, p in lumps do
			setShown(p, true)
		end
		for _, p in walker:GetChildren() do
			if p ~= walkerRoot then
				setShown(p, false)
			end
		end
	end
	local function showSitting()
		for _, p in sitUp:GetChildren() do
			setShown(p, true)
		end
		for _, p in asleep:GetChildren() do
			if LYING[p.Name] then
				setShown(p, false)
			end
		end
		for _, p in lumps do
			setShown(p, true)
		end
		for _, p in walker:GetChildren() do
			if p ~= walkerRoot then
				setShown(p, false)
			end
		end
	end
	local function showWalking()
		for _, p in sitUp:GetChildren() do
			setShown(p, false)
		end
		for _, p in asleep:GetChildren() do
			if LYING[p.Name] then
				setShown(p, false)
			end
		end
		for _, p in lumps do
			setShown(p, false) -- out of bed, the duvet lies flat
		end
		for _, p in walker:GetChildren() do
			if p ~= walkerRoot then
				setShown(p, true)
			end
		end
	end
	local function setBeam(on: boolean)
		beam.Enabled = on
		if spot then
			spot.Enabled = on
		end
	end

	local function refresh()
		local isWalking = kid:GetAttribute("Walking") == true
		local wantUp = not isWalking
			and (kid:GetAttribute("State") ~= "Asleep" or kid:GetAttribute("Flashlight") == true)
		local now = os.clock()
		if isWalking then
			if mode ~= "walking" then
				mode, modeAt = "walking", now
				walkAt = now
				local pose = kid:GetAttribute("WalkerPose")
				if typeof(pose) == "CFrame" then
					walkerCurrent = pose
					lastWalker = pose.Position
				end
				showWalking()
				setBeam(false)
			end
		elseif wantUp then
			if mode == "lying" or mode == "lowering" then
				mode, modeAt = "rising", now
				showSitting()
				setBeam(false)
			elseif mode == "walking" then
				mode, modeAt = "sitting", now
				showSitting()
				setBeam(true)
			end
		else
			if mode == "sitting" or mode == "rising" or mode == "walking" then
				lowerFrom = if mode == "rising" then RECLINE * (1 - backOut((now - modeAt) / RISE)) else 0
				mode, modeAt = "lowering", now
				showSitting()
				setBeam(false)
			end
		end
		local state = kid:GetAttribute("State")
		if state == "Stirring" and lastState ~= "Stirring" then
			wakeAt = now
		end
		lastState = state
	end
	showLying()
	setBeam(false)
	refresh()
	kid:GetAttributeChangedSignal("State"):Connect(refresh)
	kid:GetAttributeChangedSignal("Flashlight"):Connect(refresh)
	kid:GetAttributeChangedSignal("Walking"):Connect(refresh)

	-- place the sitting-up body: reclined by `recline`, turned by `turn`, head and torch following the beam
	local function poseSitting(recline: number, target: Vector3?, dt: number, now: number)
		-- turn toward the beam
		local wantLook, wantPitch, wantTwist = 0, -0.15, 0
		if target then
			local d = target - neck
			wantLook = math.clamp(math.atan2(-d.X, -d.Z), -0.9, 0.9)
			wantPitch = math.clamp(math.atan2(d.Y, Vector3.new(d.X, 0, d.Z).Magnitude) * 0.5, -0.45, 0.1)
			wantTwist = wantLook * 0.3
		end
		-- the yawn as he wakes
		local yawn = bump((now - wakeAt - RISE) / 1.6)
		wantPitch += 0.45 * yawn
		look += (wantLook - look) * math.min(1, dt * 5)
		lookPitch += (wantPitch - lookPitch) * math.min(1, dt * 5)
		twist += (wantTwist - twist) * math.min(1, dt * 3)
		local body = CFrame.new(hip)
			* CFrame.Angles(0, twist, 0)
			* CFrame.Angles(recline + 0.1 * yawn, 0, 0)
			* CFrame.new(-hip)
		for _, r in sitBody do
			r.part.CFrame = body * r.rest
		end
		local headTurn = CFrame.new(neck)
			* CFrame.Angles(0, look - twist, 0)
			* CFrame.Angles(lookPitch, 0, 0)
			* CFrame.new(-neck)
		for _, r in sitHead do
			r.part.CFrame = body * headTurn * r.rest
		end
		-- the torch arm points at the beam (its rest points straight ahead, -Z)
		local arm = CFrame.identity
		if target then
			local from = body * shoulder
			local d = target - from
			local yaw = math.atan2(-d.X, -d.Z) - twist
			local pitch = math.atan2(d.Y, Vector3.new(d.X, 0, d.Z).Magnitude) - recline
			arm = CFrame.new(shoulder) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0) * CFrame.new(-shoulder)
		else
			arm = CFrame.new(shoulder) * CFrame.Angles(-0.6, 0, 0) * CFrame.new(-shoulder)
		end
		for _, r in sitArm do
			r.part.CFrame = body * arm * r.rest
		end
		flashlight:PivotTo(body * arm * flashRest)
	end

	-- When he grabs someone: the server's time of the grab
	local grabAt = -100
	kid:GetAttributeChangedSignal("GrabAt"):Connect(function()
		local at = kid:GetAttribute("GrabAt")
		if typeof(at) == "number" then
			grabAt = os.clock() - math.max(0, Workspace:GetServerTimeNow() - at)
		end
	end)

	RunService.RenderStepped:Connect(function(dt)
		dt = math.min(dt, 0.1)
		local t = Workspace:GetServerTimeNow()
		local now = os.clock()
		if mode == "walking" then
			-- stomp along: lerp to the server's pose, legs and arms swinging, the body bobbing
			local pose = kid:GetAttribute("WalkerPose")
			if typeof(pose) == "CFrame" then
				walkerCurrent = walkerCurrent:Lerp(pose, 1 - math.exp(-dt * 8))
			end
			local moved = (walkerCurrent.Position - lastWalker).Magnitude
			lastWalker = walkerCurrent.Position
			speed += (moved / math.max(dt, 1e-3) - speed) * math.min(1, dt * 6)
			stride += dt * (1 + speed * 0.12 / S)
			local amount = math.clamp(speed / (8 * S), 0, 1)
			local bob = math.abs(math.sin(stride * 2)) * 4 * S * amount

			-- getting out of bed: bent over, pushing up
			local up = smooth((now - walkAt) / GET_UP)
			-- grabbing: bend down and scoop (0..0.4), lift (0.4..1)
			local g = (now - grabAt) / GRAB
			local bend, reach = (1 - up) * 0.55, (1 - up) * 0.6
			if g >= 0 and g < 1 then
				local down = if g < 0.4 then smooth(g / 0.4) else 1 - smooth((g - 0.4) / 0.35)
				bend += 0.7 * down
				reach += 1.5 * down + (if g >= 0.4 then 2.2 * bump((g - 0.4) / 0.6) else 0)
				amount *= 1 - down
			end
			-- a foot comes down: the floor shakes near you, dust at his feet
			local stepIndex = math.floor(stride / math.pi)
			if stepIndex ~= lastStep then
				lastStep = stepIndex
				if amount > 0.3 and VFX then
					local cam = Workspace.CurrentCamera
					local d = if cam then (cam.CFrame.Position - walkerCurrent.Position).Magnitude else 1e9
					if d < 200 then
						pcall(VFX.shake, 0.25 * (1 - d / 200), 0.25)
					end
					local side = if stepIndex % 2 == 0 then -1 else 1
					pcall(VFX.burst, "Poof", (walkerCurrent * CFrame.new(side * 20 * S, 0, -8 * S)).Position, {
						scale = 3,
					})
				end
			end
			-- look at the nearest mouse
			local wantYaw = 0
			local best = 90
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root then
					local local_ = walkerCurrent:PointToObjectSpace(root.Position)
					local d = Vector3.new(local_.X, 0, local_.Z).Magnitude
					if d < best and local_.Z < 0 then
						best = d
						wantYaw = math.clamp(math.atan2(-local_.X, -local_.Z), -0.8, 0.8)
					end
				end
			end
			if best >= 90 then
				wantYaw = math.sin(t * 0.9) * 0.5 -- searching
			end
			-- lights on: his head follows his eyes round the room (Giant.GAZE, drawn by LightsOnView)
			local gazeAt = kid:GetAttribute("GazeAt")
			if kid:GetAttribute("Gaze") == true and typeof(gazeAt) == "Vector3" then
				local seen = walkerCurrent:PointToObjectSpace(gazeAt)
				wantYaw = math.clamp(math.atan2(-seen.X, -seen.Z), -1.2, 1.2)
			end
			headYaw += (wantYaw - headYaw) * math.min(1, dt * (if kid:GetAttribute("Gaze") then 8 else 4))

			walkerRoot.CFrame = walkerCurrent
			local hipCf = CFrame.new(0, HIP_Y, 0)
			local upperBody = walkerCurrent
				* CFrame.new(0, bob, 0)
				* hipCf
				* CFrame.Angles(-bend, 0, math.sin(stride) * 0.04 * amount)
				* hipCf:Inverse()
			for _, limb in limbs do
				local cf
				if limb.kind == "Leg" then
					local legHip = CFrame.new(limb.side * 20 * S, HIP_Y, 0)
					cf = walkerCurrent
						* legHip
						* CFrame.Angles(math.sin(stride + (limb.side + 1) * 0.5 * math.pi) * 0.45 * amount, 0, 0)
						* legHip:Inverse()
						* limb.offset
				elseif limb.kind == "Arm" then
					local shoulderCf = CFrame.new(limb.side * 53 * S, SHOULDER_Y, 0)
					local swing = -math.sin(stride + (limb.side + 1) * 0.5 * math.pi) * 0.5 * amount
					cf = upperBody
						* shoulderCf
						* CFrame.Angles(swing + reach, 0, -limb.side * 0.15 * math.min(reach, 1))
						* shoulderCf:Inverse()
						* limb.offset
				elseif limb.kind == "Head" then
					local neckCf = CFrame.new(0, NECK_Y, 0)
					cf = upperBody
						* neckCf
						* CFrame.Angles(0, headYaw, 0)
						* CFrame.Angles(0.3 * bend, 0, 0)
						* neckCf:Inverse()
						* limb.offset
				else
					cf = upperBody * limb.offset
				end
				limb.part.CFrame = cf
			end
		elseif mode == "rising" or mode == "sitting" or mode == "lowering" then
			local recline = 0
			if mode == "rising" then
				local u = (now - modeAt) / RISE
				recline = RECLINE * (1 - backOut(u))
				if u >= 1 then
					mode = "sitting"
					setBeam(true)
				end
			elseif mode == "lowering" then
				local u = (now - modeAt) / LIE
				recline = lowerFrom + (RECLINE - lowerFrom) * smooth(u)
				if u >= 1 then
					mode = "lying"
					showLying()
					setBeam(false)
				end
			end
			local target = if mode == "sitting" then MapConfig.flashlightTarget(t) else nil
			if mode ~= "lying" then
				poseSitting(recline, target, dt, now)
			end
			if target then
				pool.CFrame = CFrame.new(target + Vector3.new(0, 0.35, 0)) * poolTurn
				poolLight.CFrame = CFrame.new(target + Vector3.new(0, 45, 0))
			end
		else
			-- asleep: breathing, the snot bubble, the Zs, the dangling arm; restless as the meter fills
			local meter = (kid:GetAttribute("WakeMeter") :: number?) or 0
			local restless = math.clamp(meter / 80, 0, 1)
			if now >= nextToss then
				tossAt = now
				nextToss = now + (14 - 10 * restless) * (0.7 + math.random() * 0.6)
			end
			local toss = bump((now - tossAt) / 1.4)
			upper.CFrame = upperRest
				* CFrame.new(0, math.sin(t * 1.2) * 0.9 + toss * 2.5, 0)
				* CFrame.Angles(0, 0, math.sin((now - tossAt) * 7) * 0.06 * toss)
			local headTurn = CFrame.new(0, math.sin(t * 1.2 - 0.4) * 0.5, 0)
				* CFrame.Angles(0, math.sin((now - tossAt) * 5) * 0.12 * toss, 0)
			for _, r in sleepHead do
				r.part.CFrame = r.rest * headTurn
			end
			local swing = math.sin(t * 0.8) * (0.04 + 0.1 * restless) + toss * 0.25 * math.sin((now - tossAt) * 6)
			local twitch = if restless > 0.5 then math.max(0, math.sin(t * 3.7)) ^ 12 * 0.12 * restless else 0
			local hang = CFrame.new(shoulderAsleep)
				* CFrame.Angles(swing + twitch, 0, math.sin(t * 0.6) * 0.05)
				* CFrame.new(-shoulderAsleep)
			for _, r in dangle do
				r.part.CFrame = hang * r.rest
			end
			local p = (t * 0.32) % 1
			local r = if p < 0.9 then 0.6 + p * 7 else 0.05
			bubble.Size = Vector3.one * r * 2
			bubble.CFrame = bubbleRest * CFrame.new(p * 2, -p * 1.5, -r * 0.8)
			for k = 1, 3 do
				local z = zzz:FindFirstChild("Z" .. k) :: BillboardGui?
				if z then
					local u = (t * 0.25 + k / 3) % 1
					z.StudsOffset = Vector3.new(k * 6 + math.sin(t + k) * 3, 10 + u * 70, 0)
					local label = z:FindFirstChildOfClass("TextLabel")
					if label then
						label.TextTransparency = math.clamp(u * 1.2 - 0.1, 0, 1)
					end
				end
			end
		end
	end)
end

return KidView
