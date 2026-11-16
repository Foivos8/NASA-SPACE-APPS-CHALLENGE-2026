extends CanvasLayer
## The small PAUSE / EXIT bar at the top right of a level.
##   PAUSE  freezes the whole level (timers, animations, sounds) and shows
##          RESUME and EXIT LEVEL.
##   EXIT   returns to the main menu; asks first while the level is in progress.
## Esc also pauses and resumes. This node keeps running while the game is paused.

const MENU_SCENE := "res://main_menu.tscn"
const C_PANEL := Color(0.06, 0.08, 0.13, 0.97)
const C_CARD := Color(0.14, 0.16, 0.22)
const C_BORDER := Color(0.6, 0.66, 0.74)
const C_GOLD := Color(1, 0.86, 0.3)

## Set by the level: returns true while leaving would lose progress.
var in_progress: Callable = func() -> bool: return true

var pause_button: Button
var exit_button: Button
var overlay: Control
var pause_box: Control
var confirm_box: Control
var is_paused := false
var confirming := false
var _was_paused_before_confirm := false


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	pause_button = _button("PAUSE", Vector2(520, 4), Vector2(52, 17), 8, pause)
	exit_button = _button("EXIT", Vector2(576, 4), Vector2(52, 17), 8, request_exit)
	add_child(pause_button)
	add_child(exit_button)

	overlay = Control.new()
	overlay.size = Vector2(640, 360)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP      # blocks clicks on the level underneath
	overlay.visible = false
	add_child(overlay)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.65)
	shade.size = overlay.size
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(shade)

	pause_box = _box("PAUSED", "The level is stopped. Timers and sounds are on hold.")
	pause_box.add_child(_button("RESUME", Vector2(20, 66), Vector2(100, 24), 10, resume))
	pause_box.add_child(_button("EXIT LEVEL", Vector2(140, 66), Vector2(100, 24), 10, request_exit))
	confirm_box = _box("LEAVE THIS LEVEL?", "Your progress in this level will be lost.")
	confirm_box.add_child(_button("LEAVE", Vector2(20, 66), Vector2(100, 24), 10, confirm_exit))
	confirm_box.add_child(_button("STAY", Vector2(140, 66), Vector2(100, 24), 10, cancel_exit))


func _style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_content_margin_all(2)
	return s


func _button(text: String, pos: Vector2, button_size: Vector2, font_size: int, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.clip_text = true
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_stylebox_override("normal", _style(C_CARD, C_BORDER))
	b.add_theme_stylebox_override("hover", _style(C_CARD.lightened(0.18), C_GOLD))
	b.add_theme_stylebox_override("pressed", _style(C_GOLD.darkened(0.6), C_GOLD))
	b.position = pos
	b.size = button_size
	b.pressed.connect(action)
	return b


func _box(title: String, text: String) -> Control:
	var box := Panel.new()
	box.add_theme_stylebox_override("panel", _style(C_PANEL, C_GOLD))
	box.size = Vector2(260, 104)
	box.position = Vector2(190, 120)
	box.visible = false
	overlay.add_child(box)
	for spec in [[title, 14, C_GOLD, 8.0], [text, 9, Color.WHITE, 34.0]]:
		var l := Label.new()
		l.add_theme_font_size_override("font_size", spec[1])
		l.add_theme_color_override("font_color", spec[2])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 240
		l.position = Vector2(10, spec[3])
		l.text = spec[0]
		box.add_child(l)
		l.reset_size()
	return box


func _show(box: Control) -> void:
	overlay.visible = box != null
	pause_box.visible = box == pause_box
	confirm_box.visible = box == confirm_box
	pause_button.disabled = box != null
	exit_button.disabled = box != null


func pause() -> void:
	if confirming:
		return
	is_paused = true
	get_tree().paused = true
	_show(pause_box)


func resume() -> void:
	is_paused = false
	confirming = false
	get_tree().paused = false
	_show(null)


## EXIT pressed: leave at once if nothing would be lost, otherwise ask.
func request_exit() -> void:
	if not in_progress.call():
		confirm_exit()
		return
	_was_paused_before_confirm = is_paused
	confirming = true
	get_tree().paused = true          # the level waits while the question is on screen
	_show(confirm_box)


func cancel_exit() -> void:
	confirming = false
	if _was_paused_before_confirm:
		_show(pause_box)
	else:
		resume()


## Returns to the main menu. Never quits the game.
func confirm_exit() -> void:
	confirming = false
	is_paused = false
	get_tree().paused = false
	if has_node("/root/Sfx"):
		get_node("/root/Sfx").stop_all()
	get_tree().change_scene_to_file(MENU_SCENE)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if confirming:
			cancel_exit()
		elif is_paused:
			resume()
		else:
			pause()
