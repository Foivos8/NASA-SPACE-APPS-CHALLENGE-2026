extends SceneTree
## Headless test of the "Design Your Mission" mode: the menu button, all three
## missions from launch to the completion screen, the hazards of each flight
## home, the exit bar, and that the original mode still opens.
##   godot --headless --path . --script tools/mission_test.gd

var fails := 0
var Sfx: Node


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("FAIL ", what)


func frames(n: int) -> void:
	for i in n:
		await process_frame


func wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func scene_name() -> String:
	return current_scene.scene_file_path.get_file() if current_scene != null else ""


func played(key: String) -> int:
	var n := 0
	for h in Sfx.history:
		if h[0] == key:
			n += 1
	return n


func open_mode() -> Node:
	change_scene_to_file("res://main_menu.tscn")
	await frames(3)
	current_scene.buttons[1].pressed.emit()
	await frames(3)
	return current_scene


## Steps a screen until `done` returns true.
func run_until(stage: Node, done: Callable, what: String, dt := 0.1, limit := 4000) -> void:
	var n := 0
	while not done.call() and n < limit:
		stage.step(dt)
		n += 1
	check(done.call(), what)


func finish(stage: Node, what: String) -> void:
	check(stage.completed, what + ": completion screen shown")
	stage.dismiss()


func minigame_of(surface: Node) -> Node:
	for c in surface.get_children():
		if c is CanvasLayer and "game_id" in c:
			return c
	return null


## Talks to something on the surface and reads to the end of its text.
func talk(surface: Node, id: String) -> void:
	surface.interact_with(id)
	var n := 0
	while surface.dialog_open and n < 30:
		surface.ui_text.finish()
		surface._advance_dialog()
		n += 1


func do_transit(m: Node, id: String) -> void:
	check(m.stage_name == id, "screen '%s' (got '%s')" % [id, m.stage_name])
	var s: Node = m.stage
	s.press_action()
	check(s.phase == "approach", id + ": the button does nothing before the approach is over")
	await run_until(s, func() -> bool: return s.phase == "wait", id + ": approach ends")
	check(s.action_btn.visible, id + ": action button shown")
	s.press_action()
	await run_until(s, func() -> bool: return s.completed, id + ": manoeuvre ends")
	finish(s, id)


func do_launch(m: Node) -> void:
	check(m.stage_name == "launch", "mission starts on the launch pad")
	var s: Node = m.stage
	s.press_launch()
	check(s.phase == "prep", "LAUNCH is refused before the checks are done")
	var rockets := played("rocket")
	for t in s.tasks:
		s.press_task(t["id"])
		await run_until(s, func() -> bool: return s.rows[t["id"]]["done"], "check '%s' completes" % t["id"])
	check(s.ready_to_launch(), "all checks done")
	s.press_launch()
	check(s.phase == "count", "LAUNCH starts the countdown")
	await run_until(s, func() -> bool: return s.phase == "ascent", "countdown reaches liftoff")
	check(s.flame.visible, "engine flame at liftoff")
	check(Sfx.streams.is_empty() or played("rocket") > rockets, "rocket sound at liftoff")
	await run_until(s, func() -> bool: return s.completed, "rocket reaches space")
	check(s.sky.altitude > 0.95, "sky has turned to space")
	finish(s, "launch")


func do_destination(m: Node, dest: String) -> void:
	check(m.stage_name == "destination", "destination screen follows the launch")
	var s: Node = m.stage
	check(s.cards.size() == 3 and s.cards.has("moon") and s.cards.has("mars") and s.cards.has("satellite"), "three destinations offered")
	s.choose(dest)
	for other in ["moon", "mars", "satellite"]:
		s.choose(other)
	check(s.chosen == dest, "only one destination can be chosen")
	finish(s, "destination")
	check(m.destination == dest, "controller records the destination")


func do_moon(m: Node) -> void:
	check(m.stage_name == "surface", "Moon surface follows the landing")
	var s: Node = m.stage
	check(s.data["name"].contains("moon"), "Moon map loaded")
	check(s.checklist.rows.size() == 4, "Moon checklist has four lines")
	talk(s, "lander")
	check(not s.ended and s.objective_index == 0, "cannot leave the Moon before the objectives are done")
	check(s.try_move("down") or s.try_move("left") or s.try_move("right"), "the astronaut can walk")
	await wait(0.2)
	var collects := played("collect")
	for i in 5:
		talk(s, "sample_%d" % (i + 1))
		check(s.count_done(s.data["checklist"][0]["targets"]) == i + 1, "sample counter is %d" % (i + 1))
	check("5/5" in s.checklist.rows["samples"]["label"].text, "checklist shows 5/5 samples")
	check(s.checklist.is_done("samples") and not s.checklist.is_done("flag"), "samples ticked, flag not yet")
	check(Sfx.streams.is_empty() or played("collect") >= collects + 5, "collect sound for each sample")
	check(not s.props.has("sample_1"), "collected samples leave the map")
	for id in ["boulder", "crater", "rille"]:
		talk(s, id)
	check(s.checklist.is_done("landmarks"), "landmarks ticked")
	check(s.objective_index == 0, "surface objective still open without the flag")
	talk(s, "flag_site")
	check(s.checklist.is_done("flag"), "flag ticked")
	check(s.props["flag_site"]["sprite"].texture.resource_path.ends_with("flag.png"), "the Earth flag stands on the site")
	check(s.objective_index == 1, "now the lander is the objective")
	talk(s, "lander")
	await wait(1.0)
	check(m.stage_name == "depart", "leaving the Moon after the lander")


func do_mars(m: Node) -> void:
	check(m.stage_name == "surface", "Mars surface follows the landing")
	var s: Node = m.stage
	check(s.data["name"].contains("mars"), "Mars map loaded")
	talk(s, "site_habitat")
	check(not s.target_done.has("site_habitat") and minigame_of(s) == null, "cannot build before the hover vehicle is repaired")
	talk(s, "hover")
	var g := minigame_of(s)
	check(g != null and g.game_id == "hover_repair", "hover repair activity opens")
	g.use_tool("seal")
	check(g.fixed.is_empty(), "no repair without choosing a fault")
	for f in g.faults:
		g.select_fault(f["id"])
		g.use_tool("paint")
		check(not g.repairing, "the wrong repair is refused")
		g.use_tool(f["tool"])
		await run_until(g, func() -> bool: return not g.repairing, "repair of '%s' finishes" % f["id"])
	check(g.mistakes == 3 and g.fixed.size() == 3, "three faults fixed (three wrong tries counted)")
	check(g.machine.texture.resource_path.ends_with("hover_fixed.png"), "picture shows the repaired vehicle")
	finish(g, "hover repair")
	await wait(1.4)
	check(s.riding and s.move_time < 0.14, "the repaired hover vehicle is ridden, and is faster")
	check(s.checklist.is_done("repair"), "repair ticked")
	var n := 0
	for id in ["site_habitat", "site_solar", "site_antenna", "site_lab"]:
		talk(s, id)
		var b := minigame_of(s)
		check(b != null and b.game_id.begins_with("build_"), "build activity opens for " + id)
		b.press(2)
		check(b.done == 0 and b.mistakes == 1, "a step out of order is refused")
		for i in b.steps.size():
			b.press(i)
		await run_until(b, func() -> bool: return b.completed, "building rises")
		finish(b, id)
		await frames(2)
		n += 1
		check(s.count_done(s.data["checklist"][1]["targets"]) == n, "base parts built: %d" % n)
		check(s.props[id]["sprite"].texture.resource_path.get_file() != "pad.png", "the pad now shows a building")
	check(s.checklist.is_done("base") and "4/4" in s.checklist.rows["base"]["label"].text, "base ticked at 4/4")
	talk(s, "lander")
	await wait(1.0)
	check(m.stage_name == "depart", "leaving Mars after the lander")


func do_satellite(m: Node) -> void:
	check(m.stage_name == "satellite_repair", "satellite repair follows docking")
	var g: Node = m.stage
	check(g.machine.texture.resource_path.ends_with("satellite_broken.png"), "satellite is visibly damaged")
	g._pointer_down(Vector2(30, 90))
	check(g.selected == "", "clicking an undamaged spot finds nothing")
	for f in g.faults:
		g._pointer_down(g.zones[f["id"]]["rect"].get_center())
		check(g.selected == f["id"], "clicking the damage finds fault '%s'" % f["id"])
		g.use_tool(f["tool"])
		await run_until(g, func() -> bool: return not g.repairing, "repair of '%s' finishes" % f["id"])
	check(g.machine.texture.resource_path.ends_with("satellite_fixed.png"), "satellite restored")
	finish(g, "satellite repair")
	check(m.stage_name == "earth_photo", "photography follows the repair")
	var p: Node = m.stage
	var shutters := played("shutter")
	p.aim = Vector2(40, 200)
	p.shoot()
	check(p.taken.is_empty() and p.mistakes == 1, "a photo of nothing does not count")
	for i in p.targets.size():
		var t: Dictionary = p.targets[i]
		p._pointer_move(p.VIEW.position + p.target_point(t))
		check(p.target_in_frame() == t["id"], "target '%s' can be framed" % t["id"])
		p.shoot()
		check(p.taken.size() == i + 1 and p.slots[t["id"]]["print"].texture is AtlasTexture, "photo %d shown as a print" % (i + 1))
		p.shoot()
		check(p.taken.size() == i + 1, "the same photo is not counted twice")
	check("3/3" in p.count_label.text, "photo counter shows 3/3")
	check(Sfx.streams.is_empty() or played("shutter") > shutters, "shutter sound")
	finish(p, "earth photography")


## Steers away from whatever is coming.
func steer_for(r: Node) -> Vector2:
	var best_y: float = r.ship_pos.y
	var best := -1e9
	var y := 40.0
	while y <= r.VIEW.size.y - 20.0:
		var room := 1e9
		for o in r.obstacles:
			var dx: float = o["pos"].x - r.ship_pos.x
			if dx > -50.0 and dx < 260.0:
				room = minf(room, absf(o["pos"].y + o["vel"].y * maxf(dx, 0.0) / 180.0 - y) - float(o["radius"]))
		var score := minf(room, 60.0) - absf(y - r.ship_pos.y) * 0.02
		if score > best:
			best = score
			best_y = y
		y += 8.0
	return Vector2(-1.0, clampf((best_y - r.ship_pos.y) / 6.0, -1.0, 1.0))


func do_return(m: Node, dest: String) -> void:
	check(m.stage_name == "return", "flight home follows the departure")
	var r: Node = m.stage
	var rocks: bool = dest != "satellite"
	check(r.allow_asteroids == rocks, "%s flight: asteroids %s" % [dest, "on" if rocks else "off"])
	# a collision costs hull, makes a sound and protects for a moment
	var impacts := played("impact")
	var o: Dictionary = r.spawn("asteroid", r.ship_pos.y)
	check(o["kind"] == ("asteroid" if rocks else "debris"), "%s flight: a requested asteroid becomes %s" % [dest, o["kind"]])
	o["pos"] = r.ship_pos
	r.step(0.02)
	check(r.hull == r.max_hull - 1 and r.hits == 1 and r.invulnerable > 0.0, "a collision costs one hull point")
	check(Sfx.streams.is_empty() or played("impact") > impacts, "impact sound")
	var o2: Dictionary = r.spawn("debris", r.ship_pos.y)
	o2["pos"] = r.ship_pos
	r.step(0.02)
	check(r.hull == r.max_hull - 1, "no second hit while protected")
	# losing the whole hull is not the end of the mission
	for i in 2:
		r.invulnerable = 0.0
		var x: Dictionary = r.spawn("debris", r.ship_pos.y)
		x["pos"] = r.ship_pos
		r.step(0.02)
	check(r.rescues == 1 and r.hull == r.max_hull and r.assist, "hull lost: repaired, set back, and the flight goes on")
	# fly the rest with simple steering
	var before: int = r.hits
	var n := 0
	while not r.completed and n < 20000:
		r.step(1.0 / 30.0, steer_for(r))
		n += 1
	check(r.completed, dest + " flight home can be finished")
	print("  %s flight: asteroids %d, debris %d, hits while steering %d, rescues %d" % [dest, r.spawned["asteroid"], r.spawned["debris"], r.hits - before, r.rescues])
	if rocks:
		check(r.spawned["asteroid"] >= 5 and r.spawned["debris"] >= 5, dest + " flight has asteroids and debris")
	else:
		check(r.spawned["asteroid"] == 0 and r.spawned["debris"] >= 10, "satellite flight has debris only")
	check(r.hits - before <= 2, dest + " flight is fair: simple steering gets through")
	finish(r, "return")


func do_summary(m: Node, dest: String, choice: String) -> void:
	check(m.stage_name == "summary", "completion screen follows the landing")
	var s: Node = m.stage
	var mission: Dictionary = m.cfg["missions"][dest]
	check(str(mission["name"]) in s.config["mission_name"], "summary names the mission")
	check(s.config["destination"] == mission["destination"], "summary names the destination")
	check(s.rows.size() == mission["objectives"].size(), "summary lists this mission's objectives")
	await run_until(s, func() -> bool: return s.revealed == s.rows.size(), "objectives are ticked")
	check(s.again_btn.text == "PLAY ANOTHER MISSION" and s.menu_btn.text == "RETURN TO STARTING MENU", "two choices offered")
	check(not m.top_menu.in_progress.call(), "leaving from the summary needs no warning")
	s.choose(choice)


func fly(m: Node, dest: String, choice: String) -> void:
	print("mission: ", dest)
	await do_launch(m)
	check(m.phase == 1, "progress bar: travel")
	await do_destination(m, dest)
	await do_transit(m, "arrive")
	check(m.phase == 2, "progress bar: mission")
	match dest:
		"moon":
			await do_moon(m)
		"mars":
			await do_mars(m)
		"satellite":
			await do_satellite(m)
	await do_transit(m, "depart")
	await do_return(m, dest)
	check(m.phase == 4, "progress bar: landing")
	await do_transit(m, "earth_landing")
	await do_summary(m, dest, choice)


func _initialize() -> void:
	await frames(2)
	Sfx = root.get_node_or_null("Sfx")
	for key in ["shutter", "collect", "build", "impact", "warning"]:
		check(Sfx.has(key), "sound file found for '%s'" % key)

	# ---------------- starting menu ----------------
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	await frames(3)
	var menu := current_scene
	check(menu.buttons.size() == 3, "three menu buttons")
	check(menu.buttons[0].text == "START GAME - MISSION MAP" and menu.buttons[1].text == "DESIGN YOUR MISSION" and menu.buttons[2].text == "QUIT GAME", "menu captions")
	menu.buttons[0].pressed.emit()
	await frames(3)
	check(scene_name() == "level_menu.tscn", "first button still opens the original mode")

	# ---------------- three missions, one after another ----------------
	var m: Node = await open_mode()
	check(scene_name() == "design_mission.tscn", "second button opens Design Your Mission")
	await fly(m, "moon", "again")
	check(scene_name() == "design_mission.tscn" and m.stage_name == "launch" and m.destination == "", "'play another mission' starts a fresh mission")
	await fly(m, "mars", "again")
	await fly(m, "satellite", "menu")
	check(m.missions_completed == 3, "three missions completed")
	await frames(3)
	check(scene_name() == "main_menu.tscn", "'return to starting menu' goes to the main menu")

	# ---------------- pause / exit bar inside the mode ----------------
	m = await open_mode()
	m.top_menu.pause()
	check(paused, "PAUSE stops the mission")
	m.top_menu.resume()
	m.top_menu.request_exit()
	check(m.top_menu.confirming, "EXIT asks first during a mission")
	m.top_menu.confirm_exit()
	await frames(3)
	check(scene_name() == "main_menu.tscn" and not paused, "EXIT returns to the starting menu")

	print("MISSION TEST ", "PASSED" if fails == 0 else "FAILED (%d)" % fails)
	quit(1 if fails > 0 else 0)
