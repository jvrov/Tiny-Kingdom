extends SceneTree
## Real-file save tests and the complete village/expedition interaction loop.
## All files are isolated under user://tests/phase2_<process id>/.

const MAIN := preload("res://scenes/main/Main.tscn")
var game_state: Node
var test_directory: String
var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	test_directory = "user://tests/phase2_%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(test_directory)
	game_state = root.get_node("GameState")
	_test_save_validation()
	await _test_loop()
	_cleanup()
	print("Tiny Kingdom persistence: %d checks, %d passed, %d failed" % [checks, checks - failures, failures])
	quit(1 if failures else 0)


func _expect(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)


func _frames(count: int = 3) -> void:
	for index in range(count):
		await physics_frame
		await process_frame


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_expect(false, "test fixture is writable: " + path)
		return
	file.store_string(text)
	file.close()


func _test_save_validation() -> void:
	var storage := SaveSystem.new(test_directory + "/valid.json")
	_expect(storage.load_data() == SaveSystem.defaults(), "missing save loads safe defaults")
	_expect(storage.needs_save, "missing save requests automatic creation")
	var data := SaveSystem.defaults()
	data.resources = {"wood": 14, "stone": 7, "gold": 3}
	data.player = {"level": 3, "xp": 15, "max_health": 130, "damage": 26}
	data.expeditions_completed = 4
	_expect(storage.save_data(data), "native JSON save writes successfully")
	_expect(FileAccess.file_exists(storage.path), "save file exists")
	_expect(not FileAccess.file_exists(storage.path + ".tmp"), "successful atomic write leaves no temporary file")
	_expect(storage.load_data() == data, "save round trip preserves resources, attributes, XP and expedition count")
	var invalid: Array[Dictionary] = []
	var malformed := data.duplicate(true)
	malformed.resources.wood = -1
	invalid.append(malformed)
	malformed = data.duplicate(true)
	malformed.player.xp = 70
	invalid.append(malformed)
	malformed = data.duplicate(true)
	malformed.player.level = "3"
	invalid.append(malformed)
	malformed = data.duplicate(true)
	malformed.player.max_health = 0
	invalid.append(malformed)
	malformed = data.duplicate(true)
	malformed.resources.gold = 2.5
	invalid.append(malformed)
	malformed = data.duplicate(true)
	malformed.player.damage = true
	invalid.append(malformed)
	malformed = data.duplicate(true)
	malformed.erase("expeditions_completed")
	invalid.append(malformed)
	for index in range(invalid.size()):
		_expect(not storage.save_data(invalid[index]), "invalid schema %d cannot overwrite good save" % index)
	_expect(storage.load_data() == data, "invalid writes preserve the previous file")
	var corrupt := SaveSystem.new(test_directory + "/corrupt.json")
	_write(corrupt.path, "{truncated")
	_expect(corrupt.load_data() == SaveSystem.defaults(), "malformed JSON recovers without a crash")
	_expect(corrupt.needs_save and not corrupt.write_blocked, "recoverable corruption permits a new save")
	var backups := Array(DirAccess.get_files_at(test_directory)).filter(func(name): return name.begins_with("corrupt.json.corrupt-"))
	_expect(backups.size() == 1, "corrupted file is preserved as a backup")
	_expect(corrupt.save_data(SaveSystem.defaults()), "defaults can replace backed-up corruption")
	_write(corrupt.path, JSON.stringify({"version": 1, "player": []}))
	_expect(corrupt.load_data() == SaveSystem.defaults(), "wrong nested types are rejected safely")
	var future := SaveSystem.new(test_directory + "/future.json")
	var future_data := data.duplicate(true)
	future_data.version = 2
	var future_text := JSON.stringify(future_data)
	_write(future.path, future_text)
	_expect(future.load_data() == SaveSystem.defaults() and future.write_blocked,
		"unsupported save version blocks writes")
	_expect(not future.save_data(data) and FileAccess.get_file_as_string(future.path) == future_text,
		"future-version save is never silently overwritten")
	_expect(storage.erase() and not FileAccess.file_exists(storage.path), "reset utility removes the save")


func _interact(main: Node, action: String) -> bool:
	for object in get_nodes_in_group("interactables"):
		if object.action == action:
			main.player.global_position = object.global_position + Vector2(0, 65)
			return main.player.interaction.interact()
	return false


func _test_loop() -> void:
	game_state.initialize(test_directory + "/game.json")
	_expect(FileAccess.file_exists(game_state.storage.path), "GameState automatically creates its initial save")
	var main := MAIN.instantiate()
	root.add_child(main)
	current_scene = main
	await _frames()
	var player: KingdomPlayer = main.player
	_expect(main.in_village and not game_state.expedition_active, "new game starts in the village")
	_expect(get_nodes_in_group("player").size() == 1 and get_nodes_in_group("enemies").is_empty(),
		"village has one player and no enemies")
	_expect(main.get_node("Map/Village") != null, "dedicated village scene is loaded")
	_expect(player.position == Vector2(640, 440), "village spawn is correct")
	_expect(player.get_node("Camera2D").limit_right == 1280, "camera uses village limits")
	_expect(main.hud.get_node("Root/SuppliesPanel/Supplies/SuppliesTitle").text.begins_with("ARMAZENADO"),
		"village HUD labels permanent resources")
	_expect(not player.interaction.interact(), "interaction outside all ranges has no effect")
	_expect(_interact(main, "depart"), "portal accepts the shared interaction entry point")
	_expect(not main.start_expedition(), "repeated departure during transition is rejected")
	await _frames()
	_expect(not main.in_village and game_state.expedition_active, "portal loads exploration")
	_expect(get_nodes_in_group("player").size() == 1 and get_nodes_in_group("enemies").size() == 12,
		"map change keeps one player and creates 12 enemies")
	_expect(player.position == Vector2(600, 900) and player.get_node("Camera2D").limit_right == 2600,
		"exploration spawn and camera limits are correct")
	_expect(main.hud.get_node("Root/SuppliesPanel/Supplies/SuppliesTitle").text.begins_with("CARREGANDO"),
		"exploration HUD labels temporary cargo")
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	var enemy: KingdomEnemy = get_nodes_in_group("enemies")[0]
	enemy.drop_chance = 1.0
	enemy.take_damage(1000, player)
	_expect(game_state.has_cargo() and game_state.progression.xp == 15,
		"enemy kill feeds temporary cargo and persistent XP")
	_expect(game_state.village_resources == {"wood": 0, "stone": 0, "gold": 0},
		"loot does not enter the permanent bank before deposit")
	player.add_resource("wood", 4)
	player.add_resource("stone", 3)
	player.add_resource("gold", 2)
	player.gain_experience(22)
	var carried := player.resources.duplicate()
	var progress: Dictionary = game_state.progression.duplicate()
	var on_disk := SaveSystem.new(game_state.storage.path).load_data()
	_expect(on_disk.player == progress and progress.level == 2 and progress.xp == 7,
		"XP and level save immediately during exploration")
	_expect(not on_disk.has("expedition_resources") and on_disk.resources.wood == 0,
		"carried resources are excluded from the persistent save")
	_expect(not main.deposit_resources(), "deposit cannot run from exploration")
	_expect(_interact(main, "return"), "return marker accepts interaction")
	_expect(not main.return_to_village(), "duplicate return cannot double-count expeditions")
	await _frames()
	_expect(main.in_village and player.resources == carried, "return preserves undeployed cargo")
	_expect(game_state.expeditions_completed == 1 and not game_state.expedition_active,
		"a living return completes exactly one expedition")
	_expect(player.level == 2 and player.current_health == 115, "village restores health and persistent attributes")
	_expect(not main.start_expedition() and player.resources == carried,
		"departure with cargo is blocked without discarding it")
	_expect(main.hud.objective_text.text.contains("CONCLUÍDAS: 1"), "village HUD updates expedition count")
	# Block only the temporary save file to exercise a real filesystem write failure.
	DirAccess.make_dir_absolute(game_state.storage.path + ".tmp")
	_expect(not main.deposit_resources(), "failed disk write prevents deposit")
	_expect(player.resources == carried and game_state.village_resources.wood == 0,
		"failed deposit preserves cargo and rolls back bank")
	_expect(SaveSystem.new(game_state.storage.path).load_data().resources.wood == 0,
		"failed disk write leaves the previous permanent save intact")
	_expect(not game_state.save_status.is_empty(), "save failure is visible to the player")
	DirAccess.remove_absolute(game_state.storage.path + ".tmp")
	_expect(_interact(main, "deposit"), "deposit uses the same reusable interaction system")
	_expect(game_state.village_resources == carried and not game_state.has_cargo(),
		"deposit transfers all three resources exactly once")
	_expect(player.resources == {"wood": 0, "stone": 0, "gold": 0}, "successful deposit empties player inventory")
	_expect(game_state.save_status.is_empty(), "successful retry clears save error")
	_expect(main.hud.toast.text.contains("Recursos depositados!"), "deposit displays success feedback")
	_expect(not main.deposit_resources() and game_state.village_resources == carried, "empty deposit cannot duplicate resources")
	on_disk = SaveSystem.new(game_state.storage.path).load_data()
	_expect(on_disk.resources == carried and on_disk.player == progress and on_disk.expeditions_completed == 1,
		"deposit persists bank, progression and expedition count")
	var child_output: Array = []
	var exit_code := OS.execute(OS.get_executable_path(), PackedStringArray([
		"--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://tests/persistence_probe.gd", "--",
		game_state.storage.path, Marshalls.utf8_to_base64(JSON.stringify(game_state.snapshot()))
	]), child_output, true)
	_expect(exit_code == 0, "a fresh Godot process restores deposited resources and progression")
	if exit_code != 0:
		print(child_output)
	_expect(_interact(main, "depart"), "second expedition can start after deposit")
	await _frames()
	_expect(not game_state.has_cargo() and player.level == 2 and player.damage == 22,
		"next expedition starts empty with permanent upgrades")
	player.add_resource("gold", 20)
	player.gain_experience(5)
	progress = game_state.progression.duplicate()
	player.take_damage(10000)
	_expect(main.dying and not game_state.has_cargo(), "death immediately loses temporary cargo")
	_expect(game_state.village_resources == carried and game_state.progression == progress,
		"death preserves permanent resources and XP")
	_expect(main.hud.result_description.text.contains("não depositados foram perdidos"),
		"death explains the lost cargo")
	_expect(not player.interaction.interact(), "dead player cannot use a portal")
	await _frames(130)
	_expect(main.in_village and player.current_health == player.max_health,
		"death automatically returns and heals after brief feedback")
	_expect(game_state.expeditions_completed == 1, "failed expedition does not count as completed")
	_expect(get_nodes_in_group("player").size() == 1 and get_nodes_in_group("enemies").is_empty(),
		"death transition leaves no duplicate player or enemies")
	on_disk = SaveSystem.new(game_state.storage.path).load_data()
	_expect(on_disk.resources == carried and on_disk.player == progress, "death does not erase the permanent save")
	# Keyboard action is centralized, and reset requires an explicit confirmation.
	var reset_event := InputEventAction.new()
	reset_event.action = "debug_reset"
	reset_event.pressed = true
	main._unhandled_input(reset_event)
	var dialog: ConfirmationDialog = main.hud.get_node("ResetConfirmation")
	_expect(dialog.visible and paused, "F9 opens a confirmation and pauses gameplay")
	dialog.canceled.emit()
	dialog.hide()
	_expect(not paused and game_state.village_resources == carried, "canceling reset preserves progress and resumes")
	main._unhandled_input(reset_event)
	dialog.confirmed.emit()
	dialog.hide()
	await _frames()
	_expect(not paused and main.in_village and player.level == 1 and player.current_health == 100,
		"confirmed development reset restores village and default player")
	_expect(game_state.snapshot() == SaveSystem.defaults() and not game_state.has_cargo(),
		"reset clears bank, cargo, progression and expedition count")
	_expect(SaveSystem.new(game_state.storage.path).load_data() == SaveSystem.defaults(),
		"reset replaces the deleted save with default progress")
	player.position = Vector2(940, 450)
	await _frames()
	_expect(main.hud.get_node("Root/InteractionPrompt").text.contains("E — Iniciar expedição"),
		"nearby portal displays its interaction prompt")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_E
	key.pressed = true
	root.push_input(key)
	key = InputEventKey.new()
	key.physical_keycode = KEY_E
	key.pressed = false
	root.push_input(key)
	await _frames()
	_expect(not main.in_village and game_state.expedition_active,
		"physical E travels through the viewport input pipeline to the portal")
	current_scene = null
	main.queue_free()
	await _frames()


func _cleanup() -> void:
	for filename in DirAccess.get_files_at(test_directory):
		DirAccess.remove_absolute(test_directory.path_join(filename))
	DirAccess.remove_absolute(test_directory)
