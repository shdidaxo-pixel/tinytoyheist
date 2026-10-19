# Bases session notes (fences and home upgrades)

19 Oct 2026. Dylan: "get rid of the walls between each base ... have it be fenced off ... base upgrades like the
video, our own twist, make it better."

## Done so far
- The video: `Download (1).mp4` (fishmopf.rodev, plot upgrading). Notes in `design/bases/video-notes.md`.
- Renders: `design/bases/bases-render.html` (three.js, still mode `?shot=1&cam=<name>`), stills in
  `design/bases/renders/`, review page `design/bases/bases-review.html` (published as an Artifact).
- Headless Chrome stills: run one at a time here (two in parallel came out black while Studio was busy), about
  30-60 s each.

## The design (option A, pending Dylan's pick)
- The walls between homes (`Room.luau` WallBetween1..7) and the side studs go. Each home's plot becomes its whole
  wedge: from the curve (r 380) to a curved back wall (r 554 full size), between the radial lines halfway to its
  neighbours (home angle +-11.25 degrees).
- Each home builds its own fence along both radial edges, set 3.6 in from the line, so two fences stand back to back
  between neighbours, each in its owner's level look. A corner post at the front of each fence carries the level's
  topper.
- Level looks (fence / post topper): 1 popsicle sticks / bottle cap, 2 clothes pegs + socks / pom-pom, 3 toy bricks /
  brick stack, 4 pencils + ruler / giant pencil, 5 candy canes / lollipop, 6 glow sticks / neon star, 7 coin stacks +
  gold bars / coin pillar + crown. Fence height full size 14..27 drawn at x1.6.
- The upgrade moment (client): old pieces pop and tumble front to back (0-0.7 s), new pieces drop with a bounce
  (0.4-1.2 s), the floor rolls out from the back, the corner post lands last (1.25 s), then VFX `LevelUp` /
  `Shockwave` and the banner (VFX session owns the burst; hook `HomeLevelUp`).

## Build notes for later
- `MapConfig.homeAt` must use the wedge, not the old rectangle, or the extra back corners count as "outside".
- The lock bars / door barrier span `BURROW_WIDTH`; the wedge front is wider (about 148 full size), so widen them.
- Server `Homes.luau` is also edited by the wheels session: keep my change to `relevel` small.
