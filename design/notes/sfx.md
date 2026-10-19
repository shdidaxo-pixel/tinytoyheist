# SFX and music notes (sfx session, 19 Oct 2026)

Goal: every moment has a sound; satisfying, mixed, never loud. Small moments are quiet (steps, ticks, squeaks), big
moments get a stinger and the music ducks under them.

## Files (client only)

| File | What |
| --- | --- |
| `src/StarterPlayer/StarterPlayerScripts/Bedroom/SoundIds.luau` | **every asset id** and its mix (volume, 3D range, pitch, group) |
| `.../Bedroom/Sounds.luau` | SoundGroups, `Sounds.play / loop / duck / once`, and the hooks for every moment |
| `.../Bedroom/Footsteps.luau` | footsteps by floor, landing thump, blanket drag loop, Speed wheel loop (all players) |
| `.../Bedroom/Music.luau` | night loop + chase layer |

No edits to shared files: everything listens to what the server already sends (attributes, `Reveal`, `Data`,
`Notice`, `Knocked`, prompts) and to the VFX session's `Moments` once `Shared/VFX/Moments` exists.

## API for other sessions

```lua
local Sounds = require(game.Players.LocalPlayer.PlayerScripts:WaitForChild("Bedroom"):WaitForChild("Sounds"))
Sounds.play("Click")                          -- flat
Sounds.play("Lock", somePart)                 -- 3D, follows the part (or a Vector3)
Sounds.play("CashBig", nil, { volume = 0.5, pitch = 1.1, delay = 0.2 })
Sounds.duck(3, 0.4)                            -- dip the music under a big moment
```
Add a new sound = one line in `SoundIds.luau`.

## Mixing

- **SoundService.Music** and **SoundService.SFX** SoundGroups. Settings toggles: `SettingMusic` → Music volume 0/1,
  `SettingSoundEffects` → SFX 0/1 (fades; nil = on). Roblox's own character sounds go in SFX too; its running
  sound is muted (our footsteps replace it).
- 3D: `InverseTapered`, full volume up to 15% of the range (min 8 studs), silent at the range. Ranges are sized to
  the 0.65 map: steps 45–70, toy squeaks 40, cat 90–220, train 200–380, the Kid 260–420.
- Music ducks to 25–50% under reveals (Epic+), level-ups, daily streak, the Kid waking, being robbed.
- One-shots get ±5% random pitch so repeats don't sound the same.

## Sound list

All are free Creator Store audio usable in any experience. **PSE** = Pro Sound Effects, **APM** = APM Music
(Roblox's licensed libraries), **Roblox** = Roblox's own UI set, **public** = a public upload by a verified creator.

| Moment | Name | Asset id(s) | Source | Hook |
| --- | --- | --- | --- | --- |
| Step on carpet / safe ring / homes | StepCarpet | 91882016473062, 111131620367547, 73343053773763, 123224557798023, 92103616531947, 73871404556766 | public (iLoveSwiss_0, Carpet_Footstep 1–6) | Footsteps, `MapConfig.zoneAt` |
| Step on wood | StepWood | 9120880067, 9120880314, 9120880402, 9120880564, 9120880575, 9120880755, 9120880810, 9120880063 | PSE Wood Grab Muted Thuds | Footsteps |
| Creaky boards (30% of steps) | StepCreak | 9125563589, 9125563842, 9125563286 | PSE Floor Creaks | Footsteps |
| Blanket drag loop | DragLoop | 9113455185 | PSE Blanket Movement 3 | player attr `Carrying`, pitch by `CarrySize` |
| Slow Mode | — | — | — | player attr `SlowMode` halves steps and drag |
| Grab a toy | Grab | 9113455017, 9114883390 | PSE Blanket Handle 2, Jacket 2 | player attr `Carrying` set |
| Hatch build-up | HatchRise | 9119816546 | PSE Synth Power Up Wind Up | `HatchPrompt` hold (and Moment `HatchHold`) |
| Hatch pop | HatchPop | 9117841338 | PSE Pop Airy 1 | `GameRemotes.Reveal` |
| Reveal Common | RevealCommon | 9116394545 | PSE Magic Glows chiming | Reveal `rarity` |
| Reveal Uncommon | RevealUncommon | 9126073001 | PSE Synth Sparkle Bell Ding | |
| Reveal Rare | RevealRare | 125706237686412 | APM Glistening Harp sting | |
| Reveal Epic | RevealEpic | 9039420865 | APM Something Magical (sting) | |
| Reveal Legendary | RevealLegendary | 1843982329 | APM It's So Magical sting | |
| Reveal Mythic | RevealMythic | 1841820743 | APM Palace Magic (sting) | + shimmer |
| Reveal Secret | RevealSecret | 1838007794 | APM Magical Secret (sting) | + shimmer |
| Mythic/Secret shimmer layer | RevealShimmer | 9113122722 | PSE Angel Sparkle 2 | |
| Mutation | Mutation | 9125635649 | PSE Magical Exit Sparkling | Reveal `mutation` |
| Big size (sizeMult ≥ 1.5) | BigSize | 1846544949 | APM Bass Gliss Up | Reveal `sizeMult` (toy-sizes session); lower pitch for bigger |
| Toy idle squeak (pens, within 40 studs) | ToySqueak | 9125994570, 9125994387, 9125994553, 9114122864 | PSE Squeeze Toy, Doll Squeaks | `TinyToy` tag with `Owner`, every 2.5–5 s, pitch by `Size` |
| Cash tick (at most every 3 s) | CashTick | 9113849492 | PSE Coins Jingle 6 | player attr `Cash` up |
| Big cash (sell, rewards) | CashBig | 9113849445 | PSE Coins Jingle 5 | Cash up by > 4 s of income |
| Purchase | Purchase + Register | 10066947742, 9113728625 | Roblox RBLX UI Purchase, PSE Cash Register 1 | Cash down |
| Home level-up | HomeLevelUp | 1841172671 | APM In Agreement (bells) | player attr `HomeLevel` up |
| Wheel level-up | WheelLevelUp | 9117887138 | PSE Power Up Sweeteners 3 | player attr `WheelLevel` up |
| Wheel running loop | WheelLoop | 9120658690 | PSE Squeaky Wheel | player attr `Training`; pitch 0.75 + wheel level + `SpeedPoints` |
| Steal start | StealStart | 9120709480 | PSE Whoosh Fast Short | `StealPrompt` triggered / Moment `StealStart` / Notice |
| Steal success | StealSuccess | 1848287311 | APM The Little Things - Hit | Moment `StealBanked` / Notice "You stole" |
| You're being robbed | Robbed | 9119755443 | PSE Synth Alarms Composite 3 | Moment `StealStart` to owner / Notice "is stealing your" |
| Got it back / toy banked | Recovered | 9126073318 | PSE Synth Bell Ding | Moment `Recovered` / Notice |
| Door lock / unlock | Lock / Unlock | 9116176070 / 9114142431 | PSE Keys In Padlock 3, Door Latch 2 | home attr `Locked` (any home, 3D at its padlock) |
| Kid snore loop | Snore | 9113862735 | PSE Comic Snoring Male | Kid `State` Asleep / BackToBed |
| Kid stirs | KidStir + KidSnort | 9113383926, 9119306551 | PSE Bed Creaks 5, Sniffs Snorts | Kid `State` → Stirring |
| Kid wakes | KidWake | 1846887133 | APM Suspense Sting (b) | Kid `State` → Awake |
| Lights on / off | Switch | 9125609743 | PSE light switch | lights follow Stirring/Awake |
| Flashlight | Flashlight | 9114479665 | PSE Flashlight On Off Clicks | Kid attr `Flashlight` |
| Kid footsteps | Stomp | 9113525391 | PSE heavy body impact | Kid attr `Walking` |
| Kid grab | KidGrab + Thud | 9126014962 | PSE Swish Whoosh | `Knocked` message "The Giant caught you!" |
| Cat meow | Meow | 100428235275738 | public (szur999, cute cat meow) | every 14–28 s on Patrol/Rest (6–12 s when aggressive) |
| Cat stalks | Purr | 9113984526 | PSE Creature Purring 5 | cat `State` → Stalk |
| Cat pounce | Hiss + Pounce | 71522230632243, 9120709480 | public (creeperakio, Cat Hiss), PSE whoosh | cat `State` → Pounce |
| Train chug | TrainLoop | 9120225625 | PSE Toy Wind Up 11 | always, on the engine |
| Train whistle | Whistle | 9120223157 | PSE Toy Train Whistle 11 | every 9–17 s |
| Loose board | Creak | 9125563505 | PSE Floor Creaks | hazard `Fired` |
| Duck | Squeak | 9125994570 | PSE Squeeze Toy | hazard `Fired` |
| Mouse trap | Snap | 9119057452 | PSE snap | hazard `Fired` |
| Knockdown | Thud | 9113525643 | PSE body impact | `BedroomRemotes.Knocked` |
| Landing | StepCarpet/Wood | — | — | Humanoid `Landed` |
| UI click | Click | 10066968815 | Roblox RBLX UI Select 02 | every GuiButton `Activated` |
| UI hover | Hover | 10066931761 | Roblox RBLX UI Hover 01 | UIKit buttons (`Hit`) `MouseEnter`, very quiet |
| Panel open / close | Open / Close | 10128766965 / 10066914500 | Roblox RBLX UI Swipe / Back | UIKit panel `Visible` |
| Reward claim (playtime) | Claim | 9116395089 | PSE Magic Glows chiming 4 | `GameRemotes.Data` playtimeClaimed grew |
| Daily streak | Daily | 1842312835 | APM Glockenspiel Sounds (a) | `GameRemotes.Data` Daily.Streak up |
| Other notices | NoticeGood / NoticeWarn | 9126073011 / 10066926605 | PSE bell ding, Roblox UI Delete | `BedroomRemotes.Notice` |
| Music, night | MusicNight | 9045117617 | APM Sneaky Schemes (Alt4, no percussion) | always |
| Music, chase layer | MusicChase | 9045109623 | APM Sneaky Schemes (full mix) | fades in while Kid Stirring/Awake (lights on); 35% while carrying |

## Moments I listen to (VFX session's table in vfx.md)

`HatchHold`, `HatchCancel`, `StealStart` (owner → Robbed, thief → StealStart), `StealBanked`, `Recovered`. Every one
also has a fallback from today's signals, deduped with `Sounds.once`, so nothing plays twice.

## Open / next

- Picked by library name and description; levels set by ear-less first pass. Dylan should listen and say what's
  too loud, too much or wrong (one line in `SoundIds.luau` each).
- Hallway: wood x2 floor uses StepWood; Roomba and grey cat sounds when that room is built.
