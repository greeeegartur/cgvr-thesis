extends RefCounted
class_name SceneTransition

# Screen transitions that leave the current scene: a fade to black that keeps running while the game is frozen, then the next scene

const TITLE_SCENE := "res://Scenes/Screens/TitleScreen.tscn"
const FADE_TIME := 0.8

# Fades to black, resets the run and shows the title screen (which fades in from black on its own)
static func go_to_title(tree: SceneTree) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 200
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	black.modulate.a = 0.0
	layer.add_child(black)
	tree.root.add_child(layer)
	
	var tween := black.create_tween()
	tween.set_ignore_time_scale(true)
	tween.tween_property(black, "modulate:a", 1.0, FADE_TIME)
	await tween.finished
	
	# Everything that the pause or a slow-motion effect may have left behind goes back to normal
	Engine.time_scale = 1.0
	PauseMenu.active = false
	Sfx.set_paused(false)
	Sfx.stop_all()
	PlayerData.reset_run()
	tree.change_scene_to_file(TITLE_SCENE)
	await tree.process_frame
	await tree.process_frame
	layer.queue_free()
