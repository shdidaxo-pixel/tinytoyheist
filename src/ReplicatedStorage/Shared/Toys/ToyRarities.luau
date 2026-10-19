-- Rarity order, colours and how strong each rarity's effects are. Pure data (the review page reads it too).
-- Colours match UIKit.Rarity so the toys glow in the same colours as their UI labels. Secret is rainbow.
--
-- Fx, per rarity (0 = off):
--   Ring    floor glow under the toy, opacity 0..1
--   Sparkle sparkles rising off the toy, particles per second
--   Aura    soft glow behind the toy, opacity 0..1
--   Embers  little sparks rising from the feet, particles per second
--   Light   PointLight brightness
--   Tell    true if the sleeping toy leaks its glow from under the blanket (the plan's "glow tell", Epic and up)
-- Kept soft so the toy itself reads first (Dylan, 19 Oct: toys glowed too much in the pens).
return {
	Order = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" },
	Colors = {
		Common = "#B8BCC6",
		Uncommon = "#5BE36A",
		Rare = "#3DA5FF",
		Epic = "#B45CFF",
		Legendary = "#FFD43B",
		Mythic = "#FF4D5E",
		Secret = "#FFFFFF",
	},
	Fx = {
		Common = { Ring = 0, Sparkle = 0, Aura = 0, Embers = 0, Light = 0, Tell = false },
		Uncommon = { Ring = 0.25, Sparkle = 0, Aura = 0, Embers = 0, Light = 0, Tell = false },
		Rare = { Ring = 0.35, Sparkle = 0.7, Aura = 0, Embers = 0, Light = 0, Tell = false },
		Epic = { Ring = 0.45, Sparkle = 1.5, Aura = 0, Embers = 0, Light = 0, Tell = true },
		Legendary = { Ring = 0.55, Sparkle = 2.5, Aura = 0.14, Embers = 0, Light = 0.35, Tell = true },
		Mythic = { Ring = 0.6, Sparkle = 2.5, Aura = 0.17, Embers = 3, Light = 0.45, Tell = true },
		Secret = { Ring = 0.65, Sparkle = 4, Aura = 0.2, Embers = 2.5, Light = 0.55, Tell = true },
	},
}
