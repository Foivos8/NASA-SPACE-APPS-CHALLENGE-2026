extends Node
## "Design Your Mission" - the second game mode, opened from the main menu.
## This node runs one mission from start to finish by playing its screens one
## after another and waiting for each to end:
##
##   launch -> choose destination -> arrival -> the mission itself -> departure
##          -> playable flight home -> Earth landing -> completion screen
##
## The mission itself depends on the destination, and the three never mix:
##   moon       walk the surface: 5 samples, 3 landmarks, the flag      (surface_level.gd)
##   mars       walk the surface: repair the hover vehicle, build 4 base parts
##   satellite  repair 3 faults, then photograph Earth 3 times          (repair_task.gd, earth_photo.gd)
## A screen can only end by being completed, so no objective can be skipped.
## Everything the screens say comes from data/missions.json.
## These missions are imagined. The real Apollo 13 story is the original mode.

const MissionStage := preload("res://scripts/mission/mission_stage.gd")
const TopMenu := preload("res://scripts/ui/top_menu.gd")
const MISSIONS_PATH := "res://data/missions.json"
const SURFACE_SCRIPT := "res://scripts/mission/surface_level.gd"
const MENU_SCENE := "res://main_menu.tscn"

var cfg: Dictionary = {}
var top_menu: CanvasLayer
var phase_label: Label
var phase_boxes: Array = []
var phase := 0                    # index into cfg["phases"]
var stage: Node                   # the screen being played
var stage_name := ""
var destination := ""             # "", then moon / mars / satellite
var mission: Dictionary = {}
var mission_seconds := 0.0
var missions_completed := 0
var last_result: Dictionary = {}


func _ready() -> void:
	get_tree().paused = false
	get_tree().root.content_scale_size = Vector2i(640, 360)
	MissionStage.ensure_input()
	cfg = JSON.parse_string(FileAccess.get_file_as_string(MISSIONS_PATH))
	top_menu = TopMenu.new()
	top_menu.in_progress = func() -> bool: return stage_name != "summary"
	add_child(top_menu)
	_build_phase_bar()
	run()


func _process(delta: float) -> void:
	if stage_name != "summary":
		mission_seconds += delta


## Mission after mission, until the player asks for the starting menu.
func run() -> void:
	while true:
		var choice := await fly_mission()
		if choice != "again":
			break
	return_to_menu()


func return_to_menu() -> void:
	_stop_sounds()
	get_tree().change_scene_to_file(MENU_SCENE)


## One whole mission. Returns "again" or "menu" (the choice on the completion screen).
func fly_mission() -> String:
	destination = ""
	mission = {}
	mission_seconds = 0.0
	_stop_sounds()

	_set_phase(0)
	await play("launch", cfg["launch"])

	_set_phase(1)
	var pick: Dictionary = cfg["destination"].duplicate()
	pick["briefings"] = {}
	for id in cfg["missions"]:
		pick["briefings"][id] = cfg["missions"][id]["briefing"]
	var chosen: Dictionary = await play("destination", pick)
	destination = str(chosen["destination"])
	mission = cfg["missions"][destination]
	await play("arrive", _transit(mission["arrive"]))

	_set_phase(2)
	if destination == "satellite":
		await play("satellite_repair", cfg["minigames"]["satellite_repair"])
		await play("earth_photo", cfg["minigames"]["earth_photo"])
	else:
		await play_surface(str(mission["surface"]))

	_set_phase(3)
	await play("depart", _transit(mission["depart"]))
	var flight: Dictionary = cfg["return"].duplicate()
	flight.merge(cfg["return"][destination], true)
	var flown: Dictionary = await play("return", flight)

	_set_phase(4)
	await play("earth_landing", _transit(cfg["earth_landing"]))

	var summary: Dictionary = cfg["summary"].duplicate()
	summary["mission_name"] = "MISSION: " + str(mission["name"])
	summary["destination"] = mission["destination"]
	summary["objectives"] = mission["objectives"]
	summary["congratulations"] = mission["congratulations"]
	summary["hits"] = flown.get("hits", 0)
	summary["mission_seconds"] = int(mission_seconds)
	missions_completed += 1
	var ending: Dictionary = await play("summary", summary)
	return str(ending.get("choice", "menu"))


func _transit(scene: Dictionary) -> Dictionary:
	var c := scene.duplicate()
	c["script"] = cfg["transit_script"]
	return c


## Plays one screen (a script built on mission_stage.gd) and waits for it to end.
func play(id: String, config: Dictionary) -> Dictionary:
	var node: CanvasLayer = load(str(config["script"])).new()
	node.setup(id, config)
	stage = node
	stage_name = id
	add_child(node)
	var result: Dictionary = await node.finished
	last_result = result
	return result


## Plays a walk-around surface (the Moon or Mars) and waits until the player is back in the lander.
func play_surface(level_file: String) -> Dictionary:
	var node: Node2D = load(SURFACE_SCRIPT).new()
	node.level_path = level_file
	stage = node
	stage_name = "surface"
	add_child(node)
	var result: Dictionary = await node.finished
	node.queue_free()
	last_result = result
	return result


func _stop_sounds() -> void:
	var manager := get_node_or_null("/root/Sfx")
	if manager != null:
		manager.stop_all()


# ---------------------------------------------------- mission progress bar ----

## Five small boxes beside PAUSE / EXIT: launch, travel, mission, return, landing.
func _build_phase_bar() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	phase_label = Label.new()
	phase_label.add_theme_font_size_override("font_size", 8)
	phase_label.add_theme_color_override("font_color", Color(1, 0.86, 0.3))
	phase_label.add_theme_color_override("font_outline_color", Color(0.04, 0.05, 0.09))
	phase_label.add_theme_constant_override("outline_size", 3)
	phase_label.position = Vector2(250, 21)
	phase_label.size = Vector2(200, 10)
	phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	phase_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(phase_label)
	for i in cfg["phases"].size():
		var box := ColorRect.new()
		box.position = Vector2(456 + i * 11, 25)
		box.size = Vector2(9, 6)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(box)
		phase_boxes.append(box)


func _set_phase(index: int) -> void:
	phase = index
	var names: Array = cfg["phases"]
	phase_label.text = "MISSION %d/%d: %s" % [index + 1, names.size(), names[index]]
	for i in phase_boxes.size():
		phase_boxes[i].color = Color(0.45, 1, 0.6) if i < index else (Color(1, 0.86, 0.3) if i == index else Color(0.25, 0.27, 0.32))
