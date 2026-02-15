extends Node

# This script controls the flow of combat scene transitions from areas to stops to next stages

class_name AreaManager

# Signals
signal area_changed(area: AreaData)
signal stage_changed(stage_index: int)

# All available areas
@export var areas: Array[AreaData]
var area_index := 0
var stage_index := 0
# TO-DO: make player specific var karma := 0

func get_current_area() -> AreaData:
	return areas[area_index]

func get_current_stage() -> StageData:
	return get_current_area().stages[stage_index]

func advance_stage():
	stage_index += 1
	if stage_index >= 3:
		advance_area()
	else:
		stage_changed.emit(stage_index)

func advance_area():
	stage_index = 0
	area_index += 1
	
	if area_index >= areas.size():
		_run_completed()
		return
	
	area_changed.emit(get_current_area())

# On player death, roguelike reset
func reset_to_first_area():
	area_index = 0
	stage_index = 0

func _run_completed():
	print("RUN COMPLETE")
