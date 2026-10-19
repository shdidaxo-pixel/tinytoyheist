--!strict
-- Every toy, loaded from the set files in Sets/. The source of truth for names, rarities, money, sizes and looks
-- (Toy Catalog.md is the design doc it was copied from).
--
--   ToyCatalog.get("RubberDuck")            -> toy data (Id, Name, Set, Rarity, Money, Size, Idle, ...)
--   ToyCatalog.list()                       -> every toy, in set order then catalog order
--   ToyCatalog.inSet("Kitchen", "Rare")     -> the Kitchen's Rare toys (rarity optional)
--   ToyCatalog.pick("Kitchen", "Rare", rng) -> one of them at random (nil if none)
local Sets = script.Parent:WaitForChild("Sets")

local ToyCatalog = {}

-- Room sets first (deepest last), then event lines, then specials.
ToyCatalog.SET_ORDER = {
	"Bedroom",
	"Hallway",
	"Kitchen",
	"LivingRoom",
	"Garage",
	"Attic",
	"Halloween",
	"NightmareNight",
	"Winter",
	"Specials",
}

local list: { any } = {}
local byId: { [string]: any } = {}
local setNames: { [string]: string } = {}

for _, setId in ToyCatalog.SET_ORDER do
	local module = Sets:FindFirstChild(setId)
	if module and module:IsA("ModuleScript") then
		local ok, data = pcall(require, module)
		if ok and type(data) == "table" then
			setNames[setId] = data.SetName or setId
			for _, toy in data.Toys or {} do
				toy.Set = setId
				toy.SetName = data.SetName
				if byId[toy.Id] then
					warn(`ToyCatalog: duplicate toy id {toy.Id} in {setId}`)
				end
				byId[toy.Id] = toy
				table.insert(list, toy)
			end
		else
			warn(`ToyCatalog: couldn't load Sets.{setId}: {data}`)
		end
	end
end

function ToyCatalog.get(id: string): any
	return byId[id]
end

function ToyCatalog.list(): { any }
	return list
end

function ToyCatalog.setName(setId: string): string
	return setNames[setId] or setId
end

function ToyCatalog.inSet(setId: string, rarity: string?): { any }
	local out = {}
	for _, toy in list do
		if toy.Set == setId and (rarity == nil or toy.Rarity == rarity) then
			table.insert(out, toy)
		end
	end
	return out
end

function ToyCatalog.pick(setId: string, rarity: string, rng: Random?): any
	local options = ToyCatalog.inSet(setId, rarity)
	if #options == 0 then
		return nil
	end
	return options[(rng or Random.new()):NextInteger(1, #options)]
end

return ToyCatalog
