extends CanvasLayer
class_name PauseMenu

# The pause menu: ESC freezes the game (game time stops, so every timer, tween and animation stops) and opens Resume / Options / (Restart) / Quit over a dimmed world
# Restart is only offered in the combat scene, and not once the demo ending has begun

enum State { CLOSED, MAIN, CONFIRM_QUIT, OPTIONS, QUITTING }

const DIM_SHADER := preload("res://Scenes/UI/PauseDim.gdshader")
const FONT_BOLD := preload("res://Graphics/Fonts/PixelOperator-Bold.ttf")
const OPEN_TIME := 0.2
const MIN_WIDTH := 150.0
const HINT_GAP := 16 # Between the key hints

static var active := false # True while the game is frozen by the pause menu; code that polls the keyboard for gameplay checks it

var state := State.CLOSED
var stored_time_scale := 1.0
var dim: ColorRect
var dim_material: ShaderMaterial
var panel: UIPanel
var title: Label
var note: Label
var list: UIList
var hint: HBoxContainer # Key icons with one word each, at the bottom of the panel
var hint_size := Vector2.ZERO
var open_tween: Tween
var options: OptionsMenu
var note_tween: Tween
var confirm_kind := "" # "quit", "restart" or "prompt" while the Yes/No list is open
var prompt_heading := ""
var prompt_yes: Callable # A prompt (the tutorial's Skip tutorial?) runs this on Yes
var main_entries: Array[String] = [] # The rows of the main list, in order

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()
	options = OptionsMenu.new()
	options.closed.connect(_on_options_closed)
	add_child(options)

# Builds the dim layer and the panel with its title, list and hint
func _build() -> void:
	dim = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim_material = ShaderMaterial.new()
	dim_material.shader = DIM_SHADER
	dim.material = dim_material
	add_child(dim)
	
	panel = UIPanel.new()
	add_child(panel)
	
	title = _make_label(32, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)
	
	list = UIList.new()
	list.ignore_time_scale = true
	panel.add_child(list)
	
	note = _make_label(16, false)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(note)
	
	hint = HBoxContainer.new()
	hint.add_theme_constant_override("separation", HINT_GAP)
	hint.alignment = BoxContainer.ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(hint)

# Rebuilds the key hint under the panel: key icon + one word per pair
func _set_hint(pairs: Array) -> void:
	for child in hint.get_children():
		child.queue_free()
		hint.remove_child(child)
	hint_size = Vector2.ZERO
	for pair in pairs:
		var item := HBoxContainer.new()
		item.add_theme_constant_override("separation", 5)
		item.alignment = BoxContainer.ALIGNMENT_CENTER
		var icon := KeyIcon.new()
		icon.setup(pair[0], 1.5)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		item.add_child(icon)
		var word := _make_label(16, false)
		word.text = pair[1]
		item.add_child(word)
		hint.add_child(item)
		hint_size.x += icon.custom_minimum_size.x + 5.0 + word.get_minimum_size().x + (HINT_GAP if hint_size.x > 0.0 else 0.0)
		hint_size.y = maxf(hint_size.y, maxf(icon.custom_minimum_size.y, word.get_minimum_size().y))

func _make_label(size: int, bold: bool) -> Label:
	var label := Label.new()
	label.add_theme_font_override("font", FONT_BOLD if bold else UIRow.FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6 if bold else 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	
	if state == State.OPTIONS:
		return # The options container takes the input
	
	# The key that opened a prompt (T for Skip tutorial?) closes it again
	if is_prompt_open() and event is InputEventKey and event.pressed and event.physical_keycode == KEY_T:
		Sfx.play_cancel()
		_back_to_main()
		get_viewport().set_input_as_handled()
		return
	
	if event.is_action_pressed("pause"):
		match state:
			State.CLOSED:
				if _can_open():
					open()
					get_viewport().set_input_as_handled()
			State.MAIN:
				Sfx.play_cancel()
				close()
				get_viewport().set_input_as_handled()
			State.CONFIRM_QUIT:
				_back_to_main()
				get_viewport().set_input_as_handled()
		return
	
	if state == State.CLOSED:
		return
	
	# While the menu is open it takes every input, so nothing in the game reacts
	get_viewport().set_input_as_handled()
	if state == State.QUITTING:
		return
	
	if event.is_action_pressed("ui_up"):
		list.move(-1)
	elif event.is_action_pressed("ui_down"):
		list.move(1)
	elif event.is_action_pressed("ui_accept"):
		list.confirm()
	elif event.is_action_pressed("ui_cancel"):
		Sfx.play_cancel()
		if state == State.CONFIRM_QUIT:
			_back_to_main()
		else:
			close()

# The menu does not open during screen fades or on the death screen (which has its own menu)
func _can_open() -> bool:
	var ui := get_parent().get_node_or_null("UI")
	if ui:
		var black := ui.get_node_or_null("Black") as CanvasItem
		if black and black.visible and black.modulate.a > 0.01:
			return false
		var death := ui.get_node_or_null("DeathScreen") as CanvasItem
		if death and death.visible:
			return false
	return true

func open() -> void:
	stored_time_scale = Engine.time_scale if Engine.time_scale > 0.1 else 1.0 # A hit-stop that was running is dropped
	Engine.time_scale = 0.0
	active = true
	Sfx.set_paused(true)
	Music.set_paused_dim(true)
	Sfx.play_ui("option_select")
	
	visible = true
	_show_main()
	_animate_in()

# Closes with the reverse animation, then lets time run again exactly as it was
func close() -> void:
	state = State.QUITTING # Ignores input during the animation
	if open_tween:
		open_tween.kill()
	open_tween = create_tween().set_ignore_time_scale(true).set_parallel()
	open_tween.tween_property(dim_material, "shader_parameter/amount", 0.0, OPEN_TIME)
	open_tween.tween_property(panel, "modulate:a", 0.0, OPEN_TIME)
	open_tween.tween_property(hint, "modulate:a", 0.0, OPEN_TIME)
	await open_tween.finished
	
	visible = false
	Engine.time_scale = stored_time_scale
	active = false
	Sfx.set_paused(false)
	Music.set_paused_dim(false)
	state = State.CLOSED

# Closes without the animation and lets time run again at once (a prompt's Yes starts its own fade right away)
func _close_now() -> void:
	if open_tween:
		open_tween.kill()
	visible = false
	Engine.time_scale = stored_time_scale
	active = false
	Sfx.set_paused(false)
	Music.set_paused_dim(false)
	state = State.CLOSED
	confirm_kind = ""

func _animate_in() -> void:
	if open_tween:
		open_tween.kill()
	dim_material.set_shader_parameter("amount", 0.0)
	panel.modulate.a = 0.0
	hint.modulate.a = 0.0
	panel.pivot_offset = panel.size / 2.0
	panel.scale = Vector2(0.88, 0.88)
	open_tween = create_tween().set_ignore_time_scale(true).set_parallel()
	open_tween.tween_property(dim_material, "shader_parameter/amount", 1.0, OPEN_TIME)
	open_tween.tween_property(panel, "modulate:a", 1.0, OPEN_TIME)
	open_tween.tween_property(panel, "scale", Vector2.ONE, OPEN_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	open_tween.tween_property(hint, "modulate:a", 1.0, OPEN_TIME)

# Main list: Resume / Options / (Restart) / Quit
func _show_main() -> void:
	state = State.MAIN
	_set_hint([["Z", "Confirm"], ["X", "Resume"]])
	main_entries = ["Resume", "Options"]
	if _can_restart():
		main_entries.append("Restart")
	main_entries.append("Quit")
	var rows := []
	for entry in main_entries:
		rows.append({ "text": entry })
	_set_content("Paused", "", rows, 0)
	if list.confirmed.is_connected(_on_confirm_quit):
		list.confirmed.disconnect(_on_confirm_quit)
	if not list.confirmed.is_connected(_on_main_confirmed):
		list.confirmed.connect(_on_main_confirmed)

# Restart is offered in the combat scene only, and not once the demo ending has begun
func _can_restart() -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.get_node_or_null("StageFlowController") != null and not scene.has_meta("no_restart")

# A Yes/No question on its own, with the game frozen and the sound muffled like the pause menu (the tutorial's Skip tutorial?)
# No, Cancel, Escape or close() leave the game exactly where it was; Yes closes at once and runs on_yes
func open_prompt(heading: String, on_yes: Callable) -> void:
	if state != State.CLOSED or not _can_open():
		return
	open()
	prompt_heading = heading
	prompt_yes = on_yes
	_show_confirm("prompt")

func is_prompt_open() -> bool:
	return state == State.CONFIRM_QUIT and confirm_kind == "prompt"

# Back from the Yes/No list to the main list, on the row that opened it (a prompt just closes)
func _back_to_main() -> void:
	if confirm_kind == "prompt":
		confirm_kind = ""
		close()
		return
	var row := "Restart" if confirm_kind == "restart" else "Quit"
	_show_main()
	list.select(main_entries.find(row), false)

# Confirmation list: Yes / No, with No preselected (kind is "quit" or "restart")
func _show_confirm(kind := "quit") -> void:
	state = State.CONFIRM_QUIT
	confirm_kind = kind
	_set_hint([["Z", "Confirm"], ["X", "Back"]])
	var heading := "Restart?" if kind == "restart" else "Quit to title?"
	var note_text := "Your progress won't save."
	if kind == "prompt":
		heading = prompt_heading
		note_text = ""
	_set_content(heading, note_text, [{ "text": "Yes" }, { "text": "No" }], 1)
	if list.confirmed.is_connected(_on_main_confirmed):
		list.confirmed.disconnect(_on_main_confirmed)
	if not list.confirmed.is_connected(_on_confirm_quit):
		list.confirmed.connect(_on_confirm_quit)

# Fills title, note and rows, then sizes and centers the panel around them
func _set_content(title_text: String, note_text: String, entries: Array, selected: int) -> void:
	if note_tween:
		note_tween.kill()
	title.text = title_text
	note.text = note_text
	note.modulate.a = 1.0
	list.set_rows(entries)
	list.select(selected, false)
	
	var title_size := title.get_minimum_size()
	var note_size := note.get_minimum_size() if note_text != "" else Vector2.ZERO
	var list_size := list.size
	var width := maxf(MIN_WIDTH, maxf(title_size.x, maxf(note_size.x, maxf(list_size.x, hint_size.x))))
	
	var y := 0.0
	title.position = Vector2(0, y)
	title.size = Vector2(width, title_size.y)
	y += title_size.y + 6.0
	if note_text != "":
		note.position = Vector2(0, y)
		note.size = Vector2(width, note_size.y)
		y += note_size.y + 4.0
	note.visible = note_text != ""
	list.position = Vector2((width - list_size.x) / 2.0, y)
	y += list_size.y + 10.0
	hint.size = Vector2(width, hint_size.y)
	hint.position = Vector2(0, y)
	y += hint_size.y
	
	panel.fit_to(Vector2(width, y))
	var origin := panel.content_origin()
	title.position += origin
	note.position += origin
	list.position += origin
	hint.position += origin
	
	var screen := get_viewport().get_visible_rect().size
	panel.position = ((screen - panel.size) / 2.0).round()
	panel.pivot_offset = panel.size / 2.0

func _on_main_confirmed(index: int) -> void:
	match main_entries[index]:
		"Resume":
			close()
		"Options":
			_open_options()
		"Restart":
			_show_confirm("restart")
		"Quit":
			_show_confirm("quit")

# Options opens its own container over the pause menu; the pause panel waits behind it
func _open_options() -> void:
	state = State.OPTIONS
	panel.visible = false
	options.open(false)

func _on_options_closed() -> void:
	panel.visible = true
	_show_main()
	list.select(1, false)

func _on_confirm_quit(index: int) -> void:
	if index == 0:
		state = State.QUITTING
		if confirm_kind == "prompt":
			_close_now()
			prompt_yes.call()
		elif confirm_kind == "restart":
			SceneTransition.restart_combat(get_tree())
		else:
			SceneTransition.go_to_title(get_tree())
	else:
		_back_to_main()
