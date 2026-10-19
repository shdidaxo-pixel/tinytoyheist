--!strict
-- A small button only Dylan sees (in Studio, or his account in a live server) that teleports him to the model
-- showcase (Workspace.Showcase, built by tools/bedroom/Showcase.luau) and back to where he was. While he's there the
-- showcase's Speed wheels spin; the toys animate by themselves (ToyAnimator).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local DYLAN = 7587099472 -- samrtly
local me = Players.LocalPlayer
if not RunService:IsStudio() and me.UserId ~= DYLAN then
	return
end

-- where the teleport lands: a little in front of the first row (matches Showcase.ARRIVE)
local ARRIVE = CFrame.lookAt(Vector3.new(4000, 4, -30), Vector3.new(4000, 4, 40))

local gui = Instance.new("ScreenGui")
gui.Name = "ShowcaseTeleport"
gui.ResetOnSpawn = false
gui.DisplayOrder = 5
local button = Instance.new("TextButton")
button.AnchorPoint = Vector2.new(1, 0) -- top right, under the menu icons
button.Position = UDim2.new(1, -12, 0, 132)
button.Size = UDim2.fromOffset(118, 34)
button.BackgroundColor3 = Color3.fromRGB(26, 20, 48)
button.BackgroundTransparency = 0.15
button.TextColor3 = Color3.fromRGB(255, 228, 120)
button.Font = Enum.Font.GothamBlack
button.TextSize = 15
button.Text = "SHOWCASE"
button.Parent = gui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = button
gui.Parent = me:WaitForChild("PlayerGui")

-- The showcase's wheels (they stream in once you're there, so look again every so often)
type Spinner = { model: Model, rest: CFrame, spin: number }
local wheels: { [Model]: Spinner } = {}
local function findWheels()
	local showcase = Workspace:FindFirstChild("Showcase")
	local folder = showcase and showcase:FindFirstChild("Wheels")
	if not folder then
		return
	end
	for _, d in folder:GetDescendants() do
		if d:IsA("Model") and d.Name == "Wheel" and d.PrimaryPart and not wheels[d] then
			local spin = d:GetAttribute("Spin")
			wheels[d] = { model = d, rest = d:GetPivot(), spin = if type(spin) == "number" then spin else 1.5 }
		end
	end
end

local back: CFrame? = nil
local busy = false
button.Activated:Connect(function()
	local character = me.Character
	if busy or not character or not character.PrimaryPart then
		return
	end
	busy = true
	if back then
		local home = back
		pcall(function()
			me:RequestStreamAroundAsync(home.Position)
		end)
		character:PivotTo(home)
		back = nil
		button.Text = "SHOWCASE"
	else
		back = character:GetPivot()
		pcall(function()
			me:RequestStreamAroundAsync(ARRIVE.Position)
		end)
		character:PivotTo(ARRIVE)
		button.Text = "BACK"
	end
	busy = false
end)

-- spin the wheels while you're there, like the homes' wheels
local angle, lookedAt = 0, 0
RunService.RenderStepped:Connect(function(dt)
	if not back then
		return
	end
	angle -= dt
	lookedAt -= dt
	if lookedAt <= 0 then
		lookedAt = 1
		findWheels()
	end
	for wheel, w in wheels do
		if wheel.Parent then
			wheel:PivotTo(w.rest * CFrame.Angles(angle * w.spin, 0, 0))
		else
			wheels[wheel] = nil
		end
	end
end)
