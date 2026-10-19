# Tiny Toy Heist: Handoff

Written 19 Oct 2026, at the end of the session that took the Kid's Bedroom from a written brief, through six rounds
of concept renders, to an agreed layout (concept v6). Nothing in Roblox Studio has changed yet. The next job is to
build v6 in Studio.

Read this file top to bottom before touching the map. It is long on purpose: it holds every number, every decision
and the reason behind it, every piece of Dylan's feedback in order, and a step-by-step plan for the Studio build.

---

## Contents

1. [Where things stand](#1-where-things-stand)
2. [How to work on this project](#2-how-to-work-on-this-project)
3. [Repo map](#3-repo-map)
4. [What Dylan wants: the design rules](#4-what-dylan-wants-the-design-rules)
5. [How we got here: the session, round by round](#5-how-we-got-here-the-session-round-by-round)
6. [Concept v6: the full spec](#6-concept-v6-the-full-spec)
7. [The render pipeline](#7-the-render-pipeline)
8. [What exists in the game today](#8-what-exists-in-the-game-today)
9. [Building v6 in Studio: the plan](#9-building-v6-in-studio-the-plan)
10. [Game systems v6 implies](#10-game-systems-v6-implies)
11. [Open questions](#11-open-questions)
12. [Known rough edges in the renders](#12-known-rough-edges-in-the-renders)
13. [Environment notes and gotchas](#13-environment-notes-and-gotchas)
14. [References](#14-references)
15. [Toys: how to use them](#15-toys-how-to-use-them)
16. [Appendix A: draft MapConfig for v6](#appendix-a-draft-mapconfig-for-v6)
17. [Appendix B: every camera in the render page](#appendix-b-every-camera-in-the-render-page)
18. [Appendix C: what is out of date](#appendix-c-what-is-out-of-date)
19. [Appendix D: checklists](#appendix-d-checklists)
20. [Appendix E: Dylan's messages, word for word](#appendix-e-dylans-messages-word-for-word)
21. [Appendix F: the bed and the Kid, in final Studio sizes](#appendix-f-the-bed-and-the-kid-in-final-studio-sizes)
22. [Appendix G: draft Luau for one home](#appendix-g-draft-luau-for-one-home)
23. [Appendix H: names and attributes](#appendix-h-names-and-attributes)
24. [Appendix I: glossary](#appendix-i-glossary)

---

## 0. Progress: v6 is built in Studio (19 Oct 2026, the map session)

**The Kid's Bedroom v6 is built and playable in Studio.** Everything below this section was written before the build;
where it disagrees with this section, this section wins.

### What exists now

| Piece | Where | Notes |
| --- | --- | --- |
| Map numbers | `src/ReplicatedStorage/Shared/MapConfig.luau` | v6, from Appendix A, plus home/zone/noise helpers, `trackPath`/`trackPose`, `trainCarDistance`, `flashlightTarget`, `SIGN`, `SHOWCASE_LEVELS`, `TOWER_STEPS`. |
| Spec | `tests/MapConfig.spec.luau` | Appendix D.1 and more: 2,401 checks pass. Track length 1841.0 (matches the render). Spawns 9 S / 12 M / 5 L. |
| Builder | `tools/build-bedroom.luau` + `tools/bedroom/` (Kit, Room, Homes, Furniture, Landmarks, Hazards) | Rojo: `ServerStorage.TinyToyHeistTools.BuildBedroom` and `.Bedroom`. ~3,300 parts, 22 lights, builds in a few seconds. Command bar: `local m = game.ServerStorage.TinyToyHeistTools.BuildBedroom:Clone(); print(require(m)); m:Destroy()` |
| Lighting | `src/ReplicatedStorage/Shared/BedroomLighting.luau` | `Night` and `LightsOn`, `apply(preset, seconds)`. Room lights are found by the `LightRole` attribute. |
| Pen roaming | `src/ReplicatedStorage/Shared/PenRoam.luau` | Toy position from a seed and the server clock (no history), so server and clients agree. |
| Server systems | `src/ServerScriptService/Bedroom/` | Homes (claim, spawn on your bed, signs, push-pin lock, level rebuilds, Studio demo toys), Giant (wake meter, sleep cycle, flashlight), Train, Cat, Hazards, Knock, Events. |
| Client views | `src/StarterPlayer/StarterPlayerScripts/Bedroom/` | Lights, KidView, TrainView, CatView (walk cycle, tail, head, crouch), HomeView (roaming toys, wheels, fairy lights, bobbing signs, YOUR HOME), Effects (knock-downs, noise ripples, trap/board/duck/brick animations). |
| Captures | `design/studio-v6/` | Studio shots at the Appendix B cameras and `compare-*.jpg` beside the renders. |

### Play-tested (all working)
Spawn on your matchbox bed in your own home; walk home → safe ring → carpet → over the track → wood → creaky → the
door, and back, with no snags; climb the tower to the lookout (all 25 steps with normal jumps); the train knocks you
down and fires the drop; the cat stalks, pounces, knocks you down and rests, and goes aggressive with the lights on;
wake meter 80+ → the Kid sits up and sweeps his flashlight; 100 → Stirring → Awake with the lights on (photo 1) and
back to night after; traps SNAP you home and re-arm after 20 s; boards/ducks/bricks make noise (x2 in the monitor
zone); toys roam their pens; Speed wheels spin by level; no script errors.

### Hooks for other code (also in the shared notes folder)
- `ServerStorage.BedroomEvents.DropCarried` (fired with player, reason) when a hazard knocks someone: the carry system
  should drop their toy. Hazards treat a player as carrying when the Player attribute `Carrying` is truthy.
- `ServerStorage.BedroomEvents.MakeNoise` (position, points, kind): "Drag"/"Step" count the floor
  (`MapConfig.noiseAt`); other kinds only the monitor zone. Feeds `GiantKid.WakeMeter`.
- `GiantKid` attributes: `State` (Asleep/Stirring/Awake), `WakeMeter`, `Flashlight`, `WakesAt`, `StateEndsAt`.
  Test: `workspace.Bedroom.GiantKid:SetAttribute("WakeMeter", 100)` on the Server.
- Toys in a pen: put a ToyBuilder model in `Hole#.PenToys`; the client roams it (set `RoamSeed`/`Size` if you like).
- A home's look changes live when its `Level` attribute changes.

### Changed from the plan (and why)
- **Signs** float over the middle of each home as transparent text on a BillboardGui that faces the camera (Dylan:
  "should js be transparent and should follow camera movement"), not a board on a lolly stick. "EMPTY HOME" /
  owner name / "YOUR HOME" in gold with an arrow; second line "Lv N · $X/s" or a red "LOCKED 0:32".
- **Tower steps** rise 4.8 (25 steps, 24° apart) instead of 6 (20 steps), so every step is an easy hop.
- **Lighting**: both presets use a high sun through the shadowless ceiling (tinted blue and dim at night, warm and
  bright with the lights on), so the switch is a smooth tween. Roblox's moon was too weak and blue.
- **Locked homes** don't use a solid barrier (it would trap the owner): strangers who walk in are put back outside.
- **Homes are silent** (noise 0) like the safe ring.
- **Floor** uses Roblox materials (Carpet, WoodPlanks) and a plain teal safe ring. The voxel tile path is still there
  (`ServerStorage.TinyToyHeistAssets.FloorTiles`) if the OBJ tiles are ever imported. AI-generated stud/OSB/carpet
  materials were tried and removed: they came out as grates, bricks and garish noise.
- **The train and cat collide with nothing**: hits are checked in code (no physics shoves); you can't ride the train.
- **Hallway**: open door, sign, and an invisible wall 150 studs in (past the door's swing).
- The shop arrow in the HUD now fades out after 12 s (Dylan asked).

### Still to do / open
1. **Reconnect Rojo** in Studio once: the running Rojo can't add the new ServerScriptService node live, so
   `ServerScriptService.Bedroom` in the place is a manual copy of `src/ServerScriptService/Bedroom`. After a reconnect
   Rojo manages it.
2. **The HUD's wake meter and timer are still the demo loop** (`Hud.client.luau`): wire them to the `GiantKid`
   attributes.
3. **No carry system yet**, so no real drag noise; the cat's calm mode reacts to fast movers and carriers only.
4. **The awake Giant** doesn't walk or grab yet; he sits up, sweeps the flashlight and the lights come on.
5. **Sleeping toys (blankets) on the spawns**: `ToySpawns` markers exist; the toy system should put blankets there.
6. **Sounds**: none yet (train rattle, cat bell, creaks, squeaks, trap snap).
7. Home interiors read a bit dark at night next to the render; the pine sides come out brown.
8. Walk speed 16 makes home → door about 100 s; fine with Speed upgrades, but worth a feel test.
9. Open questions in section 11 still stand (scale, keyhole, spawn count, what the safe zone protects from).

---

## 1. Where things stand

### In one paragraph

The Kid's Bedroom is now one long, simple run, like Steal an Egg but at mouse scale. All 8 player homes sit side by
side in a curved wall at the start. Their fronts are open (the drywall is torn away), so you can see into everyone's
home, and inside each home you can look straight up the wall framing (studs, blocking, cables) to the top plate. A teal
safe zone sits in front of the homes. From there the run goes straight down the room through three clearly coloured
floor bands, each with bigger sleeping toys and more noise: carpet (Small), wood (Medium), creaky boards (Large). The
Giant Kid's bed is along one long wall near the end, and the hallway door is open, straight ahead, in the far wall.
Hazards: a winding 5-car toy train, the cat, mouse traps, loose boards, the baby monitor patch and the Kid's flashlight.
Night lighting is the default; when the Kid wakes, the lights come on and the room turns warm and bright (and the cat
gets aggressive).

### Status at a glance

| Thing | State |
| --- | --- |
| Layout (concept v6) | Agreed in renders. Dylan's last messages were small tweaks, all applied. |
| Render page | `design/bedroom-v6-render.html`: live 3D scene, 17 camera views. |
| Rendered photos | `design/renders-v6/*.jpg`, 17 images, 1600 x 900. |
| Review page for comments | Published artifact "Bedroom v6 Renders": https://claude.ai/artifact/PaCsbPzSkmnQH85CyDjnhc (version 2). Private to Dylan. Source: `design/bedroom-v6-review.html`. |
| Written brief | `design/bedroom-map-brief.md`: written early in the session for the old round room. Mostly superseded (see Appendix C). Still useful for the voxel style, palette, lighting ideas and the prompt method. |
| `ReplicatedStorage.Shared.MapConfig` | Unchanged. Still describes the OLD round room (curve radius 930, burrows behind the wall). Must be rewritten for v6. |
| `tools/build-bedroom.luau` | Unchanged. Still builds the OLD round room. Must be rewritten for v6. |
| `tests/MapConfig.spec.luau` | Unchanged. Tests the OLD numbers. Must be rewritten with MapConfig. |
| Studio place | Unchanged this session. `places/TinyToyHeist-Latest.rbxl` was last committed before this session (commit a9973aa). |
| UI (`TinyToyHeistUI`) | Unchanged this session. |
| Git | All work committed on `main` and pushed to GitHub: https://github.com/shdidaxo-pixel/tinytoyheist (private, `origin`). |

### What to do next, in order

1. Read sections 4, 6 and 9.
2. Rewrite `MapConfig` for v6 (Appendix A has a full draft).
3. Rewrite `tests/MapConfig.spec.luau` for the new numbers; get it passing.
4. Rewrite `tools/build-bedroom.luau` for v6, in the order in section 9.
5. Build in Studio Edit mode, take captures from the same angles as the renders, compare side by side.
6. Ask Dylan to Save As `places/TinyToyHeist-Latest.rbxl`; commit.
7. Then the game systems in section 10 (roaming toys, train, cat aggression, lights on).

---

## 2. How to work on this project

### The house rules (from CLAUDE.md and memory)

- **Commit every change.** After each change (code, assets, design files, places): run StyLua and Selene, then commit
  with a short plain message. Don't batch unrelated changes. Videos (`*.mp4`) stay out of git.
- **Save the place every time Studio changes.** Tools can't save a place file. After changing anything in Studio, ask
  Dylan to save with File > Save to File As into `places/TinyToyHeist-Latest.rbxl`, check the file's timestamp, then
  commit it.
- Commit messages end with the co-author line the session gives you.
- Dylan's notes, decisions and devlog live in his Obsidian vault (Games/Tiny Toy Heist). This repo does not hold the
  vault; `Roblox Dev Notes.md`, `Day 1 - Starting Plan.md` and `Toy Catalog.md` in the repo root are snapshots.

### How Dylan likes to work (learned this session)

- **Renders first, then build.** For any visual change of any size, show still photos he can comment on before
  touching Studio. He said it directly: "dont start building, i want renders first, they can just be photos and i can
  just comment on them". The review artifact is how he comments.
- **He sends feedback in quick bursts while you work.** Several messages often arrive mid-task. Fold each one in; don't
  restart from scratch unless the change demands it. Acknowledge each in a line.
- **He thinks in references.** He sends screenshots of Steal an Egg / Break an Egg and photos (lighting, wall framing).
  Save his images into `design/references/` and say what you took from each.
- **Short, plain updates.** He reads quickly. Say what changed and what's next.
- **He decides; you recommend.** When something is his call (scale, layout), give a recommendation and a button-style
  choice, then do it.
- **He likes the voxel style.** Blocky, studded, bright. Keep it, but simpler than we first drew it.

### The method from the videos (deadj.rodev TikToks)

Dylan shared two TikToks and a Google Doc prompt template at the start of the session. The lessons, which this
whole session followed:

- **Maps, 3 steps:** (1) pin down the style and feel; (2) gather reference images that match it; (3) write a short
  prompt that says what, where, why and how. "Make a cool jungle biome" fails. Don't overload the AI with detail;
  prompt without waffle.
- **Models, 4 steps:** idea (role, rarity, what makes it unique) → reference images (AI-generate them if none exist)
  → collect them in one doc with a note under each saying what to take from it → a prompt structured as: protect
  existing work; identity and spawn; look (proportions, detail, colour); idle animations; main mechanic; controls; how
  the movement feels; quality and testing ("take your time and make it right").
- The deadj.rodev jungle-zone example prompt: feel ("lost world, more dangerous and richer than the last zone"), same
  grid walls and floor but recoloured, big trees with layered canopies and vines along both walls, one landmark against
  each wall (temple pyramid; waterfall into a pool), a broken archway, small scatter details, and keep the middle path
  clear.

Both of these are saved in memory (`map-and-model-method.md`).

---

## 3. Repo map

Root: `C:\Users\Dylan Wu\Downloads\Roblox brainrot game`

| Path | What it is |
| --- | --- |
| `CLAUDE.md` | Project rules: commit every change; save the place after Studio changes. |
| `default.project.json` | Rojo project. Maps `src/ReplicatedStorage/Shared` → `ReplicatedStorage.Shared`, `src/StarterPlayer/StarterPlayerScripts/TinyToyHeistUI` → `StarterPlayerScripts.TinyToyHeistUI`, `tests` → `ServerStorage.TinyToyHeistTests`, `tools/build-bedroom.luau` → `ServerStorage.TinyToyHeistTools.BuildBedroom`. |
| `rokit.toml` | Toolchain: rojo 7.7.1, StyLua 2.6.0, selene 0.32.0, luau-lsp 1.70.1. |
| `stylua.toml`, `selene.toml` | Formatter and linter config. Run both before every commit. |
| `src/ReplicatedStorage/Shared/MapConfig.luau` | Every map number, shared by the builder and game code. OLD layout. |
| `src/StarterPlayer/StarterPlayerScripts/TinyToyHeistUI/Hud.client.luau` | The HUD (1525 lines): Shop, Index, rewards, passes. Built in code. |
| `src/StarterPlayer/StarterPlayerScripts/TinyToyHeistUI/UIKit.luau` | UI helpers (841 lines). |
| `tests/MapConfig.spec.luau` | Checks the map numbers hang together (102 lines). OLD layout. |
| `tools/build-bedroom.luau` | Studio Edit-mode map builder (766 lines). OLD layout. |
| `tools/voxel/make-floor-tiles.ps1` | Generates the voxel floor tile OBJs in `assets/floor-tiles`. |
| `assets/floor-tiles/` | `carpet.obj`, `wood.obj`, `creaky.obj`, `floor-tiles.mtl`, `floor-palette.png`. 24x24-stud voxel tiles. The renders use the same OBJ data (embedded as `window.FLOOR_OBJ`). |
| `assets/ui/` | UI icons and pass-card art. |
| `places/TinyToyHeist-Latest.rbxl` | The saved place (committed). `Place save 1.rbxl` is an older save; the `.lock` file is Studio's. |
| `design/bedroom-v6-render.html` | **The current concept.** Three.js scene of v6 with 17 cameras. Open in a browser; drag to orbit. |
| `design/renders-v6/*.jpg` | **The 17 current photos.** |
| `design/bedroom-v6-review.html` | **The review page** (published as the artifact). Numbered photos with captions and notes. |
| `design/bedroom-map-brief.md` | The written brief from early in the session. Mostly out of date (Appendix C). |
| `design/references/bedroom/01-lighting-day.png` | Dylan's photo 1: the lights-on look (voxel kid's room, warm, pastel). |
| `design/references/bedroom/02-lighting-night.png` | Dylan's photo 2: the night look (same room lit deep blue, warm pools at lamp and window). |
| `design/new-map-render.html` | Concept v4, made by another chat: smaller round room, open fenced plots on the floor, hazards. The v6 page was forked from it. |
| `design/game-render.html`, `design/game-render-v1-small-map.html` | Earlier concept renders of the round room from Dylan's first sketch. |
| `design/house-map.html` | Early whole-house map concept. |
| `design/toy-turntables.html`, `design/toy-icons/` | Toy model turntables and icons. |
| `design/blanket-test.html` | Blanket (sleeping toy) look tests. |
| `design/screens/` | UI screenshots: `egg-style/` (Steal an Egg references incl. `stud-tile.png`), `studio/`, `project/`. |
| `Day 1 - Starting Plan.md` | The game plan (pitch, loop, house, threats, toys, holes, raids, progression, money, MVP). |
| `Toy Catalog.md` | All 105 toys, rooms, rarities, money. |
| `Roblox Dev Notes.md` | Dylan's general Roblox notes (Rojo, Studio MCP, building maps in code, lighting). |
| `Thumbnails & Icon/` | Game thumbnails and icon. |
| `Download*.mp4` | Videos. Not in git. |

### Memory files (outside the repo)

`C:\Users\Dylan Wu\.claude\projects\C--Users-Dylan-Wu-Downloads-Roblox-brainrot-game\memory\`

- `commit-and-save-every-change.md`
- `map-and-model-method.md`: the video method; keep voxel models.
- `bedroom-layout-direction.md`: renders first; long simple run; homes in one curved wall, open fronts; door straight ahead.

### Git history from this session

| Commit | What |
| --- | --- |
| 9ad2464 | First (short then long) bedroom map brief. |
| 7c8fb73 | Brief v2: Dylan's decisions, lighting photos, bases inside the wall. |
| d7fe33e | (Other chat) concept v4 render page. |
| 8a66230 | v6 renders: long run, 8 open homes in a curved wall, oval train track. |
| 42bef3e | v6 renders: winding 5-car train, bigger homes with roaming toy pens, levelled wheels, cat pounces with lights on. |
| (this commit) | This handoff. |

---

## 4. What Dylan wants: the design rules

These are the rules every future change should pass. Each one comes from something Dylan said; the quote is in
section 5.

### Layout

1. **One long straight run.** Like Steal an Egg / Break an Egg: you leave your home, run straight down the room,
   grab a toy, run back. Not a round room, not a maze.
2. **Not tiny.** "not super small like theirs, we still want the feeling that we are small." The furniture and walls
   stay giant; the room should still read as a kid's bedroom from a mouse's height.
3. **But not so big the toys look small.** He pushed the room smaller twice ("the room is still a tad too large bc the
   pens are still lowk small"; "it still looks pretty small? maybe shrink a bit more? it has to look reasonable").
   The current room is 420 x 1700 with 320-tall walls; the sleeping toys were made about 35% bigger.
4. **The hallway door is straight ahead** at the far end. "the hallway is in front and not to the side bc then its
   weird." You should be able to keep running and go past it (into the next room, later).
5. **The bed is on a side wall**, so the door can be straight ahead.
6. **Simple and readable.** "it feels like its too crowded, like we cant really tell it apart. also it might be too
   detailed, steal an egg and stuff is a bit more simpler and its visually more appealing to get addicted to." Cut
   props nobody walks to. Keep what matters for play.
7. **Clear floor bands.** Each zone has its own floor and a painted line and label across the run.

### Homes (bases, holes, pens)

8. **All 8 homes together, in one row or a curve, inside the wall.** "i want the homes to be in a row or curved ...
   but i want them inside the wall, def not seperated into two." Never two rows on opposite walls.
9. **A wall between each home.** "i want what we had but i want like a wall between it."
10. **Open fronts, open tops.** "a bit more open so you can see each other's base ... make it just open, cuz i want it
    so you can look up and see the studs and cables." So: drywall torn away at the front; no ceiling inside; studs,
    blocking and cables visible all the way up.
11. **You're mice in the wall.** "i want them in the wall and like where the wood studs and cables are, cuz i want it
    to feel like we are mouses." Wall-framing reference photos: OSB sheathing with studs and staggered blocking; studs
    with white cables stapled up them, outlet boxes and a PVC pipe; mineral-wool insulation between studs.
12. **Toys free-roam in the home**, so homes are bigger. "the toys should be able to freeroam, and bc of that we might
    have to make the bases a bit bigger."
13. **The hamster (Speed) wheel levels up** with the home. "the hamster wheel should level up as well."
14. **A safe zone in front of the homes**, not huge but not a sliver: "we can add a safe spot but we dont have to make
    it huge", then "we can make the safe zone a bit more bigger". Now 140 deep.

### Hazards

15. **Props are solid.** "step over n dodge, you should be able to hit them."
16. **The block tower is climbable** (a lookout). "hmm, yeah sure."
17. **The train is a moving hazard** that covers real distance and isn't just a circle, with 5 cars counting the
    engine. "we need the train to cover more distance?"; "train track shouldnt just be in a circle, you should up the
    carts to 5 total including main".
18. **The cat is more aggressive when the lights are on.** "when lights r on, cat should be more aggressive too lol".

### Look

19. **Voxel, studded, bright**, like his favourite games. "i still like the voxel models."
20. **Lighting from his two photos.** Photo 2 (deep blue night with warm pools at the lamp and window) is the default
    while the Kid sleeps; photo 1 (warm, soft, pastel, lights on) is what the room turns into when he wakes.
21. **Giant Kid as a voxel model**, rebuilt now (not later). "voxel rebuild now."

---

## 5. How we got here: the session, round by round

This section is the history, so nobody re-proposes something Dylan already turned down.

### 5.1 Learning the method

- Dylan sent `Download (7).mp4` (deadj.rodev, "How I make maps like: in 3 easy steps") and `Download (8).mp4`
  ("How I made this model in one prompt with claude"), plus a Google Doc prompt template. Frames were pulled with
  ffmpeg; the doc was exported as text. Lessons in section 2.
- Saved to memory as `map-and-model-method.md`.

### 5.2 The brief (short, then long)

- He asked for a brief for the Bedroom using the video method, to see before building. A short brief was written; he
  said "not short, give me long". The long brief (`design/bedroom-map-brief.md`, 15 sections) covered style, palette,
  references, an audit of the current room, layout (zones, keep-clear lanes, landmarks), furniture rebuild list, props,
  walls, lighting, gameplay checks, budget, the prompt, a done list and open decisions.
- At the time the room was the OLD round one (radius 930, 1200 wide), with burrows behind the curved wall.

### 5.3 Dylan's first decisions and photos

He answered the five open questions:

| Question | Answer |
| --- | --- |
| Props solid or walk-through? | "step over n dodge, you should be able to hit them" |
| Climbable tower? | "hmm, yeah sure" |
| Train? | "moving hazard" |
| Giant Kid voxel rebuild? | "voxel rebuild now" |
| References? | "you generate but ill give some ideas about lighting" |

And two lighting photos: photo 1 ("lighting i like") and photo 2 ("lighting i like for night or something"). Saved as
`design/references/bedroom/01-lighting-day.png` and `02-lighting-night.png`.

Six reference images were AI-generated into a Figma file ("Tiny Toy Heist - Bedroom References",
https://www.figma.com/design/3ZlBNM6Qd9WM7yyJpXaS17): floor-level night view, block tower and train, sock heap and
backpack, voxel Giant Kid asleep, toy clutter on a rug, the whole room with lights on. They could not be downloaded:
the Figma Starter plan hit its MCP call limit. Nobody has reviewed them; they're optional now that renders exist.

### 5.4 The sketch and the other chat

- Dylan asked whether we had "the sketch I made and also the data from the other chat". His original sketch was never
  committed (the repo started at 22:52 on 18 Oct, after that chat) and is not in any local image folder; only its
  layout survives in the old `MapConfig` and the early render pages.
- The "other chat" had committed `design/new-map-render.html` (concept v4) a minute after our first brief: smaller
  round room (radius 600, 840 wide), open fenced plots on the floor instead of burrows, plus hazards (cat, mouse
  traps, loose boards, baby monitor, flashlight at 80+ noise). The v5 and v6 pages were forked from it.

### 5.5 "Bases in the wall"

- Dylan: "wb my idea of how i want the mouse hole plots to look like? i want them in the wall and like where the wood
  studs and cables are, cuz i want it to feel like we are mouses".
- The brief got a full "inside the wall" base section (studs, insulation, cables, outlet, found-object furniture:
  bottle caps, thimble, push pin, matchbook, matchbox bed, spool wheel, fairy light) and level themes inside the wall.
- He chose: use the smaller v4 room (radius 600), keep v4's hazards with traps out of the lanes, bases inside the
  wall. "Start building."

### 5.6 "Don't build yet: renders first"

- Mid-task he said: "but dont start building, i want renders first, they can just be photos and i can just comment on
  them". This set the workflow for the rest of the session (section 7).

### 5.7 Concept v5 (round room, closed burrows): rejected direction

- v5: the v4 round room with burrows behind the curved wall (closed boxes with drywall front and a ceiling), voxel
  furniture, landmarks, clutter, sage walls lit blue. Four test renders only.
- Then a burst of feedback:
  - Homes "more open so you can see each other's base ... look up and see the studs and cables", with three wall
    framing photos (OSB with studs and blocking; studs with white cables, outlet boxes, a PVC pipe; mineral wool).
  - "too cramped ... steal an egg or break an egg ... its very long, and i want something like that, the bed should
    lowk be on the side so then the hallway door can be straight ahead".

### 5.8 Concept v6, first try: bases down both long walls: rejected

- Long room (600 x 1400, then 500 x 2100), open bays in the framing down both long walls (4 per side) in a big teal
  safe zone.
- He sent a Steal an Egg screenshot ("see how its long?") and asked for less clutter and fewer details.
- Then: "no i dont want a seperation from the mouse spots, i want what we had but i want like a wall between it, we
  can add a safe spot but we dont have to make it huge. i want the homes to be in a row or curved ... inside the wall,
  def not seperated into two". So: all homes together in one curved wall at the start, wall between each.

### 5.9 Concept v6 as it is now

Changes in the order they landed:

1. All 8 homes in a half-circle wall at the start (keyhole plan), open fronts, wall between each.
2. Clutter cut: no sock heap, bookshelf, rug, beanbag, scattered crayons/marbles/cars/socks; the toy chest and posters
   on the start wall went when the start wall became the homes.
3. "i also think, we are too small? ... the room is still a tad too large bc the pens are still lowk small, but i wanna
   see your update first" → shown first, then:
4. "we can make the safe zone a bit more bigger" → safe zone from 60 to 140 deep.
5. "we need the train to cover more distance?" → the train track went from a small circle round the tower to a long
   oval down the run.
6. "it looks like the blanket over stuff, it still looks pretty small? maybe shrink a bit more? it has to look
   reasonable" → room shrunk to 420 x 1700, walls 320; bed and furniture scale 1.5 → 1.25; blanket toys about 35%
   bigger (Small 1.15, Medium 1.4, Large 1.9).
7. "train track shouldnt just be in a circle, you should up the carts to 5 total including main" → a winding loop that
   snakes down both sides and crosses the run twice; 5 cars.
8. "the hamster wheel should level up as well, the toys should be able to freeroam, and bc of that we might have to
   make the bases a bit bigger" → homes 130 x 170 (were 120 x 110); the back of each home is a toy pen dressed for the
   level; toys wander it; the Speed wheel levels up (7 looks).
9. "when lights r on, cat should be more aggressive too lol" → in the lights-on preset the cat leaves its patrol and
   pounces at a mouse, with a red "!".
10. "ok commit n push, save it so we can start. make handoff.md" → this file.

### 5.10 Things Dylan turned down (don't bring back)

| Idea | Why it went |
| --- | --- |
| Round room with holes on the curved front wall (the original) | Too cramped; he wants a long run. |
| Closed burrows with a ceiling and a drywall front | He wants open fronts and to look up the framing. |
| Open fenced plots on the floor (v4) | He wants homes inside the wall. |
| Homes split down both long walls | "def not seperated into two." |
| A huge safe zone covering the base area | "we dont have to make it huge" (but later "a bit more bigger": 140 deep now). |
| A detailed, prop-heavy room (books, clutter, sock heap, posters, rug, beanbag) | Too crowded and hard to read; Steal an Egg is simpler. |
| Hallway door off to the side | "its weird"; it must be straight ahead. |
| A train going round in a small circle | Must cover distance and not be "just a circle". |

---

## 6. Concept v6: the full spec

Every number here is read from `design/bedroom-v6-render.html` as committed. The render uses Roblox studs as units,
so these numbers can go straight into `MapConfig`.

### 6.1 Coordinates and left/right

- **x** runs across the room. **z** runs down the room, from the start (the homes) to the far wall (the hallway door).
  **y** is up. The floor is at y = 0.
- The room is symmetric about x = 0.
- **Left and right always mean as a runner sees it, facing down the run (+z).** A runner facing +z has **+x on their
  LEFT** and **-x on their RIGHT**. So: the desk, window, night-light and block tower are on the LEFT (x > 0); the bed
  and nightstand are on the RIGHT (x < 0). The code comments in the render page sometimes say "left wall" for x < 0;
  trust this paragraph and the numbers, not those comments.
- A player avatar is about 5.3 studs tall (the render's avatar is the default R15-ish block figure).

### 6.2 Room shell

| Part | Number | Notes |
| --- | --- | --- |
| Run width | 420 (`HW` = 210) | Long walls at x = ±210 (inner face); walls 8 thick, centred at ±214. |
| Run length | 1700 (`LEN`) | Start of the room z = 0 (behind the homes); far wall inner face at z = 1700. |
| Wall height | 320 (`WALL_H`) | Was 360 before the last shrink. |
| Start area | Half-circle, radius 380 (`CR`), centre (0, 380) (`CZ0`) | The homes sit round this curve. Its outer edge (front of the homes) runs from (-380, 380) round the back (0, 0) to (380, 380). |
| Shoulders | From (±390, 380) to (±210, 510) (`SH_Z` = 510) | Angled walls joining the wide start area to the narrower run. Length about 221. |
| Long walls | x = ±210, from z = 510 to 1700 | Wallpapered; cream baseboard 15 tall. |
| Far wall | z = 1700, with the door centred | Door 130 wide (`DOOR_W`), 230 tall (`DOOR_H`), x -65..65. |
| Ceiling | y = 320 | Dark navy at night, cream with the lights on. Covered in glow-star stickers. |

The plan is a keyhole: a 780-wide half-circle at the start, narrowing to a 420-wide run. It has to be wider at the start
to fit 8 homes, each 130 wide plus walls, round a curve. (Open question: section 11.)

### 6.3 Floor bands

| Band | z range | Floor | Toys | Noise | Line at its start |
| --- | --- | --- | --- | --- | --- |
| Safe zone | Ring r 240..392 round (0, 380), in front of the homes | Teal studded mat (stud texture, colour #4FC6A8) with a white edge line at r 235..240 | None | None (safe) | White ring |
| Carpet | From the start area to z 900 (`CARPET_Z`) | Purple voxel carpet tiles (`carpet.obj`) | Small | x1 | — |
| Wood | 900–1300 (`WOOD_Z`) | Voxel wood tiles (`wood.obj`) | Medium | x2 | Yellow tape line (#FFD43B), 8 wide, across the run at z 900 |
| Creaky boards | 1300–1700 | Dark voxel creaky tiles (`creaky.obj`) | Large | x3 | Red tape line (#FF5A5A) at z 1300 |

- The centre of the half-circle inside the safe ring (r < 240) is carpet.
- Floor tiles: 24 x 24 studs, the same OBJ tiles as today's builder. Carpet tiles turn by multiples of 90° in a fixed
  pattern; wood and creaky by 0° or 180°.
- Painted floor labels (Lilita One font, white with a dark outline, lying flat, reading toward the far end):
  - "CARPET · SMALL" at (0, 560), 250 wide.
  - "WOOD · MEDIUM · NOISE x2" at (0, 950), 300 wide.
  - "CREAKY · LARGE · NOISE x3" at (90, 1350), 300 wide.

### 6.4 Walls and paint

- **Paint:** sage green #9DB08A, painted in its true colour. The night lighting turns it blue-grey; the lights-on
  preset shows it as sage. This was the main lesson from Dylan's two photos.
- **Wallpaper:** darker sage stripes (#8A9E78 with #97AA84 bands, 128-px repeat on a 256-px tile = 48 studs) on the
  bottom 120 studs, a cream rail (#F1EBDD) at 120, plain sage above, cream crown at the top.
- **Baseboards:** cream #E6E1D6, 15 tall, 3 deep.
- **The walls between homes** are sage solid prisms (see 6.6).

### 6.5 The homes: where they are

8 homes, indices 0..7, round the half-circle. Home i faces the centre of the curve (0, 380).

- Angle: `HOLE_A(i) = 270 + (i - 3.5) * 22.5` degrees, measured like a maths angle in the x/z plane
  (x = r cos a, z = 380 + r sin a). 270° points at z = 0 (straight back from the centre).
- The middle of home i's open front: `(380 cos a, 380 + 380 sin a)`.

| i | Angle | Front centre (x, z) | Render owner | Level | Toys | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| 0 | 191.25° | (-372.7, 305.9) | kayla_rbx | 3 Toy bricks | 9 | Right end of the curve (runner's view from the run looking back: far left) |
| 1 | 213.75° | (-316.0, 168.9) | Bloxer99 | 1 Cardboard | 3 | Locked (red bars) |
| 2 | 236.25° | (-211.1, 64.0) | zzz_ninja | 5 Candy land | 12 | |
| 3 | 258.75° | (-74.1, 7.3) | **You** | 2 Sock-lined | 5 | Gold sign, bouncing arrow |
| 4 | 281.25° | (74.1, 7.3) | mia.ttv | 7 Golden vault | 17 | A raider (sneakyPete) inside |
| 5 | 303.75° | (211.1, 64.0) | Dino_King | 4 Cosy cabin | 10 | |
| 6 | 326.25° | (316.0, 168.9) | sneakyPete | 1 Cardboard | 2 | |
| 7 | 348.75° | (372.7, 305.9) | toyhunter | 6 Arcade neon | 14 | |

Each home's local frame: origin at the middle of its open front, on the floor; **local +Z points into the room** (toward
(0, 380)); local −Z goes back into the wall; local +X = (−sin a, 0, cos a) in world terms. Positions inside a home use
the MapConfig "burrow" convention: `lx` across (walking in, −lx is on your right) and `lz` deep from the front.
In the render, a point (lx, lz) inside home i is at local (−lx, −lz), and its world position is
`front + (−lx)·X − lz·n` where n = (−cos a, −sin a) is the into-the-room direction.

### 6.6 The homes: the shell

| Part | Size (studs) | Where (home local) | Look |
| --- | --- | --- | --- |
| Opening | 130 wide (`BW`), 170 deep (`BD`), open up to the top plate | x −65..65, z 0..−170 | No front wall, no ceiling. |
| Subfloor | 140 x 1 x 170 | top at y 0 | OSB texture (chipboard flakes, "APA RATED" stamp). |
| Back sheathing | 140 x 320 x 2 | z = −171 | OSB, full height. Level 7: gold. |
| Side studs | 5 x 320 x 170 each | x = ±67.5 | Pine #E2B77C, full depth; they are the home's side walls. Level 7: gold. |
| Back studs | 8 x 320 x 10 each | x = ±30, against the back | Pine. They split the back into 3 bays. |
| Blocking | Flat 2x4s, 8 tall x 10 deep | Between the studs at y = 120 and 240; the middle bay 6 higher (staggered, as in Dylan's photo) | Darker pine #C9A066. |
| Top plate | 140 x 8 x 170 | y = 312..320 | Darker pine. This is what you see when you look up. |
| Torn drywall | Pieces 14 tall, 3–11 wide, 4 deep, all the way up both front edges | x = ±(70 − w/2), z ≈ −1 | Off-white #F2EFE8; jagged so it reads as drywall ripped away. |
| Wall between homes | A solid prism from home i's front-right corner to home i+1's front-left corner, 178 deep, full height | — | Sage sides with wallpaper. At the front it's about 8 studs thick, widening toward the back because of the curve. |
| End walls | Prisms from (±390, 380) to the outer corner of home 0 / home 7 | — | Same. |

Corner maths: home i's front corners are at local x = ±(BW/2 + 5) = ±70. For CR = 380 the chord between neighbouring
home centres is 2·380·sin(11.25°) = 148.3, so the gap between neighbours' front corners is about 8.3 studs. **Don't
reduce CR below about 370 or raise BW above about 140 without redoing this**, or the homes touch at the front.

### 6.7 The homes: what's inside

| Part | Where (lx, lz) or local | Size | Look |
| --- | --- | --- | --- |
| Cables (white) | Two vertical runs up the back studs, local x = 26 and −34, from the floor or the outlet to the top plate | Tube radius 1.1 | Off-white #F4F1E8, slight wobble, stapled every ~90 (grey staples 3 x 1.2 x 1.6). |
| Cable (yellow) | Horizontal across the back at y ≈ 60–64, sagging between studs | Tube radius 1.1 | #F2C94C. The fairy light hangs off it. |
| Outlet box | local (30, 24, −158) | 9 x 13 x 5 | Blue #3A6FD8, with two glowing slits (#FFC070). |
| Fairy light | 9 bulbs along the yellow cable, x −50..50 | Bulbs radius 1.2 | Alternating cream and the level colour, with soft glow sprites that twinkle. PointLight at (0, 50, −85), range 120, the level colour, intensity 1 (1.3 at Level 6). |
| Toy pen | Floor panel from lz 40 to lz 158, 116 wide | 116 x 0.6 x 118 | Level material (table below). The toys roam here. |
| Cash pile (`CashPile`) | lx 28, lz 14 | Thimble 5.5 radius, 8 tall, open top | Steel thimble with gold coins heaped in it and a few spilled. |
| Lock button (`LockButton`) | lx −30, lz 12 | Push pin: base 4.5 r, waist 2.4–3 r, cap 3.6 r, about 10.4 tall | Red #FF4D5E (dark red #8A1F2A when locked), tilted slightly. |
| Toy Index (`IndexBook`) | lx −52, lz 30 | Domino stand 9 x 5 x 5, matchbook on top | Black domino with white pips; red and cream matchbook propped open. |
| Speed wheel | lx 50, lz 22 | Grows with level (6.8) | Spins. Tag "SPEED · Lv N". |
| Spawn | lx 0, lz 24 | Matchbox bed 16 x 3.4 x 10 | Tan drawer, blue sleeve, striped sock-scrap blanket; green ring on the floor (r 9..10.5). |
| Sign (`Sign`) | local x 54, z −3, planted at the front corner | Lolly stick 2.4 x 46 x 1.4; board 34 x 17 at y 48 | Board in the owner's colour: name (or "YOU", gold) and "Lv N · $X/s" (or "LOCKED 0:32" in red). |
| "YOU" arrow | above your sign, y 66 | 9 x 9 sprite | Gold ▼, bobbing. |
| Lock bars (`LockBars`) | across the opening, local z +1 | 12 bars, radius 0.8, 30 tall, 10 apart, plus a top bar | Red with a faint glow. Only when locked. |

The prop positions are today's `MapConfig.BURROW_LAYOUT` values, so game code that finds these by name keeps working.

### 6.8 Level themes

| Level | Theme (from the plan) | Back of the bays | Toy pen floor | Fairy light | Speed wheel |
| --- | --- | --- | --- | --- | --- |
| 1 | Cardboard | Brown mineral wool batts (#A88A62 / #8E7350), lumpy, full height (Dylan's photo 3) | Plain cardboard #C49A6C | Warm #FFD27A | Cardboard spool (#D9B27C sides, #FFC93C rungs), radius 7.05 |
| 2 | Sock-lined | Odd socks stretched over the bays, 110 tall (pink, blue, yellow stripes) | Pink and white striped sock fabric | Pink #FFB0C8 | Pink sock-striped sides, white rungs, radius 7.6 |
| 3 | Toy bricks | Pink insulation (#F2A6B8 / #E58BA1) | Blue studded brick plate | Yellow #FFE08A | Red sides, yellow rungs, blue rims, radius 8.15 |
| 4 | Cosy cabin | Matchstick panelling 100 tall (cream sticks, red heads) | Light wood planks | Orange #FF9A4A | Wood sides, cream rungs, dark rims, radius 8.7 |
| 5 | Candy land | Sweet wrappers (22, shiny, five colours) | Pink and white candy stripes | Pink #FF8FC8 | Pink sides, white rungs, mint rims, radius 9.25 |
| 6 | Arcade neon | Plain OSB with LED strips (cyan, pink, purple) at y 50/90/130 | Dark with neon cyan edge strips | Cyan #7AE8FF (brighter) | Dark sides, glowing cyan rungs, purple glowing rims, radius 9.8 |
| 7 | Golden vault | Gold everywhere: back sheathing, studs | Gold | Gold #FFE07A | Gold sides, pale gold rungs, gold rims and glow, radius 10.35 |

Wheel maths: radius `6.5 + 0.55·L`, width `7 + 0.3·L`, rungs `14 + 2·L`, spin `1.2 + 0.25·L` rad/s, rims from
Level 3, glow at Levels 6 and 7. Its hub sits at height radius + 2.2.

Home levels and slots in the plan (unchanged): L1 6 slots (free), L2 8 ($500), L3 10 ($5,000), L4 12 ($50,000), L5 15
($500,000), L6 18 ($5M), L7 20 ($50M + Rebirth 1); VIP Hole adds 3. With roaming toys, "slots" become capacity, not
spots (section 10).

### 6.9 Toys in the homes

- Awake toys are the same blocky placeholder shapes as the concept renders (three sizes S/M/L built from boxes,
  each with two black eyes), in the 10 toy colours.
- Count per home = the owner's toys (render data in 6.5). Size pattern: every 5th toy Large, odd ones Medium, else
  Small.
- **They roam the pen.** Each toy picks a random spot in the pen (inset 6 from the sides and back, 4 from the front of
  the pen), walks there at about 2.1–3.4 studs/s (Large slowest) with a hop, turns to face where it's going, pauses
  0.6–3.1 s, then picks another.

### 6.10 Furniture

All are simple, big, voxel pieces against the walls. Nothing sits in the middle of the run.

**Bed and Giant Kid** (RIGHT side, x < 0)

- Built in the old v3 units inside one group scaled **1.25**, positioned at **(−110, 0, 1600)** and turned **180°**,
  so the headboard is toward the far wall and the long side is along the right-hand wall.
- World footprint about x −210..−10, z 1275..1600.
- Parts (v3 units, ×1.25): blocky headboard 150 x 86 x 10 with a stepped top (126, 92, 46 wide steps), a dark band at
  40, square posts 14 x 112 x 14 with caps at x ±80, three glowing star stickers; legs 16 x 12 x 16 like tree trunks at
  (±74, 22) and (±74, 258); frame 160 x 24 x 250 with a dark band; mattress 150 x 20 x 240 with a seam; stepped
  pillow; quilted royal-blue duvet (3x3 squares in #2F6FB9 / #3878C4 with dashed stitching on top; plain blues on the
  drapes), a corner folded back (white diamond).
- The Kid: a stepped lump under the duvet (74 x 14 x 124 plus 58 x 10 x 106) that breathes; voxel head 44 x 40 x 38
  with a painted sleeping face (closed eyes, rosy cheeks, open mouth, drool, a snot bubble that grows and pops), brown
  hair block with five tufts, a voxel teddy on the pillow, his striped-pyjama arm hanging off the side into the room
  (mirrored to the room side, local x −84) with a hand and fingers on the floor.
- Floating "Z" sprites rise from his head at about (−110, 125+, 1535).
- Sitting-up version (shown when the flashlight is on and with lights on): pyjama body, angry face, arm holding a
  flashlight; the beam sweeps `tx = 140·sin(0.5t)`, `tz = 1000 − 300·|sin(0.5t)|`, a spotlight plus a visible cone and a
  pool of light on the floor.

**Nightstand** (RIGHT side, by the bed's head): group at (−172, 0, 1650). Box 72 x 78 x 72, top 78 x 6 x 78 at y 78,
two drawer fronts facing the room with gold knobs. On top: a stepped lamp (shades 38/31/22 wide at y 104/113/122,
glowing warm), a red alarm clock reading "2:00", and the baby monitor (at world (−152, 84, 1670)).

**Desk** (LEFT side, creaky band): group at (158, 0, 1420), turned so its front faces the room. Top 180 x 9 x 105 at
y 108 (spans world z 1330..1510, x 106..210), studded top, thick legs, a drawer block; an old beige computer with a
green glowing screen ("> TINY TOY OS / > 3 TOYS FOUND / > ZZZ... / > _"), a keyboard; a red chair pushed in at world
x ≈ 76.

**Window** (LEFT wall, above the desk): z 1320..1520, y 155..305, on the x = +210 wall. Blinds: slats every 7.5 with
warm-white light glowing between them (photo 2's streetlight look), a cream frame and sill. Light stripes fall on the
floor through the slats (additive warm strips, projected along direction (−1, −1.7, 0.06)).

**Night-light** (far wall, LEFT of the door): an outlet plate at (150, 6, 1699) with a glowing dome night-light at
y 18, warm #FFD27A.

**Hallway** (beyond the far wall): the door is open, swung 72° into the hallway (hinged at x = −65). Beyond: a wood
floor 190 wide x 420 long, purple-grey walls, a warm light at the far end, and a sign over the door, "HALLWAY · NEXT
ROOM SOON".

**Removed** (don't add back without asking): toy chest, bookshelf, beanbag, cardboard boxes, sock heap, backpack,
rug, wall shelf, posters, scattered clutter (crayons, marbles, cars, socks, drawings, buttons, dust bunnies), fairy
light swags on the room walls, the star projector.

### 6.11 The block tower

- LEFT side of the carpet band, centred at **(45, 800)**.
- Four 30-stud letter blocks stacked to 120 (A red, B blue, C yellow, D green), each nudged and turned a little so the
  stack leans. Studded top at y 120.
- A spiral of 20 toy-brick steps (22 x 4 x 13, studded) at radius 27 round the stack, 30° apart, rising 6 per step,
  starting at 200°: you can climb to a lookout on top.
- A fallen letter block "E" (purple, 30 cube) lies at (−188, 0, 760), turned 0.6 rad, as a hiding spot.
- The render puts a player (kayla_rbx) on top as a lookout.

### 6.12 The train

- **Track:** a closed, smooth loop (centripetal Catmull-Rom) through these 16 points (x, z), in order:

  (140, 640) → (175, 760) → (125, 880) → (165, 1000) → (115, 1120) → (140, 1220) → (40, 1250) → (−70, 1235) →
  (−150, 1170) → (−105, 1050) → (−160, 930) → (−100, 810) → (−150, 700) → (−110, 610) → (−20, 585) → (70, 600) → back.

  It snakes down the LEFT side (x > 0), crosses the run near the bed (z ≈ 1240), snakes back up the RIGHT side, and
  crosses again near the start of the carpet band (z ≈ 590). **Length 1841 studs.**
- **Track look:** wooden bed 11 wide, 1.6 tall, laid as short segments every ~4.2 studs; two dark grooves 4.8 apart.
- **Train:** 5 cars (engine + 4), each scaled 1.4: red engine (cab, chimney, a lamp on the front), then blue, green,
  yellow and purple wagons with block cargo. Cars 27 studs apart along the track.
- **Speed:** 60 studs/s, so a lap takes **30.7 s**. Cars bob slightly.
- **Gameplay (to build):** the train is a moving hazard: it knocks you over and you drop a carried toy; it's loud
  (adds noise near it); you hear it coming. The track is flat and walkable.

### 6.13 The cat

- Big voxel orange tabby: body 70 long with darker stripes, cream belly, legs, head with glowing yellow-green eyes,
  whiskers, pink nose, ears; red collar with a gold bell; a swishing block tail.
- **Lights off (default):** crouched at (−20, 0, 1150), turned 0.4 rad, on the wood band. Patrol shown as orange dots
  on an ellipse centred (0, 1150), 150 wide each side, 60 deep each side.
- **Lights on:** aggressive. It leaves its patrol and pounces: moved to (−40, 7, 1030), facing a nearby mouse, tilted
  0.18 rad mid-leap, with a red "!" badge above it.

### 6.14 Other hazards

| Hazard | Where | Look | Gameplay (to build) |
| --- | --- | --- | --- |
| Mouse traps | (−188, 850) turned 0.15; (190, 880) turned −0.15; (−188, 1150) turned 0.1; (190, 1290) turned −0.1 | Wooden "VICTOR" trap 30 x 14, steel bail and spring, cheese on the trigger, faint red glow | SNAP: you drop your toy and go home. Always near the walls, never in the middle of the run. |
| Loose boards | Creaky band: (20, 1320), (70, 1400), (10, 1470), (60, 1550), (20, 1615), (90, 1600) | Planks 32 x 6.8 lifted at one end, dark gap, two nails | Step on one: a loud creak (big noise spike). |
| Squeaky ducks | (50, 1360), (85, 1500) | Yellow rubber ducks | Step on one: a squeak (noise). |
| Toy bricks | (−30, 1000), (50, 1180), (40, 1300), (0, 1440), (60, 960); the 1st, 3rd and 5th have a second brick stacked | Studded 2x4 bricks | Solid; knocking into them clacks (noise). |
| Baby monitor patch | Green circle radius 105 centred (40, 1420), with a "NOISE x2" tag; the monitor sits on the nightstand with pulsing signal arcs | Additive green disc and ring | Noise inside counts double. |
| Flashlight | The Kid sits up at 80+ noise | Beam sweeping back down the run | Caught in the beam carrying a toy: you drop it. |

### 6.15 Sleeping toys (blanket spawns)

Rows down each band, like eggs down a run in Steal an Egg. Each candidate gets a small fixed jitter (±6 in x, ±7 in z)
and is dropped if it lands on furniture, within 6 + r of a wall, or near the train track (within 8 + r of it).

| Size | Rows (z) | Columns (x) | Odd rows shift | Blanket scale |
| --- | --- | --- | --- | --- |
| Small | 590, 680, 770, 860 | −80, −25, 30, 85 | −25 | 1.15 |
| Medium | 950, 1040, 1130, 1220 | −70, −5, 60 | +25 | 1.4 |
| Large | 1330, 1430, 1530 | 12, 58 | +20 | 1.9 |

That's up to 16 Small, 12 Medium and 6 Large; a few get dropped by the track and furniture checks. The plan says 48
spawns in the room; the render shows fewer on purpose (readability). For the game, decide the real count (section 11).

Blankets are the hand-sculpted cartoon lumps from the earlier renders (soft dome, folds, wavy hem, rolled lip, dark
outline, toon shading), one of 10 colour pairs and 4 patterns each; a few glow on and off (rare toys peeking).

### 6.16 Lighting

**Night (default, Dylan's photo 2)**

| Setting | Value |
| --- | --- |
| Background / fog colour | #10163A; fog from 1800 to 4200 |
| Hemisphere light | sky #4058D8, ground #15132E, 0.55 |
| Ambient | #26348A, 0.22 |
| Moon (directional) | #9DB4FF, 0.34, from (500, 900, 1100) toward (0, 0, 850), soft shadows (4096 map, ±1100) |
| Lamp (nightstand) | #FFA552, 2.4, range 460, decay 2, shadows |
| Window spotlight | #FFD9A0, 1.2 |
| Desk monitor | #6BFF7A, 0.9, range 170 |
| Night-light | #FFD27A, 0.8, range 180 |
| Hallway light | #FFC27A, 0.9, range 520 |
| Ceiling colour | #1B2142 |
| Tone mapping | ACES filmic, exposure 0.98 |

**Lights on (Dylan's photo 1; when the Kid wakes)**

| Setting | Value |
| --- | --- |
| Background / fog colour | #EDE3D0 |
| Hemisphere light | sky #FFF3DE, ground #9A8466, 1.1 |
| Ambient | #FFF1DC, 0.42 |
| Moon | off |
| Sun (directional, warm) | #FFE6C4, 0.6, from (450, 1000, 600) toward (0, 0, 850), soft shadows |
| Ceiling light (point) | #FFE9C8, 1.05, at (0, 290, 850), range 3200 |
| Lamp | 3 |
| Window | 0.35 |
| Monitor | 0.45 |
| Night-light | 0.25 |
| Ceiling colour | #EFE8D8 |
| The Kid | sitting up; the cat pounces |

In the game: night by default; on wake-up, tween to lights-on in about 0.4 s; back to night over about 3 s when he
falls asleep (brief section 10). Store both presets in a small shared module (`BedroomLighting`).

### 6.17 Text and fonts in the renders

Lilita One (display: signs, floor labels, letter blocks), Nunito (UI text, tags), JetBrains Mono (the clock and the
computer screen). In Roblox, use the game's existing UI font choices (the HUD uses Gotham, like Break and Steal an
Egg) and SurfaceGuis for signs.

---

## 7. The render pipeline

This is how concepts get shown to Dylan. Use it for every layout or look change before building in Studio.

### 7.1 The pieces

| Piece | Path | What it does |
| --- | --- | --- |
| Render page | `design/bedroom-v6-render.html` | A single HTML file: three.js r128 from cdnjs (plus OrbitControls and OBJLoader from jsDelivr), the voxel floor tile OBJs embedded as `window.FLOOR_OBJ`, and the scene script. Shows a live, orbitable view, camera buttons, a gallery of stills (from `renders-v6/<cam>.jpg`), and a numbers table. |
| Still mode | `?shot=1&cam=<name>` | Hides everything except the 3D view, full window, at that camera. This is what the renderer screenshots. |
| Renderer | `render-all.sh` (in the session scratchpad; copy below) | Runs headless Chrome on each camera and saves a JPEG. |
| Photos | `design/renders-v6/<cam>.jpg` | 1600 x 900. |
| Review page | `design/bedroom-v6-review.html` | Numbered photos with captions, a "What changed" box and a "Still to decide" box; click a photo to enlarge. Published as the artifact so Dylan can comment. |
| Review artifact | https://claude.ai/artifact/PaCsbPzSkmnQH85CyDjnhc | "Bedroom v6 Renders". Private to Dylan. Republish from the same file path in the same session; from a new session pass this URL as `url` after reading it. |

### 7.2 How the scene script is organised

The scene script is one IIFE, roughly in this order. Function names to search for:

| Function / const | Builds |
| --- | --- |
| constants at the top (`HW`, `LEN`, `WALL_H`, `BW`, `BD`, `N`, `CR`, `CZ0`, `STEP`, `HOLE_A`, `SAFE_R`, `CARPET_Z`, `WOOD_Z`, `SH_Z`, `DOOR_W`, `DOOR_H`) | All the room numbers. Change these first. |
| `PC`, `HOME`, `corner`, `BP` | Curve and home-frame maths. `BP(i, lx, y, d)` = world point inside home i (used by cameras). |
| `M`, `box`, `textSprite`, `canvasTex` | Helpers (material, box with its bottom at y, sprite text, canvas texture). |
| `WALLPAPER`, `wallMat`, `osbTex`, `floorLabel`, `plankTex` | Textures. |
| `prism` | A wall-high prism over a floor outline (walls between homes). |
| `buildRoom` | Floor outline, safe ring, zone lines, labels, the curved wall prisms, shoulders, long walls, far wall, door, hallway, ceiling, stars. |
| `voxelFloor` | Lays the 24-stud OBJ tiles by band (`kindAt`). |
| `studTex`, `signTex`, `awakeToy`, `roam`, `padMesh`, `trainingWheel`, `TOY_COLS` | Copied from concept v4. |
| `THEMES`, `FAIRY`, `SLOTS_AT`, `BASES`, `SLOT_OFFS`, `stripeTex`, `tube` | Home data and helpers. |
| `baseInterior(i, pl)` | One home: shell, framing, insulation/theme dressing, cables, outlet, fairy light, toy pen with roaming toys, cash pile, lock pin, Index, level wheel, spawn bed, sign, lock bars. |
| `penToys`, `penRoam`, `levelWheel` | Roaming toys and the levelled wheel. |
| `bases` | Calls `baseInterior` for all 8. |
| `studTop`, `LAMP`… | Studded top surfaces; light handles. |
| `bedAndGiant` | The bed and Kid in the scaled group `big`. |
| `furniture` | Nightstand (lamp, clock), desk, window and floor stripes, night-light. |
| `sitUpKid`, `setFlash` | The sitting-up Kid and his flashlight beam (copied from v4, beam retargeted). |
| `PALS`, `PATS`, `fabricTex`, `blanketMesh`, `SHAPES`, `glow`, `starTex` | Sleeping-toy blankets (copied from v4). |
| `letterTex`, `TOWER`, `TRACK_CURVE`, `trackPt`, `nearTrack`, `blockTower` | Tower, track, train. |
| `cat`, `mouseTrap`, `squeakyDuck`, `babyMonitor` | Copied from v4, repositioned. |
| `FOOT`, `FOOT_C`, `blocked`, `looseBoards`, `brick`, `hazards` | Footprints for keep-clear checks; hazards. |
| `spawns`, `SPAWN_PTS` | Sleeping toys. |
| `faceDecal`, `avatar`, `animateAvatar`, `faceToward`, `players` | Player figures in the photos. |
| `setLights`, `buildCams`, `goCam`, `init`, `resize`, `loop` | Lighting presets, cameras, setup, render loop. Init waits for the web fonts first. |

### 7.3 Rendering stills

Use headless Chrome (installed at `C:\Program Files\Google\Chrome\Application\chrome.exe`). Headless Edge with
SwiftShader works but is far too slow; Chrome uses the GPU and does a still in about 25 seconds.

The script used this session:

```bash
#!/bin/bash
# Render camera views of a render page to design/<outdir>/<cam>.jpg with headless Chrome, 2 at a time; re-render
# any that come out black (the GPU sometimes drops a frame when several run at once).
# usage: render-all.sh <page.html> <outdir> cam1 cam2 ...
cd "/c/Users/Dylan Wu/Downloads/Roblox brainrot game"
PAGE=$1; OUTDIR=$2; shift 2; RUN=$(date +%s)
SCR=<a scratch folder>
mkdir -p "design/$OUTDIR" "$SCR/png"
one(){ local cam=$1 slot=$2 try
  for try in 1 2 3; do
    local png="$SCR/png/$cam.png"; rm -f "$png"
    timeout 150 "/c/Program Files/Google/Chrome/Application/chrome.exe" --headless=new --window-size=1600,900 --hide-scrollbars \
      --user-data-dir="$(cygpath -w "$SCR/cprof/$RUN-$slot")" --virtual-time-budget=6000 --screenshot="$(cygpath -w "$png")" \
      "file:///C:/Users/Dylan%20Wu/Downloads/Roblox%20brainrot%20game/design/$PAGE?shot=1&cam=$cam" >/dev/null 2>&1
    [ -f "$png" ] || continue; ffmpeg -v error -y -i "$png" -q:v 3 "design/$OUTDIR/$cam.jpg"
    [ "$(stat -c %s "design/$OUTDIR/$cam.jpg")" -gt 60000 ] && { echo "done $cam"; return; }
  done; echo "BLACK $cam"; }
i=0; for cam in "$@"; do one "$cam" $((i%2)) & i=$((i+1)); if (( i % 2 == 0 )); then wait; fi; done; wait
```

Run it from Git Bash, e.g. `bash render-all.sh bedroom-v6-render.html renders-v6 hero homes yours`. All 17 views take
about 10 minutes. Run it with `run_in_background` and wait for the notification; don't use `nohup … &` (the job dies
when the shell resets and you get no notification).

**Rules that came from things going wrong:**

- **Delete the PNG before each run** and **use a fresh `--user-data-dir` per run.** If a stopped batch leaves headless
  Chrome processes running, they lock the profile; new runs then fail silently and the script used to convert the
  previous run's stale PNG. This produced "new" photos that were actually old.
- **Never stop a render batch without cleaning up its Chrome processes.** Kill only ours, never Dylan's own Chrome:
  ```powershell
  Get-CimInstance Win32_Process -Filter "name='chrome.exe'" | Where-Object { $_.CommandLine -like '*cprof*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
  ```
- **Two at a time, not three.** Three parallel GPU renders drop frames (black images). The script retries anything
  under 60 KB up to 3 times.
- **`--virtual-time-budget=6000`** lets the animations run about 6 s of scene time before the shot (train moved, toys
  wandered, fairy lights twinkling).
- **Fonts:** the page waits for Lilita One, Nunito and JetBrains Mono before building, so canvas labels use them.

### 7.4 Checking the page

- Open it in the browser pane (`file:///C:/Users/Dylan%20Wu/Downloads/Roblox%20brainrot%20game/design/bedroom-v6-render.html`)
  and read the console for errors. The tab title becomes "ready" after 40 frames.
- The browser pane loads local files as a `data:` snapshot; it **cannot** `fetch` to localhost (a little PowerShell
  upload server was tried to save canvas captures and the pane blocked it). That's why stills come from headless
  Chrome.

### 7.5 Adding or changing a camera

Cameras live in `buildCams()` as `[key, label, {pos, look, cap, top?, xray?, flash?, day?}]`. `top` hides the
ceiling and drops the fog (top-down); `xray` hides the ceiling and stars; `flash` shows the sitting-up Kid with the
beam; `day` switches to the lights-on preset. Add the key to the review page's `PHOTOS` list, render it, republish.

### 7.6 Publishing the review page

- The review page references `renders-v6/<cam>.jpg`; publish with `files` mapping each `renders-v6/<cam>.jpg` to the
  local file (17 entries). Same `file_path` in the same session keeps the URL.
- Update its "What changed" and "Still to decide" boxes each round, and the captions.
- Dylan comments on the artifact; read comments with the ArtifactComments tool when he says he's commented.

---

## 8. What exists in the game today

All of this predates v6 and describes the OLD layout. Treat it as the starting point to rewrite, not as the design.

### 8.1 `MapConfig` (OLD)

`src/ReplicatedStorage/Shared/MapConfig.luau`. Every number for the OLD round room, shared by the builder and game code:

| Field | Old value | v6 fate |
| --- | --- | --- |
| `SCALE` | 1.5 (first-draft room scale) | Becomes the furniture scale, 1.25. |
| `HALF_WIDTH` | 600 | 210. |
| `CURVE_CENTER_Z` | 210 (at the bed) | Replaced by the homes' curve centre, 380. |
| `CURVE_RADIUS` | 930 | Replaced by the homes' curve radius, 380. |
| `WALL_HEIGHT` | 360 | 320. |
| `WALL_THICKNESS` | 20 | Not needed for homes (open fronts); keep for walls. |
| `BASEBOARD_HEIGHT` | 15 | Same. |
| `RINGS` (Creaky < 390, Wood < 660, Carpet < 930; noise 3/2/1; toySize L/M/S) | — | Replaced by z bands: Carpet < 900, Wood < 1300, Creaky < 1700; same noise and sizes. Plus the safe zone. |
| `FLOOR_TILE_SIZE` | 24 | Same. |
| `FLOOR_TILE_REACH` | 932 | Replaced by the floor outline test. |
| `HOLE_COUNT` | 8 | Same. |
| `HOLE_FIRST_ANGLE`, `HOLE_SPREAD` | 52, 76 | Replaced by `HOME_STEP` 22.5 centred on 270. |
| `DOOR_WIDTH`, `DOOR_SIDE_HEIGHT` | 28, 12 (the mouse-hole arch) | Gone: homes have open fronts, no arch. |
| `BURROW_WIDTH`, `BURROW_DEPTH`, `BURROW_HEIGHT` | 120, 100, 40 | 130, 170, open to the wall top (320). |
| `BURROW_FLOOR_LIFT` | 0.2 | Keep a small lift so home floors don't fight the room floor. |
| `MAX_SLOTS` | 20 | Same (capacity). |
| `BURROW_LAYOUT` (LockButton (−30,12), CashPile (28,14), Spawn (0,24), ToyIndex (−52,30), TrainingWheel (50,22)) | — | **Same positions.** v6 keeps them. |
| `WHEEL_RADIUS`, `WHEEL_WIDTH` | 7, 8 | Become per-level (6.8). |
| `HOLE_LEVELS` (slots, theme) | 6..20, Cardboard..GoldenVault | Same. |
| `SPAWN_RINGS` | polar rings | Replaced by z rows per band (6.15). |
| `polar`, `curveFrame`, `holeAngle`, `burrowFrame`, `sideWallLength` | — | Replaced by `homeAngle`, `homeFrame`, etc. (Appendix A). |
| `slotOffsets` | 4 rows of 5 | Capacity only; keep for any game code that still uses slot positions, or drop when roaming toys land. |
| `ringAt`, `noiseAt` | — | Replaced by `zoneAt`, `noiseAt` (by z and the safe ring). |
| `floorTiles` | — | Rewritten for the new outline. |
| `toySpawns` | — | Rewritten for rows. |

**Frame convention in the old code (keep it):** `curveFrame` uses `CFrame.lookAt(point, centre)`, so the frame's
LookVector (−Z) points into the room and **+Z points back into the burrow**. Props are placed with
`burrowFrame(i) * CFrame.new(lx, y, lz)`, with lz into the burrow. v6 keeps exactly this: a home's frame sits at the
middle of its open front, LookVector toward the curve centre, and `BURROW_LAYOUT` positions work unchanged.

### 8.2 `tools/build-bedroom.luau` (OLD)

Studio Edit-mode only. Rebuilds `Workspace.Bedroom` from `MapConfig`. Run from the command bar:

```lua
local m = game.ServerStorage.TinyToyHeistTools.BuildBedroom:Clone(); print(require(m)); m:Destroy()
```

What it builds today (old round room):
- Floor: three ring discs trimmed to the room with CSG, plus voxel floor tile MeshParts cloned from
  `ServerStorage.TinyToyHeistAssets.FloorTiles` (`CarpetTile`, `WoodTile`, `CreakyTile`) when they exist.
- Walls: back wall, side walls, a curved front wall of panels with 8 CSG-cut arches (fallback: 3-part square opening),
  arch trim, baseboards, a ceiling.
- Holes: `Holes/Hole1..8` models with attributes `HoleIndex`, `Owner` (UserId, 0 = free), `Level`, `Locked`; inside:
  `Shell` (Floor with `FloorType = "Burrow"`, `Noise = 1`; TunnelFloor, BackWall, SideWall, FrontWall, Ceiling, Lamp
  with a PointLight), `Slots/Slot1..20`, `CashPile`, `LockButton` (with a ProximityPrompt), `IndexStand` + `IndexBook`,
  the Speed training wheel (`Wheel` model spun by game code, `RunPoint`), a `SpawnLocation` named `Spawn`,
  `DoorBarrier`, `LockBars/Bar…`, `Sign` + `LevelPlate`.
- Furniture: first-draft boxes scaled 1.5x (headboard, legs, frame, mattress, pillow, duvet, nightstands, lamp shade
  with a PointLight, toy chest, desk, chair, bookshelf and books, beanbag, boxes, window with a SurfaceLight, locked
  door).
- `GiantKid` model (Body, Head (PrimaryPart), Hair, Arm, Hand), attribute `State = "Asleep"`.
- `ToySpawns`: invisible parts named like `S01`, `M12`, `L03` with attribute `Size`.
- Night lighting values at the bottom.
- Returns a summary table (parts, holes, toySpawns, archUnions, archFallbacks, floorTiles).

Patterns worth keeping: everything from `MapConfig`; a `place()` helper with options (material, shape, collide,
transparency, attributes); `batch()` yields every 150 parts so Studio doesn't freeze; CSG with a fallback; fixed
random seeds.

### 8.3 `tests/MapConfig.spec.luau` (OLD)

Returns a function taking the `Shared` folder; checks: hole angles and spread; every burrow the same distance from the
bed; neighbouring burrows don't overlap at the front; the curve meets the side walls; ring lookups and noise; 60 toy
spawns on their rings, inside the room, clear of the bed; and more. Rewrite it with the new MapConfig (Appendix D
lists the v6 checks).

### 8.4 The UI

`TinyToyHeistUI/Hud.client.luau` + `UIKit.luau`: HUD in the Steal an Egg style (Gotham font, chunky buttons): Shop
(Featured, cash packs, speed packs, Double Speed banner, passes, tabs), Index, Daily and Playtime rewards, settings.
Untouched by this session. When the map changes, check anything the HUD reads from the map (for example a "your hole"
arrow) still finds its targets.

### 8.5 The place

`places/TinyToyHeist-Latest.rbxl` holds the built OLD bedroom and the UI. Studio was open on "Place save 1.rbxl" during
this session (it contains `Workspace.Bedroom`); screen captures from Studio MCP timed out, so no Studio comparison was
made. Before building, open the right place and check which file Studio has.

---

## 9. Building v6 in Studio: the plan

Do it in this order. Each step ends with a check and a commit (and a place save after Studio changes).

### Step 0: Get set up

1. Confirm Studio is open on `places/TinyToyHeist-Latest.rbxl` (Studio MCP `list_roblox_studios`; the name shows the
   file).
2. Make sure Rojo is serving and synced (`rojo serve`; connect in Studio), so `MapConfig`, the tools and tests land in
   the place.
3. Note what's in `ServerStorage.TinyToyHeistAssets` (FloorTiles meshes) and anything game code reads from
   `Workspace.Bedroom` (search the place's scripts for `Bedroom`, `Holes`, `HoleIndex`, `ToySpawns`, `GiantKid`).
   At the time of writing the repo has no server game code; check the place for scripts that aren't in the repo.

### Step 1: MapConfig v6

- Replace the module with the v6 numbers and helpers. Appendix A has a full draft.
- Keep the field names game code may already use where the meaning is the same (`HOLE_COUNT`, `BURROW_LAYOUT`,
  `HOLE_LEVELS`, `MAX_SLOTS`, `FLOOR_TILE_SIZE`, `noiseAt`). Rename the ones whose meaning changed.
- Run StyLua and Selene.

### Step 2: The spec

- Rewrite `tests/MapConfig.spec.luau` with the v6 checks in Appendix D. Run it in Studio (Server data model after
  `start_stop_play(true)`, or require it in the command bar with `ReplicatedStorage.Shared`).
- Commit "MapConfig and spec for the v6 bedroom".

### Step 3: The builder, shell first

Rewrite `tools/build-bedroom.luau`. Keep the helpers (`rgb`, `batch`, `place`, `folder`, `disc`, `label`) and the
top-of-file comment style. Build into `Workspace.Bedroom` with these folders:

| Folder | Contents |
| --- | --- |
| `Floor` | The floor outline (see below), the safe ring, zone lines, floor labels (SurfaceGuis on thin parts), voxel tiles. Floor parts carry `FloorType` (`Safe`, `Carpet`, `Wood`, `Creaky`) and `Noise` (0, 1, 2, 3). |
| `Walls` | Long walls, shoulders, far wall with the door gap, baseboards, the walls between homes, end walls, ceiling. |
| `Homes` | `Home1..Home8` (or keep `Hole1..8` if game code needs it; decide in step 0). |
| `Furniture` | Bed group, nightstand, desk and chair, window, night-light. |
| `GiantKid` | Voxel Kid (asleep parts + sitting-up parts), same names and attributes game code uses. |
| `Landmarks` | Block tower (blocks, steps, fallen block). |
| `Train` | `Track` (segments), `TrackPoints` (ordered parts or attributes), `Cars/Car1..5`. |
| `Hazards` | `Cat`, `Traps/Trap1..4`, `LooseBoards/Board1..6`, `Ducks`, `Bricks`, `MonitorZone`. |
| `ToySpawns` | Invisible spawn parts by band, attribute `Size`. |
| `Hallway` | The open door and the short hallway beyond. |

Floor outline in Roblox: there's no ShapeGeometry, so build it from parts:
- The run: one big part 420 x 1 x 1190 (z 510..1700), and the shoulders as two wedge parts (or a few rotated parts)
  filling between (±390, 380), (±210, 510).
- The half-circle: a cylinder part (radius 392, height 1) lying flat, centred at (0, 380), cut in half with CSG
  (subtract a box covering z > 380) or simply left whole, since the half that pokes into the run is covered by the run
  floor anyway. Simplest: a full flat cylinder radius 392 under everything.
- The safe ring: a flat cylinder radius 392 in teal with a radius-240 cylinder subtracted (CSG), then cut to the back
  half; fallback: 48 thin wedge segments round the ring.
- Voxel tiles on top (24-stud MeshParts) wherever `MapConfig.floorTiles()` says: carpet in the half-circle centre and
  the carpet band, wood, creaky. Not under the safe ring.
- Check: walk from a home to the door in Play mode; no gaps, no z-fighting.

Walls between homes: Roblox has no extruded polygon either. Use one part per wall-between: a box whose front face spans
from home i's front-right corner to home i+1's front-left corner and whose depth is 178, then **WedgeParts** (or a
second box rotated) to fill the widening toward the back. Or simpler, because the back is hidden: a box 8–12 thick
along the bisector between the two homes, full height and depth, plus filler boxes behind the homes so no gaps show
from the room. The visible faces that matter: the front edge between homes, and the sides inside the homes (which are
covered by the homes' own side studs).

Check: from the room, the curve reads as one wall with 8 open bays; no light leaks or holes when you look in at any
angle.

### Step 4: The homes

For each home, `homeFrame(i)` = `CFrame.lookAt(front, Vector3.new(0, 0, CZ0))` (LookVector toward the curve centre,
+Z into the wall). Build with `homeFrame(i) * CFrame.new(lx, y, lz)`:

1. Subfloor (OSB texture or a Wood material in tan), back sheathing (OSB) full height, side studs, back studs at
   x ±30, blocking at y 120/240 (middle bay +6), top plate. Pine colour #E2B77C, Material Wood.
2. Torn drywall pieces up both front edges (small white parts, varied widths; same fixed pattern per home).
3. Cables: Roblox has no tube mesh in code; use thin cylinders (1-stud radius, rotated) in short segments, or a Beam
   between attachments (cheap and curvy: `Beam.CurveSize0/1` for sag). Staples as tiny grey parts.
4. Outlet box with two Neon slits; a small PointLight.
5. Fairy light: 9 small Neon balls along the yellow cable, one PointLight (range 30–40 in Roblox studs feels right;
   Roblox PointLight range maxes at 60).
6. Toy pen floor: one thin part per home in the level's material/colour. Name it `Pen`; attributes `PenMin`/`PenMax`
   (Vector3, home space) for roaming bounds.
7. Props at `BURROW_LAYOUT`: `CashPile` (thimble: a hollow cylinder from a cylinder minus a smaller one, or 12 thin
   parts round a ring; coins as flat cylinders), `LockButton` (push pin: three cylinders; keep its ProximityPrompt),
   `IndexBook` (domino + matchbook), the level wheel (`Wheel` model + `RunPoint`, sized per level), `Spawn`
   (SpawnLocation under a matchbox bed).
8. `Sign` (a SurfaceGui on a board on a lolly stick at the front corner) and `LevelPlate` equivalent.
9. `LockBars` (12 bars + top bar) and a `DoorBarrier` across the whole open front (invisible, `CanCollide` only when
   locked).
10. Attributes on each home model: `HoleIndex`, `Owner`, `Level`, `Locked` (same as today).
11. Level dressing: build all 7 themes as children (`Theme1..7` folders) and show only the current level (game code
    toggles), or build per level on change. Building all 7 per home costs parts; prefer building only the current
    level and rebuilding the dressing when the level changes (game code calls a shared builder function).

Check: walk into every home; look up and see studs, blocking and cables to the top; the lock button prompt works; you
spawn on the matchbox bed; the sign reads.

### Step 5: Furniture, Kid, landmarks

1. Bed group at (−110, 0, 1600), scale 1.25 of the v3 sizes, turned 180°. Build it from parts at final size (multiply
   the v3 numbers by 1.25 in code; don't use Model:ScaleTo unless you want to).
2. Voxel Kid: asleep parts (lump, head with a face Decal/SurfaceGui, hair tufts, arm and hand) and sitting-up parts
   (hidden by default). Keep `GiantKid` with `PrimaryPart = Head` and `State` attribute.
3. Nightstand with lamp (PointLight) and clock (SurfaceGui "2:00", red neon look) and the baby monitor.
4. Desk, chair, computer (SurfaceGui green screen), window with blinds (slats + a Neon backing + a SurfaceLight) and a
   SpotLight outside for the stripes.
5. Night-light on the far wall.
6. Block tower: 4 blocks with letter Decals or SurfaceGuis, 20 steps (anchored, collidable, each step a 22 x 4 x 13
   part with a studs texture), fallen block. Test that the steps are climbable at default JumpPower (rise 6 needs a jump
   height above 6; Roblox's default jump is about 7.2 studs). If not, lower the rise to 4–5 and add steps.
7. Hallway: open door (hinged look), floor, walls, warm light, sign; block the far end for now (invisible wall) until
   the Hallway room exists.

### Step 6: Train, cat, hazards, spawns

1. Track: segments along `MapConfig.trackPoints()` (pre-sampled points from the Catmull-Rom curve, every ~4 studs),
   each a 4.6 x 1.6 x 11 part, turned along the path, plus groove strips. Mark each `CanQuery = false` if it shouldn't
   block raycasts. Keep collisions on (it's 1.6 tall; players step over).
2. Train cars: 5 models, anchored, moved by game code (section 10). Build them from parts (engine with chimney and
   lamp; wagons with cargo blocks), scaled 1.4 of the render sizes.
3. Cat model; its patrol path as attachments or an attribute list.
4. Traps (4), loose boards (6), ducks (2), bricks (5 + stacked), monitor zone (a flat Neon green disc, transparent,
   `CanCollide = false`, `CanQuery = false`, with a `NoiseMultiplier = 2` attribute).
5. Spawns from `MapConfig.toySpawns()`.

### Step 7: Lighting

1. Night preset from 6.16 (convert to Roblox: `Lighting.Ambient`, `OutdoorAmbient`, `Brightness`, `ClockTime 0`,
   `EnvironmentDiffuseScale`, `ExposureCompensation`; ColorCorrection tint toward blue; Bloom for the Neon; Atmosphere
   for depth). Roblox has no hemisphere light: use Ambient/OutdoorAmbient for the blue and keep warm PointLights for the
   pools. Use `Lighting.Technology = Future` so the lamp casts pools and shadows.
2. `ReplicatedStorage.Shared.BedroomLighting` with `Night` and `LightsOn` presets (property tables) and a function to
   apply or tween.
3. Check against Dylan's photo 2 (night) and photo 1 (lights on).

### Step 8: Compare and save

1. Take Studio captures (Studio MCP `screen_capture` with camera position/look) from the same cameras as the renders
   (Appendix B). Note: captures timed out this session; retry, or use `execute_luau` to set `workspace.CurrentCamera`
   and ask Dylan for a screenshot.
2. Put render and capture side by side for Dylan.
3. Ask Dylan to Save As `places/TinyToyHeist-Latest.rbxl`; check the timestamp; commit.

### Budgets

- Room parts (walls, floor, furniture, landmarks, hazards): aim under ~2,500.
- Per home: ~150 parts at Level 1; more with dressing. 8 homes → ~1,200–2,000.
- Floor tiles: the run is 420 x 1190 → 18 x 50 = 900 tiles, plus the half-circle centre (~ π·228²/576 ≈ 280). Instance
  them as MeshParts (one mesh asset per kind) so they batch.
- Lights: about 8 in the room, 2 per home. Roblox handles this with Future lighting; check FPS on a phone.
- Use `CastShadow = false` on small parts (staples, coins, bulbs, studs).

---

## 10. Game systems v6 implies

None of these exist yet. Each needs a server script (and some client work). Build them after the map.

### 10.1 Roaming toys in the pen

- Toys in a home are no longer on slots. Each awake toy model wanders its home's pen: pick a random point inside
  `PenMin..PenMax` (home space), walk there (CFrame lerp on the server at low rate, or client-side animation from a
  shared seed), pause 0.6–3 s, repeat.
- Capacity = `HOLE_LEVELS[level].slots` (+3 VIP). When full, new toys can't be dropped in.
- Raids: a raider grabs a toy by holding on it (2 s, per the plan) wherever it is in the pen. Roaming makes grabbing
  a little harder, which is good.
- Performance: 8 homes x up to 23 toys = 184 movers. Animate on the client (each client simulates toys near it from a
  seed + server tick) and keep only ownership on the server.

### 10.2 Levelled Speed wheel

- On level change, rebuild the wheel at the new size and look (6.8). `RunPoint` moves with the radius.
- Game code spins `Wheel` faster with the level (`1.2 + 0.25·L` rad/s at idle).

### 10.3 The train

- Server moves the 5 cars along the sampled track at 60 studs/s (lap 30.7 s), cars 27 apart. Use precomputed points
  + linear interpolation; set CFrames with `BulkMoveTo` each Heartbeat, or animate on clients from a shared clock.
- Hit test: a box in front of the engine and each car (or Touched on an invisible hitbox). A hit knocks the player
  back, ragdolls/stuns them briefly and **drops any carried toy**.
- Noise: the train adds noise to anyone within ~40 studs (or just plays a rattle that the Wake Meter ignores; decide).
- Sound: a looping rattle positioned on the engine so players hear it coming; a whistle before it crosses the run.

### 10.4 The cat

- Patrol: walks the wood band ellipse (centre (0, 1150), half-axes 150 x 60). Bell jingles.
- Detection: notices a player within ~60 studs who is moving fast or carrying; stalks, then pounces (a quick lunge).
  A pounce = drop the toy, short stun.
- **Lights on:** aggressive: wider detection (~150), faster, leaves the patrol to chase the nearest player, pounces
  sooner. Back to the patrol when the lights go off.

### 10.5 Lights on/off

- When the Giant's state goes to Stirring/Awake, tween Lighting to the `LightsOn` preset in ~0.4 s and play a click.
  When he's back to bed, tween to `Night` over ~3 s.
- Clients do the tween (Lighting is local-safe) when the server's `GiantKid.State` attribute changes.

### 10.6 Zones and noise

- `MapConfig.zoneAt(position)` → Safe / Carpet / Wood / Creaky; `noiseAt` → 0 / 1 / 2 / 3. Inside the monitor zone,
  x2. Loose boards and ducks add one-off spikes; bricks clack when bumped.
- The safe zone: no noise, and (decide) hazards don't enter it; the Giant can't grab you there? (Plan says hiding in
  your hole is safe; the safe ring is new: decide what it protects from. Section 11.)

### 10.7 Spawns

- Toys respawn at empty spawn points by band size (Small on carpet, Medium on wood, Large on creaky), with the plan's
  rarity odds by size.

### 10.8 Traps, boards, ducks, monitor, flashlight

As in the plan and concept v4: trap = drop toy + go home (or stun); boards/ducks = noise; monitor = noise x2;
flashlight at 80+ noise = the Kid sits up and sweeps a beam; caught carrying = drop.

---

## 11. Open questions

Ask Dylan before (or while) building. The review page lists the first three.

1. **Scale.** After the last shrink (420 x 1700, walls 320, toys +35%), does the room feel right next to the toys and
   homes, or shrink more?
2. **The keyhole shape.** The start area is 780 wide (it has to be to fit 8 homes of 130 round a half-circle) and the
   run is 420. OK, or another shape (for example a shallower curve that carries the homes partly round onto the
   shoulders)? Not two rows: he ruled that out.
3. **Lighting.** Night (photo 2) as the default and lights-on (photo 1) when the Kid wakes: still right?
4. **Spawn count.** The render shows up to 16 Small, 12 Medium and 6 Large. The plan says 48 in the bedroom. Keep it
   readable (~30) or go back to 48?
5. **What the safe zone protects from.** No noise? No hazards (cat, train never enter it)? The Giant can't grab you?
   Raiders can't be bonked there? Decide.
6. **Homes or holes.** In code and UI, are they "holes", "homes", "bases" or "pens"? Dylan uses all of these. The plan
   and code say holes; the review page says homes. Pick one name for players.
7. **Slots vs roaming.** With roaming toys, do slot positions still exist anywhere (for display spots, the Index, or
   raids), or is it pure capacity?
8. **Toy chest, posters and other removed props.** Cut for simplicity. Any he wants back (one or two as landmarks)?
9. **The tower lookout.** Steps rise 6 studs. Check jump height in Roblox; is the lookout worth keeping?
10. **Train behaviour.** Knock-down only, or also noise? Does it stop for anything? Can players ride it (fun, but a
    shortcut)?
11. **The Hallway.** Open door with a "next room soon" sign and an invisible wall for now, or closed until it exists?
12. **The sketch.** Dylan's original sketch isn't in the repo. If he still has it, add it to `design/references/`.
13. **Figma references.** Six AI images sit in the Figma file, unreviewed and undownloaded (plan limit). Ignore, or
    export them by hand?

---

## 12. Known rough edges in the renders

These are render artefacts, not design decisions. Don't copy them into Studio.

- **Floor tile edges at the shoulders** poke out in a sawtooth where the half-circle meets the run (tiles are placed on
  a 24-stud grid and kept if their centre is inside).
- **Wall-between prisms look flat grey-lavender** at night; the wallpaper UVs on extruded sides don't line up well.
- **The pine framing reads lavender-grey** under the blue night light. It's correct for the night look, but in Studio
  make sure it still reads as wood (photo 2 keeps objects readable).
- **The cat's patrol dots** run under the bed's edge in places.
- **Left/right comments** in the render code say "left wall" for x < 0 (the runner's right). Use section 6.1.
- **Awake toys** are placeholders (box figures), not the real voxel toys from `design/toy-turntables.html`.
- **Blankets** use the toon cartoon lumps from the earlier blanket tests; the real blanket look is still open (the
  `design/blanket-test.html` options).
- **Some text sprites** (signs) are clipped at the edges in close-up home views because the camera is close.
- **The floor labels** read upside-down from the homes (they're laid to read toward the far end, for players leaving
  home). Fine in game; just know why.
- **Point lights pass through walls** in three.js (no shadows on them), so fairy lights tint neighbouring homes
  slightly. Roblox Future lighting shadows PointLights, so this won't happen there.

---

## 13. Environment notes and gotchas

### Machine and shells

- Windows 11. The repo path has spaces: always quote `"C:\Users\Dylan Wu\Downloads\Roblox brainrot game"`.
- Two shells: Git Bash (the Bash tool) and Windows PowerShell 5.1. In Bash, the temp folder is
  `/c/Users/DYLANW~1/AppData/Local/Temp/...`. No Python or Node on PATH; Perl, awk, sed and ffmpeg are available.
  ffmpeg is at `...\WinGet\Packages\Gyan.FFmpeg...\bin`.
- Chrome and Edge are installed (used headless for renders).
- Writing multi-line edits to the big HTML file: put Perl scripts in a file and run them with `perl script.pl <in >out`
  rather than inline in a shell command (quoting broke an inline script once).

### Git

- Branch `main`, tracking `origin/main` at https://github.com/shdidaxo-pixel/tinytoyheist. Push after each commit when Dylan
  wants it pushed. The GitHub CLI (`gh`) isn't installed; plain `git push` works with the saved login.
- `places/TinyToyHeist-Latest.rbxl.lock` exists while Studio has the place open; don't commit the lock.

### Studio MCP

- `list_roblox_studios` gives the studio id; every call needs it.
- `execute_luau` runs in Edit, Server or Client. Build maps in Edit. Long builds: yield (`task.wait()`) every chunk so
  the connection doesn't drop.
- `screen_capture` with a camera position timed out twice this session (and once returned a blank image from inside
  the ceiling). Retry with simple positions inside the room, or have Dylan take screenshots.
- Studio can't save a place file from tools: ask Dylan to Save As.

### Figma MCP

- Dylan's Figma is on the Starter plan; the MCP call limit was hit after creating one file and six images. Images
  generate fine but can't be downloaded once the limit hits. Don't plan on Figma for bulk work.

### The browser pane

- Opens local files as `data:` snapshots. Good for checking console errors and a quick screenshot. It blocks
  `fetch` to localhost, so it can't save captures to disk.

### The review artifact

- Private to Dylan. To show someone else he must share it from the page's Share menu.
- Comments: he can comment on the artifact; read them with ArtifactComments (action read).

---

## 14. References

- **Dylan's lighting photos:** `design/references/bedroom/01-lighting-day.png` (lights on: warm, soft, pastel voxel
  room, small lamp glow) and `02-lighting-night.png` (the same room lit deep blue; warm pools at the lamp and window
  slats; the monitor glows green; darks are blue, never black).
- **Dylan's wall-framing photos** (sent in chat, not saved to the repo): (1) OSB sheathing with studs and staggered
  horizontal blocking; (2) studs with white cables stapled up them into outlet boxes, a white PVC pipe, torn drywall
  edges; (3) mineral-wool insulation between metal studs with a wooden rail. Ask him to resend if you need them saved.
- **Dylan's Steal an Egg screenshots** (sent in chat): a long straight green-floored corridor with brick-red walls,
  a "SAFE ZONE" painted at the start, a T-rex running down a white band. The model for "long and simple".
- **Videos:** `C:\Users\Dylan Wu\Downloads\Download (7).mp4` and `Download (8).mp4` (deadj.rodev). Not in git.
- **Prompt template:** https://docs.google.com/document/d/1paXSLH91J5skRbdq9a4axJjZUmP-1YQtU6p7p4vT2fk/edit (public
  export works with `/export?format=txt`).
- **Figma file of AI references:** https://www.figma.com/design/3ZlBNM6Qd9WM7yyJpXaS17 (unreviewed).
- **Concept pages:** `design/new-map-render.html` (v4, other chat), `design/game-render.html` (round room).
- **Plan:** `Day 1 - Starting Plan.md` (holes and raids, Giant behaviour, noise numbers, MVP). **Catalog:** `Toy Catalog.md`.

---

## 15. Toys: how to use them

Added 19 Oct 2026 by the toys session. Every toy in `Toy Catalog.md` is a voxel model built from data, with its idle
animation, rarity effects and the 10 mutations. This section is the API for game code and the map (roaming pens,
blankets, the reveal). How to make or edit a toy: `tools/toys/README.md`.

### Where things are

| Thing | Where |
| --- | --- |
| Built toy models | `ServerStorage.TinyToyHeistAssets.Toys.<Id>` (e.g. `RubberDuck`), rarity effects baked in. Saved in the place. |
| Toy data (one file per set) | `src/ReplicatedStorage/Shared/Toys/Sets/*.luau` → `ReplicatedStorage.Shared.Toys.Sets` |
| Lookup | `ReplicatedStorage.Shared.Toys.ToyCatalog` (`get(id)`, `list()`, `inSet(set, rarity?)`, `pick(set, rarity, rng)`) |
| Builder | `ReplicatedStorage.Shared.Toys.ToyBuilder` (`build(toy)` → Model; `SIZE_TARGET`) |
| Rebuild in Studio | `require(game.ServerStorage.TinyToyHeistTools.BuildToys).run()` (Edit mode); `.showcase()` lines them up at z −3000, `.clearShowcase()` removes it |
| Idle animations | `ReplicatedStorage.Shared.Toys.ToyAnimator`, started for you by `StarterPlayerScripts.TinyToyHeistToys.ToyClient` |
| Effects | `ReplicatedStorage.Shared.Toys.ToyVFX` (rarity, glow tell, reveal) |
| Mutations | `ReplicatedStorage.Shared.Toys.Mutations` (+ `MutationData` for chances and multipliers) |
| Review page | `design/toy-turntables.html` (every toy, mutation and view; stills in `design/toy-renders/`); `design/toy-review.html` is the published review |
| Icons | `design/toy-icons/<Id>.png`, 256 px, transparent, for the Index and shop (`bash tools/toys/make-icons.sh` remakes them) |

### A toy model

- `Model <Id>`, `PrimaryPart = Root`. **The pivot is the centre of its feet, on the floor, and it faces −Z**
  (LookVector), so `toy:PivotTo(CFrame.lookAt(pos, pos + dir))` stands it on the floor facing `dir`.
- `Root`: an invisible, anchored box the size of the toy, `CanQuery = true` (raycast or put a ProximityPrompt on it
  for grabbing), `CanCollide = false`. Nothing else in a toy collides or is queryable.
- `Rig`: one invisible part per moving group (`Body`, `Head`, ...), each with a Motor6D `Joint`. `Blocks`: the visible
  boxes, welded to their group. `Fx`: the toy's own particles. `RarityFx` / `MutationFx`: effect folders.
- Attributes: `ToyId`, `ToyName`, `Set`, `Rarity`, `Money` (base $/s), `Size` (`S`/`M`/`L`/`G`), `VoxelScale`,
  `Height` (studs), and `Mutation` once mutated. Tagged `TinyToy`. `ModelStreamingMode = Atomic`.
- Sizes (height, or 0.75 of length if longer): Small 8, Medium 12, Large 17, Giant 25 studs; a player is 5.
  `Size` is the toy's natural size. The plan rolls the blanket size first, so if a toy comes out of a different size
  of blanket, scale it: `toy:ScaleTo(ToyBuilder.SIZE_TARGET[blanketSize] / ToyBuilder.SIZE_TARGET[toy:GetAttribute("Size")])`
  (effects and joints scale with it).
- All 105 toys, about 33 blocks each on average (3,500 or so in all); blocks under 0.3 studs don't cast shadows.

### Recipes

```lua
local ServerStorage = game:GetService("ServerStorage")
local Toys = game:GetService("ReplicatedStorage").Shared.Toys
local Mutations = require(Toys.Mutations)
local ToyVFX = require(Toys.ToyVFX)

-- Wake-up (server): clone, roll the mutation, put it in the home's pen.
local toy = ServerStorage.TinyToyHeistAssets.Toys[toyId]:Clone()
local mutation = Mutations.roll(rng, { NightmareNight = nightOn, Halloween = halloweenOn }, luck) -- nil = none
Mutations.apply(toy, mutation)                      -- recolours + effect; sets the "Mutation" attribute
local perSecond = toy:GetAttribute("Money") * roomMultiplier * Mutations.multiplier(mutation)
toy:PivotTo(CFrame.new(spot) * CFrame.Angles(0, math.random() * 2 * math.pi, 0))
toy.Parent = home.Pen                               -- anywhere under Workspace; it starts animating on every client

-- Reveal (client, when the wake-up timer ends): burst + pop.
ToyVFX.revealBurst(toy)
ToyVFX.popIn(toy)

-- Sleeping toy (server, when a blanket spawns): Epic and up leak their colour about 1 s in every 8.
ToyVFX.addGlowTell(blanketPartOrModel, rarity)      -- does nothing for Common to Rare; removeGlowTell(blanket) to undo
```

- **Idle animations play by themselves** on every client for any `TinyToy` model in Workspace, within 220 studs of the
  camera (every third frame past 90 studs). Mutation movement (Rainbow colours, Cosmic orbit, Bubble and Haunted
  floating) and the Secret rainbow ring run in the same loop.
- **Roaming (handoff 10.1):** move the whole toy with `toy:PivotTo(...)` (client-side from a shared seed is cheapest).
  Don't touch the `Rig` joints; the idle plays on top of wherever the toy is. To turn it, rotate the pivot about Y.
- **While carried:** `ToyVFX.removeRarity(toy)` hides the rarity glow; `ToyVFX.applyRarity(toy)` puts it back.
- **Index Teddy** is "always Gold": `Mutations.apply(toy, "Gold")` when it's awarded.
- **Mutations replicate** (colours, materials, effect parts are made on the server). Shadow uses a Highlight; Roblox
  draws at most 31 at once, which only matters if a server has dozens of Shadow toys in view.

---

## Appendix A: draft MapConfig for v6

A full draft to start from. It matches the render exactly (home frames, bands, spawns, track). Check it compiles,
run StyLua and Selene, and adapt names to whatever game code needs.

```lua
--!strict
-- Every number for the Kid's Bedroom (concept v6), shared by the map builder (tools/build-bedroom.luau) and game code.
-- One long run: 8 homes side by side in a half-circle wall at the start (open fronts, open tops), a safe zone in front
-- of them, then three floor bands down the run (carpet, wood, creaky boards) to the bed along the runner's right-hand
-- wall and the open hallway door straight ahead. Studs; x across (a runner facing +z has +x on their left), z down the
-- room from the start, y up.

local MapConfig = {}

-- Room
MapConfig.HALF_WIDTH = 210 -- the run is 420 wide; long walls' inner faces at x = +-210
MapConfig.LENGTH = 1700 -- far wall's inner face at z = 1700
MapConfig.WALL_HEIGHT = 320
MapConfig.WALL_THICKNESS = 8
MapConfig.BASEBOARD_HEIGHT = 15
MapConfig.FURNITURE_SCALE = 1.25 -- the bed and the Kid, from the first-draft (v3) sizes

-- The start: a half-circle wall holding the homes, then shoulders in to the run
MapConfig.HOME_CURVE_RADIUS = 380 -- the homes' open fronts sit on this circle
MapConfig.HOME_CURVE_CENTER_Z = 380 -- centre (0, 380); the curve's back touches z = 0
MapConfig.SHOULDER_END_Z = 510 -- shoulders run from (+-390, 380) to (+-210, 510)

-- Hallway door, centred in the far wall
MapConfig.DOOR_WIDTH = 130
MapConfig.DOOR_HEIGHT = 230

-- Homes
MapConfig.HOLE_COUNT = 8
MapConfig.HOME_STEP = 22.5 -- degrees between homes; home 1 at 191.25, home 8 at 348.75
MapConfig.BURROW_WIDTH = 130
MapConfig.BURROW_DEPTH = 170
MapConfig.BURROW_FLOOR_LIFT = 0.2
MapConfig.MAX_SLOTS = 20 -- capacity at Level 7 (VIP adds 3)
MapConfig.PEN_FRONT = 40 -- the toy pen runs from 40 deep...
MapConfig.PEN_BACK = 158 -- ...to 158 deep (BURROW_DEPTH - 12)
MapConfig.PEN_WIDTH = 116 -- BURROW_WIDTH - 14

-- The front of each home, in home space (x across, z into the wall; walking in, -x is on your right).
-- Unchanged from the old burrows, so game code that finds these keeps working.
export type BurrowProp = { position: Vector3, half: Vector3 }
MapConfig.BURROW_LAYOUT = {
	LockButton = { position = Vector3.new(-30, 0, 12), half = Vector3.new(4.5, 0, 4.5) },
	CashPile = { position = Vector3.new(28, 0, 14), half = Vector3.new(5.5, 0, 5.5) },
	Spawn = { position = Vector3.new(0, 0, 24), half = Vector3.new(8, 0, 5) },
	ToyIndex = { position = Vector3.new(-52, 0, 30), half = Vector3.new(4.5, 0, 3.5) },
	TrainingWheel = { position = Vector3.new(50, 0, 22), half = Vector3.new(7, 0, 11) },
} :: { [string]: BurrowProp }

-- Home levels: capacity and look. Costs live with the economy.
MapConfig.HOLE_LEVELS = {
	{ slots = 6, theme = "Cardboard" },
	{ slots = 8, theme = "SockLined" },
	{ slots = 10, theme = "ToyBricks" },
	{ slots = 12, theme = "CosyCabin" },
	{ slots = 15, theme = "CandyLand" },
	{ slots = 18, theme = "ArcadeNeon" },
	{ slots = 20, theme = "GoldenVault" },
}

-- The Speed wheel grows with the home's level.
function MapConfig.wheelSize(level: number): (number, number)
	return 6.5 + 0.55 * level, 7 + 0.3 * level -- radius, width
end

-- Floor bands down the run. Noise multiplies every sound made while standing on it.
export type Zone = { name: string, untilZ: number, noise: number, toySize: string? }
MapConfig.SAFE_RADIUS = 240 -- the safe ring: from r 240 out to the homes' fronts, round the curve's centre
MapConfig.ZONES = {
	{ name = "Carpet", untilZ = 900, noise = 1, toySize = "S" },
	{ name = "Wood", untilZ = 1300, noise = 2, toySize = "M" },
	{ name = "Creaky", untilZ = 1700, noise = 3, toySize = "L" },
} :: { Zone }
MapConfig.FLOOR_TILE_SIZE = 24

-- Furniture and landmarks (world positions)
MapConfig.BED = { position = Vector3.new(-110, 0, 1600), turn = 180 } -- headboard toward the far wall
MapConfig.NIGHTSTAND = Vector3.new(-172, 0, 1650)
MapConfig.DESK = { position = Vector3.new(158, 0, 1420), turn = -90 }
MapConfig.WINDOW = { z0 = 1320, z1 = 1520, y0 = 155, y1 = 305 } -- on the x = +210 wall
MapConfig.TOWER = Vector3.new(45, 0, 800)
MapConfig.FALLEN_BLOCK = Vector3.new(-188, 0, 760)

-- Hazards
MapConfig.CAT = { home = Vector3.new(-20, 0, 1150), patrolCenter = Vector3.new(0, 0, 1150), patrolHalf = Vector3.new(150, 0, 60) }
MapConfig.TRAPS = {
	{ position = Vector3.new(-188, 0, 850), turn = 0.15 },
	{ position = Vector3.new(190, 0, 880), turn = -0.15 },
	{ position = Vector3.new(-188, 0, 1150), turn = 0.1 },
	{ position = Vector3.new(190, 0, 1290), turn = -0.1 },
}
MapConfig.LOOSE_BOARDS = {
	Vector3.new(20, 0, 1320), Vector3.new(70, 0, 1400), Vector3.new(10, 0, 1470),
	Vector3.new(60, 0, 1550), Vector3.new(20, 0, 1615), Vector3.new(90, 0, 1600),
}
MapConfig.MONITOR_ZONE = { center = Vector3.new(40, 0, 1420), radius = 105, noise = 2 }

-- The train: a closed loop through these points (x, z), smoothed (centripetal Catmull-Rom). About 1841 studs.
MapConfig.TRAIN_SPEED = 60 -- studs per second: a lap in about 31 s
MapConfig.TRAIN_CARS = 5 -- including the engine
MapConfig.TRAIN_CAR_GAP = 27
MapConfig.TRACK_CONTROL = {
	{ 140, 640 }, { 175, 760 }, { 125, 880 }, { 165, 1000 }, { 115, 1120 }, { 140, 1220 }, { 40, 1250 }, { -70, 1235 },
	{ -150, 1170 }, { -105, 1050 }, { -160, 930 }, { -100, 810 }, { -150, 700 }, { -110, 610 }, { -20, 585 }, { 70, 600 },
}

local function toRadians(degrees: number): number
	return degrees * math.pi / 180
end

-- Homes -----------------------------------------------------------------------------------------------------------

function MapConfig.homeAngle(index: number): number
	assert(index >= 1 and index <= MapConfig.HOLE_COUNT, "home index out of range")
	return 270 + (index - (MapConfig.HOLE_COUNT + 1) / 2) * MapConfig.HOME_STEP
end

-- The middle of home i's open front, on the floor.
function MapConfig.homeFront(index: number): Vector3
	local a = toRadians(MapConfig.homeAngle(index))
	local r = MapConfig.HOME_CURVE_RADIUS
	return Vector3.new(r * math.cos(a), 0, MapConfig.HOME_CURVE_CENTER_Z + r * math.sin(a))
end

-- Home i's frame: at the middle of its open front, LookVector toward the curve's centre (into the room), so +Z points
-- back into the wall. Place things with homeFrame(i) * CFrame.new(x, y, z) using BURROW_LAYOUT positions.
function MapConfig.homeFrame(index: number): CFrame
	local p = MapConfig.homeFront(index)
	return CFrame.lookAt(p, Vector3.new(0, 0, MapConfig.HOME_CURVE_CENTER_Z))
end

-- Old name, so game code written for burrows still works.
MapConfig.burrowFrame = MapConfig.homeFrame

-- A home's front corner (side = -1 or 1), at depth z, in world space. The walls between homes run between these.
function MapConfig.homeCorner(index: number, side: number, depth: number): Vector3
	return (MapConfig.homeFrame(index) * CFrame.new(side * (MapConfig.BURROW_WIDTH / 2 + 5), 0, depth)).Position
end

-- Zones ------------------------------------------------------------------------------------------------------------

-- Inside the walkable floor (half-circle start, shoulders, run)?
function MapConfig.inRoom(position: Vector3): boolean
	local x, z = position.X, position.Z
	local cz, r, hw = MapConfig.HOME_CURVE_CENTER_Z, MapConfig.HOME_CURVE_RADIUS, MapConfig.HALF_WIDTH
	if z < cz then
		return math.sqrt(x * x + (z - cz) ^ 2) <= r
	elseif z < MapConfig.SHOULDER_END_Z then
		local limit = (r + 10) - (z - cz) * ((r + 10) - hw) / (MapConfig.SHOULDER_END_Z - cz)
		return math.abs(x) <= limit
	end
	return math.abs(x) <= hw and z <= MapConfig.LENGTH
end

function MapConfig.inSafeZone(position: Vector3): boolean
	local cz = MapConfig.HOME_CURVE_CENTER_Z
	local d = math.sqrt(position.X ^ 2 + (position.Z - cz) ^ 2)
	return position.Z < cz and d >= MapConfig.SAFE_RADIUS and d <= MapConfig.HOME_CURVE_RADIUS + 12
end

-- The band under a position in the room, or nil outside the room (homes, walls).
function MapConfig.zoneAt(position: Vector3): Zone?
	if not MapConfig.inRoom(position) or MapConfig.inSafeZone(position) then
		return nil
	end
	for _, zone in MapConfig.ZONES do
		if position.Z <= zone.untilZ then
			return zone
		end
	end
	return nil
end

function MapConfig.noiseAt(position: Vector3): number
	if MapConfig.inSafeZone(position) then
		return 0
	end
	local zone = MapConfig.zoneAt(position)
	local noise = if zone then zone.noise else 1
	local m = MapConfig.MONITOR_ZONE
	if (Vector3.new(position.X, 0, position.Z) - m.center).Magnitude <= m.radius then
		noise *= m.noise
	end
	return noise
end

-- Every floor tile centre (y = 0) and the band it takes its look from. Not under the safe ring.
function MapConfig.floorTiles(): { { position: Vector3, zone: string } }
	local out = {}
	local size = MapConfig.FLOOR_TILE_SIZE
	for ix = -16, 16 do
		for iz = 0, math.floor(MapConfig.LENGTH / size) do
			local p = Vector3.new(ix * size, 0, iz * size + size / 2)
			local cz = MapConfig.HOME_CURVE_CENTER_Z
			local inCentre = p.Z < cz and math.sqrt(p.X ^ 2 + (p.Z - cz) ^ 2) < MapConfig.SAFE_RADIUS - 12
			local zone = MapConfig.zoneAt(p)
			if (p.Z >= cz and zone and MapConfig.inRoom(p + Vector3.new(math.sign(p.X) * 12, 0, 12))) or inCentre then
				table.insert(out, { position = p, zone = if zone then zone.name else "Carpet" })
			end
		end
	end
	return out
end

-- Train track --------------------------------------------------------------------------------------------------------

-- Centripetal Catmull-Rom between p1 and p2 (Barry-Goldman), t in 0..1.
local function catmullRom(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: number): Vector3
	local function knot(ti: number, a: Vector3, b: Vector3): number
		return ti + math.sqrt((b - a).Magnitude) -- alpha = 0.5
	end
	local t0 = 0
	local t1 = knot(t0, p0, p1)
	local t2 = knot(t1, p1, p2)
	local t3 = knot(t2, p2, p3)
	local u = t1 + (t2 - t1) * t
	local a1 = p0 * ((t1 - u) / (t1 - t0)) + p1 * ((u - t0) / (t1 - t0))
	local a2 = p1 * ((t2 - u) / (t2 - t1)) + p2 * ((u - t1) / (t2 - t1))
	local a3 = p2 * ((t3 - u) / (t3 - t2)) + p3 * ((u - t2) / (t3 - t2))
	local b1 = a1 * ((t2 - u) / (t2 - t0)) + a2 * ((u - t0) / (t2 - t0))
	local b2 = a2 * ((t3 - u) / (t3 - t1)) + a3 * ((u - t1) / (t3 - t1))
	return b1 * ((t2 - u) / (t2 - t1)) + b2 * ((u - t1) / (t2 - t1))
end

-- Points every `spacing` studs round the closed track (y = 0), evenly spaced by arc length.
function MapConfig.trackPoints(spacing: number): { Vector3 }
	local control = {}
	for _, xz in MapConfig.TRACK_CONTROL do
		table.insert(control, Vector3.new(xz[1], 0, xz[2]))
	end
	local n = #control
	local dense = {}
	for i = 1, n do
		local p0 = control[(i - 2) % n + 1]
		local p1 = control[i]
		local p2 = control[i % n + 1]
		local p3 = control[(i + 1) % n + 1]
		for k = 0, 39 do
			table.insert(dense, catmullRom(p0, p1, p2, p3, k / 40))
		end
	end
	local out = { dense[1] }
	local carried = 0
	for i = 2, #dense + 1 do
		local a, b = dense[i - 1], dense[(i - 1) % #dense + 1]
		local segment = (b - a).Magnitude
		while carried + segment >= spacing do
			local t = (spacing - carried) / segment
			a = a:Lerp(b, t)
			segment = (b - a).Magnitude
			carried = 0
			table.insert(out, a)
		end
		carried += segment
	end
	return out
end

-- Sleeping-toy spawns ------------------------------------------------------------------------------------------------

-- Furniture footprints (x0, z0, x1, z1) and round keep-outs (x, z, r): no spawns or props inside them.
MapConfig.FOOTPRINTS = {
	{ -210, 1275, -10, 1600 }, -- bed
	{ -210, 1610, -134, 1690 }, -- nightstand
	{ 106, 1330, 212, 1510 }, -- desk
	{ 40, 1385, 112, 1455 }, -- chair
	{ -70, 1640, 70, 1700 }, -- in front of the door
}
MapConfig.KEEP_OUTS = { { 45, 800, 40 }, { -188, 760, 26 } } -- tower, fallen block

function MapConfig.blocked(x: number, z: number, r: number, track: { Vector3 }?): boolean
	for _, f in MapConfig.FOOTPRINTS do
		if x > f[1] - r and x < f[3] + r and z > f[2] - r and z < f[4] + r then
			return true
		end
	end
	for _, c in MapConfig.KEEP_OUTS do
		if math.sqrt((x - c[1]) ^ 2 + (z - c[2]) ^ 2) < c[3] + r then
			return true
		end
	end
	if math.abs(x) > MapConfig.HALF_WIDTH - r - 6 then
		return true
	end
	if track then
		for _, p in track do
			if math.sqrt((p.X - x) ^ 2 + (p.Z - z) ^ 2) < 8 + r then
				return true
			end
		end
	end
	return false
end

-- Rows down each band, like eggs down a run. Each candidate gets a small fixed jitter and is dropped if blocked.
MapConfig.SPAWN_ROWS = {
	{ size = "S", rows = { 590, 680, 770, 860 }, columns = { -80, -25, 30, 85 }, oddShift = -25 },
	{ size = "M", rows = { 950, 1040, 1130, 1220 }, columns = { -70, -5, 60 }, oddShift = 25 },
	{ size = "L", rows = { 1330, 1430, 1530 }, columns = { 12, 58 }, oddShift = 20 },
}

function MapConfig.toySpawns(): { { position: Vector3, size: string } }
	local out = {}
	local track = MapConfig.trackPoints(8)
	for _, band in MapConfig.SPAWN_ROWS do
		for r, z in band.rows do
			for k, x0 in band.columns do
				local x = x0 + (if r % 2 == 0 then band.oddShift else 0) -- rows 2 and 4 shift (1-based)
				local jx = ((k - 1) * 37 + z) % 13 - 6
				local jz = ((k - 1) * 53 + z) % 15 - 7
				if not MapConfig.blocked(x + jx, z + jz, 10, track) then
					table.insert(out, { position = Vector3.new(x + jx, 0, z + jz), size = band.size })
				end
			end
		end
	end
	return out
end

return MapConfig
```

Notes on the draft:
- In the render, odd rows (0-based index 1, 3) shift; in this 1-based Luau, that's `r % 2 == 0`. Same result.
- The render's jitter uses the 0-based column index; `(k - 1)` keeps it identical.
- `floorTiles` here is a starting point; compare its tile count and edges with the render's `kindAt` and fix the
  shoulder sawtooth (section 12) by testing tile corners, not just centres.
- `trackPoints` gives evenly spaced points; the train and the track builder both use it. The render's track length is
  1841; check the Luau sum matches within a few studs.

---

## Appendix B: every camera in the render page

Positions are `[x, y, z]`. `BP(i, lx, y, d)` means a point inside home i (0-based in the render: home 0 = Luau home 1)
at `lx` across and `d` deep (negative d = out in the room). Use these to take matching Studio captures.

| # | Key | Label | Position | Look at | Flags | What it shows |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | hero | The run | [0, 290, 110] | [0, 0, 1000] | — | From above the homes down the whole room. |
| 2 | homes | The homes | [0, 150, 760] | [0, 40, 170] | — | Looking back at the curved wall of 8 homes. |
| 3 | yours | Your home | BP(3, 0, 32, −150) | BP(3, 0, 30, 60) | — | Your Level 2 home from the safe zone. |
| 4 | lookup | Looking up | BP(3, 14, 8, 24) | BP(3, 0, 300, 98) | — | Inside your home looking up the framing. |
| 5 | across | From inside your home | BP(3, 0, 15, 100) | BP(6, 0, 30, 20) | — | From the back of your home toward the others. |
| 6 | bases | Along the row | BP(5, 20, 40, −260) | BP(1, 0, 40, 40) | — | Along the curve of homes. |
| 7 | l1 | Level 1 home | BP(1, 0, 32, −150) | BP(1, 0, 24, 60) | — | Bloxer99, locked, brown wool. |
| 8 | rich | Level 7 home | BP(4, 0, 32, −150) | BP(4, 0, 24, 60) | — | mia.ttv's gold vault with a raider. |
| 9 | safe | Leaving home | [0, 14, 370] | [0, 22, 1300] | — | Mouse height from the curve's centre down the run. |
| 10 | tower | Block tower and train | [−70, 70, 620] | [50, 40, 800] | — | The tower and the winding track. |
| 11 | run | Down the run | [30, 9, 850] | [10, 30, 1700] | — | Mouse height from the carpet band to the door. |
| 12 | cat | The cat | [−80, 18, 1060] | [−10, 18, 1145] | — | The cat on the wood band. |
| 13 | bed | The bed | [110, 110, 1150] | [−110, 55, 1450] | — | The Kid asleep, nightstand, monitor patch. |
| 14 | flash | Flashlight at 80+ | [150, 140, 850] | [−100, 80, 1500] | flash | The Kid sitting up, beam down the run. |
| 15 | door | The hallway door | [30, 22, 1420] | [0, 90, 1700] | — | The end of the run and the open door. |
| 16 | lightson | Lights on | [0, 290, 110] | [0, 0, 1000] | day, flash | The lights-on preset; the cat pounces. |
| 17 | map | Top-down | [0, 2000, 880] | [0, 0, 879] | top, xray | The whole plan from above. |

Field of view 55° vertical, 16:9.

---

## Appendix C: what is out of date

| File | Status | What to use instead |
| --- | --- | --- |
| `design/bedroom-map-brief.md` | Written for the OLD round room (radius 930) and then for "bases inside the curved wall" in the v4 room. Sections 5 (what's there now), 6 (layout, lanes, landmarks), 6b (bases inside the wall: closed burrows with a drywall front, ceiling and found-object props), 7–9 (furniture list, props, walls), 12–15 are superseded. Still valid in spirit: section 2 (style rules, do/don't), 3 (palette, except the room is long now), 10 (lighting ideas), the found-object prop ideas (bottle caps, thimble, push pin, matchbook, matchbox bed, spool), and the method. | This handoff, section 6. |
| `MapConfig.luau`, `build-bedroom.luau`, `MapConfig.spec.luau` | OLD layout. | Rewrite per sections 8 and 9 and Appendix A. |
| `design/new-map-render.html` (v4) | Open plots on the floor, round room. | Reference only (hazard models came from it). |
| `design/game-render*.html` | Round room. | Reference only. |
| `memory/map-and-model-method.md` | Still valid. | — |
| `memory/bedroom-layout-direction.md` | Valid; summary of section 4. | — |

---

## Appendix D: checklists

### D.1 Spec checks for the v6 MapConfig

- [ ] `homeAngle(1) == 191.25` and `homeAngle(8) == 348.75`; steps of 22.5.
- [ ] Every `homeFront(i)` is exactly `HOME_CURVE_RADIUS` from (0, `HOME_CURVE_CENTER_Z`).
- [ ] Every `homeFrame(i).LookVector` points at the curve centre (dot product > 0.999).
- [ ] Neighbouring homes don't touch at the front: the distance between `homeCorner(i, 1, 0)` and
      `homeCorner(i + 1, -1, 0)` is at least 6.
- [ ] Every `BURROW_LAYOUT` prop sits inside the home (|x| + half.X ≤ BURROW_WIDTH / 2, z − half.Z ≥ 0) and in front of
      the pen (z + half.Z ≤ PEN_FRONT).
- [ ] The pen fits inside the home (PEN_WIDTH ≤ BURROW_WIDTH, PEN_BACK ≤ BURROW_DEPTH).
- [ ] `wheelSize(7)` fits beside the door props (radius 10.35, width 9.1; no overlap with ToyIndex or the side stud).
- [ ] `inRoom` is true at (0, 0, 380), (0, 0, 1699), (200, 0, 1000); false at (300, 0, 1000), (0, 0, 1750).
- [ ] `inSafeZone` is true at (0, 0, 40) (r = 340); false at (0, 0, 300) (r = 80, the carpet centre) and at (0, 0, 600).
- [ ] `zoneAt` gives Carpet at z 600, Wood at 1000, Creaky at 1500; nil in the safe zone and outside the room.
- [ ] `noiseAt` is 0 in the safe zone, 1/2/3 in the bands, doubled in the monitor zone (40, 1420).
- [ ] The track is closed, its length is 1841 ± 5, it stays inside the room (|x| ≤ 200), clear of the bed, desk,
      nightstand, tower and fallen block, and it crosses x = 0 exactly twice.
- [ ] Every trap is at least 25 from the track and inside the room.
- [ ] `toySpawns()`: every spawn inside the room, in the band matching its size, not blocked, at least 18 apart.
- [ ] Counts: about 16 / 12 / 6 before the track filter; record the actual numbers.

### D.2 Build acceptance (Studio)

- [ ] `Workspace.Bedroom` rebuilds from the command bar with no errors and returns a summary.
- [ ] Walk from every home to the door: no gaps, no snags on the floor, no z-fighting.
- [ ] Every home: open front, wall between neighbours, framing visible to the top, sign readable, lock button prompt,
      spawn on the matchbox bed, the right level dressing and wheel.
- [ ] The safe ring, the zone lines and labels read from the start.
- [ ] Bed on the runner's right, desk and window on the left, door straight ahead and open.
- [ ] Tower climbable (or flagged if not).
- [ ] Train track continuous; the train runs the full loop (once game code exists).
- [ ] Night lighting matches photo 2; lights-on matches photo 1.
- [ ] Part counts within the budget; FPS fine on a phone.
- [ ] Captures from Appendix B angles shown to Dylan next to the renders.
- [ ] StyLua and Selene pass; committed; Dylan saved the place as `places/TinyToyHeist-Latest.rbxl`; place committed.

### D.3 Before showing Dylan anything

- [ ] Renders (or captures) first; no Studio build he hasn't seen in pictures.
- [ ] The review page's "What changed" and "Still to decide" are current.
- [ ] Every photo matches the current scene (no stale or black images: check sizes and look at a few).
- [ ] Left/right in captions is from the runner's view.
- [ ] Short summary in chat: what changed, what's next, one question if needed.

---

## Appendix E: Dylan's messages, word for word

Every message from Dylan this session, in order, so the next session can read his exact words. Button replies are
marked. Images are described in brackets.

1. [Attached `Download (8).mp4` and `Download (7).mp4`] "watch these to learn how to make better maps and models, but
   i still like the voxel models. https://docs.google.com/document/d/1paXSLH91J5skRbdq9a4axJjZUmP-1YQtU6p7p4vT2fk/edit?tab=t.0"
2. (button) "Write a short brief for the Bedroom map using the video method: style/feel, the references to gather, and
   what/where/why/how. Show it to me before building anything."
3. "not short, give me long"
4. [Two images: a voxel kid's bedroom lit warm and pastel; the same room lit deep blue at night] "1. step over n dodge,
   you should be able to hit them / 2. hmm, yeah sure / 3. moving hazard / 4. voxel rebuild now / 5. you generate but
   ill give some ideas about lighting // photo 1 - lighting i like / photo 2 - lighting i like for night or something"
5. "do u have like, the sketch i made and also the data from the other chat? it should be commited in the git"
6. "wb my idea of how i want the mouse hole plots to look like? i want them in the wall and like where the wood studs
   and cables are, cuz i want it to feel like we are mouses"
7. (button) "Yes, use the smaller room (radius 600, 840 wide), keep the concept v4 hazards with traps out of the lanes,
   bases inside the wall. Start building."
8. "but dont start building, i want renders first, tehy can js be photos and i can js comment on them"
9. [Three photos: OSB sheathing with studs and staggered blocking; studs with white cables stapled up into outlet boxes,
   a white PVC pipe, torn drywall; mineral-wool insulation between metal studs] "i want the mouse houses/holes to be a
   bit more open? so you can see each other's base. also you gotta make it js open, cuz i want it so you can look up
   and see the studs and cables"
10. "also i feel like its a bit too cramped, cuz you know how the place is for steal an egg or break an egg and steal
    it, its very long, and i want something like that, the bed should lowk be on the side so then the hallway door can
    be straight ahead so you can keep running and go past it"
11. [Two Steal an Egg screenshots: a long straight corridor with brick walls, a SAFE ZONE painted at the start, a T-rex
    running down a white band] "see how its long? i want something like that but not super small like theirs, we still
    want the feeling that we are small. so the hallway is in front and not to the side bc then its weird. also it feels
    like its too crowded, like we cant rlly tell it apart. also it might be too detailed, steal an egg and stuff is a
    bit more simpler and its visually more appealing to get addicted to. we dont have to completely dumb it down but we
    can somewhat made it less feature heavy, esp things that we prob will never touch/walk to"
12. [Screenshot of the v6 render's big teal safe zone with bases down both walls] "no i dont want a seperation from the
    mouse spots, i want what we had but i want like a wall between it, we can add a safe spot but we dont have to make
    it huge. i want the "homes" to be in a row or curved, if you have to make them in row so be it, but i want them
    inside the wall, def not seperated into two"
13. "i also think, we are too small? like being honest i feel like the room is still a tad too large bc the pens are
    still lowk small, but i wanna see your update first before aanything"
14. "we can make the safe zone a bit more bigger"
15. "we need the train to cover more distance?"
16. "it looks like the blanket over stuff, it still looks pretty small? maybe shrink a bit more? it has to look
    reasonable"
17. "train track shouldnt js be in a circle, you should up the carts to 5 total including main"
18. "the hamster wheel should level up as well, the toys should be able to freeroam, and bc of that we might have to
    make the bases a bit bigger"
19. "when lights r on, cat should be more aggressive too lol"
20. "ok commit n push, save it so we can start. make handoff.md make it super detailed like thousands thousands of
    lines of detailness"

How each was handled is in section 5.

---

## Appendix F: the bed and the Kid, in final Studio sizes

The render builds the bed in the first-draft (v3) units inside a group scaled 1.25, at (−110, 0, 1600), turned 180°.
For Studio, build the parts directly at final size. Conversion from a v3 part at local centre (lx, ly_bottom, lz):

- final size = v3 size × 1.25
- world x = −110 − 1.25 · lx
- world z = 1600 − 1.25 · lz
- world bottom y = 1.25 · ly_bottom

(The 180° turn flips both x and z.) Values rounded to 0.25.

### F.1 Bed

| Part | v3 size (w x h x d) | v3 centre (x, bottom y, z) | Final size | Final world centre (x, z), bottom y | Colour / material |
| --- | --- | --- | --- | --- | --- |
| Headboard panel | 150 x 86 x 10 | (0, 0, 5) | 187.5 x 107.5 x 12.5 | (−110, 1593.75), 0 | Walnut #7A5233, Wood |
| Headboard step 1 | 126 x 8 x 10 | (0, 86, 5) | 157.5 x 10 x 12.5 | (−110, 1593.75), 107.5 | Walnut |
| Headboard step 2 | 92 x 8 x 10 | (0, 94, 5) | 115 x 10 x 12.5 | (−110, 1593.75), 117.5 | Walnut |
| Headboard step 3 | 46 x 8 x 10 | (0, 102, 5) | 57.5 x 10 x 12.5 | (−110, 1593.75), 127.5 | Walnut |
| Headboard band | 152 x 4 x 11 | (0, 40, 5) | 190 x 5 x 13.75 | (−110, 1593.75), 50 | Dark walnut #5C3D25 |
| Post (room side) | 14 x 112 x 14 | (−80, 0, 6) | 17.5 x 140 x 17.5 | (−10, 1592.5), 0 | Dark walnut |
| Post (wall side) | 14 x 112 x 14 | (80, 0, 6) | 17.5 x 140 x 17.5 | (−210, 1592.5), 0 | Dark walnut |
| Post caps | 18 x 6 x 18 | (±80, 112, 6) | 22.5 x 7.5 x 22.5 | (−10 / −210, 1592.5), 140 | Walnut |
| Post tops | 10 x 4 x 10 | (±80, 118, 6) | 12.5 x 5 x 12.5 | (−10 / −210, 1592.5), 147.5 | Dark walnut |
| Star stickers | 16 / 20 / 16 square | (−42, 62), (0, 74), (42, 62) on the headboard face, z 10.4 | 20 / 25 / 20 | x −57.5 / −110 / −162.5, z 1587, centre y 77.5 / 92.5 / 77.5 | Glowing pale green #DFFFB0 (Neon or a Decal) |
| Legs (4) | 16 x 12 x 16 | (±74, 0, 22) and (±74, 0, 258) | 20 x 15 x 20 | x −17.5 / −202.5; z 1572.5 / 1277.5; 0 | Dark walnut |
| Leg caps | 18 x 2 x 18 | (±74, 10, 22/258) | 22.5 x 2.5 x 22.5 | same x/z, 12.5 | Walnut |
| Frame | 160 x 24 x 250 | (0, 12, 140) | 200 x 30 x 312.5 | (−110, 1425), 15 | Walnut |
| Frame band | 162 x 3 x 252 | (0, 30, 140) | 202.5 x 3.75 x 315 | (−110, 1425), 37.5 | Dark walnut |
| Mattress | 150 x 20 x 240 | (0, 36, 140) | 187.5 x 25 x 300 | (−110, 1425), 45 | Off-white #EDEFF5, Fabric |
| Mattress seam | 151 x 1.5 x 241 | (0, 45, 140) | 188.75 x 1.9 x 301.25 | (−110, 1425), 56.25 | Grey #C9CED8 |
| Pillow | 92 x 10 x 40 | (0, 56, 48) | 115 x 12.5 x 50 | (−110, 1540), 70 | White, Fabric |
| Pillow top | 84 x 4 x 32 | (0, 66, 48) | 105 x 5 x 40 | (−110, 1540), 82.5 | #F4F6FA |
| Duvet top | 158 x 10 x 175 | (0, 54, 172) | 197.5 x 12.5 x 218.75 | (−110, 1385), 67.5 | Quilted royal blue (texture: 3x3 squares #2F6FB9 / #3878C4, dashed white stitching) |
| Duvet drape, upper (2) | 4 x 22 x 175 | (±80, 42, 172) | 5 x 27.5 x 218.75 | x −10 / −210, z 1385, 52.5 | Plain #2F6FB9 |
| Duvet drape, lower (2) | 4 x 22 x 171 | (±82, 22, 172) | 5 x 27.5 x 213.75 | x −7.5 / −212.5, z 1385, 27.5 | Darker #285FA0 |
| Duvet foot, upper | 158 x 22 x 4 | (0, 42, 261) | 197.5 x 27.5 x 5 | (−110, 1273.75), 52.5 | #2F6FB9 |
| Duvet foot, lower | 154 x 20 x 4 | (0, 22, 263) | 192.5 x 25 x 5 | (−110, 1271.25), 27.5 | #285FA0 |
| Folded-back corner | 34 x 1.6 x 34, turned 45° | (54, 64.2, 236) | 42.5 x 2 x 42.5 | (−177.5, 1305), 80.25 | White #F4F6FA |

Note: the wall-side post and drapes sit at x ≈ −210, right against the long wall (inner face −210). Nudge them in by a
stud or two in Studio so they don't z-fight with the wall.

### F.2 The Kid, asleep

| Part | v3 size | v3 centre (x, bottom y, z) | Final size | Final world centre (x, z), bottom y | Look |
| --- | --- | --- | --- | --- | --- |
| Body lump (lower) | 74 x 14 x 124 | (0, 62, 165) | 92.5 x 17.5 x 155 | (−110, 1393.75), 77.5 | Plain duvet blue; breathes (scale y ±6%, 1.2 rad/s) |
| Body lump (upper) | 58 x 10 x 106 | (0, 76, 165) | 72.5 x 12.5 x 132.5 | (−110, 1393.75), 95 | Quilted duvet |
| Head | 44 x 40 x 38 | (0, 58, 52) | 55 x 50 x 47.5 | (−110, 1535), 72.5 | Skin #F2C9A0. `PrimaryPart`. |
| Face | 44 x 40 plane | (0, centre 78, 71.3) | 55 x 50 | (−110, 1510.9), centre y 97.5, facing −z (the room) | Closed eyes, brows, rosy cheeks, open mouth, drool, a snot bubble that grows and pops every ~3 s |
| Hair | 48 x 10 x 42 | (0, 94, 52) | 60 x 12.5 x 52.5 | (−110, 1535), 117.5 | Brown #5A3A22 |
| Hair tufts (5) | 10/9/8/9/7 cubes, 6 tall | (−14,104,52), (6,104,44), (16,102,62), (−4,103,63), (−20,100,40) | ×1.25 | x −92.5, −117.5, −130, −105, −85; z 1535, 1545, 1522.5, 1521.25, 1550; y 130, 130, 127.5, 128.75, 125 | Brown |
| Teddy | ~12 x 26 x 9 voxel bear | (44, 62, 42), turned −0.5 | ×1.25 | (−165, 1547.5), 77.5 | Brown fur #A8743F, muzzle #E8C79A |
| Sleeve | 16 x 30 x 16 | (−84, 34, 120) | 20 x 37.5 x 20 | (−5, 1450), 42.5 | Striped pyjama (blue #7FB6F0 / white) |
| Forearm | 13 x 28 x 13 | (−84, 7, 120) | 16.25 x 35 x 16.25 | (−5, 1450), 8.75 | Skin |
| Hand | 18 x 7 x 20 | (−86, 0, 125) | 22.5 x 8.75 x 25 | (−2.5, 1443.75), 0 | Skin |
| Fingers (4) | 3.6 x 3.6 x 8 | x −79.5, −83.8, −88.1, −92.4; z 138 | 4.5 x 4.5 x 10 | x −10.6, −5.25, 0.1, 5.5; z 1427.5; 0 | Skin |
| Thumb | 4 x 4 x 7 | (−96, 1, 124) | 5 x 5 x 8.75 | (10, 1445), 1.25 | Skin |
| Z sprites | 3 "Z" letters | rise from the head | — | from (−110, 125, 1535) drifting up and toward the room | Pale blue #C9D2FF |

The arm hangs over the room-side edge of the bed (x ≈ 0), onto the Large-toy band: that's the point.

### F.3 The Kid, sitting up (flashlight)

Hidden by default; shown at 80+ noise (and, in the lights-on view, together with the lights).

| Part | v3 size | v3 centre (x, bottom y, z) | Final world (x, z), bottom y |
| --- | --- | --- | --- |
| Pyjama torso | 62 x 58 x 36 | (0, 60, 66) | (−110, 1517.5), 75 |
| Head | 44 x 40 x 38 | (0, 118, 70) | (−110, 1512.5), 147.5 |
| Hair | 48 x 10 x 42 | (0, 156, 70) | (−110, 1512.5), 195 |
| Face (angry) | 44 x 40 | centre (0, 138, 89.2) | (−110, 1488.5), centre 172.5 |
| Arm out front | 14 x 14 x 46 | (34, 96, 104) | (−152.5, 1470), 120 |
| Hand | 14 x 14 x 12 | (34, 96, 132) | (−152.5, 1435), 120 |
| Flashlight | body r4 x 22, head r7→4.5, lens r6.5 | at (34, 103, 140) | (−152.5, 1425), 128.75 |

Beam: a SpotLight from the lens, angle ~0.32 rad, warm white #FFF2B0, sweeping between x −140 and 140 and z 700–1000
(`tx = 140 sin(0.5t)`, `tz = 1000 − 300 |sin(0.5t)|`); a faint visible cone and a pool of light on the floor.

### F.4 Nightstand, lamp, clock, monitor (world)

| Part | Size | Centre (x, z), bottom y | Look |
| --- | --- | --- | --- |
| Nightstand body | 72 x 78 x 72 | (−172, 1650), 0 | #8E6440 |
| Top | 78 x 6 x 78 | (−172, 1650), 78 | #7A5233 |
| Drawer fronts (2) | 1.5 x 24 x 60 | (−135.4, 1650), 12 and 42 | #A77A50, gold knobs 2 x 6 x 7 |
| Lamp base | 20 x 6 x 20 | (−180, 1640), 84 | #5C3D25 |
| Lamp stem | 4 x 14 x 4 | (−180, 1640), 90 | Gold |
| Lamp shades | 38 / 31 / 22 wide, 9 / 9 / 8 tall | (−180, 1640), 104 / 113 / 122 | Warm glowing #FFE2B0 (Neon), PointLight #FFA552 |
| Clock | 22 x 15 x 12 | (−156, 1668), 84 | Red #E04848, face "2:00" in red digits on the room side |
| Baby monitor | 14 x 20 x 7 | (−152, 1670), 84 | White with a green LED and pulsing signal arcs; antenna |

---

## Appendix G: draft Luau for one home

A starting point for the home builder in the new `build-bedroom.luau`. It uses the old builder's `place` and
`folder` helpers (same signatures) and the Appendix A MapConfig. It builds the shell, framing, cables (as Beams),
fairy light, pen and the door props for one level. Theme dressing is a table of small functions.

```lua
-- One home, built in its own frame: origin at the middle of the open front, LookVector into the room, +Z back into
-- the wall. x across (walking in, -x is on your right), matching MapConfig.BURROW_LAYOUT.
local BW, BD, H = MapConfig.BURROW_WIDTH, MapConfig.BURROW_DEPTH, MapConfig.WALL_HEIGHT
local PINE, PINE_DARK, OSB = rgb(0xE2B77C), rgb(0xC9A066), rgb(0xC9A46A)

local LEVEL_LOOK = {
	{ fairy = 0xFFD27A, pen = 0xC49A6C, wheel = { 0xD9B27C, 0xFFC93C, 0x8A5A34 } }, -- Cardboard
	{ fairy = 0xFFB0C8, pen = 0xF28DB2, wheel = { 0xF28DB2, 0xFFFFFF, 0x7FD6E8 } }, -- Sock-lined
	{ fairy = 0xFFE08A, pen = 0x3DA5FF, wheel = { 0xE04848, 0xFFC93C, 0x4DA8FF } }, -- Toy bricks
	{ fairy = 0xFF9A4A, pen = 0xC89A62, wheel = { 0xB07A48, 0xE8C890, 0x6B4A2E } }, -- Cosy cabin
	{ fairy = 0xFF8FC8, pen = 0xFF8FC8, wheel = { 0xFF8FC8, 0xFFFFFF, 0x8FE8D0 } }, -- Candy land
	{ fairy = 0x7AE8FF, pen = 0x1A1430, wheel = { 0x1A1430, 0x7AE8FF, 0x9B7BFF } }, -- Arcade neon
	{ fairy = 0xFFE07A, pen = 0xFFC93C, wheel = { 0xFFC93C, 0xFFF1B0, 0xD9A21E } }, -- Golden vault
}

local function buildHome(parent: Instance, index: number, level: number): Model
	local frame = MapConfig.homeFrame(index)
	local function at(x: number, y: number, z: number): CFrame
		return frame * CFrame.new(x, y, z)
	end
	local home = Instance.new("Model")
	home.Name = "Hole" .. index
	home:SetAttribute("HoleIndex", index)
	home:SetAttribute("Owner", 0)
	home:SetAttribute("Level", level)
	home:SetAttribute("Locked", false)
	home.Parent = parent
	local look = LEVEL_LOOK[level]
	local gold = level == 7
	local wood = if gold then rgb(0xFFC93C) else PINE

	-- Shell: subfloor, back sheathing, side studs, back studs, blocking, top plate
	local shell = folder(home, "Shell")
	local floor = place(shell, "Floor", Vector3.new(BW + 10, 1, BD), at(0, -0.5 + MapConfig.BURROW_FLOOR_LIFT, BD / 2), OSB, {
		material = Enum.Material.WoodPlanks,
		attributes = { FloorType = "Burrow", Noise = 1 },
	})
	place(shell, "Sheathing", Vector3.new(BW + 10, H, 2), at(0, H / 2, BD + 1), if gold then wood else OSB, {
		material = Enum.Material.Wood,
	})
	for _, side in { -1, 1 } do
		place(shell, "SideStud", Vector3.new(5, H, BD), at(side * (BW / 2 + 2.5), H / 2, BD / 2), wood, {
			material = Enum.Material.Wood,
		})
	end
	for _, x in { -30, 30 } do
		place(shell, "BackStud", Vector3.new(8, H, 10), at(x, H / 2, BD - 5), wood, { material = Enum.Material.Wood })
	end
	local bays = { { -47, 26 }, { 0, 52 }, { 47, 26 } }
	for k, bay in bays do
		for _, y in { 120, 240 } do
			local lift = if k == 2 then 6 else 0
			place(shell, "Blocking", Vector3.new(bay[2], 8, 10), at(bay[1], y + lift + 4, BD - 5), PINE_DARK, {
				material = Enum.Material.Wood,
			})
		end
	end
	place(shell, "TopPlate", Vector3.new(BW + 10, 8, BD), at(0, H - 4, BD / 2), PINE_DARK, {
		material = Enum.Material.Wood,
	})

	-- Torn drywall up both front edges: a fixed jagged pattern per home
	for _, side in { -1, 1 } do
		for y = 0, H - 14, 14 do
			local w = 3 + (y * 7 + index * 5 + (side + 1) * 3) % 9
			place(shell, "Drywall", Vector3.new(w, 14, 4), at(side * (BW / 2 + 5 - w / 2), y + 7, 1), rgb(0xF2EFE8), {
				material = Enum.Material.SmoothPlastic,
			})
		end
	end

	-- Cables: white runs up two studs and a yellow one across, as Beams between attachments (they sag nicely)
	local cables = folder(home, "Cables")
	local function cable(color: number, a: Vector3, b: Vector3, sag: number)
		local p0 = place(cables, "Anchor", Vector3.new(1, 1, 1), at(a.X, a.Y, a.Z), rgb(color), { transparency = 1, collide = false })
		local p1 = place(cables, "Anchor", Vector3.new(1, 1, 1), at(b.X, b.Y, b.Z), rgb(color), { transparency = 1, collide = false })
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.Parent, a1.Parent = p0, p1
		local beam = Instance.new("Beam")
		beam.Attachment0, beam.Attachment1 = a0, a1
		beam.Width0, beam.Width1 = 2.2, 2.2
		beam.Color = ColorSequence.new(rgb(color))
		beam.CurveSize0, beam.CurveSize1 = -sag, sag
		beam.FaceCamera = true
		beam.Parent = p0
	end
	local cz = BD - 11
	cable(0xF4F1E8, Vector3.new(-26, 30, cz), Vector3.new(-26, H - 8, cz), 2)
	cable(0xF4F1E8, Vector3.new(34, 0, cz), Vector3.new(34, H - 8, cz), 2)
	cable(0xF2C94C, Vector3.new(-60, 64, cz), Vector3.new(60, 64, cz), 3)

	-- Outlet box with glowing slits, and the fairy light on the yellow cable
	place(home, "Outlet", Vector3.new(9, 13, 5), at(-30, 30.5, BD - 12.5), rgb(0x3A6FD8))
	local fairy = folder(home, "FairyLight")
	for k = 0, 8 do
		local x = -50 + k * 12.5
		place(fairy, "Bulb", Vector3.new(2.4, 2.4, 2.4), at(x, 60 - math.sin(k / 8 * math.pi) * 1.5, cz - 1.6),
			if k % 2 == 1 then rgb(look.fairy) else rgb(0xFFF1C8), { material = Enum.Material.Neon, shape = Enum.PartType.Ball, collide = false })
	end
	local glow = place(fairy, "Glow", Vector3.new(1, 1, 1), at(0, 50, BD / 2), rgb(look.fairy), { transparency = 1, collide = false })
	local light = Instance.new("PointLight")
	light.Color = rgb(look.fairy)
	light.Range = 40
	light.Brightness = if level == 6 then 2 else 1.4
	light.Parent = glow

	-- Toy pen: the toys' own floor at the back, dressed for the level; roaming bounds as attributes
	local penDepth = MapConfig.PEN_BACK - MapConfig.PEN_FRONT
	local pen = place(home, "Pen", Vector3.new(MapConfig.PEN_WIDTH, 0.6, penDepth),
		at(0, MapConfig.BURROW_FLOOR_LIFT + 0.3, (MapConfig.PEN_FRONT + MapConfig.PEN_BACK) / 2), rgb(look.pen), {
			material = if gold then Enum.Material.Foil else Enum.Material.Fabric,
		})
	pen:SetAttribute("PenMin", Vector3.new(-MapConfig.PEN_WIDTH / 2 + 6, 0, MapConfig.PEN_FRONT + 4))
	pen:SetAttribute("PenMax", Vector3.new(MapConfig.PEN_WIDTH / 2 - 6, 0, MapConfig.PEN_BACK - 6))

	-- Door props at BURROW_LAYOUT (cash pile, lock pin, Index, wheel, spawn): see section 6.7 for their looks
	-- ... buildThimble(home, at(28, 0, 14)), buildPushPin(home, at(-30, 0, 12)), buildIndex(home, at(-52, 0, 30)),
	-- ... buildLevelWheel(home, at(50, 0, 22), level), buildMatchboxSpawn(home, at(0, 0, 24))

	-- Sign on a lolly stick at the front corner, and the lock bars across the open front (hidden until locked)
	-- ... buildSign(home, at(-54, 0, 3)), buildLockBars(home, frame)

	return home
end
```

Notes:
- Roblox `PointLight.Range` maxes at 60; the render's ranges (120 etc.) are three.js units and don't carry over.
- Beams face the camera, so they look like round cables from most angles; for close-ups, short Cylinder parts are an
  alternative.
- `Enum.Material.Foil` (gold) and `Neon` (fairy bulbs, LED strips, outlet slits) give the right look cheaply.
- Mirror check: the sign is at lx −54 in this code because Roblox's +X (RightVector) is the render's −X; the render puts
  it at local x 54 in a frame whose +X is flipped. Both land on the same corner (the corner on your left as you walk in).
  Verify in Studio once and adjust.

---

## Appendix H: names and attributes

Keep these stable; game code and tests find things by them.

| Instance | Name | Attributes | Notes |
| --- | --- | --- | --- |
| The map | `Workspace.Bedroom` (Model) | — | Rebuilt by the builder (old one destroyed first). |
| A home | `Bedroom.Holes.Hole1..8` (Model) | `HoleIndex` (1..8), `Owner` (UserId, 0 = free), `Level` (1..7), `Locked` (bool) | Same as today. Consider `Homes/Home1..8` only if nothing reads `Holes`. |
| Home floor | `Hole#.Shell.Floor` | `FloorType = "Burrow"`, `Noise = 1` | |
| Toy pen | `Hole#.Pen` | `PenMin`, `PenMax` (Vector3, home space) | New. Roaming bounds. |
| Cash pile | `Hole#.CashPile` | — | Walk over to collect. |
| Lock button | `Hole#.LockButton` | — | Has a ProximityPrompt. |
| Index | `Hole#.IndexBook` (+ `IndexStand`) | — | |
| Speed wheel | `Hole#.Wheel` (Model) + `Hole#.RunPoint` | `Level` on the wheel (new) | Game code spins it and puts the runner at RunPoint. |
| Spawn | `Hole#.Spawn` (SpawnLocation) | — | Under the matchbox bed. |
| Sign | `Hole#.Sign` | — | SurfaceGui with owner name and $/s. |
| Lock | `Hole#.DoorBarrier`, `Hole#.LockBars` | — | Barrier collides only when locked; bars shown when locked. |
| Floor parts | `Bedroom.Floor.*` | `FloorType` (`Safe`, `Carpet`, `Wood`, `Creaky`), `Noise` (0/1/2/3) | Noise code can read the part under a player, or call `MapConfig.noiseAt`. |
| Monitor zone | `Bedroom.Hazards.MonitorZone` | `NoiseMultiplier = 2` | Non-colliding. |
| Loose boards | `Bedroom.Hazards.LooseBoards.Board1..6` | `Noise` spike value | |
| Traps | `Bedroom.Hazards.Traps.Trap1..4` | `Armed` (bool) | |
| Cat | `Bedroom.Hazards.Cat` (Model) | `State` (`Patrol`, `Stalk`, `Pounce`), `Aggressive` (bool) | |
| Train | `Bedroom.Train.Cars.Car1..5`, `Bedroom.Train.Track` | — | Path from `MapConfig.trackPoints`. |
| Giant Kid | `Bedroom.GiantKid` (Model), `PrimaryPart = Head` | `State` (`Asleep`, …) | Sitting-up parts in a child folder, hidden by default. |
| Toy spawns | `Bedroom.ToySpawns.S01…`, `M…`, `L…` | `Size` (`S`/`M`/`L`) | Invisible. |
| Lighting presets | `ReplicatedStorage.Shared.BedroomLighting` | — | `Night`, `LightsOn`, `apply(preset, tweenTime)`. |

---

## Appendix I: glossary

| Word | Meaning here |
| --- | --- |
| Home / hole / base / pen | A player's space in the curved wall at the start. The plan and code say "hole"; Dylan says homes, holes, bases and pens. "Pen" here means the toy area at the back of a home. |
| The run | The long straight part of the room from the start area to the far wall. |
| Start area | The half-circle at the start, inside the curve of homes. |
| Safe zone | The teal ring in front of the homes (r 240..380 round (0, 380)). |
| Bands | The floor zones down the run: carpet, wood, creaky boards. |
| Shoulders | The angled walls joining the wide start area to the narrow run. |
| Wall-between | The solid wall between two neighbouring homes. |
| Framing | The studs, blocking and plates inside a home's wall cavity. |
| OSB | Oriented strand board: the chipboard sheathing at the back of each home ("APA RATED" stamp). |
| Blocking | Short horizontal 2x4s between studs, staggered (Dylan's photo). |
| Top plate | The horizontal 2x4 along the top of the wall; what you see when you look up in a home. |
| Lights on | The bright warm lighting when the Kid wakes (photo 1). |
| Night | The default deep-blue lighting while the Kid sleeps (photo 2). |
| Concept v4 | The other chat's render: small round room, open fenced plots on the floor. |
| Concept v5 | This session's round room with closed burrows: rejected. |
| Concept v6 | This session's long run with the curved wall of open homes: current. |
| Runner's left / right | Left/right for a player facing down the run (+z): left is +x. |
| Render page | `design/bedroom-v6-render.html`. |
| Review page / artifact | `design/bedroom-v6-review.html`, published at the artifact link. |
