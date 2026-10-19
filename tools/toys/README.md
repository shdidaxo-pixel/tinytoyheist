# Voxel toys: how they're made

Every toy in Tiny Toy Heist is a list of coloured boxes in a Luau data file. The same data builds the Roblox models
(in Studio) and the review page (`design/toy-turntables.html`), so what Dylan reviews is what the game builds.

| Piece | Path | What it does |
| --- | --- | --- |
| Set files | `src/ReplicatedStorage/Shared/Toys/Sets/<Set>.luau` | One per room set or event line: every toy's data (catalog facts, blocks, idle animation, particles). |
| Palette and kits | `src/ReplicatedStorage/Shared/Toys/ToyPalette.luau` | Colour names, particle presets (`Fx`), shared part kits (`Bear`, `Duck`). |
| Rarities | `src/ReplicatedStorage/Shared/Toys/ToyRarities.luau` | Rarity order, colours and effect strengths. |
| Mutations | `src/ReplicatedStorage/Shared/Toys/MutationData.luau`, `Mutations.luau` | Mutation chances, multipliers and looks. |
| Builder | `src/ReplicatedStorage/Shared/Toys/ToyBuilder.luau` | Turns a toy's data into a Model. |
| Build tool | `tools/toys/build-toys.luau` | Studio: builds every toy into `ServerStorage.TinyToyHeistAssets.Toys`. |
| Exporter | `tools/toys/export-toy-data.pl` | Checks every set file and writes `design/toy-data.js` for the review page. |
| Renderer | `tools/toys/render-toys.sh` | Headless-Chrome stills of the review page into `design/toy-renders/`. |

Set files are plain data: `return { ... }` with only tables, strings, numbers and booleans (no locals, no functions,
no maths), because the exporter parses them as data.

## Coordinates

- Units are "voxel units". The builder scales each toy to its size class afterwards, so pick whatever unit makes the
  design easy; the shipped toys use about 8 to 16 units of height.
- **The toy faces +X.** Y is up, Z is left/right. The front of the face (eyes, snout) is on the +X side.
- Build it symmetric around **z = 0** where you can, and use the `m` flag to mirror.
- The feet can be anywhere; the builder puts the pivot at the centre of the footprint, on the floor.

## A toy

```lua
{
	Id = "RubberDuck", -- PascalCase of the name, unique across all sets
	Name = "Rubber Duck", -- exactly as in Toy Catalog.md
	Rarity = "Common", -- Common Uncommon Rare Epic Legendary Mythic Secret
	Money = 2, -- base money per second, from the catalog
	Size = "S", -- natural size: S M L G (see Sizes)
	Mvp = true, -- only the 15 MVP toys
	Look = "Classic yellow duck, orange beak, tiny sailor hat", -- from the catalog
	IdleText = "Waddles in circles, squeaks every few steps", -- from the catalog
	Perk = "...", -- from the catalog (Epic and up, plus Jack-in-the-Box)
	Idle = { ... }, -- idle animation tracks (below)
	Fx = { ... }, -- optional particles (below); Epic and up get one
	Parts = { ... }, -- boxes, kits and groups (below)
},
```

## Parts

A box is `{ x, y, z, w, h, d, colour, flags?, rot? }`: the min corner, then the size.

- `colour`: a name from `ToyPalette.Colors` (preferred) or `"#RRGGBB"`.
- `flags` (a string, any order):
  - `m` also place a mirrored copy across z = 0 (a box at z..z+d gets a twin at -(z+d)..-z)
  - `M` metal (tin, chrome, gold): shiny
  - `N` glows (Neon in Roblox): lights, eyes that glow, magic bits. Use sparingly
  - `G` glass, see-through
  - `F` fabric: plush and cloth
- `rot`: optional `{ rx, ry, rz }` in degrees around the box centre. The style is axis-aligned blocks; only rotate when
  a shape really needs it (a tilted sword, a kite). Most toys use none.

A **group** is a set of parts that can move on its own (a head, a tail, a lid):

```lua
{ Group = "Head", Pivot = { 2, 4, 0 }, Parts = { ...boxes and nested groups... } },
```

- Coordinates inside a group are the same absolute coordinates as everywhere else (don't offset them).
- `Pivot` is the joint: the point the group rotates around (a neck, a hinge, a shoulder).
- Everything not in a group is in the implicit `Body` group, whose pivot is the toy's feet.
- Groups nest (a jaw inside a head).
- A `{ Group = "Head", Parts = {...} }` with no Pivot adds parts to an existing group, e.g. a helmet on a kit's head.

A **kit** reuses a shared part list: `{ Kit = "Bear", Colors = { Fur = "Brown", Snout = "Tan" } }`. A colour slot can be
`{ "Gold", "M" }` to add flags. Kits: `Bear` (slots Fur, Snout; has a `Head` group), `Duck` (slots Body, Beak, Wing;
has a `Head` group).

## Idle animation

`Idle` is a list of tracks, all playing at once, looping forever. Each track moves one group:

`{ target, channel, amp, speed, wave?, phase?, duty? }`

- `target`: `Body` (the whole toy, around its feet) or a group name.
- `channel`: `PosX` `PosY` `PosZ` (voxel units, so they scale with the toy), `RotX` `RotY` `RotZ` (radians), or `Fade`
  (0 = solid, 1 = invisible; for glowing bellies, blinking lights, things that appear).
- `speed` is in radians per second (6 ≈ one wiggle a second); `phase` shifts it in radians.
- `wave`, with `x = speed * time + phase`:

| wave | value | good for |
| --- | --- | --- |
| `Sin` (default) | amp * sin(x) | sways, wags, swings |
| `Abs` | amp * abs(sin(x)) | hops, bounces (always up) |
| `Pos` | amp * max(0, sin(x)) | half the time: a step, a jaw opening |
| `Lift` | amp * (1 - cos(x)) / 2 | smooth 0..amp: floating up, breathing |
| `Spin` | amp * x | turning forever (amp 1, or -1 the other way) |
| `Const` | amp | a fixed offset (start a lid open, float a little) |
| `Pulse` | a bump of height amp during the first `duty` (0.3) of each cycle, then rest | every-few-seconds actions: pops out, peeks, sneezes |
| `Turn` | one full turn (amp * 2π) during the first `duty` of each cycle | spins round once, flips over |
| `Step` | amp for half of each cycle, 0 for the other half | blinking, glitching |
| `Wobble` | a wobbly mix of two sines | jitter, scribbling, shivers |

Tracks add up: two `PosY` tracks on Body sum. Rotations apply X, then Y, then Z.

Axes for a toy facing +X: `RotZ` tips it forward and back (positive lifts the front: nodding up, a jaw opening);
`RotX` rolls it side to side (waddles); `RotY` turns it left and right.

**Readable in 2 seconds.** Pick the one movement the catalog's Idle line describes and make it big enough to see
from across a home. Keep it looping and smooth (no jumps when a wave wraps).

## Particles (Fx)

`Fx = { { "Steam", { x, y, z }, "Group"?, rate? } }`: a preset from `ToyPalette.Fx`, at a point in voxel units, on a
group (follows its animation; `Body` if none), with an optional particles-per-second override. Presets: `Steam`,
`Smoke`, `Dust`, `Sparks`, `Flame`, `GhostFlame`, `Bubbles`, `Water`, `Glow`, `Snow`, `Sparkle`, `Confetti`, `Zzz`.
Epic and up get one that fits the toy (steam from a spout, sparks from a battery). Commons to Rares usually none.
Rarity glows and mutations are added on top by code, so don't add auras yourself.

## Sizes

`Size` is the toy's natural size class. The builder scales each toy so its size (its height, or 0.75 of its length if
that's bigger) is S 8, M 12, L 17 or G 25 studs. A player (a mouse) is 5 studs tall.

| Room set | Common, Uncommon | Rare | Epic and up |
| --- | --- | --- | --- |
| Kid's Bedroom, Hallway | S | S or M | M |
| Kitchen, Living Room | M | M or L | L |
| Garage, Attic | L | L or G | G |
| Events (any room) | S or M | M or L | L, Mythic and Secret G |
| Specials | — | — | Index Teddy M, the other two G |

## Style (Dylan: "i still like the voxel models")

- **Voxel: blocky, chunky, bright solid colours.** Axis-aligned boxes, a few clear colours per toy, one accent colour.
  Look at `Sets/Bedroom.luau` and the review page: match that.
- **Cute faces.** Most toys have a face on the +X side: two `Ink` eyes (often with a tiny `White` glint), sometimes
  a small mouth, `Rose` cheeks. Objects-with-a-twist (a crayon, a toaster) get the face on their front.
- **One-glance silhouette** (catalog rule 2). Under the Flashlight it's a black shape; it must still say what it is.
  Exaggerate the one feature that identifies it (the duck's beak, the bunny's ears, the shark's fin).
- **Detail grows with rarity.** Blocks (boxes, a mirrored box counts twice): Common 12 to 25, Uncommon 15 to 30, Rare
  20 to 35, Epic 25 to 45, Legendary 30 to 55, Mythic and Secret 35 to 65. Hard limit 90 (phones). Rarer toys get
  more trim, glowing bits (`N`), metal (`M`) and an Fx.
- **Thin details** (stripes, seams, lines) are boxes 0.05 to 0.2 thick sitting on a surface. Make them stick out a
  hair (0.05) past the surface so they don't flicker.
- **Original only** (rule 1): no characters, logos or brands.
- Stay inside the catalog's Look line; add the small touches that make it charming (a scarf, a sticker, a key).

## Checking your work

From the repo root in Git Bash:

```bash
perl tools/toys/export-toy-data.pl
```

It must print `no problems`. Then render and look at the result (the `Read` tool shows images):

```bash
TOY_RENDER_SCRATCH=<your scratch folder> bash tools/toys/render-toys.sh toy-renders "kitchen|shot=sheet&set=Kitchen|1600x1000" "kitchen-lineup|shot=lineup&set=Kitchen|1600x700"
```

Still modes (`design/toy-turntables.html?shot=...`): `sheet&set=<Set>` (every toy in a set), `lineup&set=<Set>` (real
scale, with a 5-stud mouse), `blanket&set=<Set>` (under blankets), `muts&toy=<Id>` (every mutation), `rarity`,
`toy&toy=<Id>&mut=<Mutation>` (one big still). A red box in the top-right corner of a still lists data warnings.
Judge each toy at sheet size: does it read instantly? Is the face on the front? Is it on-model with the catalog?
Then fix and re-render.

`stylua` and `selene` (in `%USERPROFILE%\.rokit\bin`) must pass on any Luau you change:
`stylua src/ReplicatedStorage/Shared/Toys` and `selene src/ReplicatedStorage/Shared/Toys`.
