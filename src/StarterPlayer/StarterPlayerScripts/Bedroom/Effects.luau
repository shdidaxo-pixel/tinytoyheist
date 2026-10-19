--!strict
-- What hazards feel like: getting knocked over (pushed, on the floor for a moment, a big message), noise ripples on
-- the floor (coloured by how loud), a trap snapping shut, a loose board bouncing, a duck squashing, a brick jiggling.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local VFX = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("VFX")) :: any
local Moments = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("VFX"):WaitForChild("Moments")) :: any

local Effects = {}

local player = Players.LocalPlayer

-- A big message in the middle of the screen
local function shout(text: string, color: Color3?)
	local gui = Instance.new("ScreenGui")
	gui.Name = "BedroomShout"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = player:WaitForChild("PlayerGui")
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.38)
	label.Size = UDim2.fromScale(0.7, 0.11)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = color or Color3.fromRGB(255, 77, 94)
	label.Text = text
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.Color = Color3.fromRGB(26, 20, 48)
	stroke.Parent = label
	local scale = Instance.new("UIScale")
	scale.Scale = 0.4
	scale.Parent = label
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
	task.delay(1.6, function()
		TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		TweenService:Create(stroke, TweenInfo.new(0.4), { Transparency = 1 }):Play()
		task.wait(0.45)
		gui:Destroy()
	end)
end

-- three stars circling over a knocked-down player's head
local function dizzy(character: Model, seconds: number)
	local head = character:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "Dizzy"
	gui.Size = UDim2.fromOffset(110, 50)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 2.2, 0)
	gui.LightInfluence = 0
	gui.Adornee = head
	gui.Parent = head
	local stars = {}
	for i = 1, 3 do
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.AnchorPoint = Vector2.new(0.5, 0.5)
		img.Size = UDim2.fromOffset(26, 26)
		img.Image = VFX.Assets.get("Star")
		img.ImageColor3 = Color3.fromRGB(255, 220, 80)
		img.Parent = gui
		stars[i] = img
	end
	VFX.animate(seconds, function(t)
		local a = os.clock() * 6
		for i, img in stars do
			local k = a + i * math.pi * 2 / 3
			img.Position = UDim2.new(0.5, math.cos(k) * 40, 0.5, math.sin(k) * 12)
			img.ZIndex = if math.sin(k) > 0 then 2 else 1
			img.Rotation = a * 40
			img.ImageTransparency = if t > 0.8 then (t - 0.8) / 0.2 else 0
		end
	end, function()
		gui:Destroy()
	end)
end

local function knocked(push: Vector3, stun: number, message: string)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root then
		return
	end
	shout(message)
	-- a jolt, a white flash, a dust puff, and stars going round your head while you're down
	VFX.shake(0.55, 0.45)
	VFX.flash(Color3.new(1, 1, 1), 0.45, 0.3)
	VFX.burst("Poof", root.Position - Vector3.new(0, 2.5, 0), { scale = 1.2 })
	dizzy(character, stun)
	Moments.fire("Knocked", { message = message })
	humanoid.PlatformStand = true
	root.AssemblyLinearVelocity = push + Vector3.new(0, 38, 0)
	root.AssemblyAngularVelocity = Vector3.new(math.random() * 6 - 3, 0, math.random() * 6 - 3)
	task.delay(stun, function()
		if humanoid.Parent then
			humanoid.PlatformStand = false
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end)
end

-- A ring that spreads across the floor where a noise was made
local effects: Folder
local function ripple(position: Vector3, points: number)
	local color = if points >= 12
		then Color3.fromRGB(255, 77, 94)
		elseif points >= 6 then Color3.fromRGB(255, 154, 46)
		else Color3.fromRGB(255, 228, 120)
	local size = 10 + points * 4
	for k = 0, 1 do
		local ring = Instance.new("Part")
		ring.Anchored = true
		ring.CanCollide = false
		ring.CanQuery = false
		ring.CanTouch = false
		ring.CastShadow = false
		ring.Shape = Enum.PartType.Cylinder
		ring.Material = Enum.Material.Neon
		ring.Color = color
		ring.Transparency = 0.35
		ring.Size = Vector3.new(0.2, 2, 2)
		ring.CFrame = CFrame.new(position.X, 0.4 + k * 0.05, position.Z) * CFrame.Angles(0, 0, math.pi / 2)
		ring.Parent = effects
		local info = TweenInfo.new(0.9 + k * 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, k * 0.15)
		TweenService:Create(ring, info, { Size = Vector3.new(0.2, size, size), Transparency = 1 }):Play()
		task.delay(1.5 + k * 0.3, function()
			ring:Destroy()
		end)
	end
end

-- Turn a group of parts about an axis through `hinge`, smoothly
local function swing(parts: { BasePart }, hinge: CFrame, angle: number, seconds: number)
	for _, p in parts do
		local relative = hinge:ToObjectSpace(p.CFrame)
		local value = Instance.new("NumberValue")
		value.Changed:Connect(function(a)
			p.CFrame = hinge * CFrame.Angles(0, 0, a) * relative
		end)
		local tween = TweenService:Create(value, TweenInfo.new(seconds, Enum.EasingStyle.Back), { Value = angle })
		tween.Completed:Connect(function()
			value:Destroy()
		end)
		tween:Play()
	end
end

local function watchHazards(hazards: Instance)
	-- traps: the bail swings over when it snaps, back when it re-arms
	for _, trap in hazards:WaitForChild("Traps"):GetChildren() do
		if not trap:IsA("Model") then
			continue
		end
		local base = trap.PrimaryPart :: BasePart
		local s = base.Size.X / 30 -- the trap was built 30 long, then shrunk with the room
		local hinge = base.CFrame * CFrame.new(6 * s, (2.8 - 1.2) * s, 0)
		local bail: { BasePart } = {}
		for _, p in trap:GetChildren() do
			if p:IsA("BasePart") and p.Name == "Bail" then
				table.insert(bail, p)
			end
		end
		local sprung = false
		trap:GetAttributeChangedSignal("Armed"):Connect(function()
			local armed = trap:GetAttribute("Armed") == true
			if armed == not sprung then
				return
			end
			sprung = not armed
			swing(bail, hinge, if sprung then -math.pi * 0.95 else 0, if sprung then 0.12 else 0.6)
		end)
	end
	-- boards, ducks and bricks wobble when they go off
	local function bounce(model: Instance, part: BasePart?, amount: CFrame)
		if not part then
			return
		end
		local rest = part.CFrame
		model:GetAttributeChangedSignal("Fired"):Connect(function()
			local value = Instance.new("NumberValue")
			value.Changed:Connect(function(a)
				part.CFrame = rest:Lerp(rest * amount, a)
			end)
			value.Value = 1
			local tween = TweenService:Create(value, TweenInfo.new(0.5, Enum.EasingStyle.Elastic), { Value = 0 })
			tween.Completed:Connect(function()
				value:Destroy()
				part.CFrame = rest
			end)
			tween:Play()
		end)
	end
	for _, board in hazards:WaitForChild("LooseBoards"):GetChildren() do
		bounce(board, board:FindFirstChild("Plank") :: BasePart?, CFrame.new(0, -0.8, 0) * CFrame.Angles(0, 0, -0.12))
	end
	for _, duck in hazards:WaitForChild("Ducks"):GetChildren() do
		bounce(duck, duck:FindFirstChild("Body") :: BasePart?, CFrame.new(0, -1.2, 0))
	end
	for _, brick in hazards:WaitForChild("Bricks"):GetChildren() do
		bounce(brick, brick:FindFirstChild("Body") :: BasePart?, CFrame.Angles(0, 0.15, 0))
	end
end

function Effects.start(bedroom: Model)
	effects = Instance.new("Folder")
	effects.Name = "BedroomEffects"
	effects.Parent = Workspace
	local remotes = ReplicatedStorage:WaitForChild("BedroomRemotes");
	(remotes:WaitForChild("Knocked") :: RemoteEvent).OnClientEvent:Connect(knocked);
	(remotes:WaitForChild("NoiseRipple") :: RemoteEvent).OnClientEvent:Connect(ripple);
	-- "Placed Teddy Knight in your home!" (green) or a warning (orange)
	(remotes:WaitForChild("Notice") :: RemoteEvent).OnClientEvent:Connect(function(text: string, kind: string?)
		shout(text, if kind == "warn" then Color3.fromRGB(255, 154, 46) else Color3.fromRGB(91, 227, 106))
	end)
	watchHazards(bedroom:WaitForChild("Hazards"))
end

return Effects
