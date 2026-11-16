extends "res://scripts/mission/mission_stage.gd"
## Design Your Mission - the playable flight home.
## The player steers the rocket (arrow keys / W A S D) while obstacles drift in
## from the right. What comes at you depends on where you have been:
##   Moon, Mars   asteroids AND space debris
##   Satellite    space debris only (config["asteroids"] is false)
## Fair by design: every obstacle is announced by a yellow warning mark, there
## is always a gap to fly through, a hit costs one hull point and gives a
## moment of protection, and if the hull runs out Mission Control repairs it
## and sets you back to the last third of the route with slower obstacles, so
## the flight can always be finished.
## Text and numbers: data/missions.json -> "return".

const VIEW := Rect2(12, 68, 616, 240)
const SHIP_SIZE := Vector2(72, 32)
const SHIP_SPEED := 160.0
const SHIP_RADIUS := 11.0
const START_QUIET := 2.5          # seconds before the first obstacle
const END_QUIET := 4.5            # no new obstacles this close to Earth
const SPAWN_EVERY := 0.85
const INVULNERABLE := 1.6
const DEBRIS_FILES := ["debris_1.png", "debris_2.png", "debris_3.png"]
const ASTEROID_FILES := ["asteroid_1.png", "asteroid_2.png"]

var allow_asteroids := true
var total := 38.0                 # seconds of flight
var travel := 0.0
var max_hull := 3
var hull := 3
var hits := 0
var rescues := 0
var assist := false               # slower obstacles after a rescue
var invulnerable := 0.0
var spawn_in := START_QUIET
var obstacles: Array = []         # {node, mark, kind, pos, vel, radius, spin}
var spawned := {"asteroid": 0, "debris": 0}
var ship_pos := Vector2(90, 120)  # centre of the rocket, in view coordinates
var rng := RandomNumberGenerator.new()

var view: Control
var ship: TextureRect
var jet: ColorRect
var flash: ColorRect
var earth: TextureRect
var streaks: Array = []
var hull_boxes: Array = []
var bar_fill: ColorRect
var _last_third := -1
var _time := 0.0


func _build() -> void:
	allow_asteroids = bool(config.get("asteroids", true))
	total = float(config.get("seconds", 38))
	max_hull = int(config.get("hull", 3))
	hull = max_hull
	rng.seed = 2013
	view = add_view(VIEW, 1.0)
	for i in 26:                                          # passing stars give a sense of speed
		var s := add_rect(Rect2(rng.randf_range(0, VIEW.size.x), rng.randf_range(0, VIEW.size.y), rng.randi_range(2, 6), 1), Color(1, 1, 1, 0.35), view)
		streaks.append({"node": s, "speed": rng.randf_range(60, 200)})
	earth = add_art("res://assets/levels/earth.png", Vector2(VIEW.size.x + 10, 24), 4.0, view)
	jet = add_rect(Rect2(0, 0, 10, 6), Color(1, 0.7, 0.25), view)
	ship = add_art(MISSION_ART + "rocket_side.png", Vector2.ZERO, 2.0, view)
	flash = add_rect(Rect2(Vector2.ZERO, VIEW.size), Color(1, 0.2, 0.15, 0.0), view)
	# heads-up display inside the view
	add_label("HULL", 9, C_GOLD, Vector2(8, 4), 0, view)
	for i in max_hull:
		hull_boxes.append(add_rect(Rect2(40 + i * 16, 6, 12, 9), C_OK, view))
	add_label("EARTH", 9, C_GOLD, Vector2(VIEW.size.x - 44, 4), 0, view)
	add_rect(Rect2(VIEW.size.x - 252, 8, 202, 6), Color(0.1, 0.11, 0.14), view)
	bar_fill = add_rect(Rect2(VIEW.size.x - 251, 9, 0, 4), C_OK, view)
	say(str(config.get("intro", "")), true)
	_refresh()
	_place_ship()


func _refresh() -> void:
	for i in hull_boxes.size():
		hull_boxes[i].color = C_OK if i < hull else Color(0.3, 0.12, 0.12)
	bar_fill.size.x = 200.0 * clampf(travel / total, 0.0, 1.0)
	progress.text = "Distance %d%%   Hull %d/%d" % [int(100.0 * clampf(travel / total, 0.0, 1.0)), hull, max_hull]


func _place_ship() -> void:
	ship.position = (ship_pos - SHIP_SIZE / 2.0).round()
	jet.position = ship.position + Vector2(-8, 13)
	jet.size.x = 6.0 + 5.0 * absf(sin(_time * 30.0))
	jet.position.x = ship.position.x - jet.size.x + 2
	ship.modulate.a = 0.4 if invulnerable > 0.0 and int(_time * 12.0) % 2 == 0 else 1.0


func _process(delta: float) -> void:
	super._process(delta)
	var steer := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up"))
	step(delta, steer)


## Advances the flight by `delta` seconds with the given steering (-1..1 on each axis).
## The tests call this directly.
func step(delta: float, steer := Vector2.ZERO) -> void:
	if completed:
		return
	_time += delta
	travel += delta
	invulnerable = maxf(0.0, invulnerable - delta)
	flash.color.a = maxf(0.0, flash.color.a - delta * 1.5)
	if steer.length() > 1.0:
		steer = steer.normalized()
	ship_pos += steer * SHIP_SPEED * delta
	ship_pos.x = clampf(ship_pos.x, SHIP_SIZE.x / 2.0 + 2, VIEW.size.x * 0.55)
	ship_pos.y = clampf(ship_pos.y, SHIP_SIZE.y / 2.0 + 20, VIEW.size.y - SHIP_SIZE.y / 2.0 - 2)
	_place_ship()
	for s in streaks:
		var n: ColorRect = s["node"]
		n.position.x -= float(s["speed"]) * delta
		if n.position.x < -8:
			n.position = Vector2(VIEW.size.x + 2, rng.randf_range(0, VIEW.size.y))

	var third := mini(int(travel / total * 3.0), 2)
	if third != _last_third:                              # a new stretch of the route: sound the warning
		_last_third = third
		sfx("warning", -8.0)
	spawn_in -= delta
	if spawn_in <= 0.0 and travel < total - END_QUIET:
		spawn_in = SPAWN_EVERY * (1.6 if assist else 1.0) * rng.randf_range(0.85, 1.2)
		_spawn_fair(_pick_kind())
		if rng.randf() < 0.3:
			_spawn_fair(_pick_kind())                     # sometimes two at once, with a way between them
	_move_obstacles(delta)

	if travel > total - END_QUIET:                        # Earth slides into view
		var k := clampf((travel - (total - END_QUIET)) / END_QUIET, 0.0, 1.0)
		earth.position.x = roundf(lerpf(VIEW.size.x + 10, VIEW.size.x - 210, k))
	_refresh()
	if travel >= total:
		outcome = {"hits": hits, "rescues": rescues}
		var note := "Hull hits taken: %d." % hits if hits > 0 else "Not a scratch on the hull!"
		complete(str(config["complete_title"]), str(config["complete_text"]) + "\n\n" + note)


func _pick_kind() -> String:
	if not allow_asteroids:
		return "debris"
	return "asteroid" if rng.randf() < 0.55 else "debris"


## Adds an obstacle at a random height, but only where the rocket is still left
## a way through: the paths of everything on screen are worked out ahead of
## time, and a height that would close the last gap is not used.
func _spawn_fair(kind: String) -> void:
	var pace := 0.75 if assist else 1.0
	var speed := (rng.randf_range(110, 165) if kind == "asteroid" else rng.randf_range(150, 215)) * pace
	var vel := Vector2(-speed, rng.randf_range(-14, 14))
	for attempt in 8:
		var y := rng.randf_range(34, VIEW.size.y - 24)
		if leaves_a_gap(y, vel, 22.0 if kind == "asteroid" else 16.0):
			spawn(kind, y, vel)
			return


## True if an obstacle starting at height `y` never joins the others in a wall:
## at every moment, beside every obstacle near the rocket's part of the screen,
## there is a clear band at least as tall as the rocket to fly through.
func leaves_a_gap(y: float, vel: Vector2, radius: float) -> bool:
	var paths: Array = [[Vector2(VIEW.size.x + 90, y), vel, radius]]
	for o in obstacles:
		paths.append([o["pos"], o["vel"], o["radius"]])
	var top := SHIP_SIZE.y / 2.0 + 20
	var bottom := VIEW.size.y - SHIP_SIZE.y / 2.0 - 2
	var t := 0.0
	while t < 8.0:
		for a in paths:
			var ax: float = a[0].x + a[1].x * t
			if ax < -20.0 or ax > VIEW.size.x * 0.55 + 70.0:
				continue
			var walls: Array = []
			for b in paths:
				if absf(b[0].x + b[1].x * t - ax) < 110.0:
					var by: float = b[0].y + b[1].y * t
					var half: float = float(b[2]) + SHIP_RADIUS + 8.0
					walls.append(Vector2(by - half, by + half))
			walls.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.x < q.x)
			var cursor := top
			var widest := 0.0
			for w in walls:
				widest = maxf(widest, w.x - cursor)
				cursor = maxf(cursor, w.y)
			widest = maxf(widest, bottom - cursor)
			if widest < 36.0:
				return false
		t += 0.1
	return true


## Adds one obstacle at height `y` (view coordinates), just off the right edge.
## Asteroids are refused when the route has none (the satellite flight).
func spawn(kind: String, y: float, vel := Vector2.ZERO) -> Dictionary:
	if kind == "asteroid" and not allow_asteroids:
		kind = "debris"
	var files: Array = ASTEROID_FILES if kind == "asteroid" else DEBRIS_FILES
	var node := add_art(MISSION_ART + str(files[rng.randi_range(0, files.size() - 1)]), Vector2.ZERO, 2.0, view)
	node.pivot_offset = node.size / 2.0
	view.move_child(node, flash.get_index())
	if vel == Vector2.ZERO:
		var pace := 0.75 if assist else 1.0
		vel = Vector2(-(rng.randf_range(110, 165) if kind == "asteroid" else rng.randf_range(150, 215)) * pace, rng.randf_range(-14, 14))
	y = clampf(y, 30, VIEW.size.y - 16)
	var mark := add_art(MISSION_ART + "warning.png", Vector2(VIEW.size.x - 16, y - 6), 1.0, view)
	var o := {
		"node": node, "mark": mark, "kind": kind,
		"pos": Vector2(VIEW.size.x + 90, y),
		"vel": vel,
		"radius": minf(node.size.x, node.size.y) * 0.42,
		"spin": rng.randf_range(-1.5, 1.5) * (2.0 if kind == "debris" else 1.0),
	}
	obstacles.append(o)
	spawned[kind] += 1
	return o


func _move_obstacles(delta: float) -> void:
	for o in obstacles.duplicate():
		o["pos"] += o["vel"] * delta
		var node: TextureRect = o["node"]
		node.position = (o["pos"] - node.size / 2.0).round()
		node.rotation += float(o["spin"]) * delta
		var mark: TextureRect = o["mark"]
		mark.visible = o["pos"].x > VIEW.size.x - 6 and int(_time * 8.0) % 2 == 0
		if o["pos"].x < -60:
			_remove(o)
		elif invulnerable <= 0.0 and o["pos"].distance_to(ship_pos) < float(o["radius"]) + SHIP_RADIUS:
			_hit(o)


func _remove(o: Dictionary) -> void:
	o["node"].queue_free()
	o["mark"].queue_free()
	obstacles.erase(o)


func _hit(o: Dictionary) -> void:
	hits += 1
	hull -= 1
	invulnerable = INVULNERABLE
	flash.color.a = 0.55
	sfx("impact", -2.0)
	_remove(o)
	var tw := create_tween()                              # the whole view jolts
	for dx in [6.0, -6.0, 4.0, -3.0, 0.0]:
		tw.tween_property(view, "position:x", VIEW.position.x + dx, 0.04)
	if hull > 0:
		say("%s %s hit the rocket. Hull %d/%d." % [config["hit_text"], "An asteroid" if o["kind"] == "asteroid" else "Space debris", hull, max_hull], false)
		return
	# hull gone: patched up and set back to the start of this third of the route
	rescues += 1
	assist = true
	hull = max_hull
	invulnerable = 2.5
	travel = floorf(travel / total * 3.0) * total / 3.0
	spawn_in = START_QUIET
	for other in obstacles.duplicate():
		_remove(other)
	sfx("alarm", -12.0, 0.0, 1.2)
	say(str(config["rescue_text"]), false)
