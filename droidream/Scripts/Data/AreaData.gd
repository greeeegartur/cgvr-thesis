extends Resource

# This script is responsible for all area logic in Droidream, like transitioning from the Jungle to the Caverns

class_name AreaData

# Area identification variables
@export var area_id: String
@export var area_name: String

# Presentation variables
@export var background_scene: PackedScene # Background for the scene

# Stage data with 3 elements (1st, 2nd, 3rd stage)
@export var stages: Array[StageData]
