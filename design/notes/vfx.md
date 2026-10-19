# VFX notes (vfx session, 19 Oct 2026)

Goal (Dylan): "vfx gotta go crazyyy". The MOMENTS are huge (hatch, mutation, steal, level-up, Kid waking); idle pen
effects stay soft (he said on 19 Oct the pens were too bright).

## API for the other sessions

Everything is **client only** (LocalScripts / client modules). Lives in `src/ReplicatedStorage/Shared/VFX/`.

```lua
local VFX = require(game.ReplicatedStorage.Shared:WaitForChild("VFX"))

-- World bursts. at = Vector3 | BasePart | Model. opts all optional.
VFX.burst(kind, at, opts)
--   kind: "Hatch"     the big reveal (opts.rarity, opts.mutation, opts.sizeMult = the size roll, 1 = normal)
--         "LevelUp"   upgrade bought (opts.color, opts.scale)
--         "Cash"      coins + "$" sparks (opts.amount)
--         "Steal"     red grab burst; "Stolen" big red loss burst; "Recovered" green
--         "Poof"      small dust puff (landing, drop, knock-down)
--         "Sparkle"   a quick sparkle pop (opts.color)
--         "Shockwave" flat ring on the floor (opts.color, opts.scale)
--   opts: { rarity?, mutation?, color?: Color3, scale?: number (1 = player-sized), sizeMult?, amount? }

VFX.popText(text, at, opts)      -- "+$120" style number popping up and floating. at = world (Vector3/Part/Model)
                                 -- or screen (UDim2, or a GuiObject to pop over).
                                 -- opts { color?, size? (px, default 30), rise? (studs/px), duration?, stroke? }
VFX.shake(strength, duration)    -- camera shake. strength 0..1 (0.15 small bump, 0.5 big, 1 huge)
VFX.flash(color, alpha, duration)-- full-screen flash. alpha 0..1 peak opacity
VFX.vignette(color, alpha, duration) -- coloured screen edges; duration nil = stays until VFX.vignette(nil)
VFX.beams(at, color, count, duration) -- light pillars shooting up (rarity reveals, rare spawns)
VFX.confetti(count, colors?)     -- screen confetti rain (colors = { Color3 })

-- UI juice
VFX.uiPop(guiObject, amount?)    -- bounce (amount 0.15 default)
VFX.uiPress(button)              -- call once on a button: squash on press, pop on release, hover grow
VFX.shine(guiObject)             -- a white shine sweep across it
VFX.countTo(label, from, to, seconds, format) -- number count-up with a bounce at the end

VFX.quality()                    -- "full" or "low" (Performance Mode). Everything above already tones itself
                                 -- down in "low" (fewer particles, no shake, short flashes).
```

## Moments (shared hook names; the SFX session plays sounds on the same ones)

```lua
local Moments = require(game.ReplicatedStorage.Shared:WaitForChild("VFX"):WaitForChild("Moments"))
Moments.on(kind, function(data) ... end)  -- returns a connection
Moments.fire(kind, data)                  -- client-local fire (UI etc.)
```

Server code fires to clients with the server module `ServerScriptService.Bedroom.Moments`:
`Moments.fire(player | "all", kind, data)` → `GameRemotes.Moment` (kind, data) → client `Moments.on`.

| kind | where it comes from | data |
| --- | --- | --- |
| `HatchHold` | client: holding E on your HatchPrompt (fires once at hold start) | `{ blanket: Model, seconds }` |
| `HatchCancel` | client: let go early | `{ blanket }` |
| `Hatch` | client: `GameRemotes.Reveal` | the reveal info `{ id, name, rarity, mutation, perSecond, size, equipped, sizeMult? }` |
| `HatchCharge` | client: the build-up starts (right after Reveal); the blanket shakes for `seconds` (0.6 Common … 3 Secret) | `{ rarity, seconds }` |
| `HatchBurst` | client: the build-up ends, the toy bursts out, the card shows: **the reveal sting goes here** | `{ rarity, mutation?, sizeMult, sizeTier? }` |
| `ToyRevealed` | client: your new toy pops into your pen at the burst | `{ toy: Model, mine: true }` |
| `Cash` | client: Cash attribute went up | `{ amount }` |
| `ToyIncome` | client: the "+$" pop over one of your pen toys | `{ toy, amount }` |
| `HomeLevelUp` | client: your home's `Level` went up | `{ home, level }` |
| `WheelLevelUp` | client: your home's `WheelLevel` went up | `{ home, level }` |
| `StealStart` | server → thief and owner | `{ toyName, rarity, thief: userId, owner: userId }` |
| `StealBanked` | server → thief | `{ toyName, rarity, owner: userId }` |
| `StolenFrom` | server → owner | `{ toyName, rarity, thief: userId }` |
| `StolenDropped` | server → all | `{ position: Vector3, owner: userId }` |
| `Recovered` | server → owner | `{ toyName }` |
| `Knocked` | client: `BedroomRemotes.Knocked` | `{ message }` |
| `KidStir` | client: GiantKid `State` → Stirring | `{}` |
| `KidWake` | client: GiantKid `State` → Awake | `{}` |
| `KidSleep` | client: back to Asleep | `{}` |
| `RareSpawn` | client: a Legendary+ blanket appears on the floor | `{ blanket, rarity }` |
| `CatBite` | server → all (Cat.luau, lights on): the cat bites a mouse and throws it home (LightsOnView flies the victim, plays chomp/whoosh/landing) | `{ victim: userId, bite: s, flight: s, landing: Vector3, height }` |
| `UIClick` | client: a button wired with `VFX.uiPress` was clicked | `{ button }` |

If you add a moment, add a row here.

## Rules I'm keeping
- Particle cap per burst (Hatch Secret ≈ 250 particles max; "low" quality ≈ a quarter).
- Idle pen effects (rarity Fx, mutation auras) stay soft; the burst at the moment is where it goes crazy.
- Performance Mode = `LocalPlayer:GetAttribute("SettingPerformanceMode")`.
- Asset ids in one module: `src/ReplicatedStorage/Shared/VFX/Assets.luau`. Sources in `design/vfx/`.

## Files

| File | What |
| --- | --- |
| `src/ReplicatedStorage/Shared/VFX/init.luau` | the library (bursts, hatch charge-up, pop text, shake, flash, vignette, beams, confetti, UI juice, `VFX.freeze` for captures) |
| `src/ReplicatedStorage/Shared/VFX/Assets.luau` | every VFX texture: uploaded id, or the local Studio copy until then |
| `src/ReplicatedStorage/Shared/VFX/Moments.luau` | the client event bus |
| `src/ServerScriptService/Bedroom/Moments.luau` | `Moments.fire(player or "all", kind, data)` from server code (Raids, Carry call it) |
| `src/StarterPlayer/StarterPlayerScripts/Bedroom/VfxClient.client.luau` | wires the moments to effects: your hatch, "+$" pops, level-ups, steals, the Kid, rare spawns, button clicks |
| `.../Bedroom/Effects.luau` | knocked down: jolt, flash, dust puff, dizzy stars |
| `src/ReplicatedStorage/Shared/Toys/ToyVFX.luau` | `revealBurst` → `VFX.burst("Hatch")` (everyone sees it at the pen); your own toy is held back for your charge-up |
| `src/ReplicatedStorage/Shared/Toys/Mutations.luau` | the 10 mutation looks, each with a signature effect (low rates) |
| `.../TinyToyHeistUI/GameUI.luau` | reveal card waits for the burst (`VFX.afterHatch`), `VFX.revealCard`, cash counter bounce |
| `design/vfx/make_sprites.py`, `render_coin.py`, `preview.py`, `out/` | sprite sources (numpy in Blender's Python; the coin is a Blender render) and the PNGs |

## Your hatch, step by step
1. Hold E on a ready blanket (`HatchHold`): a sparkle.
2. The prompt fires: a local copy of the blanket replaces the real one (no gap when the server removes it).
3. `GameRemotes.Reveal` arrives: `VFX.hatchCharge` (`HatchCharge`): it shakes harder and harder, hops, swells,
   sparkles get sucked in, light and beams grow white → rarity colour, screen edges close in. 0.6 s Common … 3 s Secret.
4. Burst (`HatchBurst`): neon orb, starburst, speed lines, sparkles, shockwave rings, beams, confetti (Uncommon+),
   sunburst rays (Epic+), lightning + a second wave + a light pillar (Mythic, Secret), rainbow everything (Secret).
   Mutation: a second burst in its colour with its own particle and "GOLD!" text. Big size roll: ground slam,
   "HUGE!/GIANT!". Screen: flash, shake, FOV punch, vignette, screen confetti (Epic+), double for Mythic+.
5. The pen toy pops in (held tiny until now) and plays the animations session's hatch jump; the card shows with
   spinning rays, a shine, the rarity line bouncing in and the $/s counting up.

## Textures
- All 18 PNGs in `design/vfx/out/` were uploaded to Roblox on 19 Oct (Dylan said yes); the ids are in `Assets.luau`.
  To change one: edit and re-run `make_sprites.py` / `render_coin.py`, upload the PNG, paste the new id.
- Studio uses the local copies (Studio's `content/textures/TTHVFX1/`); live servers use the ids. New uploads fail to
  load until Roblox moderation passes them (they did right after upload). They're owned by samrtly (user), and the
  game is group-owned: check they show in a live server before launch, or re-upload them to the group.

## Tested (19 Oct, Studio Play)
- Captures in `design/studio-vfx/` (hatch frames + gif, Mythic Giant reveal card, mutation auras, home level-up,
  Kid awake). A real hatch by another session showed the card waiting for the burst, with rays and confetti.
- Kid stir/wake: red "!" over him, red edges; lights-on session's banner shows at the same time (fine).
- The "robbed" moment once showed the camera badly tilted; the shake now takes last frame's wobble off before the
  camera updates (can't add up). **Re-tested 19 Oct**: three `StolenFrom` fired from the Server 0.25 s apart, camera
  roll sampled every frame for 6 s: peak 0.5°, back to exactly 0° once it settled. Fixed.
- More captures (19 Oct, fired as Moments from the Server): `steal-start-thief` ("GO GO GO!", orange burst),
  `steal-start-owner` ("THIEF!", red edges), `steal-banked` ("STOLEN!" + toy name, confetti), `stolen-dropped-beacon`
  (red beams, "YOUR TOY! GRAB IT!"), `recovered` (green burst, "GOT IT BACK!"), `rare-blanket-pillar` (gold pillar at
  the Legendary blanket by the bed; a table frames it), `knocked-bonk` and `knocked-stars-before/after-fix`,
  `performance-mode-hatch` (Legendary Gold Huge with `SettingPerformanceMode`: beams, ring, sparkles, lighter).
- Fixed while testing: `VFX.freeze` from the command bar / MCP only froze particles (their `require` is a separate
  copy of the module); it now goes through `Workspace.VFXFrozen`, and confetti holds still too. The dizzy stars went
  into the floor when you land upside down (`StudsOffsetWorldSpace` turns with the head); they now stay above it.
- Capture tips: arm a client hook on the remote that calls `VFX.freeze(true)` ~0.5 s after the moment arrives (tool
  calls take seconds, so freezing from a separate call is too late). Tweened things (flash, the BONK shout, the
  reveal card) don't freeze. Anchor the character to hold a knock-down pose. Pin the Kid asleep for a slot with
  `GiantKid:SetAttribute("WakesAt", workspace:GetServerTimeNow() + 3600)` (Server, Play only).
- Not captured yet: phone size (pop text + reveal card). There's no Luau way to size the viewport; it needs Studio's
  Device emulator (Test tab) turned on by hand. Don't launch "Roblox Studio" from the Start menu with computer use:
  that runs the installer and closes the open Studio (happened 19 Oct, 17:25).
