# PRD: Combat clarity pass (HUD, instruction text, camera, player minigames)

Status: draft for review · Phase 3 (clarity pass) · Branch: `feature/combat-clarity` (one branch, built in segments, one reviewable commit per segment)
Follows: `droidream/Resources/code_standards.md`
Related: `clearer-selections.md` (shared selection beat, `UIPanel`, `UIRow`, `SelectionPulse`)

## 1. Summary

Four connected changes that all serve one goal: readable instructions in a turn-based game that has real-time sequences.

1. The top-left player HUD is rebuilt to fit the UI scale (small stacked power/defense, glanceable ability and item slots).
2. `TutorialText` is rebuilt: instruction text anchored to the subject it is about, outlined with BBCode motion, no big gray panel.
3. The combat camera keeps the identity of each segment (turns, abilities, victory, boons, shop) but frames the subject of each segment, especially in abilities.
4. The player minigames (Repair, Heat Up, Harden, Multi-Tame, Ball) are polished so the thing the player must act on is visible, clear and satisfying.

## 2. Problems found (code reading and a playtest in the real combat scene)

- `TutorialText` has one gray panel for every state, a fixed top position and the old text options. It covers minigame objects (Harden: the panel hides the first row of keys), and is far from what it describes.
- Repair: bolts spawn 30 px from the Droid, are tiny and gray like the Droid, and the 1.4x zoom hides where they come from.
- Heat Up: prompts appear at random places on screen (not tied to the zoomed frame).
- Harden: the key row sits under the instruction panel.
- Multi-Tame: no camera move; the aligning shapes float in empty sky between the Droid and the creature.
- Ball: the meter is a tall bar next to the Droid, on top of the gear menu area, and the Z timing window is strict.
- Victory zooms 2.4x on the Droid and the camera stays there through the boon screen; the shop just follows the Droid.
- The top HUD still uses the old big icons and long "Abilities: (0/6)" text; it does not show what the abilities and items are.

## 3. Decisions (from the grill-me session)

### 3.1 Top-left HUD

| Topic | Decision |
| --- | --- |
| Stats | Power and defense icons much smaller (UI-scale, 16 px grid), stacked vertically (power on top, defense below); numbers beside them in 16 px |
| Purpose of abilities/items | Glanceable inventory: the player sees how many they own and what they are |
| Slots | Icon slots with a small `UIPanel` frame in the panel color (green abilities, cyan items); empty slots shown as dark outlines up to the cap (6/6); two rows next to the stacked stats, forming the ":=" layout |
| Extra info | Item stack counts ("x3") on item slots; a brief name popup that slides out when an ability or item is gained, used or lost |
| Not included | Cooldown numbers on ability slots; names always visible |
| Bolts | Counter stays top right |

### 3.2 TutorialText (instruction text)

| Topic | Decision |
| --- | --- |
| Position | Anchored to the subject: above the Droid for Repair, Harden, Heat Up and block; above the targeted creature for crit and Ball; above the affected creatures for Multi-Tame. Never over the playfield objects; follows camera zoom |
| Style | Outlined text with inline key icons, no panel; BBCode motion on the action word |
| Motion | Pop-in with overshoot, then a soft float on the shared 0.8 s beat (whole pixels, no text scaling); key icon "presses" in time with the beat; the action word (block, crit, absorb) waves or shakes with a color. No particles |
| Visibility | Always the full text (as now) |
| Controls bar | Stays at the bottom but is rebuilt from compact "key icon + one word" pairs that change per state (menu, targeting, shop, boons); the pressed key flashes |
| Fonts | 16 px text, 32 px for rare big words; no off-grid sizes |

### 3.3 Camera

| Segment | Decision |
| --- | --- |
| Player turn: target select | Eases to frame the Droid and the selected creature; wider with an AOE preview so all affected creatures fit |
| Player turn: attack | Contact emphasis tuned to proportional presets (small / medium / large) for push-in, shake and hit-stop; existing punch-in kept |
| Enemy turn | Slow push toward the attacker during its wind-up, pull back when the Droid must block |
| Repair | Zoom out slightly (about 1.0x on the Droid) so the whole play area is visible; bolts fly in from near the screen edges with a trail and a pulsing direction chevron; press the opposite arrow |
| Multi-Tame | Camera pulls wide enough to show the Droid and every creature the ability hits |
| Heat Up and Harden | Stay on the Droid with a gentle "power" push-in; prompts sit on a ring around the Droid; Harden's sequence sits in a row above the Droid with the instruction text above that |
| Victory and boons | Keep the Droid-centered victory zoom through the boon screen; only refine the ease and framing (short anticipation, soft overshoot, tamed creatures visible behind) |
| Shop | Calm wide frame with the Droid and Tuh-U (the shopkeeper), a slow idle drift, a gentle push-in when an item is highlighted; the new top UI stays visible |

### 3.4 Player minigames

| Minigame | Decision |
| --- | --- |
| Repair bolts | About 2x bigger with a bright outline (the shared selection outline); pop-in with overshoot and a gentle spin while they travel in; a short trail and a pulsing chevron at the edge they came from |
| Heat Up | Key prompts on a ring around the Droid, never under the text |
| Harden | Sequence in a row above the Droid; instruction text above the row (no overlap) |
| Multi-Tame | One ghost shape over each affected creature, popping in, clear and visible, with a bright outline when aligned |
| Ball | Meter moves above the targeted creature (keeping its current size and look); the "fully one color" zone gets about 25% more time plus a grace window of about 80 ms before and after; refined hit/miss animation |
| Attack text anchor | Block text above the Droid, crit text above the target, popping in during the wind-up and gone at contact |

### 3.5 Delivery

Segments in order, each one a commit (the user commits): 1 HUD, 2 TutorialText system, 3 camera, 4 minigames (Repair, Heat Up, Harden, Multi-Tame, Ball one by one).

## 4. Requirements

### Segment 1: HUD (`PlayerStatsHUD`, `CombatUI`)

R1.1 Power and defense: 16 px icons stacked, numbers 16 px, tight spacing; rows sized from UI constants.
R1.2 Abilities and items: two rows of `UIPanel`-framed slots (16 px frame, ability and item presets), filled from `PlayerData`, empty slots as dark outlines up to the cap (ability cap 6, item cap 6); built by one reusable `HudSlotRow`.
R1.3 Item slots show stack counts; changes play a short pop on the slot using the shared beat envelope.
R1.4 Name popup: a small outlined label slides out beside the row when an ability or item is gained, used or lost, then fades.
R1.5 The HUD never overlaps the camera's safe area used by the anchored text.

### Segment 2: TutorialText

R2.1 New API: `show_hint(type, anchor: Node2D)`; hint data (text with BBCode, key icons, anchor offset) lives in one table, not in a big `match`; old `HintType` values stay for callers.
R2.2 Rendering: outlined `RichTextLabel` with key icons inline, positioned from the anchor's global position through the camera (stays readable at any zoom, clamped to the screen).
R2.3 Motion: pop-in, beat float (whole pixels), key icon press loop, action word wave/shake via a custom `RichTextEffect`.
R2.4 States: crit, block, Repair, Multi-Tame, Heat Up, Harden, Ball, target select, boons, shop; one hide path with a fade.
R2.5 Controls bar rebuilt from key icon + word pairs per state; the pressed key flashes.
R2.6 Boon and shop texts have no subject, so they stay screen-anchored (small outlined text at a fixed place) (assumption, see section 6).
R2.7 Reuses: `UIArrow`/key icon art, `SelectionPulse.beat_envelope`, the shared outline shader for icons.

### Segment 3: Camera (`CameraController`, `CombatManager`, `StageFlowController`, `StopManager`)

R3.1 `frame(subjects: Array[Node2D], padding, zoom_limits)` computes position and zoom to fit subjects inside the safe area (below the top HUD, above the controls bar).
R3.2 Target-select framing uses `frame()` on the Droid + selected creature(s); updates on `cycle_enemy` with a short ease.
R3.3 Presets small/medium/large for push-in, shake and hit-stop; crits and hits pick a preset instead of passing raw numbers.
R3.4 Enemy attack anticipation and block pull-back through `anticipate(attacker)` / `release()`.
R3.5 Repair, Multi-Tame, Heat Up, Harden call named entrances (`ability_frame_wide`, `ability_frame_targets`, `ability_push_in`) so the knowledge of framing lives in the camera, not in `CombatManager`.
R3.6 Victory refined (anticipation hold, soft overshoot, framing keeps creatures visible); camera stays zoomed through the boon screen.
R3.7 Shop frame: wide frame with the Droid and Tuh-U, idle drift (about 0.5%), push-in on item highlight.
R3.8 Camera moves never change the Droid or creature positions (only the camera), and always end with `reset_camera()`.

### Segment 4: Minigames

R4.1 Repair: `RepairObject` scene gets a 2x sprite, outline, pop-in, spin, trail and a direction chevron; spawn at the screen edge in the chosen direction (distance from the camera frame, not 30 px from the Droid).
R4.2 Heat Up: `HeatUpPrompt` positions come from a ring around the Droid in camera space; no overlaps with text.
R4.3 Harden: key row anchored above the Droid; text anchored above the row.
R4.4 Multi-Tame: one ghost shape per affected creature, anchored over each creature; aligned state has a bright outline and pop; result uses the shared feedback style.
R4.5 Ball: meter anchored above the targeted creature; zone time +25%, grace window about 80 ms each side; hit/miss pop and flash.
R4.6 Block and crit text anchors as in 3.4.

## 5. Edge cases

- Anchored text near the screen edge is clamped; with AOE it anchors to the main target and shows once.
- Camera zoom out for Repair must keep the top HUD readable and the Droid at the same ground line.
- Pause/StopManager transitions mid-ability: the text hides and the camera resets as today.
- Tutorial scene (`TutorialDirector`) uses its own speech bubbles; its calls into `TutorialText` and the camera must keep working (verify with the tutorial scene run).
- Multi-Tame with a single creature or the dummy: one shape.
- Quick-repeat input in Repair never skips a bolt animation.

## 6. Assumptions to confirm (not asked yet)

- Boon, shop and target-select texts have no single subject: they stay screen-anchored (small outlined text at a fixed place near the top of the playfield).
- The HUD name popup shows for about 1.2 s and does not block input.
- Ability cap and item cap are both 6 (as in the current "(0/6)" text).
- Ball zone widening is +25% of the zone time and a fixed 80 ms grace window (tunable constants).
- Camera presets (small/medium/large) reuse the numbers from the earlier camera design board (3%, 4-8% push, 5-10 px shake); values are constants for a playtest pass.

## 7. Test plan

- After each segment: scene smoke runs (title, tutorial, combat), no new errors; screenshots at 1920x1080 in the real combat scene.
- HUD: with 0, 3 and 6 abilities/items; gaining, using and losing; stack counts; name popup.
- Text: each state at default and zoomed camera, anchor clamping, hide on interrupt.
- Camera: each ability and turn segment, victory to boons to shop, retry after death.
- Minigames: each one played with real input (driver scripts that press keys) and frame captures at key moments; Ball hit rate with grace window; AOE Multi-Tame with 1, 2 and 3 creatures.
- Numbers where possible (e.g. text pixel identity across the beat, as in the clearer-selections check).

## 8. Acceptance criteria

1. The HUD shows power over defense and two slot rows that tell the player what they own, in the same UI scale as the rest of the UI.
2. Every instruction text is anchored to its subject, never covers a minigame object, and animates without blurry scaling.
3. In Repair the player can see where every bolt comes from and which key pulls it in.
4. Each ability and turn segment has a camera framing that shows its subject; victory, boons and shop keep their identity.
5. Ball, Multi-Tame, Heat Up and Harden are playable and clear without reading anything but the instruction text.
6. No new errors; no new `.uid` files left behind.

## 9. Risks and follow-ups

- Camera zoom-out in Repair may show off-stage edges of the background; check the background width at the zoomed-out frame.
- Heavy motion on text during real-time sequences can distract; the effect amounts are constants and easy to tone down.
- Segment 3 touches `CombatManager`, which is large; keep each change behind the named camera entrances.
- Later: sound for pops and presses (Phase 4), tutorial scene rewrite.
