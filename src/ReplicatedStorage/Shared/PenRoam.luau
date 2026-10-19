--!strict
-- Where an awake toy is in its home's pen at time t: it walks to a spot, pauses, walks to the next. Worked out from a
-- seed and the server clock alone (no history), so every client sees the same toy in the same place and the server
-- can tell where a toy is when someone grabs it. Spots come from smooth noise, so each walk is a short stroll.

local PenRoam = {}

-- Seconds per walk-and-pause, by toy size (big toys amble)
PenRoam.LEG = { S = 5, M = 6, L = 7.5, G = 9 } :: { [string]: number }
PenRoam.WALK = 0.6 -- the part of each leg spent walking

local function spot(seed: number, leg: number): (number, number)
	-- two smooth noise tracks, stretched so the toy uses the whole pen
	local x = math.noise(seed * 0.1731 + 3.1, leg * 0.37, 0.5) * 2.4
	local z = math.noise(seed * 0.2917 + 7.7, leg * 0.37, 2.5) * 2.4
	return math.clamp(x, -1, 1), math.clamp(z, -1, 1)
end

local function smooth(u: number): number
	return u * u * (3 - 2 * u)
end

-- The toy's position in home space (y = 0 on the pen floor plus its hop) and the way it faces.
function PenRoam.pose(seed: number, t: number, penMin: Vector3, penMax: Vector3, size: string?): (Vector3, Vector3)
	local period = PenRoam.LEG[size or "M"] or 6
	local time = t + (seed % 97) * 0.731
	local leg = math.floor(time / period)
	local u = (time % period) / period
	local ax, az = spot(seed, leg)
	local bx, bz = spot(seed, leg + 1)
	local walking = u < PenRoam.WALK
	local k = if walking then smooth(u / PenRoam.WALK) else 1
	local centre = (penMin + penMax) / 2
	local half = (penMax - penMin) / 2
	local x = centre.X + half.X * (ax + (bx - ax) * k)
	local z = centre.Z + half.Z * (az + (bz - az) * k)
	local dir = Vector3.new(bx - ax, 0, bz - az) * Vector3.new(half.X, 0, half.Z)
	if dir.Magnitude < 1e-3 then
		dir = Vector3.new(0, 0, 1)
	end
	local hop = 0
	if walking then
		local hops = if size == "L" or size == "G" then 4 else 6
		hop = math.abs(math.sin(u / PenRoam.WALK * math.pi * hops)) * (if size == "S" then 0.9 else 0.6)
	end
	return Vector3.new(x, hop, z), dir.Unit
end

return PenRoam
