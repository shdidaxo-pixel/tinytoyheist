# Tiny Toy Heist: Handoff

Written 19 Oct 2026, evening, after Dylan's 27-note review and the art pass. This is the short, current handoff: what
the game is, where everything lives, how to work here and what's next. The long one (the full v6 map spec, every
number, the render pipeline, the history of every decision and Dylan's messages word for word) is
[handoff-v6-full.md](handoff-v6-full.md); section numbers below like "full §15" point into it.

---

## 1. The game in one paragraph

A Roblox "steal" game (like Steal an Egg / Steal a Brainrot) where you're a tiny mouse-sized player in a Kid's
Bedroom at night. You live in one of 8 homes cut into a curved wall at the start of the room. Sleeping toys lie under
blankets down a long run (Small on the carpet, Medium on the wood, Large on the creaky boards). You grab one (hold E),
drag it home past the cat, the train, mouse traps and noisy floor while the giant Kid's wake meter fills, then hatch
it in your home. Toys pay cash every second; cash buys home levels (more pen slots) and Speed wheel levels. You can
raid other players' pens. All 105 toys exist as voxel models with idle animations, rarity effects and 10 mutations.

## 2. Where things stand

**Built and play-tested in Studio** (solo, and raids with 2 players):
- **The Kid's Bedroom** (concept v6): `Workspace.Bedroom`, built by `tools/build-bedroom.luau` + `tools/bedroom/*`,
  full size then shrunk to `MapConfig.SCALE` = 0.65. Homes in the curved wall, teal safe ring, carpet / wood /
  creaky bands, bed and Giant Kid on the right, block tower, winding train, cat, traps, loose boards, ducks, bricks,
  baby-monitor zone, hallway door straight ahead (blocked 150 studs in).
- **Game systems** (`src/ServerScriptService/Bedroom/`, numbers in `src/ReplicatedStorage/Shared/GameConfig.luau`):
  saving, inventory, hatching, cash per second, upgrades, Speed training, raids, rewards, hazards, the Kid waking.
- **UI** (`src/StarterPlayer/StarterPlayerScripts/TinyToyHeistUI/`): HUD, Upgrades, Your Toys, Index, Daily,
  Playtime, Settings, the reveal card, one-time tutorial.
- **Toys**: all 105 in `ServerStorage.TinyToyHeistAssets.Toys` (see §6).
- **Art pass** (19 Oct, evening): new blankets, toy padlock, toy-box Index stand, 7 Speed wheel looks, softer home
  lights and toy glow, and a model showcase (see §5).
- **Published** as a private experience: placeId 75787601263038, gameId 10771951800, group-owned (group 1052465801),
  still named "samrtly's Place". Studio API access is on, so **Studio play tests read and write Dylan's real save**.
  Latest place file: `places/TinyToyHeist-Latest.rbxl` (commit e128600).

**Not built yet**: the shop (needs product/pass IDs from the Roblox site), gadgets, other rooms (the Hallway has
renders only), Giant toys in the world, rebirth (hidden), sounds/music settings beyond the toggles.

## 3. How the game plays now (after Dylan's review)

- **Homes**: 8 homes, claimed in order when you join. You spawn on an invisible pad inside your home. Empty homes
  are Level 1 with nothing in them. Sign over each home: owner name and "Lv N · $X/s" (or a red lock timer).
- **Sleeping toys**: a blanket on every spawn spot (`Workspace.Bedroom.ToySpawns`), Small near the homes (the first
  ring sits right in front of them), Medium and Large further down. Rarity is rolled by blanket size; Epic and up
  leak a glow from under the blanket. Empty spots refill after 25 s.
- **Carrying**: hold E to grab; you drag the blanket behind you at 95 / 80 / 60% speed (S / M / L), making noise.
  Hazards (train, cat, traps, the Kid) knock you down and you drop it. Drop Toy button on the HUD.
- **Hatching**: carry it into your home and it lies there (max 6 blankets, `profile.Blankets`) with a timer
  (S 5 s, M 20 s, L 60 s, saved as os.time). Then hold E on it (`HatchPrompt`, owner only) to hatch: reveal card,
  mutation rolled at that moment. Your first toy ever is the Plush Bunny.
- **Inventory**: hatched toys go to your inventory (`profile.Toys`, max 100; `e` = equipped, `l` = locked) and
  equip themselves while the pen has room. **Only equipped toys earn and can be stolen.** Your Toys panel: Equip /
  Unequip, Equip Best, Lock, Sell, Sell Mode. A toy sells for 20 s of its income.
- **Money**: equipped toys pay every second, auto-collected. Shown on the home sign and the player list (Cash,
  Per Sec). No cash pile any more.
- **Upgrades**: home level 1–7 ($500 → $50M; more pen slots, new look) and the **Speed wheel level** 1–7, bought
  separately ($300 → $8M; x1 to x4 training). Speed is trained by standing in your wheel (E on it, jump to stop),
  up to walk speed 80. Strength, Sneak and Grip were removed. Rebirth is hidden (`GameConfig.SHOW_REBIRTH`).
- **Raids**: hold Steal 2 s on an equipped toy in someone's pen and drag it home. Dropped stolen toys glow red and
  slide home after 15 s; the owner can grab them back. Anti-grief: under 3 toys, a 10-min new-player shield (unless
  5+ toys), 90 s per-victim cooldown, can't steal with a full pen. Door lock: press E on your padlock.
- **The Kid**: the wake meter fills with noise (floor type, x2 in the monitor zone). At 80 he sits up and sweeps
  his flashlight; at 100 the lights go on, he gets up, walks toward noise and grabs players (drop, stun, sent home);
  then back to sleep. With the lights on the cat hunts everyone.
- **Rewards**: 7-day streak and 10 playtime gifts (cash, x2 money boosts, mystery toys).
- **HUD**: cash, $/s, speed, wake meter and timer, RUN! and Drop Toy while carrying, blanket list on the right,
  small top-right buttons with badges, Slow Mode (half speed and half drag noise), Settings (Performance Mode, Hide
  Players, music/SFX toggles as LocalPlayer attributes).

## 4. Where everything lives

| What | Where |
| --- | --- |
| Map numbers (shared by the builder and game code) | `src/ReplicatedStorage/Shared/MapConfig.luau` (scaled; `.unscaled` = full size) |
| Map spec (2,783 checks) | `tests/MapConfig.spec.luau` |
| Map builder | `tools/build-bedroom.luau` + `tools/bedroom/` (Kit, Room, Homes, Blanket, Furniture, Landmarks, Hazards, Showcase) |
| Lighting presets | `src/ReplicatedStorage/Shared/BedroomLighting.luau` (Night, LightsOn) |
| Pen roaming (same on server and clients) | `src/ReplicatedStorage/Shared/PenRoam.luau` |
| Game numbers | `src/ReplicatedStorage/Shared/GameConfig.luau` |
| Server | `src/ServerScriptService/Bedroom/` (PlayerData, Homes, Pens, Carry, Economy, Upgrades, Raids, Rewards, Giant, Cat, Train, Hazards, Knock, Events) |
| Client world views | `src/StarterPlayer/StarterPlayerScripts/Bedroom/` (HomeView, GameView, KidView, CatView, TrainView, Effects, Lights, Sounds, ShowcaseTeleport) |
| UI | `src/StarterPlayer/StarterPlayerScripts/TinyToyHeistUI/` (GameUI, Hud, UIKit) |
| Toys | `src/ReplicatedStorage/Shared/Toys/` (ToyCatalog, ToyBuilder, ToyAnimator, ToyVFX, ToyRarities, Mutations, MutationData, ToyPalette, Sets/) and `tools/toys/` |
| Design docs and renders | `design/` (v6 render page and stills, hallway brief and renders, toy review pages, toy icons, Studio captures in `studio-v6/` and `studio-artpass/`) |
| Toy list (design) | `Toy Catalog.md`; first plan: `Day 1 - Starting Plan.md` |
| Place file | `places/TinyToyHeist-Latest.rbxl` (the only one committed) |
| Notes, decisions, devlog | Obsidian vault, Games/Tiny Toy Heist |

Rojo (`default.project.json`) maps `tools/bedroom` to `ServerStorage.TinyToyHeistTools.Bedroom`, the map builder
to `ServerStorage.TinyToyHeistTools.BuildBedroom`, the spec to `ServerStorage.TinyToyHeistTests`.

## 5. The art pass (19 Oct, evening)

Dylan's notes: the blankets didn't look like the renders; the push pin should be a toy lock; the domino Index stand
was confusing; the wheels should look more special each level and show the runner; the homes and toys were too
bright. Captures: `design/studio-artpass/` (before/after).

- **Blankets** (`tools/bedroom/Blanket.luau`): voxel cloth bells like the renders: a flared skirt, shallow steps to
  a rounded top, drape folds, a rolled lip in the trim colour, a pattern (plain, dots, stars, checks, stripe) and
  the toy's shape poking up (duck head S, bunny ears M, dino head and tail L). 30–39 parts.
  `Blanket.build(Kit, parent, size, at, colour?, pattern?)`: size "S"/"M"/"L" (8 / 9.8 / 13.3 wide), `at` = bottom
  centre (the model pivots there), colour 1..10 into `Blanket.COLOURS`. PrimaryPart `Lump` = an invisible box over
  it (prompts and the glow tell go there). Nothing collides. `Carry.makeBlanket` uses it.
- **Home props** (`tools/bedroom/Homes.luau`): the cash thimble and matchbox bed are gone; `Spawn` is an invisible,
  non-colliding SpawnLocation where the bed was. `LockButton` is a toy padlock (red body, yellow plate, keyhole,
  blue shackle) with `LockPrompt`; `Homes.setLocked` darkens it and drops the shackle when locked. `IndexStand` is a
  blue toy box marked INDEX with an open picture book (`IndexBook`) on top and `IndexPrompt` ("Open Index").
- **Speed wheels** (`Homes.buildWheel(Kit, MapConfig, home, frame, level)`, looks in `Homes.WHEEL_LOOK`): open
  sides (ring, spokes, hub) so you see the runner. Lv 1 cardboard spool, 2 sock stripes, 3 toy bricks with studs,
  4 ship's wheel, 5 candy cane with a lollipop hub, 6 arcade neon, 7 golden vault with gems and glowing gold. Names
  kept: `TrainingWheel` > `Wheel` (PrimaryPart `Axle`, attribute `Spin`), `RunPoint`, `TrainPrompt`. `applyLevel`
  builds it at the home's `WheelLevel` attribute (or the home level).
- **Brightness**: home fairy light 2 → 1, front fill 1.4 → 0.65; toy rarity ring, aura and light about halved
  (`ToyRarities.Fx`, `ToyVFX`), re-applied to the 105 stored toys. Mutation effects untouched.
- **Showcase** (`tools/bedroom/Showcase.luau`): `Workspace.Showcase` at x ≈ 4000, a plain baseplate with labelled
  rows: the 7 wheels, 30 blankets (3 sizes x 10 colours), all 105 toys by set, the 10 mutations on the 14 Bedroom
  toys. Build or remove in Edit mode:
  `require(game.ServerStorage.TinyToyHeistTools.Bedroom.Showcase:Clone()).build()` / `.clear()`.
  In Play, a **SHOWCASE / BACK** button (top right) takes you there and back and spins the wheels; only in Studio or
  for Dylan's account (UserId 7587099472, samrtly). It's about 10,800 parts: **clear it before launch**.

## 6. Toys: the short API (full §15 has the rest)

- Models: `ServerStorage.TinyToyHeistAssets.Toys.<Id>`. Clone, `toy:PivotTo(cf)` (pivot = centre of its feet on the
  floor, faces −Z), parent anywhere in Workspace; `TinyToyHeistToys/ToyClient` animates it within 220 studs.
- `PrimaryPart = Root` (invisible, CanQuery, put prompts on it). Attributes: ToyId, ToyName, Set, Rarity, Money,
  Size (S/M/L/G), Height, Mutation. Tagged `TinyToy`. Sizes: S 8, M 12, L 17, G 25 studs tall; a player is 5.
- Data: `ToyCatalog.get(id)`, `.list()`, `.inSet(set, rarity?)`, `.pick(set, rarity, rng)`, `.SET_ORDER`.
- Mutations: `Mutations.roll(rng, events, luck)`, `Mutations.apply(toy, id)`, `Mutations.multiplier(id)`; order in
  `MutationData.Order` (Gold, Candy, Glitter, Bubble, Shadow, Frozen, Rainbow, Cosmic, Glow, Haunted).
- Effects: `ToyVFX.applyRarity/removeRarity(toy)`, `ToyVFX.addGlowTell(blanket, rarity)`,
  `ToyVFX.revealBurst(toy)` and `ToyVFX.popIn(toy)` (client).
- Rebuild all toys (Edit mode): `require(game.ServerStorage.TinyToyHeistTools.BuildToys).run()`; how to make or edit
  one: `tools/toys/README.md`. Icons: `design/toy-icons/<Id>.png`.

## 7. Hooks between pieces

- Homes: `Workspace.Bedroom.Holes.Hole1..8`, attributes `HoleIndex`, `Owner` (UserId, 0 = free), `Level`,
  `WheelLevel`, `Locked`. Changing `Level` / `WheelLevel` rebuilds the look (server `Homes.relevel` / `rewheel`,
  which build full size and scale by `MapConfig.SCALE`).
- Pens: equipped toys live in `Hole#.PenToys` and roam on the clients (`PenRoam`, attribute `RoamSeed`); bounds on
  `Hole#.Pen` (`PenMin`, `PenMax`, `PenTop`). Blankets waiting to hatch live in `Hole#.Waking`.
- Prompt names (the client hides non-owner ones): StealPrompt, HatchPrompt, TrainPrompt, LockPrompt, IndexPrompt.
- `ServerStorage.BedroomEvents`: `DropCarried` (player, reason), `MakeNoise` (position, points, kind),
  `ToyGrabbed`. Player attributes `Carrying`, `CarrySize`, `Training`.
- The Kid: `Workspace.Bedroom.GiantKid` attributes `State` (Asleep / Stirring / Awake / BackToBed), `WakeMeter`
  0–100, `WakesAt`, `StateEndsAt`, `Flashlight`. Test: set `WakeMeter` to 100 on the Server.
- Studio test hook `ServerStorage.GameDebug` (Studio only): `("cash", player, n)`, `("give", player, "S"|"M"|"L")`,
  `("set", player, {field = value})`, `("profile", player)`, `("wipe", player)`. **It changes Dylan's real save.**

## 8. How to work here

- **CLAUDE.md rules**: commit every change (short plain message, explicit paths), StyLua + Selene first, push to
  origin main. Videos (*.mp4) stay out of git.
- **Saving the place**: tools can't save, and since publishing Ctrl+S saves to Roblox. After any Studio change, ask
  Dylan to use **File > Download a Copy** into `places/TinyToyHeist-Latest.rbxl`, check the file's timestamp, then
  commit it. (`places/TinyToyHeist-save1.rbxl` and `-savev6.rbxl` are old, untracked copies.)
- **Rojo** must be running (`rojo serve default.project.json`) and connected in Studio (Plugins > Rojo > Connect).
  If Studio stops syncing, check `rojo.exe`. Scripts don't reload in a running Play session: stop and start again.
- **Rebuild the map** (Edit mode): `local m = game.ServerStorage.TinyToyHeistTools.BuildBedroom:Clone(); print(require(m)); m:Destroy()`
- **Spec**: `local s = game.ServerStorage.TinyToyHeistTests["MapConfig.spec"]:Clone(); print(require(s)(game.ReplicatedStorage.Shared:Clone()))`
- **Studio is shared** between sessions: stop any Play test you start, and say so before you start one. One
  `screen_capture` at a time; `workspace.CurrentCamera.FieldOfView = 55` matches the renders; SurfaceGuis can be
  blank on the first capture after a rebuild (capture again); `AlwaysOnTop` BillboardGuis don't show in captures.
- Play tests: `user_keyboard_input` (hold E) to grab; `character_navigation` walks but doesn't jump; 2-player tests
  via Test > Start Test Session (a window only renders while it's in front).
- `workspace.StreamingEnabled` is on: far-away things (like the showcase) stream in when you get close.
- **Renders first** for any new room or big model: a three.js render page in `design/`, stills with headless
  Chrome (full §7), a published review page, Dylan's comments, then build.
- **Dylan**: reads quickly; short, plain updates. He decides, you recommend. He likes the voxel style, the clean
  look of the top steal games, and seeing things (captures, renders) rather than reading about them.

## 9. Dylan's standing decisions (don't undo)

- Map: renders before building; one long, simple, readable run; homes all in one curved wall with open fronts and
  no ceilings; hallway door straight ahead; bed against a side wall; middle path clear. (Memory:
  bedroom-layout-direction.)
- Map size 0.65 of the plan ("too big ... takes too long"). Floating signs that face the camera, no boards.
- Auto-collect cash; cash pile and bed removed; spawn in your home; Speed is the only stat, trained on the wheel,
  which has its own level; rebirth hidden for now ("might be too soon").
- Hallway (room 2, renders only, `design/hallway-brief.md`): wood x2 everywhere (no quiet runner), its own grey cat
  plus a Roomba with a dock, baby gates as room locks (Strength 3 / 6 / 10 in the plan), the Kid never enters the
  hallway but it gets busier and louder while he's awake. Still open: noise multiplier while he's awake (x3
  suggested), whether the Roomba bumps players, the cat's colour. (Memory: hallway-direction.)
- Things he turned down are listed in full §5.10.

## 10. What to do next

1. **Dylan looks over the art pass** (captures in `design/studio-artpass/`, or the showcase in Studio) and gives notes.
2. **Shop**: create the game passes and developer products on the Roblox site, then wire the shop UI.
3. **Wipe Dylan's save** before launch (`GameDebug` "wipe"), clear the showcase, upload the UI and toy-icon images
   (they're local-only in Studio's `content/textures/`), rename the experience.
4. **Gadgets** (Flashlight, Decoy, ...), the Pencil Bonk, door-lock upgrades, alarm bell.
5. **The Hallway**: build it from `design/hallway-brief.md` once Dylan settles the open questions; the bedroom door
   should swing flat (it's at 72° today) and the invisible blocker 150 studs in must go.
6. Giant toys and the deeper rooms (Kitchen, Living Room, Garage, Attic): renders first.
