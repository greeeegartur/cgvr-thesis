# PRD: Consistent pixel scale and a reusable UI panel

Status: part 1 implemented (`feature/character-pixel-scale`), part 2 implemented (`feature/ui-panel`) · Phase 3 item 12 ("Pixel and UI sizes made consistent")
Follows: `droidream/Resources/code_standards.md`

## Decisions (grill-me session)

| Topic | Decision |
| --- | --- |
| Character pixel size | Everyone at the Droid's current scale, **1.6**. The new textures set each character's size |
| UI pixel size | UI art at native **1x**; fonts on the 16 grid (**16** text, **32** titles) |
| Reusable container | One 9-slice template + palette shader, wrapped in a `UIPanel` class |
| Conversion scope | `UIPanel` + `UIRow`/`UIList`, then the 3 combat menus (attack/tame, abilities, items) and the ability/item/boon info boxes. Shop, rewards, bubbles, HUD later |
| List input | `UIList` owns selection and visuals (`move(dir)`, `confirm()`); `PlayerTurnUI` keeps routing input |
| Selected look | One style everywhere: a marker, the row slides right a few pixels, a highlight bar, a small pop on the 0.8 s selection beat |
| Tabs and tails | Base panel plus an optional tail piece (edge + offset); the info boxes keep their left pointer |
| Delivery | Two branches: characters first, then UI |

## Part 1: characters (done)

- New textures: duck 40x40 frames, frog 42x42 frames, tongue 84x21 (131.25%), Tuh-U 32x32.
- All body sprites now use scale 1.6: Beetle 1.5 → 1.6, Frog 1.8 → 1.6, Duck 1.7 → 1.6, Dummy 1.8 → 1.6, Tuh-U 0.8 (on 64x64 art) → 1.6 (on 32x32 art); Bat and the Droid already were 1.6. The tutorial's extra 0.9 scale on Tuh-U was removed.
- Each sprite was repositioned so the creature's feet and horizontal center stay where they were.
- Creature extras (frog tongue and flies, duck screech) moved/scaled by the same growth factor, including their animation tracks.
- Markers above heads (intent meter, turn order number, target arrow and the arrow's animation tracks) moved with each creature's new head height. `SelectionPulse` now bobs the arrow relative to its own rest position.
- `attack_offset` for beetle, frog and duck adjusted so each creature's front edge stops where it did.
- Not changed: Bat (same scale and art), the Droid, creature slot positions.

## Part 2: UI panel (done)

Facts found: the five 96x64 panel images (gray default, green abilities, cyan items, orange tame, plus an outline-only one) have identical structure: 5 flat colors per image (fill 4840 px, outer ring 616 px, black line 568 px, two corner-mark tones) and the same 68 transparent corner pixels. Most scenes use them as a plain `StyleBoxTexture` with no 9-slice margins, so resizing stretches the borders.

### R1 Template and style
- Use `defaultMenuStyleBox` as the one template (no redraw). Find the smallest 9-slice margin where the center and edges are uniform.
- `UIPanelStyle` resource: `fill`, `ring`, `mark_dark`, `mark_light` colors. Presets with the exact original colors: default, ability (green), item (cyan), tame (orange). A helper derives a style from one base color.
- Shader that maps the template's four non-black colors to the style colors (the black line is kept).

### R2 UIPanel
- `UIPanel` (Control/NinePatch based, `class_name UIPanel`): exports for `style`, size, optional `tail` (edge, offset, uses the small tab sprites from `listInfoContainer`); any size works because of the 9-slice.

### R3 Rows and lists
- `UIRow`: icon, label, right text or pips (cooldown), selected state with the shared selected look.
- `UIList`: holds rows, the selected index and the visuals; `move(dir)`, `confirm()`, signals `selected_changed(index)` and `confirmed(index)`.

### R4 Conversion
- Attack/tame, abilities and items menus in `PlayerTurnUI` use `UIPanel` + `UIList`/`UIRow`; the ability, item and boon info containers use `UIPanel` (with tail where they had one).
- Fonts in converted pieces: 16 and 32 only.

### Acceptance
1. One panel scene/class produces every current panel color and any new size or color.
2. Borders stay crisp when the panel is resized.
3. The three combat menus look and behave as before, with the new selected style and 16/32 fonts.
4. Scene smoke runs have no new errors; web export unaffected.
