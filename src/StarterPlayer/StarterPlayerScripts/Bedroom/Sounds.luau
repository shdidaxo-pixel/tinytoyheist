--!strict
-- The bedroom's sounds, all played on this client from what the server already shares (attributes and remotes):
-- the train's wind-up chug and whistle, creaking boards, squeaky ducks, a trap's snap, the cat's hiss as it pounces,
-- the light switch when the Kid wakes, his footsteps when he walks, a rustle when you grab a toy, a chime when you
-- bank one and a thud when you're knocked over. Free Creator Store audio (mostly Pro Sound Effects).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Sounds = {}

Sounds.IDS = {
	TrainLoop = 9120225625, -- toy wind-up, running
	Whistle = 9120223157, -- toy train whistle
	Creak = 9125563505, -- wood floorboard creak
	Squeak = 9125994570, -- squeeze toy
	Snap = 9119057452, -- small sharp snap
	Hiss = 71522230632243, -- cat hiss
	Switch = 9125609743, -- light switch click
	Stomp = 9113525391, -- heavy body impact
	Rustle = 9114883390, -- cloth
	Chime = 4612374036, -- pickup bling
	Thud = 9113525643, -- body impact
}

local function make(parent: Instance, name: string, volume: number, range: number?): Sound
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = "rbxassetid://" .. Sounds.IDS[name]
	s.Volume = volume
	if range then
		s.RollOffMode = Enum.RollOffMode.InverseTapered
		s.RollOffMinDistance = range * 0.15
		s.RollOffMaxDistance = range
	end
	s.Parent = parent
	return s
end

-- Play a one-shot at a part (3D) or flat (2D) without cutting off the last one
local function play(template: Sound, at: BasePart?)
	local s = template:Clone()
	s.Parent = at or template.Parent
	s.PlaybackSpeed = template.PlaybackSpeed * (0.94 + math.random() * 0.12)
	s:Play()
	s.Ended:Once(function()
		s:Destroy()
	end)
	task.delay(10, function()
		if s.Parent then
			s:Destroy()
		end
	end)
end

function Sounds.start(bedroom: Model)
	local player = Players.LocalPlayer
	local flat = Instance.new("Folder")
	flat.Name = "BedroomSounds"
	flat.Parent = SoundService
	local switch = make(flat, "Switch", 0.8)
	local rustle = make(flat, "Rustle", 0.7)
	local chime = make(flat, "Chime", 0.6)
	local thud = make(flat, "Thud", 0.8)

	-- the train: a chug that follows the engine, and a whistle every so often
	local engine = bedroom:WaitForChild("Train"):WaitForChild("Cars"):WaitForChild("Car1")
	local engineRoot = (engine :: Model).PrimaryPart :: BasePart
	local loop = make(engineRoot, "TrainLoop", 0.6, 260)
	loop.Looped = true
	loop:Play()
	local whistle = make(engineRoot, "Whistle", 0.9, 420)
	task.spawn(function()
		while engineRoot.Parent do
			task.wait(9 + math.random() * 8)
			play(whistle, engineRoot)
		end
	end)

	-- hazards going off
	local hazards = bedroom:WaitForChild("Hazards")
	local function onFired(folderName: string, soundName: string, volume: number)
		for _, model in hazards:WaitForChild(folderName):GetChildren() do
			local at = (model :: Model).PrimaryPart
			if at then
				local template = make(at, soundName, volume, 220)
				model:GetAttributeChangedSignal("Fired"):Connect(function()
					play(template, at)
				end)
			end
		end
	end
	onFired("LooseBoards", "Creak", 1)
	onFired("Ducks", "Squeak", 0.9)
	onFired("Traps", "Snap", 1)
	-- the cat hisses as it pounces
	local cat = hazards:WaitForChild("Cat") :: Model
	local hiss = make(cat:WaitForChild("Head"), "Hiss", 0.9, 300)
	cat:GetAttributeChangedSignal("State"):Connect(function()
		if cat:GetAttribute("State") == "Pounce" then
			play(hiss, cat:FindFirstChild("Head") :: BasePart)
		end
	end)

	-- the Kid: the light switch, and footsteps while he walks
	local kid = bedroom:WaitForChild("GiantKid")
	local lastState = kid:GetAttribute("State")
	kid:GetAttributeChangedSignal("State"):Connect(function()
		local state = kid:GetAttribute("State")
		local wasOn = lastState == "Stirring" or lastState == "Awake"
		local isOn = state == "Stirring" or state == "Awake"
		if wasOn ~= isOn then
			play(switch)
		end
		lastState = state
	end)
	local walkerRoot = (kid:WaitForChild("Walker") :: Model).PrimaryPart :: BasePart
	local stomp = make(walkerRoot, "Stomp", 1, 500)
	task.spawn(function()
		while walkerRoot.Parent do
			task.wait(0.75)
			if kid:GetAttribute("Walking") then
				play(stomp, walkerRoot)
			end
		end
	end)

	-- you: grabbing, banking, getting knocked over
	player:GetAttributeChangedSignal("Carrying"):Connect(function()
		if player:GetAttribute("Carrying") then
			play(rustle)
		end
	end)
	local remotes = ReplicatedStorage:WaitForChild("BedroomRemotes");
	(remotes:WaitForChild("Notice") :: RemoteEvent).OnClientEvent:Connect(function(_text: string, kind: string?)
		if kind ~= "warn" then
			play(chime)
		end
	end);
	(remotes:WaitForChild("Knocked") :: RemoteEvent).OnClientEvent:Connect(function()
		play(thud)
	end)
end

return Sounds
