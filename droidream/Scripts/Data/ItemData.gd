extends Resource
class_name ItemData

@export var id: String
@export var display_name: String
@export var description: String
@export var icon: Texture2D

@export var cost: int = 2
@export var max_stack: int = 1   # 1 = unique and if >1 = stackable
@export var repeatable: bool = false # Can be infinitely bought (don't know if I'm going to add such items)
