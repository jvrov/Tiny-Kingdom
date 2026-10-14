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
	matches = matches and actual.expeditions_completed == expected.expeditions_completed
	for key in ["wood", "stone", "gold"]:
		matches = matches and actual.resources[key] == expected.resources[key]
	for key in ["level", "xp", "max_health", "damage"]:
		matches = matches and actual.player[key] == expected.player[key]
	matches = matches and main.in_village and main.player.level == expected.player.level
	matches = matches and get_nodes_in_group("player").size() == 1
	if not matches:
		print("Persistence mismatch: actual=", actual, " expected=", expected)
	main.queue_free()
	await process_frame
	quit(0 if matches else 1)
