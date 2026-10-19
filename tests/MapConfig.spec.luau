--!strict
-- Checks the bedroom numbers hang together. Returns the number of checks run.
return function(shared: Folder)
	local MapConfig = require(shared:WaitForChild("MapConfig")) :: any
	local checks = 0
	local function check(ok: boolean, message: string)
		assert(ok, message)
		checks += 1
	end

	-- Every hole is the same distance from the bed, and holes are evenly spaced along the curve.
	local first, last = MapConfig.holeAngle(1), MapConfig.holeAngle(MapConfig.HOLE_COUNT)
	check(first == MapConfig.HOLE_FIRST_ANGLE, "first hole angle")
	check(math.abs(last - first - MapConfig.HOLE_SPREAD) < 1e-9, "hole spread")
	for i = 1, MapConfig.HOLE_COUNT do
		local p = MapConfig.burrowFrame(i).Position
		local d = Vector3.new(p.X, 0, p.Z - MapConfig.CURVE_CENTER_Z).Magnitude
		-- Vector3 is 32-bit, so allow a little rounding (one float step at 950 studs is 0.00006)
		check(math.abs(d - (MapConfig.CURVE_RADIUS + MapConfig.WALL_THICKNESS)) < 1e-3, "burrow " .. i .. " distance")
	end

	-- Neighbouring burrows don't overlap at their front corners (the narrowest point).
	local gap = 2 * (MapConfig.CURVE_RADIUS + MapConfig.WALL_THICKNESS) * math.sin(math.rad(MapConfig.HOLE_SPREAD / 14))
	check(gap > MapConfig.BURROW_WIDTH + 4, "burrows overlap: centres only " .. gap .. " apart")

	-- The curve meets both side walls inside the room's width.
	check(
		math.cos(math.rad(first)) * MapConfig.CURVE_RADIUS < MapConfig.HALF_WIDTH + 10,
		"first hole past the side wall"
	)

	-- Rings: creaky boards by the bed, carpet by the holes.
	check(MapConfig.ringAt(MapConfig.polar(100, 90)).name == "Creaky", "inner ring")
	check(MapConfig.ringAt(MapConfig.polar(500, 90)).name == "Wood", "middle ring")
	check(MapConfig.ringAt(MapConfig.polar(800, 90)).name == "Carpet", "outer ring")
	check(MapConfig.ringAt(MapConfig.polar(1000, 90)) == nil, "outside the curve")
	check(MapConfig.noiseAt(MapConfig.polar(100, 90)) == 3, "creaky noise")

	-- Toy spawns: 60 points, each on its own ring, inside the room and clear of the bed.
	local spawns = MapConfig.toySpawns()
	check(#spawns == 60, "toy spawn count")
	local bedHalfWidth, bedEnd = 85 * MapConfig.SCALE, 265 * MapConfig.SCALE
	for k, s in spawns do
		local ring = MapConfig.ringAt(s.position)
		check(ring ~= nil and ring.toySize == s.size, "spawn " .. k .. " is on the wrong ring")
		check(
			math.abs(s.position.X) < MapConfig.HALF_WIDTH - 20 and s.position.Z > 20,
			"spawn " .. k .. " outside room"
		)
		check(not (math.abs(s.position.X) < bedHalfWidth and s.position.Z < bedEnd), "spawn " .. k .. " under the bed")
	end

	-- 20 slots, all inside the burrow and clear of the door area.
	local slots = MapConfig.slotOffsets()
	check(#slots == MapConfig.MAX_SLOTS, "slot count")
	for k, o in slots do
		check(
			math.abs(o.X) + 6 <= MapConfig.BURROW_WIDTH / 2 and o.Z - 6 >= 30 and o.Z + 6 <= MapConfig.BURROW_DEPTH,
			"slot " .. k
		)
	end

	-- Burrow props: inside the walls, behind the front wall, clear of the slots, the doorway and each other.
	local props = {}
	for name, prop in MapConfig.BURROW_LAYOUT do
		table.insert(props, { name = name, min = prop.position - prop.half, max = prop.position + prop.half })
	end
	local function overlaps(a, b)
		return a.min.X < b.max.X and b.min.X < a.max.X and a.min.Z < b.max.Z and b.min.Z < a.max.Z
	end
	for i, p in props do
		check(
			p.min.X >= -MapConfig.BURROW_WIDTH / 2 and p.max.X <= MapConfig.BURROW_WIDTH / 2,
			p.name .. " in a side wall"
		)
		check(p.min.Z >= 2 and p.max.Z <= MapConfig.BURROW_DEPTH, p.name .. " in the front or back wall")
		if p.name ~= "Spawn" then
			check(math.max(-p.max.X, p.min.X) >= MapConfig.DOOR_WIDTH / 2, p.name .. " blocks the doorway")
		end
		for k, o in slots do
			local slot = { min = o - Vector3.new(6, 0, 6), max = o + Vector3.new(6, 0, 6) }
			check(not overlaps(p, slot), p.name .. " overlaps slot " .. k)
		end
		for j = i + 1, #props do
			check(not overlaps(p, props[j]), p.name .. " overlaps " .. props[j].name)
		end
	end

	-- Floor tiles cover the room: every tile is inside the reach and touches the room, and the right ring look.
	local tiles = MapConfig.floorTiles()
	local half = MapConfig.FLOOR_TILE_SIZE / 2
	check(#tiles > 2000, "too few floor tiles: " .. #tiles)
	for k, t in tiles do
		local p = t.position
		local d = Vector3.new(p.X, 0, p.Z - MapConfig.CURVE_CENTER_Z).Magnitude
		check(d <= MapConfig.FLOOR_TILE_REACH + 1e-3, "tile " .. k .. " past the reach")
		check(p.Z + half > 0 and math.abs(p.X) - half < MapConfig.HALF_WIDTH, "tile " .. k .. " outside the room")
		local ring = MapConfig.ringAt(p)
		check(t.ring == (if ring then ring.name else "Carpet"), "tile " .. k .. " ring")
	end
	return checks
end
