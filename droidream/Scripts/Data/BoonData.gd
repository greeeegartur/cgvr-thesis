extends Resource

# This class defines the basic boon (upgrade) data

class_name BoonData

@export var id: String
@export var name: String
@export var description: String
@export var type: String # Either "Item", "Upgrade", "Passive" or "Ability"
@export var icon: Texture2D

var effect: Callable

# Each boon calls this directly with their own effect
func apply(target):
	if effect:
		effect.call(target)
