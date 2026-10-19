# Hotbar (hotbar session, 19 Oct 2026)

Dylan: "make it so that there is a hot bar where you can see what you equiped ... try to copy steal an egg's
hotbar ... so you can equip and show off blankets/toys."

## The reference

Break and Steal an Egg, from Dylan's recording `Videos/Screen Recordings/Screen Recording 2026-10-18 211549.mp4`
(about 1:55): `design/hotbar/steal-an-egg-hotbar.png`.
- A row of small square slots, bottom centre (about 75 px at 1080p), dark green-grey, a little see-through, thin
  dark outline, tiny corners. Key number top-left, the item's picture, its name small along the bottom
  ("Chicken (20KG)"). The picked slot gets a white outline.
- A new animal lands on the bar as a big cyan card over its slot, then drops into it.
- The held animal goes with you, with "$1/s" and "Common" floating over it.
- While you carry a stolen egg the bar is gone and the Drop button sits there instead.

## What Dylan decided (19 Oct)

"you cant equip pen toys in ur hotbar, they stay in the inventory and only can be equipped in the hotbar if you
unequip it from the pen. its like steal an egg but you cant see it in ur hotbar wo unequiping it first."
So the bar holds only toys waiting in your inventory (`profile.Toys` with `e == false`). A pen toy has to be
unequipped (Your Toys) to get on the bar. Holding is just for show: an inventory toy earns nothing and can't be
stolen, held or not, so raids don't change.

## How it works

| What | Where |
| --- | --- |
| The bar (client) | `src/StarterPlayer/StarterPlayerScripts/TinyToyHeistUI/Hotbar.luau`, started from `GameUI.start` (`Hotbar.start(ctx)`, and `Hotbar.update(profile)` on every `GameRemotes.Data`) |
| Holding (server) | `src/ServerScriptService/Bedroom/Hold.luau`, started by its own `HoldServer.server.luau` (no line in BedroomServer) |
| The holding pose | the animations session's `PlayerAnim.client.luau` (Player attribute `Holding`), and `ToyAnimator` plays a calm idle while held |

- Slots: up to 9 (keys 1-9, number pad too) on PC, 6 on phones; more toys show a "+N Toys" slot that opens Your
  Toys. Order: best $/s first the first time, then toys keep their slot and new ones go on the end. Each slot: key
  number, toy picture (`design/toy-icons`), name, rarity-coloured outline, a mutation chip ("GOLD") and a size chip
  ("HUGE"). Picked slot: white outline, lifted 8 px.
- Press the key or tap the slot to hold it; again to put it away. `GameRemotes.Hold(uid)` / `Hold(nil)`.
- The server builds a copy of the toy (`Pens.buildToy`, so mutation and size tier look right), scales it to about
  3 studs tall and at most 3.4 wide whatever its size, welds it in front of the chest (`HoldWeld`), and puts a
  tag over it: name (with "Huge Gold ..." in the mutation colour), $/s in green, rarity in its colour. It lives in
  `Workspace.HeldToys` as `Held_<UserId>`, owned by the holder's client. Parts don't collide, touch or block clicks.
- Player attributes: `Holding` = the toy's uid, `HoldHeight` = its height.
- Put away by itself when you start dragging (`Carrying`), train on the wheel (`Training`), die, equip or sell the
  toy, or leave. The bar hides while `Carrying` (the Drop Toy button is in that spot).
- Roblox's own backpack bar is turned off (`SetCoreGuiEnabled(Backpack, false)`).
- Equip pop: everyone sees a sparkle in the toy's rarity colour when it appears in someone's hands
  (`VFX.burst("Sparkle")`), and a client moment `HoldToy` `{ toy, mine }` fires for the sounds session.
- An empty inventory = no bar at all.

## Blankets on the bar (Dylan, 19 Oct: "blankets that arent being opened should be in the hotbar")

Built and play-tested (captures `design/hotbar/studio-blanket-pc.jpg`, `studio-blanket-touch.jpg`):
- Client (`Hotbar.update`): add `profile.Blankets` entries (kind "blanket") to the same order list, after the toys
  the first time, new ones appended with the pop-in card. Slot: a ViewportFrame with a clone of your own home
  blanket (`Hole#.Waking` child with attribute `Uid`, cached per uid; fall back to the S/M/L colour chip from
  GameUI's `BLANKET_COLOUR`), name "Small"/"Medium"/"Large", and the timer (`b.w - GetServerTimeNow()`, "READY!"
  when 0) ticking once a second. Never show the toy inside.
- Server (`Hold.hold`): if the uid is in `profile.Blankets`, take the home model (`Pens.state(player).blankets[uid]`),
  park it in a ServerStorage folder while held (so it can't show twice or be hatched mid-hold), hold a clone
  (prompts removed, every part welded to `Lump`, unanchored, no collide/touch/query, scaled to <= 3 tall / 3.4
  wide, pivot = bottom centre). Tag: "Medium Blanket" + timer, refreshed every second by the server loop.
  `putAway`: destroy the clone, put the home model back in `Hole#.Waking` only if `state.blankets[uid]` is still
  that model (Pens.reload rebuilds them). Loop: put away if the blanket left `profile.Blankets` (hatched).
- Player attribute `HoldKind` = "Toy" or "Blanket". The held blanket is about 3.6 studs across, 3 tall.
- Tested: both on the bar with their 3D picture and timer ("READY" in yellow), hold one (home spot empties, tag
  "Medium Blanket / wakes in 1:43"), put it away (it comes back with its Hatch prompt as it was), start carrying
  while holding (back home), phone layout. The test blankets were taken out of Dylan's save again.

## Not done

- A gamepad button for the bar.
