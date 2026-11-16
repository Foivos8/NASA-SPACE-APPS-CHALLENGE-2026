extends "res://scripts/mission/mission_stage.gd"
## Design Your Mission - an interactive repair (the Mars hover vehicle, the satellite).
## The picture shows the damaged machine. The player finds each fault by
## clicking the damaged part, reads what is wrong, and picks the repair that
## fixes it. When every fault is fixed the picture changes to the working machine.
## Text: data/missions.json -> minigames.hover_repair / satellite_repair.

const VIEW := Rect2(12, 70, 400, 240)
const REPAIR_TIME := 1.2

var faults: Array = []
var fixed := {}
var selected := ""
var repairing := false
var repair_t := 0.0
var zones := {}                   # fault id -> {rect, outline, tick}
var tool_buttons := {}            # tool id -> Button
var machine: TextureRect
var problem: RichTextLabel
var bar_fill: ColorRect
var count_label: Label


func _build() -> void:
	faults = config["faults"]
	var view := add_view(VIEW, 1.0)
	if config.has("backdrop"):
		add_rect(Rect2(Vector2.ZERO, VIEW.size), color_of(config["backdrop"], C_BG), view)
		add_rect(Rect2(0, VIEW.size.y - 50, VIEW.size.x, 50), color_of(config["backdrop"], C_BG).darkened(0.25), view)
	var pixel := float(config["scale"])
	var tex: Texture2D = load(str(config["image_broken"]))
	var origin := ((VIEW.size - tex.get_size() * pixel) / 2.0).round()
	machine = add_art(str(config["image_broken"]), origin, pixel, view)
	for f in faults:
		var r: Array = f["rect"]
		var rect := Rect2(VIEW.position + origin + Vector2(float(r[0]), float(r[1])) * pixel, Vector2(float(r[2]), float(r[3])) * pixel)
		var outline := Panel.new()
		outline.position = rect.position - Vector2(2, 2)
		outline.size = rect.size + Vector2(4, 4)
		outline.add_theme_stylebox_override("panel", make_style(Color(1, 0.86, 0.3, 0.12), C_GOLD))
		outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		outline.visible = false
		root.add_child(outline)
		var tick := TextureRect.new()
		tick.texture = load("res://assets/levels/check_done.png")
		tick.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tick.scale = Vector2(2, 2)
		tick.position = rect.get_center() - Vector2(9, 9)
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tick.visible = false
		root.add_child(tick)
		zones[f["id"]] = {"rect": rect, "outline": outline, "tick": tick}

	add_panel(Rect2(422, 70, 206, 240), C_PANEL, C_BORDER)
	count_label = add_label("", 10, C_GOLD, Vector2(430, 74), 190)
	problem = add_type_text(9, Color.WHITE, Vector2(430, 92), 190)
	problem.type("Move the pointer over the machine and click a damaged part.")
	var tools: Array = config["tools"]
	for i in tools.size():
		var t: Dictionary = tools[i]
		var b := add_button(str(t["label"]), Rect2(430, 160 + i * 33.0, 190, 30), 9, use_tool.bind(str(t["id"])))
		b.disabled = true
		tool_buttons[t["id"]] = b
	add_rect(Rect2(430, 296, 190, 8), Color(0.1, 0.11, 0.14))
	bar_fill = add_rect(Rect2(431, 297, 0, 6), C_OK)
	_refresh()


func _refresh() -> void:
	count_label.text = "FAULTS FIXED %d/%d" % [fixed.size(), faults.size()]
	progress.text = "Repairs %d/%d" % [fixed.size(), faults.size()]
	for id in tool_buttons:
		tool_buttons[id].disabled = selected == "" or repairing


func _fault(id: String) -> Dictionary:
	for f in faults:
		if f["id"] == id:
			return f
	return {}


func _fault_at(pos: Vector2) -> String:
	for id in zones:
		if zones[id]["rect"].grow(3).has_point(pos):
			return id
	return ""


func _pointer_move(pos: Vector2) -> void:
	var over := _fault_at(pos)
	for id in zones:
		zones[id]["outline"].visible = not fixed.has(id) and (id == over or id == selected)


func _pointer_down(pos: Vector2) -> void:
	if repairing or not VIEW.has_point(pos):
		return
	var id := _fault_at(pos)
	if id == "":
		sfx("error", -14.0)
		say(str(config["miss_text"]), false)
	elif fixed.has(id):
		say("Already fixed: " + str(_fault(id)["fixed"]), true)
	else:
		select_fault(id)


## Picks a fault to work on (the player does this by clicking the damaged part).
func select_fault(id: String) -> void:
	if repairing or fixed.has(id) or not zones.has(id):
		return
	selected = id
	var f := _fault(id)
	sfx("click", -8.0)
	problem.type("FAULT FOUND: %s.\n%s\nChoose the repair." % [f["name"], f["problem"]])
	for key in zones:
		zones[key]["outline"].visible = key == id
	_refresh()


func use_tool(tool_id: String) -> void:
	if repairing or selected == "":
		return
	if str(_fault(selected)["tool"]) != tool_id:
		mistakes += 1
		sfx("error", -8.0)
		say(str(config["wrong_tool"]), false)
		return
	repairing = true
	repair_t = 0.0
	sfx("build", -4.0)
	_refresh()


func _process(delta: float) -> void:
	super._process(delta)
	step(delta)


## Advances a running repair; the tests call this directly.
func step(delta: float) -> void:
	if not repairing:
		return
	repair_t += delta
	bar_fill.size.x = 188.0 * clampf(repair_t / REPAIR_TIME, 0.0, 1.0)
	if repair_t < REPAIR_TIME:
		return
	repairing = false
	bar_fill.size.x = 0.0
	fixed[selected] = true
	var z: Dictionary = zones[selected]
	z["outline"].visible = false
	z["tick"].visible = true
	say(str(_fault(selected)["fixed"]), true)
	sfx("confirm", -10.0)
	selected = ""
	problem.type("Fixed. Look for the next damaged part." if fixed.size() < faults.size() else "All faults fixed.")
	_refresh()
	if fixed.size() == faults.size():
		machine.texture = load(str(config["image_fixed"]))        # the machine is whole again
		for id in zones:
			zones[id]["tick"].visible = false
		complete(str(config["complete_title"]), str(config["complete_text"]))
