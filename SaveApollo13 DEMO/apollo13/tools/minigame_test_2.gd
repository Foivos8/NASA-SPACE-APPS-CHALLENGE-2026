extends SceneTree
## Headless test of mini-games 4 and 5 inside the level:
##   godot --headless --path . --script tools/minigame_test_2.gd
## Reaches objective 6 and plays Communication with Houston (one wrong reply per
## call), then objective 7 and the Launch Sequence (one missed window, wrong
## presses), and checks the level carries on into the ascent cutscene.

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


func finish_dialog(lvl: Node) -> void:
	var guard := 0
	while lvl.dialog_open and guard < 40:
		lvl._advance_dialog()
		guard += 1


func _initialize() -> void:
	var lvl: Node = load("res://main.tscn").instantiate()
	root.add_child(lvl)
	await frames(3)
	# skip the prologue quickly
	for n in 2:
		var pg := current_game(lvl)
		pg.dismiss()
		await frames(3)
	check(not lvl.frozen, "prologue dismissed")
	for c in [Vector2i(11, 9), Vector2i(5, 13), Vector2i(18, 13), Vector2i(11, 15)]:
		lvl.cell = c
		lvl.try_move("up" if c.y == 9 else ("left" if c.x == 5 else ("right" if c.x == 18 else "down")))
		lvl.moving = false
	for id in ["checklist", "flight_panel", "comm_console", "electrical_panel"]:
		lvl.interact_with(id)
		finish_dialog(lvl)
		await frames(3)
		var ig := current_game(lvl)
		if ig != null:
			ig.dismiss()
			await frames(3)
	lvl.interact_with("o2_panel")
	finish_dialog(lvl)
	check(lvl.objective_index == 5, "reached objective 6 (mission control)")

	# ---- 4. Communication with Houston: opens before the Go / No-Go text ----
	lvl.interact_with("comm_console")
	await frames(3)
	var g := current_game(lvl)
	check(g != null and g.game_id == "comm_houston" and lvl.frozen and not lvl.dialog_open, "comm mini-game opens first")
	var n_calls: int = g.scenarios.size()
	check(n_calls >= 4, "at least four scenarios")
	for i in n_calls:
		check(g.index == i, "on call %d" % i)
		check(not g.choose(0), "cannot answer while the call is still coming in")
		g.reveal_now()
		var opts: Array = g.scenarios[i]["options"]
		var right := -1
		var wrong := -1
		for k in opts.size():
			if opts[k]["ok"]:
				right = k
			else:
				wrong = k
		check(not g.choose(wrong), "wrong reply refused")
		check(g.index == i and not g.answered, "still on the same call after a wrong reply")
		check(g.choose(right), "right reply accepted")
		g.skip_wait()
	check(g.is_closing() and g.mistakes == n_calls, "closing call reached, mistakes counted")
	g.reveal_now()
	check(g.completed, "comm mini-game completes on Houston's confirmation")
	g.dismiss()
	await frames(3)
	check(lvl.dialog_open and lvl.objective_index == 5, "Go / No-Go text follows the mini-game")
	finish_dialog(lvl)
	check(lvl.objective_index == 6, "objective 6 completes as before")

	# ---- 5. Launch Sequence: after strapping in ----
	for id in ["main_switches", "checklist", "couch_cmp"]:
		lvl.interact_with(id)
		finish_dialog(lvl)
	await frames(3)
	g = current_game(lvl)
	check(g != null and g.game_id == "launch_sequence", "launch mini-game opens from the couch")
	check(lvl.objective_index == 6, "launch cutscene has not started yet")
	check(not g.press("go"), "pressing before any call is refused")
	check(is_equal_approx(g.t, 15.0), "the countdown is 15 seconds")
	g.step(0.1)                                   # the first final check is called at once
	check(g.active and g.current_task()["id"] == "systems" and is_equal_approx(g.t, 15.0), "systems check active, clock holding at T-15")
	check(not g.press("ack"), "wrong control refused")
	g.press("guidance")
	g.step(8.5)                                   # miss its 8-second window -> hold
	check(g.state == "hold" and g.holds == 1 and g.switches_on.is_empty(), "missed window puts the count on hold")
	g.step(3.0)
	g.step(0.1)
	check(g.state == "count" and g.active and is_equal_approx(g.t, 15.0), "the check is called again, clock still at T-15")
	for c in ["guidance", "power", "life_support"]:
		check(g.press(c), "switch " + c)
	check(g.task_index == 1, "systems done")
	g.step(0.1)
	check(g.current_task()["id"] == "range" and g.active, "range check active")
	var was_bad: bool = g.reading_bad
	check(not g.press("in_range" if was_bad else "out_of_range"), "wrong range report refused")
	if was_bad:
		check(g.press("out_of_range") and g.active and not g.reading_bad, "out-of-range report switches to backup")
	check(g.press("in_range") and g.task_index == 2, "range done")
	g.step(0.1)
	check(g.active and g.press("talk") and is_equal_approx(g.t, 15.0), "voice check done, clock has not moved yet")
	g.step(0.5)
	check(g.active and g.current_task()["id"] == "guidance_release" and g.t < 15.0 and g.t > 14.0, "the 15-second count is now running")
	check(g.press("ack"), "press ack")
	for step_def in [[8.0, "ack"], [3.0, "go"]]:
		g.step(g.t - step_def[0])
		check(g.active, "call active at T-%d" % int(step_def[0]))
		check(g.press(step_def[1]), "press " + step_def[1])
	check(g.task_index == g.tasks.size() and g.ignited, "all calls answered, engines lit")
	g.step(3.5)
	check(g.state == "liftoff", "liftoff at zero")
	g.step(3.0)
	check(not g.completed, "liftoff animation still running")
	g.step(3.5)
	check(g.completed, "launch mini-game completes")
	g.dismiss()
	await frames(5)
	check(lvl.objective_index == 7 and lvl.frozen, "ascent cutscene starts afterwards")
	check(lvl.ui_clock.text == "T+00:12", "cutscene skips the countdown the mini-game already covered: " + lvl.ui_clock.text)

	print("MINIGAME TEST 2 ", "PASSED" if fails == 0 else "FAILED (%d)" % fails)
	quit(fails)
