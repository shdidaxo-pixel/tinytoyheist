--!strict
-- Every sound in the game: its asset id(s) and how it's mixed. All free Creator Store audio that any experience may
-- use: Pro Sound Effects and APM Music (Roblox's licensed libraries), Roblox's own UI set, and a few public uploads
-- (carpet steps, the cat's meow and hiss). The list with sources is in design/notes/sfx.md.
--   ids:    one or more; a one-shot picks one at random each time
--   volume: before the SFX / Music group (both at 1); one-shots also get a small random pitch
--   range:  3D sounds are heard out to this many studs (the map is scaled 0.65; a player is 5 studs tall)
--   pitch:  base PlaybackSpeed (default 1)
--   group:  "Music" or "SFX" (default)

export type Def = { ids: { number }, volume: number, range: number?, pitch: number?, group: string? }

local D: { [string]: Def } = {
	-- moving
	StepCarpet = {
		ids = { 91882016473062, 111131620367547, 73343053773763, 123224557798023, 92103616531947, 73871404556766 },
		volume = 0.35,
		range = 45,
	},
	StepWood = {
		ids = { 9120880067, 9120880314, 9120880402, 9120880564, 9120880575, 9120880755, 9120880810, 9120880063 },
		volume = 0.3,
		range = 55,
		pitch = 1.25,
	},
	StepCreak = { ids = { 9125563589, 9125563842, 9125563286 }, volume = 0.55, range = 70 },
	DragLoop = { ids = { 9113455185 }, volume = 0.4, range = 60 },

	-- toys
	Grab = { ids = { 9113455017, 9114883390 }, volume = 0.6, range = 60 },
	HatchRise = { ids = { 9119816546 }, volume = 0.45 },
	HatchShake = { ids = { 9113455185 }, volume = 0.3 }, -- the blanket shaking before the burst
	HatchPop = { ids = { 9117841338 }, volume = 0.6 },
	RevealCommon = { ids = { 9116394545 }, volume = 0.5 },
	RevealUncommon = { ids = { 9126073001 }, volume = 0.45 },
	RevealRare = { ids = { 125706237686412 }, volume = 0.5 },
	RevealEpic = { ids = { 9039420865 }, volume = 0.55 },
	RevealLegendary = { ids = { 1843982329 }, volume = 0.6 },
	RevealMythic = { ids = { 1841820743 }, volume = 0.65 },
	RevealSecret = { ids = { 1838007794 }, volume = 0.7 },
	RevealShimmer = { ids = { 9113122722 }, volume = 0.35 }, -- layered under Mythic and Secret
	Mutation = { ids = { 9125635649 }, volume = 0.5 },
	BigSize = { ids = { 1846544949 }, volume = 0.5 },
	ToySqueak = { ids = { 9125994570, 9125994387, 9125994553, 9114122864 }, volume = 0.12, range = 40 },

	-- money
	CashTick = { ids = { 9113849492 }, volume = 0.08, pitch = 1.3 },
	CashBig = { ids = { 9113849445 }, volume = 0.35 },
	Purchase = { ids = { 10066947742 }, volume = 0.5 },
	Register = { ids = { 9113728625 }, volume = 0.3 },
	HomeLevelUp = { ids = { 1841172671 }, volume = 0.55 },
	WheelLevelUp = { ids = { 9117887138 }, volume = 0.5 },
	WheelLoop = { ids = { 9120658690 }, volume = 0.18, range = 50 },

	-- raids
	StealStart = { ids = { 9120709480 }, volume = 0.5 },
	StealSuccess = { ids = { 1848287311 }, volume = 0.55 },
	Robbed = { ids = { 9119755443 }, volume = 0.3 },
	Recovered = { ids = { 9126073318 }, volume = 0.45 },
	Lock = { ids = { 9116176070 }, volume = 0.5, range = 70 },
	Unlock = { ids = { 9114142431 }, volume = 0.45, range = 70 },

	-- hazards
	Snore = { ids = { 9113862735 }, volume = 0.35, range = 260 },
	KidStir = { ids = { 9113383926 }, volume = 0.6, range = 400 },
	KidSnort = { ids = { 9119306551 }, volume = 0.5, range = 300, pitch = 0.8 },
	KidWake = { ids = { 1846887133 }, volume = 0.45 },
	Switch = { ids = { 9125609743 }, volume = 0.6 },
	Flashlight = { ids = { 9114479665 }, volume = 0.6, range = 400 },
	Stomp = { ids = { 9113525391 }, volume = 0.7, range = 420, pitch = 0.8 },
	KidGrab = { ids = { 9126014962 }, volume = 0.6 },
	Meow = { ids = { 100428235275738 }, volume = 0.4, range = 160 },
	Purr = { ids = { 9113984526 }, volume = 0.35, range = 90, pitch = 0.9 },
	Hiss = { ids = { 71522230632243 }, volume = 0.7, range = 220 },
	Pounce = { ids = { 9120709480 }, volume = 0.5, range = 120 },
	TrainLoop = { ids = { 9120225625 }, volume = 0.3, range = 200 },
	Whistle = { ids = { 9120223157 }, volume = 0.45, range = 380 },
	Creak = { ids = { 9125563505 }, volume = 0.8, range = 200 },
	Squeak = { ids = { 9125994570 }, volume = 0.7, range = 180 },
	Snap = { ids = { 9119057452 }, volume = 0.8, range = 200 },
	Thud = { ids = { 9113525643 }, volume = 0.6 },

	-- UI
	Click = { ids = { 10066968815 }, volume = 0.35 },
	Hover = { ids = { 10066931761 }, volume = 0.08 },
	Open = { ids = { 10128766965 }, volume = 0.3 },
	Close = { ids = { 10066914500 }, volume = 0.25 },
	Claim = { ids = { 9116395089 }, volume = 0.5 },
	Daily = { ids = { 1842312835 }, volume = 0.5 },
	NoticeGood = { ids = { 9126073011 }, volume = 0.2 },
	NoticeWarn = { ids = { 10066926605 }, volume = 0.25 },

	-- music: two stems of the same 130 s APM cue, played in sync; the chase layer fades in over the night one
	MusicNight = { ids = { 9045117617 }, volume = 0.22, group = "Music" }, -- Sneaky Schemes, no percussion
	MusicChase = { ids = { 9045109623 }, volume = 0.3, group = "Music" }, -- Sneaky Schemes, full mix
}

return D
