extends CanvasLayer
## Shared frame for the Apollo 13 mini-games.
## A mini-game is a full-screen overlay added by level.gd. It reads its text and
## rules from data/minigames.json, and emits `finished` when the player closes
## the completion screen. Mouse: left button. E / Enter / Space also closes the
## completion screen.

signal finished(result: Dictionary)

const W := 640
const H := 360
const ART := "res://assets/minigames/"
const TypeText := preload("res://scripts/ui/type_text.gd")
const C_BG := Color(0.051, 0.067, 0.11)
const C_PANEL := Color(0.06, 0.08, 0.13, 0.96)
const C_CARD := Color(0.14, 0.16, 0.22)
const C_BORDER := Color(0.6, 0.66, 0.74)
const C_GOLD := Color(1, 0.86, 0.3)
const C_OK := Color(0.45, 1, 0.6)
const C_BAD := Color(1, 0.55, 0.5)
const C_DIM := Color(0.75, 0.85, 1)

var game_id := ""
var config: Dictionary = {}
var root: Control
var feedback: RichTextLabel     # TypeText: the information strip, typed letter by letter
var done_text: RichTextLabel    # TypeText on the completion screen
var progress: Label
var elapsed := 0.0
var mistakes := 0
var completed := false
var _done_at := -1.0


func setup(id: String, cfg: Dictionary) -> void:
	game_id = id
	config = cfg


func _ready() -> void:
	layer = 10
	root = Control.new()
	root.size = Vector2(W, H)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var bg := ColorRect.new()
	bg.color = C_BG
	bg.size = Vector2(W, H)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)
	add_label(str(config.get("title", "")), 14, C_GOLD, Vector2(12, 6), 400)
	add_label(str(config.get("scene", "")), 9, C_DIM, Vector2(12, 26), 616)
	var ins := add_label(str(config.get("instructions", "")), 10, Color.WHITE, Vector2(12, 40), 616)
	ins.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	progress = add_label("", 11, C_GOLD, Vector2(430, 8), 198)
	progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_panel(Rect2(12, 314, 616, 40), C_PANEL, C_BORDER)
	feedback = add_type_text(10, Color.WHITE, Vector2(20, 318), 600)
	feedback.chars_per_second = 70.0          # quick: this strip reacts to what the player just did
	_build()


## Override: create the mini-game's own nodes under `root`.
func _build() -> void:
	pass


func _process(delta: float) -> void:
	if not completed:
		elapsed += delta


# ---------------------------------------------------------------- input ----

func _input(event: InputEvent) -> void:
	if completed:
		var click: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
		var key: bool = InputMap.has_action("interact") and event.is_action_pressed("interact")
		if (click or key) and done_text != null and done_text.is_typing():
			get_viewport().set_input_as_handled()
			done_text.finish()                    # first press shows the whole text, the next one continues
			return
		if (click or key) and _done_at >= 0.0 \
				and Time.get_ticks_msec() / 1000.0 - _done_at > 0.6:
			get_viewport().set_input_as_handled()
			dismiss()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pointer_down(event.position)
		else:
			_pointer_up(event.position)
	elif event is InputEventMouseMotion:
		_pointer_move(event.position)


func _pointer_down(_pos: Vector2) -> void:
	pass


func _pointer_up(_pos: Vector2) -> void:
	pass


func _pointer_move(_pos: Vector2) -> void:
	pass


# -------------------------------------------------------------- helpers ----

func add_label(text: String, font_size: int, color: Color, pos: Vector2, width := 0.0, parent: Control = null) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.04, 0.05, 0.09))
	l.add_theme_constant_override("outline_size", 4)
	l.position = pos
	if width > 0.0:                      # fixed width: wrap instead of running off the screen
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = width
		l.size.x = width
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.text = text                       # set after the font size so the label measures itself correctly
	(parent if parent != null else root).add_child(l)
	l.reset_size()
	return l


## Text that types itself out, with highlights (see scripts/ui/type_text.gd).
func add_type_text(font_size: int, color: Color, pos: Vector2, width: float, parent: Control = null) -> RichTextLabel:
	var t := TypeText.new()
	t.style(font_size, color, width)
	t.position = pos
	(parent if parent != null else root).add_child(t)
	return t


func make_style(bg: Color, border: Color, border_width := 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_width)
	s.set_content_margin_all(6)
	return s


func add_panel(rect: Rect2, bg: Color, border: Color, parent: Control = null) -> Panel:
	var p := Panel.new()
	p.position = rect.position
	p.size = rect.size
	p.add_theme_stylebox_override("panel", make_style(bg, border))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else root).add_child(p)
	return p


func add_sprite(file: String, pos: Vector2, pixel_scale := 2.0, parent: Control = null) -> TextureRect:
	var t := TextureRect.new()
	t.texture = load(ART + file)
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.position = pos
	t.size = t.texture.get_size() * pixel_scale
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else root).add_child(t)
	return t


## A card with an icon and a caption. Returns {panel, icon, label, rect, home}.
func add_card(rect: Rect2, icon_file: String, caption: String) -> Dictionary:
	var p := add_panel(rect, C_CARD, C_BORDER)
	var card := {"panel": p, "rect": rect, "home": rect.position, "label": null, "icon": null}
	var text_x := 8.0
	if icon_file != "":
		card["icon"] = add_sprite(icon_file, Vector2(6, (rect.size.y - 48) / 2.0), 2.0, p)
		text_x = 60.0
	var l := add_label(caption, 10, Color.WHITE, Vector2(text_x, 6), rect.size.x - text_x - 6, p)
	l.size.y = rect.size.y - 12
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card["label"] = l
	return card


func paint_card(card: Dictionary, bg: Color, border: Color) -> void:
	card["panel"].add_theme_stylebox_override("panel", make_style(bg, border))


## Short colour flash on a card, then back to the given resting colours.
func flash_card(card: Dictionary, color: Color, rest_bg := C_CARD, rest_border := C_BORDER) -> void:
	paint_card(card, color.darkened(0.6), color)
	var p: Panel = card["panel"]
	var x := float(card["home"].x)
	var tw := create_tween()
	for dx in [5.0, -5.0, 3.0, 0.0]:
		tw.tween_property(p, "position:x", x + dx, 0.05)
	tw.tween_callback(func(): paint_card(card, rest_bg, rest_border))


func say(text: String, ok: bool) -> void:
	feedback.set_base_color(C_OK if ok else C_BAD)
	feedback.type(text)
	feedback.modulate.a = 0.3
	create_tween().tween_property(feedback, "modulate:a", 1.0, 0.2)


## Plays a sound effect through the Sfx autoload, if the project has one.
func sfx(key: String, volume_db := 0.0, from := 0.0, duration := 0.0, restart := true) -> void:
	var manager := get_node_or_null("/root/Sfx")
	if manager != null:
		manager.play(key, volume_db, from, duration, restart)


func time_text() -> String:
	return "%d s" % int(round(elapsed))


## Shows the completion screen. The mini-game ends when the player dismisses it.
func complete(title: String, body: String) -> void:
	if completed:
		return
	completed = true
	_done_at = Time.get_ticks_msec() / 1000.0
	sfx("confirm", -8.0)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.size = Vector2(W, H)
	root.add_child(shade)
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", make_style(C_PANEL, C_GOLD))
	box.position = Vector2(60, 40)
	box.custom_minimum_size = Vector2(520, 0)
	root.add_child(box)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	box.add_child(vb)
	var t := add_label(title, 14, C_GOLD, Vector2.ZERO, 0, vb)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	done_text = add_type_text(10, Color.WHITE, Vector2.ZERO, 500, vb)
	done_text.chars_per_second = 110.0
	done_text.type(body)
	var hint := add_label("Click or press E to continue", 10, C_OK, Vector2.ZERO, 0, vb)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.modulate.a = 0.0
	create_tween().tween_property(box, "modulate:a", 1.0, 0.25)


func dismiss() -> void:
	finished.emit({"id": game_id, "seconds": elapsed, "mistakes": mistakes})
	queue_free()
