# Pen roaming (pen-roam session, 19 Oct 2026)

Dylan: "update how the toys walk around in the base, they kinda just play animation and not move really, watch the
screen recording since it shows it moving around."

## The recording

`Videos/Screen Recordings/Screen Recording 2026-10-18 211549.mp4`, about 2:03-2:20: Break and Steal an Egg, Dylan
places a Cat and a Chicken in his pen. What they do:
- They walk the whole pen, fence to fence, in fairly straight lines; never standing still for long.
- Steady walking pace (the cat crosses the pen in a few seconds), short stops of a second or two, then off again.
- They turn to face where they're going; they don't slide sideways.
- Small hop/waddle while walking; nothing fancy.
(Earlier recording `Screen Recording 2026-10-18 160347.mp4`, Steal an Egg, shows the same kind of wandering pets.)

## What changed

Before: `PenRoam.pose` blended between noise spots every 6-10 s (70% walking, smoothstep), so each walk was a short
shuffle and the speed was always changing: it read as "playing an animation in place".

Now (`src/ReplicatedStorage/Shared/PenRoam.luau`):
- **Plans in chunks of 45 s** (`EPOCH`). Each toy starts each chunk at an anchor point from its seed and plans walks
  across the pen (target picked from 5 tries, first one past 35% of the pen's diagonal), with pauses between them,
  so the last walk lands on the next chunk's anchor exactly when the chunk ends. Every toy's chunks start at a
  different time (seed offset). Still worked out from the seed and the server clock only, so the server (Raids) and
  every client agree. A chunk's plan is cached per toy, so a frame is a lookup.
- **Speed by size** (`SPEED`): S 7.5, M 6, L 4.8, G 4 studs/s; each walk x0.8-1.2, 12% chance of a x1.45 trot.
  Huge/Giant (Reach above 6) slow down by sqrt(6 / Reach), never below x0.65.
- **Walks**: ease in and out over 0.35 s, follow a gentle sine curve to one side (up to 18% of the length, max 6
  studs), face along the curve.
- **Pauses**: 15% short (0.5-0.9 s), 65% normal (1-3.2 s), 20% rests (3.5-7 s).
- **Turning**: the toy turns on the spot over the last 0.6 s of each pause, then walks (no snapping).
- **Hop**: one small hop per `STEP` studs walked (S 2.6 / M 3.2 / L 4 / G 5), height `HOP` (0.8 / 0.55 / 0.45 /
  0.4), so faster toys hop more often. ToyAnimator's landing squash still fires.
- **Props**: the padlock, Index box and Speed wheel (at its biggest size) are keep-out circles taken from
  `MapConfig.BURROW_LAYOUT`. They sit in front of the pen today, so they only matter if a pen ever grows over them
  (bases session).
- **Big toys**: same as before, the roaming box shrinks by `Reach - 6` so a Huge or Giant toy keeps off the walls
  (toy-sizes session's need, kept).
- `PenRoam.pose(seed, t, penMin, penMax, size, reach)` is unchanged for callers; it now also returns the speed
  (studs/s, 0 standing) as a third value. New helpers: `PenRoam.box`, `PenRoam.speedOf`.

HomeView (`roamPen`): poses every toy in the pen, then nudges toys apart on that client: any two closer than 85% of
their reaches added push apart, partly sideways to the walk so they step round each other; the nudge eases in, drifts
back to the path when clear and is capped at 7 studs (`HomeView.NUDGE`). The server's steal check allows 30 + Reach
studs, so a nudged toy is still stealable. Raids is unchanged (pose's extra return value is ignored).

## For the other sessions
- animations: no new attribute; ToyAnimator reads speed from the position change, which works with continuous
  walks. Turns are now smooth already, so its eased-turn lag sees small turns.
- toy-sizes: Reach still shrinks the box and now also slows the toy.
- bases: PenMin / PenMax / PenTop on `Hole#.Pen` are still what the roam uses. If the pen becomes a wedge, the roam
  box is still a rectangle; tell me and I'll add a shape test to `pick`.

## Performance
Per frame per toy: one cached plan lookup (a handful of legs), a few Vector3s and a PivotTo. The nudge is pairs within
one pen (20 toys max = 190 pairs). A plan is built once per toy every 45 s.
