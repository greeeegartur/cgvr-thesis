extends Node2D

# The title screen menu: Play (with the "Play tutorial?" popup), Options and Quit; the art behind it is untouched

class_name TitleScreen

enum State { LOADING, MENU, PLAY_POPUP, OPTIONS, LEAVING }

@export var tutorial_scene_path := "res://Scenes/Screens/TutorialScene.tscn"
@export var game_scene_path := "res://Scenes/Screens/CombatScene.tscn"

const FONT_BOLD := preload("res://Graphics/Fonts/PixelOperator-Bold.ttf")
const MENU_CENTER := Vector2(135, 168) # Middle of the menu list, under the title art
const MENU_FONT_SIZE := 32
const MENU_ROW_HEIGHT := 42
const MENU_WIDTH := 150.0
const POPUP_ROW_HEIGHT := 26
const POPUP_FONT_SIZE := 20

var state := State.LOADING
var fade_tween: Tween
var menu_list: UIList
var options: OptionsMenu
var controls_hint: TutorialText # The same key hint bar as in the combat scene

# The "Play tutorial?" popup
var popup_dim: ColorRect
var popup_panel: UIPanel
var popup_title: Label
var popup_list: UIList
var popup_hint: HBoxContainer
var popup_tween: Tween

@onready var background := $Background
@onready var black := $Black

func _ready():
	set_process_unhandled_input(false)
	Music.play_title()
	MinigameCountdown.reset(true) # Every visit to the title starts a fresh session: the next player gets every countdown again, the tutorial's beetle included

	black.visible = true
	black.modulate.a = 1.0
	
	_build_menu()
	_build_popup()
	options = OptionsMenu.new()
	options.closed.connect(_on_options_closed)
	add_child(options)
	controls_hint = preload("res://Scenes/UI/TutorialText.tscn").instantiate()
	add_child(controls_hint)
	
	menu_list.modulate.a = 0.0
	await _show_title_screen()

# Play / Options / Quit as big outlined words with the shared cursor, left under the title
func _build_menu() -> void:
	menu_list = UIList.new()
	menu_list.font_size = MENU_FONT_SIZE
	menu_list.row_height = MENU_ROW_HEIGHT
	menu_list.bold = true
	menu_list.center_text = true
	menu_list.min_width = MENU_WIDTH
	menu_list.set_rows([{ "text": "Play" }, { "text": "Options" }, { "text": "Quit" }])
	menu_list.confirmed.connect(_on_menu_confirmed)
	menu_list.position = (MENU_CENTER - menu_list.size / 2.0).round()
	add_child(menu_list)

func _build_popup() -> void:
	var screen := get_viewport_rect().size
	
	popup_dim = ColorRect.new()
	popup_dim.size = screen
	popup_dim.color = Color(0, 0, 0, 0.45)
	popup_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup_dim.visible = false
	add_child(popup_dim)
	
	popup_panel = UIPanel.new()
	popup_panel.visible = false
	add_child(popup_panel)
	
	popup_title = Label.new()
	popup_title.text = "Play tutorial?"
	popup_title.add_theme_font_override("font", FONT_BOLD)
	popup_title.add_theme_font_size_override("font_size", 32)
	popup_title.add_theme_color_override("font_outline_color", Color.BLACK)
	popup_title.add_theme_constant_override("outline_size", 6)
	popup_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup_panel.add_child(popup_title)
	
	popup_list = UIList.new()
	popup_list.font_size = POPUP_FONT_SIZE
	popup_list.row_height = POPUP_ROW_HEIGHT
	popup_list.center_text = true
	popup_list.min_width = 92.0
	popup_list.set_rows([{ "text": "Yes" }, { "text": "No" }])
	popup_list.confirmed.connect(_on_popup_confirmed)
	popup_panel.add_child(popup_list)
	
	popup_hint = HBoxContainer.new()
	popup_hint.add_theme_constant_override("separation", 16)
	popup_hint.alignment = BoxContainer.ALIGNMENT_CENTER
	for pair in [["Z", "Confirm"], ["X", "Back"]]:
		var item := HBoxContainer.new()
		item.add_theme_constant_override("separation", 5)
		var icon := KeyIcon.new()
		icon.setup(pair[0], 1.5)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		item.add_child(icon)
		var word := Label.new()
		word.text = pair[1]
		word.add_theme_font_override("font", UIRow.FONT)
		word.add_theme_font_size_override("font_size", 16)
		word.add_theme_color_override("font_outline_color", Color.BLACK)
		word.add_theme_constant_override("outline_size", 4)
		item.add_child(word)
		popup_hint.add_child(item)
	popup_panel.add_child(popup_hint)
	
	# Layout: title, list, hint; the panel is centered on screen
	var title_size := popup_title.get_minimum_size()
	var hint_width := 0.0
	for item in popup_hint.get_children():
		hint_width += item.get_combined_minimum_size().x + 16.0
	hint_width -= 16.0
	var width := maxf(maxf(title_size.x, popup_list.size.x), hint_width)
	popup_title.position = Vector2.ZERO
	popup_title.size = Vector2(width, title_size.y)
	popup_list.position = Vector2((width - popup_list.size.x) / 2.0, title_size.y + 8.0)
	popup_hint.size = Vector2(width, 24.0)
	popup_hint.position = Vector2(0, popup_list.position.y + popup_list.size.y + 10.0)
	popup_panel.fit_to(Vector2(width, popup_hint.position.y + 24.0))
	var origin := popup_panel.content_origin()
	popup_title.position += origin
	popup_list.position += origin
	popup_hint.position += origin
	popup_panel.position = ((screen - popup_panel.size) / 2.0).round()
	popup_panel.pivot_offset = popup_panel.size / 2.0

func _unhandled_input(event):
	match state:
		State.MENU:
			if event.is_action_pressed("ui_down"):
				menu_list.move(1)
			elif event.is_action_pressed("ui_up"):
				menu_list.move(-1)
			elif event.is_action_pressed("ui_accept"):
				menu_list.confirm()
		State.PLAY_POPUP:
			if event.is_action_pressed("ui_down"):
				popup_list.move(1)
			elif event.is_action_pressed("ui_up"):
				popup_list.move(-1)
			elif event.is_action_pressed("ui_accept"):
				popup_list.confirm()
			elif event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
				_close_popup()

func _show_title_screen():
	await _fade_from_black(1.0)
	
	var menu_tween := create_tween()
	menu_tween.tween_property(menu_list, "modulate:a", 1.0, 0.35)
	await menu_tween.finished
	
	menu_list.select(0, false)
	state = State.MENU
	set_process_unhandled_input(true)
	controls_hint.show_hint(TutorialText.HintType.TITLE)

# MENU
func _on_menu_confirmed(index: int) -> void:
	match index:
		0:
			_open_popup()
		1:
			state = State.OPTIONS
			options.open(true)
		2:
			_quit_game()

func _on_options_closed() -> void:
	state = State.MENU

func _quit_game() -> void:
	state = State.LEAVING
	controls_hint.hide_text()
	Music.fade_out(0.8)
	await _fade_to_black(0.8)
	get_tree().quit()

# PLAY POPUP
func _open_popup() -> void:
	state = State.PLAY_POPUP
	popup_list.select(0, false)
	popup_dim.visible = true
	popup_panel.visible = true
	popup_panel.modulate.a = 0.0
	popup_panel.scale = Vector2(0.9, 0.9)
	popup_dim.modulate.a = 0.0
	if popup_tween:
		popup_tween.kill()
	popup_tween = create_tween().set_parallel()
	popup_tween.tween_property(popup_dim, "modulate:a", 1.0, 0.18)
	popup_tween.tween_property(popup_panel, "modulate:a", 1.0, 0.18)
	popup_tween.tween_property(popup_panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _close_popup() -> void:
	Sfx.play_cancel()
	state = State.MENU
	if popup_tween:
		popup_tween.kill()
	popup_tween = create_tween().set_parallel()
	popup_tween.tween_property(popup_dim, "modulate:a", 0.0, 0.15)
	popup_tween.tween_property(popup_panel, "modulate:a", 0.0, 0.15)
	await popup_tween.finished
	if state == State.MENU:
		popup_dim.visible = false
		popup_panel.visible = false

# Yes starts the tutorial (and enables the minigame countdown); No starts a free game right away
func _on_popup_confirmed(index: int) -> void:
	state = State.LEAVING
	controls_hint.hide_text()
	Music.fade_out(1.0) # The title music leaves with the fade to black
	await _fade_to_black(1.0)
	if index == 0:
		Settings.set_minigame_countdown(true) # Playing the tutorial turns the countdowns on
		get_tree().change_scene_to_file(tutorial_scene_path)
	else:
		PlayerData.reset_run()
		get_tree().change_scene_to_file(game_scene_path)

func _fade_from_black(duration := 1.0):
	black.visible = true
	black.modulate.a = 1.0
	
	if fade_tween:
		fade_tween.kill()
	
	fade_tween = create_tween()
	fade_tween.tween_property(black, "modulate:a", 0.0, duration)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)
	
	await fade_tween.finished
	black.visible = false


func _fade_to_black(duration := 0.75):
	black.visible = true
	black.modulate.a = 0.0
	
	if fade_tween:
		fade_tween.kill()
	
	fade_tween = create_tween()
	fade_tween.tween_property(black, "modulate:a", 1.0, duration)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
	
	await fade_tween.finished
