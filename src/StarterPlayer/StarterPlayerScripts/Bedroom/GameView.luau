--!strict
-- The game in the world, on each player's screen: the wake-up countdown over a banked blanket (it shakes just before
-- it pops), the reveal burst when a toy wakes up, a "$X/s" tag over every home's cash thimble, the Steal prompt
-- hidden on your own toys, and the run while you train Speed on your wheel (jump or move to stop).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig")) :: any
local ToyVFX = require(Shared:WaitForChild("Toys"):WaitForChild("ToyVFX")) :: any

local GameView = {}

local me = Players.LocalPlayer
local GOLD = Color3.fromRGB(255, 201, 60)
local INK = Color3.fromRGB(26, 20, 48)
local GREEN = Color3.fromRGB(91, 242, 90)

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

-- Only other people's toys can be stolen: hide the prompt on your own
local function hidePrompt(d: Instance, hole: Instance)
	if d:IsA("ProximityPrompt") and d.Name == "StealPrompt" then
		d.Enabled = hole:GetAttribute("Owner") ~= me.UserId
	end
end

local function watchHome(hole: Instance)
	local penToys = hole:WaitForChild("PenToys", 10)
	if penToys then
		penToys.ChildAdded:Connect(watchPenToy)
		penToys.DescendantAdded:Connect(function(d)
			hidePrompt(d, hole)
		end)
		for _, d in penToys:GetDescendants() do
			hidePrompt(d, hole)
		end
	end
	hole:GetAttributeChangedSignal("Owner"):Connect(function()
		if penToys then
			for _, d in penToys:GetDescendants() do
				hidePrompt(d, hole)
			end
		end
	end)
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
	-- the cash thimble's tag: what this home earns a second
	local pile = hole:WaitForChild("CashPile", 10) :: BasePart?
	if pile then
		local gui = Instance.new("BillboardGui")
		gui.Name = "IncomeTag"
		gui.Size = UDim2.fromOffset(120, 34)
		gui.StudsOffsetWorldSpace = Vector3.new(0, 8, 0)
		gui.LightInfluence = 0
		gui.MaxDistance = 140
		gui.Adornee = pile
		local label = textLabel(gui, "", GREEN, UDim2.fromScale(1, 1), UDim2.new())
		gui.Parent = pile
		local function refresh()
			local income = hole:GetAttribute("Income")
			local n = if typeof(income) == "number" then income else 0
			gui.Enabled = n > 0
			label.Text = "+" .. GameConfig.money(n) .. "/s"
		end
		hole:GetAttributeChangedSignal("Income"):Connect(refresh)
		refresh()
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

	local stop = ReplicatedStorage:WaitForChild("GameRemotes"):WaitForChild("StopTraining") :: RemoteEvent
	me:GetAttributeChangedSignal("Training"):Connect(training)
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
			w.label.Text = if left > 0 then string.format("Waking up... %d", math.ceil(left)) else "!!!"
			w.fill.Size = UDim2.fromScale(math.clamp(1 - left / total, 0, 1), 1)
			if left < 1.5 then
				local k = (1.5 - left) / 1.5
				blanket:PivotTo(
					w.rest
						* CFrame.new(0, math.abs(math.sin(now * 30)) * 0.6 * k, 0)
						* CFrame.Angles(0, 0, math.sin(now * 40) * 0.12 * k)
				)
			end
		end
	end)
end

return GameView
