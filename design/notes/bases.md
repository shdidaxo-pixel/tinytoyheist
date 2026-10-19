# Bases session notes (fences and home upgrades)

19 Oct 2026. Dylan: "get rid of the walls between each base ... have it be fenced off ... base upgrades like the
video, our own twist, make it better." He picked option A from the renders: a new toy fence every level, with the
upgrade build-up as shown.

## What's built
- Video notes: `design/bases/video-notes.md` (`Download (1).mp4`, fishmopf.rodev). Renders: `design/bases/`
  (render page, 17 stills, review page). Studio captures: `design/bases/studio/`.
- `MapConfig`: each home's plot is its whole wedge of the curve (`homeHalfWidth(z)`; `homeCorner` is on the plot edge,
  neighbours share edges; `homeAt` uses the wedge). `FENCE_INSET` 4, `FENCE_WALL_HEIGHT` 48, and per level in
  `HOLE_LEVELS`: `fence` name and `fenceHeight` (22 → 43 full size). `HOME_STUD` and `HOME_WALL_DEPTH` are gone.
- `Room.luau`: the walls between homes are gone; the end walls (EndFill) stay, wallpapered on the home side.
- `Homes.luau` (home shell, not the wheel): wedge floor and top plate, full-width sheathing, 6 back studs and 5 bays,
  an invisible `Shell.FenceWall` along each fence (collides, CanQuery off), wider lock bars and barrier.
  `applyLevel` recolours the plot floor (`LEVEL_LOOK.floor/ground`), builds `Fence` (`Homes.buildFence`) and the back
  corner props (`Homes.cornerProps`). Fence parts don't collide; each has attribute `U` (0 front … 1 back, 1.1 corner
  post).
- Client `Bedroom/HomeUpgradeView.client.luau`: on any home's Level going up, the old fence (a local copy) pops off
  front to back, the new fence and dressing drop in, the corner posts land at 1.25 s with a gold Shockwave and Poofs.
  Workspace attribute `UpgradeSlowMo` (a number) slows it down for captures.
- Studio: homes rebuilt in Edit mode on 19 Oct (only the homes and the walls; no full map rebuild). Saved by Dylan
  as V7 at 17:14 (commit 59c26e7). Map spec passes (2,879 checks). Play test: Lv 1 → 4 → 5 build-up works, no errors.

## Open
- Asked vfx to delay its home `LevelUp` burst from 0.35 s to 1.25 s (VfxClient watchLevels) to land with the posts.
- The end-wall wallpaper only appears after a full map rebuild.
- Fence height (3 to 5 players tall) and the Lv 7 crown were not commented on yet.
