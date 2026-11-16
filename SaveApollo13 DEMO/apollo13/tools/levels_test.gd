extends SceneTree
## Headless test of the main menu, Level 1, Level 2, the pause / exit bar and
## the sound triggers:   godot --headless --path . --script tools/levels_test.gd

var fails := 0
var Sfx: Node


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("FAIL ", what)


func frames(n: int) -> void:
	for i in n:
		await process_frame


func scene_name() -> String:
	return current_scene.scene_file_path.get_file() if current_scene != null else ""


func played(key: String) -> int:
	var n := 0
	for h in Sfx.history:
		if h[0] == key:
			n += 1
	return n


func _initialize() -> void:
	await frames(2)
	Sfx = root.get_node_or_null("Sfx")
	check(Sfx != null, "Sfx autoload exists")
	for key in ["rocket", "footsteps", "walkie", "radio", "beeps", "houston", "talk"]:
		check(Sfx.has(key), "audio file found for '%s'" % key)
	print("audio files: ", Sfx.files)

	# ---------------- main menu ----------------
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	await frames(3)
	check(scene_name() == "main_menu.tscn", "game starts in the main menu")
	var menu := current_scene
	check(menu.buttons.size() == 3, "three menu buttons: start game, design your mission, quit")
	check(menu.buttons[0].text == "START GAME - MISSION MAP" and menu.buttons[2].text == "QUIT GAME", "menu button captions")
	menu.buttons[0].pressed.emit()
	await frames(3)
	check(scene_name() == "level_menu.tscn", "first menu button opens the level menu (mission map)")

	# ---------------- level menu ----------------
	var board := current_scene
	check(root.content_scale_size == Vector2i(640, 360), "level menu runs at the game's own 640x360 scale")
	check(board.S.size() == 10 and board.title_label.text == "1. Launch from Florida", "ten stations, in English")
	check(board.play_level.visible and board.play_level.text == "PLAY LEVEL 1" and board.go.text == "CONTINUE", "station 1 offers Level 1")
	board.show_info(true)
	check(board.modal.visible and "Jim Lovell" in board.modal_text.plain, "info sheet opens")
	board.show_info(false)
	board.go_to_station(1)
	check(board.cur == 1 and board.play_level.visible and board.play_level.text == "PLAY LEVEL 2", "clicking station 2 jumps straight to it and offers Level 2")
	check(board.station_at(board.PATH[board.IDX[6]] + Vector2(3, -2)) == 6 and board.station_at(Vector2(300, 120)) == -1, "station hit areas")
	board.go_to_station(2)
	check(board.cur == 2 and not board.play_level.visible, "station 3 has no level button")
	board.go_to_station(0)
	check(board.cur == 0, "and back to station 1")
	board.on_go()
	check(board.cur == 1 and board.play_level.text == "PLAY LEVEL 2", "CONTINUE from station 1 reaches station 2 and Level 2")
	board.on_play_level()
	await frames(3)
	check(scene_name() == "level2_trajectory.tscn", "Level 2 opens from the level menu")
	current_scene.top_menu.request_exit()
	check(paused and current_scene.top_menu.confirming, "exit asks for confirmation while in progress")
	current_scene.top_menu.confirm_exit()
	await frames(3)
	check(scene_name() == "main_menu.tscn" and not paused, "Exit Level returns to the main menu")
	current_scene.buttons[0].pressed.emit()
	await frames(3)
	board = current_scene
	for n in 4:
		board.on_go()
	check(board.cur == 4 and board.shake > 0.0, "station 5 (the accident) shakes the map")
	board.on_go()
	board.on_go()
	check(board.cur == 6 and board.go.text == "START THE CHALLENGE", "station 7 has the COAS challenge")
	board.on_go()
	check(board.mode == "coas" and board.game_box.visible and not board.go.visible, "COAS challenge opens")
	board.go_to_station(0)
	check(board.cur == 6, "the map cannot be clicked away from under a challenge")
	var sight_before: Vector2 = board.ter
	board.nudge(Vector2(-1, 0))
	check(Sfx.history[-1][0] == "thruster", "thruster puff on a nudge")
	check(board.ter.x < sight_before.x, "nudging moves the sight")
	board.advance(1.0)
	check(board.mode == "coas" and not board.done.has(6), "COAS is not solved while off-centre")
	for k in 30:
		board.ter = Vector2.ZERO
		board.vel = Vector2.ZERO
		board.advance(0.1)
	check(board.mode == "" and board.done.has(6) and board.go.text == "CONTINUE", "holding the centre for 2 s solves it")
	board.on_go()
	board.on_go()
	check(board.cur == 8 and board.go.text == "START THE CHALLENGE", "station 9 has the dice challenge")
	board.on_go()
	Sfx.history.clear()
	board.roll_dice(1, 1)
	check(played("dice") == 1, "dice rattle on a roll")
	check("too shallow" in board.game_msg.text and board.dice_phase == "", "total 2: too shallow, roll again")
	board.roll_dice(6, 6)
	check("too steep" in board.game_msg.text and board.dice_phase == "", "total 12: too steep, roll again")
	board.roll_dice(3, 3)
	check(board.dice_phase == "good", "total 6 is accepted")
	board.advance(1.3)
	check(board.dice_phase == "silence", "radio silence follows")
	board.to_main_menu()                      # leaving in the middle of the wait must not break anything
	await frames(3)
	check(scene_name() == "main_menu.tscn", "can leave the level menu during a challenge")
	current_scene.buttons[0].pressed.emit()
	await frames(3)
	board = current_scene
	for n in 7:
		board.on_go()                         # stations 1-7, then START THE CHALLENGE
	for k in 30:
		board.ter = Vector2.ZERO
		board.vel = Vector2.ZERO
		board.advance(0.1)
	board.on_go()
	board.on_go()
	check(board.cur == 8, "back at station 9")
	board.on_go()
	board.roll_dice(2, 3)
	board.advance(1.3)
	board.advance(4.6)
	check(board.mode == "" and board.done.has(8), "dice challenge finishes after the blackout")
	board.on_go()
	check(board.cur == 9 and board.go.text == "PLAY AGAIN", "station 10 ends the journey")
	board.on_go()
	check(board.cur == 0 and board.done.is_empty(), "PLAY AGAIN starts over")
	board.on_play_level()
	await frames(3)
	check(scene_name() == "main.tscn", "Level 1 opens from the level menu")

	# ---------------- Level 1: the walk-around cabin, with sky, sound and the top bar ----------------
	var lv := current_scene
	check(lv.sky != null and lv.top_menu != null, "cabin level has the sky and the PAUSE / EXIT bar")
	check(lv.ground.get_cell_source_id(Vector2i(0, 0)) == -1 and lv.ground.get_cell_source_id(Vector2i(11, 2)) != -1,
			"outside tiles are open to the sky, floor tiles are drawn")
	check(lv.frozen, "the launch-morning mini-games still open the level")
	for n in 2:
		for c in lv.get_children():
			if c is CanvasLayer and c.has_signal("finished"):
				check(c.progress.position.x + c.progress.size.x <= 520.0, "mini-game counter clear of the top bar")
				c.dismiss()
		await frames(3)
	check(not lv.frozen, "player has control after the prologue")
	check(Sfx.is_playing("hum") and Sfx.players["hum"].volume_db <= -20.0, "quiet cabin hum loops in the Command Module")
	Sfx.history.clear()
	await create_timer(0.4).timeout
	check(played("footsteps") == 0, "no footsteps while standing still")
	lv.try_move("down")
	await frames(3)
	check(played("footsteps") == 1 and Sfx.is_playing("footsteps"), "footsteps start when the astronaut walks")
	check(Sfx.history[-1][1] >= 0.25 and Sfx.players["footsteps"].volume_db >= -3.0, "footsteps skip the silent lead-in and are loud enough")
	lv.try_move("down")
	await frames(2)
	check(played("footsteps") == 1, "footsteps are not restarted on every step")
	await create_timer(0.7).timeout
	check(not Sfx.is_playing("footsteps"), "footsteps stop when the astronaut stops")
	lv.interact_with("comm_console")
	check(played("walkie") == 1, "walkie sound when the astronaut uses the radio")
	while lv.dialog_open:
		lv._advance_dialog()
	lv.top_menu.pause()
	check(paused and lv.top_menu.pause_box.visible, "Pause works in the cabin level")
	lv.top_menu.resume()
	lv.top_menu.request_exit()
	check(lv.top_menu.confirming, "exit asks for confirmation in the cabin level")
	lv.top_menu.cancel_exit()
	check(not paused and scene_name() == "main.tscn", "STAY keeps the cabin level running")
	lv.interact_with("flight_panel")
	check(Sfx.history[-1][0] == "click", "panel click when an instrument is opened")
	while lv.dialog_open:
		lv._advance_dialog()
	lv.level_complete = true                       # (the launch itself is covered by minigame_test_2.gd)
	lv.continue_to_next_level()
	await frames(3)
	check(not Sfx.is_playing("hum"), "cabin hum stops when the level is left")
	check(scene_name() == "level2_trajectory.tscn", "Level 2 continues from the cabin level")

	# ---------------- the stand-alone radio level (kept in the project, no longer on the menu) ----------------
	change_scene_to_file("res://level1_comm.tscn")
	await frames(3)
	check(scene_name() == "level1_comm.tscn", "stand-alone radio level still opens")

	# ---------------- Level 1: radio ----------------
	var g := current_scene
	var cl: Control = g.checklist
	check(cl.items.size() == 9 and cl.done_count() == 0 and cl.current_id() == "first", "Level 1 checklist: 9 open items")
	check(not g.choose(0), "no reply possible before the channel is open")
	Sfx.history.clear()
	g.action_btn.pressed.emit()
	check(g.phase == "comm" and played("walkie") == 1 and played("radio") == 1, "PUSH TO TALK opens the channel with walkie + radio sounds")
	check(not cl.is_done("first"), "first message not ticked before it has arrived")
	g.reveal_now()
	check(cl.is_done("first") and cl.current_id() == "system", "first message ticked when received")
	var expect := {0: "system", 1: "reading", 3: "request", 4: "problem"}
	for i in g.scenarios.size():
		check(g.index == i, "on call %d" % i)
		g.reveal_now()
		var opts: Array = g.scenarios[i]["options"]
		var right := -1
		var wrong := -1
		for k in opts.size():
			if opts[k]["ok"]:
				right = k
			else:
				wrong = k
		var before: int = cl.done_count()
		check(not g.choose(wrong) and cl.done_count() == before, "wrong reply: no tick, retry allowed")
		check(g.feedback.plain.begins_with("Not the best reply"), "wrong reply is explained")
		check(g.choose(right), "right reply accepted")
		if expect.has(i):
			check(cl.is_done(expect[i]), "checklist ticks '%s'" % expect[i])
		else:
			check(cl.done_count() == before, "the broken message ticks nothing")
		g.skip_wait()
	check(played("beeps") == g.scenarios.size() - 1 and played("radio") == 2, "beeps before calls, radio static on the broken call")
	check(played("walkie") == 1 + 2 * g.scenarios.size(), "walkie sound on every reply")
	check(g.is_closing() and not cl.is_done("confirm"), "closing call incoming, not yet ticked")
	g.reveal_now()
	check(cl.is_done("confirm") and g.phase == "go" and g.action_btn.visible, "Houston's confirmation ticked; GO button shown")
	check(played("talk") == 1, "Mission Control voices during the poll")

	# pause must stop the countdown
	g.action_btn.pressed.emit()
	check(g.phase == "countdown" and not Sfx.is_playing("talk"), "countdown starts; voices stop")
	await frames(20)
	var c0: float = g.count
	g.top_menu.pause()
	check(paused and g.top_menu.is_paused and g.top_menu.pause_box.visible, "Pause shows the pause menu")
	await frames(30)
	check(is_equal_approx(g.count, c0), "countdown timer frozen while paused")
	check(Sfx.can_process() == false, "sound manager is paused with the game")
	g.top_menu.resume()
	await frames(20)
	check(not paused and g.count < c0, "Resume continues the countdown")
	g.top_menu.request_exit()
	g.top_menu.cancel_exit()
	check(not paused and scene_name() == "level1_comm.tscn", "STAY keeps the level running")

	# ---------------- Level 1: launch ----------------
	check(played("rocket") == 0 or g.ignited, "rocket sound not before ignition")
	g.advance(g.count - 8.5)
	check(g.ignited and played("rocket") == 1, "rocket sound starts at engine ignition")
	check(not cl.is_done("countdown"), "countdown not ticked early")
	g.advance(g.count + 0.01)
	check(cl.is_done("countdown") and g.phase == "ascent", "countdown complete at zero -> liftoff")
	g.advance(1.0)
	check(not cl.is_done("launch"), "launch not ticked before the tower is cleared")
	g.advance(2.5)
	check(cl.is_done("launch") and g.rocket.position.y < 14.0, "rocket lifts off and clears the tower")
	g.advance(5.0)
	check(g.sky.altitude > 0.3 and not cl.is_done("space"), "sky darkening during the climb")
	g.advance(5.0)
	check(cl.is_done("space") and cl.all_done() and g.completed and g.sky.altitude >= 0.99, "Level 1 ends in space, checklist complete")
	check(played("rocket") == 1, "rocket sound was not restarted")
	check(g.top_menu.in_progress.call() == false, "no exit confirmation once the level is complete")
	g.dismiss()
	await frames(3)
	check(scene_name() == "level2_trajectory.tscn", "Level 2 follows Level 1 directly")

	# ---------------- Level 2 ----------------
	g = current_scene
	cl = g.checklist
	Sfx.history.clear()
	check(g.stage == "orbit" and cl.is_done("start") and cl.items.size() == 6, "Level 2 starts in space (no pad, no countdown)")
	check(g.sky.altitude >= 0.8 and not g.map_group.visible, "space background from the first frame")
	check(not g.press_action(), "button locked for the first second")
	g.advance(1.1)
	check(g.press_action() and g.stage == "tli", "third stage fires")
	check(played("click") == 1 and played("rocket") == 1, "button click, and the engine is heard during the burn")
	g.advance(4.1)
	check(g.stage == "tli_done" and cl.is_done("away"), "travelling away from Earth ticked")
	check(g.press_action() and g.stage == "separate", "separation starts")
	g.advance(3.0)
	check(g.csm.flip_h and g.lm.visible, "CSM has turned around and the LM is visible")
	g.advance(3.1)
	check(g.stage == "separated" and g.sivb.position.x < 0, "spacecraft separated from the third stage")
	check(played("latch") == 2, "one latch sound for the release, one for docking")
	check(g.press_action() and g.stage == "coast" and g.map_group.visible, "trajectory map shown")
	g.advance(5.0)
	check(g.map.flown > 0.3 and g.map.flown < 0.5 and not cl.is_done("trajectory"), "trajectory line growing")
	check(played("houston") == 0 and g.csm.texture.resource_path.ends_with("csm.png"), "no explosion before the accident point")
	g.advance(5.9)
	check(g.stage == "bang" and is_equal_approx(g.map.flown, 0.8), "accident happens at 80% of the way out")
	check(cl.is_done("trajectory") and g.data_time.text == "055:54" and g.data_dist.text == "321,860 km", "mission time and distance at the accident")
	check(g.csm.texture.resource_path.ends_with("csm_damaged.png") and g.debris.size() > 0, "Service Module shown damaged with debris")
	check(played("bang") == 1 and played("vent") == 1 and played("alarm") == 0 and played("houston") == 0, "bang and venting gas first")
	g.advance(0.6)
	check(played("alarm") == 1, "master alarm follows the bang")
	g.advance(0.7)
	check(g.press_action() and g.stage == "call" and played("houston") == 1, "'Houston, we've had a problem' plays when the problem is reported")
	check(cl.is_done("explosion") and "Houston, we've had a problem." in g.feedback.plain, "famous line shown, explosion ticked")
	g.advance(5.0)
	check("Say again" in g.feedback.plain and not g.press_action(), "Mission Control's reply shown")
	g.advance(2.0)
	check(g.press_action() and g.stage == "incident" and played("talk") == 1, "incident explanation")
	g.advance(6.1)
	check(g.press_action() and g.stage == "freereturn", "free-return view")
	g.advance(4.0)
	check(g.map.returned > 0.4 and g.return_label.visible, "free-return line animating")
	g.advance(5.0)
	check(g.stage == "quiz" and not cl.is_done("freereturn"), "question asked")
	var opts2: Array = g.text["options"]
	var r2 := -1
	var w2 := -1
	for k in opts2.size():
		if opts2[k]["ok"]:
			r2 = k
		else:
			w2 = k
	check(not g.answer(w2) and not cl.is_done("freereturn"), "wrong answer explained, retry")
	check(g.answer(r2) and cl.is_done("freereturn"), "right answer ticks free-return")
	g.advance(3.1)
	check(g.completed and cl.all_done(), "Level 2 completion screen, checklist complete")
	check(played("footsteps") == 0, "footsteps are never played in these levels")
	g.dismiss()
	await frames(3)
	check(scene_name() == "main_menu.tscn", "Level 2 returns to the main menu")

	# ---------------- quit ----------------
	print("LEVELS TEST ", "PASSED" if fails == 0 else "FAILED (%d)" % fails)
	current_scene.quit_game()        # the QUIT GAME button's action ends this test run
