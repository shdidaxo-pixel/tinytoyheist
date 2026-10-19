--!strict
-- Every number for the Kid's Bedroom map, shared by the map builder (tools/build-bedroom.luau) and game code.
-- Layout from the sketch: a flat back wall at z = 0 with the bed in the middle, and a curved front wall that is
-- part of a circle centred on the bed. The 8 mouse holes sit on that curve, so every hole is the same distance
-- from the Giant Kid. Studs; x across the room, z away from the back wall, y up. The room is 1.5x the first draft.

local MapConfig = {}

MapConfig.SCALE = 1.5 -- applied to the first-draft room; players and toys keep their normal size

-- Room shell
MapConfig.HALF_WIDTH = 600 -- back wall runs from x = -600 to 600
MapConfig.CURVE_CENTER_Z = 210 -- the circle's centre, at the bed
MapConfig.CURVE_RADIUS = 930
MapConfig.WALL_HEIGHT = 360
MapConfig.WALL_THICKNESS = 20 -- the curved wall, thick enough for a short tunnel into each burrow
MapConfig.BASEBOARD_HEIGHT = 15

-- Floor rings, measured from the curve centre. Noise multiplies every sound made while standing on it.
export type FloorRing = { name: string, outer: number, noise: number, toySize: string }
MapConfig.RINGS = {
	{ name = "Creaky", outer = 390, noise = 3, toySize = "L" },
	{ name = "Wood", outer = 660, noise = 2, toySize = "M" },
	{ name = "Carpet", outer = 930, noise = 1, toySize = "S" },
} :: { FloorRing }

-- Voxel floor tiles (visual only; the rings above stay for collision and noise). Square, on a grid centred on the bed.
MapConfig.FLOOR_TILE_SIZE = 24
MapConfig.FLOOR_TILE_REACH = 932 -- tile centres stay within R + 2, so tiles reach under the tunnels but not the burrows

-- Mouse holes and burrows
MapConfig.HOLE_COUNT = 8
MapConfig.HOLE_FIRST_ANGLE = 52 -- degrees; 90 is straight out from the bed
MapConfig.HOLE_SPREAD = 76 -- degrees from the first hole to the last
MapConfig.DOOR_WIDTH = 28
MapConfig.DOOR_SIDE_HEIGHT = 12 -- straight sides, then a semicircle on top: 26 tall in all
MapConfig.BURROW_WIDTH = 120 -- room for the Speed training wheel beside the door
MapConfig.BURROW_DEPTH = 100
MapConfig.BURROW_HEIGHT = 40
MapConfig.BURROW_FLOOR_LIFT = 0.2 -- burrow floors sit just above the room floor parts that reach under them
MapConfig.MAX_SLOTS = 20 -- hole Level 7

-- The front of each burrow, in burrow space (x across, z into the burrow; walking in, -x is on your right).
-- half = half the footprint in x and z, so the spec can check nothing overlaps the slots, the walls or the door.
export type BurrowProp = { position: Vector3, half: Vector3 }
MapConfig.BURROW_LAYOUT = {
	LockButton = { position = Vector3.new(-30, 0, 12), half = Vector3.new(4.5, 0, 4.5) },
	CashPile = { position = Vector3.new(28, 0, 14), half = Vector3.new(5, 0, 5) },
	Spawn = { position = Vector3.new(0, 0, 24), half = Vector3.new(5, 0, 5) },
	ToyIndex = { position = Vector3.new(-52, 0, 30), half = Vector3.new(4.5, 0, 3.5) },
	TrainingWheel = { position = Vector3.new(50, 0, 22), half = Vector3.new(6.5, 0, 7.5) },
} :: { [string]: BurrowProp }
MapConfig.WHEEL_RADIUS = 7 -- the Speed hamster wheel: two cardboard spool discs with rungs between
MapConfig.WHEEL_WIDTH = 8 -- between the discs, wide enough to run in

-- Hole levels: slots and look. Costs live with the economy, not here.
MapConfig.HOLE_LEVELS = {
	{ slots = 6, theme = "Cardboard" },
	{ slots = 8, theme = "SockLined" },
	{ slots = 10, theme = "ToyBricks" },
	{ slots = 12, theme = "CosyCabin" },
	{ slots = 15, theme = "CandyLand" },
	{ slots = 18, theme = "ArcadeNeon" },
	{ slots = 20, theme = "GoldenVault" },
}

-- Sleeping-toy spawn points: radius, first angle, angle step, count (radii alternate for a less regular look).
export type SpawnRing = { size: string, radii: { number }, firstAngle: number, step: number, count: number }
MapConfig.SPAWN_RINGS = {
	{ size = "L", radii = { 330, 270 }, firstAngle = 5, step = 170 / 11, count = 12 },
	{ size = "M", radii = { 450, 520, 600 }, firstAngle = 8, step = 164 / 19, count = 20 },
	{ size = "S", radii = { 720, 800, 880 }, firstAngle = 50, step = 80 / 27, count = 28 },
} :: { SpawnRing }

local function toRadians(degrees: number): number
	return degrees * math.pi / 180
end

-- A point on a circle around the bed, at floor height y.
function MapConfig.polar(radius: number, angleDegrees: number, y: number?): Vector3
	local a = toRadians(angleDegrees)
	return Vector3.new(radius * math.cos(a), y or 0, MapConfig.CURVE_CENTER_Z + radius * math.sin(a))
end

-- A frame standing on the circle: LookVector points at the bed (into the room), so local +Z points out
-- through the wall into the burrow.
function MapConfig.curveFrame(radius: number, angleDegrees: number, y: number?): CFrame
	local p = MapConfig.polar(radius, angleDegrees, y)
	return CFrame.lookAt(p, Vector3.new(0, p.Y, MapConfig.CURVE_CENTER_Z))
end

function MapConfig.holeAngle(index: number): number
	assert(index >= 1 and index <= MapConfig.HOLE_COUNT, "hole index out of range")
	return MapConfig.HOLE_FIRST_ANGLE + (index - 1) * MapConfig.HOLE_SPREAD / (MapConfig.HOLE_COUNT - 1)
end

-- The burrow's frame: origin on the floor where the tunnel opens into the burrow, -Z back toward the room.
function MapConfig.burrowFrame(index: number): CFrame
	return MapConfig.curveFrame(MapConfig.CURVE_RADIUS + MapConfig.WALL_THICKNESS, MapConfig.holeAngle(index))
end

-- Where the side walls meet the curve.
function MapConfig.sideWallLength(): number
	local r, w = MapConfig.CURVE_RADIUS, MapConfig.HALF_WIDTH
	return MapConfig.CURVE_CENTER_Z + math.sqrt(r * r - w * w)
end

-- Toy slots in burrow space (x across, z into the burrow): 4 rows of 5. As in the render, the back two rows fill
-- first, from the middle out, so Level 1's 6 slots are 2 rows of 3 at the back; the front rows come after 10.
function MapConfig.slotOffsets(): { Vector3 }
	local out = {}
	for _, rows in { { 76, 92 }, { 40, 58 } } do
		for _, column in { 0, -1, 1, -2, 2 } do
			for _, z in rows do
				table.insert(out, Vector3.new(column * 18, 0, z))
			end
		end
	end
	return out
end

-- Floor ring under a world position inside the room, or nil when outside the curve (walls, burrows).
function MapConfig.ringAt(position: Vector3): FloorRing?
	local dx, dz = position.X, position.Z - MapConfig.CURVE_CENTER_Z
	local distance = math.sqrt(dx * dx + dz * dz)
	for _, ring in MapConfig.RINGS do
		if distance <= ring.outer then
			return ring
		end
	end
	return nil
end

function MapConfig.noiseAt(position: Vector3): number
	local ring = MapConfig.ringAt(position)
	return if ring then ring.noise else 1
end

-- Every floor tile centre (y = 0) and the ring it takes its look from. Tiles wholly behind the back wall or past a
-- side wall are left out; edge tiles may hang a little into the walls.
function MapConfig.floorTiles(): { { position: Vector3, ring: string } }
	local out = {}
	local size, reach = MapConfig.FLOOR_TILE_SIZE, MapConfig.FLOOR_TILE_REACH
	local steps = math.ceil(reach / size)
	for i = -steps, steps do
		for j = -steps, steps do
			local p = Vector3.new(i * size, 0, MapConfig.CURVE_CENTER_Z + j * size)
			local inRoom = p.Z + size / 2 > 0 and math.abs(p.X) - size / 2 < MapConfig.HALF_WIDTH
			if inRoom and math.sqrt(p.X * p.X + (j * size) ^ 2) <= reach then
				local ring = MapConfig.ringAt(p)
				table.insert(out, { position = p, ring = if ring then ring.name else "Carpet" })
			end
		end
	end
	return out
end

-- Every sleeping-toy spawn point as { position, size }.
function MapConfig.toySpawns(): { { position: Vector3, size: string } }
	local out = {}
	for _, ring in MapConfig.SPAWN_RINGS do
		for k = 0, ring.count - 1 do
			local radius = ring.radii[(k % #ring.radii) + 1]
			table.insert(out, { position = MapConfig.polar(radius, ring.firstAngle + k * ring.step), size = ring.size })
		end
	end
	return out
end

return MapConfig
