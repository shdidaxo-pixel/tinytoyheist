--!strict
-- The game in the world, on each player's screen: the wake-up countdown over a blanket in a home (it shakes as it
-- gets ready, then says READY! Hold E), the reveal burst when a toy hatches, which prompts you see (promptRule), the
-- run while you train Speed on your wheel (jump or move to stop), and the Performance Mode and Hide Players settings.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ToyVFX = require(Shared:WaitForChild("Toys"):WaitForChild("ToyVFX")) :: any

local GameView = {}

local me = Players.LocalPlayer
local GOLD = Color3.fromRGB(255, 201, 60)
local INK = Color3.fromRGB(26, 20, 48)

local function textLabel(parent: Instance, text: string, color: Color3, size: UDim2, position: UDim2): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = position
	l.Text = text
	l.TextScaled = true
	l.Font = Enum.Font.GothamBlack
	l.TextColor3 = color
	local s = Instance.new("UIStroke")
	s.Thickness = 2.5
	s.Color = INK
	s.Parent = l
	l.Parent = parent
	return l
end

-- A blanket waking up in a pen: a countdown and a bar over it, and a shake for the last second and a half
type Waking = { blanket: Model, rest: CFrame, label: TextLabel, fill: Frame, gui: BillboardGui }
local waking: { [Model]: Waking } = {}

local function watchWaking(blanket: Instance)
	if not blanket:IsA("Model") or waking[blanket] then
		return
	end
	local main = blanket.PrimaryPart or blanket:FindFirstChildWhichIsA("BasePart")
	if not main then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "WakeTimer"
	gui.Size = UDim2.fromOffset(150, 56)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 9, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 160
	gui.Adornee = main
	local label = textLabel(gui, "Waking up...", Color3.new(1, 1, 1), UDim2.new(1, 0, 0, 30), UDim2.new())
	local back = Instance.new("Frame")
	back.BackgroundColor3 = INK
	back.Size = UDim2.new(1, -20, 0, 14)
	back.Position = UDim2.fromOffset(10, 36)
	back.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 7)
	corner.Parent = back
	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = GOLD
	fill.Size = UDim2.fromScale(0, 1)
	fill.Parent = back
	corner:Clone().Parent = fill
	gui.Parent = main
	waking[blanket] = { blanket = blanket, rest = blanket:GetPivot(), label = label, fill = fill, gui = gui }
	blanket.AncestryChanged:Connect(function()
		if not blanket.Parent then
			waking[blanket] = nil
		end
	end)
end

-- A toy that just woke up: confetti burst and a pop
local function watchPenToy(toy: Instance)
	if not toy:IsA("Model") then
		return
	end
	task.defer(function()
		local at = toy:GetAttribute("RevealedAt")
		if typeof(at) == "number" and Workspace:GetServerTimeNow() - at < 4 then
			pcall(ToyVFX.revealBurst, toy)
			pcall(ToyVFX.popIn, toy, 0.5)
		end
	end)
end

-- Prompts in homes, on your screen: Steal only on other people's toys; Hatch, Train, Lock and Index only in your own
-- home; Train hidden while you're already training. Hidden by distance 0, which the server never changes.
local function promptRule(d: Instance, hole: Instance)
	if not d:IsA("ProximityPrompt") then
		return
	end
	local mine = hole:GetAttribute("Owner") == me.UserId
	local base = d:GetAttribute("BaseDistance")
	if typeof(base) ~= "number" then
		base = d.MaxActivationDistance
		d:SetAttribute("BaseDistance", base)
	end
	local show = true
	if d.Name == "StealPrompt" then
		show = not mine
	elseif d.Name == "TrainPrompt" then
		show = mine and me:GetAttribute("Training") ~= true
	elseif d.Name == "HatchPrompt" or d.Name == "LockPrompt" or d.Name == "IndexPrompt" then
		show = mine
	end
	d.MaxActivationDistance = if show then base :: number else 0
end

local homes: { Instance } = {}
local function refreshPrompts()
	for _, hole in homes do
		for _, d in hole:GetDescendants() do
			promptRule(d, hole)
		end
	end
end

local function watchHome(hole: Instance)
	table.insert(homes, hole)
	hole.DescendantAdded:Connect(function(d)
		promptRule(d, hole)
	end)
	hole:GetAttributeChangedSignal("Owner"):Connect(function()
		for _, d in hole:GetDescendants() do
			promptRule(d, hole)
		end
	end)
	for _, d in hole:GetDescendants() do
		promptRule(d, hole)
	end
	local penToys = hole:WaitForChild("PenToys", 10)
	if penToys then
		penToys.ChildAdded:Connect(watchPenToy)
	end
	local function watchFolder(folder: Instance)
		if folder.Name == "Waking" then
			folder.ChildAdded:Connect(watchWaking)
			for _, b in folder:GetChildren() do
				watchWaking(b)
			end
		end
	end
	hole.ChildAdded:Connect(watchFolder)
	for _, c in hole:GetChildren() do
		watchFolder(c)
	end
end

-- Training on the wheel: play the run animation in place; jump or move to hop off
local runTrack: AnimationTrack? = nil
local function training()
	local on = me:GetAttribute("Training") == true
	local character = me.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if on and humanoid then
		local animator = humanoid:FindFirstChildOfClass("Animator")
		local animate = character and character:FindFirstChild("Animate")
		local run = animate and animate:FindFirstChild("run")
		local anim = run and run:FindFirstChildOfClass("Animation")
		if animator and anim then
			runTrack = animator:LoadAnimation(anim);
			(runTrack :: AnimationTrack):Play(0.2, 1, 1.6)
		end
	elseif runTrack then
		runTrack:Stop(0.2)
		runTrack = nil
	end
end

function GameView.start(bedroom: Model)
	local holes = bedroom:WaitForChild("Holes")
	for _, hole in holes:GetChildren() do
		task.spawn(watchHome, hole)
	end

	-- Steal: the toy roams only on our screen, so tell the server which one we held (it checks where it really is)
	local steal = ReplicatedStorage:WaitForChild("GameRemotes"):WaitForChild("Steal") :: RemoteEvent
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local toy = prompt.Name == "StealPrompt" and prompt:FindFirstAncestorWhichIsA("Model")
		local uid = toy and toy:GetAttribute("Uid")
		if typeof(uid) == "string" then
			steal:FireServer(uid)
		end
	end)

	local stop = ReplicatedStorage:WaitForChild("GameRemotes"):WaitForChild("StopTraining") :: RemoteEvent
	me:GetAttributeChangedSignal("Training"):Connect(function()
		training()
		refreshPrompts()
	end)
	local function hopOff()
		if me:GetAttribute("Training") then
			stop:FireServer()
		end
	end
	UserInputService.JumpRequest:Connect(hopOff)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		local k = input.KeyCode
		if
			k == Enum.KeyCode.W
			or k == Enum.KeyCode.A
			or k == Enum.KeyCode.S
			or k == Enum.KeyCode.D
			or k == Enum.KeyCode.Up
			or k == Enum.KeyCode.Down
			or k == Enum.KeyCode.Left
			or k == Enum.KeyCode.Right
		then
			hopOff()
		end
	end)

	RunService.RenderStepped:Connect(function()
		local now = Workspace:GetServerTimeNow()
		for blanket, w in waking do
			local wakeAt = blanket:GetAttribute("WakeAt") :: number?
			local total = (blanket:GetAttribute("WakeSeconds") :: number?) or 5
			if not wakeAt then
				continue
			end
			local left = math.max(0, wakeAt - now)
			local mine = blanket:GetAttribute("Owner") == me.UserId
			w.label.Text = if left > 0
				then string.format("Waking up... %d", math.ceil(left))
				elseif mine then "READY! Hold E"
				else "READY!"
			w.fill.Size = UDim2.fromScale(math.clamp(1 - left / total, 0, 1), 1)
			if left <= 0 then
				-- ready: a slow, happy wiggle until it's hatched
				blanket:PivotTo(
					w.rest
						* CFrame.new(0, math.abs(math.sin(now * 3)) * 0.5, 0)
						* CFrame.Angles(0, 0, math.sin(now * 6) * 0.06)
				)
			elseif left < 1.5 then
				local k = (1.5 - left) / 1.5
				blanket:PivotTo(
					w.rest
						* CFrame.new(0, math.abs(math.sin(now * 30)) * 0.6 * k, 0)
						* CFrame.Angles(0, 0, math.sin(now * 40) * 0.12 * k)
				)
			end
		end
	end)

	-- Settings: Hide Players makes everyone else see-through on your screen; Performance Mode switches off particles
	local hidden = false
	local performance = false
	local function setParticles(on: boolean)
		for _, d in Workspace:GetDescendants() do
			if d:IsA("ParticleEmitter") or d:IsA("Sparkles") or d:IsA("Trail") then
				if not on then
					d:SetAttribute("WasEnabled", d.Enabled)
					d.Enabled = false
				elseif d:GetAttribute("WasEnabled") ~= nil then
					d.Enabled = d:GetAttribute("WasEnabled") == true
					d:SetAttribute("WasEnabled", nil)
				end
			end
		end
	end
	Workspace.DescendantAdded:Connect(function(d)
		if performance and (d:IsA("ParticleEmitter") or d:IsA("Sparkles") or d:IsA("Trail")) then
			d:SetAttribute("WasEnabled", d.Enabled)
			d.Enabled = false
		end
	end)
	me:GetAttributeChangedSignal("SettingPerformanceMode"):Connect(function()
		performance = me:GetAttribute("SettingPerformanceMode") == true
		setParticles(not performance)
	end)
	RunService.Heartbeat:Connect(function()
		local hide = me:GetAttribute("SettingHidePlayers") == true
		if not hide and not hidden then
			return
		end
		hidden = hide
		for _, other in Players:GetPlayers() do
			if other ~= me and other.Character then
				for _, d in other.Character:GetDescendants() do
					if d:IsA("BasePart") or d:IsA("Decal") then
						d.LocalTransparencyModifier = if hide then 1 else 0
					end
				end
			end
		end
	end)
end

return GameView
