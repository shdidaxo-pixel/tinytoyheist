--!strict
-- The cat. It patrols an ellipse on the wood band. It notices a mouse nearby that's carrying a toy or running, stalks
-- it and pounces: a hit knocks you over and you drop your toy. With the lights on (the Kid awake) it's aggressive:
-- it hunts every mouse in the run wherever they are, runs nearly as fast as one, pounces from further and rests
-- less. It never comes into the safe zone or the homes.
-- The server works out where it is and writes it to the Cat's "Pose" attribute; clients move the model smoothly.
-- Attributes on Hazards.Cat: State (Patrol, Stalk, Pounce, Rest, Groom), Aggressive, Pose (CFrame of its Root).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MapConfig")) :: any
local Events = require(script.Parent.Events)
local Knock = require(script.Parent.Knock)

local Cat = {}
local S = MapConfig.SCALE -- the room (and the cat) are shrunk; distances that come from its size shrink too
Cat.CALM = { sight = 70, stalk = 9, patrol = 8, pounceFrom = 26 * S }
-- lights on: it hunts everyone in the run, anywhere, and runs faster than all but a late-game mouse (lights-on
-- session: was 26; Dylan to OK). It also cuts you off: it runs at where you're going, not where you are.
Cat.ANGRY = { sight = 3000, stalk = 60, patrol = 30, pounceFrom = 48 * S }
Cat.LEAD = 0.8 -- lights on: aims up to this many seconds ahead of the mouse
Cat.CARRY_SIGHT = 1.6 -- a mouse dragging a toy is noticed from further away
Cat.LEAP_SPEED = 75 * S
Cat.ANGRY_LEAP_SPEED = 130 * S -- lights on, the pounce is longer and quicker too
Cat.LEAP_TIME = 0.45
Cat.HIT_RADIUS = 16 * S + 2
Cat.REST = 2.5 -- seconds it sits after a pounce
Cat.GROOM = 5 -- calm, on patrol, now and then it stops to lick a paw for this long
Cat.GROOM_EVERY = { 25, 45 } -- seconds between
Cat.HEARS_GRAB = 700 -- it hears a toy being grabbed this far away (full-size studs: the whole start area)
Cat.ALERT_TIME = 12 -- and comes for that mouse for this long
Cat.RUN = 15 -- how fast it comes: just slower than a mouse with a Small toy, faster than with a bigger one
Cat.FAST = 12 -- a mouse moving faster than this catches its eye (calm)

-- Keep a point where the cat may walk: inside the run, away from the homes, off the furniture
local function allowed(p: Vector3): Vector3
	local edge = MapConfig.HALF_WIDTH - 25 * S
	local x = math.clamp(p.X, -edge, edge)
	local z = math.clamp(p.Z, MapConfig.CAT.minZ, MapConfig.LENGTH - 50 * S)
	-- never into the safe ring: stay just inside its inner edge
	local cz = MapConfig.HOME_CURVE_CENTER_Z
	local fromCentre = Vector3.new(x, 0, z - cz)
	if z < cz and fromCentre.Magnitude > MapConfig.SAFE_RADIUS - 8 * S then
		local inside = fromCentre.Unit * (MapConfig.SAFE_RADIUS - 8 * S)
		x, z = inside.X, cz + inside.Z
	end
	-- round the tower and the fallen block
	for _, c in MapConfig.KEEP_OUTS do
		local d = Vector3.new(x - c[1], 0, z - c[2])
		local r = c[3] + 20 * S
		if d.Magnitude < r then
			local out = (if d.Magnitude > 0.01 then d.Unit else Vector3.xAxis) * r
			x, z = c[1] + out.X, c[2] + out.Z
		end
	end
	for _, f in MapConfig.FOOTPRINTS do
		local x0, z0, x1, z1 = f[1] - 22 * S, f[2] - 22 * S, f[3] + 22 * S, f[4] + 22 * S
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
	local alerted: { [Player]: number } = {} -- mice it heard grabbing a toy, until when
	Events.ToyGrabbed.Event:Connect(function(player: Player, at: Vector3)
		if typeof(at) == "Vector3" and (Vector3.new(at.X, 0, at.Z) - position).Magnitude <= Cat.HEARS_GRAB * S then
			alerted[player] = os.clock() + Cat.ALERT_TIME
		end
	end)
	local leapFrom, leapDir, leapAt = position, facing, 0
	local leapSpeed = Cat.LEAP_SPEED
	local restUntil = 0
	local groomUntil, nextGroom = 0, os.clock() + 15

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

			if state == "Patrol" or state == "Stalk" or state == "Groom" then
				-- pick (or keep) a target
				local best, bestDistance = nil, math.huge
				for _, player in Players:GetPlayers() do
					local root = Knock.root(player)
					if root and inPlay(root.Position) and Knock.ready(player) then
						local distance = (Vector3.new(root.Position.X, 0, root.Position.Z) - position).Magnitude
						local velocity = root.AssemblyLinearVelocity
						local heard = (alerted[player] or 0) > os.clock()
						local interesting = aggressive
							or heard
							or player:GetAttribute("Carrying")
							or Vector3.new(velocity.X, 0, velocity.Z).Magnitude > Cat.FAST
							or player == target
						local sight = tune.sight
						if player:GetAttribute("Carrying") then
							sight *= Cat.CARRY_SIGHT
						end
						if player == target then
							sight *= 1.5
						end
						if heard then
							sight = math.max(sight, Cat.HEARS_GRAB * S * 1.3)
						end
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
					if aggressive then
						-- cut it off: where it'll be by the time the cat gets there
						local v = root.AssemblyLinearVelocity
						local lead = math.min(Cat.LEAD, bestDistance / tune.stalk)
						goal += Vector3.new(v.X, 0, v.Z) * lead
					end
					if bestDistance <= tune.pounceFrom then
						state = "Pounce"
						leapFrom, leapAt = position, os.clock()
						leapDir = (goal - position).Unit
						leapSpeed = if aggressive then Cat.ANGRY_LEAP_SPEED else Cat.LEAP_SPEED
						facing = leapDir
					else
						local running = (alerted[target :: Player] or 0) > os.clock()
						moveToward(goal, if running then math.max(tune.stalk, Cat.RUN) else tune.stalk, dt)
					end
				elseif state == "Patrol" and not aggressive and os.clock() >= nextGroom then
					-- now and then it sits and licks a paw (CatView); anyone interesting still gets stalked (above)
					state = "Groom"
					groomUntil = os.clock() + Cat.GROOM
					nextGroom = groomUntil
						+ Cat.GROOM_EVERY[1]
						+ math.random() * (Cat.GROOM_EVERY[2] - Cat.GROOM_EVERY[1])
				elseif not (state == "Groom" and os.clock() < groomUntil and not aggressive) then
					state = "Patrol"
					-- walk the ellipse at an even pace
					local tangent = Vector3.new(-half.X * math.sin(angle), 0, half.Z * math.cos(angle))
					local onRing = centre + Vector3.new(half.X * math.cos(angle), 0, half.Z * math.sin(angle))
					-- the point on the ring keeps moving even if something is in the way, so it never gets stuck
					if (onRing - position).Magnitude < 40 * S then
						angle += tune.patrol * dt / tangent.Magnitude
					else
						angle += tune.patrol * 0.3 * dt / tangent.Magnitude
					end
					moveToward(
						centre + Vector3.new(half.X * math.cos(angle), 0, half.Z * math.sin(angle)),
						tune.patrol * 1.5,
						dt
					)
				end
			elseif state == "Pounce" then
				local u = (os.clock() - leapAt) / Cat.LEAP_TIME
				position = allowed(leapFrom + leapDir * leapSpeed * Cat.LEAP_TIME * math.min(u, 1))
				hop = math.sin(math.min(u, 1) * math.pi) * 12 * S
				tilt = 0.18 * math.sin(math.min(u, 1) * math.pi)
				-- anyone under the cat as it lands gets knocked over
				for _, player in Players:GetPlayers() do
					local root = Knock.root(player)
					if root and inPlay(root.Position) then
						local flat = Vector3.new(root.Position.X, 0, root.Position.Z)
						if (flat - position).Magnitude <= Cat.HIT_RADIUS and root.Position.Y < 30 * S + 6 then
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
					restUntil = os.clock() + (if aggressive then Cat.REST * 0.3 else Cat.REST)
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
		alerted[player] = nil
		if target == player then
			target = nil
		end
	end)
end

return Cat
