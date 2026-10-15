extends Node

# Combat types as enum values for safer implementation and conversion helper functions just in case

# New logic
enum EntityType {
	SKY,
	EARTH,
	WATER,
	NONE
}

# Type colors, shared by the duck type reveal and feedback texts
const TYPE_COLORS := {
	EntityType.SKY: Color("f7ff3c"),
	EntityType.EARTH: Color("8b5a2b"),
	EntityType.WATER: Color("4da6ff")
}

# Returns the type's name wrapped in its color as bbcode
static func type_bbcode(t: EntityType) -> String:
	var color: Color = TYPE_COLORS.get(t, Color.WHITE)
	return "[color=#%s]%s[/color]" % [color.to_html(false), guess_type_to_string(t)]

static func guess_type_to_string(t: EntityType) -> String:
	match t:
		EntityType.SKY: return "Sky"
		EntityType.EARTH: return "Earth"
		EntityType.WATER: return "Water"
	return "?"
