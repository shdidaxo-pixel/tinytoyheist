--!strict
-- The small hazards, checked ten times a second against every player's position:
--   mouse traps   SNAP: you drop your toy and go home; the trap re-arms after a while
--   loose boards  a loud creak (a big noise spike)
--   squeaky ducks a squeak (noise)
--   toy bricks    a clack when you bump them (noise)
-- The baby monitor's zone needs nothing here: MapConfig.noiseAt doubles noise inside it.
-- Each hazard model gets a "Fired" attribute (server time) when it goes off, so clients can animate it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local MapConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MapConfig")) :: any

local Events = require(script.Parent.Events)
local Knock = require(script.Parent.Knock)

local Hazards = {}
Hazards.TRAP_REARM = 20
Hazards.COOLDOWN = { Board = 2.5, Duck = 1.5, Brick = 2.5 }

type Spot = { model: Model, kind: string, cf: CFrame, half: Vector3, noise: number, ready: number }

function Hazards.start(bedroom: Model)
	local folder = bedroom:WaitForChild("Hazards")
	local spots: { Spot } = {}
	local function add(model: Instance, kind: string, half: Vector3)
		if not model:IsA("Model") then
			return
		end
		local pivot = model:GetPivot()
		table.insert(spots, {
			model = model,
			kind = kind,
			cf = CFrame.new(pivot.Position.X, 0, pivot.Position.Z) * (pivot - pivot.Position),
			half = half,
			noise = (model:GetAttribute("Noise") :: number?) or 0,
			ready = 0,
		})
	end
	for _, trap in folder:WaitForChild("Traps"):GetChildren() do
		add(trap, "Trap", Vector3.new(16, 8, 8) * MapConfig.SCALE + Vector3.new(1.5, 2, 1.5))
	end
	for _, board in folder:WaitForChild("LooseBoards"):GetChildren() do
		add(board, "Board", Vector3.new(17, 6, 5) * MapConfig.SCALE + Vector3.new(1.5, 2, 1.5))
	end
	for _, duck in folder:WaitForChild("Ducks"):GetChildren() do
		add(duck, "Duck", Vector3.new(8, 12, 7) * MapConfig.SCALE + Vector3.new(1.5, 2, 1.5))
	end
	for _, brick in folder:WaitForChild("Bricks"):GetChildren() do
		add(brick, "Brick", Vector3.new(7.5, 10, 4.5) * MapConfig.SCALE + Vector3.new(1.5, 2, 1.5))
	end

	task.spawn(function()
		while folder.Parent do
			task.wait(0.1)
			local t = os.clock()
			for _, player in Players:GetPlayers() do
				local root = Knock.root(player)
				if not root then
					continue
				end
				-- the character's feet, roughly
				local feet = root.Position - Vector3.new(0, 3, 0)
				for _, spot in spots do
					if t < spot.ready then
						continue
					end
					local p = spot.cf:PointToObjectSpace(feet)
					if math.abs(p.X) > spot.half.X or math.abs(p.Z) > spot.half.Z or p.Y > spot.half.Y then
						continue
					end
					local position = spot.cf.Position
					if spot.kind == "Trap" then
						if spot.model:GetAttribute("Armed") and Knock.ready(player) then
							spot.model:SetAttribute("Armed", false)
							spot.model:SetAttribute("Fired", Workspace:GetServerTimeNow())
							spot.ready = t + Hazards.TRAP_REARM
							Events.MakeNoise:Fire(position, 10, "Spike")
							Knock.hit(
								player,
								position,
								{ message = "SNAP! A mouse trap!", push = 25, stun = 2, home = true }
							)
							local model = spot.model
							task.delay(Hazards.TRAP_REARM, function()
								model:SetAttribute("Armed", true)
							end)
						end
					else
						spot.ready = t + Hazards.COOLDOWN[spot.kind]
						spot.model:SetAttribute("Fired", Workspace:GetServerTimeNow())
						Events.MakeNoise:Fire(position, spot.noise, spot.kind)
					end
				end
			end
		end
	end)
end

return Hazards
