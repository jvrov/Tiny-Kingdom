extends VillageBuilding

@export var attack_range: float = 300.0
@export var damage: int = 10
@export var attack_cooldown: float = 1.0
var _remaining := 0.0
var _flash := 0.0
var _hit_point := Vector2.ZERO


func _physics_process(delta: float) -> void:
	_remaining = maxf(0, _remaining - delta)
	_flash = maxf(0, _flash - delta)
	if level > 0 and _remaining <= 0:
		var enemy := nearest_enemy()
		if enemy != null:
			_remaining = attack_cooldown
			_flash = 0.18
			_hit_point = to_local(enemy.global_position)
			# Defensive kills do not grant expedition cargo or XP.
			enemy.take_damage(damage)
	queue_redraw()


func nearest_enemy() -> KingdomEnemy:
	var result: KingdomEnemy = null
	var distance := attack_range * attack_range
	for candidate in get_tree().get_nodes_in_group("enemies"):
		if candidate is KingdomEnemy and candidate.is_alive():
			var next := global_position.distance_squared_to(candidate.global_position)
			if next <= distance:
				distance = next
				result = candidate
	return result


func _draw() -> void:
	super._draw()
	if level > 0 and _flash > 0:
		draw_line(Vector2(0, -53), _hit_point, Color(1, 0.87, 0.5, _flash / 0.18), 3, true)
		draw_circle(_hit_point, 8, Color(1, 0.87, 0.5, _flash / 0.18))
