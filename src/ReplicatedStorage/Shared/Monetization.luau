--!strict
-- Everything sold for Robux: the game passes and the developer products (Mystery Blankets, Speed packs, Cash packs,
-- Wake All, and a gift version of every pass). Server (Bedroom/Shop) and the shop UI both read it.
--   The Roblox ids live in ProductIds (written by tools/roblox-setup.ps1, which creates the passes and products on
--   the Roblox site). An id of 0 means "not created yet": the button says so instead of prompting.
--   `price` is only a fallback for the button: the shop shows the live price from Roblox once it has loaded.

local ProductIds = require(script.Parent:WaitForChild("ProductIds")) :: any

local Monetization = {}

export type Pass = {
	key: string,
	name: string,
	description: string, -- shown on the Roblox store page
	price: number,
	icon: string, -- picture in assets/tth2 (the store icon and the shop card badge)
	id: number,
	giftId: number, -- the developer product that gifts this pass to someone else
}
export type Product = {
	key: string,
	name: string,
	description: string,
	price: number,
	icon: string,
	id: number,
	kind: string, -- "Mystery", "Speed", "Cash", "WakeAll"
	amount: number, -- blankets, Speed or cash given
}

local function passId(key: string): number
	return (ProductIds.Passes or {})[key] or 0
end
local function productId(key: string): number
	return (ProductIds.Products or {})[key] or 0
end

-- Game passes ---------------------------------------------------------------------------------------------------------
Monetization.CASH_PASS = 2 -- x2 Cash: all toy income
Monetization.SPEED_PASS = 2 -- x2 Speed: Speed trained on the wheel
Monetization.LUCK_ROLLS = 2 -- x2 Luck: every blanket rolls its rarity twice and keeps the better toy, x2 mutation luck
Monetization.VIP_CASH = 1.5 -- VIP: +50% income and a VIP chat tag

Monetization.Passes = {
	{
		key = "Speed",
		name = "x2 Speed",
		description = "Train Speed twice as fast on your Speed wheel. Forever!",
		price = 99,
		icon = "PassSpeed3",
	},
	{
		key = "Cash",
		name = "x2 Cash",
		description = "Every toy in your pen earns double money. Forever!",
		price = 499,
		icon = "PassCash3",
	},
	{
		key = "Luck",
		name = "x2 Luck",
		description = "Every blanket rolls twice and you keep the rarer toy, plus double mutation luck.",
		price = 399,
		icon = "PassLuck3",
	},
	{
		key = "VIP",
		name = "VIP",
		description = "VIP chat tag and +50% cash from your toys.",
		price = 799,
		icon = "PassVIP3",
	},
} :: { Pass }

-- Developer products --------------------------------------------------------------------------------------------------
-- Mystery Blanket odds: these are the odds shown in the shop (Roblox requires odds on every random item), and the
-- server rolls exactly these.
Monetization.MYSTERY_ODDS = {
	{ "Common", 45 },
	{ "Uncommon", 30 },
	{ "Rare", 15 },
	{ "Epic", 7 },
	{ "Legendary", 2.5 },
	{ "Mythic", 0.5 },
}
Monetization.MYSTERY_WAKE = 10 -- seconds a bought blanket takes to wake up

Monetization.Products = {
	{ key = "Mystery1", name = "1 Mystery Blanket", kind = "Mystery", amount = 1, price = 99, icon = "Featured_hero" },
	{
		key = "Mystery3",
		name = "3 Mystery Blankets",
		kind = "Mystery",
		amount = 3,
		price = 249,
		icon = "Featured_hero",
	},
	{
		key = "Mystery10",
		name = "10 Mystery Blankets",
		kind = "Mystery",
		amount = 10,
		price = 799,
		icon = "Featured_hero",
	},
	{
		key = "Mystery50",
		name = "50 Mystery Blankets",
		kind = "Mystery",
		amount = 50,
		price = 3499,
		icon = "Featured_hero",
	},
	{ key = "Speed1", name = "+150K Speed", kind = "Speed", amount = 150_000, price = 59, icon = "SpeedPack1v2" },
	{ key = "Speed2", name = "+1M Speed", kind = "Speed", amount = 1_000_000, price = 199, icon = "SpeedPack2v2" },
	{ key = "Speed3", name = "+10M Speed", kind = "Speed", amount = 10_000_000, price = 459, icon = "SpeedPack3v2" },
	{ key = "Speed4", name = "+50M Speed", kind = "Speed", amount = 50_000_000, price = 999, icon = "SpeedPack4v2" },
	{ key = "Speed5", name = "+250M Speed", kind = "Speed", amount = 250_000_000, price = 1999, icon = "SpeedPack5v2" },
	{ key = "Cash1", name = "+$100K Cash", kind = "Cash", amount = 100_000, price = 59, icon = "CashPack1v2" },
	{ key = "Cash2", name = "+$500K Cash", kind = "Cash", amount = 500_000, price = 199, icon = "CashPack2v2" },
	{ key = "Cash3", name = "+$2M Cash", kind = "Cash", amount = 2_000_000, price = 459, icon = "CashPack3v2" },
	{ key = "Cash4", name = "+$20M Cash", kind = "Cash", amount = 20_000_000, price = 999, icon = "CashPack4v2" },
	{ key = "Cash5", name = "+$100M Cash", kind = "Cash", amount = 100_000_000, price = 1999, icon = "CashPack5v2" },
	{ key = "WakeAll", name = "Wake All Blankets", kind = "WakeAll", amount = 0, price = 29, icon = "Clock" },
} :: { Product }

local productDescriptions = {
	Mystery = "Mystery blankets delivered to your home. Odds: Common 45%, Uncommon 30%, Rare 15%, Epic 7%, "
		.. "Legendary 2.5%, Mythic 0.5%.",
	Speed = "Instantly adds Speed to your total.",
	Cash = "Instantly adds cash to your wallet.",
	WakeAll = "Every blanket waiting in your home wakes up right now, ready to hatch.",
}

Monetization.byKey = {} :: { [string]: Pass | Product }
Monetization.byProductId = {} :: { [number]: { kind: string, key: string } } -- product id -> what it sells
Monetization.byPassId = {} :: { [number]: Pass }

for _, pass in Monetization.Passes do
	pass.id = passId(pass.key)
	pass.giftId = productId("Gift" .. pass.key)
	Monetization.byKey[pass.key] = pass
	if pass.id ~= 0 then
		Monetization.byPassId[pass.id] = pass
	end
	if pass.giftId ~= 0 then
		Monetization.byProductId[pass.giftId] = { kind = "GiftPass", key = pass.key }
	end
end
for _, product in Monetization.Products do
	product.id = productId(product.key)
	product.description = productDescriptions[product.kind] or ""
	Monetization.byKey[product.key] = product
	if product.id ~= 0 then
		Monetization.byProductId[product.id] = { kind = "Product", key = product.key }
	end
end

function Monetization.pass(key: string): Pass?
	for _, pass in Monetization.Passes do
		if pass.key == key then
			return pass
		end
	end
	return nil
end

function Monetization.product(key: string): Product?
	for _, product in Monetization.Products do
		if product.key == key then
			return product
		end
	end
	return nil
end

-- The Player attribute that says someone owns a pass (bought or gifted), for the HUD
function Monetization.attribute(key: string): string
	return "Pass" .. key
end

return Monetization
