extends RichTextEffect
class_name HintTextEffect

# BBCode effect for instruction text, [hint kind=wave]word[/hint] or kind=shake; it moves letters in whole pixels so the text stays crisp

var bbcode := "hint"

func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	var kind: String = char_fx.env.get("kind", "wave")
	var time := char_fx.elapsed_time
	var index := char_fx.relative_index
	
	if kind == "shake":
		# Small jolts at 12 steps per second, different for every letter
		var step := floorf(time * 12.0)
		char_fx.offset.x = roundf(sin(step * 12.9898 + index * 78.233))
		char_fx.offset.y = roundf(sin(step * 39.346 + index * 11.135))
	else:
		# A wave running through the letters, up to 3 px high
		char_fx.offset.y = -roundf(1.5 + 1.5 * sin(time * 7.0 - index * 0.7))
	return true
