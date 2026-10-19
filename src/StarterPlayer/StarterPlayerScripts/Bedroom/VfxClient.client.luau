--!strict
-- The big moments on this player's screen (ReplicatedStorage.Shared.VFX does the effects; Moments is the shared
-- event bus the SFX listen to as well, see design/notes/vfx.md):
--   your hatch (charge-up, burst, card), "+$" pops over your pen toys, home and wheel level-ups, steals (yours and
--   from you), dropped stolen toys, the Kid stirring and waking, a rare blanket appearing, and button clicks.
-- Getting knocked down is in Effects.luau.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local VFX = require(Shared:WaitForChild("VFX")) :: any
local Moments = require(Shared:WaitForChild("VFX"):WaitForChild("Moments")) :: any
local ToyVFX = require(Shared:WaitForChild("Toys"):WaitForChild("ToyVFX")) :: any
local ToyAnimator = require(Shared:WaitForChild("Toys"):WaitForChild("ToyAnimator")) :: any
local GameConfig = require(Shared:WaitForChild("GameConfig")) :: any

local me = Players.LocalPlayer
local bedroom = Workspace:WaitForChild("Bedroom")
local remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local GOLD = Color3.fromRGB(255, 201, 60)
local RED = Color3.fromRGB(255, 61, 82)
local GREEN = Color3.fromRGB(91, 227, 106)

local function money(n: number): string
	return GameConfig.money(n)
end

local function myHome(): Instance?
	for _, h in bedroom:WaitForChild("Holes"):GetChildren() do
		if h:GetAttribute("Owner") == me.UserId then
			return h
		end
	end
	return nil
end

local function homeCentre(hole: Instance): Vector3
	local pen = hole:FindFirstChild("Pen")
	if pen and pen:IsA("BasePart") then
		return pen.Position
	end
	return (hole :: any):GetPivot().Position
end

local function myRoot(): BasePart?
	local c = me.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function near(pos: Vector3, studs: number): boolean
	local cam = Workspace.CurrentCamera
	return cam ~= nil and (cam.CFrame.Position - pos).Magnitude < studs
end

---------------------------------------------------------------------------------------------------------------------
-- Hatching your toy: hold E (a little charge), let go (the blanket shakes and builds up), the server says what it is
-- (GameRemotes.Reveal), the build-up runs for the rarity, then the burst, the pen toy pops in and the card shows.

local snapshot: Model? = nil -- our local copy of the blanket being hatched (the server deletes the real one)
local holding: Model? = nil

ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt)
	if prompt.Name ~= "HatchPrompt" then
		return
	end
	local blanket = prompt:FindFirstAncestorWhichIsA("Model")
	if not blanket then
		return
	end
	holding = blanket
	Moments.fire("HatchHold", { blanket = blanket, seconds = prompt.HoldDuration })
	VFX.burst("Sparkle", blanket, { color = Color3.new(1, 1, 1) })
end)

ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt)
	if prompt.Name == "HatchPrompt" and holding then
		local b = holding
		holding = nil
		task.defer(function()
			if not snapshot then
				Moments.fire("HatchCancel", { blanket = b })
			end
		end)
	end
end)

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt.Name ~= "HatchPrompt" then
		return
	end
	local blanket = prompt:FindFirstAncestorWhichIsA("Model")
	if not blanket or snapshot then
		return
	end
	-- copy it now, before the server takes the real one away, so there's no gap
	local copy = blanket:Clone()
	for _, d in copy:GetDescendants() do
		if d:IsA("ProximityPrompt") or d:IsA("BillboardGui") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
		end
	end
	copy.Name = "HatchingBlanket"
	copy:PivotTo(blanket:GetPivot())
	copy.Parent = Workspace:FindFirstChild("VFX") or Workspace
	snapshot = copy
	VFX.hatchBegin()
	-- the server never answered: put things back
	task.delay(4, function()
		if snapshot == copy then
			snapshot = nil
			copy:Destroy()
			VFX.hatchEnd()
		end
	end)
end)

local function onReveal(info: any)
	Moments.fire("Hatch", info)
	local copy = snapshot
	snapshot = nil
	local sizeMult = tonumber(info.sizeMult) or 1
	local function burst(at: Vector3, height: number?)
		Moments.fire("HatchBurst", { rarity = info.rarity, mutation = info.mutation, sizeMult = sizeMult })
		local toys = VFX.hatchEnd()
		local toy = toys[1]
		VFX.burst("Hatch", at, {
			rarity = info.rarity,
			mutation = info.mutation,
			sizeMult = sizeMult,
			mine = true,
			scale = math.max(1, (height or 5) / 4), -- as big as the blanket it came out of
		})
		for _, t in toys do
			pcall(ToyVFX.popIn, t, 0.5)
			pcall(ToyAnimator.play, t, "Hatch") -- the animations session's hatch jump, now that it can be seen
		end
		if toy then
			Moments.fire("ToyRevealed", { toy = toy, mine = true })
		end
		-- the screen
		local tier = VFX.tier(info.rarity)
		local color = VFX.rarityColor(info.rarity)
		VFX.flash(color:Lerp(Color3.new(1, 1, 1), 0.5), tier.flash, 0.3 + tier.n * 0.06)
		VFX.shake(tier.shake + (sizeMult - 1) * 0.3, 0.4 + tier.n * 0.08)
		if tier.n >= 3 then
			VFX.fovPunch(4 + tier.n * 1.5, 0.5)
			VFX.vignette(color, 0.35 + tier.n * 0.05, 1 + tier.n * 0.15)
		end
		if tier.screenConfetti > 0 then
			VFX.confetti(tier.screenConfetti)
		end
		if tier.n >= 6 then
			task.delay(0.35, function()
				VFX.flash(Color3.new(1, 1, 1), 0.5, 0.4)
				VFX.confetti(tier.screenConfetti)
			end)
		end
	end
	if copy and copy.Parent then
		local seconds = VFX.hatchCharge(copy, info.rarity, burst)
		Moments.fire("HatchCharge", { rarity = info.rarity, seconds = seconds })
	else
		local root = myRoot()
		burst(if root then root.Position else Vector3.zero)
	end
end
(remotes:WaitForChild("Reveal") :: RemoteEvent).OnClientEvent:Connect(onReveal)

---------------------------------------------------------------------------------------------------------------------
-- Cash: "+$" pops over your pen toys (each about every 6 s, staggered so they ripple), and the Cash moment

local POP_EVERY = 6
task.spawn(function()
	local beat = 0
	while true do
		task.wait(1)
		beat += 1
		local hole = myHome()
		local pen = hole and hole:FindFirstChild("PenToys")
		if not pen or not near(homeCentre(hole :: Instance), 140) then
			continue
		end
		for i, toy in pen:GetChildren() do
			if not toy:IsA("Model") then
				continue
			end
			local ps = toy:GetAttribute("PerSecond")
			if typeof(ps) ~= "number" or ps <= 0 or (beat + i) % POP_EVERY ~= 0 then
				continue
			end
			local amount = ps * POP_EVERY
			VFX.popText("+" .. money(amount), toy, { color = Color3.fromRGB(120, 255, 120), size = 24, duration = 1.1 })
			if VFX.quality() == "full" then
				VFX.coins(toy:GetPivot().Position, 4, 2)
			end
			Moments.fire("ToyIncome", { toy = toy, amount = amount })
		end
	end
end)

local lastCash = me:GetAttribute("Cash")
me:GetAttributeChangedSignal("Cash"):Connect(function()
	local cash = me:GetAttribute("Cash")
	if typeof(cash) == "number" and typeof(lastCash) == "number" and cash > lastCash then
		Moments.fire("Cash", { amount = cash - lastCash })
	end
	lastCash = cash
end)

---------------------------------------------------------------------------------------------------------------------
-- Home and wheel level-ups (your home's Level / WheelLevel going up; the server rebuilds the look first)

local function watchLevels(hole: Instance)
	local levels = { Level = hole:GetAttribute("Level"), WheelLevel = hole:GetAttribute("WheelLevel") }
	for name in levels do
		hole:GetAttributeChangedSignal(name):Connect(function()
			local new = hole:GetAttribute(name)
			local old = levels[name]
			levels[name] = new
			if hole:GetAttribute("Owner") ~= me.UserId then
				return
			end
			if typeof(new) ~= "number" or typeof(old) ~= "number" or new <= old then
				return
			end
			task.wait(0.35) -- let the new look build
			local wheel = name == "WheelLevel" and hole:FindFirstChild("TrainingWheel", true)
			local at: any = if wheel then wheel else homeCentre(hole)
			local color = if name == "Level" then GOLD else Color3.fromRGB(80, 200, 255)
			VFX.burst("LevelUp", at, { color = color, scale = if wheel then 1 else 2 })
			if near(homeCentre(hole), 250) then
				VFX.flash(color, 0.35, 0.45)
				VFX.shake(0.35, 0.5)
				VFX.fovPunch(6, 0.5)
				VFX.confetti(80)
				VFX.popText(
					if name == "Level" then `HOME LEVEL {new}!` else `SPEED WHEEL LV {new}!`,
					UDim2.fromScale(0.5, 0.3),
					{ color = color, size = 56, duration = 2, rise = 30 }
				)
			end
			Moments.fire(if name == "Level" then "HomeLevelUp" else "WheelLevelUp", { home = hole, level = new })
		end)
	end
end
for _, hole in bedroom:WaitForChild("Holes"):GetChildren() do
	watchLevels(hole)
end

---------------------------------------------------------------------------------------------------------------------
-- Steals (the server sends these through GameRemotes.Moment)

Moments.on("StealStart", function(d: any)
	local root = myRoot()
	if d.thief == me.UserId then
		if root then
			VFX.burst("Steal", root)
		end
		VFX.vignette(Color3.fromRGB(255, 140, 40), 0.35, 0.9)
		VFX.shake(0.25, 0.3)
		VFX.popText("GO GO GO!", UDim2.fromScale(0.5, 0.3), { color = Color3.fromRGB(255, 170, 60), size = 50 })
	elseif d.owner == me.UserId then
		VFX.flash(RED, 0.4, 0.4)
		VFX.shake(0.45, 0.5)
		VFX.vignette(RED, 0.55, 2.2)
		VFX.popText("THIEF!", UDim2.fromScale(0.5, 0.3), { color = RED, size = 60, duration = 1.6 })
	end
end)

Moments.on("StealBanked", function(d: any)
	local hole = myHome()
	if hole then
		VFX.burst("LevelUp", homeCentre(hole), { color = Color3.fromRGB(255, 120, 60), scale = 1.6 })
	end
	VFX.flash(GOLD, 0.35, 0.4)
	VFX.shake(0.35, 0.4)
	VFX.confetti(70)
	VFX.popText("STOLEN!", UDim2.fromScale(0.5, 0.3), { color = GOLD, size = 64, duration = 1.8 })
	if d.toyName then
		VFX.popText(tostring(d.toyName), UDim2.fromScale(0.5, 0.38), { color = VFX.rarityColor(d.rarity), size = 34 })
	end
end)

Moments.on("StolenFrom", function(d: any)
	local hole = myHome()
	if hole then
		VFX.burst("Stolen", homeCentre(hole), { scale = 1.5 })
	end
	VFX.flash(RED, 0.5, 0.5)
	VFX.shake(0.6, 0.6)
	VFX.vignette(RED, 0.6, 1.6)
	VFX.popText(
		"-" .. tostring(d.toyName or "toy"),
		UDim2.fromScale(0.5, 0.3),
		{ color = RED, size = 50, duration = 1.8 }
	)
end)

Moments.on("StolenDropped", function(d: any)
	if typeof(d.position) ~= "Vector3" or not near(d.position, 300) then
		return
	end
	local mine = d.owner == me.UserId
	VFX.beams(d.position, RED, if mine then 3 else 2, 2.2, 30)
	VFX.burst("Shockwave", d.position, { color = RED, scale = 1.2 })
	VFX.popText(
		if mine then "YOUR TOY! GRAB IT!" else "DROPPED!",
		d.position,
		{ color = RED, size = 30, duration = 1.6 }
	)
end)

Moments.on("Recovered", function()
	local root = myRoot()
	if root then
		VFX.burst("Recovered", root)
	end
	VFX.flash(GREEN, 0.3, 0.35)
	VFX.popText("GOT IT BACK!", UDim2.fromScale(0.5, 0.3), { color = GREEN, size = 52 })
end)

---------------------------------------------------------------------------------------------------------------------
-- The Kid: stirring (a jolt, red edges), awake (a big jolt, a red flash, the edges thump like a heartbeat until he's
-- back in bed)

task.spawn(function()
	local kid = bedroom:WaitForChild("GiantKid", 30)
	if not kid then
		return
	end
	local last = kid:GetAttribute("State")
	local function head(): Vector3
		local h = kid:FindFirstChild("Head", true)
		return if h and h:IsA("BasePart") then h.Position else (kid :: any):GetPivot().Position + Vector3.new(0, 30, 0)
	end
	kid:GetAttributeChangedSignal("State"):Connect(function()
		local state = kid:GetAttribute("State")
		if state == last then
			return
		end
		last = state
		if state == "Stirring" then
			VFX.shake(0.25, 0.5)
			VFX.vignette(RED, 0.3, 1.4)
			VFX.popText("!", head(), { color = RED, size = 90, duration = 1.4, rise = 6 })
			Moments.fire("KidStir", {})
		elseif state == "Awake" then
			VFX.flash(RED, 0.4, 0.5)
			VFX.shake(0.85, 1.2)
			VFX.fovPunch(8, 0.6)
			VFX.vignette(RED, 0.45) -- held until he goes back to bed
			VFX.popText("!!", head(), { color = RED, size = 110, duration = 1.6, rise = 8 })
			Moments.fire("KidWake", {})
		else
			VFX.vignette(nil)
			if state == "Asleep" then
				Moments.fire("KidSleep", {})
			end
		end
	end)
end)

---------------------------------------------------------------------------------------------------------------------
-- A rare blanket appears on the floor: a pillar of light and its rarity name, for everyone nearby

local RARE = { Legendary = true, Mythic = true, Secret = true }
task.spawn(function()
	local folder = bedroom:WaitForChild("SleepingToys", 60)
	if not folder then
		return
	end
	folder.ChildAdded:Connect(function(b)
		task.wait(0.2) -- attributes arrive with it, but give the model a moment to settle
		local rarity = b:GetAttribute("Rarity")
		if not b:IsA("Model") or not RARE[rarity] or b:GetAttribute("Spawn") == nil then
			return
		end
		local pos = b:GetPivot().Position
		if not near(pos, 350) then
			return
		end
		local color = VFX.rarityColor(rarity)
		VFX.beams(pos, if rarity == "Secret" then VFX.RAINBOW else color, 3, 2.4, 60)
		VFX.burst("Shockwave", pos, { color = color, scale = 1.5 })
		VFX.burst("Sparkle", b, { color = color })
		VFX.popText(string.upper(rarity) .. "!", b, { color = color, size = 34, duration = 2 })
		Moments.fire("RareSpawn", { blanket = b, rarity = rarity })
	end)
end)

---------------------------------------------------------------------------------------------------------------------
-- Buttons: a pop and a few sparks where you click (UIKit.clickable buttons are invisible "Hit" buttons over a block)

local function wire(d: Instance)
	if d:IsA("GuiButton") and d:FindFirstAncestor("TinyToyHeistUI") then
		local holder = if d.Name == "Hit" and d.Parent and d.Parent:IsA("GuiObject") then d.Parent else d
		VFX.uiPress(d, holder :: GuiObject)
	end
end
task.spawn(function()
	local pg = me:WaitForChild("PlayerGui")
	pg.DescendantAdded:Connect(wire)
	for _, d in pg:GetDescendants() do
		wire(d)
	end
end)
