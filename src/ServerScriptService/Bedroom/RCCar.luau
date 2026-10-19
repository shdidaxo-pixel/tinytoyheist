--!strict
-- The RC car: parked on its charger while the lights are off; with the lights on (the Kid awake) it tears round the
-- floor going for mice (carriers first) and bumps anyone it hits: knocked over, toy dropped. It's fast but turns
-- wide, so a quick mouse can step aside, and a very fast one simply outruns it. It never comes into the safe ring or
-- the homes. When the lights go off it drives back to its charger.
-- The server drives it and writes Hazards.RCCar attributes: State (Docked, Driving, Bumped, Return), Pose (its Root
-- CFrame), Speed (studs a second, for the wheels and the motor sound), Steer (-1..1). Clients move the model
-- (RCCarView).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MapConfig")) :: any
local Knock = require(script.Parent.Knock)

local RCCar = {}
local S = MapConfig.SCALE
RCCar.SPEED = 72 -- top speed, studs a second (a mouse walks 16 at the start, 80 at the old max, 100+ late game)
RCCar.ACCEL = 70 -- studs a second, per second
RCCar.TURN = 2.1 -- radians a second at full lock: it swings wide, so you can sidestep it
RCCar.LEAD = 0.5 -- aims this many seconds ahead of the mouse it's after
RCCar.HALF_LENGTH = 18 * S + 2 -- hit box: half its length, half its width, how high you can be and still be hit
RCCar.HALF_WIDTH = 13 * S + 2
RCCar.HEIGHT = 24 * S + 4
RCCar.BUMP_BACK = 0.7 -- seconds it reverses after a bump
RCCar.FORGET = 4 -- seconds before it goes for a mouse it just bumped again
RCCar.CRUISE = 0.6 -- with nobody about, it roams at this much of its top speed

-- Keep a point where the car may drive: inside the run, away from the homes and the safe ring, off the furniture
local function allowed(p: Vector3): Vector3
	local edge = MapConfig.HALF_WIDTH - 16 * S
	local x = math.clamp(p.X, -edge, edge)
	local z = math.clamp(p.Z, MapConfig.CAT.minZ, MapConfig.LENGTH - 30 * S)
	local cz = MapConfig.HOME_CURVE_CENTER_Z
	local fromCentre = Vector3.new(x, 0, z - cz)
	if z < cz and fromCentre.Magnitude > MapConfig.SAFE_RADIUS - 16 * S then
		local inside = fromCentre.Unit * (MapConfig.SAFE_RADIUS - 16 * S)
		x, z = inside.X, cz + inside.Z
	end
	for _, c in MapConfig.KEEP_OUTS do
		local d = Vector3.new(x - c[1], 0, z - c[2])
		local r = c[3] + 16 * S
		if d.Magnitude < r then
			local out = (if d.Magnitude > 0.01 then d.Unit else Vector3.xAxis) * r
			x, z = c[1] + out.X, c[2] + out.Z
		end
	end
	for _, f in MapConfig.FOOTPRINTS do
		local x0, z0, x1, z1 = f[1] - 16 * S, f[2] - 16 * S, f[3] + 16 * S, f[4] + 16 * S
		if x > x0 and x < x1 and z > z0 and z < z1 then
			local options = { { x0 - x, 0 }, { x1 - x, 0 }, { 0, z0 - z }, { 0, z1 - z } }
			table.sort(options, function(a, b)
				return math.abs(a[1]) + math.abs(a[2]) < math.abs(b[1]) + math.abs(b[2])
			end)
			x += options[1][1]
			z += options[1][2]
		end
	end
	return Vector3.new(x, 0, z)
end

local function inPlay(position: Vector3): boolean
	return MapConfig.inRoom(position)
		and position.Z >= MapConfig.CAT.minZ
		and not MapConfig.inSafeZone(position)
		and not MapConfig.homeAt(position)
end

-- the signed angle from a to b about +y
local function angleTo(a: Vector3, b: Vector3): number
	return math.atan2(a:Cross(b).Y, a:Dot(b))
end

function RCCar.start(bedroom: Model)
	local hazards = bedroom:WaitForChild("Hazards")
	local car = hazards:FindFirstChild("RCCar") :: Model? -- the map is all there on the server; never hold up the start
	if not car then
		warn("RCCar: no Hazards.RCCar in the map (build it: tools/bedroom/Hazards.luau, only = RCCar)")
		return
	end
	local kid = bedroom:WaitForChild("GiantKid") :: Model
	local dockCf = (car.PrimaryPart :: BasePart).CFrame
	local rootY = dockCf.Position.Y
	local dock = Vector3.new(dockCf.Position.X, 0, dockCf.Position.Z)
	local dockFacing = Vector3.new(dockCf.LookVector.X, 0, dockCf.LookVector.Z).Unit
	local position = dock
	local facing = dockFacing
	local speed = 0
	local steer = 0
	local state = "Docked"
	local bumpedUntil = 0
	local bumped: { [Player]: number } = {}
	local roam: Vector3? = nil
	local roamUntil = 0

	local function setPose()
		car:SetAttribute(
			"Pose",
			CFrame.lookAt(
				Vector3.new(position.X, rootY, position.Z),
				Vector3.new(position.X + facing.X, rootY, position.Z + facing.Z)
			)
		)
		car:SetAttribute("Speed", speed)
		car:SetAttribute("Steer", steer)
	end
	local function setState(s: string)
		if s ~= state then
			state = s
			car:SetAttribute("State", s)
		end
	end
	setState("Docked")
	car:SetAttribute("State", "Docked")
	setPose()

	-- drive toward a point: turn (limited), speed up or slow for the bend, move, slide off walls and furniture
	local function drive(goal: Vector3, top: number, dt: number)
		local d = Vector3.new(goal.X - position.X, 0, goal.Z - position.Z)
		if d.Magnitude > 0.5 then
			local turn = angleTo(facing, d.Unit)
			local step = math.clamp(turn, -RCCar.TURN * dt, RCCar.TURN * dt)
			facing = (CFrame.Angles(0, step, 0) * facing).Unit
			steer += (math.clamp(turn * 1.5, -1, 1) - steer) * math.min(1, dt * 8)
			-- slow down for a tight bend, and when it's nearly there
			top *= 0.55 + 0.45 * math.max(0, math.cos(math.min(math.abs(turn), math.pi)))
			top = math.min(top, d.Magnitude * 3)
		end
		speed += math.clamp(top - speed, -RCCar.ACCEL * 2 * dt, RCCar.ACCEL * dt)
		local want = position + facing * speed * dt
		local got = allowed(want)
		if speed > 10 and (got - want).Magnitude > speed * dt * 0.5 then
			-- hit a wall or furniture: bonk, lose speed and swing round
			speed *= 0.35
			facing = (CFrame.Angles(0, (if steer >= 0 then 1 else -1) * 1.2, 0) * facing).Unit
		end
		position = got
	end

	task.spawn(function()
		local last = os.clock()
		local sinceSend = 0
		while car.Parent do
			task.wait()
			local dt = math.min(os.clock() - last, 0.1)
			last = os.clock()
			local now = os.clock()
			local lightsOn = kid:GetAttribute("State") == "Awake"

			if state == "Docked" then
				speed = 0
				if lightsOn then
					setState("Driving")
				end
			elseif state == "Bumped" then
				-- back off from the mouse it just hit
				speed += (-RCCar.SPEED * 0.35 - speed) * math.min(1, dt * 6)
				position = allowed(position + facing * speed * dt)
				if now >= bumpedUntil then
					setState(if lightsOn then "Driving" else "Return")
				end
			elseif state == "Driving" then
				if not lightsOn then
					setState("Return")
				else
					-- go for the nearest mouse in the run (one dragging a toy counts as nearer)
					local best, bestScore = nil, math.huge
					for _, player in Players:GetPlayers() do
						local root = Knock.root(player)
						if root and inPlay(root.Position) and (bumped[player] or 0) < now and Knock.ready(player) then
							local flat = Vector3.new(root.Position.X, 0, root.Position.Z)
							local score = (flat - position).Magnitude
							if player:GetAttribute("Carrying") then
								score *= 0.5
							end
							if score < bestScore then
								best, bestScore = root, score
							end
						end
					end
					if best then
						local v = best.AssemblyLinearVelocity
						local lead = math.min(RCCar.LEAD, bestScore / RCCar.SPEED)
						drive(best.Position + Vector3.new(v.X, 0, v.Z) * lead, RCCar.SPEED, dt)
					else
						-- nobody about: roam to random spots down the run
						if not roam or now >= roamUntil or (roam - position).Magnitude < 20 * S then
							roam = allowed(
								Vector3.new(
									(math.random() * 2 - 1) * MapConfig.HALF_WIDTH,
									0,
									MapConfig.CAT.minZ + math.random() * (MapConfig.LENGTH - MapConfig.CAT.minZ)
								)
							)
							roamUntil = now + 5
						end
						drive(roam :: Vector3, RCCar.SPEED * RCCar.CRUISE, dt)
					end
				end
			elseif state == "Return" then
				-- back to the charger: line up in front of it, then roll on
				local front = dock + dockFacing * 40 * S
				if (front - position).Magnitude > 8 * S and (dock - position).Magnitude > 12 * S then
					drive(front, RCCar.SPEED * 0.7, dt)
				else
					local d = dock - position
					speed = math.max(0, math.min(speed, 20))
					position += if d.Magnitude > 0.5 then d.Unit * math.min(d.Magnitude, 20 * dt) else Vector3.zero
					facing = facing:Lerp(dockFacing, math.min(1, dt * 4)).Unit
					if d.Magnitude < 1 and facing:Dot(dockFacing) > 0.99 then
						position, facing, speed, steer = dock, dockFacing, 0, 0
						setState("Docked")
					end
				end
				if lightsOn then
					setState("Driving")
				end
			end

			-- bumps: anyone in its box while it's moving gets knocked over
			if math.abs(speed) > 15 then
				local across = Vector3.new(-facing.Z, 0, facing.X)
				for _, player in Players:GetPlayers() do
					local root = Knock.root(player)
					if root and inPlay(root.Position) then
						local offset = root.Position - Vector3.new(position.X, rootY, position.Z)
						local along = offset:Dot(facing)
						local side = offset:Dot(across)
						if
							math.abs(along) <= RCCar.HALF_LENGTH
							and math.abs(side) <= RCCar.HALF_WIDTH
							and offset.Y < RCCar.HEIGHT
						then
							local from = position - facing * 12 * S - across * math.sign(side + 1e-3) * 6 * S
							if
								Knock.hit(player, from, { message = "Bumped by the RC car!", push = 95, stun = 1.6 })
							then
								bumped[player] = now + RCCar.FORGET
								if state == "Driving" then
									bumpedUntil = now + RCCar.BUMP_BACK
									setState("Bumped")
								end
							end
						end
					end
				end
			end

			sinceSend += dt
			if sinceSend >= 1 / 20 and not (state == "Docked" and speed == 0 and car:GetAttribute("Speed") == 0) then
				sinceSend = 0
				setPose()
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		bumped[player] = nil
	end)
end

return RCCar
