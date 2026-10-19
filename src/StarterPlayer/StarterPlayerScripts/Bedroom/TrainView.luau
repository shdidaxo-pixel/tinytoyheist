--!strict
-- Moves the 5-car train round its loop from the server clock, the same maths the server uses to check for hits,
-- so it's smooth here and fair there. The cars bob a little on the rails.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MapConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MapConfig")) :: any

local TrainView = {}

function TrainView.start(bedroom: Model)
	local cars = bedroom:WaitForChild("Train"):WaitForChild("Cars")
	local path = MapConfig.trackPath()
	local up = Vector3.new(0, MapConfig.TRACK_HEIGHT, 0)
	local list: { Model } = {}
	for k = 1, MapConfig.TRAIN_CARS do
		list[k] = cars:WaitForChild("Car" .. k) :: Model
	end
	RunService.RenderStepped:Connect(function()
		local t = Workspace:GetServerTimeNow()
		for k, car in list do
			local position, direction = MapConfig.trackPose(path, MapConfig.trainCarDistance(t, k))
			local base = CFrame.lookAt(position + up, position + up + direction) * CFrame.Angles(0, math.pi / 2, 0)
			car:PivotTo(base * CFrame.new(0, 0.5 + math.abs(math.sin(t * 14 + k)) * 0.35, 0))
		end
	end)
end

return TrainView
