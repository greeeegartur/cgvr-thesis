extends Node

# Combat types as enum values for safer implementation and conversion helper functions just in case

# New logic
enum EntityType {
	SKY,
	EARTH,
	WATER,
	NONE
}

static func guess_type_to_string(t: EntityType) -> String:
	match t:
		EntityType.SKY: return "Sky"
		EntityType.EARTH: return "Earth"
		EntityType.WATER: return "Water"
	return "?"
