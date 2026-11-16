extends RefCounted
## Small helpers shared by the main menu and the two levels.

const LEVELS_PATH := "res://data/levels.json"
const MENU_SCENE := "res://main_menu.tscn"
const LEVEL_MENU_SCENE := "res://level_menu.tscn"   # the mission board with the ten stations
const LEVEL1_SCENE := "res://main.tscn"            # the original walk-around Command Module level
const LEVEL2_SCENE := "res://level2_trajectory.tscn"


## Text and rules for one level from data/levels.json.
static func config(level_id: String) -> Dictionary:
	var all: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LEVELS_PATH))
	return all[level_id]


## Makes sure the "interact" action (E / Enter / Space) exists. The cabin level
## registers it too; this covers scenes opened straight from the menu.
static func ensure_input() -> void:
	if InputMap.has_action("interact"):
		return
	InputMap.add_action("interact")
	for key in [KEY_E, KEY_ENTER, KEY_SPACE]:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		InputMap.action_add_event("interact", ev)


## A button in the game's style. `game` is a mini-game / level built on minigame_base.gd.
static func button(game, text: String, rect: Rect2, font_size: int, action: Callable, parent: Control = null) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_stylebox_override("normal", game.make_style(game.C_CARD, game.C_BORDER))
	b.add_theme_stylebox_override("hover", game.make_style(game.C_CARD.lightened(0.15), game.C_GOLD))
	b.add_theme_stylebox_override("pressed", game.make_style(game.C_GOLD.darkened(0.6), game.C_GOLD))
	b.add_theme_stylebox_override("disabled", game.make_style(Color(0.1, 0.11, 0.14, 0.9), Color(0.25, 0.27, 0.32)))
	b.position = rect.position
	b.size = rect.size
	b.pressed.connect(action)
	(parent if parent != null else game.root).add_child(b)
	return b


## Level completion screen inside `rect`, so the finished checklist beside it
## stays visible. After this the level ends on a click or E (handled by
## minigame_base.gd, which calls dismiss()).
static func completion(game, rect: Rect2, title: String, body: String, hint: String) -> void:
	if game.completed:
		return
	game.completed = true
	game._done_at = Time.get_ticks_msec() / 1000.0
	game.sfx("confirm", -8.0)
	var box: Panel = game.add_panel(rect, Color(game.C_PANEL, 1.0), game.C_GOLD)
	var t: Label = game.add_label(title, 14, game.C_GOLD, Vector2(0, 6), rect.size.x, box)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game.done_text = game.add_type_text(9, Color.WHITE, Vector2(10, 30), rect.size.x - 20, box)
	game.done_text.chars_per_second = 110.0
	game.done_text.type(body)
	var h: Label = game.add_label(hint, 10, game.C_OK, Vector2(0, rect.size.y - 20), rect.size.x, box)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.modulate.a = 0.0
	game.create_tween().tween_property(box, "modulate:a", 1.0, 0.3)
