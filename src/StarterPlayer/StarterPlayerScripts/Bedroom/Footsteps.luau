--!strict
-- Sounds that follow every player's character: tiny footsteps by floor (soft carpet, tapping wood, and on the creaky
-- boards a creak now and then, which should feel risky), a thump on landing, the blanket dragging behind you while
-- you carry a toy (lower for bigger blankets) and the squeaky Speed wheel while you train, pitching up as you get
-- faster. Slow Mode halves your steps and drag. Roblox's own running sound is muted. Started by Sounds.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MapConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MapConfig")) :: any
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig")) :: any

local Footsteps = {}

local HEAR = 80 -- other players' steps are skipped past this distance from the camera
local CREAK_CHANCE = 0.3 -- a step on the creaky boards creaks this often
local DRAG_PITCH = { S = 1.15, M = 1, L = 0.85 }

type Walker = {
	player: Player,
	humanoid: Humanoid,
	root: BasePart,
	timer: number,
	drag: Sound?,
	dragLevel: number,
	wheel: Sound?,
	wheelLevel: number,
	spin: number,
}

function Footsteps.start(_bedroom: Model, Sounds: any)
	local me = Players.LocalPlayer
	local walkers: { [Player]: Walker } = {}
	local rng = Random.new()

	local function quietDefaults(root: BasePart)
		local function fix(s: Instance)
			if s:IsA("Sound") then
				s.SoundGroup = Sounds.SFX
				if s.Name == "Running" then
					s.Volume = 0
				end
			end
		end
		root.ChildAdded:Connect(fix)
		for _, c in root:GetChildren() do
			fix(c)
		end
	end

	local function step(w: Walker, loud: number)
		local pos = w.root.Position
		local zone = MapConfig.zoneAt(pos)
		local name = zone and zone.name or "Carpet"
		local mine = w.player == me
		local v = loud * (if mine then 1 else 0.7) * (if w.player:GetAttribute("SlowMode") then 0.5 else 1)
		local at = w.root
		if name == "Carpet" then
			Sounds.play("StepCarpet", at, { volume = v })
		elseif name == "Wood" then
			Sounds.play("StepWood", at, { volume = v })
		else
			Sounds.play("StepWood", at, { volume = v * 0.9, pitch = 0.85 })
			if rng:NextNumber() < CREAK_CHANCE then
				Sounds.play("StepCreak", at, { volume = v, pitch = rng:NextNumber(0.85, 1.15) })
			end
		end
	end

	local function track(player: Player, character: Model)
		local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
		local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
		if not humanoid or not root then
			return
		end
		quietDefaults(root)
		local w: Walker = {
			player = player,
			humanoid = humanoid,
			root = root,
			timer = 0,
			drag = nil,
			dragLevel = 0,
			wheel = nil,
			wheelLevel = 0,
			spin = 0,
		}
		walkers[player] = w
		humanoid.StateChanged:Connect(function(_old, new)
			if new == Enum.HumanoidStateType.Landed then
				step(w, 1.3)
			end
		end)
		character.AncestryChanged:Connect(function()
			if not character.Parent and walkers[player] == w then
				walkers[player] = nil
			end
		end)
	end
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(c)
			track(player, c)
		end)
		if player.Character then
			task.spawn(track, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(watch)
	for _, p in Players:GetPlayers() do
		watch(p)
	end
	Players.PlayerRemoving:Connect(function(p)
		walkers[p] = nil
	end)

	local maxLevel = if type(GameConfig.WHEELS) == "table" then math.max(2, #GameConfig.WHEELS) else 25
	-- how fast you are, 0 (walk speed 16) to 1 (116 and up)
	local function fastness(player: Player): number
		local speed = player:GetAttribute("Speed") :: number?
		if type(speed) ~= "number" or type(GameConfig.walkSpeed) ~= "function" then
			return 0
		end
		return math.clamp((GameConfig.walkSpeed(speed) - 16) / 100, 0, 1)
	end
	RunService.Heartbeat:Connect(function(dt)
		local camera = Workspace.CurrentCamera
		for player, w in walkers do
			if not w.root.Parent then
				walkers[player] = nil
				continue
			end
			local near = player == me or (camera and (camera.CFrame.Position - w.root.Position).Magnitude < HEAR)
			local v = w.root.AssemblyLinearVelocity
			local speed = Vector3.new(v.X, 0, v.Z).Magnitude
			local training = player:GetAttribute("Training") == true
			local grounded = w.humanoid.FloorMaterial ~= Enum.Material.Air
			local moving = grounded and speed > 2 and not training

			-- footsteps: quick little patter, faster as you run
			if moving and near then
				w.timer -= dt
				if w.timer <= 0 then
					w.timer = math.clamp(4.5 / speed, 0.11, 0.32)
					step(w, 1)
				end
			else
				w.timer = 0.05
			end

			-- the blanket dragging behind you
			local carrying = player:GetAttribute("Carrying") ~= nil
			if carrying and not w.drag then
				local s = Sounds.loop("DragLoop", w.root) :: Sound
				s:SetAttribute("Base", s.Volume)
				s.Volume = 0
				s:Play()
				w.drag = s
			end
			if w.drag then
				local base = w.drag:GetAttribute("Base") :: number
				local slow = if player:GetAttribute("SlowMode") then 0.5 else 1
				local target = if carrying and moving then math.clamp(speed / 16, 0.4, 1.2) * slow else 0
				w.dragLevel += (target - w.dragLevel) * math.min(1, dt * 6)
				w.drag.Volume = base * w.dragLevel
				w.drag.PlaybackSpeed = DRAG_PITCH[player:GetAttribute("CarrySize") :: any] or 1
				if not carrying and w.dragLevel < 0.02 then
					w.drag:Destroy()
					w.drag = nil
				end
			end

			-- the Speed wheel: spins up when you start, pitch rises with your wheel level and Speed
			if training and not w.wheel then
				local s = Sounds.loop("WheelLoop", w.root) :: Sound
				s:SetAttribute("Base", s.Volume)
				s.Volume = 0
				s:Play()
				w.wheel = s
				w.spin = 0
			end
			if w.wheel then
				local base = w.wheel:GetAttribute("Base") :: number
				w.spin += ((if training then 1 else 0) - w.spin) * math.min(1, dt * (if training then 1.5 else 4))
				local level = (player:GetAttribute("WheelLevel") :: number?) or 1
				local tier = math.clamp((level - 1) / (maxLevel - 1), 0, 1)
				local pitch = 0.75 + 0.25 * tier + 0.45 * fastness(player)
				w.wheel.PlaybackSpeed = pitch * (0.5 + 0.5 * w.spin)
				w.wheel.Volume = base * w.spin
				if not training and w.spin < 0.02 then
					w.wheel:Destroy()
					w.wheel = nil
				end
			end
		end
	end)
end

return Footsteps
