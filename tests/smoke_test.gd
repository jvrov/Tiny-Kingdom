extends SceneTree
## Integration tests against real scenes, physics, signals and scene reloads.
## Run after an editor import: godot --headless --path . --script res://tests/smoke_test.gd

const MAIN := preload("res://scenes/main/Main.tscn")
const PLAYER := preload("res://scenes/player/Player.tscn")
const ENEMY := preload("res://scenes/enemies/Enemy.tscn")
const WORLD := preload("res://scenes/world/World.tscn")

var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_input_bindings()
	await _test_scene_hud_and_progression()
	await _test_movement_and_boundaries()
	await _test_automatic_combat()
	await _test_enemy_behavior()
	await _test_death_and_restart()
	print("Tiny Kingdom: %d checks, %d passed, %d failed" % [checks, checks - failures, failures])
	quit(1 if failures > 0 else 0)


func _expect(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)


func _frames(count: int) -> void:
	for index in range(count):
		await physics_frame
		await process_frame


func _discard(node: Node) -> void:
	node.queue_free()
	await _frames(2)


func _test_input_bindings() -> void:
	var keys := {
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN]
	}
	for action in keys:
		var actual: Array[int] = []
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				actual.append(event.physical_keycode)
		_expect(actual == keys[action], action + " binds WASD and arrows")
	var source := MovementInput.new()
	root.add_child(source)
	Input.action_press("move_right")
	Input.action_press("move_down")
	_expect(is_equal_approx(source.get_direction().length(), 1.0), "keyboard diagonal is normalized")
	source.set_virtual_direction(Vector2(2, 2))
	_expect(is_equal_approx(source.get_direction().length(), 1.0), "virtual input caps full deflection")
	source.set_virtual_direction(Vector2(0.3, 0))
	_expect(source.get_direction().is_equal_approx(Vector2(0.3, 0)), "virtual input preserves analog intensity")
	Input.action_release("move_right")
	Input.action_release("move_down")
	source.clear_virtual_direction()
	_expect(source.get_direction() == Vector2.ZERO, "releasing virtual input stops movement")
	source.free()


func _test_scene_hud_and_progression() -> void:
	var main := MAIN.instantiate()
	root.add_child(main)
	var player: KingdomPlayer = main.player
	var hud: KingdomHUD = main.hud
	player.set_physics_process(false)
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	_expect(get_nodes_in_group("enemies").size() == 12, "main spawns 12 enemies")
	_expect(main.get_node("World").get_child_count() == 4, "map has four collision boundaries")
	_expect(player.get_node("Camera2D").enabled, "player has an enabled follow camera")
	_expect(hud.health_bar.value == 100 and hud.xp_bar.value == 0, "HUD binds initial health and XP")
	player.take_damage(20)
	_expect(player.current_health == 80 and hud.health_bar.value == 80, "damage updates HUD through signal")
	player.gain_experience(95)
	_expect(player.level == 3 and player.experience == 15, "multiple level-ups preserve leftover XP")
	_expect(player.max_health == 130 and player.damage == 26, "level-ups increase health and damage")
	_expect(player.current_health == 130, "level-up healing respects maximum health")
	_expect(hud.xp_bar.max_value == 70 and hud.xp_bar.value == 15, "XP bar follows new level threshold")
	_expect(hud.health_bar.max_value == 130 and hud.level_text.text.contains("03"), "HUD reflects new stats and level")
	for kind in ["wood", "stone", "gold"]:
		player.add_resource(kind, 3)
	_expect(player.resources == {"wood": 3, "stone": 3, "gold": 3}, "inventory stores all three resources")
	_expect(hud.resource_text.text.count("003") == 3, "HUD reflects all resource quantities")
	player.add_resource("invalid", 5)
	player.add_resource("wood", -1)
	player.gain_experience(-10)
	player.take_damage(-5)
	_expect(player.resources.size() == 3 and player.resources["wood"] == 3
		and player.experience == 15 and player.current_health == 130, "invalid rewards and negative damage are ignored")
	for enemy in get_nodes_in_group("enemies"):
		enemy.take_damage(1000, player)
	_expect(main.remaining_enemies == 0 and main.finished, "clearing every enemy completes expedition")
	_expect(hud.result_panel.visible and hud.result_title.text == "Clareira protegida!", "victory is displayed")
	_expect(hud.objective_text.text.contains("12 / 12"), "objective counts defeated enemies")
	await _discard(main)


func _test_movement_and_boundaries() -> void:
	var arena := Node2D.new()
	root.add_child(arena)
	arena.add_child(WORLD.instantiate())
	var player := PLAYER.instantiate() as KingdomPlayer
	player.position = Vector2(800, 850)
	arena.add_child(player)
	await _frames(2)
	player.movement_input.set_virtual_direction(Vector2.RIGHT)
	var start := player.position
	await _frames(60)
	var straight := player.position.distance_to(start)
	player.movement_input.set_virtual_direction(Vector2(1, 1))
	start = player.position
	await _frames(60)
	var diagonal := player.position.distance_to(start)
	_expect(absf(straight - player.speed) < 10.0, "physics movement covers speed pixels in one second")
	_expect(absf(straight - diagonal) < 5.0, "diagonal speed matches horizontal speed")
	player.position = Vector2(25, 900)
	player.movement_input.set_virtual_direction(Vector2.LEFT)
	await _frames(20)
	_expect(player.position.x >= 16.0 and player.position.x <= 18.0, "left map wall blocks player")
	player.position = Vector2(2575, 900)
	player.movement_input.set_virtual_direction(Vector2.RIGHT)
	await _frames(20)
	_expect(player.position.x <= 2584.0, "right map wall blocks player")
	player.position = Vector2(800, 25)
	player.movement_input.set_virtual_direction(Vector2.UP)
	await _frames(20)
	_expect(player.position.y >= 16.0, "top map wall blocks player")
	player.position = Vector2(800, 1775)
	player.movement_input.set_virtual_direction(Vector2.DOWN)
	await _frames(20)
	_expect(player.position.y <= 1784.0, "bottom map wall blocks player")
	player.movement_input.clear_virtual_direction()
	await _frames(2)
	_expect(player.velocity == Vector2.ZERO, "movement stops when input is released")
	await _discard(arena)


func _test_automatic_combat() -> void:
	var arena := Node2D.new()
	root.add_child(arena)
	var player := PLAYER.instantiate() as KingdomPlayer
	player.position = Vector2(600, 900)
	arena.add_child(player)
	var far := ENEMY.instantiate() as KingdomEnemy
	far.position = player.position + Vector2(200, 0)
	arena.add_child(far)
	far.set_physics_process(false)
	await _frames(3)
	_expect(far.current_health == far.max_health, "auto-attack does not hit outside range")
	far.position = player.position + Vector2(100, 0)
	var near := ENEMY.instantiate() as KingdomEnemy
	near.position = player.position + Vector2(65, 0)
	near.drop_chance = 1.0
	arena.add_child(near)
	near.set_physics_process(false)
	_expect(player.find_nearest_enemy() == near, "auto-attack selects nearest enemy")
	await _frames(3)
	_expect(near.current_health == 18 and far.current_health == 36, "automatic attack damages only nearest enemy")
	await _frames(10)
	_expect(near.current_health == 18, "player attack respects cooldown")
	await _frames(35)
	_expect(not is_instance_valid(near), "second automatic hit kills and removes enemy")
	_expect(player.experience == 15, "automatic kill grants XP")
	var resource_total: int = player.resources["wood"] + player.resources["stone"] + player.resources["gold"]
	_expect(resource_total >= 1 and resource_total <= 3, "guaranteed drop grants one resource stack")
	player.set_physics_process(false)
	far.drop_chance = 0.0
	far.take_damage(1000, player)
	var xp_after := player.experience
	var level_after := player.level
	far.take_damage(1000, player)
	_expect(player.experience == xp_after and player.level == level_after, "duplicate lethal damage cannot duplicate XP")
	_expect(player.resources["wood"] + player.resources["stone"] + player.resources["gold"] == resource_total,
		"zero drop chance grants no resources")
	await _discard(arena)


func _test_enemy_behavior() -> void:
	var arena := Node2D.new()
	root.add_child(arena)
	var player := PLAYER.instantiate() as KingdomPlayer
	player.position = Vector2(600, 900)
	arena.add_child(player)
	player.set_physics_process(false)
	var enemy := ENEMY.instantiate() as KingdomEnemy
	enemy.position = player.position + Vector2(500, 0)
	arena.add_child(enemy)
	var start := enemy.position
	await _frames(10)
	_expect(enemy.position.is_equal_approx(start), "enemy stays idle outside detection range")
	enemy.position = player.position + Vector2(200, 0)
	await _frames(30)
	_expect(enemy.position.distance_to(player.position) < 180.0, "enemy detects and pursues player")
	enemy.position = player.position + Vector2(37, 0)
	await _frames(3)
	_expect(player.current_health == 92, "enemy deals contact damage")
	_expect(enemy.velocity.is_zero_approx(), "enemy stops near player")
	await _frames(20)
	_expect(player.current_health == 92, "contact damage respects cooldown")
	await _frames(50)
	_expect(player.current_health == 84, "enemy attacks again after cooldown")
	player.take_damage(1000)
	start = enemy.position
	await _frames(10)
	_expect(enemy.position.is_equal_approx(start) and player.current_health == 0,
		"enemy stops attacking and pursuing dead player")
	await _discard(arena)


func _test_death_and_restart() -> void:
	var main := MAIN.instantiate()
	root.add_child(main)
	current_scene = main
	var player: KingdomPlayer = main.player
	var death_count := [0]
	player.died.connect(func(): death_count[0] += 1)
	player.take_damage(1000)
	player.take_damage(1000)
	player.gain_experience(100)
	player.add_resource("gold", 100)
	_expect(player.current_health == 0 and death_count[0] == 1, "health clamps to zero and death emits once")
	_expect(player.experience == 0 and player.resources["gold"] == 0, "dead player cannot earn rewards")
	_expect(main.hud.result_panel.visible and main.finished, "death displays restart screen")
	player.movement_input.set_virtual_direction(Vector2.RIGHT)
	var position_before := player.position
	await _frames(5)
	_expect(player.position == position_before, "dead player cannot move")
	main.hud.get_node("Root/ResultPanel/Result/RestartButton").pressed.emit()
	await _frames(5)
	_expect(current_scene != null and current_scene != main, "restart button reloads main scene")
	var restarted := current_scene
	_expect(restarted.player.current_health == 100 and restarted.player.level == 1,
		"restart resets player health and progression")
	_expect(get_nodes_in_group("enemies").size() == 12 and not restarted.hud.result_panel.visible,
		"restart restores enemies and hides result screen")
	current_scene = null
	await _discard(restarted)
