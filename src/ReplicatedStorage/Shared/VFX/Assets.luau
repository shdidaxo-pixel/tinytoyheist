--!strict
-- Every VFX texture in one place. Sources: design/vfx/ (make_sprites.py, render_coin.py -> design/vfx/out/*.png).
-- Until a texture is uploaded (id = ""), Studio uses the local copy in its content folder (TTHVFX1, copied from
-- design/vfx/out/), which only works in Studio. Before launch: upload each PNG and paste its rbxassetid here.
-- sheet = a 4x4 flipbook (1024 px, 16 frames of 256).
local LOCAL = "rbxasset://textures/TTHVFX1/" -- bump the folder name when pictures change; Studio caches by path

export type Tex = { id: string, file: string, sheet: boolean }

local Assets: { [string]: Tex } = {
	Glow = { id = "", file = "glow", sheet = false },
	Sparkle = { id = "", file = "sparkle", sheet = false },
	Ring = { id = "", file = "ring", sheet = false },
	Star = { id = "", file = "star", sheet = false },
	Bubble = { id = "", file = "bubble", sheet = false },
	Snowflake = { id = "", file = "snowflake", sheet = false },
	Heart = { id = "", file = "heart", sheet = false },
	Beam = { id = "", file = "beam", sheet = false },
	Vignette = { id = "", file = "vignette", sheet = false },
	Rays = { id = "", file = "rays", sheet = false },
	Burst = { id = "", file = "burst_sheet", sheet = true },
	Shock = { id = "", file = "shock_sheet", sheet = true },
	Puff = { id = "", file = "puff_sheet", sheet = true },
	Flame = { id = "", file = "flame_sheet", sheet = true },
	Electric = { id = "", file = "electric_sheet", sheet = true },
	Swirl = { id = "", file = "swirl_sheet", sheet = true },
	Twinkle = { id = "", file = "twinkle_sheet", sheet = true },
	Coin = { id = "", file = "coin_sheet", sheet = true },
}

-- The texture to use for `name` (the uploaded id, or the local Studio copy).
local function get(name: string): string
	local t = Assets[name]
	if not t then
		return ""
	end
	return if t.id ~= "" then t.id else LOCAL .. t.file .. ".png"
end

return {
	list = Assets,
	get = get,
	isSheet = function(name: string): boolean
		local t = Assets[name]
		return t ~= nil and t.sheet
	end,
}
