--!strict
-- Where an awake toy is in its home's pen at time t. Toys roam the whole pen like the pets in Dylan's recording
-- (Break and Steal an Egg, 19 Oct: "they kinda just play animation and not move really"): they stand a moment, turn
-- on the spot to face somewhere, stroll right across the pen on a gentle curve (easing in and out), stop, and go
-- again. Small toys trot, big ones amble.
--
-- Worked out from a seed and the server clock alone (no history), so every client sees the same toy in the same
-- place and the server can tell where a toy is when someone grabs it (Raids). Time is cut into chunks of EPOCH
-- seconds; each toy starts every chunk at an anchor point from its seed and plans its walks inside the chunk so the
-- last one ends on the next chunk's anchor, exactly on time. A chunk's plan is cached, so a frame is a lookup.
-- Toys never stop on (or walk through) the door props when the pen reaches them. Keeping clear of each other is done
-- on the clients (HomeView nudges toys apart by a few studs; the server's steal check allows far more than that).

local Shared = script.Parent
local MapConfig = require(Shared:WaitForChild("MapConfig")) :: any

local PenRoam = {}

-- Cruise speed in studs a second by toy size (each walk varies it), and how far one hop step goes
PenRoam.SPEED = { S = 7.5, M = 6, L = 4.8, G = 4 } :: { [string]: number }
PenRoam.STEP = { S = 2.6, M = 3.2, L = 4, G = 5 } :: { [string]: number }
PenRoam.HOP = { S = 0.8, M = 0.55, L = 0.45, G = 0.4 } :: { [string]: number }
PenRoam.EPOCH = 45 -- seconds per planned chunk
PenRoam.EASE = 0.35 -- seconds to speed up at the start of a walk (and to slow down at the end)
PenRoam.TURN = 0.6 -- seconds to turn on the spot before a walk
PenRoam.NORMAL_REACH = 6 -- the pen's roaming bounds already keep this far from its walls

type Leg = {
	start: number, -- when the walk starts (seconds into the chunk; the pause before it ends here)
	pause: number,
	ax: number,
	az: number,
	bx: number,
	bz: number,
	dist: number,
	dur: number,
	speed: number, -- cruise speed
	bend: number, -- sideways bulge at the middle of the walk, in studs
}
type Box = { x0: number, x1: number, z0: number, z1: number }
type Plan = { legs: { Leg }, endX: number, endZ: number }

-- Door props in home space (radius = how much room they take). They sit in front of the pen today; if a pen ever
-- grows over them, toys keep out. The wheel uses its largest size so plans don't change with the wheel level.
local OBSTACLES: { { x: number, z: number, r: number } } = {}
do
	local layout = MapConfig.BURROW_LAYOUT or {}
	for _, name in { "LockButton", "ToyIndex", "TrainingWheel" } do
		local p = layout[name]
		if p then
			local r = math.max(p.half.X, p.half.Z) * 1.42
			if name == "TrainingWheel" and MapConfig.wheelSize then
				local R, W = MapConfig.wheelSize(7)
				r = math.max(r, R, W / 2)
			end
			table.insert(OBSTACLES, { x = p.position.X, z = p.position.Z, r = r })
		end
	end
end

local function blocked(reach: number, x: number, z: number): boolean
	for _, o in OBSTACLES do
		local r = o.r + reach
		if (x - o.x) ^ 2 + (z - o.z) ^ 2 < r * r then
			return true
		end
	end
	return false
end

local function crosses(reach: number, ax: number, az: number, bx: number, bz: number): boolean
	for _, o in OBSTACLES do
		local dx, dz = bx - ax, bz - az
		local len2 = dx * dx + dz * dz
		local u = if len2 > 0 then math.clamp(((o.x - ax) * dx + (o.z - az) * dz) / len2, 0, 1) else 0
		local px, pz = ax + dx * u - o.x, az + dz * u - o.z
		local r = o.r + reach
		if px * px + pz * pz < r * r then
			return true
		end
	end
	return false
end

-- A random spot in the box that isn't on a prop
local function pick(rng: Random, box: Box, reach: number): (number, number)
	local x, z = 0, 0
	for _ = 1, 8 do
		x = box.x0 + (box.x1 - box.x0) * rng:NextNumber()
		z = box.z0 + (box.z1 - box.z0) * rng:NextNumber()
		if not blocked(reach, x, z) then
			break
		end
	end
	return x, z
end

local function anchor(seed: number, epoch: number, box: Box, reach: number): (number, number)
	return pick(Random.new(seed + epoch * 999983 + 17), box, reach)
end

local function walkTime(dist: number, speed: number): number
	return dist / speed + PenRoam.EASE
end

-- The walks a toy makes in one chunk: from this chunk's anchor to the next one's, all inside EPOCH seconds
local function plan(seed: number, epoch: number, box: Box, speed: number, reach: number): Plan
	local E = PenRoam.EPOCH
	local rng = Random.new(seed * 7 + epoch * 1000003 + 5)
	local x, z = anchor(seed, epoch, box, reach)
	local ex, ez = anchor(seed, epoch + 1, box, reach)
	local w, d = box.x1 - box.x0, box.z1 - box.z0
	local longest = math.sqrt(w * w + d * d)
	local legs: { Leg } = {}
	local t = 0
	local function leg(pause: number, bx: number, bz: number, cruise: number, dur: number?)
		local dist = math.sqrt((bx - x) ^ 2 + (bz - z) ^ 2)
		local time = dur or walkTime(dist, cruise)
		if dur then
			cruise = dist / math.max(dur - PenRoam.EASE, 0.05)
		end
		local bend = (rng:NextNumber() * 2 - 1) * math.min(dist * 0.18, 6)
		table.insert(legs, {
			start = t + pause,
			pause = pause,
			ax = x,
			az = z,
			bx = bx,
			bz = bz,
			dist = dist,
			dur = time,
			speed = cruise,
			bend = bend,
		})
		t += pause + time
		x, z = bx, bz
	end
	while true do
		-- stand a moment: mostly a second or two, sometimes a proper rest, sometimes straight off again
		local roll = rng:NextNumber()
		local pause = if roll < 0.15
			then 0.5 + rng:NextNumber() * 0.4
			elseif roll < 0.8 then 1 + rng:NextNumber() * 2.2
			else 3.5 + rng:NextNumber() * 3.5
		-- somewhere well across the pen (a few tries for a long, clear walk)
		local bx, bz = x, z
		local best = -1
		for _ = 1, 5 do
			local cx, cz = pick(rng, box, reach)
			local len = math.sqrt((cx - x) ^ 2 + (cz - z) ^ 2)
			if not crosses(reach, x, z, cx, cz) and len > best then
				bx, bz, best = cx, cz, len
				if len > longest * 0.35 then
					break
				end
			end
		end
		-- most walks at cruise, now and then a trot
		local cruise = speed * (0.8 + rng:NextNumber() * 0.4) * (if rng:NextNumber() < 0.12 then 1.45 else 1)
		local time = walkTime(math.max(best, 0), cruise)
		local home = walkTime(math.sqrt((ex - bx) ^ 2 + (ez - bz) ^ 2), speed) + 0.5
		if best < 0 or t + pause + time + home > E then
			break
		end
		leg(pause, bx, bz, cruise)
	end
	-- the last walk ends on the next chunk's anchor right as the chunk ends (rest first if there's time)
	local need = walkTime(math.sqrt((ex - x) ^ 2 + (ez - z) ^ 2), speed)
	local left = E - t
	local dur = math.min(need, math.max(left - 0.5, 0.05))
	leg(math.max(left - dur, 0), ex, ez, speed, dur)
	return { legs = legs, endX = ex, endZ = ez }
end

-- one cached plan per toy per chunk (and the chunk before, for the way it faced coming in)
type Entry = { epoch: number, key: number, plan: Plan, before: Plan? }
local cache: { [number]: Entry } = {}
local cached = 0

local function sizeKey(box: Box, speed: number, reach: number): number
	return box.x0 * 3.1 + box.x1 * 5.7 + box.z0 * 7.3 + box.z1 * 11.9 + speed * 13.1 + reach * 17.3
end

local function planFor(seed: number, epoch: number, box: Box, speed: number, reach: number): Entry
	local key = sizeKey(box, speed, reach)
	local e = cache[seed]
	if e and e.epoch == epoch and e.key == key then
		return e
	end
	local before = if e and e.epoch == epoch - 1 and e.key == key then e.plan else nil
	if cached > 4000 then
		table.clear(cache)
		cached = 0
	end
	if not cache[seed] then
		cached += 1
	end
	local entry = { epoch = epoch, key = key, plan = plan(seed, epoch, box, speed, reach), before = before }
	cache[seed] = entry
	return entry
end

local function smooth(u: number): number
	return u * u * (3 - 2 * u)
end

-- distance along a walk after tau seconds: speeds up over EASE, cruises, slows down over EASE
local function along(leg: Leg, tau: number): number
	local a = math.min(PenRoam.EASE, leg.dur / 2)
	local v = leg.dist / math.max(leg.dur - a, 0.05)
	if tau <= 0 then
		return 0
	elseif tau >= leg.dur then
		return leg.dist
	elseif tau < a then
		return v * tau * tau / (2 * a)
	elseif tau > leg.dur - a then
		local r = leg.dur - tau
		return leg.dist - v * r * r / (2 * a)
	end
	return v * a / 2 + v * (tau - a)
end

-- point and heading on a walk at distance s (a straight line with a sine bulge to one side)
local function onLeg(leg: Leg, s: number): (number, number, number, number)
	local dx, dz = leg.bx - leg.ax, leg.bz - leg.az
	local L = math.max(leg.dist, 1e-3)
	local ux, uz = dx / L, dz / L
	local f = math.clamp(s / L, 0, 1)
	local side = leg.bend * math.sin(f * math.pi)
	local x = leg.ax + dx * f - uz * side
	local z = leg.az + dz * f + ux * side
	local slope = leg.bend * math.pi / L * math.cos(f * math.pi)
	return x, z, ux - uz * slope, uz + ux * slope
end

local function heading(leg: Leg, s: number): Vector3
	local _, _, hx, hz = onLeg(leg, s)
	local v = Vector3.new(hx, 0, hz)
	return if v.Magnitude > 1e-4 then v.Unit else Vector3.new(0, 0, 1)
end

local function lastHeading(p: Plan?): Vector3?
	if not p or #p.legs == 0 then
		return nil
	end
	local leg = p.legs[#p.legs]
	if leg.dist < 0.05 then
		return nil
	end
	return heading(leg, leg.dist)
end

-- The roaming box in home space: the pen's bounds, pulled in for a big toy (its Reach past a normal toy's)
function PenRoam.box(penMin: Vector3, penMax: Vector3, reach: number?): Box
	local cx, cz = (penMin.X + penMax.X) / 2, (penMin.Z + penMax.Z) / 2
	local inset = math.max(0, (reach or 0) - PenRoam.NORMAL_REACH)
	local hx = math.max((penMax.X - penMin.X) / 2 - inset, 0)
	local hz = math.max((penMax.Z - penMin.Z) / 2 - inset, 0)
	return { x0 = cx - hx, x1 = cx + hx, z0 = cz - hz, z1 = cz + hz }
end

-- Cruise speed for a toy: by its size, and a Huge or Giant one (bigger Reach) lumbers a bit
function PenRoam.speedOf(size: string?, reach: number?): number
	local base = PenRoam.SPEED[size or "M"] or PenRoam.SPEED.M
	local r = reach or 0
	if r > PenRoam.NORMAL_REACH then
		base *= math.clamp(math.sqrt(PenRoam.NORMAL_REACH / r), 0.65, 1)
	end
	return base
end

-- The toy's position in home space (y = 0 on the pen floor plus its hop), the way it faces, and how fast it's going
-- (studs a second; 0 standing). `reach` is half the toy's footprint (its Reach attribute).
function PenRoam.pose(
	seed: number,
	t: number,
	penMin: Vector3,
	penMax: Vector3,
	size: string?,
	reach: number?
): (Vector3, Vector3, number)
	seed = math.floor(seed)
	local box = PenRoam.box(penMin, penMax, reach)
	local speed = PenRoam.speedOf(size, reach)
	local r = math.max(reach or 0, 3)
	local E = PenRoam.EPOCH
	local time = t + (seed % 997) * 0.613 -- every toy's chunks start at a different moment
	local epoch = math.floor(time / E)
	local u = time - epoch * E
	local entry = planFor(seed, epoch, box, speed, r)
	local legs = entry.plan.legs
	-- find the walk we're in (or the pause before it)
	local i = 1
	while i < #legs and u >= legs[i].start + legs[i].dur do
		i += 1
	end
	local leg = legs[i]
	local tau = u - leg.start
	local x, z, dir, moving = leg.ax, leg.az, nil :: Vector3?, 0
	if tau < 0 then
		-- standing before this walk: face the way we came, and turn on the spot to face the new way at the end
		local prev: Vector3?
		if i > 1 then
			local p = legs[i - 1]
			prev = heading(p, p.dist)
		else
			if not entry.before then
				local before = plan(seed, epoch - 1, box, speed, r)
				entry.before = before
			end
			prev = lastHeading(entry.before)
		end
		local nxt = if leg.dist > 0.05 then heading(leg, 0) else (prev or Vector3.new(0, 0, 1))
		prev = prev or nxt
		local turn = math.min(PenRoam.TURN, leg.pause)
		local k = smooth(math.clamp((tau + turn) / math.max(turn, 1e-3), 0, 1))
		local a0 = math.atan2((prev :: Vector3).X, (prev :: Vector3).Z)
		local a1 = math.atan2(nxt.X, nxt.Z)
		local da = (a1 - a0 + math.pi) % (2 * math.pi) - math.pi
		local a = a0 + da * k
		dir = Vector3.new(math.sin(a), 0, math.cos(a))
	else
		local s = along(leg, tau)
		local hx, hz
		x, z, hx, hz = onLeg(leg, s)
		local v = Vector3.new(hx, 0, hz)
		dir = if v.Magnitude > 1e-4 then v.Unit else Vector3.new(0, 0, 1)
		moving = (along(leg, tau + 0.05) - s) / 0.05
	end
	local hop = 0
	if moving > 0.05 then
		local s = along(leg, tau)
		local step = PenRoam.STEP[size or "M"] or 3.2
		if r > PenRoam.NORMAL_REACH then
			step *= r / PenRoam.NORMAL_REACH
		end
		hop = math.abs(math.sin(s / step * math.pi)) * (PenRoam.HOP[size or "M"] or 0.55)
	end
	x = math.clamp(x, box.x0, box.x1)
	z = math.clamp(z, box.z0, box.z1)
	return Vector3.new(x, hop, z), dir :: Vector3, moving
end

return PenRoam
