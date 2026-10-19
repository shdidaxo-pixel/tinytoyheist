# Lights-on danger phase (lights-on session, 19 Oct 2026)

Dylan: "make it so when the lights are on, it's almost nearly (unless super endgame) impossible to collect anything,
the cat is faster and there's an RC car driving around bumping everyone and the boy is constantly looking."

## How it plays

1. **Warning (10 s, Kid `Stirring`)**: lights snap on, a big **LIGHTS ON!** slams in with "HIDE! He gets up in N"
   and a tick each second. Get to the safe ring, your home, or behind something big.
2. **Lights on (45 s, Kid `Awake`)**: red **LIGHTS ON 0:45** timer at the top. All at once:
   - **The Kid's eyes**: a beam from his head to a spot on the floor that darts round the room and glances near
     mice. Step into it (and he can see you: not behind the bed, desk, chair, nightstand, tower or fallen block)
     and his eyes lock on and follow you. Stay in them 0.8 s and he's got you: drop, 2 s stun, sent home. You
     get a red "!" over your head and "HE SEES YOU! RUN!" with a bar filling. He still walks toward noise and
     grabs whoever he reaches, like before.
   - **The cat**: chases at 60 (was 26), aims where you're going (cuts you off), pounces longer and faster, barely
     rests.
     **Its pounce is a bite** (Dylan, 19 Oct): it holds you in its mouth and shakes you (0.6 s, CHOMP!), flicks
     its head and throws you in an arc (0.8–1.8 s) to the middle of the safe ring right in front of **your own
     home** (no home: the nearest bit of the ring). Toy dropped, 3 s grace after landing. Recommendation: land in
     front of your home, not in the home: you see your base, you're safe, and you're one step from the run again.
   - **The RC car**: leaves its charger by the desk and tears round the floor going for the nearest mouse
     (carriers first). Fast but turns wide; a hit = knocked down, toy dropped, 1.6 s stun.
3. **Lights out** (Kid `BackToBed`): "LIGHTS OUT", the car drives back to its charger.

The safe ring and the homes are always safe: the eyes, cat and car never target or enter them.

## Numbers (proposed, Dylan to OK)

| What | Number | Where |
| --- | --- | --- |
| Warning | 10 s | `Giant.STIR` |
| Lights on | 45 s (was 60) | `Giant.AWAKE` |
| Kid's eyes: search speed | 60 studs/s | `Giant.GAZE.SEARCH` |
| Kid's eyes: follow speed | 95 studs/s | `Giant.GAZE.TRACK` |
| Kid's eyes: spot size | 14 studs radius | `Giant.GAZE.RADIUS` |
| Kid's eyes: time to catch | 0.8 s in his eyes | `Giant.GAZE.LOCK` |
| Kid's eyes: give up | 1 s out of them | `Giant.GAZE.LOSE` |
| Cat chase (lights on) | 60 (was 26); pounce 85 studs/s | `Cat.ANGRY.stalk`, `Cat.ANGRY_LEAP_SPEED` |
| RC car | top 72, turns 2.1 rad/s | `RCCar.SPEED`, `RCCar.TURN` |
| Cat bite | hold 0.6 s, flick 0.35 s, flight 0.8–1.8 s, 3 s grace after landing | `Cat.BITE`, `Cat.THROW`, `Cat.FLIGHT`, `Cat.LAND_GRACE` |

**Who gets through**: you shake his eyes only if you're faster than follow + spot / catch time = 95 + 14 / 0.8
≈ **113 studs/s** (after the carry slow-down). With today's Speed curve (`GameConfig.walkSpeed`):

| Carrying | Walk needed | Speed needed |
| --- | --- | --- |
| nothing | 113 | ≈ 2.7M |
| Small (x0.95) | 118 | ≈ 4.8M |
| Medium (x0.8) | 141 | ≈ 50M |
| Large (x0.6) | 188 | ≈ 7.4B |

Anyone slower can still hide behind furniture (breaks his line of sight) or get lucky with where he's looking.
The cat (60) and car (72) are easy to outrun at those speeds; they're what stop mid-game players.

## Files

| File | What |
| --- | --- |
| `src/ServerScriptService/Bedroom/Giant.luau` | `Giant.GAZE` + the eyes loop (attributes `Gaze`, `GazeAt`, `GazeTarget`, `GazeLock`, `GazeRadius`, `SpottedAt`) |
| `src/ServerScriptService/Bedroom/Cat.luau` | lights-on speed, lead (cut-off), faster pounce, shorter rest; the bite and throw (states `Bite`, `Throw`, attribute `BiteTarget`, moment `CatBite`) |
| `src/ServerScriptService/Bedroom/Knock.luau` | `Knock.protect(player, seconds)`: the landing grace |
| `src/ServerScriptService/Bedroom/RCCar.luau` | the car's driver (attributes on `Hazards.RCCar`: `State` Docked/Driving/Bumped/Return, `Pose`, `Speed`, `Steer`) |
| `src/StarterPlayer/StarterPlayerScripts/Bedroom/RCCarView.luau` | moves the car, spinning/steering wheels, antenna whip, headlights, dust, motor sound, bump bonk, charger light |
| `src/StarterPlayer/StarterPlayerScripts/Bedroom/LightsOnView.luau` | LIGHTS ON warning + countdown, the timer, the eyes' beam and floor spot, "!" over who he's watching, HE SEES YOU |
| `src/StarterPlayer/StarterPlayerScripts/Bedroom/KidView.luau` | (one small edit) his head follows his eyes while walking |
| `tools/bedroom/Hazards.luau` | the RC car + charger model (`buildRCCar`); can build only the car (command in the file's header) |
| `src/ReplicatedStorage/Shared/MapConfig.luau` | `MapConfig.RC_CAR.dock` |

Sounds reuse the SFX session's library (`Click` ticks, `NoticeWarn` when he sees you, `TrainLoop` pitched up for
the motor, `Thud` for the bump). Effects use the VFX library (`shake`, `flash`, `Poof`, `Shockwave`).

## Test

Server command bar while playing: `workspace.Bedroom.GiantKid:SetAttribute("WakeMeter", 100)`.

## Play test (19 Oct, 17:29–17:45, Studio, solo)

Captures in `design/studio-lightson/` (car on its charger, the LIGHTS ON warning, "The Kid spotted you!", an
overview with his eyes, the car and the timer).

- Warning: "LIGHTS ON! HIDE! He gets up in N" counts down; then the red "LIGHTS ON 0:45" timer; "LIGHTS OUT" after.
- His eyes swept the run, found a player standing still at (-60, 760) within 5 s, locked on and caught them.
- The cat bit a player on the carpet and threw them to (-43, 34): the safe ring right in front of their home.
- The RC car drove out at lights on and chased. Found: it got pinned on the desk and dithered by its charger.
  Fixed (8eb160c): it now plans a route round the furniture corners, slides free if pinned, and parks. Checked with
  a maths run in Studio (it reaches every test spot in 2–9 s); a live re-check is queued.
- Dylan's screenshot: the cat's head looked twisted into its body during the bite/throw. That's the bite and throw
  poses in CatView (animations session), reported to them.
- Not tested yet: an endgame-speed player escaping his eyes, two players at once.
