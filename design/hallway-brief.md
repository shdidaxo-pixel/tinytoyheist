# Hallway: map brief (concept v2)

Room 2 of Tiny Toy Heist. Renders first: `design/hallway-render.html`, photos in `design/renders-hallway/`, review page
`design/hallway-review.html`. Nothing is built in Studio yet. Numbers are full size, like the bedroom renders (the game
shrinks everything to `MapConfig.SCALE` = 0.65).

## 0. Dylan's decisions (19 Oct 2026, on concept v1)

| Question | Answer | What changed in v2 |
| --- | --- | --- |
| Length 800 (~33 s end to end in game) | "thats fine bc we will have speed upgrades" | Kept. |
| Quiet runner (x1) or wood x2 everywhere like the plan | "i like the plan" | Runner removed: wood x2 all the way. |
| One cat or two | "second cat that is diff color and also a roomba or something" | The hallway has its own smoky-grey cat (the bedroom's is orange), plus a Roomba with a dock. |
| Baby gates as room locks | "yeah thats fine" | Kept: Strength 3 / 6 / 10. |
| Living Room door on the side wall | "yes" | Kept. |
| Bedroom door | "swing flat" | Shown lying against the hallway's right-hand wall. The builder still has it at 72 degrees (`tools/bedroom/Room.luau`, rotation -1.25): change it to about -2.06 when the hallway is built. |
| Does the Giant Kid walk into the hallway | "nope, everything in the hallways gets more busy and noisy tho" | He stays in the bedroom. While he's awake the hallway ramps up instead: lights on, the cat pounces, the Roomba goes on turbo, and noise there counts for more (number to pick; x3 suggested). |

## 1. Feel

> "You've left the bedroom. The hallway is longer, narrower and louder, and it's busy: a cat and a Roomba live here."

- **Same house, new room.** Same voxel style, same wallpaper pattern (stripes under a cream rail at 120, plain above,
  cream crown), recoloured from sage to dusty plum. Same voxel wood tiles, recoloured to a warmer honey oak.
- **Exposed and loud.** Wood all the way (noise x2), no bed to hide under, two things moving around: the hallway's own
  cat down the middle and a Roomba looping round.
- **Stuff dropped on the way out the door.** Shoes, an umbrella stand, coats on hooks, a key table: the Hallway toy set
  (Button Beetle, Shoelace Snake, Umbrella Bat, Coat-Hook Kraken...) comes from exactly this junk.
- **A glimpse of what's next.** The Kitchen door straight ahead and the Living Room door on the side are ajar, lit from
  inside, with a glowing toy behind a baby gate. The attic hatch's pull cord dangles out of reach.

## 2. References

- Dylan's two lighting photos (`design/references/bedroom/`): night = deep blue with warm pools, lights on = warm pastel.
- The bedroom v6 renders (`design/renders-v6/`): voxel furniture, blanket toys, the cat, the wallpaper, so the two rooms
  read as one house.
- Steal an Egg / Break an Egg screenshots (`design/screens/egg-style/`): one long readable run, props at the edges.
- The early whole-house plan (`design/house-map.html`) and `Day 1 - Starting Plan.md`: shoe rack to crawl under,
  umbrella stand, key table with keys to knock off, locked doors with a glowing toy, the attic hatch, the Roomba that
  collects dropped toys into a dock worth raiding.
- Real hallways: pressure-mounted baby gates, wall coat hooks, plug-in night-lights, robot vacuums and their docks.

## 3. The brief (what, where, why, how)

The Hallway is a straight corridor 280 wide and 800 long, 320 tall, starting right behind the bedroom's far-wall door
and running on in the same direction, so you keep running straight. Its walls are the bedroom wallpaper recoloured plum;
its floor is honey-oak voxel wood, noise x2 everywhere. A yellow tape line halfway splits it: Small toys in the first
half, Medium in the second, 8 sleeping toys in all, off the middle. Two moving hazards: the hallway's own smoky-grey cat
walks the middle end to end and turns round at its bed by the Kitchen door, and a Roomba loops round between the middle
and the toys, sucking up any toy someone dropped and dumping it at its dock on the left wall, where the pile becomes a
jackpot to raid. Landmarks stay against the walls and the middle stays clear: on the left a shoe rack you can crawl
under, the Roomba dock, then a key table (keys to knock off for noise, a Medium toy hiding underneath); on the right the
nook behind the bedroom door (swung flat against the wall), an umbrella stand under a raincoat and a long scarf, the
Living Room door (ajar, purple TV glow, Strength 10), and the cat's bed and bowls at the end. Straight ahead is the
Kitchen door (ajar, cool fridge light, Strength 6). Overhead, the attic hatch (Rebirth 1). A baby gate in the bedroom
doorway is the Strength 3 lock. Night lighting by default. The Giant Kid never comes in; when he wakes, the hallway gets
busier and louder instead: lights on, the cat pounces, the Roomba speeds up.

## 4. Numbers (render units = full size)

| Part | Number | Notes |
| --- | --- | --- |
| Hallway | x -140..140, z 1708..2508, walls 320 | Starts behind the bedroom far wall (inner face z 1700, 8 thick). |
| Bedroom door | 130 x 230, hinge x -65, rotation about -2.06 rad | Lies against the hallway's right wall. Behind it: a hiding nook. |
| Baby gate | 130 wide, 120 tall, bedroom side of the door | Strength 3 lock, see-through. Per player (client-side open). |
| Floor | Honey-oak voxel wood tiles, noise x2 everywhere | Same OBJ tile as the bedroom wood band, new palette. |
| Zone line | Yellow tape at z 2100 | Small before, Medium after. |
| Spawns | 8: S at (-78,1840) (70,1915) (-76,1990) (74,2065); M at (-80,2160) (114,2242, under the key table) (-80,2345) (78,2420) | |
| Cat (hallway) | Smoky grey, white chest, amber eyes, blue collar | Route: x 0 from z 1785 to 2380, round to its bed at (-92, 2455). |
| Roomba | Disc r 22, 9 tall | Loop through (40,1800)–(40,2400)–(-40,2400)–(-40,1800), out to its dock. Lights on: turbo (red light). |
| Roomba dock | Left wall, z 2106..2150 | Dropped toys it collects pile up here: a jackpot to raid. |
| Shoe rack | Left wall, z 1820..1950, 48 deep, 3 shelves, bottom one 18 up | Crawl under to hide. Sneakers, slippers, rain boots, a lace trailing out. |
| Umbrella stand + coats | Right wall, z 1965..2065; hooks at y 266 | Raincoat hangs to y 124, striped scarf to the floor. |
| Night-light | Left wall, z 2005, low | Warm pool on the floor. |
| Key table | Left wall, z 2170..2315, 48 deep, 130 tall | Key bowl on top (knock off: noise). Open underneath. |
| Living Room door | Right wall, z 2200..2330 | Ajar, purple glow, baby gate, "LIVING ROOM · STRENGTH 10". |
| Cat bed + bowls | Right corner, z 2350..2495 | Where the cat turns round. |
| Kitchen door | Far wall z 2508, centred, 130 x 230 | Ajar, cool white light, baby gate, "KITCHEN · STRENGTH 6". |
| Attic hatch | Ceiling, centre, z 1950..2050 | Pull cord to y 155 with a ring: "ATTIC · REBIRTH 1". |
| Lighting | Night and lights-on presets as the bedroom | Plus: night-light, kitchen and living-room glow, two ceiling domes (on when the Kid wakes). |

Times at walk speed 16 in game: the hallway is 800 x 0.65 = 520 studs, about 33 s end to end, on top of the bedroom's
~45 s from home to the door. Speed upgrades bring that down.

## 5. Keep / don't

- Keep: the run straight (Kitchen door straight ahead), the middle clear, landmarks at the walls, few props, big
  readable shapes.
- Don't bring back: the quiet runner, clutter, a split route, props in the middle of the run, the Giant Kid in the
  hallway.
