extends SceneTree
## Headless test of the three mini-games inside the level:
##   godot --headless --path . --script tools/minigame_test.gd
## Plays the prologue (medical exam, suit up), then reaches the electrical panel
## and plays the instrument inspection, with one wrong answer in each.

var fails := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("FAIL ", what)


func current_game(lvl: Node) -> Node:
	for c in lvl.get_children():
		if c is CanvasLayer and c.has_signal("finished"):
			return c
	return null


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _initialize() -> void:
	var lvl: Node = load("res://main.tscn").instantiate()
	root.add_child(lvl)
	await frames(3)

	# 1. medical examination
	var g := current_game(lvl)
	check(g != null and g.game_id == "medical_exam" and lvl.frozen, "prologue starts with the medical exam")
	check(not g.try_match("thermometer", "heart_monitor"), "wrong match is refused")
	check(g.mistakes == 1 and g.matched.size() == 0, "wrong match counted, nothing matched")
	for id in ["heart_monitor", "bp_monitor", "thermometer"]:
		check(g.try_match(id, id), "match " + id)
	check(g.completed, "medical exam completes")
	g.dismiss()
	await frames(3)

	# 2. suit up
	g = current_game(lvl)
	check(g != null and g.game_id == "suit_up", "suit up follows")
	check(not g.try_place("helmet", "head"), "helmet before suit and headset is refused")
	check(not g.try_place("suit", "head"), "suit on the head is refused")
	check(not g.try_place("gloves", "hands"), "gloves before suit are refused")
	check(g.zone_at(g.FIG_POS + Vector2(24, 10) * g.FIG_SCALE) == "head", "zone lookup: head")
	check(g.zone_at(g.FIG_POS + Vector2(11, 44) * g.FIG_SCALE) == "hands", "zone lookup: hands")
	check(g.zone_at(g.FIG_POS + Vector2(24, 30) * g.FIG_SCALE) == "chest", "zone lookup: chest")
	check(g.zone_at(g.FIG_POS + Vector2(20, 60) * g.FIG_SCALE) == "body", "zone lookup: body")
	check(g.try_place("suit", "body"), "suit")
	check(not g.try_place("helmet", "head"), "helmet still needs the headset")
	check(g.try_place("headset", "head"), "headset")
	check(g.try_place("helmet", "head"), "helmet")
	check(g.try_place("gloves", "hands"), "gloves")
	check(not g.try_place("connections", "hands"), "connections on the hands are refused")
	check(g.try_place("connections", "chest"), "connections")
	check(g.completed and g.layers["helmet"].visible, "suit up completes with layers shown")
	g.dismiss()
	await frames(3)
	check(current_game(lvl) == null and not lvl.frozen, "player gets control after the prologue")

	# 3. instrument inspection, reached through the normal objective flow
	for c in [Vector2i(11, 9), Vector2i(5, 13), Vector2i(18, 13), Vector2i(11, 15)]:
		lvl.cell = c
		lvl.try_move("up" if c.y == 9 else ("left" if c.x == 5 else ("right" if c.x == 18 else "down")))
		lvl.moving = false
	for id in ["checklist", "flight_panel", "comm_console"]:
		lvl.interact_with(id)
		while lvl.dialog_open:
			lvl._advance_dialog()
	check(lvl.objective_index == 4, "reached the systems objective")
	lvl.interact_with("electrical_panel")
	while lvl.dialog_open:
		lvl._advance_dialog()
	await frames(3)
	g = current_game(lvl)
	check(g != null and g.game_id == "instrument_inspection" and lvl.frozen, "panel opens the inspection")
	var bad := 0
	for i in g.gauges.size():
		var gg: Dictionary = g.gauges[i]
		var outside: bool = gg["value"] < gg["normal_min"] or gg["value"] > gg["normal_max"]
		check(outside == gg["abnormal"], "gauge value matches its abnormal flag: " + gg["id"])
		bad += int(gg["abnormal"])
		g.select_gauge(i)
		check(not g.report(i, not gg["abnormal"]), "wrong report is refused")
		check(g.btn_call.disabled, "cannot call before all are inspected")
		check(g.report(i, gg["abnormal"]), "right report is accepted")
	check(bad == 2 and g.mistakes == 5, "two abnormal gauges, five counted mistakes")
	check(not g.btn_call.disabled, "call button enabled")
	g.call_mission_control()
	check(g.completed, "inspection completes")
	check(not lvl.done_targets.has("electrical_panel"), "target not credited before the mini-game ends")
	g.dismiss()
	await frames(3)
	check(lvl.done_targets.has("electrical_panel") and not lvl.frozen, "target credited afterwards")
	lvl.interact_with("o2_panel")
	while lvl.dialog_open:
		lvl._advance_dialog()
	check(lvl.objective_index == 5, "objective 5 finishes as before")

	print("MINIGAME TEST ", "PASSED" if fails == 0 else "FAILED (%d)" % fails)
	quit(fails)
