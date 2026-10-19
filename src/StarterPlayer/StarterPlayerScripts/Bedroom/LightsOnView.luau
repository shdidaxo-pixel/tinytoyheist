--!strict
-- The lights-on danger phase on each screen (the server runs it: Giant, Cat, RCCar):
--   Warning (Kid Stirring): a big "LIGHTS ON!" slams in with "HIDE!" and a countdown to when he gets up, ticking.
--   Lights on (Awake): a red "LIGHTS ON 0:45" timer at the top; his eyes: a beam from his head to a spot on the
--     floor that darts round the room (GazeAt), yellow while he's looking, red as it locks on someone (GazeLock).
--     Whoever he's watching gets a red "!" over their head; if it's you, "HE SEES YOU! RUN!" and a bar filling up.
--   Lights out (BackToBed): "LIGHTS OUT" and the timer goes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")

local LightsOnView = {}

local YELLOW = Color3.fromRGB(255, 212, 59)
local RED = Color3.fromRGB(232, 32, 46)
local INK = Color3.fromRGB(20, 16, 24)

-- The VFX session's effects library, if it's there
local VFX: any = nil
task.spawn(function()
	local m = Shared:WaitForChild("VFX", 30)
	if m and m:IsA("ModuleScript") then
		local ok, lib = pcall(require, m)
		if ok then
			VFX = lib
		end
	end
end)

local function label(parent: Instance, text: string, size: number, color: Color3, y: number): TextLabel
	local t = Instance.new("TextLabel")
	t.AnchorPoint = Vector2.new(0.5, 0.5)
	t.Position = UDim2.new(0.5, 0, 0, y)
	t.Size = UDim2.fromOffset(900, size)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.FredokaOne
	t.Text = text
	t.TextSize = size
	t.TextColor3 = color
	local s = Instance.new("UIStroke")
	s.Color = INK
	s.Thickness = math.max(2, size / 14)
	s.Parent = t
	t.Parent = parent
	return t
end

function LightsOnView.start(bedroom: Model)
	local kid = bedroom:WaitForChild("GiantKid")
	local player = Players.LocalPlayer
	local Sounds: any = nil
	task.spawn(function()
		local ok, lib = pcall(require, script.Parent:WaitForChild("Sounds", 10) :: ModuleScript)
		if ok then
			Sounds = lib
		end
	end)
	local function sound(name: string, opts: any?)
		if Sounds then
			pcall(Sounds.play, name, nil, opts)
		end
	end

	---------------------------------------------------------------------------------------------------------------
	-- The screen: the warning banner, the timer, "HE SEES YOU"
	local gui = Instance.new("ScreenGui")
	gui.Name = "LightsOn"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 15
	gui.Parent = player:WaitForChild("PlayerGui")
	local scale = Instance.new("UIScale")
	scale.Parent = gui
	local function fit()
		local cam = Workspace.CurrentCamera
		local size = if cam then cam.ViewportSize else Vector2.new(1280, 720)
		scale.Scale = math.clamp(math.min(size.X / 1280, size.Y / 720), 0.45, 1.4)
	end
	fit()
	if Workspace.CurrentCamera then
		Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end
	-- everything sits in a 1280-wide frame centred at the top, so UIScale keeps it in place
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.fromScale(0.5, 0)
	frame.Size = UDim2.fromOffset(1280, 720)
	frame.BackgroundTransparency = 1
	frame.Parent = gui

	local banner = Instance.new("Frame")
	banner.AnchorPoint = Vector2.new(0.5, 0.5)
	banner.Position = UDim2.new(0.5, 0, 0, 250)
	banner.Size = UDim2.fromOffset(900, 200)
	banner.BackgroundTransparency = 1
	banner.Visible = false
	banner.Parent = frame
	local bannerScale = Instance.new("UIScale")
	bannerScale.Parent = banner
	local title = label(banner, "LIGHTS ON!", 104, YELLOW, 60)
	local sub = label(banner, "HIDE!", 44, Color3.new(1, 1, 1), 150)

	local timer = Instance.new("Frame")
	timer.AnchorPoint = Vector2.new(0.5, 0)
	timer.Position = UDim2.new(0.5, 0, 0, 132)
	timer.Size = UDim2.fromOffset(300, 54)
	timer.BackgroundColor3 = RED
	timer.Visible = false
	timer.Parent = frame
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = timer
	local edge = Instance.new("UIStroke")
	edge.Color = Color3.fromRGB(78, 6, 16)
	edge.Thickness = 4
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Parent = timer
	local timerText = label(timer, "LIGHTS ON 0:45", 34, Color3.new(1, 1, 1), 27)
	timerText.Size = UDim2.fromOffset(300, 54)
	local timerSub = label(timer, "Stay in the safe ring!", 22, YELLOW, 72)
	timerSub.Size = UDim2.fromOffset(400, 26)

	local seen = Instance.new("Frame")
	seen.AnchorPoint = Vector2.new(0.5, 0.5)
	seen.Position = UDim2.new(0.5, 0, 0, 330)
	seen.Size = UDim2.fromOffset(520, 120)
	seen.BackgroundTransparency = 1
	seen.Visible = false
	seen.Parent = frame
	local seenText = label(seen, "HE SEES YOU! RUN!", 64, RED, 36)
	seenText.TextColor3 = Color3.fromRGB(255, 70, 80)
	local bar = Instance.new("Frame")
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.new(0.5, 0, 0, 80)
	bar.Size = UDim2.fromOffset(360, 20)
	bar.BackgroundColor3 = INK
	bar.Parent = seen
	local barCorner = corner:Clone()
	barCorner.CornerRadius = UDim.new(0.5, 0)
	barCorner.Parent = bar
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = RED
	fill.Parent = bar
	barCorner:Clone().Parent = fill

	local function slam(text: string, subText: string, color: Color3)
		title.Text = text
		title.TextColor3 = color
		sub.Text = subText
		banner.Visible = true
		bannerScale.Scale = 2.2
		title.TextTransparency, sub.TextTransparency = 0, 0
		TweenService:Create(bannerScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1,
		}):Play()
	end
	local function hideBanner(after: number)
		local shown = title.Text
		task.delay(after, function()
			if title.Text ~= shown then
				return
			end
			local info = TweenInfo.new(0.4)
			TweenService:Create(title, info, { TextTransparency = 1 }):Play()
			TweenService:Create(sub, info, { TextTransparency = 1 }):Play()
			task.delay(0.4, function()
				if title.Text == shown then
					banner.Visible = false
				end
			end)
		end)
	end

	local lastState = kid:GetAttribute("State")
	local function onState()
		local state = kid:GetAttribute("State")
		if state == lastState then
			return
		end
		local was = lastState
		lastState = state
		if state == "Stirring" then
			slam("LIGHTS ON!", "HIDE!", YELLOW)
			if VFX then
				pcall(VFX.shake, 0.35, 0.5)
			end
		elseif state == "Awake" then
			slam("HE'S UP!", "Get to the safe ring, or hide behind something big!", Color3.fromRGB(255, 90, 90))
			hideBanner(2.5)
		elseif was == "Awake" or was == "Stirring" then
			slam("LIGHTS OUT", "Go go go!", Color3.fromRGB(120, 230, 255))
			hideBanner(2)
		end
	end
	kid:GetAttributeChangedSignal("State"):Connect(onState)

	---------------------------------------------------------------------------------------------------------------
	-- His eyes in the world: a disc on the floor and a beam to it from his head
	local holder = Instance.new("Folder")
	holder.Name = "KidEyes"
	holder.Parent = Workspace.CurrentCamera or Workspace
	local radius = (kid:GetAttribute("GazeRadius") :: number?) or 14
	local disc = Instance.new("Part")
	disc.Name = "GazeSpot"
	disc.Anchored = true
	disc.CanCollide, disc.CanQuery, disc.CanTouch = false, false, false
	disc.CastShadow = false
	disc.Shape = Enum.PartType.Cylinder
	disc.Material = Enum.Material.Neon
	disc.Color = YELLOW
	disc.Transparency = 1
	disc.Size = Vector3.new(0.3, radius * 2, radius * 2)
	disc.Parent = holder
	local ring = disc:Clone()
	ring.Name = "GazeRing"
	ring.Size = Vector3.new(0.2, radius * 2 + 2, radius * 2 + 2)
	ring.Parent = holder
	local floorAt = Instance.new("Attachment")
	floorAt.Parent = disc
	local beam = Instance.new("Beam")
	beam.Attachment1 = floorAt
	beam.FaceCamera = true
	beam.LightEmission = 0.6
	beam.LightInfluence = 0
	beam.Segments = 1
	beam.Width0 = 2
	beam.Width1 = radius * 2
	beam.Color = ColorSequence.new(YELLOW)
	beam.Transparency = NumberSequence.new(0.75, 0.55)
	beam.Enabled = false
	beam.Parent = disc
	local eyeAt: Attachment? = nil
	local function headAttachment(): Attachment?
		if eyeAt and eyeAt.Parent then
			return eyeAt
		end
		local walker = kid:FindFirstChild("Walker")
		local head = walker and walker:FindFirstChild("Head")
		if head and head:IsA("BasePart") then
			local a = Instance.new("Attachment")
			a.Name = "Eyes"
			a.Position = Vector3.new(0, 0, -head.Size.Z * 0.3)
			a.Parent = head
			eyeAt = a
			beam.Attachment0 = a
		end
		return eyeAt
	end

	-- a red "!" over whoever he's watching
	local bang = Instance.new("BillboardGui")
	bang.Name = "KidSeesYou"
	bang.Size = UDim2.fromOffset(60, 60)
	bang.StudsOffsetWorldSpace = Vector3.new(0, 5, 0)
	bang.AlwaysOnTop = true
	bang.LightInfluence = 0
	bang.Enabled = false
	bang.Parent = holder
	local bangText = label(bang, "!", 56, Color3.fromRGB(255, 70, 80), 30)
	bangText.Size = UDim2.fromScale(1, 1)

	---------------------------------------------------------------------------------------------------------------
	-- The cat's bite (Cat.luau, the CatBite moment): everyone sees CHOMP at the cat, the whoosh and the landing;
	-- the bitten mouse's own screen holds it in the cat's mouth, shaking, then flies it in an arc to where it lands.
	local catModel = bedroom:WaitForChild("Hazards"):WaitForChild("Cat")
	local function mouth(): CFrame
		local head = catModel:FindFirstChild("Head") :: BasePart?
		if not head then
			return (catModel :: any):GetPivot()
		end
		-- the cat faces its local +X; the mouth is at the front of the head, a little low
		return head.CFrame * CFrame.new(head.Size.X * 0.55, -head.Size.Y * 0.2, 0)
	end
	local function onBite(data: any)
		if typeof(data) ~= "table" or typeof(data.landing) ~= "Vector3" then
			return
		end
		local bite, flight = tonumber(data.bite) or 0.6, tonumber(data.flight) or 1
		local landing: Vector3 = data.landing
		local height = tonumber(data.height) or 40
		local victim = Players:GetPlayerByUserId(tonumber(data.victim) or 0)
		local at = mouth().Position
		if Sounds then
			pcall(Sounds.play, "Snap", at, { pitch = 0.7 })
			pcall(Sounds.play, "Hiss", at)
		end
		if VFX then
			pcall(VFX.popText, "CHOMP!", at + Vector3.new(0, 6, 0), {
				color = Color3.fromRGB(255, 140, 40),
				size = 46,
				duration = 1,
			})
			pcall(VFX.burst, "Poof", at, { scale = 1.6 })
		end
		task.delay(bite, function()
			if Sounds then
				pcall(Sounds.play, "Pounce", mouth().Position, { pitch = 0.8 })
			end
		end)
		task.delay(bite + flight, function()
			if Sounds then
				pcall(Sounds.play, "Thud", landing, { volume = 0.9 })
			end
			if VFX then
				pcall(VFX.burst, "Poof", landing, { scale = 2.5 })
				pcall(VFX.burst, "Shockwave", landing, { scale = 1.4 })
			end
		end)
		if victim ~= player then
			return
		end
		-- it's me: in the mouth, shaking; then the throw
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			return
		end
		if VFX then
			pcall(VFX.shake, 0.5, bite)
			pcall(VFX.flash, Color3.fromRGB(255, 140, 40), 0.3, 0.3)
		end
		local started = os.clock()
		local from: Vector3? = nil
		local spinAxis = Vector3.new(math.random() - 0.5, 0.2, math.random() - 0.5)
		local connection: RBXScriptConnection
		connection = RunService.RenderStepped:Connect(function()
			local t = os.clock() - started
			if not root.Parent then
				connection:Disconnect()
				return
			end
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
			if t < bite then
				-- dangling from its mouth, shaken side to side
				local m = mouth()
				root.CFrame = m
					* CFrame.new(0, -1, math.sin(t * 38) * 1.4)
					* CFrame.Angles(math.sin(t * 38) * 0.6, 0, math.pi / 2)
			elseif t < bite + flight then
				from = from or root.Position
				local u = (t - bite) / flight
				local p = (from :: Vector3):Lerp(landing + Vector3.new(0, 3, 0), u)
					+ Vector3.new(0, height * 4 * u * (1 - u), 0)
				root.CFrame = CFrame.new(p) * CFrame.fromAxisAngle(spinAxis.Unit, u * 4 * math.pi)
			else
				root.CFrame = CFrame.new(landing + Vector3.new(0, 3, 0))
				connection:Disconnect()
				if VFX then
					pcall(VFX.shake, 0.45, 0.35)
				end
			end
		end)
	end
	task.spawn(function()
		local m = Shared:WaitForChild("VFX", 30)
		local bus = m and m:WaitForChild("Moments", 10)
		if bus and bus:IsA("ModuleScript") then
			local ok, Moments = pcall(require, bus)
			if ok then
				(Moments :: any).on("CatBite", onBite)
			end
		end
	end)

	local shown = Vector3.zero
	local wasWatched = false
	local lastTick = -1
	RunService.RenderStepped:Connect(function(dt)
		local state = kid:GetAttribute("State")
		local t = Workspace:GetServerTimeNow()
		local left = math.max(0, ((kid:GetAttribute("StateEndsAt") :: number?) or t) - t)

		-- the warning countdown and the lights-on timer
		if state == "Stirring" then
			banner.Visible = true
			sub.Text = string.format("HIDE!  He gets up in %d", math.ceil(left))
			local secs = math.ceil(left)
			if secs ~= lastTick and secs <= 10 and secs > 0 then
				lastTick = secs
				sound("Click", { pitch = if secs <= 3 then 1.2 else 0.8, volume = 0.6 })
				if secs <= 3 then
					bannerScale.Scale = 1.15
					TweenService:Create(bannerScale, TweenInfo.new(0.25), { Scale = 1 }):Play()
				end
			end
		end
		timer.Visible = state == "Awake"
		if state == "Awake" then
			local secs = math.ceil(left)
			timerText.Text = string.format("LIGHTS ON %d:%02d", secs // 60, secs % 60)
			local pulse = 0.5 + 0.5 * math.sin(os.clock() * 6)
			timer.BackgroundColor3 = RED:Lerp(Color3.fromRGB(150, 10, 24), pulse)
			timerSub.Text = if secs <= 5 then "Lights out in a moment..." else "Stay in the safe ring!"
		end

		-- his eyes
		local on = kid:GetAttribute("Gaze") == true
		local at = kid:GetAttribute("GazeAt")
		local lock = (kid:GetAttribute("GazeLock") :: number?) or 0
		local target = (kid:GetAttribute("GazeTarget") :: number?) or 0
		if on and typeof(at) == "Vector3" then
			if disc.Transparency >= 1 then
				shown = at
			end
			shown = shown:Lerp(at, 1 - math.exp(-dt * 14))
			local color = if target ~= 0 then Color3.fromRGB(255, 140, 40):Lerp(RED, lock) else YELLOW
			local flicker = if target ~= 0 then 0.1 * math.sin(os.clock() * (10 + 30 * lock)) else 0
			disc.CFrame = CFrame.new(shown + Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, 0, math.pi / 2)
			ring.CFrame = disc.CFrame * CFrame.new(-0.05, 0, 0)
			disc.Color, ring.Color = color, color
			disc.Transparency = 0.72 - 0.25 * lock + flicker
			ring.Transparency = 0.45
			beam.Color = ColorSequence.new(color)
			beam.Enabled = headAttachment() ~= nil
		else
			disc.Transparency, ring.Transparency = 1, 1
			beam.Enabled = false
		end

		-- who he's watching
		local watched = if target ~= 0 then Players:GetPlayerByUserId(target) else nil
		local head = watched and watched.Character and watched.Character:FindFirstChild("Head")
		bang.Adornee = head
		bang.Enabled = on and head ~= nil
		if bang.Enabled then
			bangText.TextSize = 48 + 20 * lock + 6 * math.sin(os.clock() * 20)
		end
		local me = on and watched == player
		seen.Visible = me
		if me then
			fill.Size = UDim2.fromScale(lock, 1)
			seenText.Rotation = math.sin(os.clock() * 30) * 2
			if not wasWatched then
				sound("NoticeWarn", { volume = 0.8 })
				if VFX then
					pcall(VFX.flash, RED, 0.25, 0.25)
					pcall(VFX.shake, 0.2, 0.3)
				end
			end
		end
		wasWatched = me
	end)
end

return LightsOnView
