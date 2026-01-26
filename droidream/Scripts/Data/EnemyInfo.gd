extends Resource

# This script is for defining all necessary enemy info

class_name EnemyInfo

@export var enemy_id: String
@export var name: String
@export var type: CombatTypes.EntityType

@export var max_hp: float
@export var attack: int

@export var trust_max: int
@export var minigame_id: String

@export var attack_patterns: Array[EnemyAttackPattern]
@export var visual_scene: PackedScene
