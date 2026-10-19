--!strict
-- Every VFX texture in one place. Sources: design/vfx/ (make_sprites.py, render_coin.py -> design/vfx/out/*.png).
-- All 18 uploaded to Roblox on 19 Oct 2026 (ids below). If one is changed: re-run the script, upload the PNG, paste
-- the new id. A texture with id = "" falls back to a local copy in Studio's content folder (TTHVFX1, copied from
-- design/vfx/out/), which only works in Studio.
-- sheet = a 4x4 flipbook (1024 px, 16 frames of 256).
local LOCAL = "rbxasset://textures/TTHVFX1/" -- bump the folder name when pictures change; Studio caches by path

export type Tex = { id: string, file: string, sheet: boolean }

local Assets: { [string]: Tex } = {
	Glow = { id = "rbxassetid://72877366263449", file = "glow", sheet = false },
	Sparkle = { id = "rbxassetid://136455414095107", file = "sparkle", sheet = false },
	Ring = { id = "rbxassetid://89689017966003", file = "ring", sheet = false },
	Star = { id = "rbxassetid://135264715373631", file = "star", sheet = false },
	Bubble = { id = "rbxassetid://105647494965781", file = "bubble", sheet = false },
	Snowflake = { id = "rbxassetid://97725261414409", file = "snowflake", sheet = false },
	Heart = { id = "rbxassetid://101053639513287", file = "heart", sheet = false },
	Beam = { id = "rbxassetid://85118885708483", file = "beam", sheet = false },
	Vignette = { id = "rbxassetid://94969580754753", file = "vignette", sheet = false },
	Rays = { id = "rbxassetid://135758243455516", file = "rays", sheet = false },
	Burst = { id = "rbxassetid://83067527071282", file = "burst_sheet", sheet = true },
	Shock = { id = "rbxassetid://79777786784253", file = "shock_sheet", sheet = true },
	Puff = { id = "rbxassetid://130192730600368", file = "puff_sheet", sheet = true },
	Flame = { id = "rbxassetid://105067568879274", file = "flame_sheet", sheet = true },
	Electric = { id = "rbxassetid://81482861421561", file = "electric_sheet", sheet = true },
	Swirl = { id = "rbxassetid://71402566903680", file = "swirl_sheet", sheet = true },
	Twinkle = { id = "rbxassetid://114540391758375", file = "twinkle_sheet", sheet = true },
	Coin = { id = "rbxassetid://101366042482832", file = "coin_sheet", sheet = true },
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
