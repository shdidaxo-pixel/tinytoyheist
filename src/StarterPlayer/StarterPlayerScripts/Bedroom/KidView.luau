--!strict
-- The Giant Kid. Asleep: he breathes, a snot bubble grows and pops, Zs drift up. When he sits up (his flashlight
-- at 80 on the wake meter, or stirring and awake) the sitting-up parts show and the flashlight sweeps its beam down
-- the run, aimed where the server checks it (MapConfig.flashlightTarget on the server clock).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MapConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MapConfig")) :: any

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

function KidView.start(bedroom: Model)
	local kid = bedroom:WaitForChild("GiantKid") :: Model
	local asleep = kid:WaitForChild("Asleep")
	local sitUp = kid:WaitForChild("SitUp")
	local flashlight = sitUp:WaitForChild("Flashlight") :: Model
	local lens = flashlight:WaitForChild("Lens") :: BasePart
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
	local lensRest = lens.Position
	local aimRest = CFrame.lookAt(lensRest, lensRest + Vector3.new(0, 0, -1))
	local poolTurn = pool.CFrame - pool.CFrame.Position

	local up: boolean? = nil
	local walking: boolean? = nil
	local walker = kid:WaitForChild("Walker") :: Model
	local walkerRoot = walker.PrimaryPart :: BasePart
	local lumps = { asleep:WaitForChild("BodyLower"), upper }
	-- the walking Kid's parts, with their rest offsets from his Root and which leg or arm they belong to
	local limbs: { { part: BasePart, offset: CFrame, kind: string, side: number } } = {}
	for _, p in walker:GetChildren() do
		if p:IsA("BasePart") and p ~= walkerRoot then
			local offset = walkerRoot.CFrame:ToObjectSpace(p.CFrame)
			local kind = if p.Name == "Leg" or p.Name == "Foot"
				then "Leg"
				elseif p.Name == "Arm" or p.Name == "Hand" then "Arm"
				else "Body"
			table.insert(limbs, { part = p, offset = offset, kind = kind, side = if offset.X < 0 then -1 else 1 })
		end
	end
	local walkerCurrent = walkerRoot.CFrame
	local lastWalker = walkerCurrent.Position
	local stride, speed = 0, 0

	local function refresh()
		local isWalking = kid:GetAttribute("Walking") == true
		local want = not isWalking and (kid:GetAttribute("State") ~= "Asleep" or kid:GetAttribute("Flashlight") == true)
		if want == up and isWalking == walking then
			return
		end
		up, walking = want, isWalking
		for _, p in sitUp:GetChildren() do
			setShown(p, want)
		end
		for _, p in asleep:GetChildren() do
			if LYING[p.Name] then
				setShown(p, not want and not isWalking)
			end
		end
		for _, p in lumps do
			setShown(p, not isWalking) -- out of bed, the duvet lies flat
		end
		for _, p in walker:GetChildren() do
			if p ~= walkerRoot then
				setShown(p, isWalking)
			end
		end
		beam.Enabled = want
		if spot then
			spot.Enabled = want
		end
		local angry = sitUp:FindFirstChild("Head")
		local face = angry and angry:FindFirstChild("Face") :: SurfaceGui?
		if face then
			face.Enabled = want
		end
		if isWalking then
			local pose = kid:GetAttribute("WalkerPose")
			if typeof(pose) == "CFrame" then
				walkerCurrent = pose
			end
		end
	end
	refresh()
	kid:GetAttributeChangedSignal("State"):Connect(refresh)
	kid:GetAttributeChangedSignal("Flashlight"):Connect(refresh)
	kid:GetAttributeChangedSignal("Walking"):Connect(refresh)

	RunService.RenderStepped:Connect(function(dt)
		local t = Workspace:GetServerTimeNow()
		if walking then
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
			walkerRoot.CFrame = walkerCurrent
			for _, limb in limbs do
				local cf
				if limb.kind == "Leg" then
					local hip = CFrame.new(limb.side * 20 * S, 86 * S, 0)
					cf = walkerCurrent
						* hip
						* CFrame.Angles(math.sin(stride + (limb.side + 1) * 0.5 * math.pi) * 0.45 * amount, 0, 0)
						* hip:Inverse()
						* limb.offset
				elseif limb.kind == "Arm" then
					local shoulder = CFrame.new(limb.side * 53 * S, 156 * S, 0)
					cf = walkerCurrent
						* CFrame.new(0, bob, 0)
						* shoulder
						* CFrame.Angles(-math.sin(stride + (limb.side + 1) * 0.5 * math.pi) * 0.5 * amount, 0, 0)
						* shoulder:Inverse()
						* limb.offset
				else
					cf = walkerCurrent * CFrame.new(0, bob, 0) * limb.offset
				end
				limb.part.CFrame = cf
			end
		elseif up then
			local target = MapConfig.flashlightTarget(t)
			local aim = CFrame.lookAt(lensRest, target)
			flashlight:PivotTo(aim * aimRest:Inverse() * flashRest)
			pool.CFrame = CFrame.new(target + Vector3.new(0, 0.35, 0)) * poolTurn
			poolLight.CFrame = CFrame.new(target + Vector3.new(0, 45, 0))
		else
			-- breathing, the snot bubble, the Zs
			upper.CFrame = upperRest * CFrame.new(0, math.sin(t * 1.2) * 0.9, 0)
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
