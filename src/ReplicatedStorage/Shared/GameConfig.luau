--!strict
-- The game's numbers: home level costs, stats, wake-up timers, raids, rebirths and rewards. From the Day 1 plan
-- unless a note says otherwise. Server and client both read it (the client only to show prices and progress).

local GameConfig = {}

-- Money ----------------------------------------------------------------------------------------------------------------
-- Toys pay straight into your wallet every second (Dylan, 19 Oct: auto collect, no walking to the cash pile).
GameConfig.START_CASH = 0
GameConfig.SELL_SECONDS = 20 -- a toy sells for 20 seconds of what it earns

-- Home levels: cost to reach each level (MapConfig.HOLE_LEVELS has the slots and look).
GameConfig.HOME_COST = { [2] = 500, [3] = 5_000, [4] = 50_000, [5] = 500_000, [6] = 5_000_000, [7] = 50_000_000 }
GameConfig.HOME_REBIRTH = {} :: { [number]: number } -- rebirths are hidden for now (Dylan: "might be too soon")

-- Inventory: the pen shows the equipped toys (home slots); the rest wait in the inventory
GameConfig.INVENTORY_MAX = 100 -- toys and blankets you can own at once
GameConfig.MAX_BLANKETS = 6 -- blankets waiting in your home to be hatched
GameConfig.SHOW_REBIRTH = false

-- Wake-up timer after banking, in seconds, by blanket size and the toy's rarity: bigger blankets and better toys take
-- longer (Dylan, 19 Oct: "make it longer for better/bigger blankets"). Your very first toy takes FIRST_WAKE.
GameConfig.WAKE_SECONDS = {
	S = { Common = 10, Uncommon = 15, Rare = 30, Epic = 45, Legendary = 60, Mythic = 60, Secret = 60 },
	M = { Common = 60, Uncommon = 75, Rare = 120, Epic = 180, Legendary = 240, Mythic = 300, Secret = 300 },
	L = { Common = 180, Uncommon = 240, Rare = 300, Epic = 420, Legendary = 540, Mythic = 600, Secret = 600 },
	G = { Common = 600, Uncommon = 600, Rare = 600, Epic = 600, Legendary = 600, Mythic = 600, Secret = 600 },
} :: { [string]: { [string]: number } }
GameConfig.FIRST_WAKE = 5
GameConfig.FIRST_TOY = "PlushBunny" -- your very first toy is always an Uncommon Plush Bunny (the plan's first minute)

-- Toy size: rolled when a toy hatches, on top of its mutation (a toy can be Huge and Gold). Bigger toys earn and sell
-- for more (Dylan, 19 Oct: "variable sizes as a mutation and get bigger and give more money"). chance is per hatch;
-- scale multiplies the model; money multiplies its income and sell price; carry multiplies a thief's walk speed.
GameConfig.SIZE = {
	Order = { "Normal", "Big", "Huge", "Giant" },
	Normal = { chance = 0.85, scale = 1, money = 1, carry = 1, color = "#FFFFFF" },
	Big = { chance = 0.11, scale = 1.5, money = 2, carry = 1, color = "#7FE3FF" },
	Huge = { chance = 0.035, scale = 2, money = 4, carry = 0.9, color = "#FFB547" },
	Giant = { chance = 0.005, scale = 3, money = 10, carry = 0.8, color = "#FF5FA8" },
}

-- Speed --------------------------------------------------------------------------------------------------------------
-- The one stat (Dylan, 19 Oct: "you really just need speed"; Strength, Sneak and Grip are gone). Speed is a big
-- number trained on your home's Speed wheel ("the bigger the number the better people will want to get it higher"):
-- 1,000 Speed = 1 walk speed, so you start at 16,000 and today's old max (walk 80) is 80,000. Past that the number
-- keeps flying (no cap) while your real walk speed keeps rising slower and slower (Dylan, 19 Oct: "no speed cap rn,
-- just make it look bigger than it is"). The wheel has its own levels, bought separately from the home; a better
-- wheel just trains faster (no top per wheel).
GameConfig.SPEED_START = 16_000 -- Speed you start with (walk 16)
GameConfig.SPEED_PER_WALK = 1_000 -- Speed per 1 walk speed, up to SPEED_SOFT
GameConfig.SPEED_SOFT = 80_000 -- walk 80; past it walk = 80 + SPEED_LOG * ln(Speed / SPEED_SOFT)
GameConfig.SPEED_LOG = 9.4 -- 1M Speed walks 104, 100M 147, 10B 190
GameConfig.SPEED_SAFETY = 400 -- a physics safety limit on real walk speed, never reached in normal play
function GameConfig.walkSpeed(speed: number): number -- real Humanoid walk speed for a Speed number
	if speed <= GameConfig.SPEED_SOFT then
		return speed / GameConfig.SPEED_PER_WALK
	end
	local walk = GameConfig.SPEED_SOFT / GameConfig.SPEED_PER_WALK
		+ GameConfig.SPEED_LOG * math.log(speed / GameConfig.SPEED_SOFT)
	return math.min(walk, GameConfig.SPEED_SAFETY)
end

-- The Speed wheel's levels: the name of its look, its price and the Speed it trains each second you run in it
-- (about 1.6x the level before; each costs about 2.6x). Looks: tools/bedroom/Homes.luau WHEEL_LOOK.
GameConfig.WHEELS = {
	{ name = "Cardboard Spool", cost = 0, gain = 100 },
	{ name = "Sock Stripes", cost = 200, gain = 160 },
	{ name = "Toy Bricks", cost = 550, gain = 260 },
	{ name = "Ship's Wheel", cost = 1_500, gain = 410 },
	{ name = "Candy Cane", cost = 4_000, gain = 660 },
	{ name = "Arcade Neon", cost = 10_000, gain = 1_000 },
	{ name = "Golden Vault", cost = 25_000, gain = 1_700 },
	{ name = "Dino Bones", cost = 70_000, gain = 2_700 },
	{ name = "Bubble Pop", cost = 180_000, gain = 4_300 },
	{ name = "Frosty Ice", cost = 500_000, gain = 6_900 },
	{ name = "Robot Gears", cost = 1_200_000, gain = 11_000 },
	{ name = "Rocket", cost = 3_300_000, gain = 18_000 },
	{ name = "Lava", cost = 9_000_000, gain = 28_000 },
	{ name = "Rainbow", cost = 23_000_000, gain = 45_000 },
	{ name = "Thunderstorm", cost = 60_000_000, gain = 72_000 },
	{ name = "Haunted", cost = 160_000_000, gain = 120_000 },
	{ name = "Diamond", cost = 420_000_000, gain = 180_000 },
	{ name = "Dragon", cost = 1_100_000_000, gain = 300_000 },
	{ name = "Ringed Planet", cost = 3_000_000_000, gain = 470_000 },
	{ name = "Galaxy", cost = 8_000_000_000, gain = 760_000 },
	{ name = "Black Hole", cost = 20_000_000_000, gain = 1_200_000 },
	{ name = "Supernova", cost = 55_000_000_000, gain = 1_900_000 },
	{ name = "Angel Wings", cost = 140_000_000_000, gain = 3_100_000 },
	{ name = "Royal Crown", cost = 380_000_000_000, gain = 5_000_000 },
	{ name = "Infinity", cost = 1_000_000_000_000, gain = 7_900_000 },
} :: { { name: string, cost: number, gain: number } }
GameConfig.WHEEL_COST = {} :: { [number]: number } -- cost to reach each level (level 1 is free)
for level, wheel in GameConfig.WHEELS do
	if level > 1 then
		GameConfig.WHEEL_COST[level] = wheel.cost
	end
end
function GameConfig.wheelGain(level: number): number -- Speed a second on a wheel of this level
	local wheel = GameConfig.WHEELS[math.clamp(level, 1, #GameConfig.WHEELS)]
	return wheel.gain
end
function GameConfig.wheelName(level: number): string
	return GameConfig.WHEELS[math.clamp(level, 1, #GameConfig.WHEELS)].name
end
-- Speed as shown: in full with commas below a million (16,000; 845,300), then short (1.25M, 3.4B)
function GameConfig.speedText(speed: number): string
	speed = math.floor(speed)
	if speed >= 1_000_000 then
		return GameConfig.short(speed)
	end
	local text = tostring(speed)
	while true do
		local done
		text, done = string.gsub(text, "^(%d+)(%d%d%d)", "%1,%2")
		if done == 0 then
			return text
		end
	end
end
-- A saved game from before 19 Oct had SpeedPoints (walk = 16 + points): the same walk speed in Speed
function GameConfig.speedFromPoints(points: number): number
	return GameConfig.SPEED_START + points * GameConfig.SPEED_PER_WALK
end

-- Carrying (these were in Carry.luau)
GameConfig.CARRY_SPEED = { S = 0.95, M = 0.8, L = 0.6 } :: { [string]: number }
GameConfig.CARRY_NOISE = { S = 0.5, M = 1, L = 2 } :: { [string]: number }
GameConfig.SLOW_MODE = 0.5 -- Slow Mode: walk speed and drag noise x0.5

-- Rebirth ("Growth Spurt"): resets cash, stats and home level; keeps toys and the Index.
GameConfig.REBIRTH = {
	{ cash = 50_000_000 },
	{ cash = 500_000_000 },
	{ cash = 5_000_000_000 },
}
function GameConfig.rebirthCost(n: number): number -- cash needed for rebirth n (1-based)
	local r = GameConfig.REBIRTH[n]
	if r then
		return r.cash
	end
	return 5_000_000_000 * 10 ^ (n - 3)
end
function GameConfig.rebirthMultiplier(rebirths: number): number -- money multiplier after this many rebirths
	if rebirths <= 0 then
		return 1
	elseif rebirths == 1 then
		return 1.5
	elseif rebirths == 2 then
		return 2
	end
	return 3 + (rebirths - 3)
end
GameConfig.MAX_REBIRTHS = 10

-- Raids ----------------------------------------------------------------------------------------------------------------
GameConfig.RAID = {
	hold = 2, -- seconds to hold Steal on a toy in someone's pen
	minToys = 3, -- players with fewer toys than this can't be raided
	shieldMinutes = 10, -- new players can't be raided for their first 10 minutes played...
	shieldToys = 5, -- ...unless they already own this many toys
	cooldown = 90, -- seconds before you can steal from the same player again
	returnAfter = 15, -- a dropped stolen toy slides back home after this long untouched
}

-- Index ----------------------------------------------------------------------------------------------------------------
-- Finding every toy in a room's set pays a one-time reward and +2% luck on mutations.
GameConfig.SET_REWARD = {
	Bedroom = 25_000,
	Hallway = 250_000,
	Kitchen = 2_500_000,
	LivingRoom = 25_000_000,
	Garage = 250_000_000,
	Attic = 2_500_000_000,
}
GameConfig.SET_LUCK = 0.02

-- Rewards --------------------------------------------------------------------------------------------------------------
-- Daily streak: one claim a day (UTC); miss a day and it starts again. Kinds: Cash, Boost (x2 money for `minutes`),
-- Toy (a sleeping toy of `size` delivered to your pen, which wakes up as usual).
GameConfig.DAILY = {
	{ kind = "Cash", amount = 2_500 },
	{ kind = "Boost", minutes = 10 },
	{ kind = "Cash", amount = 6_000 },
	{ kind = "Toy", size = "M" },
	{ kind = "Cash", amount = 10_000 },
	{ kind = "Boost", minutes = 30 },
	{ kind = "Toy", size = "L", cash = 15_000 }, -- Day 7 jackpot
}
-- Playtime gifts: unlock after this many minutes played in a session
GameConfig.PLAYTIME = {
	{ minutes = 1, kind = "Cash", amount = 1_000 },
	{ minutes = 5, kind = "Boost", minutes2 = 5 },
	{ minutes = 8, kind = "Cash", amount = 2_000 },
	{ minutes = 12, kind = "Toy", size = "S" },
	{ minutes = 15, kind = "Cash", amount = 3_000 },
	{ minutes = 20, kind = "Cash", amount = 4_000 },
	{ minutes = 25, kind = "Boost", minutes2 = 10 },
	{ minutes = 30, kind = "Toy", size = "M" },
	{ minutes = 40, kind = "Cash", amount = 8_000 },
	{ minutes = 50, kind = "Toy", size = "L" },
}
GameConfig.BOOST_MULTIPLIER = 2

-- Formatting -----------------------------------------------------------------------------------------------------------
local SUFFIX = { "", "K", "M", "B", "T", "Qa", "Qi" }
-- 950 -> "950", 1500 -> "1.5K", 2_340_000 -> "2.34M"
function GameConfig.short(n: number): string
	n = math.floor(n + 0.5)
	if math.abs(n) < 1000 then
		return tostring(n)
	end
	local k = 1
	local v = n
	while math.abs(v) >= 1000 and k < #SUFFIX do
		v /= 1000
		k += 1
	end
	local text = if math.abs(v) >= 100 then string.format("%d", math.floor(v)) else string.format("%.3g", v)
	return text .. SUFFIX[k]
end
function GameConfig.money(n: number): string
	return "$" .. GameConfig.short(n)
end

return GameConfig
