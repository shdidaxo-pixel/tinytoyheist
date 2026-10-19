--!strict
-- Toy size, the second roll at hatch: Normal, Big, Huge or Giant (numbers in GameConfig.SIZE). It stacks with the
-- look mutation (Huge + Gold), scales the model, multiplies money and sell price and slows a thief carrying it.
-- Saved on the toy as `z` (nil = Normal, so older saves need nothing). Also the hatch timer by blanket and rarity.
-- Server and client both use it.
--   ToySize.roll(rng) -> tier?         nil for Normal
--   ToySize.money(tier?) / .scale(tier?) / .carry(tier?)
--   ToySize.name(tier?) -> "Huge" ...   ToySize.color(tier?) -> Color3
--   ToySize.apply(model, tier?)         grows the model; sets attributes SizeTier, Height and Reach
--   ToySize.reach(model) -> number      half the toy's footprint (studs), for keeping it inside the pen
--   ToySize.wakeSeconds(blanketSize, rarity, first?) -> number

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig")) :: any

local ToySize = {}

type Tier = { chance: number, scale: number, money: number, carry: number, color: string }
local SIZE = GameConfig.SIZE :: { [string]: any }
ToySize.Order = SIZE.Order :: { string }

local function tier(id: string?): Tier
	return (SIZE[id or "Normal"] or SIZE.Normal) :: Tier
end

-- nil for Normal, otherwise "Big" / "Huge" / "Giant"
function ToySize.roll(rng: Random): string?
	local roll = rng:NextNumber()
	-- rarest first, so the odds read straight off the table
	for i = #ToySize.Order, 2, -1 do
		local id = ToySize.Order[i]
		roll -= tier(id).chance
		if roll < 0 then
			return id
		end
	end
	return nil
end

function ToySize.money(id: string?): number
	return tier(id).money
end
function ToySize.scale(id: string?): number
	return tier(id).scale
end
function ToySize.carry(id: string?): number
	return tier(id).carry
end
function ToySize.name(id: string?): string
	return if id and SIZE[id] then id else "Normal"
end
function ToySize.color(id: string?): Color3
	return Color3.fromHex(tier(id).color)
end
function ToySize.isBig(id: string?): boolean
	return id ~= nil and id ~= "Normal" and SIZE[id] ~= nil
end

-- Half the widest side of the toy's visible body (effects and the invisible Root left out), in studs
function ToySize.reach(model: Model): number
	local pivot = model:GetPivot()
	local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p.Transparency < 0.6 and p ~= model.PrimaryPart then
			local c = pivot:PointToObjectSpace(p.Position)
			local half = p.Size / 2
			lo = lo:Min(c - half)
			hi = hi:Max(c + half)
		end
	end
	if lo.X > hi.X then
		return 3
	end
	local span = hi - lo
	return math.max(span.X, span.Z) / 2
end

-- The widest a grown toy may get (half its footprint, studs): the pen is about 68 x 70 inside, so a very wide toy
-- (a Giant paper plane from a Large blanket) is held back to fit and still roam a little
ToySize.MAX_REACH = 26

local function grow(model: Model, k: number)
	model:ScaleTo(model:GetScale() * k)
	local height = model:GetAttribute("Height") :: number?
	if height then
		model:SetAttribute("Height", height * k)
	end
end

-- Grow a toy model to its size tier (call once, after any other scaling)
function ToySize.apply(model: Model, id: string?)
	local k = ToySize.scale(id)
	if k ~= 1 then
		grow(model, k)
	end
	local reach = ToySize.reach(model)
	if k > 1 and reach > ToySize.MAX_REACH then
		grow(model, ToySize.MAX_REACH / reach)
		reach = ToySize.MAX_REACH
	end
	model:SetAttribute("SizeTier", ToySize.name(id))
	model:SetAttribute("Reach", reach)
end

-- How long a blanket takes to wake up: by blanket size and the toy's rarity; the very first toy is quick
function ToySize.wakeSeconds(blanketSize: string, rarity: string?, first: boolean?): number
	if first then
		return GameConfig.FIRST_WAKE
	end
	local row = GameConfig.WAKE_SECONDS[blanketSize] or GameConfig.WAKE_SECONDS.S
	return row[rarity or "Common"] or row.Common or 10
end

return ToySize
