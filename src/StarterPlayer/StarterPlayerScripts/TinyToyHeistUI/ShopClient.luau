--!strict
-- The client side of the Robux shop (the server is Bedroom/Shop): buy or gift something by its Monetization key,
-- live prices from Roblox, and whether you own a pass. The server prompts the purchase and sends a notice when
-- something can't be bought (not created yet, already owned, ...).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Monetization = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Monetization")) :: any

local ShopClient = {}
ShopClient.Monetization = Monetization

local me = Players.LocalPlayer
local prices: { [string]: number } = {}

local function remote(name: string): RemoteFunction?
	local remotes = ReplicatedStorage:FindFirstChild("GameRemotes")
	return remotes and remotes:FindFirstChild(name) :: RemoteFunction?
end

-- Buy `key` for yourself, or as a gift for another player (their UserId)
function ShopClient.buy(key: string, giftUserId: number?)
	local item = Monetization.byKey[key]
	-- Studio before the products exist: the Mystery Blanket buttons still drop test blankets (as before the shop)
	if item and item.kind == "Mystery" and item.id == 0 and RunService:IsStudio() and not giftUserId then
		local claim = remote("Claim")
		if claim then
			task.spawn(function()
				claim:InvokeServer("TestBlanket", item.amount)
			end)
		end
		return
	end
	local shop = remote("Shop")
	if shop then
		task.spawn(function()
			shop:InvokeServer("Buy", key, giftUserId)
		end)
	end
end

function ShopClient.owns(key: string): boolean
	return me:GetAttribute(Monetization.attribute(key)) == true
end

-- Call fn now and whenever ownership of the pass changes
function ShopClient.onOwned(key: string, fn: (boolean) -> ())
	fn(ShopClient.owns(key))
	me:GetAttributeChangedSignal(Monetization.attribute(key)):Connect(function()
		fn(ShopClient.owns(key))
	end)
end

local function commas(n: number): string
	local text = tostring(math.floor(n))
	while true do
		local done
		text, done = string.gsub(text, "^(%d+)(%d%d%d)", "%1,%2")
		if done == 0 then
			return text
		end
	end
end
ShopClient.commas = commas

-- The price to show: the live one from Roblox once known, else the planned one
function ShopClient.priceText(key: string): string
	local item = Monetization.byKey[key]
	return commas(prices[key] or (item and item.price) or 0)
end

-- Ask Roblox for the live price and call fn(text) when it arrives (fn runs once now with the planned price)
function ShopClient.watchPrice(key: string, fn: (string) -> ())
	fn(ShopClient.priceText(key))
	local item = Monetization.byKey[key]
	if not item or item.id == 0 then
		return
	end
	task.spawn(function()
		if prices[key] == nil then
			local isPass = Monetization.pass(key) ~= nil
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfo(
					item.id,
					if isPass then Enum.InfoType.GamePass else Enum.InfoType.Product
				)
			end)
			if ok and info and typeof(info.PriceInRobux) == "number" then
				prices[key] = info.PriceInRobux
			end
		end
		fn(ShopClient.priceText(key))
	end)
end

return ShopClient
