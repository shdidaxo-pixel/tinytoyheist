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
		Uncommon = { Ring = 0.3, Sparkle = 0, Aura = 0, Embers = 0, Light = 0, Tell = false },
		Rare = { Ring = 0.5, Sparkle = 0.7, Aura = 0, Embers = 0, Light = 0, Tell = false },
		Epic = { Ring = 0.7, Sparkle = 2, Aura = 0, Embers = 0, Light = 0.6, Tell = true },
		Legendary = { Ring = 0.85, Sparkle = 3.5, Aura = 0.45, Embers = 0, Light = 1, Tell = true },
		Mythic = { Ring = 0.95, Sparkle = 3, Aura = 0.55, Embers = 4, Light = 1.3, Tell = true },
		Secret = { Ring = 1, Sparkle = 6, Aura = 0.6, Embers = 3, Light = 1.5, Tell = true },
	},
}
