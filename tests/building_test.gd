extends SceneTree
## Real migration, transactions, UI/input, damage persistence and tower combat.
## Isolated files only; this suite never opens the player's actual save slot.

const MAIN := preload("res://scenes/main/Main.tscn")
const ENEMY := preload("res://scenes/enemies/Enemy.tscn")
var state: Node
var directory: String
var checks := 0
var failures := 0
var legacy := {
	"version": 1,
	"resources": {"wood": 200, "stone": 220, "gold": 100},
	"player": {"level": 4, "xp": 17, "max_health": 145, "damage": 30},
	"expeditions_completed": 7
}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	directory = "user://tests/buildings_%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(directory)
	state = root.get_node("GameState")
	_test_migration()
	_test_schema()
	await _test_buildings()
	for name in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(name))
	DirAccess.remove_absolute(directory)
	print("Tiny Kingdom buildings: %d checks, %d passed, %d failed" % [checks, checks - failures, failures])
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


func _write(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()


func _test_migration() -> void:
	var path := directory + "/migration.json"
	_write(path, legacy)
	var store := SaveSystem.new(path)
	var migrated := store.load_data()
	_expect(migrated.version == SaveSystem.VERSION and store.needs_save, "v1 requests migration to current version")
	_expect(migrated.resources == legacy.resources, "migration preserves all bank resources")
	_expect(migrated.player == legacy.player, "migration preserves level, XP, health and total damage")
	_expect(migrated.expeditions_completed == 7, "migration preserves completed expeditions")
	_expect(migrated.weapon_level == 0 and migrated.buildings == BuildingData.default_state(),
		"migration adds empty buildings and zero weapon upgrades")
	var backups := Array(DirAccess.get_files_at(directory)).filter(func(name): return name.begins_with("migration.json.v1-"))
	_expect(backups.size() == 1, "migration creates a v1 backup before writing")
	_expect(FileAccess.get_file_as_string(path) == FileAccess.get_file_as_string(directory.path_join(backups[0])),
		"v1 backup preserves the original file exactly")
	DirAccess.make_dir_absolute(path + ".tmp")
	_expect(not store.save_data(migrated), "migration handles a blocked save destination")
	_expect(JSON.parse_string(FileAccess.get_file_as_string(path)).version == 1,
		"failed migration leaves the original v1 file intact")
	DirAccess.remove_absolute(path + ".tmp")
	_expect(store.save_data(migrated), "migration can be retried after a write failure")
	_expect(store.load_data() == migrated and not store.needs_save, "current save reload does not migrate or duplicate bonuses")
	_write(directory + "/game.json", legacy)
	state.initialize(directory + "/game.json")
	_expect(state.progression == legacy.player and state.village_resources == legacy.resources,
		"GameState loads all existing Phase 2 progress")
	_expect(JSON.parse_string(FileAccess.get_file_as_string(state.storage.path)).version == SaveSystem.VERSION,
		"GameState automatically commits migration")


func _test_schema() -> void:
	var bad := SaveSystem.defaults()
	bad.buildings.town_hall.level = 2
	_expect(not SaveSystem.valid_data(bad), "building levels above the current maximum are rejected")
	bad = SaveSystem.defaults()
	bad.buildings.blacksmith.level = 1
	_expect(not SaveSystem.valid_data(bad), "schema enforces the Town Hall prerequisite")
	bad = SaveSystem.defaults()
	bad.weapon_level = 1
	_expect(not SaveSystem.valid_data(bad), "weapon upgrades require a built blacksmith")
	bad = SaveSystem.defaults()
	bad.buildings.town_hall.position.x = 700
	_expect(not SaveSystem.valid_data(bad), "save cannot turn fixed plots into free placement")
	bad = SaveSystem.defaults()
	bad.weapon_level = 4
	_expect(not SaveSystem.valid_data(bad), "weapon upgrade cap is validated")
	bad = SaveSystem.defaults()
	bad.buildings.erase("archer_tower")
	_expect(not SaveSystem.valid_data(bad), "missing building entries are rejected")
	_expect(not state.can_afford({"wood": -1}) and not state.can_afford({"wood": 1.5})
		and not state.can_afford({"unknown": 1}), "economy rejects negative, fractional and unknown costs")
	_expect(state.can_afford({"wood": 20, "stone": 15, "gold": 5}), "central affordability check uses permanent resources")
	var before: Dictionary = state.snapshot()
	_expect(state.spend_resources({"wood": 1}), "central spending can commit a valid cost")
	_expect(state.village_resources.wood == 199 and SaveSystem.new(state.storage.path).load_data().resources.wood == 199,
		"central spending deducts and persists once")
	state.village_resources = before.resources.duplicate()
	state.persist()


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event)
	event = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = false
	root.push_input(event)


func _open(main: Node, id: String) -> void:
	for building in get_nodes_in_group("buildings"):
		if building.building_id == id:
			main.player.position = building.position + Vector2(0, 65)
			main.player.interaction.interact()
			return


func _test_buildings() -> void:
	var main := MAIN.instantiate()
	root.add_child(main)
	current_scene = main
	await _frames()
	var player: KingdomPlayer = main.player
	var panel: BuildingPanel = main.hud.building_panel
	_expect(get_nodes_in_group("buildings").size() == 3, "village has exactly three fixed building plots")
	_expect(get_nodes_in_group("buildings").all(func(building): return building.level == 0), "all plots start available")
	_expect(main.hud.get_node("Root/SuppliesPanel/Supplies/SuppliesTitle").text.contains("Vila Nv. 0"), "HUD initially shows village level zero")
	_expect(player.damage == 30 and player.level == 4, "migration is applied to the live player")
	var original: Dictionary = state.snapshot()
	_expect(not state.purchase_building("blacksmith", "build", 0), "blacksmith is locked before Town Hall")
	_expect(not state.purchase_building("archer_tower", "build", 0), "tower is locked before Town Hall")
	_expect(state.snapshot() == original, "locked buildings spend no resources")
	_open(main, "blacksmith")
	_expect(panel.visible and panel.confirm_button.disabled and panel.reason_label.text.contains("Prefeitura"),
		"locked building panel explains the prerequisite")
	_key(KEY_ESCAPE)
	_expect(not panel.visible and not paused, "Escape closes the modal and resumes play")
	state.village_resources = {"wood": 0, "stone": 0, "gold": 0}
	state.expedition_resources = {"wood": 1000, "stone": 1000, "gold": 1000}
	player.resources = state.expedition_resources.duplicate()
	state.persist()
	_open(main, "town_hall")
	_expect(panel.confirm_button.disabled and panel.reason_label.text == "Recursos insuficientes",
		"carried resources cannot pay for construction")
	_key(KEY_ENTER)
	_expect(state.building_level("town_hall") == 0 and state.village_resources.wood == 0, "Enter cannot bypass insufficient resources")
	panel.close()
	state.village_resources = original.resources.duplicate()
	state.expedition_resources = {"wood": 0, "stone": 0, "gold": 0}
	player.resources = state.expedition_resources.duplicate()
	state.persist()
	player.position = Vector2(640, 385)
	_key(KEY_E)
	_expect(panel.visible and paused, "E opens the construction panel and pauses gameplay")
	_expect(panel.offer.cost == {"wood": 20, "stone": 15, "gold": 5}, "Town Hall panel shows the intended cost")
	_expect(panel.get_node("Center/Panel/Content/Available").text.contains("Madeira 200"), "panel shows available permanent resources")
	panel.get_node("Center/Panel/Content/Buttons/Cancel").pressed.emit()
	_expect(state.snapshot() == original and not paused, "Cancel leaves resources and buildings unchanged")
	_open(main, "town_hall")
	DirAccess.make_dir_absolute(state.storage.path + ".tmp")
	_key(KEY_ENTER)
	_expect(panel.visible and state.snapshot() == original, "failed construction save changes no live state")
	_expect(panel.reason_label.text.contains("Não foi possível salvar"), "construction write failure is explained")
	_expect(main.get_node("Map/Village/TownHall").level == 0, "failed construction keeps the empty-plot visual")
	DirAccess.remove_absolute(state.storage.path + ".tmp")
	_key(KEY_ENTER)
	_expect(not panel.visible and not paused and state.building_level("town_hall") == 1, "Enter builds Town Hall and closes the panel")
	_expect(state.village_resources == {"wood": 180, "stone": 205, "gold": 95}, "Town Hall deducts exactly 20 wood, 15 stone and 5 gold")
	_expect(main.get_node("Map/Village/TownHall").level == 1, "Town Hall visual updates immediately")
	_expect(main.hud.get_node("Root/SuppliesPanel/Supplies/SuppliesTitle").text.contains("Vila Nv. 1"), "Town Hall raises village HUD to level one")
	_expect(main.hud.toast.text.contains("Prefeitura construída"), "construction uses existing feedback")
	var after_hall: Dictionary = state.snapshot()
	_expect(not state.purchase_building("town_hall", "build", 0) and state.snapshot() == after_hall,
		"duplicate confirmation cannot charge for Town Hall twice")
	_expect(state.building_offer("blacksmith").enabled and state.building_offer("archer_tower").enabled,
		"Town Hall unlocks both remaining buildings")
	_open(main, "blacksmith")
	panel.confirm_button.pressed.emit()
	_expect(state.building_level("blacksmith") == 1 and state.weapon_level == 0, "building the blacksmith does not grant an unpurchased upgrade")
	_expect(state.village_resources == {"wood": 165, "stone": 185, "gold": 87}, "blacksmith deducts exactly 15 wood, 20 stone and 8 gold")
	_expect(player.damage == 30, "constructing the blacksmith does not change damage")
	_open(main, "blacksmith")
	_expect(panel.offer.action == "upgrade" and panel.offer.cost == {"wood": 10, "stone": 15, "gold": 5}, "built blacksmith offers the first weapon upgrade")
	var before_upgrade: Dictionary = state.snapshot()
	DirAccess.make_dir_absolute(state.storage.path + ".tmp")
	panel.confirm_purchase()
	_expect(state.snapshot() == before_upgrade and player.damage == 30, "failed upgrade preserves resources, weapon level and live damage")
	DirAccess.remove_absolute(state.storage.path + ".tmp")
	_key(KEY_ENTER)
	_expect(state.weapon_level == 1 and player.damage == 33, "first weapon upgrade immediately adds three permanent damage")
	_expect(state.village_resources == {"wood": 155, "stone": 170, "gold": 82}, "first upgrade deducts the intended cost")
	_expect(not state.purchase_building("blacksmith", "upgrade", 0) and player.damage == 33,
		"stale upgrade confirmation cannot duplicate a bonus")
	_open(main, "blacksmith")
	_expect(panel.offer.cost == {"wood": 20, "stone": 30, "gold": 10}, "second weapon cost increases")
	panel.confirm_purchase()
	_expect(state.weapon_level == 2 and player.damage == 37, "second upgrade adds four more damage")
	_open(main, "blacksmith")
	_expect(panel.offer.cost == {"wood": 30, "stone": 45, "gold": 15}, "third weapon cost increases")
	panel.confirm_purchase()
	_expect(state.weapon_level == 3 and player.damage == 42, "third upgrade adds five more damage")
	_expect(state.village_resources == {"wood": 105, "stone": 95, "gold": 57}, "all three upgrades debit the exact accumulated cost")
	_open(main, "blacksmith")
	_expect(panel.confirm_button.disabled and panel.offer.description.contains("+12 dano"), "max-level panel shows cumulative bonus and disables purchase")
	var maximum: Dictionary = state.snapshot()
	_expect(not state.purchase_building("blacksmith", "upgrade", 3) and state.snapshot() == maximum,
		"weapon upgrades stop at level three")
	panel.close()
	player.set_physics_process(false)
	var tower: VillageBuilding = main.get_node("Map/Village/ArcherTower")
	var near := _enemy(main, tower.position + Vector2(-150, 0))
	var farther := _enemy(main, tower.position + Vector2(-250, 0))
	var outside := _enemy(main, tower.position + Vector2(-350, 0))
	await _frames(65)
	_expect(near.current_health == 36 and farther.current_health == 36, "unbuilt tower cannot attack")
	_open(main, "archer_tower")
	panel.confirm_purchase()
	_expect(state.building_level("archer_tower") == 1 and tower.level == 1, "tower is built and updates its visual state")
	_expect(state.village_resources == {"wood": 80, "stone": 80, "gold": 47}, "tower deducts exactly 25 wood, 15 stone and 10 gold")
	_expect(tower.nearest_enemy() == near, "tower selects nearest living enemy inside range")
	await _frames(3)
	_expect(near.current_health == 26 and farther.current_health == 36, "tower causes ten damage only to the nearest target")
	await _frames(20)
	_expect(near.current_health == 26, "tower respects one-second cooldown")
	await _frames(45)
	_expect(near.current_health == 16, "tower attacks again after cooldown")
	await _frames(120)
	_expect(not is_instance_valid(near), "tower can kill an enemy")
	_expect(player.experience == 17 and not state.has_cargo(), "defensive kills grant no expedition XP or cargo")
	farther.queue_free()
	await _frames(65)
	_expect(outside.current_health == 36, "tower does not hit outside its 300-pixel range")
	outside.queue_free()
	await _frames()
	player.gain_experience(100)
	_expect(player.level == 5 and player.damage == 46, "normal leveling still adds damage on top of the permanent weapon bonus")
	player.apply_progress(state.progression, state.expedition_resources)
	player.apply_progress(state.progression, state.expedition_resources)
	_expect(player.damage == 46, "reapplying saved attributes never adds the weapon bonus twice")
	var saved := SaveSystem.new(state.storage.path).load_data()
	_expect(saved.buildings == state.buildings and saved.weapon_level == 3 and saved.player.damage == 46,
		"save reload preserves all three buildings and total upgraded damage")
	for attempt in range(2):
		var output: Array = []
		var status := OS.execute(OS.get_executable_path(), PackedStringArray([
			"--headless", "--path", ProjectSettings.globalize_path("res://"),
			"--script", "res://tests/persistence_probe.gd", "--", state.storage.path,
			Marshalls.utf8_to_base64(JSON.stringify(state.snapshot()))
		]), output, true)
		_expect(status == 0, "fresh process %d restores buildings and damage without duplicate bonuses" % (attempt + 1))
		if status != 0:
			print(output)
	main.start_expedition()
	await _frames()
	_expect(get_nodes_in_group("buildings").is_empty() and player.damage == 46, "expedition retains upgraded damage without spawning village buildings")
	_expect(not state.purchase_building("blacksmith", "upgrade", 3), "economy rejects purchasing during an expedition")
	player.set_physics_process(true)
	player.take_damage(10000)
	await _frames(130)
	_expect(main.in_village and get_nodes_in_group("buildings").size() == 3 and player.damage == 46,
		"death restores village buildings and preserves upgraded damage")
	_expect(get_nodes_in_group("buildings").all(func(building): return building.level == 1), "all constructed visuals survive map changes")
	main.reset_progress()
	await _frames()
	_expect(state.weapon_level == 0 and player.damage == 18, "debug reset removes weapon bonuses")
	_expect(get_nodes_in_group("buildings").all(func(building): return building.level == 0), "debug reset restores available plots")
	_expect(state.snapshot() == SaveSystem.defaults(), "reset persists complete current defaults")
	current_scene = null
	main.queue_free()
	await _frames()


func _enemy(main: Node, point: Vector2) -> KingdomEnemy:
	var enemy := ENEMY.instantiate() as KingdomEnemy
	enemy.position = point
	main.get_node("Actors").add_child(enemy)
	enemy.set_physics_process(false)
	return enemy
