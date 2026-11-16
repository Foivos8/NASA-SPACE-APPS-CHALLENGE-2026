extends Control
## Main menu: APOLLO 13. This is the scene the game starts in.
##   START GAME           the original Apollo 13 mode: the mission map, from which both levels are started
##   DESIGN YOUR MISSION  the second mode: launch, choose the Moon, Mars or a satellite, and fly home
##   QUIT GAME

const LevelUI := preload("res://scripts/ui/level_ui.gd")
const SkyBackground := preload("res://scripts/ui/sky_background.gd")
const DESIGN_MISSION_SCENE := "res://design_mission.tscn"
const C_PANEL := Color(0.06, 0.08, 0.13, 0.9)
const C_CARD := Color(0.10, 0.13, 0.20, 0.94)
const C_BORDER := Color(0.6, 0.66, 0.74)
const C_GOLD := Color(1, 0.86, 0.3)

var buttons: Array = []
var title: Label
var _time := 0.0


func _ready() -> void:
	get_tree().paused = false
	get_tree().root.content_scale_size = Vector2i(640, 360)     # in case we came back from the level menu
	size = Vector2(640, 360)
	var sky := SkyBackground.new()
	sky.size = Vector2(640, 360)
	add_child(sky)
	_rect(Rect2(0, 318, 640, 12), Color(0.25, 0.47, 0.72))            # sea
	_rect(Rect2(0, 326, 640, 34), Color(0.36, 0.42, 0.34))            # ground
	_rect(Rect2(456, 320, 150, 8), Color(0.5, 0.52, 0.56))            # pad
	_sprite("res://assets/minigames/launch_tower.png", Vector2(540, 114), 2.0)
	_sprite("res://assets/minigames/saturn_v.png", Vector2(488, 130), 2.0)

	title = _label("APOLLO 13", 44, C_GOLD, Vector2(40, 38))
	title.add_theme_constant_override("outline_size", 10)
	_label("An educational space mission game", 11, Color.WHITE, Vector2(44, 98))

	var entries := [
		["START GAME - MISSION MAP", open_level_menu],
		["DESIGN YOUR MISSION", open_design_mission],
		["QUIT GAME", quit_game],
	]
	for i in entries.size():
		var b := _button(entries[i][0], Vector2(40, 150 + i * 46), entries[i][1])
		buttons.append(b)
	_label("Mouse: click a button.   In a level: Esc pauses.", 9, Color(0.9, 0.94, 1), Vector2(44, 296))


func _process(delta: float) -> void:
	_time += delta
	title.position.y = 38.0 + roundf(sin(_time * 1.6) * 2.0)          # gentle bob, whole pixels


func _rect(r: Rect2, c: Color) -> void:
	var cr := ColorRect.new()
	cr.color = c
	cr.position = r.position
	cr.size = r.size
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cr)


func _sprite(path: String, pos: Vector2, pixel_scale: float) -> void:
	var t := TextureRect.new()
	t.texture = load(path)
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.position = pos
	t.size = t.texture.get_size() * pixel_scale
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(t)


func _label(text: String, font_size: int, color: Color, pos: Vector2) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.04, 0.05, 0.09))
	l.add_theme_constant_override("outline_size", 4)
	l.position = pos
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.text = text
	add_child(l)
	return l


func _style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.content_margin_left = 14
	return s


func _button(text: String, pos: Vector2, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_ALL                       # arrow keys + Enter also work
	b.add_theme_font_size_override("font_size", 12)
	b.add_theme_color_override("font_hover_color", C_GOLD)
	b.add_theme_color_override("font_focus_color", C_GOLD)
	b.add_theme_stylebox_override("normal", _style(C_CARD, C_BORDER))
	b.add_theme_stylebox_override("hover", _style(C_CARD.lightened(0.12), C_GOLD))
	b.add_theme_stylebox_override("focus", _style(Color(0, 0, 0, 0), C_GOLD))
	b.add_theme_stylebox_override("pressed", _style(C_GOLD.darkened(0.6), C_GOLD))
	b.position = pos
	b.size = Vector2(330, 36)
	b.pressed.connect(_click)
	b.pressed.connect(action)
	# hover / focus feedback: the button slides right a little
	b.mouse_entered.connect(_nudge.bind(b, pos.x + 8.0))
	b.mouse_exited.connect(_nudge.bind(b, pos.x))
	b.focus_entered.connect(_nudge.bind(b, pos.x + 8.0))
	b.focus_exited.connect(_nudge.bind(b, pos.x))
	add_child(b)
	return b


func _click() -> void:
	var manager := get_node_or_null("/root/Sfx")
	if manager != null:
		manager.play("click", -10.0, 0.0, 0.0, true)


func _nudge(b: Button, x: float) -> void:
	create_tween().tween_property(b, "position:x", x, 0.1)


## The first button: the mission board, from which Level 1 and Level 2 are started.
func open_level_menu() -> void:
	get_tree().change_scene_to_file(LevelUI.LEVEL_MENU_SCENE)


## The second button: the "Design Your Mission" mode.
func open_design_mission() -> void:
	get_tree().change_scene_to_file(DESIGN_MISSION_SCENE)


func quit_game() -> void:
	get_tree().quit()
