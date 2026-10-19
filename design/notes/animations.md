# Animations (animations session, 19 Oct 2026)

Dylan: "i want to make better animations for everything." All procedural (CFrame / Motor6D.Transform), no uploads,
client only except two small server hooks. Captures in `design/animations/` (mp4s stay out of git).

## What moves now

| What | File | What it does |
| --- | --- | --- |
| Awake toys | `Shared/Toys/ToyAnimator.luau` | Personality layer on top of each toy's data idle: breathing, lean into the walk + waddle, eased turns (the pen roam snaps direction; the Body joint lags behind and catches up), squash on every hop landing (head/ears sink into the body and spring back, arms splay), look-around while standing still, and a move every few seconds by rarity (below). Fresh hatch (`RevealedAt` < 1.5 s) = big jump + spin + cheering hops. Carried by a thief (Root has `CarryWeld`) = struggling and flailing. Dropped stolen toy (`StolenGlow`) = shivering, looking about. |
| Sleeping toys | `TinyToyHeistToys/BlanketAnimator.luau` | Blankets breathe and now and then turn over; a blanket waking in a home tosses more as `WakeAt` gets close. Dragged: a client-side copy squirms and kicks (the real welded one is hidden on each screen). |
| Players | `Bedroom/PlayerAnim.client.luau` | R15 extras after the Animator (the joints are AnimationConstraints now, Roblox's newer avatar joints; Motor6Ds work too): dragging (lean, arms back to the load, head up, a tug each step, by `CarrySize`), yank when you get hold, crouch-and-reach while holding E (sneaky look-around on Steal, pat-pat on Hatch; own screen only), flailing while knocked down, dizzy after, cheer after a hatch into your pen (bigger for Rare+) and a small one when you bring a toy home. Everyone's character is posed on every screen. |
| The Kid | `Bedroom/KidView.luau` | Asleep: breathing, the dangling arm swings, tosses more as the meter fills. Sits up with a spring from the pillow, yawns when Stirring, head and shoulders follow the beam, the torch arm points at it. Out of bed: pushes up, stomps (camera shake + dust within 200 studs), looks at the nearest mouse, scoops on `GrabAt`. Lies back down before the sleeping pose returns. |
| The cat | `Bedroom/CatView.luau` | Prowl (shoulder roll), stalk (low, tail tip twitch, butt wiggle), pounce (legs reach/kick), landing crouch + puff, grooming (paw up, licking, ear rub) in Rest and the new Groom, ears flat + tail bristling with the lights on, ear flicks. |
| Train | `Bedroom/TrainView.luau` | Wheels turn with distance, cars lean out on bends and rock, engine chuffs with a chimney puff, cargo jiggles. Same track maths, so hits are unchanged. |
| Ducks | `Bedroom/PropsView.client.luau` | Heads look about and nod (heads only, so Effects' squash on Body still works). |

Rarity moves (`PERSONALITY` in ToyAnimator): Common hop/stretch every 8–13 s · Uncommon + wiggle · Rare + spin ·
Epic spins and wiggles · Legendary + front flip · Mythic twirl in the air · Secret glitch. Rarer ones also look around
more.

## Server hooks (small)
- `Giant.luau`: `GiantKid` attribute `GrabAt` (server time) when he catches someone.
- `Cat.luau`: new state `Groom`: calm, on patrol, every 25–45 s it sits 5 s licking a paw (`Cat.GROOM`,
  `Cat.GROOM_EVERY`). It still notices mice while grooming and goes straight to stalking. Lights on: never grooms.
  **Dylan to OK** (it's a small gameplay change: a 5 s pause in the patrol).

## For other sessions
- `ToyAnimator.play(model, move)` plays a move ("Hatch", "Hop", "Spin", "Flip", "Wiggle", "Stretch", "Twirl",
  "Glitch"). Everything scales with the toy's Root size, so `Model:ScaleTo` toys animate right.
- Uses the VFX library (`Shared/VFX`) if it's there: `burst("Poof")` for landings/stomps/chimney, `shake` for stomps.
- Studio-only test hook: `LocalPlayer:SetAttribute("AnimTest", "cheer" | "smallcheer" | "yank" | "dizzy")`.
- The Speed-wheel runner is the wheels session's; untouched.

## Fixed on the way (Giant.luau, movement)
- The awake Kid got out of bed into a pocket boxed in by the bed, chair and desk footprints and never reached the run
  (so he never grabbed anyone). He now gets out at the foot of the bed.
- With nobody in the run he walked to z = 1000 (the back wall at 0.65 scale); now the middle of the room.

## Play-tested (19 Oct, Studio, solo)
Toys (pen roam, rarity moves, hatch jump), blankets (breathing, dragged copy struggling), player (drag, cheer, knocked
over, dizzy), Kid (sleep, sit up, sweep, stir, get up, walk, grab), cat (hunt, pounce, groom), train. Captures:
`design/animations/01-toys.mp4`, `02-player-kid-cat-train.mp4`. Not seen yet: two players at once (other players'
poses come from the same code), the Kid lying back down at the end of BackToBed, ducks.

## Added after the first pass (19 Oct, later)
- **Walk cycle** (ToyAnimator): legs and arms swing in step, a small bob each step, lean and waddle, all from the
  toy's speed. Speed is measured from how the toy moves; a mover can set a client-side number attribute
  `RoamSpeed` (studs/s, 0 standing) instead. pen-roam owns where pen toys go (PenRoam, HomeView); this file owns the
  joints (Motor6D.Transform) and nobody else should write them.
- **Held toy** (hotbar): a toy welded to a player's HumanoidRootPart without a CarryWeld gets a calm idle: sways,
  looks about, no walking or tricks (a fresh Hatch still plays).
- **Holding pose** (PlayerAnim): Player attribute `Holding` (a toy uid) = both arms forward hugging the toy from
  below, bobbing with the walk; a cheer or a knock-down takes over the arms.

## Checked in Studio (19 Oct, evening, TinyToyHeist-V7.rbxl)
Walk cycle, held toy idle + holding pose (simulated hold: a toy welded at the chest with HeldBy, local Holding),
the Kid lying back down, the ducks, and the cat bite/throw after the head fix (head turns about its middle now,
collar left out, no grooming while angry). Capture: `design/animations/03-walk-hold-kid-duck-bite.mp4`.
Still not seen: two players at once.
