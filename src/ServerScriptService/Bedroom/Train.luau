--!strict
-- The toy train runs its loop on the server clock (MapConfig.trainCarDistance), so the server and every client agree
-- where each car is without sending positions. Clients move the cars; the server only checks for players in the
-- way: a hit knocks you over and you drop what you carry.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local MapConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MapConfig")) :: any
local Knock = require(script.Parent.Knock)

local Train = {}
-- half the size of a car's hit box: along the track, across it, and how high you can be and still get hit
Train.HALF_LENGTH = 13 * MapConfig.SCALE + 2
Train.HALF_WIDTH = 9 * MapConfig.SCALE + 2
Train.HEIGHT = 22 * MapConfig.SCALE + 4

function Train.start()
	local path = MapConfig.trackPath()
	task.spawn(function()
		while true do
			task.wait(1 / 20)
			local t = Workspace:GetServerTimeNow()
			local roots = {}
			for _, player in Players:GetPlayers() do
				local root = Knock.root(player)
				if root and root.Position.Z > 540 * MapConfig.SCALE and Knock.ready(player) then
					table.insert(roots, { player = player, root = root })
				end
			end
			if #roots == 0 then
				continue
			end
			for car = 1, MapConfig.TRAIN_CARS do
				local position, direction = MapConfig.trackPose(path, MapConfig.trainCarDistance(t, car))
				local across = Vector3.new(-direction.Z, 0, direction.X)
				for _, r in roots do
					local offset = r.root.Position - position
					local along = offset:Dot(direction)
					local side = offset:Dot(across)
					if
						math.abs(along) <= Train.HALF_LENGTH
						and math.abs(side) <= Train.HALF_WIDTH
						and offset.Y < Train.HEIGHT
					then
						-- thrown forward and off to the side you were on
						local from = position
							- direction * 20 * MapConfig.SCALE
							- across * math.sign(side + 1e-3) * 10 * MapConfig.SCALE
						Knock.hit(r.player, from, { message = "Hit by the train!", push = 80, stun = 1.6 })
					end
				end
			end
		end
	end)
end

return Train
