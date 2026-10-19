# Kid's Bedroom: map brief

This brief follows the method from the deadj.rodev videos: pick the style and feel, gather references that match it, then
write a prompt that says what, where, why and how. It covers the Kid's Bedroom only: the room players see first, where
they spend their first sessions and judge the game.

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
- The 8 mouse holes, their arches, the tunnels and everything inside the burrows.
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
| Walls | Night blue | `#4E5A88` | Existing |
| Wallpaper stripe (new) | Lighter blue | `#5B68A0` | Vertical stripes 24 studs wide, the same grid as the floor tiles |
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
| Beanbag | x −285, z 600 | Orange sphere mesh | Not voxel |
| Cardboard boxes | x 300, z 630 and x 375, z 705 | Two boxes | Plain |
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
- **Where:** against the left wall, around x −480, z 650–800, next to the bookshelf.
- **What:** a tower of big toy blocks (letter blocks A, B, C, each about 30 studs) stacked 4 or 5 high and leaning, with
  one fallen block lying on its side. A wooden train track loops round its base, with a stopped train of three carriages.
- **Why:** you can see it from any left-side hole, so "my hole is by the tower" works. The fallen block gives a hiding
  spot.
- **Climbable?** The bottom two blocks yes, as a lookout. The top no.

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
| **Giant Kid** | Rebuilt as a voxel kid under the duvet: a head with closed eyes, messy hair blocks, one arm hanging off the edge (already there) with a voxel hand. Same part names, `PrimaryPart` and attributes. A small "Zzz" made of blocks floating above, which game code can bob. |
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

**Rules**
- **More props further from the bed:** the carpet gets about 60% of them, wood 35% and creaky 5%. Near the Giant it
  should feel exposed.
- **Clusters, not a spread.** Props come in little groups (a crayon pile, a brick heap), with open floor between them.
- **A fixed seed** (`Random.new(...)`), so rebuilding gives the same layout, as the floor tiles already do.
- **Lane and spawn checks:** solid props skip any spot inside a lane or within 8 studs of a spawn.
- Props that don't collide set `CanCollide`, `CanQuery` and `CanTouch` to false, so they don't get in the way of dragging.

---

## 9. Walls and ceiling

The walls are 360 studs tall and players see them all the time. Today they're flat blue.

- **Wallpaper:** vertical stripes in two blues, 24 studs wide to match the floor grid. On the bottom 120 studs only, then
  a cream dado rail, then plain wall above.
- **Posters:** 2 or 3 big posters made from blocks: a dinosaur, a rocket, a racing car. One crooked, with a block of tape
  at a corner. Put them on the back and side walls, above furniture height.
- **Glow stars:** 30–40 small neon stars on the ceiling and the upper back wall, spaced unevenly. They give the dark
  ceiling something to look at.
- **Outlet:** a socket on the back wall at floor level, about 20 studs tall to a player, with a night-light plugged in
  (see Lighting).
- **Height marks:** pencil height marks on the door frame, with dates, for nostalgia.
- **Curved front wall:** keep it plain apart from the hole arches and their trim, so the 8 doorways stay easy to read.
  At most, add a small toy-coloured sign or sticker above each hole, matching its burrow theme.

---

## 10. Lighting

Keep the current night setup (`ClockTime 0`, blue ambient, light haze) and add warm spots so the room isn't one flat
blue.

- **Lamp** (left nightstand): warm orange `PointLight`, range 80–90, brightness 2. It lights the bed head and the left
  back corner.
- **Night-light** (the outlet on the back wall, about x 250): small warm-yellow neon block with a `PointLight`, range 50.
  A cosy glow on the creaky ring.
- **Window moonlight** (right wall): keep the existing `SurfaceLight` and add a soft blue `SpotLight` angled down onto
  the Sock Mountain, so the right landmark is lit.
- **Door crack** (left wall): a thin strip of warm light under the door with a small `SurfaceLight` lighting the floor in
  front of it.
- **Glow stars:** neon only, no lights, so they're cheap.
- **Under-furniture shade:** paint the undersides darker instead of relying on shadows. Roblox night shadows are weak.
- **Light count:** about 6 lights in the whole room, for phones.

---

## 11. Gameplay checks

The map exists for the steal loop, so every change has to respect it.

- **Hiding spots:** the fallen block, the backpack, the beanbag's shadow, under the bed, the slipper. Each should be big
  enough to stand behind with a carried toy.
- **Sightlines:** from any hole doorway you can see the bed and at least one landmark.
- **Dragging:** a player dragging a Large toy home along any lane hits nothing.
- **Climbing:** nothing new a player can climb onto that puts them over a spawn point or on top of the bed (unless that
  becomes a feature later).
- **Noise readability:** the creaky ring should look creaky. Uneven board ends and a few raised boards (visual only)
  hint that it's loud before the meter shows it.

---

## 12. Performance budget

The plan targets 8 players on phones.

- **New parts:** about 2,500 at most for furniture, landmarks, props and walls together.
- **Repeated things** (studs, bricks, crayons, stars) should be one template cloned, or a MeshPart, not hand-placed
  stacks. Studs on big surfaces can be a stud `Texture` on the top face instead of thousands of stud parts.
- **Far props:** solid props that are never touched can have collisions turned off on everything except a simple box.
- **CastShadow** off on small props and studs.

---

## 13. The prompt

The final what/where/why/how prompt to run once the references are in, kept direct as the video recommends:

> Rebuild the Kid's Bedroom furniture and decorations in `tools/build-bedroom.luau` in our voxel, studded style, following
> `design/bedroom-map-brief.md` and the reference pictures in `design/references/bedroom/`.
>
> **Protect what's there:** don't change MapConfig, the floor rings and their attributes, the floor tiles, the 8 holes and
> burrows, the toy spawns, the training wheel, or the Giant Kid's part names, PrimaryPart and State attribute.
>
> **Feel:** you're an inch tall, sneaking through a giant kid's bedroom at 2 a.m. Cosy and nostalgic, a bit tense, never
> horror. Furniture should loom.
>
> **Furniture:** rebuild every piece as chunky voxel blocks with studs on top surfaces and darker undersides: a quilted
> blue duvet with one corner flipped up, tree-trunk bed legs you can walk between, nightstands with a stepped lamp and a
> glowing clock, the toy chest with its lid propped open and toys poking out, the desk with a pencil cup and books, a
> real bookshelf, a stepped beanbag (no spheres), boxes with open flaps, a framed window with curtains and a voxel moon,
> and a door with light under it.
>
> **Landmarks:** a leaning letter-block tower with a train track round it against the left wall (around x −480,
> z 650–800), and a sock heap with an open backpack under the moonlit window on the right (around x 480, z 450–650). A
> teal and mustard block rug on the carpet ring in front of the bed.
>
> **Small props:** crayons, toy bricks, marbles, socks, a picture book, toy cars, drawings, a pair of slippers, buttons
> and dust bunnies, in clusters. About 60% on the carpet, 35% on wood, 5% on the creaky boards. Fixed random seed.
>
> **Rules:** keep a 30-stud lane clear from each hole doorway straight to the bed, and nothing solid within 8 studs of a
> toy spawn. Flat, non-colliding decor may cross lanes.
>
> **Walls and light:** blue striped wallpaper on the bottom 120 studs with a cream rail, 2 or 3 block posters, 30–40 glow
> stars on the ceiling, an outlet with a night-light. Keep the night lighting, and add warm light from the lamp,
> night-light and door crack, plus a soft moonlight spot on the right landmark. About 6 lights in all.
>
> **Budget and testing:** about 2,500 new parts at most, templates for repeated props, no shadows on small things. Rebuild
> in Edit mode, then take captures from a player's eye height at 3 holes (1, 4 and 8), from the bed, and from each
> landmark, and check the lane and spawn rules in code. Don't break anything that works now. Take your time and make it
> right.

---

## 14. Done when

- [ ] Every furniture piece is voxel and studded; no smooth boxes, spheres or cylinders left in the room.
- [ ] Both landmarks are built and visible from every hole on their side.
- [ ] The rug and at least 60 small props are placed, and they're clustered.
- [ ] All 8 lanes are clear of solid parts (checked in code).
- [ ] No solid part within 8 studs of a toy spawn (checked in code).
- [ ] Walls have wallpaper, posters and glow stars.
- [ ] About 6 lights, with warm pools at the lamp, the night-light and the door.
- [ ] New part count under about 2,500.
- [ ] Game still works in a play test: steal a toy from each ring, drag it home down a lane, and the Giant still wakes
  and moves.
- [ ] Captures reviewed by Dylan, StyLua and Selene pass, the builder change is committed, and the place is saved to
  `places/TinyToyHeist-Latest.rbxl` and committed.

---

## 15. Decide before building

1. **Props:** solid obstacles to dodge round, or decoration you walk through? Solid adds hiding spots and makes the floor
   feel real, but it can snag a dragged toy. The brief assumes small props are solid and low (you step over them), and
   flat ones aren't.
2. **Climbable landmarks:** should the block tower be a lookout players can climb?
3. **Train:** still scenery for now, or a moving train later as a hazard that makes noise?
4. **Giant Kid:** rebuild him as voxel in this pass, or leave his body until the wake-up animation work?
5. **References:** will you gather the pictures, or should I search for and AI-generate them and put them in
   `design/references/bedroom/` for you to approve?
