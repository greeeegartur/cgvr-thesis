# Droidream code standards

How the code in this project has been written so far, and the style future changes should follow.
Derived from the existing `.gd` files (71 scripts, ~10.7k lines) — when in doubt, copy the nearest existing script.

Engine: Godot 4.x, GDScript, GL Compatibility renderer, exported to Web / macOS / Windows / Linux.

---

## 1. Language of comments and text

- **Everything is English**: comments, identifiers, `print` messages, enemy/item/ability names, dialogue.
- Comments are plain sentences written in the **third person about what the code does** ("Loads enemy info for entity via enemy_id string", "Opens the player critical hit window during player's attack").
- Use `# ` (hash + space). Commented-out code is `#code` with no space, and should be deleted once it is no longer needed.
- Tone is informal but precise. No emojis, no ASCII art.
- Game terms are used consistently:
  - **tame / kill** — the two ends of the enemy *axis* (`axis_value`, `axis_max`); `axis_max` = tamed, `-axis_max` = killed.
  - **chips / guesses** — the Sky / Earth / Water types the player attacks with (`CombatTypes.EntityType`).
  - **minigame** — an enemy's short reflex sequence; **player actions** — ability / item sequences started by the player.
  - **boon** — run upgrade chosen on the boon screen; **passive** — always-on ability.

## 2. Where comments go

| Where | Style |
| --- | --- |
| Top of file | One sentence directly under `extends` / `class_name` saying what the script is responsible for. Minigames also add a `# HOW TO PLAY?` block. |
| Above every function | One or two lines: what it does, and what it expects (parameters, preconditions). |
| Inside a function | A comment above each logical step ("# Camera settings", "# End of the turn"). |
| Trailing (`# ...` after code) | Short facts about a single value: `var axis_max := 1.0 # axis_max = tamed, while -axis_max = killed`. |
| Section banners | `# UPPER CASE TITLE` on its own line, e.g. `# HELPERS`, `# ACTION FUNCTIONS`, `# COMBAT SETUP FUNCTIONS`, `# SCRIPT VARIABLES`. |
| Open work | `# TO-DO: ...` (hyphenated, upper case) — keep it actionable and specific. |

```gdscript
extends Node
class_name CombatEntity

# This script is for handling entity data in combat, such as the player and enemy(s)

# Loads enemy info for entity via enemy_id string
# enemy_id string must be present on an enemy resource in the Data folder
func load_from_enemy_id(enemy_id: String) -> void:
	var data = EnemyDatabase.get_enemy(enemy_id)
	...
```

Order at the top of a script: `extends` → `class_name` → header comment → `signal`s → `@export`s → `@onready`s → plain `var`s → `const`s (existing files vary; new files should follow this order).

## 3. Naming

| Thing | Convention | Example |
| --- | --- | --- |
| Files / scenes / `class_name` | `PascalCase` | `CombatManager.gd`, `BatFlash.tscn` |
| Variables, functions, signals | `snake_case` | `selected_enemy`, `player_attack()`, `combat_end` |
| Private helpers (not called from other scripts) | leading underscore | `_apply_axis_shift()`, `_enemy_turn()` |
| Constants | `UPPER_SNAKE_CASE` | `DAMAGE`, `MAX_BUFFER_LENGTH` |
| Enums | `PascalCase` name, `UPPER_CASE` values | `EntityType.SKY` |
| Resource ids (strings) | lower `snake_case`, no spaces | `"bat_flash"`, `"multitame"` |
| Folders | `PascalCase`, **no spaces** | `Scenes/Minigames/BatFlash/` |
| Sprites | `snake_case` or `PascalCase`, **no spaces / parentheses** | `player_attack.png` |

Methods that run as a coroutine and drive a sequence are named `_<thing>_sequence` (`_ability_repair_sequence`, `_item_ball_sequence`).

## 4. Formatting

- **Tabs** for indentation (the existing scripts use tabs only); never spaces.
- Use `:=` for inferred local/member variables and give function parameters types (`enemy: CombatEntity`). Return types (`-> void`, `-> bool`) are only on ~18% of existing functions; add them to all new functions.
- Prefer a blank line between functions; one blank line inside a function separates logical steps.
- Multi-line signal connections use the lambda form with `CONNECT_ONE_SHOT`:

```gdscript
player_visual.attack_finished.connect(
	func():
		# Check if enemy defeated
		if _check_victory():
			_end_combat(true)
		else:
			_enemy_turn(),
	CONNECT_ONE_SHOT
)
```

## 5. How the game logic is structured

- **Signals up, calls down.** Visual scripts (`PlayerVisual`, `EnemyVisual`, UI) emit signals (`attack_hit`, `block_attempted`, `combat_end`); `CombatManager` listens and owns the game state. Visuals never decide damage.
- **Turns are coroutines.** Sequences use `await` (animations, timers, minigame completion). Guard against re-entry with flags (`combat_has_ended`, `in_minigame`) before progressing a turn.
- **Content is data.** Enemies, attack patterns, abilities, items, boons, areas and stages are `Resource` (`.tres`) files under `Scripts/Data/…`, typed by a script (`EnemyInfo`, `AbilityData`, `BoonData`, `ItemData`, `AreaData`, `StageData`).
  - `EnemyDatabase` scans `Scripts/Data/Enemies/` at runtime; `AbilityDb`, `ItemDb`, `CombatItemDb` and `BoonManager` `preload` each resource in `_ready()` and attach its behaviour (an `execute`/`effect` lambda) there.
  - To add an enemy: new `.tres` in `Scripts/Data/Enemies`, scene in `Scenes/Entities/<Name>/`, attack patterns in `Scripts/Data/Attack_Patterns`, minigame in `Scenes/Minigames/<Name>/` + `Scripts/Minigames/<Name>.gd` extending `BaseMinigame`.
- **Autoloads** (global singletons, see `project.godot`): `Utils`, `EnemyDatabase`, `CombatTypes`, `PlayerData`, `ItemDb`, `AbilityDb`, `CombatItemDb`. Use them for shared state; do not add new ones lightly.
- **Debug output**: plain-English `print("Player attacks with: ", attack_type)`; `print("")` for visual spacing in the terminal; `push_error("...")` for guard failures that should never happen. Remove noisy debug prints once a bug is fixed.
- **Dev-only shortcuts** must be wrapped in `OS.is_debug_build()` so they never ship.

## 6. Project layout

```
droidream/
  Documentation/    screenshots, recordings, notes for the thesis
  Graphics/
    Fonts/
    Sprites/        Backgrounds, Boons, Items, Minigames/<Name>, Player, Title, UI, VFX
  Resources/        project meta: code_standards.md (not exported)
  Scenes/
    Screens/        top-level scenes (Title, Tutorial, Combat)
    Combat/         combat background, stop/pause UI
    Entities/       player and enemy visual scenes (one folder per enemy)
    Minigames/      enemy minigames, one folder per minigame
    PlayerActions/  ability / item sequences (Ball, Harden, HeatUp, MultiTame, Repair)
    UI/             HUD, menus, rows, containers, rewards, shop, boon screen
    VFX/            damage numbers, explosions, feedback text, light rays
  Scripts/          mirrors Scenes/ — Combat, Entities, Minigames, PlayerActions, Tutorial, UI, VFX
    Data/           Resource definitions + .tres content (Abilities, Areas, Attack_Patterns, Boons, Enemies, Items, ShopItems)
```

Rules of thumb:
- A scene and its script share the same name (`PlayerTurnUI.tscn` ↔ `PlayerTurnUI.gd`).
- Move/rename files **inside the Godot editor** (or with a script that also moves `.import`/`.uid` files and rewrites `res://` paths). Moving them in Finder leaves broken references.
- No spaces in file or folder names.

## 7. Git workflow

- `main` — released builds only. `dev` — integration branch. Work happens on short-lived branches off `dev`, one feature/bugfix per branch, merged back into `dev`; `dev` is merged to `main` for a release.
- Branch names: `feature/<name>`, `bugfix/<name>`, `hotfix/<name>`, `refactor/<name>`.
- Commit messages: short imperative summary, details in the body.
- Do not commit `.godot/`, `.DS_Store`, `*.zip` or editor/tooling caches (see root `.gitignore`).

## 8. Known inconsistencies (fix when touching the file)

- `@export` scene/texture variables are sometimes `PascalCase` (`BatScene`); use `snake_case`.
- Header comment sits before or after `class_name` depending on the file; use the order in section 2.
- Return types are missing on ~80% of functions.
- ~19 open `TO-DO` comments, several about defense/damage math that is tracked in the demo changes list.
