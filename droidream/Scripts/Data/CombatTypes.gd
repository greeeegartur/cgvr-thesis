extends Node

# Combat types as enum values for safer implementation and conversion helper functions just in case

enum EntityType {
	GROUNDED,
	FLYING,
	SPECIAL
}

const ENTITY_TYPE_NAMES := {
	EntityType.GROUNDED: "grounded",
	EntityType.FLYING: "flying",
	EntityType.SPECIAL: "special"
}

func entity_type_to_string(type: EntityType) -> String:
	return ENTITY_TYPE_NAMES[type]

func string_to_entity_type(type: String) -> EntityType:
	if type == "grounded":
		return EntityType.GROUNDED
	elif type == "flying":
		return EntityType.FLYING
	elif type == "special":
		return EntityType.SPECIAL
	
	return EntityType
