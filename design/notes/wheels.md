# Speed wheels notes (wheels session, 19 Oct 2026)

Dylan: "the hamster wheels should have way more upgrades and have better stat gain, also the speed can go up more ...
the bigger the number the better people will want to get it higher." Then, picking from the table: no top per
wheel ("no caps, just faster"); no real speed cap; "make it look bigger than it is, eg. 100 rn should be like 100k
speed"; and "number flies, real slows" over an exact x1000.

## How Speed works now

- **Speed is one big number** (`profile.Speed`, Player attribute `Speed`). 1,000 Speed = 1 walk speed: you start at
  **16,000** (walk 16) and the old max (walk 80) is **80,000**.
- **Real walk speed**: `GameConfig.walkSpeed(speed)` = speed / 1,000 up to 80,000, then
  `80 + 9.4 * ln(speed / 80,000)`: keeps rising forever, slower and slower. 1M walks 104, 100M 147, 10B 190.
  A physics safety limit of 400 (`SPEED_SAFETY`) is never reached in normal play.
- **Training**: run in your wheel; every 0.5 s you gain half of the wheel's `gain` (`GameConfig.wheelGain(level)`).
  No top per wheel and no overall cap; a better wheel just trains faster.
- **25 wheel levels** (`GameConfig.WHEELS`: name, cost, gain). Gain is about x1.6 per level, cost about x2.6.

| Lv | Look | Cost | Speed / s |
| --- | --- | --- | --- |
| 1 | Cardboard Spool | free | 100 |
| 2 | Sock Stripes | $200 | 160 |
| 3 | Toy Bricks | $550 | 260 |
| 4 | Ship's Wheel | $1.5K | 410 |
| 5 | Candy Cane | $4K | 660 |
| 6 | Arcade Neon | $10K | 1,000 |
| 7 | Golden Vault | $25K | 1,700 |
| 8 | Dino Bones | $70K | 2,700 |
| 9 | Bubble Pop | $180K | 4,300 |
| 10 | Frosty Ice | $500K | 6,900 |
| 11 | Robot Gears | $1.2M | 11K |
| 12 | Rocket | $3.3M | 18K |
| 13 | Lava | $9M | 28K |
| 14 | Rainbow | $23M | 45K |
| 15 | Thunderstorm | $60M | 72K |
| 16 | Haunted | $160M | 120K |
| 17 | Diamond | $420M | 180K |
| 18 | Dragon | $1.1B | 300K |
| 19 | Ringed Planet | $3B | 470K |
| 20 | Galaxy | $8B | 760K |
| 21 | Black Hole | $20B | 1.2M |
| 22 | Supernova | $55B | 1.9M |
| 23 | Angel Wings | $140B | 3.1M |
| 24 | Royal Crown | $380B | 5M |
| 25 | Infinity | $1T | 7.9M |

## Old saves

`PlayerData` reconcile: a profile with `SpeedPoints` and no `Speed` gets `Speed = 16,000 + 1,000 x points` (same
walk speed as before); `SpeedPoints` / `SpeedProgress` are dropped. `WheelLevel` is kept as is (levels 1–7 keep
their looks).

## Where it shows

- HUD bottom left (`GameUI` `speed()`, `GameConfig.speedText`: "16,000", "845,300", then "1.25M").
- Player list: a **Speed** column next to Cash and Per Sec (`Economy` leaderstats).
- Upgrades panel: the wheel's name, "+N Speed a second", the next wheel's name and gain; the big Speed number ticks
  up live.
- Buying a wheel: "Rocket wheel! +18,000 Speed a second".
- Training: "+N Speed" pops off your head every tick (`WheelFx.client.luau`, uses `VFX.popText`).

## Wheel looks (`tools/bedroom/Homes.luau`)

`Homes.WHEEL_LOOK[1..25]`, data-driven; `Homes.buildWheel` reads the flags (listed above the table). The wheel
grows up to level 7 and then stays that size (it has to fit the home); past that the looks get wilder: spikes and
crystals on the ring, bone and lightning spokes, bubbles, a voxel planet / sun / black-hole core, inner neon rings,
moons, torches with fire, horns, storm clouds, rocket boosters, wings, a crown on an arch, a halo, light streaks
(Trails) and particles (presets `WHEEL_PARTICLES`, Roblox's built-in textures, in a still box round the wheel).
Spin: idle spin grows with the level; `WheelFx` spins a wheel x2 to about x6 while its owner trains (max 16 rad/s).
Server: `Homes.rewheel` clamps to `#WHEEL_LOOK`.

Showcase: `Workspace.Showcase` wheel row is now 3 rows of 9 with each wheel's name; blankets moved to z 140 and toys
to z 250.

## Tested (19 Oct, Studio Play, Dylan's save)

- Save migrated: Speed 16,000, wheel 1, walk 16; player list shows "16,000".
- Training: +100 Speed a second on wheel 1 ("+50 Speed" pops every half second), HUD and Upgrades panel tick up
  live, the wheel spins x2.4 while running; hopping off sets walk speed from Speed (18,400 Speed = walk 18.4).
- Wheel 20 look built in a real home (`WheelLevel` attribute on the hole, not saved). No errors in the output.
- Not tested: buying a wheel level in Play (it would spend Dylan's cash).

Captures: `design/studio-wheels/` (`all-wheels.jpg` = every level on one sheet, three per shot; `training-popup.jpg`,
`upgrades-panel.jpg`). The showcase in Studio was rebuilt with all 25 (Studio change: the place needs saving).

## For the other sessions

- **SFX** (`Footsteps.luau` wheel loop pitch): the `SpeedPoints` attribute and `GameConfig.SPEED_MAX_POINTS` are gone.
  Use `player:GetAttribute("Speed")` with `GameConfig.walkSpeed(speed)` (16 to ~200).
- **Bases**: I only touched `WHEEL_LOOK`, `buildWheel` and the wheel particle presets above it in
  `tools/bedroom/Homes.luau`.
- The shop's Speed Packs (+150K ... +250M Speed) now fit this scale.

## Open

- Real walk at the top end (150–200) makes the Kid, cat and train much easier to outrun; worth a look once players
  get there. Tune with `SPEED_LOG`.
- Prices assume late-game income in the tens of millions a second; retune if the economy changes.
