--!strict
-- Every number for the Kid's Bedroom (concept v6), shared by the map builder (tools/build-bedroom.luau) and game code.
-- One long run: 8 homes side by side in a half-circle wall at the start (open fronts, open tops), a safe zone in front
-- of them, then three floor bands down the run (carpet, wood, creaky boards) to the bed along the runner's right-hand
-- wall and the open hallway door straight ahead. Studs; x across (a runner facing +z has +x on their LEFT), z down
-- the room from the start, y up. The floor is at y = 0.

local MapConfig = {}

-- Room ---------------------------------------------------------------------------------------------------------------
MapConfig.HALF_WIDTH = 210 -- the run is 420 wide; the long walls' inner faces are at x = +-210
MapConfig.LENGTH = 1700 -- the far wall's inner face is at z = 1700
MapConfig.WALL_HEIGHT = 320
MapConfig.WALL_THICKNESS = 8
MapConfig.BASEBOARD_HEIGHT = 15
MapConfig.FURNITURE_SCALE = 1.25 -- the bed and the Kid, from the first-draft (v3) sizes

-- The start: a half-circle wall holding the homes, then shoulders in to the run
MapConfig.HOME_CURVE_RADIUS = 380 -- the homes' open fronts sit on this circle
MapConfig.HOME_CURVE_CENTER_Z = 380 -- centre (0, 380); the curve's back touches z = 0
MapConfig.SHOULDER_START_X = 390 -- the shoulders run from (+-390, 380)...
MapConfig.SHOULDER_END_Z = 510 -- ...to (+-210, 510)

-- The hallway door, centred in the far wall and open; a short hallway behind it (blocked until the next room exists)
MapConfig.DOOR_WIDTH = 130
MapConfig.DOOR_HEIGHT = 230
MapConfig.HALLWAY_WIDTH = 190
MapConfig.HALLWAY_LENGTH = 420

-- Homes --------------------------------------------------------------------------------------------------------------
MapConfig.HOLE_COUNT = 8
MapConfig.HOME_STEP = 22.5 -- degrees between homes: home 1 at 191.25, home 8 at 348.75
MapConfig.BURROW_WIDTH = 130 -- the open front; the side studs sit just outside it
MapConfig.BURROW_DEPTH = 170
MapConfig.BURROW_FLOOR_LIFT = 0.2 -- home floors sit just above the room floor that reaches under their fronts
MapConfig.HOME_STUD = 5 -- the side studs, which are each home's side walls
MapConfig.HOME_WALL_DEPTH = 178 -- the walls between homes reach this deep, past the back sheathing
MapConfig.MAX_SLOTS = 20 -- capacity at Level 7 (the VIP Hole adds 3)
MapConfig.PEN_FRONT = 40 -- the toy pen runs from 40 deep...
MapConfig.PEN_BACK = 158 -- ...to 158 deep
MapConfig.PEN_WIDTH = 116
MapConfig.SIGN = Vector3.new(-54, 0, 3) -- the owner's sign on its stick, at the front corner on your right walking in

-- The front of each home, in home space (x across, z into the wall; walking in, -x is on your right).
-- Unchanged from the old burrows, so game code that finds these keeps working. half = half the footprint in x and z.
export type BurrowProp = { position: Vector3, half: Vector3 }
MapConfig.BURROW_LAYOUT = {
	LockButton = { position = Vector3.new(-30, 0, 12), half = Vector3.new(4.5, 0, 4.5) },
	CashPile = { position = Vector3.new(28, 0, 14), half = Vector3.new(5.5, 0, 5.5) },
	Spawn = { position = Vector3.new(0, 0, 24), half = Vector3.new(8, 0, 5.2) },
	ToyIndex = { position = Vector3.new(-52, 0, 30), half = Vector3.new(4.5, 0, 3.5) },
	TrainingWheel = { position = Vector3.new(50, 0, 22), half = Vector3.new(7, 0, 10.5) },
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
	return 6.5 + 0.55 * level, 7 + 0.3 * level -- radius, width
end

function MapConfig.wheelSpin(level: number): number
	return 1.2 + 0.25 * level -- radians a second while idle
end

function MapConfig.wheelRungs(level: number): number
	return 14 + 2 * level
end

-- Floor bands ----------------------------------------------------------------------------------------------------------
-- Noise multiplies every sound made while standing on it.
export type Zone = { name: string, untilZ: number, noise: number, toySize: string }
MapConfig.SAFE_RADIUS = 240 -- the safe ring: from r 240 out to the homes' fronts, round the curve's centre
MapConfig.SAFE_LINE = 5 -- the white edge line just inside it
MapConfig.ZONES = {
	{ name = "Carpet", untilZ = 900, noise = 1, toySize = "S" },
	{ name = "Wood", untilZ = 1300, noise = 2, toySize = "M" },
	{ name = "Creaky", untilZ = 1700, noise = 3, toySize = "L" },
} :: { Zone }
MapConfig.FLOOR_TILE_SIZE = 24

-- Furniture and landmarks (world positions) ----------------------------------------------------------------------------
MapConfig.BED = { position = Vector3.new(-110, 0, 1600), turn = 180 } -- headboard toward the far wall
MapConfig.NIGHTSTAND = Vector3.new(-172, 0, 1650)
MapConfig.DESK = { position = Vector3.new(158, 0, 1420), turn = -90 } -- its front faces the room
MapConfig.WINDOW = { z0 = 1320, z1 = 1520, y0 = 155, y1 = 305 } -- on the x = +210 wall, above the desk
MapConfig.NIGHT_LIGHT = Vector3.new(150, 18, 1700) -- in an outlet on the far wall, left of the door
MapConfig.TOWER = Vector3.new(45, 0, 800)
MapConfig.TOWER_BLOCK = 30
-- The spiral of toy-brick steps round the tower. Default jump height is 7.2, so a 4.8 rise is an easy hop.
MapConfig.TOWER_STEPS = { count = 25, rise = 4.8, radius = 27, firstAngle = 200, angleStep = 24 }
MapConfig.FALLEN_BLOCK = { position = Vector3.new(-188, 0, 760), turn = 0.6 }

-- Hazards --------------------------------------------------------------------------------------------------------------
-- The cat patrols an ellipse on the wood band and never comes closer to the homes than minZ.
MapConfig.CAT = {
	home = Vector3.new(-20, 0, 1150),
	patrolCenter = Vector3.new(0, 0, 1150),
	patrolHalf = Vector3.new(150, 0, 60),
	minZ = 560,
}
MapConfig.TRAPS = {
	{ position = Vector3.new(-188, 0, 850), turn = 0.15 },
	{ position = Vector3.new(190, 0, 880), turn = -0.15 },
	{ position = Vector3.new(-188, 0, 1150), turn = 0.1 },
	{ position = Vector3.new(190, 0, 1290), turn = -0.1 },
}
MapConfig.LOOSE_BOARDS = {
	Vector3.new(20, 0, 1320),
	Vector3.new(70, 0, 1400),
	Vector3.new(10, 0, 1470),
	Vector3.new(60, 0, 1550),
	Vector3.new(20, 0, 1615),
	Vector3.new(90, 0, 1600),
}
MapConfig.DUCKS = {
	{ position = Vector3.new(50, 0, 1360), turn = 1 },
	{ position = Vector3.new(85, 0, 1500), turn = 4 },
}
-- Toy bricks lying about; the 1st, 3rd and 5th have a second brick on top.
MapConfig.BRICKS = {
	Vector3.new(-30, 0, 1000),
	Vector3.new(50, 0, 1180),
	Vector3.new(40, 0, 1300),
	Vector3.new(0, 0, 1440),
	Vector3.new(60, 0, 960),
}
MapConfig.MONITOR = Vector3.new(-152, 84, 1670) -- the baby monitor on the nightstand
MapConfig.MONITOR_ZONE = { center = Vector3.new(40, 0, 1420), radius = 105, noise = 2 }

-- Where the Kid's flashlight points at time t (seconds) while he sits up: a sweep back down the run.
function MapConfig.flashlightTarget(t: number): Vector3
	local s = math.sin(t * 0.5)
	return Vector3.new(140 * s, 0, 1000 - 300 * math.abs(s))
end

-- The train: a closed loop through these points (x, z), smoothed (centripetal Catmull-Rom). About 1841 studs.
MapConfig.TRAIN_SPEED = 60 -- studs a second: a lap in about 31 s
MapConfig.TRAIN_CARS = 5 -- including the engine
MapConfig.TRAIN_CAR_GAP = 27
MapConfig.TRAIN_SCALE = 1.4
MapConfig.TRACK_WIDTH = 11
MapConfig.TRACK_HEIGHT = 1.6
MapConfig.TRACK_CONTROL = {
	{ 140, 640 },
	{ 175, 760 },
	{ 125, 880 },
	{ 165, 1000 },
	{ 115, 1120 },
	{ 140, 1220 },
	{ 40, 1250 },
	{ -70, 1235 },
	{ -150, 1170 },
	{ -105, 1050 },
	{ -160, 930 },
	{ -100, 810 },
	{ -150, 700 },
	{ -110, 610 },
	{ -20, 585 },
	{ 70, 600 },
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
	return position.Z < cz and d >= MapConfig.SAFE_RADIUS and d <= MapConfig.HOME_CURVE_RADIUS + 12
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
export type TrackPath = { points: { Vector3 }, distances: { number }, length: number }
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
	return t * MapConfig.TRAIN_SPEED + 300 - (car - 1) * MapConfig.TRAIN_CAR_GAP
end

-- Sleeping-toy spawns --------------------------------------------------------------------------------------------------

-- Furniture footprints (x0, z0, x1, z1) and round keep-outs (x, z, r): no spawns or props inside them.
MapConfig.FOOTPRINTS = {
	{ -210, 1275, -10, 1600 }, -- bed
	{ -210, 1610, -134, 1690 }, -- nightstand
	{ 106, 1330, 212, 1510 }, -- desk
	{ 40, 1385, 112, 1455 }, -- chair
	{ -70, 1640, 70, 1700 }, -- in front of the door
}
MapConfig.KEEP_OUTS = { { 45, 800, 40 }, { -188, 760, 26 } } -- tower, fallen block

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
	if math.abs(x) > MapConfig.HALF_WIDTH - r - 6 then
		return true
	end
	if track then
		for _, p in track do
			if math.sqrt((p.X - x) ^ 2 + (p.Z - z) ^ 2) < 8 + r then
				return true
			end
		end
	end
	return false
end

-- Rows down each band, like eggs down a run. Each candidate gets a small fixed jitter and is dropped if blocked.
MapConfig.SPAWN_ROWS = {
	{ size = "S", rows = { 590, 680, 770, 860 }, columns = { -80, -25, 30, 85 }, oddShift = -25 },
	{ size = "M", rows = { 950, 1040, 1130, 1220 }, columns = { -70, -5, 60 }, oddShift = 25 },
	{ size = "L", rows = { 1330, 1430, 1530 }, columns = { 12, 58 }, oddShift = 20 },
}

function MapConfig.toySpawns(): { { position: Vector3, size: string } }
	local out = {}
	local track = MapConfig.trackPoints(8)
	for _, band in MapConfig.SPAWN_ROWS do
		for r, z in band.rows do
			for k, x0 in band.columns do
				local x = x0 + (if r % 2 == 0 then band.oddShift else 0) -- rows 2 and 4 shift (1-based)
				local jx = ((k - 1) * 37 + z) % 13 - 6
				local jz = ((k - 1) * 53 + z) % 15 - 7
				if not MapConfig.blocked(x + jx, z + jz, 10, track) then
					table.insert(out, { position = Vector3.new(x + jx, 0, z + jz), size = band.size })
				end
			end
		end
	end
	return out
end

return MapConfig
