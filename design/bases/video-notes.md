# Base upgrade video: what it does

Source: `Download (1).mp4` in the project root (fishmopf.rodev TikTok, "Plot upgrading system", 13 s, 576x1024).
Frames were pulled with ffmpeg into the session scratchpad (not in git, like the video).

## The levels it shows

| Level | Floor | Fence | Decoration |
| --- | --- | --- | --- |
| 1 | Grass, same as outside | Plain red wooden farm fence | Nothing; an "UPGRADE PEN" board at the front corner |
| 2 | Snow | White/lilac picket fence with bigger posts | A snowy pine at the back |
| 3 | Sand | Wooden posts with a blue rail along the bottom | A palm tree |
| 4 | Pale dirt | Bone fence (white bones as pickets) | A dead tree, small torches |
| 5 | Adobe | Low sandstone brick wall with battlements | Cactuses, a column |
| 6 | Dark rock | Black brick wall with glowing lava in the cracks and fire on the posts | Torches, the brightest of all |

## What makes the upgrade feel good

1. **One button, an instant swap.** You press "Upgrade Pen" on the board and the whole plot changes theme at once:
   floor, fence and props. There's no loading or building wait, so it feels like a reward.
2. **Big pixel "LEVEL UP!" text** in the middle of the screen with "Plot Level N" under it, staying about 2 s.
3. **A yellow ring** sweeps out across the ground from the plot, over the player's feet. It's cheap and reads well.
4. **The fence gets taller and heavier each level** (thin rail → pickets → posts → bones → wall → lava wall), so
   you can tell a rich plot from across the map without reading a sign.
5. **A new theme every level**: each level is a new place (snow, beach, desert, volcano), not just a new colour.
6. **Props grow** from nothing to trees to torches and fire. The last levels glow.
7. The board shows what you get next (the pen size, "4 x 8 seats") and the price, so you know what to save for.

## What's weak (where we can do better)

- The swap is a hard cut: no build-up, so the moment is over in a frame. A short "build" (old pieces pop off, new
  ones drop in one after another) would make it feel earned.
- Nothing reacts: the pets in the pen don't notice, and neighbours don't see anything.
- The themes have nothing to do with the game (snow, beach, volcano). Ours should be things from a kid's bedroom.
- No sense that the pen got bigger, though the board says it did.

## Our twist (taken into the renders)

- The dividers between homes become **toy fences**, one per home, back to back, so each side shows its owner's level.
- **Each level is a new toy fence** that matches the existing level themes (and the Speed wheels): popsicle sticks,
  clothes pegs and odd socks, toy bricks, a pencil palisade, candy canes, glow sticks, and a gold coin-and-ruler fence.
- **A corner post at the front of each fence** carries a topper that grows each level, so the level reads from the run.
- **The upgrade is built in front of you** (about 1.5 s): the old pieces pop up and tumble away, the new pieces drop
  in from the front to the back with a bounce, the floor rolls out like a rug, then a ring, confetti and the banner.
  The toys in the pen hop and cheer, and the new pen slots light up.
