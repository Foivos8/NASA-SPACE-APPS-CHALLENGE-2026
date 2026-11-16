extends "res://scripts/minigames/minigame_base.gd"
## Shared base for the screens of the "Design Your Mission" mode.
## It is the game's mini-game frame (title, instructions, typed information
## strip, completion screen) plus a few helpers the mission screens share.
## A screen ends with `finished`, carrying whatever it put in `outcome`.

const LevelUI := preload("res://scripts/ui/level_ui.gd")
const SkyBackground := preload("res://scripts/ui/sky_background.gd")
const MISSION_ART := "res://assets/mission/"

var outcome := {}                 # extra values returned with `finished`


## Registers the movement and interact keys (the cabin level does the same).
static func ensure_input() -> void:
	var map := {
		"move_up": [KEY_UP, KEY_W], "move_down": [KEY_DOWN, KEY_S],
		"move_left": [KEY_LEFT, KEY_A], "move_right": [KEY_RIGHT, KEY_D],
		"interact": [KEY_E, KEY_ENTER, KEY_SPACE],
	}
	for action in map:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			for key in map[action]:
				var ev := InputEventKey.new()
				ev.physical_keycode = key
				InputMap.action_add_event(action, ev)


func _ready() -> void:
	ensure_input()
	super._ready()
	progress.position.x = 310.0           # keeps the counter clear of PAUSE / EXIT
	progress.size.x = 200.0


## An image from any folder, drawn with crisp pixels.
func add_art(path: String, pos: Vector2, pixel_scale := 2.0, parent: Control = null) -> TextureRect:
	var t := TextureRect.new()
	t.texture = load(path)
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.position = pos
	t.size = t.texture.get_size() * pixel_scale
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else root).add_child(t)
	return t


func add_rect(rect: Rect2, color: Color, parent: Control = null) -> ColorRect:
	var c := ColorRect.new()
	c.color = color
	c.position = rect.position
	c.size = rect.size
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else root).add_child(c)
	return c


## A clipped window onto a scene, with a starry sky (altitude 1) or blue sky (0) behind it.
func add_view(rect: Rect2, altitude := 1.0) -> Control:
	var view := Control.new()
	view.position = rect.position
	view.size = rect.size
	view.clip_contents = true
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(view)
	var sky := SkyBackground.new()
	sky.name = "Sky"
	sky.size = rect.size
	sky.altitude = altitude
	view.add_child(sky)
	var frame := Panel.new()                  # border drawn over the scene
	frame.position = rect.position - Vector2(2, 2)
	frame.size = rect.size + Vector2(4, 4)
	frame.add_theme_stylebox_override("panel", make_style(Color(0, 0, 0, 0), C_BORDER))
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(frame)
	return view


func add_button(text: String, rect: Rect2, font_size: int, action: Callable, parent: Control = null) -> Button:
	return LevelUI.button(self, text, rect, font_size, action, parent)


func color_of(list: Array, fallback: Color) -> Color:
	if list.size() < 3:
		return fallback
	return Color(float(list[0]) / 255.0, float(list[1]) / 255.0, float(list[2]) / 255.0)


func sfx_fade(key: String, seconds: float) -> void:
	var manager := get_node_or_null("/root/Sfx")
	if manager != null:
		manager.fade_out(key, seconds)


func sfx_stop(key: String) -> void:
	var manager := get_node_or_null("/root/Sfx")
	if manager != null:
		manager.stop(key)


## Ends the screen at once (used by screens that do not show the completion box).
func end_stage() -> void:
	completed = true
	dismiss()


func dismiss() -> void:
	var result := {"id": game_id, "seconds": elapsed, "mistakes": mistakes}
	result.merge(outcome, true)
	finished.emit(result)
	queue_free()
