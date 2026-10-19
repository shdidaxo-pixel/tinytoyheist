--!strict
-- The Giant Kid. Asleep: he breathes, a snot bubble grows and pops, Zs drift up. When he sits up (his flashlight
-- at 80 on the wake meter, or stirring and awake) the sitting-up parts show and the flashlight sweeps its beam down
-- the run, aimed where the server checks it (MapConfig.flashlightTarget on the server clock).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MapConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MapConfig")) :: any

local KidView = {}

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
	local function refresh()
		local want = kid:GetAttribute("State") ~= "Asleep" or kid:GetAttribute("Flashlight") == true
		if want == up then
			return
		end
		up = want
		for _, p in sitUp:GetChildren() do
			setShown(p, want)
		end
		for _, p in asleep:GetChildren() do
			if LYING[p.Name] then
				setShown(p, not want)
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
	end
	refresh()
	kid:GetAttributeChangedSignal("State"):Connect(refresh)
	kid:GetAttributeChangedSignal("Flashlight"):Connect(refresh)

	RunService.RenderStepped:Connect(function()
		local t = Workspace:GetServerTimeNow()
		if up then
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
