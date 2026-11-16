extends "res://scripts/mission/mission_stage.gd"
## Design Your Mission - the mission completion screen.
## Shows the mission name, the destination, every completed objective, the safe
## return and a congratulation, then offers another mission or the starting menu.
## The controller passes the mission's own summary in the config, so each of
## the three missions gets its own screen.

const TICK_EVERY := 0.28

var rows: Array = []              # {mark, label}
var revealed := 0
var _wait := 0.6
var count_label: Label
var again_btn: Button
var menu_btn: Button


func _build() -> void:
	var sky := SkyBackground.new()
	sky.size = Vector2(W, 250)
	sky.position = Vector2(0, 62)
	sky.altitude = 0.0
	root.add_child(sky)

	add_panel(Rect2(12, 66, 300, 244), Color(C_PANEL, 0.94), C_GOLD)
	var name_label := add_label(str(config["mission_name"]), 12, C_GOLD, Vector2(22, 72), 280)
	var y := name_label.position.y + maxf(name_label.size.y, 16.0) + 4.0
	add_label("Destination: " + str(config["destination"]), 9, Color.WHITE, Vector2(22, y), 280)
	y += 26.0
	add_label("Returned safely to Earth: YES", 10, C_OK, Vector2(22, y), 280)
	y += 16.0
	var seconds := int(config.get("mission_seconds", 0))
	add_label("Mission time: %d min %02d s" % [seconds / 60, seconds % 60], 9, C_DIM, Vector2(22, y), 280)
	y += 13.0
	var hits := int(config.get("hits", 0))
	add_label("Hull hits on the way home: %d" % hits if hits > 0 else "Hull hits on the way home: none", 9, C_DIM, Vector2(22, y), 280)
	y += 18.0
	var words := add_type_text(9, Color.WHITE, Vector2(22, y), 280)
	words.type(str(config["congratulations"]))

	add_panel(Rect2(322, 66, 306, 194), Color(C_PANEL, 0.94), C_BORDER)
	count_label = add_label("", 10, C_GOLD, Vector2(332, 72), 286)
	var list: Array = config["objectives"]
	var todo: Texture2D = load("res://assets/levels/check_todo.png")
	for i in list.size():
		var row_y := 92.0 + i * 22.0
		var mark := TextureRect.new()
		mark.texture = todo
		mark.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		mark.position = Vector2(334, row_y + 2)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(mark)
		var l := add_label(str(list[i]), 9, Color(0.82, 0.86, 0.92), Vector2(350, row_y - 1), 270)
		rows.append({"mark": mark, "label": l})
	again_btn = add_button(str(config["again"]), Rect2(322, 266, 148, 42), 9, choose.bind("again"))
	menu_btn = add_button(str(config["menu"]), Rect2(480, 266, 148, 42), 9, choose.bind("menu"))
	_refresh()
	sfx("confirm", -6.0)
	say("Welcome home. Every objective of this mission is complete.", true)


func _refresh() -> void:
	count_label.text = "OBJECTIVES COMPLETED %d/%d" % [revealed, rows.size()]
	progress.text = "Mission complete"


func _process(delta: float) -> void:
	super._process(delta)
	step(delta)


## Ticks the objectives one after another.
func step(delta: float) -> void:
	if revealed >= rows.size():
		return
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = TICK_EVERY
	var row: Dictionary = rows[revealed]
	row["mark"].texture = load("res://assets/levels/check_done.png")
	row["label"].add_theme_color_override("font_color", C_OK)
	revealed += 1
	sfx("tick", -10.0)
	_refresh()


## "again" starts a new mission, "menu" returns to the starting menu.
func choose(what: String) -> void:
	if completed:
		return
	outcome = {"choice": what}
	end_stage()
