--!strict
-- The Kid's Bedroom lighting. Night (Dylan's photo 2: deep blue, warm pools at the lamp and the window, darks blue,
-- never black) is the default while the Kid sleeps; LightsOn (photo 1: warm, soft, pastel) is what the room turns
-- into when he wakes. apply(preset, seconds) switches to a preset, tweening when seconds > 0. The map builder applies
-- Night once; clients tween between the two when the Giant's State changes (lights on in about 0.4 s, back to night
-- over about 3 s).
--
-- Room lights are found by the LightRole attribute on their parts in Workspace.Bedroom (Lamp, Window, Monitor,
-- NightLight, Hallway, Ceiling, WindowStripe).

local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local BedroomLighting = {}

export type Preset = {
	name: string,
	clockTime: number, -- set at once (tweening it would swing the sun across the sky)
	lighting: { [string]: any },
	atmosphere: { [string]: any },
	colorCorrection: { [string]: any },
	bloom: { [string]: any },
	sunRays: { [string]: any },
	roles: { [string]: number }, -- brightness of each kind of room light
	ceiling: Color3,
	windowStripes: number, -- transparency of the streetlight stripes on the floor
}

BedroomLighting.Night = {
	name = "Night",
	clockTime = 14,
	lighting = {
		Brightness = 0.9,
		Ambient = Color3.fromRGB(104, 112, 162),
		OutdoorAmbient = Color3.fromRGB(100, 110, 166),
		ColorShift_Top = Color3.fromRGB(150, 170, 255),
		ColorShift_Bottom = Color3.fromRGB(30, 35, 80),
		EnvironmentDiffuseScale = 0.2,
		EnvironmentSpecularScale = 0.2,
		ExposureCompensation = 0.35,
	},
	atmosphere = {
		Density = 0.06,
		Offset = 0,
		Color = Color3.fromRGB(40, 46, 92),
		Decay = Color3.fromRGB(20, 26, 60),
		Glare = 0,
		Haze = 0,
	},
	colorCorrection = {
		TintColor = Color3.fromRGB(226, 232, 255),
		Saturation = 0.12,
		Contrast = 0.1,
		Brightness = 0,
	},
	bloom = { Intensity = 0.7, Size = 28, Threshold = 1.4 },
	sunRays = { Intensity = 0 },
	roles = { Lamp = 2.6, Window = 1.4, Monitor = 1, NightLight = 1.2, Hallway = 1.2 },
	ceiling = Color3.fromRGB(27, 33, 66),
	windowStripes = 0.9,
} :: Preset

BedroomLighting.LightsOn = {
	name = "LightsOn",
	clockTime = 14,
	lighting = {
		Brightness = 2.6,
		Ambient = Color3.fromRGB(170, 158, 140),
		OutdoorAmbient = Color3.fromRGB(180, 166, 146),
		ColorShift_Top = Color3.fromRGB(255, 228, 190),
		ColorShift_Bottom = Color3.fromRGB(140, 120, 100),
		EnvironmentDiffuseScale = 0.4,
		EnvironmentSpecularScale = 0.3,
		ExposureCompensation = 0.15,
	},
	atmosphere = {
		Density = 0.04,
		Offset = 0,
		Color = Color3.fromRGB(237, 227, 208),
		Decay = Color3.fromRGB(210, 190, 160),
		Glare = 0,
		Haze = 0,
	},
	colorCorrection = {
		TintColor = Color3.fromRGB(255, 246, 232),
		Saturation = 0.05,
		Contrast = 0.04,
		Brightness = 0.02,
	},
	bloom = { Intensity = 0.4, Size = 24, Threshold = 2 },
	sunRays = { Intensity = 0 },
	roles = { Lamp = 3, Window = 0.4, Monitor = 0.5, NightLight = 0.3, Hallway = 1.5 },
	ceiling = Color3.fromRGB(239, 232, 216),
	windowStripes = 1,
} :: Preset

local function effect(className: string, name: string): Instance
	local found = Lighting:FindFirstChild(name)
	if found and found.ClassName == className then
		return found
	end
	local made = Instance.new(className :: any)
	made.Name = name
	made.Parent = Lighting
	return made
end

local function set(target: Instance, props: { [string]: any }, seconds: number, style: Enum.EasingStyle)
	if seconds > 0 then
		TweenService:Create(target, TweenInfo.new(seconds, style, Enum.EasingDirection.Out), props):Play()
	else
		for key, value in props do
			(target :: any)[key] = value
		end
	end
end

-- Switch the room to a preset, tweening over `seconds` (0 = at once).
function BedroomLighting.apply(preset: Preset, seconds: number?)
	local t = seconds or 0
	local style = if preset.name == "LightsOn" then Enum.EasingStyle.Quad else Enum.EasingStyle.Sine
	-- the same high "sun" for both: tinted blue and dim it plays the moon, warm and bright the ceiling light. The
	-- ceiling casts no shadow, so it lights the room from above.
	Lighting.ClockTime = preset.clockTime
	Lighting.GeographicLatitude = 23.5
	Lighting.GlobalShadows = true
	set(Lighting, preset.lighting, t, style)
	set(effect("Atmosphere", "Atmosphere"), preset.atmosphere, t, style)
	set(effect("ColorCorrectionEffect", "BedroomColor"), preset.colorCorrection, t, style)
	set(effect("BloomEffect", "Bloom"), preset.bloom, t, style)
	set(effect("SunRaysEffect", "SunRays"), preset.sunRays, t, style)
	local bedroom = Workspace:FindFirstChild("Bedroom")
	if not bedroom then
		return
	end
	for _, p in bedroom:GetDescendants() do
		local role = p:GetAttribute("LightRole")
		if role == nil or not p:IsA("BasePart") then
			continue
		end
		if role == "Ceiling" then
			set(p, { Color = preset.ceiling }, t, style)
		elseif role == "WindowStripe" then
			set(p, { Transparency = preset.windowStripes }, t, style)
		else
			local brightness = preset.roles[role]
			if brightness then
				for _, light in p:GetChildren() do
					if light:IsA("Light") then
						set(light, { Brightness = brightness }, t, style)
					end
				end
			end
		end
	end
end

return BedroomLighting
