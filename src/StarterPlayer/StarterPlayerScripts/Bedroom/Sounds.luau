--!strict
-- The game's sounds, all played on this client from what the server already shares (attributes and remotes), plus
-- the VFX session's Moments (Shared.VFX.Moments) once they exist. Ids and the mix live in SoundIds; footsteps, the
-- blanket drag and the wheel in Footsteps; the music in Music. Everything goes through two SoundGroups in
-- SoundService, "Music" and "SFX", which follow the Settings toggles (LocalPlayer attributes SettingMusic and
-- SettingSoundEffects).
--   Sounds.play(name, at?, opts?)  a one-shot; at = a BasePart / Attachment (3D, follows it) or a Vector3 (3D, fixed)
--                                  or nil (flat). opts { volume = x, pitch = x, delay = s }
--   Sounds.loop(name, parent?)     a looped Sound, not playing yet (the caller plays, stops and destroys it)
--   Sounds.duck(seconds, level?)   dip the music under a big moment

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local SoundIds = require(script.Parent:WaitForChild("SoundIds"))

local Sounds = {}
Sounds.IDS = SoundIds

local player = Players.LocalPlayer
local rng = Random.new()

local function group(name: string): SoundGroup
	local g = SoundService:FindFirstChild(name)
	if not (g and g:IsA("SoundGroup")) then
		g = Instance.new("SoundGroup")
		g.Name = name
		g.Volume = 1
		g.Parent = SoundService
	end
	return g :: SoundGroup
end
Sounds.Music = group("Music")
Sounds.SFX = group("SFX")
local musicLevel, duckLevel = 1, 1

local flat = Instance.new("Folder")
flat.Name = "TinyToyHeistSounds"
flat.Parent = SoundService

local function make(name: string, parent: Instance): Sound
	local d = SoundIds[name]
	assert(d, `no sound called {name}`)
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = "rbxassetid://" .. d.ids[rng:NextInteger(1, #d.ids)]
	s.Volume = d.volume
	s.PlaybackSpeed = d.pitch or 1
	s.SoundGroup = if d.group == "Music" then Sounds.Music else Sounds.SFX
	if d.range and not parent:IsDescendantOf(SoundService) then
		s.RollOffMode = Enum.RollOffMode.InverseTapered
		s.RollOffMinDistance = math.max(8, d.range * 0.15)
		s.RollOffMaxDistance = d.range
	end
	s.Parent = parent
	return s
end

function Sounds.play(
	name: string,
	at: (Instance | Vector3)?,
	opts: { volume: number?, pitch: number?, delay: number? }?
)
	local o = opts or {}
	local function go()
		local parent: Instance = flat
		local temp: Attachment? = nil
		if typeof(at) == "Vector3" then
			local a = Instance.new("Attachment")
			a.WorldPosition = at
			a.Parent = Workspace.Terrain
			parent, temp = a, a
		elseif typeof(at) == "Instance" and at.Parent then
			parent = at
		end
		local s = make(name, parent)
		s.Volume *= o.volume or 1
		s.PlaybackSpeed *= (o.pitch or 1) * rng:NextNumber(0.95, 1.05)
		s:Play()
		local function clean()
			if s.Parent then
				s:Destroy()
			end
			if temp and temp.Parent then
				temp:Destroy()
			end
		end
		s.Ended:Once(clean)
		task.delay(20, clean)
	end
	if o.delay and o.delay > 0 then
		task.delay(o.delay, go)
	else
		go()
	end
end

function Sounds.loop(name: string, parent: Instance?): Sound
	local s = make(name, parent or flat)
	s.Looped = true
	return s
end

-- true at most once per key in a window: the same moment can arrive from two places (a Moment and a Notice)
local lastAt: { [string]: number } = {}
function Sounds.once(key: string, seconds: number?): boolean
	local now = os.clock()
	if lastAt[key] and now - lastAt[key] < (seconds or 1) then
		return false
	end
	lastAt[key] = now
	return true
end
local function recent(key: string, seconds: number): boolean
	return lastAt[key] ~= nil and os.clock() - lastAt[key] < seconds
end

local function applyMusic(seconds: number)
	TweenService:Create(Sounds.Music, TweenInfo.new(seconds), { Volume = musicLevel * duckLevel }):Play()
end
local duckUntil = 0
function Sounds.duck(seconds: number, level: number?)
	duckUntil = math.max(duckUntil, os.clock() + seconds)
	duckLevel = level or 0.35
	applyMusic(0.25)
	task.delay(seconds, function()
		if os.clock() >= duckUntil - 0.01 then
			duckLevel = 1
			applyMusic(1.2)
		end
	end)
end

-- the Settings toggles (the HUD sets them; nil counts as on)
local function settings()
	local function follow(key: string, apply: (boolean) -> ())
		local function f()
			apply(player:GetAttribute(key) ~= false)
		end
		player:GetAttributeChangedSignal(key):Connect(f)
		f()
	end
	follow("SettingMusic", function(on)
		musicLevel = if on then 1 else 0
		applyMusic(0.4)
	end)
	follow("SettingSoundEffects", function(on)
		TweenService:Create(Sounds.SFX, TweenInfo.new(0.2), { Volume = if on then 1 else 0 }):Play()
	end)
end

local function primary(model: Instance): BasePart?
	if model:IsA("BasePart") then
		return model
	end
	if model:IsA("Model") and model.PrimaryPart then
		return model.PrimaryPart
	end
	return model:FindFirstChildWhichIsA("BasePart", true)
end

-- the Kid: snoring while asleep, stirring, the light switch and a sting when he wakes, the flashlight, his footsteps
local function kidSounds(bedroom: Model)
	local kid = bedroom:WaitForChild("GiantKid")
	local head = kid:FindFirstChild("Head", true) or primary(kid)
	local snore = Sounds.loop("Snore", head)
	local function asleep(state: any): boolean
		return state == "Asleep" or state == "BackToBed" or state == nil
	end
	local lastState = kid:GetAttribute("State")
	local function onState()
		local state = kid:GetAttribute("State")
		if asleep(state) and not snore.IsPlaying then
			snore:Play()
		elseif not asleep(state) and snore.IsPlaying then
			snore:Stop()
		end
		local wasOn = lastState == "Stirring" or lastState == "Awake"
		local isOn = state == "Stirring" or state == "Awake"
		if wasOn ~= isOn then
			Sounds.play("Switch")
		end
		if state == "Stirring" and lastState ~= "Stirring" then
			Sounds.play("KidStir", head)
			Sounds.play("KidSnort", head, { delay = 0.4 })
		elseif state == "Awake" and lastState ~= "Awake" then
			Sounds.play("KidWake")
			Sounds.duck(2.5, 0.5)
		end
		lastState = state
	end
	kid:GetAttributeChangedSignal("State"):Connect(onState)
	onState()
	kid:GetAttributeChangedSignal("Flashlight"):Connect(function()
		Sounds.play("Flashlight", head)
	end)
	local walker = kid:WaitForChild("Walker") :: Model
	task.spawn(function()
		while walker.Parent do
			task.wait(0.75)
			local root = walker.PrimaryPart
			if kid:GetAttribute("Walking") and root then
				Sounds.play("Stomp", root)
			end
		end
	end)
end

-- the train, the hazards going off, the cat
local function worldSounds(bedroom: Model)
	local engine = bedroom:WaitForChild("Train"):WaitForChild("Cars"):WaitForChild("Car1") :: Model
	local engineRoot = engine.PrimaryPart :: BasePart
	Sounds.loop("TrainLoop", engineRoot):Play()
	task.spawn(function()
		while engineRoot.Parent do
			task.wait(rng:NextNumber(9, 17))
			Sounds.play("Whistle", engineRoot)
		end
	end)

	local hazards = bedroom:WaitForChild("Hazards")
	local function onFired(folderName: string, soundName: string)
		for _, model in hazards:WaitForChild(folderName):GetChildren() do
			local at = primary(model)
			if at then
				model:GetAttributeChangedSignal("Fired"):Connect(function()
					Sounds.play(soundName, at)
				end)
			end
		end
	end
	onFired("LooseBoards", "Creak")
	onFired("Ducks", "Squeak")
	onFired("Traps", "Snap")

	local cat = hazards:WaitForChild("Cat") :: Model
	local catHead = cat:WaitForChild("Head") :: BasePart
	local catState = cat:GetAttribute("State")
	cat:GetAttributeChangedSignal("State"):Connect(function()
		local state = cat:GetAttribute("State")
		if state == "Pounce" then
			Sounds.play("Hiss", catHead)
			Sounds.play("Pounce", catHead, { delay = 0.15 })
		elseif state == "Stalk" and catState ~= "Stalk" then
			Sounds.play("Purr", catHead)
		end
		catState = state
	end)
	task.spawn(function()
		while cat.Parent do
			task.wait(if cat:GetAttribute("Aggressive") then rng:NextNumber(6, 12) else rng:NextNumber(14, 28))
			if catState == "Patrol" or catState == "Rest" then
				Sounds.play("Meow", catHead, { pitch = rng:NextNumber(0.9, 1.15) })
			end
		end
	end)
end

-- home padlocks clicking (anyone's, heard nearby)
local function lockSounds(bedroom: Model)
	for _, hole in bedroom:WaitForChild("Holes"):GetChildren() do
		hole:GetAttributeChangedSignal("Locked"):Connect(function()
			local button = hole:FindFirstChild("LockButton", true)
			local at = button and primary(button) or primary(hole)
			Sounds.play(if hole:GetAttribute("Locked") then "Lock" else "Unlock", at)
		end)
	end
end

-- very soft squeaks from toys roaming pens close to you
local SQUEAK_PITCH = { S = 1.35, M = 1.1, L = 0.9, G = 0.75 }
local function toySqueaks()
	task.spawn(function()
		while true do
			task.wait(rng:NextNumber(2.5, 5))
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				local near = {}
				for _, toy in CollectionService:GetTagged("TinyToy") do
					local at = toy:IsA("Model") and toy.PrimaryPart
					if at and toy:GetAttribute("Owner") and (at.Position - root.Position).Magnitude < 40 then
						table.insert(near, toy)
					end
				end
				if #near > 0 then
					local toy = near[rng:NextInteger(1, #near)] :: Model
					local pitch = SQUEAK_PITCH[toy:GetAttribute("Size") :: any] or 1
					Sounds.play("ToySqueak", toy.PrimaryPart, { pitch = pitch })
				end
			end
		end
	end)
end

-- the reveal: the riser while you hold E on a blanket, the blanket rustling while it shakes (VFX HatchCharge, longer
-- for rarer toys), then at the burst a pop and a stinger by rarity, with mutation and size stingers after
local BIG_RARITY = { Mythic = true, Secret = true }
local riser: Sound? = nil
local shake: Sound? = nil
local function fadeOut(s: Sound?)
	if s then
		TweenService:Create(s, TweenInfo.new(0.15), { Volume = 0 }):Play()
		task.delay(0.2, function()
			s:Destroy()
		end)
	end
end
local function stopRiser()
	fadeOut(riser)
	fadeOut(shake)
	riser, shake = nil, nil
end
local function hatchHold()
	if not Sounds.once("HatchHold", 0.3) then
		return
	end
	stopRiser()
	local r = make("HatchRise", flat)
	r:Play()
	riser = r
	task.delay(8, function()
		if riser == r then
			stopRiser()
		end
	end)
end
-- the build-up: restart the riser timed to end on the burst, and rustle the blanket faster and faster
local function hatchCharge(data: any)
	local seconds = math.max(0.3, type(data) == "table" and tonumber(data.seconds) or 1)
	local r = riser or make("HatchRise", flat)
	riser = r
	r.TimePosition = 0
	r.PlaybackSpeed = math.clamp(r.TimeLength / seconds, 0.8, 3)
	if not r.IsPlaying then
		r:Play()
	end
	fadeOut(shake)
	local s = Sounds.loop("HatchShake")
	s:Play()
	shake = s
	TweenService:Create(s, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		PlaybackSpeed = 1.6,
		Volume = s.Volume * 1.6,
	}):Play()
end
local function reveal(info: any)
	stopRiser()
	if not Sounds.once("Reveal", 0.5) then
		return
	end
	local rarity = if type(info) == "table" and type(info.rarity) == "string" then info.rarity else "Common"
	local name = "Reveal" .. rarity
	if not SoundIds[name] then
		name = "RevealCommon"
	end
	Sounds.play("HatchPop")
	Sounds.play(name, nil, { delay = 0.05 })
	if BIG_RARITY[rarity] then
		Sounds.play("RevealShimmer", nil, { delay = 0.1 })
		Sounds.duck(5, 0.25)
	elseif rarity == "Epic" or rarity == "Legendary" then
		Sounds.duck(3.5, 0.4)
	end
	local sizeMult = type(info) == "table" and tonumber(info.sizeMult) or 1
	if sizeMult and sizeMult >= 1.5 then
		Sounds.play("BigSize", nil, { delay = 0.35, pitch = math.clamp(1.6 / sizeMult, 0.6, 1.1) })
	end
	if type(info) == "table" and info.mutation then
		Sounds.play("Mutation", nil, { delay = 0.7 })
	end
end

-- money and levels, from the mirrored Player attributes
local function moneySounds()
	local cash = player:GetAttribute("Cash") :: number?
	local lastTick = 0
	player:GetAttributeChangedSignal("Cash"):Connect(function()
		local now = player:GetAttribute("Cash") :: number?
		if type(now) ~= "number" or type(cash) ~= "number" then
			cash = now
			return
		end
		local delta = now - cash
		cash = now
		local income = player:GetAttribute("Income") :: number? or 0
		if delta < 0 then
			Sounds.play("Purchase")
			Sounds.play("Register", nil, { delay = 0.05 })
		elseif delta > math.max(25, (income :: number) * 4) then
			Sounds.play("CashBig")
		elseif delta > 0 and os.clock() - lastTick > 5 then
			lastTick = os.clock()
			Sounds.play("CashTick")
		end
	end)
	local function levelUp(attr: string, sound: string)
		local last = player:GetAttribute(attr) :: number?
		player:GetAttributeChangedSignal(attr):Connect(function()
			local now = player:GetAttribute(attr) :: number?
			if type(now) == "number" and type(last) == "number" and now > last then
				Sounds.play(sound, nil, { delay = 0.15 })
				Sounds.duck(3, 0.4)
			end
			last = now
		end)
	end
	levelUp("HomeLevel", "HomeLevelUp")
	levelUp("WheelLevel", "WheelLevelUp")
end

-- rewards, from the profile copy the server sends (GameRemotes.Data)
local function rewardSounds(remotes: Instance)
	local streak: number? = nil
	local claimed: number? = nil
	local data = remotes:WaitForChild("Data") :: RemoteEvent
	data.OnClientEvent:Connect(function(p: any, m: any)
		local s = type(p) == "table" and type(p.Daily) == "table" and tonumber(p.Daily.Streak) or nil
		local c = type(m) == "table" and type(m.playtimeClaimed) == "table" and #m.playtimeClaimed or nil
		if s and streak and s > streak then
			Sounds.play("Daily")
			Sounds.duck(3, 0.4)
		elseif c and claimed and c > claimed then
			Sounds.play("Claim")
		end
		streak = s or streak
		claimed = c or claimed
	end)
end

-- raids: from the VFX Moments when they exist, and from the notices the server already sends
local function stealStart()
	if Sounds.once("StealStart") then
		Sounds.play("StealStart")
	end
end
local function robbed()
	if Sounds.once("Robbed", 2) then
		Sounds.play("Robbed")
		Sounds.duck(2, 0.5)
	end
end
local function stealBanked()
	if Sounds.once("StealSuccess") then
		Sounds.play("StealSuccess")
	end
end
local function recovered()
	if Sounds.once("Recovered") then
		Sounds.play("Recovered")
	end
end
local function notice(text: any, kind: any)
	if type(text) ~= "string" then
		return
	end
	if text:find("is stealing your", 1, true) then
		robbed()
	elseif text:find("Drag it to your home", 1, true) then
		stealStart()
	elseif text:find("You stole", 1, true) then
		stealBanked()
	elseif text:find("Got it back", 1, true) or text:find("+1 toy", 1, true) then
		recovered()
	elseif not recent("Reveal", 2) and Sounds.once("Notice", 0.8) then
		Sounds.play(if kind == "warn" then "NoticeWarn" else "NoticeGood")
	end
end
local momentsReady = false
local pendingReveal: any = nil
local function moments()
	local shared = ReplicatedStorage:WaitForChild("Shared")
	local vfx = shared:WaitForChild("VFX", 120)
	local module = vfx and vfx:WaitForChild("Moments", 30)
	if not (module and module:IsA("ModuleScript")) then
		return
	end
	local ok, Moments = pcall(require, module)
	if not ok or type(Moments) ~= "table" or type(Moments.on) ~= "function" then
		return
	end
	local me = player.UserId
	Moments.on("HatchHold", hatchHold)
	Moments.on("HatchCancel", stopRiser)
	Moments.on("HatchCharge", hatchCharge)
	Moments.on("HatchBurst", function(data: any)
		local info = pendingReveal or data
		pendingReveal = nil
		reveal(info)
	end)
	momentsReady = true
	Moments.on("StealStart", function(data: any)
		if type(data) == "table" and data.owner == me then
			robbed()
		else
			stealStart()
		end
	end)
	Moments.on("StealBanked", stealBanked)
	Moments.on("Recovered", recovered)
end

-- UI: a click on every button, a faint tick on hover over the UIKit ones, a swish as panels open and close
local function uiSounds()
	local gui = player:WaitForChild("PlayerGui")
	local function watch(d: Instance)
		if d:IsA("GuiButton") then
			d.Activated:Connect(function()
				if Sounds.once("Click", 0.06) then
					Sounds.play("Click")
				end
			end)
			if d.Name == "Hit" then
				d.MouseEnter:Connect(function()
					if Sounds.once("Hover", 0.08) then
						Sounds.play("Hover")
					end
				end)
			end
		elseif d:IsA("Frame") and d.Name == "Pop" and d.Parent and d.Parent:IsA("Frame") then
			local panel = d.Parent :: Frame
			panel:GetPropertyChangedSignal("Visible"):Connect(function()
				Sounds.play(if panel.Visible then "Open" else "Close")
			end)
		end
	end
	gui.DescendantAdded:Connect(watch)
	for _, d in gui:GetDescendants() do
		watch(d)
	end
end

function Sounds.start(bedroom: Model)
	settings()
	local remotes = ReplicatedStorage:WaitForChild("BedroomRemotes")
	local gameRemotes = ReplicatedStorage:WaitForChild("GameRemotes")

	for _, name in { "Music", "Footsteps" } do
		task.spawn(function()
			local ok, err = pcall(function()
				(require(script.Parent:WaitForChild(name)) :: any).start(bedroom, Sounds)
			end)
			if not ok then
				warn(`Sounds: {name} didn't start: {err}`)
			end
		end)
	end
	for _, f in { kidSounds, worldSounds, lockSounds } :: { (Model) -> () } do
		task.spawn(f, bedroom)
	end
	toySqueaks()
	moneySounds()
	task.spawn(rewardSounds, gameRemotes)
	task.spawn(uiSounds)
	task.spawn(moments)

	ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt)
		if prompt.Name == "HatchPrompt" then
			hatchHold()
		end
	end)
	local hatchedAt = 0
	ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt)
		if prompt.Name == "HatchPrompt" then
			task.delay(0.1, function()
				if os.clock() - hatchedAt > 0.5 then
					stopRiser() -- let go early
				end
			end)
		end
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt.Name == "HatchPrompt" then
			hatchedAt = os.clock()
		elseif prompt.Name == "StealPrompt" then
			stealStart()
		end
	end)
	local revealRemote = gameRemotes:WaitForChild("Reveal") :: RemoteEvent
	revealRemote.OnClientEvent:Connect(function(info: any)
		if not momentsReady then
			reveal(info)
			return
		end
		-- the VFX build-up runs first; the stinger waits for its HatchBurst (or plays anyway if that never comes)
		pendingReveal = info
		task.delay(4.5, function()
			if pendingReveal == info then
				pendingReveal = nil
				reveal(info)
			end
		end)
	end)
	player:GetAttributeChangedSignal("Carrying"):Connect(function()
		if player:GetAttribute("Carrying") then
			Sounds.play("Grab")
		end
	end)
	local noticeRemote = remotes:WaitForChild("Notice") :: RemoteEvent
	noticeRemote.OnClientEvent:Connect(notice)
	local knocked = remotes:WaitForChild("Knocked") :: RemoteEvent
	knocked.OnClientEvent:Connect(function(_push, _stun, message)
		if type(message) == "string" and message:find("Giant", 1, true) then
			Sounds.play("KidGrab")
		end
		Sounds.play("Thud", nil, { delay = 0.1 })
	end)
end

return Sounds
