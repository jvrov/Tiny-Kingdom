extends SceneTree
## Real files/scenes, deterministic loot rolls, input and process reloads.
const MAIN := preload("res://scenes/main/Main.tscn")
const ENEMY := preload("res://scenes/enemies/Enemy.tscn")
var state: Node
var directory: String
var checks := 0
var failures := 0


func _initialize() -> void:
	run.call_deferred()


func expect(condition: bool, description: String) -> void:
	checks += 1
	if condition: print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)


func frames(count: int = 3) -> void:
	for index in range(count):
		await physics_frame
		await process_frame


func run() -> void:
	directory = "user://tests/inventory_%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(directory)
	state = root.get_node("GameState")
	catalog_and_schema()
	migrations()
	state.initialize(directory + "/game.json")
	await gameplay()
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(filename))
	DirAccess.remove_absolute(directory)
	print("Tiny Kingdom inventory: %d checks, %d passed, %d failed" % [checks, checks - failures, failures])
	quit(1 if failures else 0)


func catalog_and_schema() -> void:
	expect(ItemData.CATALOG.size() == 13, "catalog has twelve equipment items and one potion")
	for id in ItemData.CATALOG:
		var item := ItemData.definition(id)
		expect(item.id == id and not item.name.is_empty() and not item.icon.is_empty() and not item.description.is_empty(),
			"stable catalog definition: " + id)
	expect(ItemData.definition("missing").is_empty(), "unknown item cannot be created")
	var rolls := [0.0, 0.5999, 0.60, 0.8499, 0.85, 0.9699, 0.97, 1.0]
	var expected := ["common", "common", "uncommon", "uncommon", "rare", "rare", "epic", "epic"]
	for index in range(rolls.size()):
		expect(ItemData.rarity_for_roll(rolls[index]) == expected[index], "rarity probability boundary %d" % index)
	var rng := RandomNumberGenerator.new()
	rng.seed = 41017
	var gear_count := 0
	var potion_count := 0
	var rarities := {"common": 0, "uncommon": 0, "rare": 0, "epic": 0}
	for index in range(10000):
		for id in ItemData.roll_loot(rng):
			if id == "health_potion": potion_count += 1
			else:
				gear_count += 1
				rarities[ItemData.definition(id).rarity] += 1
	expect(gear_count > 2200 and gear_count < 2800, "equipment drop rate approximates 25 percent")
	expect(potion_count > 1000 and potion_count < 1400, "independent potion rate approximates 12 percent")
	expect(rarities.common > rarities.uncommon and rarities.uncommon > rarities.rare and rarities.rare > rarities.epic and rarities.epic > 0,
		"seeded loot includes all four weighted rarities")
	expect(ItemData.roll_loot(rng, 0, 0).is_empty(), "zero rates disable all item drops")
	expect(ItemData.roll_loot(rng, 1, 1).size() == 2, "independent rolls can drop gear and potion together")
	var data := SaveSystem.defaults()
	expect(data.inventory.size() == 20 and SaveSystem.valid_data(data), "empty v4 schema has exactly twenty slots")
	for quantity in [0, -1, 1.5, 6, true]:
		var bad := data.duplicate(true)
		bad.inventory[0] = {"id": "health_potion", "quantity": quantity}
		expect(not SaveSystem.valid_data(bad), "invalid potion quantity rejected: " + str(quantity))
	var bad := data.duplicate(true)
	bad.inventory[0] = {"id": "royal_blade", "quantity": 2}
	expect(not SaveSystem.valid_data(bad), "equipment cannot stack")
	bad = data.duplicate(true)
	bad.inventory[0] = {"id": "unknown", "quantity": 1}
	expect(not SaveSystem.valid_data(bad), "unknown persistent ID rejected")
	bad = data.duplicate(true)
	bad.inventory.pop_back()
	expect(not SaveSystem.valid_data(bad), "wrong bag capacity rejected")
	bad = data.duplicate(true)
	bad.equipment.weapon = "royal_armor"
	expect(not SaveSystem.valid_data(bad), "equipment must match slot")
	bad = data.duplicate(true)
	bad.attribute_base.damage = 999
	expect(not SaveSystem.valid_data(bad), "inconsistent permanent stat sources rejected")


func migrations() -> void:
	for version in [1, 2, 3]:
		var old := SaveSystem.defaults()
		old.version = version
		for key in ["inventory", "equipment", "attribute_base"]: old.erase(key)
		old.player = {"level": 3, "xp": 17, "max_health": 137, "damage": 41}
		old.resources = {"wood": 88, "stone": 77, "gold": 66}
		old.expeditions_completed = 5
		old.defenses_completed = 4
		old.weapon_level = 2
		for id in BuildingData.IDS: old.buildings[id].level = 1
		if version < 3: old.erase("defenses_completed")
		if version == 1:
			old.erase("buildings")
			old.erase("weapon_level")
		var path := directory + "/v%d.json" % version
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(JSON.stringify(old))
		file.close()
		var original := FileAccess.get_file_as_string(path)
		var storage := SaveSystem.new(path)
		var migrated := storage.load_data()
		expect(migrated.version == 4 and storage.needs_save, "v%d migrates to v4" % version)
		expect(migrated.player == old.player and migrated.resources == old.resources and migrated.expeditions_completed == 5,
			"v%d preserves original progress and customized totals" % version)
		expect(migrated.inventory == InventoryData.empty_slots() and migrated.equipment == InventoryData.empty_equipment(),
			"v%d starts with empty inventory and equipment" % version)
		var totals := AttributeStats.permanent(migrated.attribute_base, migrated.player.level, migrated.weapon_level)
		expect(totals.damage == 41 and totals.max_health == 137, "v%d decomposes stats without changing totals" % version)
		expect(migrated.defenses_completed == (4 if version == 3 else 0), "v%d preserves or defaults defenses" % version)
		var backups := Array(DirAccess.get_files_at(directory)).filter(func(name): return name.begins_with("v%d.json.v%d-" % [version, version]))
		expect(backups.size() == 1 and FileAccess.get_file_as_string(directory.path_join(backups[0])) == original,
			"v%d original backed up byte for byte" % version)
		DirAccess.make_dir_absolute(path + ".tmp")
		expect(not storage.save_data(migrated) and FileAccess.get_file_as_string(path) == original,
			"v%d migration failure preserves original file" % version)
		DirAccess.remove_absolute(path + ".tmp")
		expect(storage.save_data(migrated) and storage.load_data() == migrated, "v%d migration retry persists intact v4" % version)


func index_of(id: String) -> int:
	for index in range(state.inventory.size()):
		if state.inventory[index].get("id") == id: return index
	return -1


func press(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.keycode = keycode
	event.pressed = true
	root.push_input(event)
	event = InputEventKey.new()
	event.physical_keycode = keycode
	event.keycode = keycode
	event.pressed = false
	root.push_input(event)


func gameplay() -> void:
	var main := MAIN.instantiate()
	root.add_child(main)
	current_scene = main
	await frames()
	var player: KingdomPlayer = main.player
	var panel: InventoryPanel = main.hud.inventory_panel
	expect(player.damage == 18 and player.max_health == 100 and player.speed == 230, "new player retains baseline stats")
	press(KEY_I)
	expect(panel.visible and paused and panel.slot_buttons.size() == 20, "I opens twenty-slot inventory and pauses gameplay")
	press(KEY_I)
	expect(not panel.visible and not paused, "I closes and resumes")
	press(KEY_F8)
	expect(get_nodes_in_group("world_items").size() == 1, "F8 creates physical debug loot")
	var debug_drop: WorldItem = get_nodes_in_group("world_items")[0]
	debug_drop.queue_free()
	await frames()
	var item := main.spawn_item("iron_sword", player.position + Vector2(100, 0)) as WorldItem
	await frames()
	expect(index_of("iron_sword") == -1 and is_instance_valid(item), "physical item waits on ground outside pickup range")
	player.position = item.position
	await frames()
	expect(not is_instance_valid(item) and index_of("iron_sword") >= 0, "touching item automatically collects it")
	expect(main.hud.toast.text.contains("Espada de Ferro"), "pickup uses existing HUD feedback")
	var initial: Dictionary = state.snapshot()
	item = main.spawn_item("royal_blade", player.position)
	item.set_physics_process(false)
	DirAccess.make_dir_absolute(state.storage.path + ".tmp")
	expect(not item.try_pickup(player) and state.snapshot() == initial and not item.is_queued_for_deletion(), "failed pickup save preserves ground item and bag")
	DirAccess.remove_absolute(state.storage.path + ".tmp")
	expect(item.try_pickup(player), "pickup succeeds after disk recovery")
	expect(not item.try_pickup(player), "same ground item cannot be collected twice")
	await frames()
	press(KEY_I)
	panel.select(index_of("iron_sword"))
	panel.equip_button.pressed.emit()
	expect(player.damage == 23 and state.equipment.weapon == "iron_sword", "UI equips sword and applies five damage immediately")
	expect(state.progression.damage == 18 and state.attribute_base.damage == 18, "equipment damage stays out of permanent progression")
	panel.select(index_of("royal_blade"))
	panel.equip_button.pressed.emit()
	expect(player.damage == 33 and index_of("iron_sword") >= 0, "new sword replaces old and returns old to bag")
	state.collect_item("leather_armor")
	state.collect_item("explorer_boots")
	player.take_damage(30)
	var health := player.current_health
	state.inventory_action(player, "equip", index_of("leather_armor"))
	expect(player.max_health == 120 and player.current_health == health, "armor increases max HP without free healing")
	state.inventory_action(player, "equip", index_of("explorer_boots"))
	expect(player.speed == 240, "boots immediately add ten speed")
	state.collect_item("health_potion", 7)
	expect(InventoryData.count(state.inventory, "health_potion") == 7, "potion collection stores all seven units")
	var stacks: Array = state.inventory.filter(func(entry): return entry.get("id") == "health_potion").map(func(entry): return entry.quantity)
	expect(stacks == [5, 2], "potions stack up to five and overflow into another slot")
	initial = state.snapshot()
	DirAccess.make_dir_absolute(state.storage.path + ".tmp")
	expect(not state.inventory_action(player, "use", index_of("health_potion")) and player.current_health == health and state.snapshot() == initial,
		"failed potion save neither heals nor consumes")
	expect(not state.inventory_action(player, "equip", index_of("iron_sword")) and player.damage == 33 and state.snapshot() == initial,
		"failed equipment save preserves live attributes and ownership")
	expect(not state.inventory_action(player, "discard", index_of("iron_sword")) and state.snapshot() == initial,
		"failed discard save preserves item")
	DirAccess.remove_absolute(state.storage.path + ".tmp")
	expect(state.inventory_action(player, "use", index_of("health_potion")) and player.current_health == 110, "potion heals exactly forty")
	expect(state.inventory_action(player, "use", index_of("health_potion")) and player.current_health == 120, "potion healing clamps at maximum")
	var potions := InventoryData.count(state.inventory, "health_potion")
	expect(not state.inventory_action(player, "use", index_of("health_potion")) and InventoryData.count(state.inventory, "health_potion") == potions,
		"full-health use does not waste potion")
	expect(state.inventory_action(player, "unequip", -1, "armor") and player.max_health == 100 and player.current_health == 100,
		"unequipping armor clamps HP and returns item")
	panel.select(index_of("health_potion"))
	panel.confirm_discard()
	expect(panel.discard_dialog.visible, "discard requests confirmation for whole stack")
	panel.discard_dialog.canceled.emit()
	panel.discard_dialog.hide()
	expect(InventoryData.count(state.inventory, "health_potion") == potions, "canceling discard retains stack")
	panel.confirm_discard()
	panel.discard_dialog.confirmed.emit()
	panel.discard_dialog.hide()
	expect(InventoryData.count(state.inventory, "health_potion") == 2, "confirmed discard removes selected stack only")
	press(KEY_ESCAPE)
	expect(not panel.visible and not paused, "Escape closes inventory")
	# Full bag swapping uses the selected slot; unequipping requires a free slot.
	while state.inventory.any(func(entry): return entry.is_empty()):
		state.collect_item("rusty_sword")
	expect(not state.collect_item("iron_armor"), "full bag rejects new equipment")
	var before: Dictionary = state.snapshot()
	item = main.spawn_item("iron_armor", player.position)
	item.set_physics_process(false)
	expect(not item.try_pickup(player) and not item.is_queued_for_deletion(), "full bag leaves world item available")
	expect(not state.inventory_action(player, "unequip", -1, "weapon") and state.snapshot() == before, "full bag cannot lose unequipped weapon")
	expect(state.inventory_action(player, "equip", index_of("iron_sword")) and index_of("royal_blade") >= 0,
		"equipment swap works without loss with all twenty slots occupied")
	expect(state.collect_item("health_potion", 3) and InventoryData.count(state.inventory, "health_potion") == 5, "full bag accepts potions into partial stack")
	expect(not state.collect_item("health_potion") and InventoryData.count(state.inventory, "health_potion") == 5, "full stacks reject excess without partial mutation")
	state.inventory_action(player, "discard", index_of("rusty_sword"))
	expect(item.try_pickup(player) and index_of("iron_armor") >= 0, "freeing a slot permits previously blocked pickup")
	await frames()
	# Level, blacksmith and gear are independent and reproducible.
	state.village_resources = {"wood": 500, "stone": 500, "gold": 500}
	state.persist()
	state.purchase_building("town_hall", "build", 0)
	state.purchase_building("blacksmith", "build", 0)
	state.purchase_building("blacksmith", "upgrade", 0)
	state.purchase_building("blacksmith", "upgrade", 1)
	player.gain_experience(80)
	expect(player.level == 3 and player.damage == 38, "base18 + level8 + smith7 + iron sword5 equals38")
	var parts: Dictionary = state.attribute_breakdown()
	expect(parts.base.damage == 18 and parts.level.damage == 8 and parts.blacksmith == 7 and parts.equipment.damage == 5,
		"attribute breakdown exposes each damage source")
	for attempt in range(3):
		player.apply_equipment(state.progression, state.equipment, state.attribute_base.speed)
		player.apply_progress(state.progression, state.expedition_resources)
	expect(player.damage == 38 and state.progression.damage == 33, "repeated application never doubles bonuses")
	expect(state.inventory_action(player, "equip", index_of("iron_armor")) and player.max_health == 165, "armor stacks with level-based HP")
	var save: Dictionary = state.snapshot()
	var loaded := SaveSystem.new(state.storage.path).load_data()
	expect(loaded == save, "v4 reload preserves inventory quantities equipment and stat sources")
	for attempt in range(2):
		var output: Array = []
		var status := OS.execute(OS.get_executable_path(), PackedStringArray([
			"--headless", "--path", ProjectSettings.globalize_path("res://"),
			"--script", "res://tests/persistence_probe.gd", "--", state.storage.path,
			Marshalls.utf8_to_base64(JSON.stringify(save))
		]), output, true)
		expect(status == 0, "fresh process %d restores all gear without duplicate bonuses" % attempt)
		if status != 0: print(output)
	expect(main.start_expedition(), "equipped player can enter expedition")
	await frames()
	player.set_physics_process(false)
	for enemy in get_nodes_in_group("enemies"): enemy.set_physics_process(false)
	var enemy: KingdomEnemy = get_nodes_in_group("enemies")[0]
	enemy.equipment_drop_chance = 1
	enemy.potion_drop_chance = 1
	var drops_before := get_nodes_in_group("world_items").size()
	enemy.take_damage(10000, player)
	expect(get_nodes_in_group("world_items").size() == drops_before + 2, "expedition enemy emits physical gear and potion")
	enemy.take_damage(10000, player)
	expect(get_nodes_in_group("world_items").size() == drops_before + 2, "duplicate kill cannot duplicate drops")
	var invader := ENEMY.instantiate() as KingdomEnemy
	invader.invading = true
	invader.loot_enabled = true
	invader.equipment_drop_chance = 1
	invader.potion_drop_chance = 1
	invader.loot_dropped.connect(main.spawn_item)
	main.get_node("Actors").add_child(invader)
	invader.set_physics_process(false)
	invader.take_damage(10000, player)
	expect(get_nodes_in_group("world_items").size() == drops_before + 2, "invaders never drop items even with forced drop rates")
	player.add_resource("gold", 5)
	var inventory_before: Array = state.inventory.duplicate(true)
	var equipment_before: Dictionary = state.equipment.duplicate()
	player.take_damage(10000)
	expect(not state.inventory_action(player, "use", index_of("health_potion")), "dead player cannot consume items")
	press(KEY_I)
	expect(not panel.visible, "inventory cannot open while incapacitated")
	await frames(130)
	expect(main.in_village and state.inventory == inventory_before and state.equipment == equipment_before, "expedition death keeps all collected and equipped items")
	expect(not state.has_cargo() and get_nodes_in_group("world_items").is_empty(), "death loses resources and clears uncollected world drops")
	expect(player.damage == state.progression.damage + 5 and player.speed == 240, "death return preserves gear stats")
	main.request_defense()
	var dialog: ConfirmationDialog = main.hud.get_node("DefenseConfirmation")
	dialog.confirmed.emit()
	dialog.hide()
	press(KEY_I)
	expect(paused and panel.visible and main.waves.is_battle(), "inventory can pause defense for equipment and potion use")
	press(KEY_ESCAPE)
	expect(not paused and main.waves.is_battle(), "closing inventory resumes defense")
	player.add_resource("gold", 5)
	expect(state.has_cargo(), "reset fixture carries resources alongside equipment")
	main.reset_progress()
	await frames()
	expect(not state.has_cargo() and player.resources.gold == 0, "stat refresh cannot restore cargo cleared by reset")
	expect(state.inventory == InventoryData.empty_slots() and state.equipment == InventoryData.empty_equipment(), "debug reset clears items and equipped slots")
	expect(player.damage == 18 and player.max_health == 100 and player.speed == 230 and state.snapshot() == SaveSystem.defaults(), "reset removes all gear bonuses and persists defaults")
	current_scene = null
	main.queue_free()
	await frames()
