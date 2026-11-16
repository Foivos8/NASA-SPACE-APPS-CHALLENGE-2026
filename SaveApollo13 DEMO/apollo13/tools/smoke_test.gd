extends SceneTree
## Headless walkthrough: godot --headless --path . --script tools/smoke_test.gd
## Drives the level through every objective and checks the result.

func _initialize() -> void:
	var lvl: Node = load("res://main.tscn").instantiate()
	lvl.minigames_enabled = false      # mini-games have their own test: tools/minigame_test.gd
	root.add_child(lvl)
	await process_frame
	var fails := 0
	# walk from the White Room through the hatch
	for d in ["down", "down", "down", "down"]:
		lvl.try_move(d)
		lvl.moving = false
	if lvl.cell != Vector2i(11, 6):
		fails += 1; print("FAIL walk-in, at ", lvl.cell)
	# explore: teleport-walk into each zone
	for c in [Vector2i(11, 9), Vector2i(5, 13), Vector2i(18, 13), Vector2i(11, 15)]:
		lvl.cell = c
		lvl.try_move("up" if c.y == 9 else ("left" if c.x == 5 else ("right" if c.x == 18 else "down")))
		lvl.moving = false
	if lvl.objective_index != 1 or not lvl.hatch_closed or not lvl.is_solid(Vector2i(11, 4)):
		fails += 1; print("FAIL explore ", lvl.objective_index)
	var order := ["checklist", "flight_panel", "comm_console", "electrical_panel", "o2_panel",
			"comm_console", "couch_cmp", "main_switches", "checklist", "couch_cmp"]
	var expect := [2, 3, 4, 4, 5, 6, 6, 6, 6, 7]
	for i in order.size():
		lvl.interact_with(order[i])
		var guard := 0
		while lvl.dialog_open and guard < 40:
			lvl._advance_dialog()
			guard += 1
		if lvl.objective_index != expect[i]:
			fails += 1; print("FAIL step ", i, " ", order[i], " -> ", lvl.objective_index)
	# wrong answer must not complete a target
	if not lvl.frozen:
		fails += 1; print("FAIL launch not started")
	# the launch text can be fast-forwarded with E: one press shows the message, the next moves on
	await create_timer(0.2).timeout
	var typing_before: bool = lvl.ui_text.is_typing()
	var press := InputEventAction.new()
	press.action = "interact"
	press.pressed = true
	lvl._unhandled_input(press)
	if not typing_before or lvl.ui_text.is_typing() or lvl.launch_skip:
		fails += 1; print("FAIL first E should only finish the typing")
	var started := Time.get_ticks_msec()
	var presses := 0
	while not lvl.level_complete and presses < 80:
		lvl._unhandled_input(press)
		presses += 1
		await create_timer(0.08).timeout
	var took := (Time.get_ticks_msec() - started) / 1000.0
	if not lvl.level_complete or took > 8.0:
		fails += 1; print("FAIL launch not skippable: ", took, " s, ", presses, " presses")
	if not lvl.in_orbit or "Continue to Level 2" not in lvl.ui_text.get_parsed_text():
		fails += 1; print("FAIL launch end state")
	print("  launch skipped in %.1f s with %d presses" % [took, presses])
	print("SMOKE TEST ", "PASSED" if fails == 0 else "FAILED (%d)" % fails)
	quit(fails)
