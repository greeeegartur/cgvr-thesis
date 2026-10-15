class_name ItemData
extends Resource

enum TargetType {
	SELF,
	ENEMY
}

@export var id: String
@export var display_name: String
@export_multiline var description: String
@export var icon: Texture2D
@export var target_type := TargetType.SELF
@export var target_reach := 0 # Creatures also hit on each side of the main target (0 = only the target)
@export var max_stack := 9

var use_effect: Callable
