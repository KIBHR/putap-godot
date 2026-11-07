extends SceneTree

var game
var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func key(code: Key, pressed: bool, physical: Key = KEY_NONE) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = physical
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func tick(count: int = 1) -> void:
	for i in count:
		game._process(game.frametime)

func release_actions() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down", "jump"]:
		Input.action_release(action)

func start_level(number: int) -> void:
	release_actions()
	game.level_num = number
	game.restart_level()
	game.set_game_mode(game.GM_ROUND)
	game.animations = [[0], [0]]
	for voice in game.playnik.voices:
		voice.queue.clear()

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	await process_frame
	check(game.game_mode == game.GM_TITLE, "The title screen must open on startup")
	# Regression: Space and arrows are gameplay keys, not window-button shortcuts.
	var controls = game.get_node("WindowControls")
	var test_toolbar := HBoxContainer.new()
	for caption in ["Окно", "Весь экран", "Выход"]:
		controls.add_button(test_toolbar, caption, "", Callable(game, "restart_game"))
		var button := test_toolbar.get_child(test_toolbar.get_child_count() - 1) as Button
		check(button.focus_mode == Control.FOCUS_NONE, "Window button %s must not steal arrows or Space" % caption)
	test_toolbar.free()

	check(game.tilemap.get_used_cells().size() == 1024, "The complete screen must render on startup")
	check(game.playnik.playback != null and game.playnik.player.playing, "Procedural audio must start")
	check(load("res://default_env.tres") is Environment, "The migrated environment must load")
	var atlas = game.tilemap.tile_set.get_source(0)
	for code in range(32, 162):
		check(atlas.has_tile(game.code_to_subtile(code)), "Missing atlas tile %d" % code)

	key(KEY_SPACE, true)
	tick()
	key(KEY_SPACE, false)
	check(game.game_mode == game.GM_ROUND and game.level_num == 1, "Space must start the game")

	# Pausing freezes the SceneTree, and the controls can still unpause it.
	check(controls.process_mode == Node.PROCESS_MODE_ALWAYS, "Controls must process while paused")
	check(not paused, "SceneTree should start unpaused")
	controls._toggle_pause()
	check(paused, "Pause button must pause the game")
	controls._toggle_pause()
	check(not paused, "Pressing pause again must resume the game")

	# Sound toggle must affect the actual Master output and be reversible.
	var master_bus := AudioServer.get_bus_index("Master")
	if master_bus >= 0:
		var initially_muted := AudioServer.is_bus_mute(master_bus)
		controls._toggle_sound()
		check(AudioServer.is_bus_mute(master_bus) != initially_muted, "Sound button must toggle Master mute")
		controls._toggle_sound()
		check(AudioServer.is_bus_mute(master_bus) == initially_muted, "Sound button must restore Master mute")



	# Save/load tests use their own file, never the player's real save.
	var old_path: String = game.save_path
	game.save_path = "user://potap-smoke-test-save.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.save_path))
	check(not game.has_saved_game(), "A missing save must not be considered valid")

	game.player_xy = Vector2i(4, 4)
	game.score = 137
	game.remaining = 5
	game.cles = 2
	game.timer = 67
	game.set_bigtile(4, 4, 1)
	game.potap1.position = Vector2(32, 32)
	game.potap1.visible = true
	check(game.save_game(), "Saving the current round must succeed")
	check(game.has_saved_game(), "The save file must be readable")
	game.start_new_game()
	check(game.has_saved_game(), "Starting a new game must not delete the saved game")
	check(game.load_game(), "Loading the saved game must succeed")
	check(game.level_num == 1 and game.score == 137, "Level and score must be restored")
	check(game.remaining == 5 and game.cles == 2 and game.timer == 67, "Lives, keys and timer must be restored")
	check(game.player_xy == Vector2i(4, 4) and game.screen[4][4] == 0x20, "Player position and changed map must be restored")
	check(game.potap1.visible and game.potap1.position == Vector2(32, 32), "Sprite state must be restored")
	check(game.game_mode == game.GM_ROUND and not paused, "Restored game must be running")

	# A fresh scene can continue from the same file after the previous one exits.
	var resumed = load("res://main.tscn").instantiate()
	root.add_child(resumed)
	resumed.set_process(false)
	await process_frame
	resumed.save_path = game.save_path
	check(resumed.load_game(), "A fresh game instance must find the previous save")
	check(resumed.score == 137 and resumed.player_xy == Vector2i(4, 4), "Continue must restore the previous position and score")
	resumed.queue_free()
	await process_frame

	# Invalid saves are rejected without replacing the current state.
	var invalid_file := FileAccess.open(game.save_path, FileAccess.WRITE)
	invalid_file.store_string("{broken")
	invalid_file.close()
	var before_invalid_score: int = game.score
	check(not game.load_game(), "Corrupt save data must be rejected")
	check(game.score == before_invalid_score, "Corrupt save must not mutate the game")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.save_path))
	game.save_path = old_path

	# Reinitialize game before the movement, collection and enemy tests.
	game.restart_game()
	game.set_game_mode(game.GM_ROUND)

	game.player_xy = Vector2i(4, 4)
	game.jump = 1
	key(KEY_RIGHT, true)
	key(KEY_SHIFT, true)
	tick()
	check(game.player_xy == Vector2i(5, 3), "Right and Shift must move and jump together")
	key(KEY_RIGHT, false)
	key(KEY_SHIFT, false)
	key(KEY_NONE, true, KEY_A)
	check(Input.is_action_pressed("move_left"), "Physical A must work independently of keyboard layout")
	key(KEY_NONE, false, KEY_A)
	key(KEY_DOWN, true)
	check(Input.is_action_pressed("move_down"), "Down must activate the use action")
	key(KEY_DOWN, false)
	key(KEY_ALT, true)
	check(Input.is_action_pressed("jump"), "Alt must remain a jump key")
	key(KEY_ALT, false)
	key(KEY_CTRL, true)
	check(Input.is_action_pressed("jump"), "Control must remain a jump key")
	key(KEY_CTRL, false)

	start_level(1)
	game.player_xy = Vector2i(4, 4)
	var old_score: int = game.score
	game.set_bigtile(4, 4, 10)
	game.pickup_stuff()
	check(game.score == old_score + 10, "Collecting cherries must award points")
	check(game.screen[5][4] == 0x20, "Collected fruit must disappear")
	game.set_bigtile(4, 4, 7)
	game.pickup_stuff()
	check(game.cles == 1, "A bead must add a key")
	game.set_bigtile(4, 6, 8)
	key(KEY_DOWN, true)
	tick()
	key(KEY_DOWN, false)
	check(game.cles == 0 and game.open_locks == 1, "Down must insert a key into a lock")
	check(game.screen[game.exit_xy.y + 1][game.exit_xy.x] == 0x74, "Unlocking must open the exit")
	game.player_xy = game.exit_xy
	game.pickup_stuff()
	check(game.game_mode == game.GM_EXITBONUS, "Entering the exit must start the bonus")
	check(game.potap1.frame == 6, "The exit pose must use a valid sprite frame")
	game.timer = 280
	tick(2)
	check(game.level_num == 2 and game.game_mode == game.GM_ROUND, "The exit bonus must advance the level")

	start_level(1)
	var old_lives: int = game.remaining
	game.player_xy = Vector2i(4, 4)
	game.set_bigtile(4, 4, 6)
	game.test_collision()
	check(game.game_mode == game.GM_DEATH, "Fire must trigger death")
	tick(20)
	check(game.game_mode == game.GM_ROUND and game.remaining == old_lives - 1, "Death must restart the level and remove a life")
	game.remaining = 0
	game.set_game_mode(game.GM_DEATH)
	for i in 60:
		if game.game_mode == game.GM_HISCORE:
			break
		tick()
	check(game.game_mode == game.GM_HISCORE, "The final death must reach game over")
	tick(26)
	check(game.game_mode == game.GM_TITLE, "Game over must return to the title")

	start_level(1)
	game.timer = 280
	game.process_time()
	check(game.foe[1][0] == game.FS_SUN_APPROACH, "Timeout must spawn the pursuing enemy")
	for i in 50:
		game.process_foe(1)
		game.process_foe(2)
	check(game.game_mode == game.GM_DEATH, "The pursuing enemy must eventually reach the player")

	var random := RandomNumberGenerator.new()
	random.seed = 472
	for number in range(1, 16):
		start_level(number)
		game.remaining = 100
		for frame in 180:
			for action in ["move_left", "move_right", "move_down", "jump"]:
				Input.action_release(action)
			var direction: int = random.randi_range(0, 2)
			if direction < 2:
				Input.action_press("move_left" if direction == 0 else "move_right")
			if random.randf() < 0.6:
				Input.action_press("jump")
			if random.randf() < 0.15:
				Input.action_press("move_down")
			tick()
			check(game.player_xy.x >= 0 and game.player_xy.x <= 30, "Player escaped level %d horizontally" % number)
			check(game.player_xy.y >= 0 and game.player_xy.y <= 20, "Player escaped level %d vertically" % number)
		game.flush_screen()
		for coords in game.tilemap.get_used_cells():
			check(atlas.has_tile(game.tilemap.get_cell_atlas_coords(coords)), "Level %d contains an invalid rendered tile" % number)
		print("Level %d: simulated 180 game ticks" % number)

	start_level(15)
	game.set_game_mode(game.GM_EXITBONUS)
	game.timer = 280
	tick(2)
	check(game.game_mode == game.GM_WIN, "Finishing level 15 must open the victory screen")
	old_score = game.score
	tick(28)
	check(game.game_mode == game.GM_HISCORE and game.score == old_score + 5000, "Victory must award the final bonus")

	var voice = load("res://Play.gd").Voice.new()
	voice.queue.append([440.0, 0.05, 1.0])
	voice.queue.append([660.0, 0.05, 0.5])
	var buffer: Array = []
	buffer.resize(4096)
	buffer.fill(Vector2.ZERO)
	voice.fill(buffer)
	check(voice.queue.is_empty(), "The audio queue must advance through fractional-sample note lengths")
	check(buffer.any(func(sample): return sample.length_squared() > 0.0), "Queued notes must produce audio samples")
	game.playnik.beepq(0, 440.0, 0.05)
	buffer.fill(Vector2.ZERO)
	game.playnik.voices[0].fill(buffer)

	release_actions()
	game.queue_free()
	game = null
	atlas = null
	await process_frame
	await create_timer(0.1).timeout
	if failures.is_empty():
		print("PASS: startup, keyboard, movement, jumping, pickups, locks, exits, death, timeout, 15 levels, victory and audio")
	quit(0 if failures.is_empty() else 1)
