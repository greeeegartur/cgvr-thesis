class_name AbilityData extends Resource

enum TargetType {
	ENEMY,
	SELF
}

@export var id: String
@export var display_name: String
@export var icon: Texture2D
@export var cooldown_max := 1
@export var target_type: TargetType

var execute: Callable
