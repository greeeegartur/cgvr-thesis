extends BaseMinigame
class_name TutorialPromptMinigame

var tutorial_paused := false

func _ready():
	set_duration(20.0)
	
	progress_bar.max_value = max_duration
	progress_bar.value = max_duration
	timer_label.text = "%.1fs" % max_duration

	# FOR TESTING
	# play()

func _process(delta):
	if tutorial_paused:
		return
	
	super._process(delta)
	
	if not running:
		return
	
	update_timer_ui()

func _unhandled_input(event):
	if tutorial_paused:
		return
	
	if not running:
		return
	
	if event.is_action_pressed("ui_accept"):
		await end(true)

func set_tutorial_paused(paused: bool):
	tutorial_paused = paused

func on_timeout():
	await end(false)
