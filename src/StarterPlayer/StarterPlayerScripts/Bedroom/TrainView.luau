--!strict
-- Moves the 5-car train round its loop from the server clock, the same maths the server uses to check for hits,
-- so it's smooth here and fair there. On top of that, the toy-train look: the wheels turn with the distance run, the
-- cars rock and bounce on the rails and lean out on the bends, the engine chuffs (its body pumps and a puff leaves
-- the chimney), and the cargo jiggles in the wagons. Only the look: the server's hit test doesn't change.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MapConfig = require(Shared:WaitForChild("MapConfig")) :: any

local TrainView = {}
TrainView.NEAR = 260 -- studs: closer than this the details (wheels, cargo, puffs) move too

-- The VFX session's effects library, if it's there (chimney puffs)
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

type Bit = { part: BasePart, offset: CFrame, kind: string, radius: number, seed: number }
type Car = { model: Model, bits: { Bit }, lastDir: Vector3?, lean: number }

function TrainView.start(bedroom: Model)
	local cars = bedroom:WaitForChild("Train"):WaitForChild("Cars")
	local path = MapConfig.trackPath()
	local up = Vector3.new(0, MapConfig.TRACK_HEIGHT, 0)
	local list: { Car } = {}
	for k = 1, MapConfig.TRAIN_CARS do
		local model = cars:WaitForChild("Car" .. k) :: Model
		local pivot = model:GetPivot()
		local bits: { Bit } = {}
		for _, p in model:GetDescendants() do
			if p:IsA("BasePart") then
				local kind = if p.Name == "Wheel"
					then "Wheel"
					elseif p.Name == "Cargo" then "Cargo"
					elseif p.Name == "Chimney" then "Chimney"
					else "Body"
				table.insert(bits, {
					part = p,
					offset = pivot:ToObjectSpace(p.CFrame),
					kind = kind,
					radius = math.max(p.Size.Y, p.Size.Z) / 2,
					seed = math.random() * 10,
				})
			end
		end
		list[k] = { model = model, bits = bits, lastDir = nil, lean = 0 }
	end

	local parts: { BasePart } = {}
	local cframes: { CFrame } = {}
	local lastPuff = 0
	RunService.RenderStepped:Connect(function(dt)
		dt = math.min(dt, 0.1)
		local t = Workspace:GetServerTimeNow()
		local cam = Workspace.CurrentCamera
		local eye = if cam then cam.CFrame.Position else Vector3.zero
		table.clear(parts)
		table.clear(cframes)
		for k, car in list do
			local distance = MapConfig.trainCarDistance(t, k)
			local position, direction = MapConfig.trackPose(path, distance)
			local base = CFrame.lookAt(position + up, position + up + direction) * CFrame.Angles(0, math.pi / 2, 0)
			-- lean out on the bends: how fast it's turning
			local turn = 0
			if car.lastDir then
				local last = car.lastDir :: Vector3
				turn = math.atan2(last:Cross(direction).Y, last:Dot(direction)) / math.max(dt, 1 / 240)
			end
			car.lastDir = direction
			car.lean += (math.clamp(turn * 0.12, -0.14, 0.14) - car.lean) * math.min(1, dt * 5)
			local bounce = math.abs(math.sin(t * 14 + k)) * 0.35
			local chuff = if k == 1 then math.abs(math.sin(t * 7)) else 0
			local rock = math.sin(t * 9 + k * 1.7) * 0.025
			local body = base * CFrame.new(0, 0.5 + bounce + chuff * 0.15, 0) * CFrame.Angles(car.lean + rock, 0, 0)
			if (position - eye).Magnitude > TrainView.NEAR then
				car.model:PivotTo(body)
				continue
			end
			for _, bit in car.bits do
				local cf
				if bit.kind == "Wheel" then
					-- on the rails (no bounce), turning about their axle
					cf = base * CFrame.new(0, 0.5, 0) * bit.offset * CFrame.Angles(-distance / bit.radius, 0, 0)
				elseif bit.kind == "Cargo" then
					local j = math.abs(math.sin(t * 11 + bit.seed)) * 0.25
					cf = body
						* bit.offset
						* CFrame.new(0, j, 0)
						* CFrame.Angles(0, math.sin(t * 5 + bit.seed) * 0.05, 0)
				elseif bit.kind == "Chimney" then
					cf = body * bit.offset * CFrame.new(math.sin(t * 7) * 0.08, 0, 0)
				else
					cf = body * bit.offset
				end
				table.insert(parts, bit.part)
				table.insert(cframes, cf)
			end
			-- a puff from the chimney with every chuff
			if k == 1 and VFX and t - lastPuff > 0.45 then
				lastPuff = t
				for _, bit in car.bits do
					if bit.kind == "Chimney" then
						local top = (body * bit.offset).Position + Vector3.new(0, bit.part.Size.X / 2 + 0.5, 0)
						pcall(VFX.burst, "Poof", top, { scale = 1.2 })
						break
					end
				end
			end
		end
		if #parts > 0 then
			Workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end)
end

return TrainView
