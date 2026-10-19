# PRD: Clearer selections in the player turn UI

Status: implemented · Phase 3 item 11 ("Selection feedback + Tame as…") · Branch: `feature/clearer-selections` (off `feature/ui-panel`)
Follows: `droidream/Resources/code_standards.md`

## 1. Summary

Choosing a combat option should read clearly and feel like the command menus of Mario & Luigi: Superstar Saga (the original took inspiration from it). The option select screen gets side arrows and a beat bounce on the selected option, the tame type panel gets a "Tame as…" title, and the lists get one highlight bar that travels between rows with a small bounce on arrival. The boon cards get the same beat bounce.

## 2. Problem

- On the gear option select, the selected option is only bigger and brighter; nothing tells the player they can move left and right.
- The tame type panel has no title, so it is not obvious what the choice means (especially when an ability asks for a type).
- In the lists, each row draws its own bar and marker, so moving between options looks like two separate fades instead of one cursor moving.
- The selected look is not the same on every screen.

## 3. Decisions (from the grill-me session)

| Topic | Decision |
| --- | --- |
| Side arrows | On the option select screen, two small arrows flank the selected option and bob outward on the shared 0.8 s beat (`SelectionPulse.BEAT`). They wrap like the menu does (no end-of-row hiding) |
| Gear option | Keeps its larger size and brightness and also pops and hops on the shared beat; the other options stay dim and still. No outline |
| "Tame as…" | Title above the orange panel, 16 px bold with outline (same style as the gear option labels); shown for both tame paths (plain Tame and ability tame type); appears and disappears with the panel |
| Lists (tame types, abilities, items) | One highlight bar that travels between rows (eased), with the marker as part of it; a short squash-and-bounce on the row it arrives at, then the slow beat pop |
| Unselected rows | Keep their current dim; no shrink |
| Look | Pixel-drawn in code, white with black outline; the bar uses the panel's ring color at about 30% opacity. No new art files |
| Boon cards | The selected card also gets the beat bounce, on top of its current gear spin and pulse |
| Not in scope | Shop and rewards screens (not converted to `UIPanel` yet), sound (none exists yet) |
| Delivery | PRD first, then implement on this branch |

## 4. Requirements

R1 **Gear menu arrows**: `PlayerTurnUI` creates a small left and right arrow (drawn by a tiny `UIArrow` control or `_draw`) attached to the selected option. They follow the selection (reparented or moved when the index changes), bob outward on the beat, and are hidden whenever the gear menu is not the active state (locked, submenu open, targeting).
R2 **Gear beat bounce**: the selected option runs a looping tween with the beat envelope (same curve as `UIRow`'s pop, plus a small vertical hop). It stops when the option is no longer selected or the menu hides, and restores scale and position.
R3 **"Tame as…" title**: a `Label` (PixelOperator-Bold, 16, outline 4) placed above `AttackTypeMenu/Panel` so its bottom edge touches the panel's top edge, horizontally aligned to the panel's left padding. It scales and fades with the panel in `_open_menu` / `_close_menu`. The text is always "Tame as…" for the attack panel.
R4 **Traveling bar**: `UIList` owns one `UICursor` (a child drawn behind the rows) that holds the bar and the marker. On `select()` it tweens to the selected row's y (about 0.1 s, ease out with a small overshoot) and is sized to the list width. `UIRow` stops drawing its own bar and marker; it keeps the slide right, the brightening and the pop.
R5 **Arrival bounce**: when the cursor arrives, the selected row plays a squash and stretch (about 0.12 s, 8% in y, then back) before the beat pop continues. First selection when a menu opens plays no bounce.
R6 **Scrolling lists**: when the window scrolls, the cursor and rows move together (the cursor follows the row's on-screen y, not its list index).
R7 **Boon cards**: `BoonSelectionScreen` applies the beat bounce to the selected card in addition to its current scale pulse (the pulse is replaced by the shared envelope so there is one motion, not two); gears and their spin stay as they are.
R8 **Shared constants**: beat length, envelope and pop amount come from `SelectionPulse` / `UIRow` constants so all screens stay in rhythm.

## 5. Code touchpoints

| File | Change |
| --- | --- |
| `Scripts/UI/UIRow.gd` | remove own bar/marker drawing; add `bounce()`; keep slide, dim, pop |
| `Scripts/UI/UIList.gd` | add the cursor, travel tween, arrival `bounce()` call, scroll handling |
| `Scripts/UI/UICursor.gd` (new) | draws bar and marker in whole pixels |
| `Scripts/UI/PlayerTurnUI.gd` | side arrows, gear beat bounce, "Tame as…" label |
| `Scenes/UI/PlayerTurnUI.tscn` | `TameTitle` label and arrow nodes |
| `Scripts/UI/BoonSelectionScreen.gd` | beat bounce for the selected card |
| `Resources/code_standards.md` | note the shared selection style |

## 6. Edge cases

- Gear menu wraps (Tame → Abilities → Items → Tame): the arrows jump with the selected option; no flicker during the 0.18 s shuffle.
- Panels scale from zero when opening: the title and the cursor must scale with the panel, not appear at full size.
- Empty lists ("No abilities" / "No items"): the cursor shows on the placeholder row but confirm is blocked as today.
- Quick repeated input: the cursor tween is killed and restarted, never stacked.
- Tutorial: the preselected Earth option still works (cursor starts on the preset row without a bounce).

## 7. Test plan

Manual and screenshot checks at 1920x1080 through the real combat scene: each gear option selected (arrows and bounce), attack panel (title visible, cursor on each row), abilities and items with 6+ rows (scrolling), boon screen, and a quick sequence of up/down presses; scene smoke runs (title, tutorial, combat) with no new errors.

## 8. Acceptance criteria

1. The selected gear option has an arrow on each side and bounces in time with the other selection effects.
2. "Tame as…" shows above the type panel for both tame paths and animates with it.
3. In every combat list one bar moves between rows with a small bounce on arrival; there is never more than one bar.
4. The selected boon card bounces on the same beat as the combat menus.
5. No new errors in scene runs; no new art files.

## 9. Risks and follow-ups

- The bar overshoot and the squash can feel busy when moving fast; the amounts are constants so they are easy to tone down after a playtest.
- Shop and rewards should adopt `UIList` later to get this for free.
- Sound for move and confirm is part of the sound channels work (Phase 4).
