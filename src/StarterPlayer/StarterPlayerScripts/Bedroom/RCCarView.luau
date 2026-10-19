--!strict
-- The RC car on each screen. The server drives it (ServerScriptService.Bedroom.RCCar) and shares Pose, Speed, Steer
-- and State on Hazards.RCCar; this moves the model smoothly between updates and makes it look like a toy car tearing
-- about: the wheels spin with the distance run and the front ones steer, the body squats and noses up as it speeds
-- up and brakes, the antenna whips about, headlights on while it drives, dust kicked up behind, a whiny motor, and a
-- bonk when it bumps someone. Its charger's light is green while it's parked and blinks red while it's out.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")

local RCCarView = {}
RCCarView.NEAR = 260 -- studs: closer than this the details move too

-- The VFX session's effects library, if it's there (dust, bump)
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

type Bit = { part: BasePart, offset: CFrame, wheel: number?, antenna: boolean }

function RCCarView.start(bedroom: Model)
	local hazards = bedroom:WaitForChild("Hazards")
	local car = hazards:WaitForChild("RCCar", 60) :: Model?
	if not car then
		return
	end
	local dock = hazards:FindFirstChild("RCDock")
	local root = car.PrimaryPart :: BasePart
	local rest = root.CFrame

	-- the four tyres are the wheels' centres; hubs and treads turn with the nearest one
	local centres: { CFrame } = {}
	for _, p in car:GetChildren() do
		if p:IsA("Part") and p.Name == "Wheel" and p.Shape == Enum.PartType.Cylinder then
			table.insert(centres, rest:ToObjectSpace(p.CFrame))
		end
	end
	local antennaBase = Vector3.zero
	for _, p in car:GetChildren() do
		if p:IsA("BasePart") and p.Name == "Antenna" then
			local a = p.Position + p.CFrame.RightVector * p.Size.X / 2
			local b = p.Position - p.CFrame.RightVector * p.Size.X / 2
			antennaBase = rest:PointToObjectSpace(if a.Y < b.Y then a else b)
		end
	end
	local bits: { Bit } = {}
	local lights: { BasePart } = {}
	local spot: SpotLight? = nil
	for _, p in car:GetDescendants() do
		if p:IsA("SpotLight") then
			spot = p
		end
		if not p:IsA("BasePart") or p == root then
			continue
		end
		local offset = rest:ToObjectSpace(p.CFrame)
		local wheel: number? = nil
		if p.Name == "Wheel" or p.Name == "Hub" or p.Name == "Tread" then
			local best = math.huge
			for k, c in centres do
				local d = (c.Position - offset.Position).Magnitude
				if d < best then
					best, wheel = d, k
				end
			end
			offset = centres[wheel :: number]:ToObjectSpace(offset)
		end
		if p.Name == "Headlight" then
			table.insert(lights, p)
		end
		table.insert(bits, {
			part = p,
			offset = offset,
			wheel = wheel,
			antenna = p.Name == "Antenna" or p.Name == "AntennaTip",
		})
	end
	local radius = 4
	for _, p in car:GetChildren() do
		if p:IsA("Part") and p.Name == "Wheel" and p.Shape == Enum.PartType.Cylinder then
			radius = p.Size.Y / 2
			break
		end
	end
	local chargeLight = dock and dock:FindFirstChild("ChargeLight") :: BasePart?
	local chargeGlow = chargeLight and chargeLight:FindFirstChildOfClass("PointLight")

	-- the motor and the bonk, through the SFX session's Sounds if it's there
	local Sounds: any = nil
	local motor: Sound? = nil
	task.spawn(function()
		local ok, lib = pcall(require, script.Parent:WaitForChild("Sounds", 10) :: ModuleScript)
		if ok and lib then
			Sounds = lib
			local ok2, s = pcall(lib.loop, "TrainLoop", root)
			if ok2 and s then
				motor = s
			end
		end
	end)

	local current = root.CFrame
	local poseAt = os.clock()
	local function pose(): CFrame
		local p = car:GetAttribute("Pose")
		return if typeof(p) == "CFrame" then p else rest
	end
	car:GetAttributeChangedSignal("Pose"):Connect(function()
		poseAt = os.clock()
	end)
	car:GetAttributeChangedSignal("State"):Connect(function()
		local state = car:GetAttribute("State")
		if state == "Bumped" then
			local front = (current * CFrame.new(0, 3, -12)).Position
			if Sounds then
				pcall(Sounds.play, "Thud", front, { pitch = 1.4 })
			end
			if VFX then
				pcall(VFX.burst, "Poof", front, { scale = 2 })
				pcall(VFX.burst, "Shockwave", front, { scale = 1.2 })
			end
		end
	end)

	local spin, steerShown, speedShown, pitch = 0, 0, 0, 0
	local wobble, wobbleV = 0, 0
	local lastDust = 0
	local parts: { BasePart } = {}
	local cframes: { CFrame } = {}
	RunService.RenderStepped:Connect(function(dt)
		dt = math.min(dt, 0.1)
		local now = os.clock()
		local state = car:GetAttribute("State")
		local speed = (car:GetAttribute("Speed") :: number?) or 0
		local steer = (car:GetAttribute("Steer") :: number?) or 0
		-- follow the server, a touch ahead (it moves fast between updates)
		local target = pose() * CFrame.new(0, 0, -speed * math.min(now - poseAt, 0.15))
		current = current:Lerp(target, 1 - math.exp(-dt * 14))
		local accel = (speed - speedShown) / math.max(dt, 1e-3)
		speedShown = speed
		spin += speed * dt / radius
		steerShown += (steer - steerShown) * math.min(1, dt * 10)
		-- nose up when it speeds away, down when it brakes; a little shake at speed
		pitch += (math.clamp(accel * 0.0012, -0.08, 0.08) - pitch) * math.min(1, dt * 6)
		local buzz = if math.abs(speed) > 5 then math.sin(now * 55) * 0.12 else 0
		-- the antenna is a spring pushed by the acceleration
		wobbleV += (-wobble * 120 - wobbleV * 5 - accel * 0.004) * dt
		wobble += wobbleV * dt
		wobble = math.clamp(wobble, -0.6, 0.6)

		local eye = Workspace.CurrentCamera and Workspace.CurrentCamera.CFrame.Position or Vector3.zero
		local near = (current.Position - eye).Magnitude < RCCarView.NEAR
		local body = current
			* CFrame.new(0, buzz, 0)
			* CFrame.Angles(pitch, 0, -steerShown * 0.05 * math.min(1, math.abs(speed) / 40))
		table.clear(parts)
		table.clear(cframes)
		root.CFrame = current
		if near then
			local antenna = CFrame.new(antennaBase) * CFrame.Angles(wobble, 0, wobble * 0.3) * CFrame.new(-antennaBase)
			for _, bit in bits do
				local cf
				if bit.wheel then
					local c = centres[bit.wheel]
					local turn = if c.Position.Z < 0 then CFrame.Angles(0, -steerShown * 0.5, 0) else CFrame.identity
					cf = current * c * turn * CFrame.Angles(-spin, 0, 0) * bit.offset
				elseif bit.antenna then
					cf = body * antenna * bit.offset
				else
					cf = body * bit.offset
				end
				table.insert(parts, bit.part)
				table.insert(cframes, cf)
			end
			if #parts > 0 then
				Workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
			end
			-- dust kicked up behind it
			if VFX and math.abs(speed) > 35 and now - lastDust > 0.12 then
				lastDust = now
				pcall(VFX.burst, "Poof", (current * CFrame.new(0, 1, 12)).Position, { scale = 0.9 })
			end
		else
			car:PivotTo(current)
		end

		local out = state ~= "Docked"
		for _, l in lights do
			l.Color = if out then Color3.fromRGB(255, 250, 215) else Color3.fromRGB(120, 116, 96)
		end
		if spot then
			spot.Brightness = if out then 3 else 0
		end
		if chargeLight then
			local on = not out or (now * 2) % 1 < 0.5
			chargeLight.Color = if out then Color3.fromRGB(255, 60, 70) else Color3.fromRGB(61, 255, 122)
			chargeLight.Transparency = if on then 0 else 0.7
			if chargeGlow then
				chargeGlow.Color = chargeLight.Color
				chargeGlow.Enabled = on
			end
		end
		if motor then
			local m = motor :: Sound
			local loud = math.clamp(math.abs(speed) / 72, 0, 1)
			if out and not m.IsPlaying then
				m:Play()
			elseif not out and m.IsPlaying then
				m:Stop()
			end
			m.PlaybackSpeed = 1.3 + loud * 1.1
			m.Volume = 0.15 + loud * 0.45
		end
	end)
end

return RCCarView
