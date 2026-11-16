extends "res://scripts/level.gd"
## Design Your Mission - walking on the Moon or Mars.
## This is the game's own walk-around level engine (scripts/level.gd: grid
## movement, "Press E", typed dialogue, objectives, markers, mini-games) fed
## with a surface map instead of the Command Module:
##   data/mission_moon.json   5 samples, 3 landmarks, the flag, back to the lander
##   data/mission_mars.json   repair the hover vehicle, build 4 base parts, back to the lander
## On top of the engine it adds the props standing on the ground, a checklist
## with counters, and what happens when each thing is done (a sample is picked
## up, the flag rises, a build pad becomes a building, the hover vehicle flies).
## The controller (design_mission.gd) sets `level_path` before adding this node
## and waits for `finished`.

signal finished(result: Dictionary)

const Checklist := preload("res://scripts/ui/checklist_panel.gd")
const MISSIONS_PATH := "res://data/missions.json"
const MISSION_ART := "res://assets/mission/"
const RIDE_TIME := 0.09           # seconds per tile on the hover vehicle (walking is 0.14)

var props := {}                   # id -> {sprite, data}
var target_done := {}             # every target finished so far, across objectives
var checklist: Control
var notice: Label
var notice_time := 0.0
var riding := false
var ended := false


func _ready() -> void:
	minigame_data = JSON.parse_string(FileAccess.get_file_as_string(MISSIONS_PATH))["minigames"]
	super._ready()
	sfx_stop("hum")                               # no cabin fans out here
	_build_props()
	_build_checklist()
	_refresh_objective()


## The surface fills the screen, and the mission controller owns the PAUSE / EXIT bar.
func _build_sky() -> void:
	pass


func _build_top_menu() -> void:
	pass


func continue_to_next_level() -> void:
	pass


func _build_props() -> void:
	player.z_index = 2
	markers.z_index = 4
	for p in data.get("props", []):
		var s := Sprite2D.new()
		s.texture = load(MISSION_ART + str(p["sprite"]))
		s.centered = false
		s.position = _prop_position(p, s.texture)
		s.z_index = 1 if s.texture.get_height() <= int(p["size"][1]) * ts else 3     # tall things overlap the tile above
		if str(p["id"]) in ["flag_site", "crater", "rille"] or str(p["sprite"]) == "pad.png":
			s.z_index = 0
		add_child(s)
		props[p["id"]] = {"sprite": s, "data": p}
		if p.get("solid", true):
			for c in _prop_cells(p):
				blocked[c] = true


func _prop_cells(p: Dictionary) -> Array:
	var cells: Array = []
	for dy in int(p["size"][1]):
		for dx in int(p["size"][0]):
			cells.append(Vector2i(int(p["tile"][0]) + dx, int(p["tile"][1]) + dy))
	return cells


## Bottom-centre of the sprite on the bottom-centre of its tiles.
func _prop_position(p: Dictionary, tex: Texture2D) -> Vector2:
	var area := Vector2(int(p["size"][0]), int(p["size"][1])) * ts
	return Vector2(int(p["tile"][0]), int(p["tile"][1])) * ts + Vector2((area.x - tex.get_width()) / 2.0, area.y - tex.get_height())


func _build_checklist() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var list: Array = []
	for it in data.get("checklist", []):
		list.append({"id": it["id"], "text": it["text"]})
	checklist = Checklist.new()
	checklist.setup("MISSION OBJECTIVES", list, Vector2(168, 20 + list.size() * 20), 20.0)
	checklist.position = Vector2(464, 34)
	layer.add_child(checklist)
	notice = _label(10, Color(0.45, 1, 0.6))
	notice.position = Vector2(8, 52)
	layer.add_child(notice)
	_update_checklist()


func count_done(targets: Array) -> int:
	var n := 0
	for t in targets:
		if target_done.has(t):
			n += 1
	return n


func _update_checklist() -> void:
	for it in data.get("checklist", []):
		var targets: Array = it["targets"]
		var n := count_done(targets)
		if targets.size() > 1:
			checklist.rows[it["id"]]["label"].text = "%s  %d/%d" % [it["text"], n, targets.size()]
		if n == targets.size():
			checklist.complete(it["id"])


func _checklist_item(target: String) -> Dictionary:
	for it in data.get("checklist", []):
		if target in it["targets"]:
			return it
	return {}


func show_notice(text: String) -> void:
	notice.text = text
	notice.modulate.a = 1.0
	notice_time = 4.0


func _process(delta: float) -> void:
	super._process(delta)
	if notice_time > 0.0:
		notice_time -= delta
		notice.modulate.a = clampf(notice_time, 0.0, 1.0)


func _refresh_objective() -> void:
	super._refresh_objective()
	if objective_index >= data["objectives"].size():
		ui_objective.text = "Surface work complete"


## The hover vehicle makes no footsteps.
func _update_footsteps(delta: float) -> void:
	if riding:
		sfx_stop("footsteps")
		return
	super._update_footsteps(delta)


func _complete_target(target: String) -> void:
	target_done[target] = true
	_target_effect(target)
	_update_checklist()
	super._complete_target(target)
	if objective_index >= data["objectives"].size() and not ended:
		_end()


func _objective_finished(id: String) -> void:
	super._objective_finished(id)
	match id:
		"surface":
			show_notice("All surface work done. Return to the lander.")
		"base":
			show_notice("The research base is complete. Return to the lander.")


func _end() -> void:
	ended = true
	frozen = true
	level_complete = true
	sfx_stop("footsteps")
	await get_tree().create_timer(0.7, false).timeout
	finished.emit({"id": "surface", "targets": target_done.size()})


# ------------------------------------------------- what each target does ----

func _target_effect(target: String) -> void:
	var item := _checklist_item(target)
	var n := count_done(item.get("targets", []))
	var total: int = item.get("targets", []).size()
	if target.begins_with("sample_"):
		_collect_sample(target)
		show_notice("Sample %d/%d stowed: %s" % [n, total, str(interactables[target]["name"]).trim_prefix("Sample: ")])
	elif target == "flag_site":
		_plant_flag()
		show_notice("The Earth flag is planted!")
	elif target == "hover":
		_repair_hover()
	elif target.begins_with("site_"):
		_build_site(target)
		show_notice("Base part %d/%d built: %s" % [n, total, str(interactables[target]["name"]).trim_prefix("Build site: ")])
	elif item.get("id", "") == "landmarks":
		sfx("confirm", -12.0, 0.0, 0.0, true)
		show_notice("Landmark %d/%d explored" % [n, total])


## Takes a prop off the map: it can be walked over and no longer interacted with.
func _clear_prop(id: String, free_sprite := true) -> void:
	var p: Dictionary = props[id]
	for c in _prop_cells(p["data"]):
		blocked.erase(c)
		tile_to_interactable.erase(c)
	if free_sprite:
		p["sprite"].queue_free()
	props.erase(id)


func _collect_sample(id: String) -> void:
	sfx("collect", -6.0, 0.0, 0.0, true)
	var s: Sprite2D = props[id]["sprite"]
	_clear_prop(id, false)
	s.z_index = 5
	var tw := s.create_tween()                      # the rock lifts off the ground and vanishes into the sample bag
	tw.set_parallel(true)
	tw.tween_property(s, "position:y", s.position.y - 22, 0.5)
	tw.tween_property(s, "modulate:a", 0.0, 0.5)
	tw.set_parallel(false)
	tw.tween_callback(s.queue_free)


func _plant_flag() -> void:
	sfx("latch", -6.0, 0.0, 0.0, true)
	props["flag_site"]["sprite"].queue_free()
	var tile: Array = props["flag_site"]["data"]["tile"]
	var flag := Sprite2D.new()
	flag.texture = load(MISSION_ART + "flag.png")
	flag.centered = false
	flag.z_index = 3
	var base_y := (int(tile[1]) + 1) * ts           # the foot of the pole
	flag.position = Vector2(int(tile[0]) * ts, base_y)
	flag.scale = Vector2(1, 0)
	add_child(flag)
	props["flag_site"]["sprite"] = flag
	var h := float(flag.texture.get_height())
	var tw := flag.create_tween()                   # the pole rises out of the ground, then the flag settles
	tw.set_parallel(true)
	tw.tween_property(flag, "scale:y", 1.0, 0.9).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(flag, "position:y", base_y - h, 0.9).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.set_parallel(false)
	for dx in [2.0, -2.0, 1.0, 0.0]:
		tw.tween_property(flag, "skew", dx * 0.03, 0.15)
	var it: Dictionary = interactables["flag_site"]
	it["name"] = "Earth flag"
	it["steps"]["default"] = {"title": "Earth flag", "pages": [
		"The Earth flag stands on the Moon. It shows the whole planet, because you came here for everyone on it."]}


func _repair_hover() -> void:
	var p: Dictionary = props["hover"]
	p["sprite"].texture = load(MISSION_ART + "hover_fixed.png")
	show_notice("Hover vehicle repaired. Climbing aboard...")
	frozen = true
	var s: Sprite2D = p["sprite"]
	var tw := s.create_tween()                      # it lifts off the ground and bobs, then the astronaut boards
	tw.tween_property(s, "position:y", s.position.y - 4, 0.35)
	tw.tween_property(s, "position:y", s.position.y, 0.35)
	tw.tween_property(s, "position:y", s.position.y - 4, 0.35)
	tw.tween_callback(_board_hover)


func _board_hover() -> void:
	_clear_prop("hover")
	riding = true
	move_time = RIDE_TIME
	player.texture = load(MISSION_ART + "hover_ride.png")
	_face(facing)
	frozen = ended
	sfx("thruster", -8.0, 0.0, 0.0, true)
	show_notice("You are riding the hover vehicle: faster, and it carries the base parts.")


func _build_site(id: String) -> void:
	sfx("build", -4.0, 0.0, 0.0, true)
	var p: Dictionary = props[id]
	var s: Sprite2D = p["sprite"]
	s.texture = load(MISSION_ART + str(p["data"]["built"]))
	s.position = _prop_position(p["data"], s.texture)
	s.z_index = 1
	var rest := s.position
	s.scale = Vector2(1, 0.2)                       # the building rises from its pad
	s.position.y = rest.y + s.texture.get_height() * 0.8
	var tw := s.create_tween()
	tw.set_parallel(true)
	tw.tween_property(s, "scale:y", 1.0, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "position:y", rest.y, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var it: Dictionary = interactables[id]
	it["name"] = str(it["name"]).trim_prefix("Build site: ")
	it["steps"]["default"] = it["steps"]["built"]
