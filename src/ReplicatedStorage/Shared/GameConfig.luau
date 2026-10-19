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

-- Wake-up timer after banking, by blanket size
GameConfig.WAKE_SECONDS = { S = 5, M = 20, L = 60, G = 180 } :: { [string]: number }
GameConfig.FIRST_TOY = "PlushBunny" -- your very first toy is always an Uncommon Plush Bunny (the plan's first minute)

-- Speed --------------------------------------------------------------------------------------------------------------
-- The one stat (Dylan, 19 Oct: "you really just need speed"; Strength, Sneak and Grip are gone). Your walk speed is
-- BASE plus the points trained on your home's Speed wheel. Each point takes a bit longer; a better wheel trains
-- faster. The wheel has its own levels, bought separately from the home, so either can come first.
GameConfig.SPEED_BASE = 16
GameConfig.SPEED_MAX_POINTS = 64 -- walk speed 80
function GameConfig.trainSeconds(points: number): number -- seconds of running for the next point, at x1
	return 2 + 0.5 * points
end
GameConfig.WHEEL_COST = { [2] = 300, [3] = 2_500, [4] = 20_000, [5] = 150_000, [6] = 1_000_000, [7] = 8_000_000 }
function GameConfig.trainRate(wheelLevel: number): number -- how much faster than x1 a wheel trains
	return 1 + 0.5 * (wheelLevel - 1)
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
