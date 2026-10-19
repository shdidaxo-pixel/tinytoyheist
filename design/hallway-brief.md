# Hallway: map brief (concept v1)

Room 2 of Tiny Toy Heist. Renders first: `design/hallway-render.html`, photos in `design/renders-hallway/`, review page
`design/hallway-review.html`. Nothing is built in Studio yet. Numbers are full size, like the bedroom renders (the game
shrinks everything to `MapConfig.SCALE` = 0.65).

## 1. Feel

> "You've left the bedroom. The hallway is longer, narrower and louder, and it belongs to the cat."

- **Same house, new room.** Same voxel style, same wallpaper pattern (stripes under a cream rail at 120, plain above,
  cream crown), recoloured from sage to dusty plum. Same voxel wood tiles, recoloured to a warmer honey oak.
- **Exposed.** No bed to hide under, just a long wooden floor (noise x2) with a red carpet runner down the middle. The
  runner is quiet (x1) but it's the cat's route: the quiet way is the dangerous way.
- **Stuff dropped on the way out the door.** Shoes, an umbrella stand, coats on hooks, a key table: the Hallway toy set
  (Button Beetle, Shoelace Snake, Umbrella Bat, Coat-Hook Kraken...) comes from exactly this junk.
- **A glimpse of what's next.** The Kitchen door straight ahead and the Living Room door on the side are ajar, lit from
  inside, with a glowing toy behind a baby gate. The attic hatch's pull cord dangles out of reach.

## 2. References

- Dylan's two lighting photos (`design/references/bedroom/`): night = deep blue with warm pools, lights on = warm pastel.
  The hallway keeps both presets so the wake-up switch works the same everywhere.
- The bedroom v6 renders (`design/renders-v6/`): voxel furniture, blanket toys, the cat, the wallpaper, so the two rooms
  read as one house.
- Steal an Egg / Break an Egg screenshots (`design/screens/egg-style/`): one long readable run, props at the edges.
- The early whole-house plan (`design/house-map.html`): its hallway ideas (carpet runner as the quiet lane, shoe rack to
  crawl under, umbrella stand, key table with keys to knock off, locked doors with a glowing toy, the attic hatch).
- Real hallways: runner rugs with tassels, pressure-mounted baby gates, wall-mounted coat hooks, plug-in night-lights.

## 3. The brief (what, where, why, how)

The Hallway is a straight corridor 280 wide and 800 long, 320 tall, starting right behind the bedroom's far-wall door
and running on in the same direction, so you keep running straight. Its walls are the bedroom wallpaper recoloured plum;
its floor is honey-oak voxel wood (noise x2) with a burgundy runner 72 wide down the middle (noise x1, the cat's patrol).
A yellow tape line halfway splits it: Small toys in the first half, Medium in the second, 8 sleeping toys in all, on the
wood either side of the runner, so grabbing one means stepping off the quiet lane. Landmarks stay against the walls and
the middle stays clear: on the left a shoe rack you can crawl under, then a key table (keys to knock off for noise, a
Medium toy hiding underneath); on the right the nook behind the open bedroom door, an umbrella stand under coats and a
long scarf, the Living Room door (ajar, purple TV glow, Strength 10), and the cat's bed and bowls at the end. Straight
ahead is the Kitchen door (ajar, cool fridge light, Strength 6). Overhead, the attic hatch (Rebirth 1). A baby gate in
the bedroom doorway is the Strength 3 lock: you can see in, and it opens once you're strong enough. Night lighting by
default; when the Kid wakes, the hallway ceiling lights come on too and the cat goes for you.

## 4. Numbers (render units = full size)

| Part | Number | Notes |
| --- | --- | --- |
| Hallway | x -140..140, z 1708..2508, walls 320 | Starts behind the bedroom far wall (inner face z 1700, 8 thick). |
| Bedroom door | 130 x 230, hinge x -65 | Swung about 118 degrees so it lies against the hallway's right wall (today it's 72 degrees, which pokes into the run). Behind it: a hiding nook. |
| Baby gate | 130 wide, 120 tall, bedroom side of the door | Strength 3 lock, see-through. Per player (client-side open). |
| Floor | Honey-oak voxel wood tiles, noise x2 | Same OBJ tile as the bedroom wood band, new palette. |
| Runner | x -36..36, z 1760..2440, noise x1 | Burgundy carpet tiles, cream border, tassels. The cat walks it. |
| Zone line | Yellow tape at z 2100 | Small before, Medium after. |
| Spawns | 8: S at z 1840, 1915, 1990, 2065; M at 2160, 2245 (under the key table), 2340, 2420 | Alternate sides, about 75 off the centre line. |
| Shoe rack | Left wall, z 1820..1950, 48 deep, 3 shelves, bottom one 14 up | Crawl under to hide. Sneakers, a rain boot, a lace trailing out. |
| Umbrella stand + coats | Right wall, z 1880..1960; hooks at y 275 | Coat hangs to y 130, stripy scarf to the floor. |
| Night-light | Left wall, z 2005, low | Warm pool on the floor. |
| Key table | Left wall, z 2170..2315, 48 deep, 130 tall | Key bowl on top (knock off: noise). Open underneath. |
| Living Room door | Right wall, z 2200..2330 | Ajar, purple glow, baby gate, "LIVING ROOM · STRENGTH 10". |
| Cat bed + bowls | Right corner, z 2350..2495 | The cat's station; its route runs from here down the runner and back. |
| Kitchen door | Far wall z 2508, centred, 130 x 230 | Ajar, cool white light wedge, baby gate, "KITCHEN · STRENGTH 6". |
| Attic hatch | Ceiling, centre, z 1950..2050 | Pull cord to y 150 with a ring: "ATTIC · REBIRTH 1". |
| Lighting | Night and lights-on presets as the bedroom | Plus: night-light, kitchen and living-room glow, two ceiling domes (on when the Kid wakes). |

Times at walk speed 16 in game: the hallway is 800 x 0.65 = 520 studs, about 33 s end to end, on top of the bedroom's
~45 s from home to the door.

## 5. Keep / don't

- Keep: the run straight (Kitchen door straight ahead, never off to the side), the middle clear, landmarks at the walls,
  few props, big readable shapes.
- Don't bring back: clutter, a split route, props in the middle of the run.
