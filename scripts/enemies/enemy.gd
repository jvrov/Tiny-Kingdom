class_name KingdomEnemy
extends CharacterBody2D

signal defeated

@export var speed: float = 92.0
@export var max_health: int = 36
@export var damage: int = 8
@export var detection_range: float = 420.0
@export var attack_range: float = 44.0
@export var stop_distance: float = 37.0
@export var attack_cooldown: float = 1.1
@export var experience_reward: int = 15
@export_range(0.0, 1.0) var drop_chance: float = 0.65

var current_health: int
var target: KingdomPlayer
var _dead := false
var _attack_remaining: float = 0.0
var _hurt_flash: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	current_health = max_health
	_rng.randomize()
	add_to_group("enemies")
	if not is_instance_valid(target):
		target = get_tree().get_first_node_in_group("player") as KingdomPlayer


func _physics_process(delta: float) -> void:
	_attack_remaining = maxf(0.0, _attack_remaining - delta)
	_hurt_flash = maxf(0.0, _hurt_flash - delta)
	velocity = Vector2.ZERO
	if is_alive() and is_instance_valid(target) and target.is_alive():
		var offset := target.global_position - global_position
		var distance := offset.length()
		if distance <= detection_range:
			if distance > stop_distance:
				velocity = offset.normalized() * speed
			if distance <= attack_range and _attack_remaining <= 0.0:
				_attack_remaining = attack_cooldown
				target.take_damage(damage)
	move_and_slide()
	queue_redraw()


func is_alive() -> bool:
	return not _dead and current_health > 0


func take_damage(amount: int, source: KingdomPlayer = null) -> void:
	if not is_alive() or amount <= 0:
		return
	current_health = maxi(0, current_health - amount)
	_hurt_flash = 0.15
	if current_health == 0:
		_dead = true
		remove_from_group("enemies")
		set_physics_process(false)
		set_deferred("collision_layer", 0)
		set_deferred("collision_mask", 0)
		# Guarded by _dead: multiple hits in one frame cannot duplicate rewards.
		if is_instance_valid(source) and source.is_alive():
			source.gain_experience(experience_reward)
			if _rng.randf() < drop_chance:
				var kinds := ["wood", "stone", "gold"]
				source.add_resource(kinds[_rng.randi_range(0, kinds.size() - 1)],
					_rng.randi_range(1, 3))
		defeated.emit()
		queue_free()
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2(0, 8), 19, Color(0.03, 0.06, 0.06, 0.3))
	draw_circle(Vector2.ZERO, 18, Color("592d38"))
	draw_circle(Vector2.ZERO, 14, Color.WHITE if _hurt_flash > 0 else Color("dc7273"))
	draw_circle(Vector2(-5, -3), 3, Color("fff0db"))
	draw_circle(Vector2(5, -3), 3, Color("fff0db"))
	draw_line(Vector2(-6, 6), Vector2(6, 6), Color("592d38"), 2)
	if current_health < max_health:
		draw_rect(Rect2(-19, -29, 38, 5), Color("282f35"))
		draw_rect(Rect2(-19, -29, 38.0 * current_health / max_health, 5), Color("ef9690"))
