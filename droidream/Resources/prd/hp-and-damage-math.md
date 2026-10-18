# PRD: HP and damage math fixes (quarter-step values)

Status: draft for review · Phase 2, item 8 · Branch suggestion: `bugfix/quarter-step-math`
Follows: `droidream/Resources/code_standards.md`

## 1. Summary

All HP and intent-meter values move in steps of 0.25. "HP shows 0" and "HP is 0" become the same thing, and a creature whose intent meter is one step from full counts as tamed (or killed). The rule lives in one place so multi-tame, the ball, and the quick-tame reward bonus can rely on it.

## 2. Problem (what is wrong today)

Found by reading the current code:

1. **Player HP is not stored in quarters.** `_set_player_hp` only clamps. Damage is `attack × multiplier` with crit ×1.5, block ×0.5, Thick Jelly and flat defense applied one after another and never rounded. Some heals are also unrounded (minigame heal, Microbots, Human at Heart, which writes `PlayerData.hp` directly).
2. **The display disagrees with the state.** `PlayerVisual.update_hp` rounds to the nearest quarter, so 0.1 HP is drawn as "0" while the player is alive (`player.hp <= 0` is exact).
3. **Creature meters look full before they count.** Shifts are rounded to quarters, but `is_minigame_ready` / `is_killed` compare exactly (`axis >= axis_max`), so 7.75 / 8 looks full but is not tamed.
4. **Rounding is copied three times** (`CombatManager.round_quarter`, `PlayerVisual.round_quarter`, inline `round(x*4)/4`).
5. **Some data is off the grid.** The duck double hit blocked is 0.375, which rounds to 0.5, so block saves one third instead of half.

## 3. Goals and non-goals

Goals
- Every player HP value and every creature axis value is a multiple of 0.25 at all times.
- Death is exactly `hp == 0`. Tame/kill is exactly "within one step of the end".
- One set of helpers and setters, so later systems cannot reintroduce stray values.
- Automated tests for the rules.

Non-goals
- Rebalancing numbers beyond the one duck data fix (a general balance pass comes after this).
- New HUD design (the meter numbers use the new values, but layout is Phase 3).
- Changing reward logic (the quick-tame bonus only reads `is_tamed()`).

## 4. Decisions (from the grill-me session)

| Topic | Decision |
| --- | --- |
| HP storage | Always in quarters; every write is snapped in one setter |
| Damage rounding | Nearest quarter (ties away from zero). Any hit that deals damage is at least 0.25, even after defense. Misses and fully "missed" hits stay 0 |
| Heal rounding | Nearest quarter, at least 0.25 when the heal would give something |
| Tame/kill snap | A creature within 0.25 of either end counts as tamed/killed; its axis is set to the exact end so the bar looks full |
| Scratchy Frame | Reflect margin becomes 0.5, so reflected damage never tames or kills |
| Blocked quirk | Duck double hit multiplier 0.75 → 0.5 (blocked: 0.25 exact; unblocked total 1.0) |
| Implementation | One helper, compute in floats and round once at the end |
| Meter numbers | Exact quarters (e.g. 5.75 / 8) |
| Minimum meter shift | Any resolved tame/kill hit moves the meter by at least 0.25 |
| Data checks | Warn at load when enemy data would produce off-grid values |
| Verification | GdUnit4 tests plus the headless scene runs |

## 5. Requirements

R1 **Quantize helpers** in `Scripts/Data/Utils.gd` (autoload):
- `quantize(v) -> float`: `round(v * 4.0) / 4.0`.
- `quantize_min(v, minimum := 0.25) -> float`: quantize, and if `v > 0` return at least `minimum`.
R2 **Player HP setter**: `_set_player_hp` quantizes (and clamps to `[0, max_hp]`). All heals/damage go through `_change_player_hp`; no direct writes to `PlayerData.hp` from combat code (Human at Heart, post-combat sync).
R3 **Damage chain**: compute `base × hit_multiplier × crit × block × jelly` and the flat defense subtraction in floats; quantize once via `quantize_min` when the resulting damage is greater than 0 before defense; 0 only for a miss.
R4 **Heals**: Microbots, Ice Cube, Beetle Juice, Human at Heart and the minigame heal all use `quantize_min`.
R5 **Creature axis**: all axis writes (tame shift, kill shift, multi-tame, ball, hypno, minigame restore, heal) go through one setter that quantizes, clamps to `[-axis_max, axis_max]` and then snaps (R6).
R6 **Snap**: after each write, if `axis_value >= axis_max - 0.25` set it to `axis_max`; if `axis_value <= -(axis_max - 0.25)` set it to `-axis_max`. `is_minigame_ready()` and `is_killed()` then keep exact comparisons.
R7 **Minimum shift**: a resolved correct or wrong guess shifts by at least 0.25 (before clamp).
R8 **Scratchy Frame**: margin constant 0.25 → 0.5.
R9 **Display**: HP label and heart use the stored value directly (no second rounding). Creature meter number, when shown, is the exact quarter value.
R10 **Data warnings**: `EnemyDatabase` (or an enemy-load helper) warns when `max_hp`, `attack`, or any hit multiplier × attack is not a multiple of 0.25 for the unblocked and blocked case.
R11 **Data fix**: `duck_tackle_double.tres` multipliers 0.75 → 0.5.
R12 **Remove duplicates**: delete `PlayerVisual.round_quarter` and `CombatManager.round_quarter`; callers use `Utils.quantize`.

## 6. Worked examples (acceptance numbers)

| Case | Result |
| --- | --- |
| HP 1.0, damage 0.9 | damage 1.0, HP 0, player dies (no more "0 HP and alive") |
| Duck single 1.5, enemy crit ×1.5, block ×0.5 | 1.125 → 1.25 |
| Duck double 0.5, blocked | 0.25 |
| 0.25 hit, defense 0.5 | 0.25 (minimum) |
| Microbots at max HP 10: 20 % | 2.0; at max HP 10.25: 2.05 → 2.0 |
| Creature 8 HP at 7.75 | counts as tamed, axis set to 8 |
| Creature 8 HP at -7.75 | counts as killed |
| Scratchy reflect on a creature at 7.0 / 8 | reflects at most 0.5 (stops at 7.5) |
| Multi-tame 1.25× on shift 1.8 | 2.25 (one rounding of 1.8 × 1.25 = 2.25) |

## 7. Code touchpoints

| File | Change |
| --- | --- |
| `Scripts/Data/Utils.gd` | add `quantize`, `quantize_min` |
| `Scripts/Combat/CombatEntity.gd` | axis setter + snap; `is_*` stay exact |
| `Scripts/Combat/CombatManager.gd` | `_set_player_hp` (R2); `_resolve_enemy_hit` damage chain (R3); heals at the Microbots, Ice Cube, Beetle Juice, Human at Heart and minigame heal sites (R4); `_apply_axis_shift`, `_apply_axis_shift_with_multiplier`, ball/hypno/heal axis writes (R5, R7); Scratchy margin (R8); drop `round_quarter` (R12) |
| `Scripts/Entities/PlayerVisual.gd` | use stored HP directly; drop duplicate rounding (R9, R12) |
| `Scripts/Data/PlayerData.gd` | `add_hp`/max HP use `quantize` |
| `Scripts/Data/EnemyDatabase.gd` | data warnings (R10) |
| `Scripts/Data/Attack_Patterns/duck_tackle_double.tres` | R11 |
| `Tests/` (new) + `addons/gdUnit4/` (dev only) | tests; export filter updated so neither ships |

## 8. Edge cases

- Overheal: heal clamps at max HP after quantizing; the shown heal number is the amount actually applied.
- Max HP upgrades that are not multiples of 0.25 are quantized on add.
- Multi-hit patterns: death is checked after each hit (existing behavior); later hits are cancelled.
- A creature snapped to full mid-multi-tame still resolves the rest of the targets in order.
- Karma and reward formulas read creature `max_hp` and `trust_max` only; unaffected.
- The tutorial dummy and the tutorial's scripted HP stay on the grid (verify).

## 9. Test plan

Automated (GdUnit4)
- `quantize` / `quantize_min`: ties, negatives, 0, very small positives.
- Player damage chain: table of (base, multiplier, crit, block, defense) cases, including the 0.9-damage-at-1.0-HP case.
- Heals: each heal source with odd max HP values.
- Axis: shifts that end at 7.5 / 7.75 / 8, snap on both sides, minimum shift, clamp.
- Scratchy margin: reflect never tames/kills.
- Property check: 10 000 random hits/heals; assert HP and axis always on the 0.25 grid and `hp == 0` ⇔ dead.

Manual / headless
- Scene smoke runs (title, tutorial, combat) with no new errors.
- Playtest: duck fight, a block-heavy fight, Microbots + Ice Cube run, a multi-tame on 3 creatures.

## 10. Acceptance criteria

1. No stray values: in any combat log, every HP and axis value printed is a multiple of 0.25.
2. The player can never be alive while the HUD shows 0.
3. A creature that visually looks full is tamed (or killed), and the meter shows full.
4. The duck table in section 6 holds.
5. All tests pass; the web export builds and does not include tests or the test addon.

## 11. Risks and follow-ups

- **Balance shift**: min 0.25 damage and the 7.75 snap make fights slightly shorter or harsher; do a short balance pass afterwards (duck was already marked for revisit).
- **Test addon**: GdUnit4 is not in the project yet; adding it must not enter the exported build (update `exclude_filter` and keep CI unchanged).
- **Later phases**: multi-tame minigame (0.75 / 1 / 1.25 / 1.5× tiers) and the ball area target reuse the same setters; the HUD meter number is part of Phase 3 item 13.

## 12. Open questions

None blocking. Optional: whether the web build should print the new data warnings (suggested: editor and debug builds only).
