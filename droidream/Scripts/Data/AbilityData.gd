class_name AbilityData extends Resource

enum TargetType {
	ENEMY,
	SELF
}

enum UseMode {
	STANDARD, # Normal ability, which targets self/creature and then executes
	TAME_STYLE # Abilities that choose a tame chip after selection and then executes
}

@export var id: String
@export var display_name: String
@export var icon: Texture2D
@export var cooldown_max := 1
@export var target_type: TargetType
@export var use_mode: UseMode = UseMode.STANDARD

var execute: Callable
