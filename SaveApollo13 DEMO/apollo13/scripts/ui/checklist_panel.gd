extends Control
## A level checklist: green ticks for finished tasks, a highlighted current
## task, and the remaining tasks still visible. Tasks are ticked in any order
## with complete(id); the "current" task is always the first unfinished one.

signal all_completed

const ROW_FONT := 8
const C_PANEL := Color(0.06, 0.08, 0.13, 0.92)
const C_BORDER := Color(0.6, 0.66, 0.74)
const C_GOLD := Color(1, 0.86, 0.3)
const C_OK := Color(0.45, 1, 0.6)
const C_TODO := Color(0.82, 0.86, 0.92)

var items: Array = []          # [{id, text}]
var done := {}
var rows := {}                 # id -> {mark, label, glow}
var header: Label
var row_height := 22.0
var _tex := {}


## `list` is an Array of {"id": String, "text": String}.
func setup(title: String, list: Array, panel_size: Vector2, row_h := 22.0) -> void:
	items = list
	size = panel_size
	row_height = row_h
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for k in ["done", "now", "todo"]:
		_tex[k] = load("res://assets/levels/check_%s.png" % k)
	var bg := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = C_PANEL
	style.border_color = C_BORDER
	style.set_border_width_all(2)
	bg.add_theme_stylebox_override("panel", style)
	bg.size = panel_size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	header = _label(title, 9, C_GOLD)
	header.position = Vector2(8, 3)
	add_child(header)
	for i in items.size():
		var it: Dictionary = items[i]
		var y := 18.0 + i * row_height
		var glow := ColorRect.new()
		glow.color = Color(1, 0.86, 0.3, 0.16)
		glow.position = Vector2(3, y - 1)
		glow.size = Vector2(panel_size.x - 6, row_height - 1)
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(glow)
		var mark := TextureRect.new()
		mark.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		mark.position = Vector2(7, y + 1)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(mark)
		var l := _label(str(it["text"]), ROW_FONT, C_TODO)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = panel_size.x - 26
		l.add_theme_constant_override("line_spacing", -2)
		l.position = Vector2(20, y - 2)
		add_child(l)
		l.reset_size()
		rows[it["id"]] = {"mark": mark, "label": l, "glow": glow}
	_refresh()


func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.04, 0.05, 0.09))
	l.add_theme_constant_override("outline_size", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.text = text
	return l


func current_id() -> String:
	for it in items:
		if not done.has(it["id"]):
			return it["id"]
	return ""


func is_done(id: String) -> bool:
	return done.has(id)


func done_count() -> int:
	return done.size()


func all_done() -> bool:
	return done.size() == items.size()


## Ticks a task. Returns false if the id is unknown or already ticked.
func complete(id: String) -> bool:
	if not rows.has(id) or done.has(id):
		return false
	done[id] = true
	var mark: TextureRect = rows[id]["mark"]
	mark.pivot_offset = Vector2(4.5, 4.5)
	mark.scale = Vector2(2.2, 2.2)
	create_tween().tween_property(mark, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_refresh()
	if all_done():
		all_completed.emit()
	return true


func _refresh() -> void:
	var now := current_id()
	for it in items:
		var id: String = it["id"]
		var row: Dictionary = rows[id]
		var state := "done" if done.has(id) else ("now" if id == now else "todo")
		row["mark"].texture = _tex[state]
		row["glow"].visible = state == "now"
		row["label"].add_theme_color_override("font_color", C_OK if state == "done" else (C_GOLD if state == "now" else C_TODO))
	if header != null and all_done():
		header.text = "CHECKLIST COMPLETE"
		header.add_theme_color_override("font_color", C_OK)
