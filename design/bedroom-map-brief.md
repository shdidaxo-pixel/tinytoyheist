# Kid's Bedroom: map brief

This brief follows the method from the deadj.rodev videos: pick the style and feel, gather references that match it, then
write a prompt that says what, where, why and how. It covers the Kid's Bedroom only: the room players see first, where
they spend their first sessions and judge the game.

**Sources:** Dylan's answers and two lighting photos (19 Oct), his "bases inside the wall" idea, the layout from his first
sketch (the sketch itself was never committed; only its layout survives, in `MapConfig` and `design/game-render.html`),
and the other chat's concept v4 (`design/new-map-render.html`), whose hazards this brief borrows. Section 15 lists where
the two disagree.

Positions are in studs, taken from `MapConfig` and `tools/build-bedroom.luau`. x runs across the room, z runs away from
the back wall, and y is up. The bed sits at x = 0, the floor rings are centred on (0, 210), and a player is about 5 studs
tall.

---

## 1. Goal

**Make the bedroom feel like a giant, cosy, slightly scary playground seen from an inch tall, in our voxel style, without
touching the game.** A new player should know where they are within a second, find their hole and the bed without a
map, and want to explore the corners.

### Don't touch

- `MapConfig` numbers: room size, rings, hole angles, burrow layout, spawn rings.
- The 8 mouse holes: their positions, arches and tunnels, and every name and attribute game code reads inside a
  burrow (`Hole1`–`Hole8` with `HoleIndex`, `Owner`, `Level`, `Locked`; `Floor`, `Slots`/`SlotN`, `CashPile`,
  `LockButton`, `IndexBook`, `Spawn`, `DoorBarrier`, `LockBars`, `Sign`, `LevelPlate`). The burrow **interiors** get
  restyled as wall cavities (section 6b), but these names and the `BURROW_LAYOUT` positions stay.
- The floor rings and their `FloorType` and `Noise` attributes, which drive the noise system.
- The voxel floor tiles (`FloorTiles`), which stay as they are.
- The `ToySpawns` folder and its points.
- The `GiantKid` model's part names, `PrimaryPart` and `State` attribute. Game code animates him, so if he gets a voxel
  rebuild, these must stay.
- The Speed training wheel and its `Wheel` and `RunPoint` names.

### Allowed to change

- All the furniture in the `Furniture` folder: its look, and where needed its shape. Footprints should stay close to what
  they are, so nothing moves onto a spawn point.
- Wall dressing: wallpaper, posters, the window, the door, outlets, trim.
- New folders for landmarks, scatter props and lights.
- Lighting values at the bottom of the builder.

---

## 2. Style and feel

### Mood in one line

> "It's 2 a.m., the kid is asleep, and the bedroom floor is a whole world."

### Three pillars

1. **Huge.** Furniture should loom. The mattress top is already 84 studs up, about 17 times a player's height, so lean
   into it. Make the bed legs look like tree trunks and the desk like a building. Players should look up a lot.
2. **Cosy and nostalgic.** It's a kid's room people remember: glow stars, a night-light, a toy box, crayons on the
   carpet, a quilt. Warm and familiar, not creepy-pasta.
3. **A bit tense.** It's dark, the Giant Kid is right there, and the boards by the bed creak. Shadows under the furniture
   are good places to hide. It should never be horror, just the feeling of "don't wake him."

### Visual style rules

- **Voxel and studded**, like Steal an Egg (`design/screens/egg-style/stud-tile.png`) and the deadj.rodev maps: chunky
  blocks, visible studs on top surfaces, bright solid colours.
- **No smooth or realistic shapes.** No spheres (the beanbag is a sphere mesh today), no cylinders unless built from
  stepped blocks, no realistic textures.
- **Readable colour blocks.** Each object gets 2 to 4 flat colours plus one darker shade for edges and undersides.
- **Big shapes first, details second.** Each furniture piece reads as a silhouette from across the room, then shows
  details (studs, quilting, knobs, book spines) up close.
- **Same pattern, different colour per zone.** The video's trick: keep the grid or stud pattern everywhere and shift the
  colour. Here the three floor rings already do that, so wall dressing and props should follow the same colour bands.

### Do and don't

| Do | Don't |
| --- | --- |
| Stepped, blocky edges | Smooth bevels, spheres, wedges as decoration |
| Studs on every top surface you can stand on or see from above | Studs on vertical faces |
| A darker underside on furniture (fake ambient occlusion) | Leaning on Roblox shadows alone, which are weak at night |
| One clear landmark per side wall | Clutter in the lanes from holes to the bed |
| More props near the holes, fewer by the bed | An even spread of props everywhere |
| Neon only for light sources (lamp, night-light, stars, window) | Neon on ordinary objects |

---

## 3. Colour palette

Existing colours stay. New ones fit around them.

| Use | Colour | Hex | Notes |
| --- | --- | --- | --- |
| Walls | Sage green | `#9DB08A` | **Changed from night blue `#4E5A88`.** Dylan's photos paint true colours and let the light make it night; the blue ambient turns sage to blue-grey |
| Wallpaper stripe (new) | Darker sage | `#8A9E78` | Vertical stripes 24 studs wide, the same grid as the floor tiles |
| Wall cavity wood (new) | Raw pine | `#D9B27A` / `#B88C55` | Studs and plates inside the wall; the darker shade for end grain and edges |
| Insulation (new) | Candy pink | `#F2A6B8` / `#E58BA1` | Fluffy voxel batts between studs |
| Cable (new) | Yellow and white | `#F2C94C` / `#F4F1E8` | Electrical cable running through drilled studs |
| Drywall back (new) | Paper grey | `#CFCAC0` | The inside face of the room wall |
| Baseboard and trim | Cream | `#E6E1D6` / `#F1EBDD` | Existing |
| Bed and headboard wood | Walnut | `#7A5233` | Existing; add a darker `#5C3D25` for edges |
| Duvet | Royal blue | `#2F6FB9` | Existing; add quilt squares in `#3B7FCC` |
| Mattress and pillow | Off-white | `#EDEFF5` | Existing |
| Creaky ring | Dark board | `#6B4F35` | Existing |
| Wood ring | Mid board | `#8A6A48` | Existing |
| Carpet ring | Purple | `#6A5BA0` | Existing |
| Rug (new) | Teal and mustard | `#3FA7A0` / `#E8B84A` | Block-pattern rug on the carpet ring |
| Toy chest | Red with gold lid | `#C0523E` / `#D9B44A` | Existing |
| Lamp and night-light glow | Warm orange | `#FFB36B` | Existing lamp light |
| Moonlight | Pale blue | `#B9CCFF` | Existing window light |
| Glow stars (new) | Soft green-yellow | `#D8FF9A` | Neon, on the ceiling and the upper walls |
| Toy brights | Red, blue, green, yellow, purple | `#E04848` `#4DA8FF` `#3DDC97` `#FFC93C` `#9246D4` | The existing book colours, reused for props |

---

## 4. References to gather

Collect them in one doc, or in `design/references/bedroom/`, with **a line under each picture saying exactly what to take
from it**. The video's point: without that note, the AI copies the wrong part of the picture.

| # | What to search for | What to take from it | What to ignore |
| --- | --- | --- | --- |
| 1 | Steal an Egg map screenshots | Stud size, how bright the colours are, how much is studded | Their egg props and layout |
| 2 | Grow a Garden / Dig a Pet map screenshots | Prop density per area, how they keep paths clear | Their outdoor theme |
| 3 | deadj.rodev voxel jungle and sakura maps (from the video) | The grid walls and floors, layered canopies built from blocks, one landmark per wall | The theme itself |
| 4 | Floor-level shots of Andy's room (Toy Story) | Camera height, how the bed and desk loom, toys as scenery | The realistic rendering |
| 5 | "Honey, I Shrunk the Kids", "The Borrowers", "Arrietty" | Everyday objects at giant scale: a crayon as a log, a marble as a boulder | Live-action textures |
| 6 | MagicaVoxel bedroom / "voxel kids room" renders | Block shapes for the bed, desk, shelf, chest and beanbag | Tiny voxel sizes; ours are bigger and chunkier |
| 7 | Kid's bedroom at night with a night-light (photos) | The balance of blue moonlight and warm lamp pools, and how the light falls across the floor | Real-world mess |
| 8 | Lego bricks, crayons and marbles on a carpet (photos) | Which props, how many, and how they cluster | Exact brands |
| 9 | Glow-in-the-dark star ceilings | Star sizes and spacing | — |
| 10 | Wooden toy train tracks (photos) | Track shape for the left-side landmark | — |

If a picture doesn't exist (for example "voxel giant bed seen from a mouse's height"), AI-generate one, as the video
suggests, and save it with the others.

### Gathered so far

| File | From | Take from it |
| --- | --- | --- |
| `design/references/bedroom/01-lighting-day.png` | Dylan | **The lights-on look.** Soft warm light, pastel colours (sage walls, peach wood, lavender rug), gentle shadows that fill in, small warm lamp glow. Small voxels, studded toys, posters made of pixels. |
| `design/references/bedroom/02-lighting-night.png` | Dylan | **The night look (the default).** The same room and colours, lit deep blue. Warm orange pools only at the lamp and the window slats; the monitor glows green. Darks are blue, not black, and you can still read every object. |
| Figma: "Tiny Toy Heist - Bedroom References" ([file](https://www.figma.com/design/3ZlBNM6Qd9WM7yyJpXaS17)) | AI-generated | Six pictures: floor-level night view, block tower and train, sock heap and backpack under the window, the voxel Giant Kid asleep, toy clutter on the rug, the whole room with the lights on. **Not reviewed yet:** the Figma Starter plan hit its MCP call limit before they could be downloaded. Export them into this folder when you can. |

### Still to find (for the inside-the-wall bases)

| What to search for | Take from it |
| --- | --- |
| "inside wall framing studs insulation wiring" photos | How 2×4 studs, top and bottom plates, pink batts, cable runs and outlet boxes sit together |
| "mouse house inside wall" illustrations (Brambly Hedge, Stuart Little, Ratatouille, The Tale of Despereaux) | Found-object furniture: thimbles, spools, matchboxes, bottle caps, buttons |
| Cartoon mouse hole in a baseboard (Tom and Jerry) | The arch shape and dark doorway seen from the room |

---

## 5. What's there now

| Thing | Where | Now | Problem |
| --- | --- | --- | --- |
| Bed (frame, mattress, duvet, pillow, headboard) | x 0, z 22–397 | Smooth flat boxes | Looks grey-box; no quilting, no wood grain blocks |
| Giant Kid | On the bed | 6 flat boxes | Reads as blocks, not a sleeping kid |
| Nightstands | x ±177, z 69 | Plain cubes | Nothing on them except the left lamp |
| Lamp | Left nightstand | A neon cylinder | Cylinder; the only warm light in the room |
| Toy chest | x −495, z 75 | Red box, gold lid | Fine colours, flat shape |
| Desk and chair | x 480, z 82 / x 465, z 180 | Thin boxes | Good silhouette; needs voxel detail and things on the desk |
| Bookshelf | Left wall, x −570, z 495 | A box with 21 book boxes | No shelves showing; books float |
| Beanbag | x −285, z 600 | Orange sphere mesh | Not voxel, and **it sits right in lane 8** (126°, the lane is at 128°). Move it to about x −380, z 480. |
| Cardboard boxes | x 300, z 630 and x 375, z 705 | Two boxes | Plain, and **both sit in lane 1** (53–55°, the lane is at 52°). Move them to about x 430, z 300–380, beside the Sock Mountain. |
| Window | Right wall, x 600, z 345, high up | A neon panel | No frame, no curtains, no moon |
| Locked door | Left wall, x −598, z 330 | A thin box with a knob | No frame or gap of light underneath |
| Walls | Back wall, side walls, curved front wall | Flat blue | Empty; nothing to look at above eye height |
| Floor between holes and bed | 930 studs from the bed to the holes | Tiles only | Huge empty plain; no landmarks or props |

---

## 6. Layout plan

### Zones

The three floor rings already set the gameplay. The dressing should make each one feel different, not just look
different.

| Ring | Distance from bed | Toys | Noise | Feel | Dressing |
| --- | --- | --- | --- | --- | --- |
| Creaky | 0–390 | Large | x3 | Danger: right under the Giant | Bare dark boards, few props, a slipper, the bed's shadow. Open and exposed on purpose. |
| Wood | 390–660 | Medium | x2 | The middle: furniture land | The beanbag, boxes, bookshelf, landmarks. Medium props. |
| Carpet | 660–930 | Small | x1 | Safe-ish: near the holes | The rug, the most small props, crayons, bricks, a cosy feel. |

### Keep-clear lanes

Each hole has a straight run to the bed. **Keep a lane 30 studs wide clear of anything solid along each of these lines**,
from the hole doorway at radius 930 to the bed at radius about 200:

| Hole | Angle | Doorway near |
| --- | --- | --- |
| 1 | 52.0° | x 573, z 943 |
| 2 | 62.9° | x 424, z 1038 |
| 3 | 73.7° | x 261, z 1103 |
| 4 | 84.6° | x 88, z 1136 |
| 5 | 95.4° | x −88, z 1136 |
| 6 | 106.3° | x −261, z 1103 |
| 7 | 117.1° | x −424, z 1038 |
| 8 | 128.0° | x −573, z 943 |

Flat decorations that don't collide (the rug, crayon marks, scattered paper) may cross a lane. Anything solid may not.

### Keep-clear spawn points

Nothing solid within **8 studs** of any `ToySpawns` point. Players need to reach every toy and drag it out. The builder
can check this the same way the spec checks the burrow layout.

### Landmarks: one big thing per side

The video puts one landmark against each wall (a temple pyramid on one side, a waterfall on the other). Here the side
walls are the open space outside the lanes: angles below 52° and above 128°, roughly x 400–600 on each side, z 150–850.

**Left side (x < 0): the Block Tower and the Train Track.**
- **Where:** near the left wall, centred around x −500, z 680, just in front of the bookshelf. Checked against lane 8:
  the tower and a track loop of radius 45 round it stay about 60 studs clear of the lane's edge.
- **What:** a tower of big toy blocks (letter blocks A, B, C, each about 30 studs) stacked 4 or 5 high and leaning, with
  one fallen block lying on its side. A wooden train track loops round its base.
- **Why:** you can see it from any left-side hole, so "my hole is by the tower" works. The fallen block gives a hiding
  spot.
- **Climbable (decided):** yes, it's a lookout. The blocks step up like stairs (each one offset so you can jump to the
  next) to a flat top about 120 studs up, where you can see the whole floor and the Giant. Nothing up there is worth
  stealing, so it's a scouting spot, not a shortcut.
- **The train (decided): a moving hazard.** A wind-up train of three carriages runs round the track on a loop. It's loud
  (its rattle adds noise to anyone near it) and it knocks you over and makes you drop a carried toy if it hits you. You
  hear it before you see it. The track loop stays outside every lane, so it's a hazard you choose to cross, never one
  in the way home. Game code drives it; the map gives it a `Track` path (a folder of ordered point parts) and a `Train`
  model.

**Right side (x > 0): the Sock Mountain and the Backpack.**
- **Where:** against the right wall under the window, around x 480, z 450–650.
- **What:** a heap of socks and a dropped school backpack lying on its side with its zip open, pencils and a lunchbox
  spilling out. Moonlight from the window falls right on it.
- **Why:** it's the bright, moonlit corner, so it reads from any right-side hole. The open backpack is a cave to duck
  into.

**Back corners (behind the bed line):**
- Back left: the toy chest, lid propped open, with toys poking out. It's already there, so rebuild it as the landmark.
- Back right: the desk, with a desk lamp switched off, a stack of books, a pencil cup and a drawing pinned to the wall
  above.

**The middle (in front of the bed, between the lanes):**
- A rug on the carpet ring (flat, doesn't collide), with a big block pattern in teal and mustard. It marks "the front"
  and gives the carpet zone colour.

---

## 6b. The bases: inside the wall

**Dylan's idea: you're mice, so your base is inside the wall, between the wooden studs, with the cables and
insulation.** You run through the mouse hole in the baseboard and come out in the hidden space behind the bedroom wall.
That's home.

### Why it works

- It sells the fantasy straight away: the room is the giant's world, the wall is yours.
- It's a strong contrast: the room is dark blue and open; the wall is warm, cramped and cosy.
- It suits the hole level themes. Each upgrade is the mouse furnishing their bit of wall with better found stuff.
- The layout already supports it: the burrows sit right behind the curved wall, so this is a restyle, not a move.

### Scale

A player is 5 studs tall, roughly an inch, so **1 inch ≈ 5 studs**. Real framing at that scale:

| Real thing | Real size | In studs | What we use |
| --- | --- | --- | --- |
| 2×4 wall stud | 1.5 × 3.5 in, every 16 in | 7.5 × 17.5, every 80 | Studs 8 wide, about 40 apart, so each burrow's back wall has 3 bays |
| Wall cavity depth | 3.5 in | 17.5 | **100**: far too thin for real, so stretch it (game license). It still reads as "inside a wall" thanks to the studs and the drywall |
| Electrical cable | 0.4 in thick | 2 | 2-stud cables |
| Outlet box | 2 × 3 × 3 in | 10 × 15 × 15 | Same, glowing from the room side |
| Nail | 0.1 × 3 in | 0.5 × 15 | Chunky 1-stud nails poking through the drywall, for detail |

The burrow keeps its size (120 wide, 100 deep, 40 tall) and its prop positions (`BURROW_LAYOUT`, slot offsets), so game
code and specs don't change. Only the dressing changes.

### What's in a burrow

Walking in through the tunnel (the thickness of the baseboard and drywall):

- **The front wall** (the room side) is the **back of the drywall**: grey paper board with a few nails poking through,
  and the arch of the mouse hole. The lock bars and door barrier stay on this arch.
- **Wooden studs** stand floor to ceiling. Each side wall *is* a stud, a big pine beam running front to back, just
  as real studs span the cavity. Along the back wall, two more stud faces split it into three bays (at x −20 and 20,
  set into the back wall so they never block the slots, spawn or wheel). They rest on a **bottom plate** (a 2×4 lying
  flat along the floor edges) and hold up a **top plate** at the ceiling. Raw pine colour, with end grain and a few
  knots.
- **Pink insulation** fills the back wall between studs: fluffy voxel batts, slightly bulging, a bit torn in places.
- **Cables** run sideways through holes drilled in the studs, about two thirds up: one yellow and one white, sagging a
  little between studs, held by staples. One drops down to an **outlet box** on the front wall, and warm room light
  leaks through its slots. That's the main light in the base.
- **A copper pipe** runs up one side, for colour.
- **The ceiling** is the underside of the top plate and the floor above: dark wood joists.
- **The floor** is the bottom plate and dusty boards, with crumbs and a dropped bead or two.

### Base props, made from found stuff

Same game objects, mouse versions:

| Game object (name stays) | Mouse version |
| --- | --- |
| `Slots` (toy shelf spots) | Each slot is a **bottle cap** turned upside down, a little stage for a toy |
| `CashPile` | A pile of **coins and shiny buttons** in a thimble or half a walnut shell |
| `LockButton` | A big red **push pin** you press, its point stuck in the floor |
| `IndexBook` / `IndexStand` | A **matchbook** propped open on a **domino** stand |
| Speed training wheel | Already a cardboard spool: keep it. It's perfect for a mouse |
| `Spawn` | A **matchbox bed** with a scrap of sock as a blanket |
| `Lamp` | Replace the bulb with a **Christmas fairy light** hanging off the cable, plus the outlet glow |
| `Sign` / `LevelPlate` (room side, over the hole) | A **lolly stick** sign pinned above the arch with the owner's name |

### Level themes inside the wall

The existing themes (`HOLE_LEVELS`) become how well the mouse has done up their bit of wall:

| Level | Theme | Inside the wall |
| --- | --- | --- |
| 1 | Cardboard | Bare studs and insulation, cardboard scraps on the floor, one fairy light |
| 2 | Sock-lined | Odd socks stuffed over the insulation like wallpaper, a sock rug |
| 3 | Toy bricks | Brick shelving between the studs, a brick floor |
| 4 | Cosy cabin | Matchstick panelling, a tea-light "fireplace", a stamp as a painting |
| 5 | Candy land | Sweet wrappers on the walls, gumdrop stools, a lolly lamp |
| 6 | Arcade neon | LED strips along the cables, a calculator screen glowing, a game cartridge table |
| 7 | Golden vault | Gold foil over everything, coins stacked like pillars, a jewel in the ceiling |

### Seeing into other bases

Raiding works better when you can see what's worth stealing. Optional: a **crack in the drywall** above each mouse
hole (a jagged gap about 20 × 12) lets players in the room peek at the best toy on display. It doesn't change any
gameplay rules, and it can be added later if raids feel too blind. (The other chat's concept solved this with open
plots on the floor; see section 15.)

---

## 7. Furniture rebuild list

Each piece keeps roughly its current footprint. All of them are built from blocks, studded on top, with a darker shade
on the edges and undersides.

| Piece | Voxel version |
| --- | --- |
| **Bed frame** | Walnut blocks with visible plank lines (alternate two browns). The legs are thick stepped posts like tree trunks: you walk between them and under the bed. |
| **Headboard** | Tall walnut panel with a stepped top edge and two round-ish knobs built from blocks. A glow-star sticker or two on it. |
| **Mattress** | Off-white slab with a slight stepped edge and a light grey seam line. |
| **Duvet** | Quilted: a grid of slightly raised squares in two blues. Hangs over the sides in a stepped drape. One corner flipped up so you can see the white underside. |
| **Pillow** | Chunky stepped pillow, slightly squashed where the head is. |
| **Giant Kid** (rebuild now, decided) | Rebuilt as a voxel kid under the duvet: a head with closed eyes, messy hair blocks, one arm hanging off the edge (already there) with a voxel hand. Same part names, `PrimaryPart` and attributes. A small "Zzz" made of blocks floating above, which game code can bob. |
| **Nightstands** | Two-drawer stands with knobs. Left: the lamp and a cup. Right: an alarm clock with a glowing face (small neon) and a book. |
| **Lamp** | Stepped shade (3 or 4 rings of blocks getting narrower) on a block base. Keeps the neon and warm `PointLight`, range up to about 90. |
| **Toy chest** | Lid propped open at an angle on a block hinge. Inside: a teddy ear, a ball and a robot arm sticking out. Gold trim blocks on the corners. |
| **Desk** | Top with a stepped front edge, drawers on one side, thick legs. On top: a switched-off desk lamp, a pencil cup with 3 or 4 colour pencils, a closed laptop or sketchbook, two books. |
| **Chair** | Red seat and back with a darker red frame, pushed out from the desk at a slight angle. |
| **Bookshelf** | Real shelves (3 planks) with books standing on them, some leaning, one lying flat. A small plant or trophy on top. |
| **Beanbag** | Not a sphere: a stepped blob 4 or 5 layers high, wider at the bottom, with a dent in the top. Orange with a darker orange seam. |
| **Cardboard boxes** | Flaps open on the bigger one, packing tape strip across the smaller one, a "TOYS" label on the side. |
| **Window** | Block frame, a cross bar, curtains hanging on each side (stepped fabric blocks), a big voxel moon and a few stars outside. Keeps the moonlight. |
| **Locked door** | Door frame trim, panels in the door, a gap of warm light under it (thin neon strip), a doorknob. Hints at the Hallway beyond. |

---

## 8. Small props (scatter)

These turn "a big empty floor" into "a kid's floor." All are built from blocks, sized against a 5-stud player.

| Prop | Size (studs) | Where | Count | Solid? |
| --- | --- | --- | --- | --- |
| Crayon | 3 × 3 × 20, lying down | Carpet, in little clusters of 2–3 | 12 | Yes (low, you step over) |
| Toy brick (2×4) | 8 × 5 × 16, studded | Carpet and wood, near the tower | 20 | Yes |
| Marble | 6, stepped block "sphere" | Wood ring | 8 | Yes |
| Lone sock | 10 × 2 × 30, flat | Carpet and wood | 4 | No |
| Open picture book | 30 × 3 × 40 | Carpet, on the rug's edge | 1 | No |
| Toy car | 12 × 8 × 20 | Wood ring, by the boxes | 2 | Yes |
| Drawing paper with a crayon scribble | 30 × 0.2 × 40 | Carpet | 3 | No |
| Slipper | 20 × 10 × 45 | Creaky ring, by the bed | 1 pair | Yes (a hiding spot near the Giant) |
| Coin or button | 5 × 1 × 5 | Everywhere, sparse | 10 | No |
| Dust bunny | 6, grey fuzz blocks | Under the bed and furniture | 6 | No |

**Decided: props are solid.** You step over the low ones and dodge round the tall ones, and you can bump into them.
Low props (under about 2.5 studs, like a crayon or a sock) are walk-over height, so Roblox's step-up carries you over.
Taller ones (bricks, marbles, cars, slippers) block you. A carried toy can catch on them, so watch the lanes.

**Rules**
- **More props further from the bed:** the carpet gets about 60% of them, wood 35% and creaky 5%. Near the Giant it
  should feel exposed.
- **Clusters, not a spread.** Props come in little groups (a crayon pile, a brick heap), with open floor between them.
- **A fixed seed** (`Random.new(...)`), so rebuilding gives the same layout, as the floor tiles already do.
- **Lane and spawn checks:** solid props skip any spot inside a lane or within 8 studs of a spawn.
- Only the flat things (paper, the rug, the sock if it's flat) skip collisions, with `CanCollide`, `CanQuery` and
  `CanTouch` false. Solid props get one simple box collider each, not per-voxel collisions.

---


## 9. Walls and ceiling

The walls are 360 studs tall and players see them all the time. Today they're flat blue.

- **Paint:** sage green (section 3), with the night lighting doing the blue. This is the main lesson from Dylan's two
  photos: the same colours read as cosy by day and as night once the light changes.
- **Wallpaper:** vertical stripes in two sages, 24 studs wide to match the floor grid. On the bottom 120 studs only, then
  a cream dado rail, then plain wall above.
- **Posters:** 2 or 3 big pixel-art posters made from blocks, like the ones in the reference photo: a dinosaur, a
  rocket, a racing car. One crooked, with a block of tape at a corner. Put them on the back and side walls, above
  furniture height.
- **Wall shelf:** a floating shelf above the desk with books, a trophy and a mug, like the photo.
- **Glow stars:** 30–40 small neon stars on the ceiling and the upper back wall, spaced unevenly. They give the dark
  ceiling something to look at.
- **Outlet:** a socket on the back wall at floor level, about 20 studs tall to a player, with a night-light plugged in.
  The photo has one by the dresser.
- **Height marks:** pencil height marks on the door frame, with dates, for nostalgia.
- **Curved front wall:** this is the wall the mice live in. Keep it plain apart from the hole arches, their trim and the
  lolly-stick signs, so the 8 doorways stay easy to read. Small hints at what's behind it: a nail poking through, a
  cable bump under the paint, a crack.

---

## 10. Lighting

Dylan's two photos set this. **Night (photo 2) is the default while the Kid sleeps. Lights-on (photo 1) is what the room
turns into when he wakes up.**

### What the photos do

| | Photo 1: lights on | Photo 2: night |
| --- | --- | --- |
| Overall | Warm, soft, bright; pastel colours read true | Deep blue over everything; same colours, tinted |
| Shadows | Soft and filled in; nothing goes black | Blue, never black; every object still readable |
| Warm light | A small lamp glow by the bed | Strong orange pools at the lamp and at the window blinds |
| Accents | — | The monitor glows green, the clock red |
| Contrast | Low | High between warm pools and blue darks: that's the mood |

### Night setup (default)

Values to start from, then tune by eye against photo 2:

- `Lighting.Technology` = **Future** so lamps cast real pools and shadows (set it in Studio if the script can't).
- `ClockTime` 0, `Brightness` 1, `Ambient` `#2E3A78`, `OutdoorAmbient` `#33418A`, `EnvironmentDiffuseScale` 0.3,
  `EnvironmentSpecularScale` 0.2.
- `ColorCorrection`: tint `#C9D3FF`, contrast 0.12, saturation 0.1.
- `Bloom`: intensity 0.6, size 24, threshold 1.1, so the neon (lamp, stars, monitor, slats) glows like in the photo.
- `Atmosphere`: density 0.2, colour `#26306A`, for depth across the big room.
- **Lamp** (left nightstand): warm orange `PointLight` `#FFA552`, range 90, brightness 3, shadows on. The biggest warm
  pool, on the bed head.
- **Window blinds** (right wall): photo 2's window glows warm white through the slats, like a streetlight outside. Use
  glowing neon slats with a `SurfaceLight` into the room, and fake the stripes of light on the floor with thin,
  slightly see-through neon strips (no collisions). They land on the Sock Mountain, so it's the right side's lit
  landmark.
- **Desk monitor:** add an old computer with a green glowing screen, like the photo. Small green `PointLight`, range 30.
- **Alarm clock:** red glowing face, neon only.
- **Night-light** (outlet on the back wall, about x 250): warm yellow, range 50. A cosy glow on the creaky boards.
- **Door crack** (left wall): a thin warm strip under the door with a small `SurfaceLight` on the floor in front of it.
- **Glow stars:** neon only, no lights.
- **Under-furniture shade:** paint the undersides darker too. It keeps objects readable on phones, where Future
  lighting may fall back.
- **About 8 lights** in the room.

### Lights on (when the Giant wakes)

When the Kid wakes up, he switches the lamp up and the room snaps toward photo 1. It's a strong danger signal you see
from anywhere, even inside a base.

- Over about 0.4 s: `Ambient` to `#B9AE96`, `Brightness` to 2.2, `ColorCorrection` tint to `#FFF1DE`, contrast 0.05,
  bloom intensity down to 0.3, lamp brightness to 6.
- Back to night over about 3 s when he falls asleep again.
- The map stores both presets in a small new shared module (`BedroomLighting`); game code tweens between them. The
  builder applies the night preset.

### Inside the wall

Warm and cosy, the opposite of the room: one fairy light hanging off the cable (warm, range 35) plus the outlet glow
(orange, range 25). It fits the "safe at home" feel. That's 2 lights per base, 16 for all 8.

---

## 11. Gameplay checks

The map exists for the steal loop, so every change has to respect it.

- **Hiding spots:** the fallen block, the backpack, the beanbag's shadow, under the bed, the slipper. Each should be big
  enough to stand behind with a carried toy.
- **Sightlines:** from any hole doorway you can see the bed and at least one landmark.
- **Dragging:** a player dragging a Large toy home along any lane hits nothing. Solid props stay out of lanes.
- **Bumping:** low props (under about 2.5 studs) step over cleanly; taller ones stop you without trapping you. No gap
  between props narrower than 8 studs, so nobody gets wedged.
- **The tower lookout:** the jumps up are doable on a phone and nothing on top overlooks a spawn point closely enough
  to drop onto it.
- **The train:** you always hear it before it reaches you, and its loop never crosses a lane.
- **Noise readability:** the creaky ring should look creaky. Uneven board ends and a few raised boards (visual only)
  hint that it's loud before the meter shows it.
- **Bases:** every `BURROW_LAYOUT` prop still fits, the slots are reachable, and the in-wall dressing never covers the
  spawn, the lock button or the wheel. The burrow layout spec still passes.

---

## 12. Performance budget

The plan targets 8 players on phones.

- **New parts:** about 2,500 at most in the room (furniture, landmarks, props, walls), plus about 150 per base (1,200
  for all 8).
- **Repeated things** (studs, bricks, crayons, stars, insulation lumps, bottle caps) should be one template cloned, or a
  MeshPart, not hand-placed stacks. Studs on big surfaces can be a stud `Texture` on the top face instead of thousands
  of stud parts.
- **Colliders:** one simple box per solid prop; everything inside it doesn't collide.
- **CastShadow** off on small props and studs.
- **Lights:** about 8 in the room and 2 per base.

---

## 13. The prompt

The final what/where/why/how prompt to run, kept direct as the video recommends:

> Rebuild the Kid's Bedroom and its 8 bases in `tools/build-bedroom.luau` in our voxel, studded style, following
> `design/bedroom-map-brief.md` and the references in `design/references/bedroom/`.
>
> **Protect what's there:** don't change MapConfig, the floor rings and their attributes, the floor tiles, the toy
> spawns, the hole positions, or any part name or attribute game code reads (the hole and burrow names in section 1,
> the training wheel, and the Giant Kid's part names, PrimaryPart and State).
>
> **Feel:** you're mice, an inch tall, sneaking through a giant kid's bedroom at 2 a.m. Cosy and nostalgic, a bit tense,
> never horror. Furniture should loom. Your base is inside the wall.
>
> **Furniture:** rebuild every piece as chunky voxel blocks with studs on top and darker undersides: a quilted blue duvet
> with a corner flipped up, tree-trunk bed legs, nightstands with a stepped lamp and a red clock, the toy chest with its
> lid open, the desk with an old green-screen computer and a pencil cup, a wall shelf, a real bookshelf, a stepped
> beanbag (no spheres) moved out of lane 8, boxes with open flaps moved out of lane 1, a window with glowing blinds and
> curtains, and a door with light under it. Rebuild the Giant Kid as a voxel kid asleep under the duvet.
>
> **Landmarks:** a climbable leaning letter-block tower (a lookout) near the left wall around x −500, z 680, with a train
> track looping round it and a `Train` model and `Track` points for game code. A sock heap and open backpack under the
> window on the right, around x 480, z 450–650, lit by stripes of light through the blinds. A teal and mustard block rug
> in front of the bed.
>
> **Small props:** crayons, toy bricks, marbles, socks, a picture book, toy cars, drawings, slippers, buttons and dust
> bunnies, in clusters. They're solid: low ones you step over, tall ones you dodge. About 60% on the carpet, 35% on wood,
> 5% on the creaky boards. Fixed random seed.
>
> **Bases inside the wall:** restyle each burrow as the space between the wall studs: drywall back with nails on the
> room side, pine studs and plates, pink insulation, yellow and white cables through drilled studs, an outlet glowing
> through, a copper pipe. Found-object props on the same positions: bottle-cap slots, a coin pile, a push-pin lock
> button, a matchbook index, a matchbox bed spawn, a fairy light. Level themes change the dressing.
>
> **Rules:** keep a 30-stud lane clear from each hole doorway straight to the bed, and nothing solid within 8 studs of a
> toy spawn. Flat, non-colliding decor may cross lanes.
>
> **Walls and light:** sage walls with striped wallpaper below a cream rail, pixel posters, glow stars. Night lighting to
> match `02-lighting-night.png`: Future lighting, deep blue ambient, bloom, warm pools at the lamp, blinds, night-light and
> door crack, a green monitor. Add a lights-on preset to match `01-lighting-day.png` for when the Giant wakes, in a
> `BedroomLighting` module.
>
> **Budget and testing:** about 2,500 new parts in the room and 150 per base, templates for repeated props, no shadows on
> small things. Rebuild in Edit mode, then take captures from a player's eye height at holes 1, 4 and 8, inside a base,
> from the tower top, from the bed, and with the lights-on preset. Check the lane and spawn rules in code and run the
> specs. Don't break anything that works now. Take your time and make it right.

---

## 14. Done when

- [ ] Every furniture piece is voxel and studded; no smooth boxes, spheres or cylinders left in the room.
- [ ] The Giant Kid is voxel, and game code still finds every part it uses.
- [ ] Both landmarks are built and visible from every hole on their side; the tower can be climbed on a phone.
- [ ] The train has its track points and model, and its loop stays out of every lane.
- [ ] The rug and at least 60 small props are placed and clustered; low ones step over, tall ones block.
- [ ] All 8 lanes are clear of solid parts (checked in code).
- [ ] No solid part within 8 studs of a toy spawn (checked in code).
- [ ] Walls are sage with wallpaper, posters, a shelf and glow stars.
- [ ] Night lighting matches photo 2, and the lights-on preset matches photo 1, side by side in captures.
- [ ] All 8 bases look like the inside of a wall, with found-object props on the existing positions; level 1 at least is
  fully dressed, the other themes at least sketched.
- [ ] Part counts within budget.
- [ ] Game still works in a play test: steal a toy from each ring, drag it home down a lane, lock the base, and the
  Giant still wakes and moves.
- [ ] Captures reviewed by Dylan, StyLua and Selene pass, the builder change is committed, and the place is saved to
  `places/TinyToyHeist-Latest.rbxl` and committed.

---

## 15. Decisions

### Decided (19 Oct)

| Question | Answer |
| --- | --- |
| Props solid or walk-through? | Solid: step over the low ones, dodge the tall ones, you can bump into them |
| Climbable tower? | Yes, a lookout |
| Train? | A moving hazard |
| Giant Kid voxel rebuild? | Now, in this pass |
| References? | Claude generates them; Dylan gave the lighting (two photos) |
| Where are the bases? | Inside the wall, among the studs, cables and insulation |

### Still open

1. **Room size.** The other chat's concept v4 shrinks the room (curve radius 930 to 600, 840 wide instead of 1200) so a
   run from base to the Large toys takes about 13 s instead of about 45 s. Bases inside the wall work with either size.
   **Recommendation: take the smaller room.** 45 s each way is long, and a smaller room is easier to fill with detail.
   It means new `MapConfig` numbers, so the lane, landmark and prop positions in this brief get rescaled (about 0.65×).
2. **Hazards from concept v4.** It adds a prowling cat on the wood ring, mouse traps, loose creaky boards, a baby monitor
   patch where noise counts double, and the Kid's flashlight at 80+ noise. **Recommendation: keep all of them alongside
   the train, but keep mouse traps out of the 8 lanes** (concept v4 puts them in the gaps between plots, which become
   wall again with in-wall bases).
3. **Peeking into bases.** Add a crack in the drywall above each hole so raiders can see the best toy inside, now or
   only if raids feel blind? **Recommendation: later.**
4. **The other chat.** It may still be heading toward open floor plots. If it's still running, tell it bases are going
   inside the wall, so the two don't build different maps.
