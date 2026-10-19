# Toy sizes and hatch timers (19 Oct 2026)

Dylan: "make it so the toys that get hatched can have variable sizes as a mutation and get bigger and give more
money" and "make it longer for better/bigger blankets". He picked the brief's sizes and the proposed timers.

## Size tiers (rolled at hatch, stacks with the look mutation)

| Tier | Odds | Model size | Money and sell price | Thief carry speed |
| --- | --- | --- | --- | --- |
| Normal | 85% | x1 | x1 | x1 |
| Big | 11% | x1.5 | x2 | x1 |
| Huge | 3.5% | x2 | x4 | x0.9 |
| Giant | 0.5% | x3 | x10 | x0.8 |

Average money per hatch goes up about 26%. A Huge Gold toy pays x8 (4 x 2). Numbers: `GameConfig.SIZE`.

## Hatch timers (blanket size x rarity, `GameConfig.WAKE_SECONDS`)

|        | Common | Uncommon | Rare | Epic | Legendary | Mythic |
| --- | --- | --- | --- | --- | --- | --- |
| Small  | 10 s | 15 s | 30 s | 45 s | 1 min | - |
| Medium | 1 min | 1:15 | 2 min | 3 min | 4 min | 5 min |
| Large  | 3 min | 4 min | 5 min | 7 min | 9 min | 10 min |

The very first toy ever (the Plush Bunny) takes `GameConfig.FIRST_WAKE` = 5 s. A long timer hints at a good toy,
which builds anticipation. The blanket's timer is now a big clock ("2:45", "12s") over a bar.

## How it works

- `src/ReplicatedStorage/Shared/Toys/ToySize.luau`: `roll`, `money`, `scale`, `carry`, `name`, `color`, `isBig`,
  `apply(model, tier)` (ScaleTo on top of the blanket-size scaling; sets `SizeTier`, `Height`, `Reach`),
  `reach(model)` (half the visible footprint), `wakeSeconds(blanketSize, rarity, first)`.
- Save: `profile.Toys[i].z` = "Big" / "Huge" / "Giant" (nil = Normal, so old saves are Normal).
  `profile.Blankets[i].t` = the whole wake time (for the progress bar; old blankets fall back to the table).
- `Pens.hatch` rolls the size and sends `sizeTier` and `sizeMult` (= model scale) with the Reveal; the VFX hatch burst
  already grows with `sizeMult`. `Pens.perSecond` includes the size money, so income, Sell and Equip Best follow.
- Pens: big toys get a `SizeTag` billboard ("HUGE" in the tier colour) and the Steal prompt says "Huge Teddy Knight".
- `PenRoam.pose(..., reach)`: a toy wider than a normal one keeps its sides off the pen walls (HomeView and Raids
  pass the toy's `Reach`). Raids allows the steal from `30 + Reach` studs.
- Carry: a stolen Huge/Giant toy slows the thief (x0.9 / x0.8 on top of the carry speed).
- UI (GameUI): reveal card has a tilted BIG/HUGE/GIANT stamp that punches in, and a slightly bigger picture; Your
  Toys tiles show the tier word; the detail line reads "Huge x4 · Gold x2"; the client $/s includes the size.

## Testing in Studio

On the Server: `game.Players.<name>:SetAttribute("DebugSizeTier", "Giant")` and the next hatch comes out that size
(Studio only). `GameDebug("give", player, "L")` gives a blanket.

## Play test (19 Oct, 16:12, Dylan's real save, solo)

Captures in `design/studio-toysizes/`.
- Timers: gave S, M, L blankets: S Uncommon 15 s, M Common 1:00, L Uncommon 4:00, shown as "50s" / "3:50" clocks
  (01).
- Hatched with forced tiers (`ready`, then hold E): Giant Night-Light Owl from the Large ($12 to $120/s, 02),
  Huge Crayon Buddy from the Medium ($4 to $16/s, 03), Big Night-Light Owl from the Small ($12 to $24/s, 04).
  Reveal stamps punch in; Steal prompts read "Giant Night-Light Owl" etc.
- Pen: the Giant owl is 51 studs tall and towers over the pen, BIG / GIANT tags float over them (05).
- Your Toys: tier word on each tile, "Giant x10", Sell $2.4K (06).
- Roaming: sampled 50 min of PenRoam for all six toys: every body stays inside the pen walls (Giant reach 18.9).
- No errors from this code in the output.
- Dylan's save now has those 3 sized toys (6 toys, pen 6/6).
- Not tested: stealing a Huge/Giant toy with two players (the slower carry and the wider steal range are code-only).

## Not done / ideas

- The Index doesn't track sizes yet (it's toy x mutation). Could add a "biggest found" badge later.
- The tier is called Giant and so is the (unused) Giant blanket size `G`; they don't collide in code (`z` vs `s`).
