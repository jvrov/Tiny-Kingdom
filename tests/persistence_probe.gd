extends SceneTree
## Child process used by progression_test.gd. Never opens the real save slot.

const MAIN := preload("res://scenes/main/Main.tscn")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 or not args[0].begins_with("user://tests/") or args[0].contains(".."):
		quit(2)
		return
	var expected: Variant = JSON.parse_string(Marshalls.base64_to_utf8(args[1]))
	if not expected is Dictionary:
		quit(2)
		return
	var state := root.get_node("GameState")
	state.initialize(args[0])
	var main := MAIN.instantiate()
	root.add_child(main)
	var actual: Dictionary = state.snapshot()
	var matches: bool = actual.version == expected.version and not state.has_cargo()
	matches = matches and actual.defenses_completed == expected.defenses_completed
	matches = matches and not state.defense_busy() and get_nodes_in_group("enemies").is_empty()
	matches = matches and actual.expeditions_completed == expected.expeditions_completed
	for key in ["wood", "stone", "gold"]:
		matches = matches and actual.resources[key] == expected.resources[key]
	for key in ["level", "xp", "max_health", "damage"]:
		matches = matches and actual.player[key] == expected.player[key]
	matches = matches and main.in_village and main.player.level == expected.player.level
	var bonuses := InventoryData.bonuses(expected.equipment)
	# JSON numbers are floats; compare quantities numerically, not container types.
	matches = matches and actual.inventory.size() == expected.inventory.size()
	for index in range(actual.inventory.size()):
		var entry: Dictionary = actual.inventory[index]
		var wanted: Dictionary = expected.inventory[index]
		matches = matches and entry.is_empty() == wanted.is_empty()
		if not entry.is_empty() and not wanted.is_empty():
			matches = matches and entry.id == wanted.id and entry.quantity == wanted.quantity
	matches = matches and actual.equipment == expected.equipment
	for key in actual.attribute_base:
		matches = matches and actual.attribute_base[key] == expected.attribute_base[key]
	matches = matches and main.player.damage == expected.player.damage + bonuses.damage
	matches = matches and main.player.max_health == expected.player.max_health + bonuses.max_health
	matches = matches and main.player.speed == expected.attribute_base.speed + bonuses.speed
	matches = matches and actual.weapon_level == expected.weapon_level
	for id in BuildingData.IDS:
		matches = matches and actual.buildings[id].level == expected.buildings[id].level
		for axis in ["x", "y"]:
			matches = matches and actual.buildings[id].position[axis] == expected.buildings[id].position[axis]
	for building in get_nodes_in_group("buildings"):
		matches = matches and building.level == expected.buildings[building.building_id].level
	matches = matches and get_nodes_in_group("player").size() == 1
	if not matches:
		print("Persistence mismatch: actual=", actual, " expected=", expected)
	main.queue_free()
	await process_frame
	quit(0 if matches else 1)
