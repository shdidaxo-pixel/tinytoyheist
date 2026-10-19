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
| `ToyRevealed` | client: a toy pops into any pen with a fresh `RevealedAt` | `{ toy: Model, mine: boolean }` |
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
| `UIClick` | client: a button wired with `VFX.uiPress` was clicked | `{ button }` |

If you add a moment, add a row here.

## Rules I'm keeping
- Particle cap per burst (Hatch Secret ≈ 250 particles max; "low" quality ≈ a quarter).
- Idle pen effects (rarity Fx, mutation auras) stay soft; the burst at the moment is where it goes crazy.
- Performance Mode = `LocalPlayer:GetAttribute("SettingPerformanceMode")`.
- Asset ids in one module: `src/ReplicatedStorage/Shared/VFX/Assets.luau`. Sources in `design/vfx/`.
