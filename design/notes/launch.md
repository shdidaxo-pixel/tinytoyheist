# Launch: Robux shop, bug pass, playtest checklist

Written 19 Oct 2026, night.

## The Robux shop (built)

Everything sold is listed once in `src/ReplicatedStorage/Shared/Monetization.luau`; the Roblox ids go in
`ProductIds.luau` (0 = not created yet, the button says "Coming soon!"). Server: `Bedroom/Shop.luau`. Client:
`TinyToyHeistUI/ShopClient.luau`, wired into the existing shop cards in `Hud.client.luau`.

| Item | Price (R$) | What it does |
| --- | --- | --- |
| x2 Speed pass | 99 | Speed trained on the wheel x2 (the rainbow offer while training buys it) |
| x2 Cash pass | 499 | All toy income x2 |
| x2 Luck pass | 399 | Every blanket rolls twice, keeps the rarer toy; mutation luck x2 |
| VIP pass | 799 | [VIP] chat tag, +50% income |
| Mystery Blanket 1 / 3 / 10 / 50 | 99 / 249 / 799 / 3499 | Large blankets with the shown odds (45/30/15/7/2.5/0.5), wake in 10 s; extras queue until slots free |
| Speed packs | 59 – 1999 | +150K / 1M / 10M / 50M / 250M Speed |
| Cash packs | 59 – 1999 | +$100K / 500K / 2M / 20M / 100M |
| Wake All | 29 | Every sleeping blanket at home is ready now (button under the blanket list) |
| Gift: <pass> | same as pass | The purple gift buttons: pick a player in the server |

Shown prices come live from Roblox, so changing a price on the Creator Hub is enough. Receipts are saved before
they're confirmed and never granted twice. Friends in the same server give +10% cash each (up to 5), and the
INVITE FRIENDS banner now opens the invite prompt.

Studio tests without Robux: `ServerStorage.GameDebug:Invoke("buy", player, { key = "Speed1", id = "t1" })` and
`("pass", player, { key = "Cash", on = true })`.

## Before the playtest (Dylan)

1. **Create the passes and products.** Either run `tools/roblox-setup.ps1` with an Open Cloud API key (instructions at
   the top of the script; it writes `ProductIds.luau`), or make them by hand on the Creator Hub with the names and
   prices above and paste the ids into `ProductIds.luau`.
2. **Upload the UI pictures.** Every icon, shop card and toy picture is still a Studio-only local file
   (`assets/tth2`); live players see blank squares until they're uploaded and their ids are in `ImageIds.luau`.
3. **Game Settings:** Max Players 8 (there are 8 homes; a 9th player now waits for a free home, but 8 is right),
   rename "samrtly's Place" to Tiny Toy Heist, icon and thumbnails from `Thumbnails & Icon/`, description, genre,
   maturity questionnaire.
4. **Clear the showcase** (about 10,800 parts): `require(game.ServerStorage.TinyToyHeistTools.Bedroom.Showcase:Clone()).clear()`.
5. **Wipe your own save** if you want to start fresh for the public: `GameDebug:Invoke("wipe", player)` in Play.
6. Save the place (File > Download a Copy into `places/TinyToyHeist-Latest.rbxl`), publish, then a 2-player
   Test Session to try raids and gifting.

## Bug pass (19 Oct)

Two read-only audits (server and client), then fixes, then a Studio play test. Fixed:

- Stealing only from inside the owner's unlocked home (an exploiter could steal across the fence or through a lock);
  a teleport while dragging drops the toy; two players grabbing one blanket in the same frame can't duplicate it.
- Saving: the leave save retries 4 times; an autosave can't re-lock a released save; shutdown waits for every save.
- Lock has a 20 s cooldown after it runs out (no locking forever); a 9th player waits for a free home; sell list
  capped; dropped blankets always tidy up; dying with a blanket drops it where you fell.
- One player's error can't stop everyone's income (and the UI's once-a-second loop can't die).
- UI: asks the server for its profile after connecting (could stay on "Loading..." on slow joins); tutorial
  pointer survives a hatched blanket; blanket list keeps its phone scaling; wake meter no longer covers the corner
  buttons on phones; no stuck hover on touch; "Tap and hold" hints on phones; music plays even if a track fails.
- Shop: the fake "5d 10h 46m" timer is gone and the odds tiles show real Bedroom toys.
- Speed now climbs by uneven whole numbers on the wheel (Dylan: no totals always ending in 00).

Still open (smaller): the 2 s steal hold isn't checked on the server; Settings reset on each join; the corner
buttons are small on phones; after the Day 7 claim the Daily panel shows days 1–6 as locked until tomorrow; four
sound ids (StepCarpet, RevealRare, Meow, Hiss) may need permission for the group's universe (check in a live server).

## TikTok drafts

`promo/` (not in git): three 1080x1920 clips recorded from Studio play, captions burned in, silent so a trending
sound can be added in TikTok. 1) Steal from a giant (33 s), 2) Don't wake him (19 s), 3) Giant Mythic hatch (24 s).
Suggested post text: "I made a Roblox game where you're mouse-sized and steal toys from a giant kid 🧸 #roblox
#robloxgames #stealabrainrot #gamedev #indiegame".
