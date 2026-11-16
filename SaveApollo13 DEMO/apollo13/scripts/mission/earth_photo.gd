extends "res://scripts/mission/mission_stage.gd"
## Design Your Mission - photographing Earth from the repaired satellite.
## The player moves a viewfinder over Earth (mouse, or arrow keys) and takes a
## photograph (click, or E). A photograph counts when one of the listed targets
## is in the centre of the frame; each one is then shown as a small print with
## its caption, and the counter goes up.
## Text: data/missions.json -> minigames.earth_photo.

const VIEW := Rect2(12, 70, 400, 240)
const EARTH_POS := Vector2(56, -8)        # inside the view
const PIXEL := 3.0
const FRAME := Vector2(72, 54)            # the viewfinder, on screen
const AIM_RADIUS := 15.0
const KEY_SPEED := 140.0

var targets: Array = []
var taken := {}                   # target id -> true
var aim := Vector2(200, 120)      # centre of the viewfinder, in view coordinates
var shots := 0
var view: Control
var earth_tex: Texture2D
var finder: Control
var brackets: Array = []
var flash: ColorRect
var slots := {}                   # target id -> {print, label}
var count_label: Label


func _build() -> void:
	targets = config["targets"]
	view = add_view(VIEW, 1.0)
	earth_tex = load(MISSION_ART + "earth_big.png")
	add_art(MISSION_ART + "earth_big.png", EARTH_POS, PIXEL, view)
	finder = Control.new()
	finder.size = FRAME
	finder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(finder)
	for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:      # four corner brackets
		var at: Vector2 = corner * FRAME
		brackets.append(add_rect(Rect2(at.x - (14 if corner.x > 0 else 0), at.y - (2 if corner.y > 0 else 0), 14, 2), Color.WHITE, finder))
		brackets.append(add_rect(Rect2(at.x - (2 if corner.x > 0 else 0), at.y - (14 if corner.y > 0 else 0), 2, 14), Color.WHITE, finder))
	brackets.append(add_rect(Rect2(FRAME.x / 2 - 4, FRAME.y / 2, 9, 1), Color.WHITE, finder))
	brackets.append(add_rect(Rect2(FRAME.x / 2, FRAME.y / 2 - 4, 1, 9), Color.WHITE, finder))
	flash = add_rect(Rect2(Vector2.ZERO, VIEW.size), Color(1, 1, 1, 0), view)

	add_panel(Rect2(422, 70, 206, 240), C_PANEL, C_BORDER)
	count_label = add_label("", 10, C_GOLD, Vector2(430, 74), 190)
	for i in targets.size():
		var t: Dictionary = targets[i]
		var y := 96.0 + i * 70.0
		add_panel(Rect2(430, y, 78, 60), Color(0.02, 0.02, 0.05), C_BORDER)
		var print_rect := TextureRect.new()
		print_rect.position = Vector2(433, y + 3)
		print_rect.size = FRAME
		print_rect.stretch_mode = TextureRect.STRETCH_SCALE
		print_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		print_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		print_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(print_rect)
		var l := add_label("TO PHOTOGRAPH:\n" + str(t["name"]), 9, Color.WHITE, Vector2(514, y + 4), 108)
		slots[t["id"]] = {"print": print_rect, "label": l}
	_refresh()
	_place_finder()
	say(str(config["instructions"]), true)


func _refresh() -> void:
	count_label.text = "PHOTOGRAPHS %d/%d" % [taken.size(), targets.size()]
	progress.text = "Photos %d/%d" % [taken.size(), targets.size()]


func target_point(t: Dictionary) -> Vector2:
	return EARTH_POS + Vector2(float(t["at"][0]), float(t["at"][1])) * PIXEL


## The target in the centre of the frame, or "" if there is none.
func target_in_frame() -> String:
	for t in targets:
		if target_point(t).distance_to(aim) <= AIM_RADIUS:
			return t["id"]
	return ""


func _place_finder() -> void:
	aim.x = clampf(aim.x, FRAME.x / 2.0, VIEW.size.x - FRAME.x / 2.0)
	aim.y = clampf(aim.y, FRAME.y / 2.0, VIEW.size.y - FRAME.y / 2.0)
	finder.position = (aim - FRAME / 2.0).round()
	var id := target_in_frame()
	var color := Color.WHITE if id == "" else (C_GOLD if taken.has(id) else C_OK)
	for b in brackets:
		b.color = color


## Points the camera at a target (the tests use this; the player uses the mouse).
func aim_at(target_id: String) -> void:
	for t in targets:
		if t["id"] == target_id:
			aim = target_point(t)
	_place_finder()


func _pointer_move(pos: Vector2) -> void:
	if VIEW.has_point(pos):
		aim = pos - VIEW.position
		_place_finder()


func _pointer_down(pos: Vector2) -> void:
	if VIEW.has_point(pos):
		aim = pos - VIEW.position
		_place_finder()
		shoot()


func _input(event: InputEvent) -> void:
	var was_done := completed
	super._input(event)
	if not was_done and not completed and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		shoot()


func _process(delta: float) -> void:
	super._process(delta)
	flash.color.a = maxf(0.0, flash.color.a - delta * 3.0)
	if completed:
		return
	var move := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up"))
	if move != Vector2.ZERO:
		aim += move * KEY_SPEED * delta
		_place_finder()


## Takes a photograph of whatever is in the viewfinder.
func shoot() -> void:
	if completed:
		return
	shots += 1
	flash.color.a = 0.8
	sfx("shutter", -2.0)
	var id := target_in_frame()
	if id == "":
		mistakes += 1
		say(str(config["miss_text"]), false)
		return
	if taken.has(id):
		say(str(config["repeat_text"]), false)
		return
	taken[id] = true
	var region := Rect2((aim - EARTH_POS - FRAME / 2.0) / PIXEL, FRAME / PIXEL)       # the part of Earth inside the frame
	region.position.x = clampf(roundf(region.position.x), 0.0, earth_tex.get_width() - region.size.x)
	region.position.y = clampf(roundf(region.position.y), 0.0, earth_tex.get_height() - region.size.y)
	var photo := AtlasTexture.new()
	photo.atlas = earth_tex
	photo.region = region
	for t in targets:
		if t["id"] == id:
			slots[id]["print"].texture = photo
			slots[id]["label"].text = "PHOTO OF EARTH:\n" + str(t["caption"])
			slots[id]["label"].add_theme_color_override("font_color", C_OK)
			say(str(t["info"]), true)
	_refresh()
	_place_finder()
	if taken.size() == targets.size():
		complete(str(config["complete_title"]), str(config["complete_text"]))
