extends Node2D
## One player/HUD survive map changes. GameState survives the whole session.

const ITEM_SCENE := preload("res://scenes/items/WorldItem.tscn")
const ENEMY_SCENE := preload("res://scenes/enemies/Enemy.tscn")
const WORLD_SCENE := preload("res://scenes/world/World.tscn")
const VILLAGE_SCENE := preload("res://scenes/world/Village.tscn")
const ENEMY_POSITIONS: Array[Vector2] = [
	Vector2(1050, 900), Vector2(1210, 1080), Vector2(1200, 740),
	Vector2(1430, 1000), Vector2(1570, 650), Vector2(1720, 840),
	Vector2(1870, 1100), Vector2(2060, 800), Vector2(2110, 570),
	Vector2(1640, 1280), Vector2(1130, 1430), Vector2(2170, 1370)
]

var remaining_enemies := 0
var finished := false
var in_village := true
var transitioning := false
var dying := false
var _generation := 0

@onready var game_state: Node = get_node("/root/GameState")
@onready var player: KingdomPlayer = $Actors/Player
@onready var hud: KingdomHUD = $HUD
@onready var waves: WaveManager = $WaveManager


func _ready() -> void:
	game_state.initialize()
	player.stats_changed.connect(func(): game_state.sync_player(player))
	player.died.connect(_on_player_died)
	player.interaction.prompt_changed.connect(hud.set_interaction_prompt)
	hud.reset_requested.connect(reset_progress)
	hud.building_panel.purchase_requested.connect(_on_purchase_requested)
	game_state.weapon_upgraded.connect(_on_weapon_upgraded)
	game_state.inventory_changed.connect(_on_weapon_upgraded)
	hud.inventory_panel.bind_player(player)
	hud.defense_confirmed.connect(_confirm_defense)
	hud.defense_canceled.connect(waves.cancel_preparation)
	waves.message.connect(func(text): hud.show_message(text, 7.0))
	waves.changed.connect(_refresh_defense)
	hud.bind_player(player)
	_load_map(true)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("inventory"):
		if not transitioning and not dying and player.is_alive() and not get_tree().paused:
			hud.inventory_panel.open()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("debug_loot"):
		debug_spawn_item()
		get_viewport().set_input_as_handled()
	if OS.is_debug_build() and event.is_action_pressed("debug_reset") and not event.is_echo():
		hud.confirm_reset()
		get_viewport().set_input_as_handled()


func _load_map(village: bool) -> void:
	_generation += 1
	for drop in $Drops.get_children():
		$Drops.remove_child(drop)
		drop.queue_free()
	in_village = village
	dying = false
	finished = false
	for child in $Map.get_children():
		$Map.remove_child(child)
		child.queue_free()
	for child in $Actors.get_children():
		if child != player:
			$Actors.remove_child(child)
			child.queue_free()
	var map := (VILLAGE_SCENE if village else WORLD_SCENE).instantiate()
	$Map.add_child(map)
	for object in map.get_children():
		if object is VillageBuilding:
			object.interacted.connect(_on_building_interacted.bind(object))
		elif object is KingdomInteractable:
			object.interacted.connect(_on_interacted.bind(object.action))
	player.position = Vector2(640, 440) if village else Vector2(600, 900)
	player.resources = game_state.expedition_resources.duplicate()
	_on_weapon_upgraded()
	player.apply_progress(game_state.progression, game_state.expedition_resources)
	player.interaction.enabled = true
	var camera: Camera2D = player.get_node("Camera2D")
	camera.limit_right = 1280 if village else 2600
	camera.limit_bottom = 720 if village else 1800
	camera.reset_smoothing()
	remaining_enemies = 0 if village else ENEMY_POSITIONS.size()
	if not village:
		for spawn_position in ENEMY_POSITIONS:
			var enemy := ENEMY_SCENE.instantiate() as KingdomEnemy
			enemy.position = spawn_position
			enemy.target = player
			enemy.loot_enabled = true
			enemy.loot_dropped.connect(spawn_item)
			enemy.defeated.connect(_on_enemy_defeated)
			$Actors.add_child(enemy)
	hud.result_panel.hide()
	hud.set_location(village)
	if not village:
		hud.update_objective(remaining_enemies, ENEMY_POSITIONS.size())
	transitioning = false


func _on_building_interacted(_actor: KingdomPlayer, building: VillageBuilding) -> void:
	if _block_defense():
		return
	if in_village and not transitioning and not dying and player.is_alive():
		hud.building_panel.open(building.building_id)


func _on_purchase_requested(id: String, action: String, expected_level: int) -> void:
	if _block_defense():
		return
	if not in_village or transitioning or dying or not player.is_alive():
		return
	var nearby := false
	for building in get_tree().get_nodes_in_group("buildings"):
		if building.building_id == id and building.can_interact(player):
			nearby = true
	if not nearby:
		hud.building_panel.show_error("Aproxime-se do terreno para construir.")
		return
	if game_state.purchase_building(id, action, expected_level):
		hud.building_panel.close()
		hud.show_message(game_state.action_message)
	else:
		hud.building_panel.show_error(game_state.action_message)


func _on_weapon_upgraded() -> void:
	player.apply_equipment(game_state.progression, game_state.equipment, game_state.attribute_base.speed)


func _on_interacted(_actor: KingdomPlayer, action: String) -> void:
	if transitioning or dying:
		return
	match action:
		"depart": start_expedition()
		"return": return_to_village()
		"deposit": deposit_resources()
		"defend": request_defense()


func start_expedition() -> bool:
	if _block_defense():
		return false
	if waves.reward_pending:
		hud.show_message("Receba a recompensa pendente na bandeira antes de partir.")
		return false
	if not in_village or transitioning or dying:
		return false
	if not game_state.begin_expedition():
		hud.show_message("Deposite os recursos carregados antes de partir.")
		return false
	transitioning = true
	player.interaction.enabled = false
	_load_map.call_deferred(false)
	return true


func return_to_village() -> bool:
	if in_village or transitioning or dying or not player.is_alive():
		return false
	game_state.sync_player(player)
	if not game_state.finish_expedition(true):
		return false
	transitioning = true
	player.interaction.enabled = false
	_load_map.call_deferred(true)
	hud.show_message("Expedição concluída! Leve os recursos ao depósito.")
	return true


func deposit_resources() -> bool:
	if _block_defense():
		return false
	if not in_village or transitioning or dying:
		return false
	if not game_state.has_cargo():
		hud.show_message("Você não está carregando recursos.")
		return false
	if not game_state.deposit():
		hud.show_message("Depósito não concluído. Os recursos continuam com você.")
		return false
	player.resources = game_state.expedition_resources.duplicate()
	player.stats_changed.emit()
	hud.show_message("Recursos depositados! Progresso salvo.")
	return true


func _on_enemy_defeated() -> void:
	remaining_enemies -= 1
	hud.update_objective(remaining_enemies, ENEMY_POSITIONS.size())
	if remaining_enemies == 0:
		finished = true
		hud.show_message("Clareira protegida! Volte ao marco de retorno para ir à vila.", 7.0)


func _on_player_died() -> void:
	if in_village and waves.is_battle():
		waves.incapacitate_player()
		return
	if dying or in_village:
		return
	dying = true
	player.interaction.enabled = false
	game_state.sync_player(player)
	game_state.finish_expedition(false)
	player.resources = game_state.expedition_resources.duplicate()
	player.stats_changed.emit()
	hud.show_failure()
	var generation := _generation
	await get_tree().create_timer(2.0, false).timeout
	if generation == _generation and dying:
		transitioning = true
		_load_map.call_deferred(true)


func reset_progress() -> void:
	if not OS.is_debug_build():
		return
	if game_state.reset_progress():
		player.resources = game_state.expedition_resources.duplicate()
		_on_weapon_upgraded()
		waves.cancel()
		# Invalidate a pending death timer before scheduling the new map.
		_generation += 1
		transitioning = true
		_load_map.call_deferred(true)
		hud.show_message("Progresso reiniciado.")


func _block_defense() -> bool:
	if game_state.defense_busy():
		hud.show_message("A vila está sob ataque!")
		return true
	return false


func request_defense() -> bool:
	if not in_village or transitioning or dying or not player.is_alive():
		return false
	if _block_defense():
		return false
	if waves.reward_pending:
		return waves.claim_reward()
	if not waves.prepare(player, $Actors, $Map/Village/TownHall):
		return false
	hud.confirm_defense()
	return true


func _confirm_defense() -> void:
	if in_village and not transitioning and player.is_alive():
		if waves.start():
			return
	waves.cancel_preparation()


func _refresh_defense() -> void:
	hud.update_defense(waves)
	if in_village and $Map.get_child_count() > 0:
		$Map.get_child(0).set_under_attack(waves.is_battle())


func spawn_item(id: String, point: Vector2) -> WorldItem:
	if ItemData.definition(id).is_empty():
		return null
	var item := ITEM_SCENE.instantiate() as WorldItem
	item.item_id = id
	item.position = point
	item.collected.connect(func(item_id): hud.show_message("Item recebido: " + ItemData.definition(item_id).name))
	item.pickup_failed.connect(hud.show_message)
	$Drops.add_child(item)
	return item


func debug_spawn_item() -> WorldItem:
	if not OS.is_debug_build() or transitioning or dying or not player.is_alive() or game_state.defense_busy():
		return null
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var id := "health_potion" if rng.randf() < 0.25 else ItemData.random_equipment(rng)
	return spawn_item(id, player.position + Vector2(45, 0))
