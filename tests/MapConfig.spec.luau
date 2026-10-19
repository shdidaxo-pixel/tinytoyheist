--!strict
-- Checks the v6 bedroom numbers hang together. Returns a summary: the number of checks run and a few measured values.
-- Run it from the command bar (cloning so a fresh MapConfig is required each time):
--   local s = game.ServerStorage.TinyToyHeistTests["MapConfig.spec"]:Clone()
--   print(require(s)(game.ReplicatedStorage.Shared:Clone()))
return function(shared: Folder)
	local MapConfig = require(shared:WaitForChild("MapConfig")) :: any
	local checks = 0
	local function check(ok: boolean, message: string)
		assert(ok, message)
		checks += 1
	end
	local function near(a: number, b: number, tolerance: number?): boolean
		return math.abs(a - b) <= (tolerance or 1e-3)
	end
	local cz, r = MapConfig.HOME_CURVE_CENTER_Z, MapConfig.HOME_CURVE_RADIUS
	local centre = Vector3.new(0, 0, cz)

	-- Homes: angles, distance from the curve's centre, facing it, and no two touching at the front.
	check(near(MapConfig.homeAngle(1), 191.25), "home 1 angle")
	check(near(MapConfig.homeAngle(MapConfig.HOLE_COUNT), 348.75), "home 8 angle")
	for i = 1, MapConfig.HOLE_COUNT do
		if i > 1 then
			check(near(MapConfig.homeAngle(i) - MapConfig.homeAngle(i - 1), MapConfig.HOME_STEP), "home step " .. i)
		end
		local front = MapConfig.homeFront(i)
		check(near((front - centre).Magnitude, r), "home " .. i .. " distance")
		local frame = MapConfig.homeFrame(i)
		check(frame.LookVector:Dot((centre - front).Unit) > 0.999, "home " .. i .. " faces the centre")
		check(MapConfig.homeAt((frame * CFrame.new(0, 0, 80)).Position) == i, "homeAt " .. i)
		check(MapConfig.inRoom((frame * CFrame.new(0, 0, -30)).Position), "in front of home " .. i .. " is the room")
		if i < MapConfig.HOLE_COUNT then
			-- home i + 1 sits on home i's -X side
			local gap = (MapConfig.homeCorner(i, -1, 0) - MapConfig.homeCorner(i + 1, 1, 0)).Magnitude
			check(gap >= 6, "homes " .. i .. " and " .. i + 1 .. " touch at the front (" .. gap .. ")")
			local inside = (MapConfig.homeCorner(i, -1, 0) - MapConfig.homeCorner(i + 1, -1, 0)).Magnitude
			check(inside > gap, "home " .. i + 1 .. " is on home " .. i .. "'s -X side")
		end
	end
	-- the end homes meet the shoulders: their outer corners are within a few studs of (+-390, 380)
	check((MapConfig.homeCorner(1, 1, 0) - Vector3.new(-390, 0, cz)).Magnitude < 10, "home 1 reaches the shoulder")
	check(
		(MapConfig.homeCorner(MapConfig.HOLE_COUNT, -1, 0) - Vector3.new(390, 0, cz)).Magnitude < 10,
		"home 8 reaches the shoulder"
	)

	-- Props at the front of a home: inside it, in front of the pen, and not on top of each other.
	local BW = MapConfig.BURROW_WIDTH
	local props = {}
	for name, prop in MapConfig.BURROW_LAYOUT do
		local p, h = prop.position, prop.half
		check(math.abs(p.X) + h.X <= BW / 2, name .. " inside the home's width")
		check(p.Z - h.Z >= 0, name .. " behind the open front")
		check(p.Z + h.Z <= MapConfig.PEN_FRONT, name .. " in front of the pen")
		table.insert(props, { name = name, p = p, h = h })
	end
	for a = 1, #props do
		for b = a + 1, #props do
			local A, B = props[a], props[b]
			local apart = math.abs(A.p.X - B.p.X) >= A.h.X + B.h.X or math.abs(A.p.Z - B.p.Z) >= A.h.Z + B.h.Z
			check(apart, A.name .. " overlaps " .. B.name)
		end
	end
	check(MapConfig.PEN_WIDTH <= BW and MapConfig.PEN_BACK <= MapConfig.BURROW_DEPTH, "the pen fits the home")
	check(MapConfig.PEN_FRONT < MapConfig.PEN_BACK, "the pen has depth")
	local wheel = MapConfig.BURROW_LAYOUT.TrainingWheel
	for level = 1, #MapConfig.HOLE_LEVELS do
		local radius, width = MapConfig.wheelSize(level)
		-- the frame posts stand 1.4 outside the wheel's sides
		check(width / 2 + 2.1 <= wheel.half.X and radius <= wheel.half.Z, "wheel " .. level .. " fits its spot")
	end
	check(near((MapConfig.wheelSize(7)), 10.35), "wheel radius at Level 7")
	check(#MapConfig.SHOWCASE_LEVELS == MapConfig.HOLE_COUNT, "a showcase level per home")

	-- The room outline, the safe ring and the bands.
	check(MapConfig.inRoom(Vector3.new(0, 0, 380)), "the curve's centre is in the room")
	check(MapConfig.inRoom(Vector3.new(0, 0, 1699)), "by the far wall")
	check(MapConfig.inRoom(Vector3.new(200, 0, 1000)), "by the left wall")
	check(MapConfig.inRoom(Vector3.new(300, 0, 400)), "in the left shoulder")
	check(not MapConfig.inRoom(Vector3.new(300, 0, 1000)), "outside the left wall")
	check(not MapConfig.inRoom(Vector3.new(0, 0, 1750)), "past the far wall")
	check(not MapConfig.inRoom(Vector3.new(0, 0, -20)), "behind the homes")
	check(MapConfig.inSafeZone(Vector3.new(0, 0, 40)), "safe zone in front of the middle homes")
	check(not MapConfig.inSafeZone(Vector3.new(0, 0, 300)), "the carpet in the middle is not safe")
	check(not MapConfig.inSafeZone(Vector3.new(0, 0, 600)), "the run is not safe")
	local function zone(x: number, z: number): string?
		local found = MapConfig.zoneAt(Vector3.new(x, 0, z))
		return if found then found.name else nil
	end
	check(zone(0, 300) == "Carpet", "carpet in the middle of the curve")
	check(zone(0, 600) == "Carpet", "carpet band")
	check(zone(0, 1000) == "Wood", "wood band")
	check(zone(0, 1500) == "Creaky", "creaky band")
	check(zone(0, 40) == nil, "no band in the safe zone")
	check(zone(400, 1000) == nil, "no band outside the room")
	check(MapConfig.noiseAt(Vector3.new(0, 0, 40)) == 0, "safe zone is silent")
	check(MapConfig.noiseAt(MapConfig.homeFrame(3) * Vector3.new(0, 0, 60)) == 0, "homes are silent")
	check(MapConfig.noiseAt(Vector3.new(0, 0, 600)) == 1, "carpet noise")
	check(MapConfig.noiseAt(Vector3.new(0, 0, 1000)) == 2, "wood noise")
	check(MapConfig.noiseAt(Vector3.new(-150, 0, 1500)) == 3, "creaky noise")
	check(MapConfig.noiseAt(Vector3.new(40, 0, 1420)) == 6, "the monitor doubles creaky noise")

	-- The train track: closed, the right length, inside the room, clear of the furniture, across the run twice.
	local track = MapConfig.trackPoints(2)
	local path = MapConfig.trackPath()
	check(near(path.length, 1841, 5), "track length " .. path.length)
	check((track[#track] - track[1]).Magnitude < 2.5, "track closes on itself")
	local crossings = 0
	for k, p in track do
		local q = track[k % #track + 1]
		check(math.abs(p.X) <= 200, "track inside the room at " .. tostring(p))
		check(not MapConfig.blocked(p.X, p.Z, MapConfig.TRACK_WIDTH / 2), "track on furniture at " .. tostring(p))
		if (p.X < 0) ~= (q.X < 0) then
			crossings += 1
		end
	end
	check(crossings == 2, "track crosses the run " .. crossings .. " times")
	local position, direction = MapConfig.trackPose(path, 0)
	check((position - track[1]).Magnitude < 0.01 and near(direction.Magnitude, 1), "trackPose at the start")
	local wrapped = MapConfig.trackPose(path, path.length + 10)
	check((wrapped - MapConfig.trackPose(path, 10)).Magnitude < 0.01, "trackPose wraps round the loop")

	-- Traps sit by the walls, well clear of the track, inside the room.
	for k, trap in MapConfig.TRAPS do
		check(MapConfig.inRoom(trap.position), "trap " .. k .. " in the room")
		local clearance = math.huge
		for _, p in track do
			clearance = math.min(clearance, (p - trap.position).Magnitude)
		end
		check(clearance >= 25, "trap " .. k .. " only " .. clearance .. " from the track")
	end

	-- Toy spawns: inside the room, in the band matching their size, not blocked, not crowded.
	local spawns = MapConfig.toySpawns()
	local counts = { S = 0, M = 0, L = 0 }
	local bandOf = { S = "Carpet", M = "Wood", L = "Creaky" }
	local coarse = MapConfig.trackPoints(8)
	for k, s in spawns do
		counts[s.size] += 1
		check(MapConfig.inRoom(s.position), "spawn " .. k .. " in the room")
		check(zone(s.position.X, s.position.Z) == bandOf[s.size], "spawn " .. k .. " in its band")
		check(not MapConfig.blocked(s.position.X, s.position.Z, 10, coarse), "spawn " .. k .. " blocked")
		for j = k + 1, #spawns do
			check((spawns[j].position - s.position).Magnitude >= 18, "spawns " .. k .. " and " .. j .. " too close")
		end
	end
	check(counts.S >= 8 and counts.M >= 8 and counts.L >= 4, "enough spawns in every band")

	-- The tower steps are an easy hop at the default jump height (7.2) and reach the top of the stack.
	local steps = MapConfig.TOWER_STEPS
	check(steps.rise <= 5, "tower steps rise " .. steps.rise)
	check(near(steps.count * steps.rise, 4 * MapConfig.TOWER_BLOCK), "tower steps reach the top")

	-- The flashlight sweeps the run between the carpet and the wood.
	for t = 0, 12, 0.5 do
		local target = MapConfig.flashlightTarget(t)
		check(MapConfig.inRoom(target), "flashlight target in the room at t " .. t)
	end

	return {
		checks = checks,
		trackLength = math.floor(path.length * 10) / 10,
		spawns = string.format("%d S, %d M, %d L", counts.S, counts.M, counts.L),
		floorTiles = #MapConfig.floorTiles(),
	}
end
