extends Node2D
## One player/HUD survive map changes. GameState survives the whole session.

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


func _ready() -> void:
	game_state.initialize()
	player.stats_changed.connect(func(): game_state.sync_player(player))
	player.died.connect(_on_player_died)
	player.interaction.prompt_changed.connect(hud.set_interaction_prompt)
	hud.reset_requested.connect(reset_progress)
	hud.bind_player(player)
	_load_map(true)


func _unhandled_input(event: InputEvent) -> void:
	if OS.is_debug_build() and event.is_action_pressed("debug_reset") and not event.is_echo():
		hud.confirm_reset()
		get_viewport().set_input_as_handled()


func _load_map(village: bool) -> void:
	_generation += 1
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
		if object is KingdomInteractable:
			object.interacted.connect(_on_interacted.bind(object.action))
	player.position = Vector2(640, 440) if village else Vector2(600, 900)
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
			enemy.defeated.connect(_on_enemy_defeated)
			$Actors.add_child(enemy)
	hud.result_panel.hide()
	hud.set_location(village)
	if not village:
		hud.update_objective(remaining_enemies, ENEMY_POSITIONS.size())
	transitioning = false


func _on_interacted(_actor: KingdomPlayer, action: String) -> void:
	if transitioning or dying:
		return
	match action:
		"depart": start_expedition()
		"return": return_to_village()
		"deposit": deposit_resources()


func start_expedition() -> bool:
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
		# Invalidate a pending death timer before scheduling the new map.
		_generation += 1
		transitioning = true
		_load_map.call_deferred(true)
		hud.show_message("Progresso reiniciado.")
