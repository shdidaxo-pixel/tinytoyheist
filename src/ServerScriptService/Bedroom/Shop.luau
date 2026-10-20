--!strict
-- Robux: game passes and developer products (the list is Shared/Monetization).
--   Passes: owned if Roblox says you bought it (checked on join and when a purchase finishes) or someone gifted it to
--   you (profile.Passes). Ownership is the Player attribute Pass<Key> ("PassCash", ...): the systems that give the
--   perks read it (Economy: Cash and VIP, Upgrades: Speed, Carry/Pens: Luck, Fast Hatch and Slots, Homes: Super Lock)
--   and so does the HUD.
--   Products: MarketplaceService.ProcessReceipt grants them. Each PurchaseId is remembered in profile.Receipts and
--   the profile is saved before the purchase is confirmed, so a receipt is never granted twice or lost.
--   Buying: the client asks GameRemotes.Shop ("Buy", key, giftUserId?) and the server prompts the purchase, so it
--   knows who a gift is for. A gift goes to that player if they're still here (a pass gift for a pass they already
--   own is refused before the prompt), otherwise back to the buyer.
--   Mystery Blankets you can't fit yet wait in profile.MysteryOwed and arrive as your blanket slots free up.
--   Skip: the Wake now prompt on a sleeping blanket buys it for that blanket. Server Luck and Lullaby change the whole
--   server (Workspace attribute ServerLuckUntil; Giant.lullaby) and are announced to everyone.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig")) :: any
local Monetization = require(Shared:WaitForChild("Monetization")) :: any
local PlayerData = require(script.Parent.PlayerData)
local Pens = require(script.Parent.Pens)
local Carry = require(script.Parent.Carry)
local Moments = require(script.Parent.Moments)
local Giant = require(script.Parent.Giant)

local Shop = {}
Shop.RECEIPTS_KEPT = 100
Shop.INTENT_SECONDS = 120 -- a gift choice is forgotten after this long without a purchase

local notice: RemoteEvent
-- what each player asked to buy last: product id -> who gets it
local intents: { [Player]: { id: number, target: number, at: number, uid: string? } } = {}
local lastAsk: { [Player]: number } = {}

local function say(player: Player?, text: string, kind: string?)
	if player and player.Parent and notice then
		notice:FireClient(player, text, kind or "good")
	end
end

function Shop.owns(player: Player, key: string): boolean
	return player:GetAttribute(Monetization.attribute(key)) == true
end

local function setOwned(player: Player, key: string)
	if Shop.owns(player, key) then
		return
	end
	player:SetAttribute(Monetization.attribute(key), true)
end

-- Ask Roblox which passes this player bought (and add the gifted ones)
local function checkPasses(player: Player, profile: any)
	for _, pass in Monetization.Passes do
		local owned = profile.Passes and profile.Passes[pass.key] == true
		if not owned and pass.id ~= 0 and player.UserId > 0 then
			local ok, result = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.id)
			end)
			owned = ok and result == true
		end
		if owned then
			setOwned(player, pass.key)
		end
	end
end

---------------------------------------------------------------------------------------------------------------------
-- Granting

-- Give a product's contents to `player`. Returns a short description for the notice.
local function grantProduct(player: Player, product: any, uid: string?, buyer: Player): string
	local p = PlayerData.get(player) :: any
	if product.kind == "Cash" then
		PlayerData.addCash(player, product.amount)
		return "+" .. GameConfig.money(product.amount) .. " cash"
	elseif product.kind == "Speed" then
		p.Speed += product.amount
		player:SetAttribute("Speed", p.Speed)
		Carry.refreshSpeed(player)
		return "+" .. GameConfig.speedText(product.amount) .. " Speed"
	elseif product.kind == "Mystery" then
		p.MysteryOwed = (p.MysteryOwed or 0) + product.amount
		return `{product.amount} Mystery Blanket{if product.amount == 1 then "" else "s"}`
	elseif product.kind == "WakeAll" then
		local woken = Pens.wakeAll(player)
		return if woken > 0 then "all your blankets woke up" else "Wake All (nothing was asleep)"
	elseif product.kind == "Skip" then
		return if Pens.wakeOne(player, uid) then "a blanket woke up" else "a Skip for your next blanket"
	elseif product.kind == "Boost" then
		p.BoostUntil = math.max(os.time(), p.BoostUntil) + product.amount * 60
		return `x2 cash for {product.amount} minutes`
	elseif product.kind == "ServerLuck" then
		local untilTime = math.max(os.time(), (Workspace:GetAttribute("ServerLuckUntil") :: number?) or 0)
			+ product.amount * 60
		Workspace:SetAttribute("ServerLuckUntil", untilTime)
		Workspace:SetAttribute("ServerLuckBy", buyer.DisplayName)
		notice:FireAllClients(`{buyer.DisplayName} turned on x2 Server Luck for everyone!`, "good")
		return `x2 Server Luck for {product.amount} minutes`
	elseif product.kind == "Lullaby" then
		if Giant.lullaby then
			Giant.lullaby()
		end
		notice:FireAllClients(`{buyer.DisplayName} sang the Giant Kid back to sleep!`, "good")
		return "a Lullaby: the Kid is fast asleep"
	end
	return product.name
end

local function remember(profile: any, purchaseId: string)
	table.insert(profile.Receipts, purchaseId)
	while #profile.Receipts > Shop.RECEIPTS_KEPT do
		table.remove(profile.Receipts, 1)
	end
end

local function processReceipt(receipt: any): Enum.ProductPurchaseDecision
	local buyer = Players:GetPlayerByUserId(receipt.PlayerId)
	local buyerProfile = buyer and PlayerData.get(buyer) :: any
	if not buyer or not buyerProfile then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- Roblox tries again next time they join
	end
	local purchaseId = tostring(receipt.PurchaseId)
	if table.find(buyerProfile.Receipts, purchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted -- already given
	end
	local what = Monetization.byProductId[receipt.ProductId]
	if not what then
		warn(`Shop: unknown product {receipt.ProductId} bought by {buyer.Name}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- who gets it: the gift target chosen with this purchase, if they're still here
	local intent = intents[buyer]
	local receiver = buyer
	if intent and intent.id == receipt.ProductId and intent.target ~= buyer.UserId then
		local target = Players:GetPlayerByUserId(intent.target)
		if target and PlayerData.get(target) then
			receiver = target
		end
	end
	intents[buyer] = nil
	local receiverProfile = PlayerData.get(receiver) :: any

	local ok, result = pcall(function(): string
		if what.kind == "GiftPass" then
			local pass = Monetization.byKey[what.key]
			if receiver ~= buyer and Shop.owns(receiver, what.key) then
				receiver = buyer -- they got it some other way since: it's yours instead
				receiverProfile = buyerProfile
			end
			receiverProfile.Passes[what.key] = true
			setOwned(receiver, what.key)
			return pass.name .. " pass"
		end
		return grantProduct(receiver, Monetization.byKey[what.key], intent and intent.uid, buyer)
	end)
	if not ok then
		warn(`Shop: couldn't grant {what.key} to {receiver.Name}: {result}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	remember(buyerProfile, purchaseId)
	PlayerData.changed(buyer)
	PlayerData.changed(receiver)
	-- save now: the purchase is only confirmed once it's in the store
	local saved = PlayerData.save(buyer, false)
	if receiver ~= buyer then
		PlayerData.save(receiver, false)
	end
	if not saved then
		-- the grant stays in this session (and saves later); Roblox will ask again and the receipt list says it's done
		warn(`Shop: {buyer.Name}'s purchase {purchaseId} is granted but not saved yet`)
	end

	if receiver ~= buyer then
		say(buyer, `You gifted {result} to {receiver.DisplayName}!`)
		say(receiver, `{buyer.DisplayName} gifted you {result}!`)
		Moments.fire(receiver, "Purchased", { gift = true, what = result })
	else
		say(buyer, `Thanks! You got {result}!`)
		Moments.fire(buyer, "Purchased", { what = result })
	end
	return if saved then Enum.ProductPurchaseDecision.PurchaseGranted else Enum.ProductPurchaseDecision.NotProcessedYet
end

---------------------------------------------------------------------------------------------------------------------
-- Buying (GameRemotes.Shop)

local function ask(player: Player, action: any, key: any, giftUserId: any, uid: string?): (boolean, string?)
	if typeof(action) ~= "string" or typeof(key) ~= "string" then
		return false, "?"
	end
	local now = os.clock()
	if lastAsk[player] and now - lastAsk[player] < 0.5 then
		return false, nil
	end
	lastAsk[player] = now
	if not PlayerData.get(player) then
		return false, "Still loading..."
	end
	local item = Monetization.byKey[key]
	if not item or action ~= "Buy" then
		return false, "?"
	end
	local target: Player? = nil
	if giftUserId ~= nil then
		if typeof(giftUserId) ~= "number" then
			return false, "?"
		end
		target = Players:GetPlayerByUserId(giftUserId)
		if not target or target == player or not PlayerData.get(target :: Player) then
			return false, "That player isn't here any more"
		end
	end
	local isPass = Monetization.pass(key) ~= nil
	if isPass then
		if target then
			if Shop.owns(target :: Player, key) then
				return false, `{(target :: Player).DisplayName} already has {item.name}!`
			end
			if item.giftId == 0 then
				return false, "Gifting this pass isn't set up yet"
			end
			intents[player] = { id = item.giftId, target = giftUserId, at = now }
			MarketplaceService:PromptProductPurchase(player, item.giftId)
			return true, nil
		end
		if Shop.owns(player, key) then
			return false, "You already own this!"
		end
		if item.id == 0 then
			return false, "Coming soon!"
		end
		MarketplaceService:PromptGamePassPurchase(player, item.id)
		return true, nil
	end
	if item.id == 0 then
		return false, "Coming soon!"
	end
	if item.kind == "Lullaby" then
		local kid = Workspace:FindFirstChild("Bedroom") and Workspace.Bedroom:FindFirstChild("GiantKid")
		if
			kid
			and kid:GetAttribute("State") == "Asleep"
			and ((kid:GetAttribute("WakeMeter") :: number?) or 0) < 1
			and ((kid:GetAttribute("WakesAt") :: number?) or 0) - Workspace:GetServerTimeNow() > 120
		then
			return false, "The Kid is fast asleep already"
		end
	end
	if item.kind == "WakeAll" and not target then
		local p = PlayerData.get(player) :: any
		local asleep = false
		for _, b in p.Blankets do
			if b.w > os.time() then
				asleep = true
			end
		end
		if not asleep then
			return false, "No blankets are asleep right now"
		end
	end
	intents[player] = { id = item.id, target = if target then giftUserId else player.UserId, at = now, uid = uid }
	MarketplaceService:PromptProductPurchase(player, item.id)
	return true, nil
end

-- Studio tests (GameDebug "buy" / "pass"): run a purchase through the real receipt code without Robux. Products that
-- aren't created yet get a stand-in id for the test.
function Shop.debugBuy(player: Player, key: string, purchaseId: string, giftUserId: number?): string
	local item = Monetization.byKey[key]
	if not item then
		return "no such key"
	end
	local isPass = Monetization.pass(key) ~= nil
	local id = if isPass then item.giftId else item.id
	if id == 0 then
		id = -#key * 1000 - string.byte(key, -1)
		Monetization.byProductId[id] = { kind = if isPass then "GiftPass" else "Product", key = key }
	end
	if giftUserId then
		intents[player] = { id = id, target = giftUserId, at = os.clock() }
	end
	return processReceipt({ PlayerId = player.UserId, ProductId = id, PurchaseId = purchaseId }).Name
end
function Shop.debugPass(player: Player, key: string, on: boolean)
	player:SetAttribute(Monetization.attribute(key), if on then true else nil)
end

---------------------------------------------------------------------------------------------------------------------

function Shop.start(_bedroom: Model)
	notice = ReplicatedStorage:WaitForChild("BedroomRemotes"):WaitForChild("Notice") :: RemoteEvent
	local shopRemote = PlayerData.remote("RemoteFunction", "Shop") :: RemoteFunction
	shopRemote.OnServerInvoke = function(player: Player, action: any, key: any, gift: any)
		local ok, result, message = pcall(ask, player, action, key, gift)
		if not ok then
			warn(`Shop: {player.Name} {action} {key}: {result}`)
			return false, "Something went wrong"
		end
		if not result and message then
			say(player, message, "warn")
		end
		return result, message
	end

	MarketplaceService.ProcessReceipt = processReceipt

	-- Wake now on a sleeping blanket at home: buy a Skip for that blanket
	Pens.onSkip = function(player: Player, uid: string)
		local ok, result, message = pcall(ask, player, "Buy", "Skip", nil, uid)
		if ok and not result and message then
			say(player, message, "warn")
		end
	end

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local pass = Monetization.byPassId[passId]
		if purchased and pass then
			setOwned(player, pass.key)
			say(player, `Thanks! {pass.name} is yours forever!`)
			Moments.fire(player, "Purchased", { what = pass.name })
		end
	end)
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, purchased)
		if purchased then
			return
		end
		-- cancelled: forget the gift choice so a later buy of the same product isn't sent to someone else
		local player = Players:GetPlayerByUserId(userId)
		local intent = player and intents[player]
		if intent and intent.id == productId then
			intents[player :: Player] = nil
		end
	end)

	PlayerData.onLoaded(function(player, profile)
		checkPasses(player, profile)
	end)
	Players.PlayerRemoving:Connect(function(player)
		intents[player] = nil
		lastAsk[player] = nil
	end)

	-- Mystery Blankets waiting to be delivered, and stale gift choices
	task.spawn(function()
		while true do
			task.wait(2)
			for _, player in Players:GetPlayers() do
				local ok, err = pcall(function()
					local intent = intents[player]
					if intent and os.clock() - intent.at > Shop.INTENT_SECONDS then
						intents[player] = nil
					end
					local p = PlayerData.get(player) :: any
					if not p or (p.MysteryOwed or 0) <= 0 or not Pens.state(player) then
						return
					end
					local given = 0
					while p.MysteryOwed > 0 and Pens.canBank(player) do
						if not Carry.giveMystery(player, Monetization.MYSTERY_ODDS, Monetization.MYSTERY_WAKE) then
							break
						end
						p.MysteryOwed -= 1
						given += 1
					end
					if given > 0 then
						PlayerData.changed(player)
						local left = if p.MysteryOwed > 0
							then ` ({p.MysteryOwed} more on the way as you hatch them)`
							else ""
						say(player, `{given} Mystery Blanket{if given == 1 then "" else "s"} in your home!{left}`)
					end
				end)
				if not ok then
					warn(`Shop: mystery delivery for {player.Name}: {err}`)
				end
			end
		end
	end)
end

return Shop
