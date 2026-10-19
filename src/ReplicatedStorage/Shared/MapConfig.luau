--!strict
-- Every number for the Kid's Bedroom (concept v6), shared by the map builder (tools/build-bedroom.luau) and game code.
-- One long run: 8 homes side by side in a half-circle wall at the start (open fronts, open tops), a safe zone in front
-- of them, then three floor bands down the run (carpet, wood, creaky boards) to the bed along the runner's right-hand
-- wall and the open hallway door straight ahead. Studs; x across (a runner facing +z has +x on their LEFT), z down
-- the room from the start, y up. The floor is at y = 0.

--
-- Sizes: the numbers below are the full-size layout. The map is built at that size and then shrunk to SCALE, so this
-- module returns the shrunk numbers (what game code sees in the world); MapConfig.unscaled holds the full-size ones
-- for the builder. Change SCALE to make the whole room bigger or smaller.

export type BurrowProp = { position: Vector3, half: Vector3 }
export type Zone = { name: string, untilZ: number, noise: number, toySize: string }
export type TrackPath = { points: { Vector3 }, distances: { number }, length: number }

local SCALE = 0.65 -- Dylan, 19 Oct: the room felt too big and slow to cross

local function build(S: number): any
	local MapConfig = {}
	MapConfig.SCALE = S

	-- Room ---------------------------------------------------------------------------------------------------------------
	MapConfig.HALF_WIDTH = 210 * S -- the run is 420 wide; the long walls' inner faces are at x = +-210
	MapConfig.LENGTH = 1700 * S -- the far wall's inner face is at z = 1700
	MapConfig.WALL_HEIGHT = 320 * S
	MapConfig.WALL_THICKNESS = 8 * S
	MapConfig.BASEBOARD_HEIGHT = 15 * S
	MapConfig.FURNITURE_SCALE = 1.25 * S -- the bed and the Kid, from the first-draft (v3) sizes

	-- The start: a half-circle wall holding the homes, then shoulders in to the run
	MapConfig.HOME_CURVE_RADIUS = 380 * S -- the homes' open fronts sit on this circle
	MapConfig.HOME_CURVE_CENTER_Z = 380 * S -- centre (0, 380); the curve's back touches z = 0
	MapConfig.SHOULDER_START_X = 390 * S -- the shoulders run from (+-390, 380)...
	MapConfig.SHOULDER_END_Z = 510 * S -- ...to (+-210, 510)

	-- The hallway door, centred in the far wall and open; a short hallway behind it (blocked until the next room exists)
	MapConfig.DOOR_WIDTH = 130 * S
	MapConfig.DOOR_HEIGHT = 230 * S
	MapConfig.HALLWAY_WIDTH = 190 * S
	MapConfig.HALLWAY_LENGTH = 420 * S

	-- Homes --------------------------------------------------------------------------------------------------------------
	MapConfig.HOLE_COUNT = 8
	MapConfig.HOME_STEP = 22.5 -- degrees between homes: home 1 at 191.25, home 8 at 348.75
	MapConfig.BURROW_WIDTH = 130 * S -- the open front; the side studs sit just outside it
	MapConfig.BURROW_DEPTH = 170 * S
	MapConfig.BURROW_FLOOR_LIFT = 0.2 * S -- home floors sit just above the room floor that reaches under their fronts
	MapConfig.HOME_STUD = 5 * S -- the side studs, which are each home's side walls
	MapConfig.HOME_WALL_DEPTH = 178 * S -- the walls between homes reach this deep, past the back sheathing
	MapConfig.MAX_SLOTS = 20 -- capacity at Level 7 (the VIP Hole adds 3)
	MapConfig.PEN_FRONT = 40 * S -- the toy pen runs from 40 deep...
	MapConfig.PEN_BACK = 158 * S -- ...to 158 deep
	MapConfig.PEN_WIDTH = 116 * S
	-- The owner's name floats over the middle of the open front, always facing you (like Steal an Egg)
	MapConfig.SIGN = { position = Vector3.new(0, 70, -6) * S }

	-- The front of each home, in home space (x across, z into the wall; walking in, -x is on your right).
	-- Unchanged from the old burrows, so game code that finds these keeps working. half = half the footprint in x and z.
	MapConfig.BURROW_LAYOUT = {
		LockButton = { position = Vector3.new(-30, 0, 12) * S, half = Vector3.new(4.5, 0, 4.5) * S },
		-- an invisible spawn pad where the matchbox bed was (the bed and the cash thimble went, Dylan 19 Oct)
		Spawn = { position = Vector3.new(28, 0, 30) * S, half = Vector3.new(8, 0, 5.2) * S },
		ToyIndex = { position = Vector3.new(-52, 0, 30) * S, half = Vector3.new(5.5, 0, 5.5) * S }, -- turned 45 degrees
		TrainingWheel = { position = Vector3.new(50, 0, 22) * S, half = Vector3.new(7, 0, 10.5) * S },
	} :: { [string]: BurrowProp }

	-- Home levels: capacity and look. Costs live with the economy.
	MapConfig.HOLE_LEVELS = {
		{ slots = 6, theme = "Cardboard" },
		{ slots = 8, theme = "SockLined" },
		{ slots = 10, theme = "ToyBricks" },
		{ slots = 12, theme = "CosyCabin" },
		{ slots = 15, theme = "CandyLand" },
		{ slots = 18, theme = "ArcadeNeon" },
		{ slots = 20, theme = "GoldenVault" },
	}
	-- The levels the builder dresses the homes at, so every theme shows in Studio (game code sets the real ones)
	MapConfig.SHOWCASE_LEVELS = { 3, 1, 5, 2, 7, 4, 1, 6 }

	-- The Speed wheel grows with the home's level.
	function MapConfig.wheelSize(level: number): (number, number)
		return (6.5 + 0.55 * level) * S, (7 + 0.3 * level) * S -- radius, width
	end

	function MapConfig.wheelSpin(level: number): number
		return 1.2 + 0.25 * level -- radians a second while idle
	end

	function MapConfig.wheelRungs(level: number): number
		return 14 + 2 * level
	end

	-- Floor bands ----------------------------------------------------------------------------------------------------------
	-- Noise multiplies every sound made while standing on it.
	MapConfig.SAFE_RADIUS = 285 * S -- the safe ring: from r 285 out to the homes' fronts, round the curve's centre
	MapConfig.SAFE_LINE = 5 * S -- the white edge line just inside it
	MapConfig.ZONES = {
		{ name = "Carpet", untilZ = 900 * S, noise = 1, toySize = "S" },
		{ name = "Wood", untilZ = 1300 * S, noise = 2, toySize = "M" },
		{ name = "Creaky", untilZ = 1700 * S, noise = 3, toySize = "L" },
	} :: { Zone }
	MapConfig.FLOOR_TILE_SIZE = 24 * S

	-- Furniture and landmarks (world positions) ----------------------------------------------------------------------------
	MapConfig.BED = { position = Vector3.new(-110, 0, 1600) * S, turn = 180 } -- headboard toward the far wall
	MapConfig.NIGHTSTAND = Vector3.new(-172, 0, 1650) * S
	MapConfig.DESK = { position = Vector3.new(158, 0, 1420) * S, turn = -90 } -- its front faces the room
	MapConfig.WINDOW = { z0 = 1320 * S, z1 = 1520 * S, y0 = 155 * S, y1 = 305 * S } -- on the x = +210 wall, above the desk
	MapConfig.NIGHT_LIGHT = Vector3.new(150, 18, 1700) * S -- in an outlet on the far wall, left of the door
	MapConfig.TOWER = Vector3.new(45, 0, 800) * S
	MapConfig.TOWER_BLOCK = 30 * S
	-- The spiral of toy-brick steps round the tower. Default jump height is 7.2, so a 4.8 rise is an easy hop.
	MapConfig.TOWER_STEPS = { count = 25, rise = 4.8 * S, radius = 27 * S, firstAngle = 200, angleStep = 24 }
	MapConfig.FALLEN_BLOCK = { position = Vector3.new(-188, 0, 760) * S, turn = 0.6 }

	-- Hazards --------------------------------------------------------------------------------------------------------------
	-- The cat patrols the carpet circle in front of the homes, near the first toys you grab (it comes running when
	-- it hears one being grabbed). It never comes into the safe ring or the homes, nor closer to the start than minZ.
	MapConfig.CAT = {
		home = Vector3.new(0, 0, 420) * S,
		patrolCenter = Vector3.new(0, 0, 400) * S,
		patrolHalf = Vector3.new(150, 0, 140) * S,
		minZ = 60 * S,
	}
	MapConfig.TRAPS = {
		{ position = Vector3.new(-188, 0, 850) * S, turn = 0.15 },
		{ position = Vector3.new(190, 0, 880) * S, turn = -0.15 },
		{ position = Vector3.new(-188, 0, 1150) * S, turn = 0.1 },
		{ position = Vector3.new(190, 0, 1290) * S, turn = -0.1 },
	}
	MapConfig.LOOSE_BOARDS = {
		Vector3.new(20, 0, 1320) * S,
		Vector3.new(70, 0, 1400) * S,
		Vector3.new(10, 0, 1470) * S,
		Vector3.new(60, 0, 1550) * S,
		Vector3.new(20, 0, 1615) * S,
		Vector3.new(90, 0, 1600) * S,
	}
	MapConfig.DUCKS = {
		{ position = Vector3.new(50, 0, 1360) * S, turn = 1 },
		{ position = Vector3.new(85, 0, 1500) * S, turn = 4 },
	}
	-- Toy bricks lying about; the 1st, 3rd and 5th have a second brick on top.
	MapConfig.BRICKS = {
		Vector3.new(-30, 0, 1000) * S,
		Vector3.new(50, 0, 1180) * S,
		Vector3.new(40, 0, 1300) * S,
		Vector3.new(0, 0, 1440) * S,
		Vector3.new(60, 0, 960) * S,
	}
	MapConfig.MONITOR = Vector3.new(-152, 84, 1670) * S -- the baby monitor on the nightstand
	MapConfig.MONITOR_ZONE = { center = Vector3.new(40, 0, 1420) * S, radius = 105 * S, noise = 2 }

	-- Where the Kid's flashlight points at time t (seconds) while he sits up: a sweep back down the run.
	function MapConfig.flashlightTarget(t: number): Vector3
		local s = math.sin(t * 0.5)
		return Vector3.new(140 * s, 0, 1000 - 300 * math.abs(s)) * S
	end

	-- The train: a closed loop through these points (x, z), smoothed (centripetal Catmull-Rom). About 1841 studs.
	MapConfig.TRAIN_SPEED = 60 * S -- studs a second: a lap in about 31 s
	MapConfig.TRAIN_CARS = 5 -- including the engine
	MapConfig.TRAIN_CAR_GAP = 27 * S
	MapConfig.TRAIN_SCALE = 1.4 * S
	MapConfig.TRACK_WIDTH = 11 * S
	MapConfig.TRACK_HEIGHT = 1.6 * S
	MapConfig.TRACK_CONTROL = {
		{ 140 * S, 640 * S },
		{ 175 * S, 760 * S },
		{ 125 * S, 880 * S },
		{ 165 * S, 1000 * S },
		{ 115 * S, 1120 * S },
		{ 140 * S, 1220 * S },
		{ 40 * S, 1250 * S },
		{ -70 * S, 1235 * S },
		{ -150 * S, 1170 * S },
		{ -105 * S, 1050 * S },
		{ -160 * S, 930 * S },
		{ -100 * S, 810 * S },
		{ -150 * S, 700 * S },
		{ -110 * S, 610 * S },
		{ -20 * S, 585 * S },
		{ 70 * S, 600 * S },
	}

	local function toRadians(degrees: number): number
		return degrees * math.pi / 180
	end

	-- Homes ----------------------------------------------------------------------------------------------------------------

	function MapConfig.homeAngle(index: number): number
		assert(index >= 1 and index <= MapConfig.HOLE_COUNT, "home index out of range")
		return 270 + (index - (MapConfig.HOLE_COUNT + 1) / 2) * MapConfig.HOME_STEP
	end

	-- The middle of home i's open front, on the floor.
	function MapConfig.homeFront(index: number): Vector3
		local a = toRadians(MapConfig.homeAngle(index))
		local r = MapConfig.HOME_CURVE_RADIUS
		return Vector3.new(r * math.cos(a), 0, MapConfig.HOME_CURVE_CENTER_Z + r * math.sin(a))
	end

	-- Home i's frame: at the middle of its open front, LookVector toward the curve's centre (into the room), so +Z points
	-- back into the wall. Place things with homeFrame(i) * CFrame.new(x, y, z) using BURROW_LAYOUT positions. Home i + 1
	-- is on home i's -X side.
	function MapConfig.homeFrame(index: number): CFrame
		local p = MapConfig.homeFront(index)
		return CFrame.lookAt(p, Vector3.new(0, 0, MapConfig.HOME_CURVE_CENTER_Z))
	end

	-- Old name, so game code written for burrows still works.
	MapConfig.burrowFrame = MapConfig.homeFrame

	-- A home's front corner (side = -1 or 1, the outer face of that side stud), at depth z, in world space. The walls
	-- between homes run between these.
	function MapConfig.homeCorner(index: number, side: number, depth: number): Vector3
		local x = side * (MapConfig.BURROW_WIDTH / 2 + MapConfig.HOME_STUD)
		return (MapConfig.homeFrame(index) * CFrame.new(x, 0, depth)).Position
	end

	-- The home a position is inside (between its side studs, from its open front to its back), or nil.
	function MapConfig.homeAt(position: Vector3): number?
		local cz = MapConfig.HOME_CURVE_CENTER_Z
		if position.Z > cz then
			return nil
		end
		for i = 1, MapConfig.HOLE_COUNT do
			local p = MapConfig.homeFrame(i):PointToObjectSpace(Vector3.new(position.X, 0, position.Z))
			if math.abs(p.X) <= MapConfig.BURROW_WIDTH / 2 and p.Z >= 0 and p.Z <= MapConfig.BURROW_DEPTH then
				return i
			end
		end
		return nil
	end

	-- Zones ----------------------------------------------------------------------------------------------------------------

	-- Inside the walkable floor of the room (half-circle start, shoulders, run)? Homes are not part of the room.
	function MapConfig.inRoom(position: Vector3): boolean
		local x, z = position.X, position.Z
		local cz, r, hw = MapConfig.HOME_CURVE_CENTER_Z, MapConfig.HOME_CURVE_RADIUS, MapConfig.HALF_WIDTH
		if z < 0 then
			return false
		elseif z < cz then
			return math.sqrt(x * x + (z - cz) ^ 2) <= r
		elseif z < MapConfig.SHOULDER_END_Z then
			local x0 = MapConfig.SHOULDER_START_X
			local limit = x0 - (z - cz) * (x0 - hw) / (MapConfig.SHOULDER_END_Z - cz)
			return math.abs(x) <= limit
		end
		return math.abs(x) <= hw and z <= MapConfig.LENGTH
	end

	-- The teal ring in front of the homes (out to the fronts' corners).
	function MapConfig.inSafeZone(position: Vector3): boolean
		local cz = MapConfig.HOME_CURVE_CENTER_Z
		local d = math.sqrt(position.X ^ 2 + (position.Z - cz) ^ 2)
		return position.Z < cz and d >= MapConfig.SAFE_RADIUS and d <= MapConfig.HOME_CURVE_RADIUS + 12 * S
	end

	-- The band under a position in the room, or nil in the safe zone and outside the room (homes, walls).
	function MapConfig.zoneAt(position: Vector3): Zone?
		if not MapConfig.inRoom(position) or MapConfig.inSafeZone(position) then
			return nil
		end
		for _, zone in MapConfig.ZONES do
			if position.Z <= zone.untilZ then
				return zone
			end
		end
		return nil
	end

	-- How much a sound made here counts: 0 in the safe zone and the homes, the band's multiplier in the run, doubled in
	-- the baby monitor's zone.
	function MapConfig.noiseAt(position: Vector3): number
		if MapConfig.inSafeZone(position) or MapConfig.homeAt(position) then
			return 0
		end
		local zone = MapConfig.zoneAt(position)
		local noise = if zone then zone.noise else 1
		local m = MapConfig.MONITOR_ZONE
		if (Vector3.new(position.X, 0, position.Z) - m.center).Magnitude <= m.radius then
			noise *= m.noise
		end
		return noise
	end

	-- Voxel floor tile centres (y = 0) and the band each takes its look from, row by row from the start of each band.
	-- Only used when the tile meshes exist; the band floors underneath match them, so the ragged edges don't show.
	function MapConfig.floorTiles(): { { position: Vector3, zone: string } }
		local out = {}
		local size = MapConfig.FLOOR_TILE_SIZE
		local half = size / 2
		local cz = MapConfig.HOME_CURVE_CENTER_Z
		local inner = MapConfig.SAFE_RADIUS - MapConfig.SAFE_LINE
		-- the carpet in the middle of the safe ring
		for ix = -10, 10 do
			for iz = 0, 10 do
				local p = Vector3.new(ix * size, 0, cz - half - iz * size)
				if math.sqrt(p.X ^ 2 + (p.Z - cz) ^ 2) + half * math.sqrt(2) <= inner then
					table.insert(out, { position = p, zone = "Carpet" })
				end
			end
		end
		-- the bands down the run
		local from = cz
		for _, zone in MapConfig.ZONES do
			local z = from + half
			while z + half <= zone.untilZ do
				for ix = -17, 17 do
					local p = Vector3.new(ix * size, 0, z)
					local corners = {
						p + Vector3.new(-half, 0, -half),
						p + Vector3.new(half, 0, -half),
						p + Vector3.new(-half, 0, half),
						p + Vector3.new(half, 0, half),
					}
					local keep = false
					for _, c in corners do
						keep = keep or MapConfig.inRoom(c)
					end
					if keep then
						table.insert(out, { position = p, zone = zone.name })
					end
				end
				z += size
			end
			from = zone.untilZ
		end
		return out
	end

	-- Train track ----------------------------------------------------------------------------------------------------------

	-- Centripetal Catmull-Rom between p1 and p2 (Barry-Goldman), t in 0..1.
	local function catmullRom(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: number): Vector3
		local function knot(ti: number, a: Vector3, b: Vector3): number
			return ti + math.sqrt((b - a).Magnitude) -- alpha = 0.5
		end
		local t0 = 0
		local t1 = knot(t0, p0, p1)
		local t2 = knot(t1, p1, p2)
		local t3 = knot(t2, p2, p3)
		local u = t1 + (t2 - t1) * t
		local a1 = p0 * ((t1 - u) / (t1 - t0)) + p1 * ((u - t0) / (t1 - t0))
		local a2 = p1 * ((t2 - u) / (t2 - t1)) + p2 * ((u - t1) / (t2 - t1))
		local a3 = p2 * ((t3 - u) / (t3 - t2)) + p3 * ((u - t2) / (t3 - t2))
		local b1 = a1 * ((t2 - u) / (t2 - t0)) + a2 * ((u - t0) / (t2 - t0))
		local b2 = a2 * ((t3 - u) / (t3 - t1)) + a3 * ((u - t1) / (t3 - t1))
		return b1 * ((t2 - u) / (t2 - t1)) + b2 * ((u - t1) / (t2 - t1))
	end

	-- The smoothed loop as a dense polyline (40 points between control points), y = 0.
	local function denseTrack(): { Vector3 }
		local control = {}
		for _, xz in MapConfig.TRACK_CONTROL do
			table.insert(control, Vector3.new(xz[1], 0, xz[2]))
		end
		local n = #control
		local dense = {}
		for i = 1, n do
			local p0 = control[(i - 2) % n + 1]
			local p1 = control[i]
			local p2 = control[i % n + 1]
			local p3 = control[(i + 1) % n + 1]
			for k = 0, 39 do
				table.insert(dense, catmullRom(p0, p1, p2, p3, k / 40))
			end
		end
		return dense
	end

	-- Points every `spacing` studs round the closed track (y = 0), evenly spaced by arc length. The last point is less
	-- than `spacing` short of the first.
	function MapConfig.trackPoints(spacing: number): { Vector3 }
		local dense = denseTrack()
		local out = { dense[1] }
		local carried = 0
		for i = 2, #dense + 1 do
			local a, b = dense[i - 1], dense[(i - 1) % #dense + 1]
			local segment = (b - a).Magnitude
			while carried + segment >= spacing do
				local t = (spacing - carried) / segment
				a = a:Lerp(b, t)
				segment = (b - a).Magnitude
				carried = 0
				table.insert(out, a)
			end
			carried += segment
		end
		if (out[#out] - out[1]).Magnitude < spacing * 0.5 then
			table.remove(out) -- the walk ended right back on the first point
		end
		return out
	end

	-- The track as a path you can sample by distance: points every 2 studs and the distance to each.
	function MapConfig.trackPath(): TrackPath
		local points = MapConfig.trackPoints(2)
		local distances = { 0 }
		for i = 2, #points do
			distances[i] = distances[i - 1] + (points[i] - points[i - 1]).Magnitude
		end
		local length = distances[#points] + (points[1] - points[#points]).Magnitude
		return { points = points, distances = distances, length = length }
	end

	-- Where along the track distance s is (wrapping round the loop), and the direction of travel there.
	function MapConfig.trackPose(path: TrackPath, s: number): (Vector3, Vector3)
		local points, distances = path.points, path.distances
		s %= path.length
		local lo, hi = 1, #points
		while lo < hi do -- the last point at or before s
			local mid = (lo + hi + 1) // 2
			if distances[mid] <= s then
				lo = mid
			else
				hi = mid - 1
			end
		end
		local a = points[lo]
		local b = points[lo % #points + 1]
		local nextDistance = if lo == #points then path.length else distances[lo + 1]
		local t = (s - distances[lo]) / math.max(nextDistance - distances[lo], 1e-6)
		return a:Lerp(b, t), (b - a).Unit
	end

	-- Where each train car is at time t (seconds): car 1 is the engine, the others follow TRAIN_CAR_GAP apart.
	function MapConfig.trainCarDistance(t: number, car: number): number
		return t * MapConfig.TRAIN_SPEED + 300 * S - (car - 1) * MapConfig.TRAIN_CAR_GAP
	end

	-- Sleeping-toy spawns --------------------------------------------------------------------------------------------------

	-- Furniture footprints (x0, z0, x1, z1) and round keep-outs (x, z, r): no spawns or props inside them.
	MapConfig.FOOTPRINTS = {
		{ -210 * S, 1275 * S, -10 * S, 1600 * S }, -- bed
		{ -210 * S, 1610 * S, -134 * S, 1690 * S }, -- nightstand
		{ 106 * S, 1330 * S, 212 * S, 1510 * S }, -- desk
		{ 40 * S, 1385 * S, 112 * S, 1455 * S }, -- chair
		{ -70 * S, 1640 * S, 70 * S, 1700 * S }, -- in front of the door
	}
	MapConfig.KEEP_OUTS = { { 45 * S, 800 * S, 40 * S }, { -188 * S, 760 * S, 26 * S } } -- tower, fallen block

	-- Is a circle of radius r at (x, z) on furniture, too near a long wall, or (given track points) near the track?
	function MapConfig.blocked(x: number, z: number, r: number, track: { Vector3 }?): boolean
		for _, f in MapConfig.FOOTPRINTS do
			if x > f[1] - r and x < f[3] + r and z > f[2] - r and z < f[4] + r then
				return true
			end
		end
		for _, c in MapConfig.KEEP_OUTS do
			if math.sqrt((x - c[1]) ^ 2 + (z - c[2]) ^ 2) < c[3] + r then
				return true
			end
		end
		if math.abs(x) > MapConfig.HALF_WIDTH - r - 6 * S then
			return true
		end
		if track then
			for _, p in track do
				if math.sqrt((p.X - x) ^ 2 + (p.Z - z) ^ 2) < 8 * S + r then
					return true
				end
			end
		end
		return false
	end

	-- Rows down each band, like eggs down a run (full-size numbers; scaled where they are used). Each candidate gets a
	-- small fixed jitter and is dropped if blocked.
	MapConfig.SPAWN_ROWS = {
		{ size = "S", rows = { 590, 680, 770, 860 }, columns = { -80, -25, 30, 85 }, oddShift = -25 },
		{ size = "M", rows = { 950, 1040, 1130, 1220 }, columns = { -70, -5, 60 }, oddShift = 25 },
		{ size = "L", rows = { 1330, 1430, 1530 }, columns = { 12, 58 }, oddShift = 20 },
	}

	-- The first toys sit right in front of the homes, just past the safe ring (like Steal an Egg): one facing each
	-- home, and a second ring between them a little further in. Full-size radii round the curve's centre.
	MapConfig.SPAWN_ARCS = {
		{ size = "S", radius = 255, offset = 0 },
		{ size = "S", radius = 175, offset = 0.5 },
	}

	function MapConfig.toySpawns(): { { position: Vector3, size: string } }
		local out = {}
		local track = MapConfig.trackPoints(8)
		for _, arc in MapConfig.SPAWN_ARCS do
			for i = 1, MapConfig.HOLE_COUNT do
				local a = math.rad(MapConfig.homeAngle(i) + arc.offset * MapConfig.HOME_STEP)
				local p = Vector3.new(math.cos(a) * arc.radius, 0, 380 + math.sin(a) * arc.radius) * S
				if (arc.offset == 0 or i < MapConfig.HOLE_COUNT) and not MapConfig.blocked(p.X, p.Z, 10 * S, track) then
					table.insert(out, { position = p, size = arc.size })
				end
			end
		end
		for _, band in MapConfig.SPAWN_ROWS do
			for r, z in band.rows do
				for k, x0 in band.columns do
					local x = x0 + (if r % 2 == 0 then band.oddShift else 0) -- rows 2 and 4 shift (1-based)
					local jx = ((k - 1) * 37 + z) % 13 - 6
					local jz = ((k - 1) * 53 + z) % 15 - 7
					if not MapConfig.blocked((x + jx) * S, (z + jz) * S, 10 * S, track) then
						table.insert(out, { position = Vector3.new(x + jx, 0, z + jz) * S, size = band.size })
					end
				end
			end
		end
		return out
	end

	return MapConfig
end

local MapConfig = build(SCALE)
MapConfig.unscaled = build(1)
return MapConfig
