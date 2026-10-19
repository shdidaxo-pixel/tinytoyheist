--!strict
-- The game's numbers: home level costs, stats, wake-up timers, raids, rebirths and rewards. From the Day 1 plan
-- unless a note says otherwise. Server and client both read it (the client only to show prices and progress).

local GameConfig = {}

-- Money ----------------------------------------------------------------------------------------------------------------
-- Toys pay straight into your wallet every second (Dylan, 19 Oct: auto collect, no walking to the cash pile).
GameConfig.START_CASH = 0
GameConfig.SELL_SECONDS = 20 -- a toy sells for 20 seconds of what it earns

-- Home levels: cost to reach each level (MapConfig.HOLE_LEVELS has the slots and look). Level 7 needs a rebirth.
GameConfig.HOME_COST = { [2] = 500, [3] = 5_000, [4] = 50_000, [5] = 500_000, [6] = 5_000_000, [7] = 50_000_000 }
GameConfig.HOME_REBIRTH = { [7] = 1 }

-- Wake-up timer after banking, by blanket size
GameConfig.WAKE_SECONDS = { S = 5, M = 20, L = 60, G = 180 } :: { [string]: number }
GameConfig.FIRST_TOY = "PlushBunny" -- your very first toy is always an Uncommon Plush Bunny (the plan's first minute)

-- Stats ----------------------------------------------------------------------------------------------------------------
-- Strength, Sneak and Grip are bought with cash; each level costs 1.6x the last. Speed is trained on your wheel.
GameConfig.STAT_GROWTH = 1.6
GameConfig.STATS = {
	Strength = { order = 1, max = 20, cost = 100, text = "+5% speed dragging Large toys" },
	Sneak = { order = 2, max = 20, cost = 150, text = "-3% noise when you drag a toy" },
	Grip = { order = 3, max = 10, cost = 500, text = "+5% chance to hold on when hit" },
} :: { [string]: { order: number, max: number, cost: number, text: string } }
GameConfig.STAT_ORDER = { "Strength", "Sneak", "Grip" }
GameConfig.LARGE_STRENGTH = 5 -- Strength needed to grab a Large toy

-- cost of the next level of a stat when you're at `level`
function GameConfig.statCost(stat: string, level: number): number
	local s = GameConfig.STATS[stat]
	return math.floor(s.cost * GameConfig.STAT_GROWTH ^ level + 0.5)
end

-- Speed: your walk speed is BASE plus the points trained on your home's wheel. Each point takes a bit longer, and a
-- bigger wheel (higher home level) trains faster.
GameConfig.SPEED_BASE = 16
GameConfig.SPEED_MAX_POINTS = 34 -- walk speed 50
function GameConfig.trainSeconds(points: number): number
	return 2 + 0.6 * points
end
function GameConfig.trainRate(homeLevel: number): number
	return 1 + 0.25 * (homeLevel - 1)
end

-- Carrying (these were in Carry.luau)
GameConfig.CARRY_SPEED = { S = 0.95, M = 0.8, L = 0.6 } :: { [string]: number }
GameConfig.CARRY_NOISE = { S = 0.5, M = 1, L = 2 } :: { [string]: number }

-- Rebirth ("Growth Spurt"): resets cash, stats and home level; keeps toys and the Index.
GameConfig.REBIRTH = {
	{ cash = 50_000_000, strength = 18 },
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
