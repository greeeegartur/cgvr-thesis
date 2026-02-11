extends Node

class_name StopManager

signal stop_finished

@onready var ui := $"../UI/StopUI"

func open(tier: int):
	ui.show_stop(tier)
	ui.next_pressed.connect(_on_next)

func _on_next():
	ui.hide()
	stop_finished.emit()

# TO-DO: karma based prices
