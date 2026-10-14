class_name WaveManager
extends Node
## One runtime state machine owns spawning, results and respawn. No battle is saved.

signal changed
signal message(text: String)
signal battle_finished(won: bool)

enum State { IDLE, PREPARING, ACTIVE, BETWEEN_WAVES, VICTORY, DEFEAT }
const COUNTS := [5, 7, 9, 12, 15]
const REWARD := {"wood": 20, "stone": 15, "gold": 10}
const SPAWNS := [Vector2(640, 45), Vector2(640, 675), Vector2(1235, 360), Vector2(45, 360)]
@export var enemy_scene: PackedScene = preload("res://scenes/enemies/Enemy.tscn")
@export var spawn_interval := 0.8
@export var between_waves := 5.0
@export var respawn_delay := 5.0

var state := State.IDLE
var wave := 0
var spawned := 0
var countdown := 0.0
var respawn_remaining := 0.0
var reward_pending := false
var enemies: Dictionary = {}
var player: KingdomPlayer
var hall: VillageBuilding
var actors: Node
var _spawn_remaining := 0.0
var _difficulty := 0
@onready var game_state: Node = get_node("/root/GameState")


func _ready() -> void:
	game_state.defense = self


func _exit_tree() -> void:
	if game_state.defense == self:
		game_state.defense = null


func is_running() -> bool:
	return state in [State.PREPARING, State.ACTIVE, State.BETWEEN_WAVES]


func is_battle() -> bool:
	return state in [State.ACTIVE, State.BETWEEN_WAVES]


func prepare(actor: KingdomPlayer, container: Node, town_hall: VillageBuilding) -> bool:
	if is_running() or reward_pending or game_state.expedition_active or not actor.is_alive():
		return false
	if game_state.building_level("town_hall") == 0:
		message.emit("Construa a Prefeitura primeiro.")
		return false
	player = actor
	actors = container
	hall = town_hall
	state = State.PREPARING
	changed.emit()
	return true


func cancel_preparation() -> void:
	if state == State.PREPARING:
		state = State.IDLE
		changed.emit()


func start() -> bool:
	if state != State.PREPARING or not is_instance_valid(hall) or not hall.is_alive() or not player.is_alive():
		return false
	_difficulty = mini(game_state.defenses_completed, 10)
	wave = 0
	respawn_remaining = 0
	for building in get_tree().get_nodes_in_group("buildings"):
		building.set_defending(true)
	if not hall.health_changed.is_connected(_hall_changed):
		hall.health_changed.connect(_hall_changed)
	_next_wave()
	message.emit("VILA SOB ATAQUE! Proteja a Prefeitura.")
	return true


static func enemy_stats(wave_number: int, completed: int) -> Dictionary:
	var index := clampi(wave_number, 1, 5) - 1
	var difficulty := clampi(completed, 0, 10)
	return {
		"health": roundi((30 + index * 4) * (1.0 + difficulty * 0.05)),
		"damage": roundi((5 + index) * (1.0 + difficulty * 0.03)),
		"speed": 72.0 + index * 3.0
	}


func _next_wave() -> void:
	wave += 1
	spawned = 0
	_spawn_remaining = 0
	state = State.ACTIVE
	changed.emit()


func _physics_process(delta: float) -> void:
	if not is_battle():
		return
	if respawn_remaining > 0:
		respawn_remaining = maxf(0, respawn_remaining - delta)
		if respawn_remaining == 0:
			_restore_player()
	if state == State.BETWEEN_WAVES:
		countdown = maxf(0, countdown - delta)
		if countdown == 0:
			_next_wave()
	elif state == State.ACTIVE:
		_spawn_remaining -= delta
		if spawned < COUNTS[wave - 1] and _spawn_remaining <= 0:
			_spawn_enemy()
			_spawn_remaining = maxf(0.05, spawn_interval)
	changed.emit()


func choose_spawn(index: int) -> Vector2:
	# Rotate the entry point, skipping any point occupied by the player.
	for offset in range(SPAWNS.size()):
		var point: Vector2 = SPAWNS[(index + offset) % SPAWNS.size()]
		if point.distance_to(player.global_position) >= 220:
			return point
	return SPAWNS[index % SPAWNS.size()]


func _spawn_enemy() -> void:
	var enemy := enemy_scene.instantiate() as KingdomEnemy
	var stats := enemy_stats(wave, _difficulty)
	enemy.max_health = stats.health
	enemy.damage = stats.damage
	enemy.speed = stats.speed
	enemy.invading = true
	enemy.defended_hall = hall
	enemy.defending_player = player
	enemy.position = choose_spawn(spawned)
	var id := enemy.get_instance_id()
	enemies[id] = enemy
	enemy.defeated.connect(_enemy_defeated.bind(id))
	spawned += 1
	actors.add_child(enemy)


func _enemy_defeated(id: int) -> void:
	if not enemies.has(id):
		return
	enemies.erase(id)
	if state == State.ACTIVE and spawned == COUNTS[wave - 1] and enemies.is_empty():
		message.emit("Onda %d concluída!" % wave)
		if wave == COUNTS.size():
			_finish(true)
		else:
			state = State.BETWEEN_WAVES
			countdown = between_waves
	changed.emit()


func _hall_changed() -> void:
	if is_battle() and not hall.is_alive():
		_finish(false)
	changed.emit()


func incapacitate_player() -> void:
	if is_battle() and not player.is_alive() and respawn_remaining <= 0:
		respawn_remaining = respawn_delay
		player.interaction.enabled = false
		message.emit("Incapacitado! Retorno em 5 segundos. A defesa continua.")
		changed.emit()


func _restore_player() -> void:
	player.position = Vector2(640, 440)
	player.apply_progress(game_state.progression, game_state.expedition_resources)
	player.interaction.enabled = true


func _clear_enemies() -> void:
	for enemy in enemies.values():
		if is_instance_valid(enemy):
			enemy.remove_from_group("enemies")
			enemy.set_physics_process(false)
			enemy.queue_free()
	enemies.clear()


func _restore_village() -> void:
	respawn_remaining = 0
	_clear_enemies()
	for building in get_tree().get_nodes_in_group("buildings"):
		building.set_defending(false)
	if is_instance_valid(player):
		_restore_player()


func _finish(won: bool) -> void:
	if not is_battle():
		return
	state = State.VICTORY if won else State.DEFEAT
	reward_pending = won
	_restore_village()
	if won:
		claim_reward()
	else:
		message.emit("A vila foi derrotada. Construções e estoque preservados.")
	changed.emit()
	battle_finished.emit(won)


func can_claim_reward() -> bool:
	return state == State.VICTORY and reward_pending


func claim_reward() -> bool:
	if not can_claim_reward():
		return false
	if game_state.commit_defense_reward():
		message.emit("Vila defendida! +20 madeira · +15 pedra · +10 ouro")
		changed.emit()
		return true
	message.emit("Vila defendida! Falha ao salvar recompensa. Use E na bandeira para tentar novamente antes de sair.")
	changed.emit()
	return false


func cancel() -> void:
	state = State.IDLE
	reward_pending = false
	_restore_village()
	wave = 0
	spawned = 0
	countdown = 0
	changed.emit()
