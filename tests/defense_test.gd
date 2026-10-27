extends SceneTree
## Real scenes, real files, deterministic wave clocks and a fresh-process reload.
const MAIN := preload("res://scenes/main/Main.tscn")
const ENEMY := preload("res://scenes/enemies/Enemy.tscn")
var state: Node
var directory: String
var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


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


func _write(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()


func _run() -> void:
	directory = "user://tests/defense_%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(directory)
	state = root.get_node("GameState")
	_test_migrations()
	state.initialize(directory + "/game.json")
	await _test_defense()
	for name in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(name))
	DirAccess.remove_absolute(directory)
	print("Tiny Kingdom defense: %d checks, %d passed, %d failed" % [checks, checks - failures, failures])
	quit(1 if failures else 0)


func _test_migrations() -> void:
	var v2 := SaveSystem.defaults()
	v2.version = 2
	v2.erase("defenses_completed")
	v2.resources = {"wood": 98, "stone": 76, "gold": 54}
	v2.player = {"level": 4, "xp": 12, "max_health": 145, "damage": 42}
	v2.expeditions_completed = 9
	v2.weapon_level = 3
	for id in BuildingData.IDS:
		v2.buildings[id].level = 1
	var path := directory + "/v2.json"
	_write(path, v2)
	var storage := SaveSystem.new(path)
	var migrated := storage.load_data()
	_expect(migrated.version == SaveSystem.VERSION and migrated.defenses_completed == 0, "v2 migrates to v3 with zero defenses")
	_expect(migrated.resources == v2.resources and migrated.player == v2.player, "v2 resources and all player attributes survive")
	_expect(migrated.buildings == v2.buildings and migrated.weapon_level == 3 and migrated.expeditions_completed == 9,
		"v2 buildings, positions, weapon and expeditions survive")
	var backups := Array(DirAccess.get_files_at(directory)).filter(func(name): return name.begins_with("v2.json.v2-"))
	_expect(backups.size() == 1 and FileAccess.get_file_as_string(directory.path_join(backups[0])) == FileAccess.get_file_as_string(path),
		"v2 original is backed up byte for byte")
	DirAccess.make_dir_absolute(path + ".tmp")
	_expect(not storage.save_data(migrated) and JSON.parse_string(FileAccess.get_file_as_string(path)).version == 2,
		"failed v2 migration write leaves original intact")
	DirAccess.remove_absolute(path + ".tmp")
	_expect(storage.save_data(migrated) and storage.load_data() == migrated and not storage.needs_save,
		"v3 round trip needs no second migration")
	var v1 := v2.duplicate(true)
	v1.version = 1
	v1.erase("buildings")
	v1.erase("weapon_level")
	v1.player.damage = 30
	path = directory + "/v1.json"
	_write(path, v1)
	storage = SaveSystem.new(path)
	migrated = storage.load_data()
	_expect(migrated.version == SaveSystem.VERSION and migrated.defenses_completed == 0 and migrated.weapon_level == 0,
		"v1 passes through both schema migrations to v3")
	_expect(migrated.player == v1.player and migrated.resources == v1.resources and migrated.expeditions_completed == 9,
		"v1 migration preserves all original progress")
	_expect(migrated.buildings == BuildingData.default_state() and storage.save_data(migrated), "v1 gains empty plots and persists v3")
	var bad := SaveSystem.defaults()
	bad.erase("defenses_completed")
	_expect(not SaveSystem.valid_data(bad), "v3 requires defense counter")
	for value in [-1, 1.5, true, "2", SaveSystem.MAX_VALUE + 1]:
		bad = SaveSystem.defaults()
		bad.defenses_completed = value
		_expect(not SaveSystem.valid_data(bad), "invalid defense counter rejected: " + str(value))
	v2.buildings.archer_tower.level = 99
	_write(directory + "/bad_v2.json", v2)
	storage = SaveSystem.new(directory + "/bad_v2.json")
	_expect(storage.load_data() == SaveSystem.defaults() and storage.needs_save, "migration still validates legacy building schema")


func _confirm(main: Node) -> void:
	var dialog: ConfirmationDialog = main.hud.get_node("DefenseConfirmation")
	dialog.confirmed.emit()
	dialog.hide()


func _freeze(waves: WaveManager) -> void:
	for enemy in waves.enemies.values():
		enemy.set_physics_process(false)


func _clear_wave(waves: WaveManager) -> void:
	for enemy in waves.enemies.values():
		enemy.take_damage(10000)


func _test_defense() -> void:
	var main := MAIN.instantiate()
	root.add_child(main)
	current_scene = main
	await _frames()
	var waves: WaveManager = main.waves
	var player: KingdomPlayer = main.player
	var hall: VillageBuilding = main.get_node("Map/Village/TownHall")
	var smith: VillageBuilding = main.get_node("Map/Village/Blacksmith")
	var tower: VillageBuilding = main.get_node("Map/Village/ArcherTower")
	var bell: KingdomInteractable = main.get_node("Map/Village/DefenseFlag")
	var dialog: ConfirmationDialog = main.hud.get_node("DefenseConfirmation")
	_expect(waves.state == WaveManager.State.IDLE and not state.defense_busy(), "defense begins idle and never automatically starts")
	_expect(not main.request_defense() and main.hud.toast.text == "Construa a Prefeitura primeiro.", "Town Hall is required with clear feedback")
	_expect(not dialog.visible and get_nodes_in_group("enemies").is_empty(), "blocked defense creates no dialog or enemies")
	state.village_resources = {"wood": 500, "stone": 500, "gold": 500}
	state.persist()
	state.purchase_building("town_hall", "build", 0)
	player.position = bell.position + Vector2(0, 65)
	_expect(player.interaction.interact(), "existing E interaction can reach defense marker")
	_expect(dialog.visible and paused and waves.state == WaveManager.State.PREPARING, "marker opens a paused confirmation")
	_expect(state.defense_busy() and not state.begin_expedition(), "preparation locks departure centrally")
	dialog.canceled.emit()
	dialog.hide()
	_expect(not paused and waves.state == WaveManager.State.IDLE and waves.enemies.is_empty(), "canceling confirmation returns to idle without spawning")
	_expect(main.request_defense(), "defense can prepare with Town Hall alone")
	_confirm(main)
	_expect(waves.is_battle() and not paused and waves.wave == 1, "confirmation starts wave one without requiring a tower")
	_expect(hall.current_health == 300 and hall.defending, "Town Hall starts defense at 300 HP")
	_expect(main.hud.get_node("Root/DefensePanel").visible and main.get_node("Map/Village").under_attack, "defense HUD and village alert are active")
	waves.set_physics_process(false)
	player.set_physics_process(false)
	_expect(waves.COUNTS == [5, 7, 9, 12, 15], "five waves use 5, 7, 9, 12 and 15 enemies")
	var snapshot: Dictionary = state.snapshot()
	player.add_resource("gold", 4)
	_expect(not main.start_expedition() and not main.deposit_resources() and not main.request_defense(), "departure, deposit and nested defense are blocked")
	_expect(main.hud.toast.text == "A vila está sob ataque!", "blocked interaction explains the attack")
	_expect(not state.begin_expedition() and not state.deposit() and not state.spend_resources({"wood": 1}), "state rejects direct expedition, deposit and spending")
	_expect(not state.purchase_building("blacksmith", "build", 0) and state.snapshot() == snapshot, "construction blocked without consuming resources")
	main._on_building_interacted(player, smith)
	_expect(not main.hud.building_panel.visible and not paused, "building interaction cannot pause battle with a construction panel")
	_expect(not waves.start(), "duplicate start cannot restart or duplicate wave")
	player.position = WaveManager.SPAWNS[0]
	var chosen := waves.choose_spawn(0)
	_expect(chosen.distance_to(player.position) >= 220, "spawn skips entry occupied by player")
	player.position = Vector2(420, 555)
	waves._physics_process(0.01)
	_expect(waves.spawned == 1 and waves.enemies.size() == 1, "first enemy spawns at start")
	var first: KingdomEnemy = waves.enemies.values()[0]
	_expect(first.position == WaveManager.SPAWNS[0] and first.invading, "invasion starts on a fixed border point")
	_expect(first.max_health == 30 and first.damage == 5 and first.speed == 72, "first-wave baseline is modest")
	_freeze(waves)
	waves._physics_process(0.3)
	_expect(waves.spawned == 1, "spawns respect their interval")
	waves._physics_process(0.51)
	_expect(waves.spawned == 2 and waves.enemies.size() == 2, "next interval spawns exactly one enemy")
	_freeze(waves)
	_expect(waves.enemies.values()[1].position == WaveManager.SPAWNS[1], "spawn entries rotate around village")
	_clear_wave(waves)
	_expect(waves.state == WaveManager.State.ACTIVE and waves.enemies.is_empty(), "zero living enemies does not finish a partially spawned wave")
	for index in range(3):
		waves._physics_process(0.81)
		_freeze(waves)
	_clear_wave(waves)
	_expect(waves.state == WaveManager.State.BETWEEN_WAVES and waves.countdown == 5, "completed spawn budget and kills trigger five-second interval")
	_expect(main.hud.get_node("Root/DefensePanel/Content/DefenseText").text.contains("Próxima onda em: 5"), "HUD shows inter-wave countdown")
	_expect(not main.start_expedition(), "inter-wave period also locks interactions")
	waves._physics_process(4)
	_expect(waves.wave == 1 and waves.countdown == 1, "next wave waits the full interval")
	waves._physics_process(1)
	_expect(waves.wave == 2 and waves.state == WaveManager.State.ACTIVE, "countdown starts wave two")
	var before_defeat: Dictionary = state.snapshot()
	hall.take_damage(55)
	_expect(hall.current_health == 245 and main.hud.get_node("Root/DefensePanel/Content/DefenseText").text.contains("245 / 300"), "Town Hall damage updates HUD")
	hall.take_damage(10000)
	_expect(waves.state == WaveManager.State.DEFEAT and not state.defense_busy(), "Town Hall zero HP ends defense immediately")
	_expect(state.snapshot() == before_defeat and state.defenses_completed == 0, "defeat neither removes progress nor grants rewards")
	_expect(hall.current_health == 300 and not hall.defending and waves.enemies.is_empty(), "defeat restores structures and removes invaders")
	_expect(not main.hud.get_node("Root/DefensePanel").visible and not main.get_node("Map/Village").under_attack, "defeat hides battle HUD and alert")
	_expect(player.resources.gold == 4 and player.is_alive(), "preexisting carried resources survive defense")
	_expect(main.deposit_resources(), "deposit works again after defeat")
	state.purchase_building("blacksmith", "build", 0)
	state.purchase_building("archer_tower", "build", 0)
	state.purchase_building("blacksmith", "upgrade", 0)
	tower.set_physics_process(false)
	_expect(main.request_defense(), "new defense starts after a defeat")
	_confirm(main)
	_expect(not state.purchase_building("blacksmith", "upgrade", 1), "weapon upgrade is blocked during defense")
	# A real invader exercises targeting/movement and both damage recipients.
	var enemy := ENEMY.instantiate() as KingdomEnemy
	enemy.invading = true
	enemy.defending_player = player
	enemy.defended_hall = hall
	enemy.position = Vector2(640, 45)
	main.get_node("Actors").add_child(enemy)
	player.position = Vector2(100, 100)
	_expect(enemy.select_defense_target() == hall, "distant invader advances toward Town Hall")
	var start := enemy.position
	await _frames(30)
	_expect(enemy.position.y > start.y, "real physics moves invader into village")
	enemy.set_physics_process(false)
	enemy.position = smith.position + Vector2(37, 0)
	player.position = Vector2(640, 440)
	_expect(enemy.select_defense_target() == smith, "nearby built structure becomes a target")
	enemy._physics_process(0.02)
	_expect(smith.current_health == smith.max_health - enemy.damage, "invader damages a nearby structure")
	player.position = enemy.position + Vector2(0, 37)
	_expect(enemy.select_defense_target() == player, "nearby living player takes target priority")
	enemy._physics_process(1.2)
	_expect(player.current_health == player.max_health - enemy.damage, "invader deals contact damage to player")
	var bank: Dictionary = state.village_resources.duplicate()
	var cargo := player.resources.duplicate()
	var xp := player.experience
	enemy.drop_chance = 1.0
	enemy.take_damage(10000, player)
	_expect(player.experience != xp or player.level > 1, "player receives XP from invasion kills")
	_expect(player.resources == cargo and state.village_resources == bank, "invasion kill never drops resources even at guaranteed drop chance")
	var after_xp: Dictionary = state.progression.duplicate()
	enemy.take_damage(10000, player)
	_expect(state.progression == after_xp, "duplicate lethal hit grants no second XP")
	enemy = ENEMY.instantiate() as KingdomEnemy
	enemy.invading = true
	enemy.defending_player = player
	enemy.defended_hall = hall
	enemy.position = tower.position + Vector2(-100, 0)
	main.get_node("Actors").add_child(enemy)
	enemy.set_physics_process(false)
	_expect(tower.nearest_enemy() == enemy, "existing tower selects invader in range")
	tower._remaining = 0
	tower._physics_process(0.01)
	_expect(enemy.current_health == 26, "existing tower damages invader by ten")
	tower.take_damage(10000)
	_expect(not tower.is_alive() and tower.level == 1, "zero HP disables tower without deleting construction")
	tower._physics_process(2)
	_expect(enemy.current_health == 26, "disabled tower stops firing")
	smith.take_damage(10000)
	_expect(not smith.is_alive() and smith.level == 1, "blacksmith can be incapacitated temporarily")
	player.take_damage(10000)
	_expect(not player.is_alive() and waves.respawn_remaining == 5 and waves.is_battle(), "player death schedules five-second respawn without ending defense")
	_expect(not main.dying and not player.interaction.enabled, "defense death does not enter expedition-return flow")
	var progress_dead: Dictionary = state.snapshot()
	waves._physics_process(4.9)
	_freeze(waves)
	_expect(not player.is_alive(), "respawn does not occur early")
	waves._physics_process(0.11)
	_freeze(waves)
	_expect(player.is_alive() and player.current_health == player.max_health and player.position == Vector2(640, 440), "respawn returns player to center at full health")
	_expect(state.snapshot() == progress_dead and player.resources == cargo, "respawn preserves XP, bank and cargo without reward duplication")
	enemy.take_damage(10000)
	_expect(state.progression == after_xp, "tower-style unattributed kill grants no player XP")
	hall.take_damage(10000)
	_expect(tower.is_alive() and smith.is_alive() and tower.current_health == tower.max_health, "battle end restores disabled structures")
	await _frames()
	# All five waves, exact reward, write failure/retry and replay protection.
	_expect(main.request_defense(), "full five-wave defense can start")
	_confirm(main)
	var baseline: Dictionary = state.snapshot()
	var total := 0
	for number in range(1, 6):
		_expect(waves.wave == number and waves.state == WaveManager.State.ACTIVE, "expected wave %d starts" % number)
		for index in range(WaveManager.COUNTS[number - 1]):
			waves._physics_process(0.81)
			_freeze(waves)
		total += waves.spawned
		_expect(waves.enemies.size() == WaveManager.COUNTS[number - 1], "wave %d spawns its exact enemy budget" % number)
		if number == 5:
			DirAccess.make_dir_absolute(state.storage.path + ".tmp")
		_clear_wave(waves)
		if number < 5:
			waves._physics_process(5)
	_expect(total == 48 and waves.state == WaveManager.State.VICTORY, "all 48 enemies across five waves produce victory")
	_expect(waves.reward_pending and state.snapshot() == baseline, "failed victory save keeps reward pending and live progress unchanged")
	_expect(SaveSystem.new(state.storage.path).load_data() == baseline, "failed victory save preserves disk progress")
	_expect(not main.start_expedition(), "pending reward cannot be abandoned through departure")
	_expect(not waves.prepare(player, main.get_node("Actors"), hall), "pending reward blocks a new defense")
	DirAccess.remove_absolute(state.storage.path + ".tmp")
	_expect(main.request_defense(), "marker retries a pending victory reward")
	_expect(state.defenses_completed == 1 and not waves.reward_pending, "successful reward increments defense counter exactly once")
	_expect(state.village_resources == {"wood": baseline.resources.wood + 20, "stone": baseline.resources.stone + 15, "gold": baseline.resources.gold + 10},
		"reward goes directly to permanent bank with exact amounts")
	_expect(player.resources == cargo, "reward does not enter temporary cargo")
	var paid: Dictionary = state.snapshot()
	_expect(not waves.claim_reward() and not state.commit_defense_reward() and state.snapshot() == paid, "repeated claim cannot duplicate reward")
	_expect(main.hud.toast.text.contains("Vila defendida!"), "victory feedback is shown")
	_expect(SaveSystem.new(state.storage.path).load_data() == paid, "reward and counter persist together")
	var output: Array = []
	var code := OS.execute(OS.get_executable_path(), PackedStringArray([
		"--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://tests/persistence_probe.gd", "--", state.storage.path,
		Marshalls.utf8_to_base64(JSON.stringify(paid))
	]), output, true)
	_expect(code == 0, "fresh process restores v3 progress without battle or duplicate rewards")
	if code != 0:
		print(output)
	_expect(WaveManager.enemy_stats(1, 1).health > WaveManager.enemy_stats(1, 0).health, "completed defenses increase invader health")
	_expect(WaveManager.enemy_stats(5, 0).damage > WaveManager.enemy_stats(1, 0).damage, "later waves increase enemy damage")
	_expect(WaveManager.enemy_stats(5, 10) == WaveManager.enemy_stats(5, 100000), "scaling stops after ten completed defenses")
	_expect(WaveManager.enemy_stats(5, 10).health == 69 and WaveManager.enemy_stats(5, 10).damage == 12, "maximum difficulty stays bounded")
	_expect(main.request_defense(), "victory permits another defense")
	_confirm(main)
	waves._physics_process(0.01)
	_freeze(waves)
	_expect(waves.enemies.values()[0].max_health == WaveManager.enemy_stats(1, 1).health, "next defense actually applies completed-defense scaling")
	player.take_damage(10000)
	main.reset_progress()
	await _frames()
	_expect(waves.state == WaveManager.State.IDLE and not state.defense_busy() and waves.enemies.is_empty(), "debug reset cancels spawning and respawn")
	_expect(state.snapshot() == SaveSystem.defaults() and not waves.reward_pending, "debug reset clears defense counter and pending reward")
	_expect(get_nodes_in_group("enemies").is_empty() and get_nodes_in_group("player").size() == 1, "reset leaves no stale invaders or duplicate player")
	current_scene = null
	main.queue_free()
	await _frames()
	_expect(not state.defense_busy(), "removing coordinator clears transient defense state")
