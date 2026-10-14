extends Node2D

const ENEMY_SCENE := preload("res://scenes/enemies/Enemy.tscn")
const ENEMY_POSITIONS: Array[Vector2] = [
	Vector2(1050, 900), Vector2(1210, 1080), Vector2(1200, 740),
	Vector2(1430, 1000), Vector2(1570, 650), Vector2(1720, 840),
	Vector2(1870, 1100), Vector2(2060, 800), Vector2(2110, 570),
	Vector2(1640, 1280), Vector2(1130, 1430), Vector2(2170, 1370)
]

var remaining_enemies: int = 0
var finished := false

@onready var player: KingdomPlayer = $Actors/Player
@onready var hud: KingdomHUD = $HUD


func _ready() -> void:
	hud.bind_player(player)
	hud.restart_requested.connect(restart)
	player.died.connect(_on_player_died)
	remaining_enemies = ENEMY_POSITIONS.size()
	for spawn_position in ENEMY_POSITIONS:
		var enemy := ENEMY_SCENE.instantiate() as KingdomEnemy
		enemy.position = spawn_position
		enemy.target = player
		enemy.defeated.connect(_on_enemy_defeated)
		$Actors.add_child(enemy)
	hud.update_objective(remaining_enemies, ENEMY_POSITIONS.size())
	$Actors/Player/Camera2D.reset_smoothing()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart") and not event.is_echo():
		restart()


func restart() -> void:
	get_tree().reload_current_scene()


func _on_enemy_defeated() -> void:
	remaining_enemies -= 1
	hud.update_objective(remaining_enemies, ENEMY_POSITIONS.size())
	if remaining_enemies == 0 and not finished:
		finished = true
		hud.show_result(true)


func _on_player_died() -> void:
	if finished:
		return
	finished = true
	hud.show_result(false)
