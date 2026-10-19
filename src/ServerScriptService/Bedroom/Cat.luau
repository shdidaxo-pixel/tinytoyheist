--!strict
-- The cat. It patrols an ellipse on the wood band. It notices a mouse nearby that's carrying a toy or running, stalks
-- it and pounces: a hit knocks you over and you drop your toy. With the lights on (the Kid awake) it's aggressive:
-- it sees further, chases anyone, runs faster and pounces sooner. It never comes into the safe zone or the homes.
-- The server works out where it is and writes it to the Cat's "Pose" attribute; clients move the model smoothly.
-- Attributes on Hazards.Cat: State (Patrol, Stalk, Pounce, Rest), Aggressive, Pose (CFrame of its Root).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MapConfig")) :: any
local Knock = require(script.Parent.Knock)

local Cat = {}
Cat.CALM = { sight = 60, stalk = 9, patrol = 8, pounceFrom = 26 }
Cat.ANGRY = { sight = 150, stalk = 22, patrol = 12, pounceFrom = 40 }
Cat.LEAP_SPEED = 75
Cat.LEAP_TIME = 0.45
Cat.HIT_RADIUS = 16
Cat.REST = 2.5 -- seconds it sits after a pounce
Cat.FAST = 12 -- a mouse moving faster than this catches its eye (calm)

-- Keep a point where the cat may walk: inside the run, away from the homes, off the furniture
local function allowed(p: Vector3): Vector3
	local x = math.clamp(p.X, -185, 185)
	local z = math.clamp(p.Z, MapConfig.CAT.minZ, MapConfig.LENGTH - 50)
	for _, f in MapConfig.FOOTPRINTS do
		local x0, z0, x1, z1 = f[1] - 22, f[2] - 22, f[3] + 22, f[4] + 22
		if x > x0 and x < x1 and z > z0 and z < z1 then
			-- step out of the footprint the shortest way
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
	return MapConfig.inRoom(position) and position.Z >= MapConfig.CAT.minZ and not MapConfig.inSafeZone(position)
end

function Cat.start(bedroom: Model)
	local cat = bedroom:WaitForChild("Hazards"):WaitForChild("Cat") :: Model
	local kid = bedroom:WaitForChild("GiantKid") :: Model
	local centre, half = MapConfig.CAT.patrolCenter, MapConfig.CAT.patrolHalf
	local rootY = (cat.PrimaryPart :: BasePart).Position.Y
	local position = allowed(MapConfig.CAT.home)
	local facing = Vector3.new(math.cos(0.4), 0, -math.sin(0.4))
	local angle = math.atan2((position.Z - centre.Z) / half.Z, (position.X - centre.X) / half.X)
	local state = "Patrol"
	local target: Player? = nil
	local leapFrom, leapDir, leapAt = position, facing, 0
	local restUntil = 0

	local function setPose(hop: number, tilt: number)
		local yaw = math.atan2(-facing.Z, facing.X)
		local pose = CFrame.new(position.X, rootY + hop, position.Z)
			* CFrame.Angles(0, yaw, 0)
			* CFrame.Angles(0, 0, tilt)
		cat:SetAttribute("Pose", pose)
	end
	local function moveToward(goal: Vector3, speed: number, dt: number)
		local d = Vector3.new(goal.X - position.X, 0, goal.Z - position.Z)
		if d.Magnitude < 0.5 then
			return
		end
		local step = math.min(d.Magnitude, speed * dt)
		position = allowed(position + d.Unit * step)
		-- turn smoothly toward where it's going
		facing = facing:Lerp(d.Unit, math.min(1, dt * 6)).Unit
	end

	cat:SetAttribute("State", state)
	setPose(0, 0)
	task.spawn(function()
		local last = os.clock()
		local sinceSend = 0
		while cat.Parent do
			task.wait()
			local dt = math.min(os.clock() - last, 0.1)
			last = os.clock()
			local kidState = kid:GetAttribute("State")
			local aggressive = kidState == "Stirring" or kidState == "Awake"
			cat:SetAttribute("Aggressive", aggressive)
			local tune = if aggressive then Cat.ANGRY else Cat.CALM
			local hop, tilt = 0, 0

			if state == "Patrol" or state == "Stalk" then
				-- pick (or keep) a target
				local best, bestDistance = nil, math.huge
				for _, player in Players:GetPlayers() do
					local root = Knock.root(player)
					if root and inPlay(root.Position) and Knock.ready(player) then
						local distance = (Vector3.new(root.Position.X, 0, root.Position.Z) - position).Magnitude
						local velocity = root.AssemblyLinearVelocity
						local interesting = aggressive
							or player:GetAttribute("Carrying")
							or Vector3.new(velocity.X, 0, velocity.Z).Magnitude > Cat.FAST
							or player == target
						local sight = if player == target then tune.sight * 1.5 else tune.sight
						if interesting and distance <= sight and distance < bestDistance then
							best, bestDistance = player, distance
						end
					end
				end
				target = best
				if target then
					state = "Stalk"
					local root = Knock.root(target) :: BasePart
					local goal = Vector3.new(root.Position.X, 0, root.Position.Z)
					if bestDistance <= tune.pounceFrom then
						state = "Pounce"
						leapFrom, leapAt = position, os.clock()
						leapDir = (goal - position).Unit
						facing = leapDir
					else
						moveToward(goal, tune.stalk, dt)
					end
				else
					state = "Patrol"
					-- walk the ellipse at an even pace
					local tangent = Vector3.new(-half.X * math.sin(angle), 0, half.Z * math.cos(angle))
					local onRing = centre + Vector3.new(half.X * math.cos(angle), 0, half.Z * math.sin(angle))
					if (onRing - position).Magnitude > 6 then
						moveToward(onRing, tune.patrol, dt)
					else
						angle += tune.patrol * dt / tangent.Magnitude
						moveToward(
							centre + Vector3.new(half.X * math.cos(angle), 0, half.Z * math.sin(angle)),
							tune.patrol * 1.5,
							dt
						)
					end
				end
			elseif state == "Pounce" then
				local u = (os.clock() - leapAt) / Cat.LEAP_TIME
				position = allowed(leapFrom + leapDir * Cat.LEAP_SPEED * Cat.LEAP_TIME * math.min(u, 1))
				hop = math.sin(math.min(u, 1) * math.pi) * 12
				tilt = 0.18 * math.sin(math.min(u, 1) * math.pi)
				-- anyone under the cat as it lands gets knocked over
				for _, player in Players:GetPlayers() do
					local root = Knock.root(player)
					if root and inPlay(root.Position) then
						local flat = Vector3.new(root.Position.X, 0, root.Position.Z)
						if (flat - position).Magnitude <= Cat.HIT_RADIUS and root.Position.Y < 30 then
							Knock.hit(
								player,
								position - leapDir * 10,
								{ message = "The cat got you!", push = 70, stun = 1.8 }
							)
						end
					end
				end
				if u >= 1 then
					state = "Rest"
					restUntil = os.clock() + (if aggressive then Cat.REST * 0.5 else Cat.REST)
					target = nil
				end
			elseif state == "Rest" then
				if os.clock() >= restUntil then
					state = "Patrol"
					angle = math.atan2((position.Z - centre.Z) / half.Z, (position.X - centre.X) / half.X)
				end
			end

			cat:SetAttribute("State", state)
			sinceSend += dt
			if sinceSend >= 1 / 20 or state == "Pounce" then
				sinceSend = 0
				setPose(hop, tilt)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		if target == player then
			target = nil
		end
	end)
end

return Cat
