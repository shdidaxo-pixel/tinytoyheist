--!strict
-- The Speed wheel while you train: "+N Speed" pops off your runner every time your Speed ticks up, and every home's
-- wheel spins faster while its owner is running in it (faster still the faster they are). The pops use the shared
-- VFX library (ReplicatedStorage.Shared.VFX.popText); the spin only changes the wheel's Spin attribute on this
-- screen, which HomeView already spins it by.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig")) :: any
local VFX = require(Shared:WaitForChild("VFX")) :: any

local me = Players.LocalPlayer
local holes = Workspace:WaitForChild("Bedroom"):WaitForChild("Holes")

local CYAN = Color3.fromRGB(127, 216, 255)
local MAX_SPIN = 16 -- radians a second, so it reads as a blur and not a strobe

local function speedOf(player: Player): number
	local v = player:GetAttribute("Speed")
	return if typeof(v) == "number" then v else GameConfig.SPEED_START
end

-- "+N Speed" over your head each time the number goes up while you're running in the wheel
local last = speedOf(me)
me:GetAttributeChangedSignal("Speed"):Connect(function()
	local now = speedOf(me)
	local gained = now - last
	last = now
	if gained <= 0 or me:GetAttribute("Training") ~= true then
		return
	end
	local head = me.Character and me.Character:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end
	local jitter = Vector3.new(math.random(-15, 15) / 10, 1.5 + math.random(0, 10) / 10, math.random(-15, 15) / 10)
	VFX.popText(`+{GameConfig.speedText(gained)} Speed`, head.Position + jitter, {
		color = CYAN,
		size = 26,
		duration = 0.9,
	})
end)

-- Wheels spin faster while their owner trains: x2 at walk 16 up to about x6 at the top, eased in and out
local spinning: { [Model]: { base: number, now: number } } = {}
RunService.Heartbeat:Connect(function(dt)
	for _, hole in holes:GetChildren() do
		local holder = hole:FindFirstChild("TrainingWheel")
		local wheel = holder and holder:FindFirstChild("Wheel") :: Model?
		if not wheel then
			continue
		end
		local s = spinning[wheel]
		if not s then
			local base = wheel:GetAttribute("Spin")
			s = { base = if typeof(base) == "number" then base else 1.5, now = 1 }
			spinning[wheel] = s
		end
		local owner = Players:GetPlayerByUserId((hole:GetAttribute("Owner") :: number?) or 0)
		local target = 1
		if owner and owner:GetAttribute("Training") == true then
			target = 2 + GameConfig.walkSpeed(speedOf(owner)) / 40
		end
		s.now += (target - s.now) * math.min(1, dt * 2)
		local spin = math.min(s.base * s.now, MAX_SPIN)
		if math.abs(spin - ((wheel:GetAttribute("Spin") :: number?) or 0)) > 0.01 then
			wheel:SetAttribute("Spin", spin)
		end
	end
	-- forget wheels that were rebuilt (level up) or removed
	for wheel in spinning do
		if not wheel.Parent then
			spinning[wheel] = nil
		end
	end
end)
