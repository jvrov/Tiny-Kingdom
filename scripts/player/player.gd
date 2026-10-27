class_name KingdomPlayer
extends CharacterBody2D

signal stats_changed
signal level_gained(new_level: int)
signal resource_gained(resource_name: String, amount: int)
signal died

@export var speed: float = 230.0
@export var max_health: int = 100
@export var damage: int = 18
@export var attack_range: float = 115.0
@export var attack_cooldown: float = 0.65

var equipment_bonuses := {"damage": 0, "max_health": 0, "speed": 0}
var base_speed := 230.0
var current_health: int
var experience: int = 0
var level: int = 1
var resources: Dictionary = {"wood": 0, "stone": 0, "gold": 0}
var _attack_remaining: float = 0.0
var _attack_flash: float = 0.0
var _hurt_flash: float = 0.0
var _attack_point := Vector2.ZERO
var _facing := Vector2.RIGHT

@onready var movement_input: MovementInput = $MovementInput
@onready var interaction: InteractionController = $InteractionController


func apply_progress(progress: Dictionary, cargo: Dictionary) -> void:
	level = progress.level
	experience = progress.xp
	max_health = progress.max_health + equipment_bonuses.max_health
	damage = progress.damage + equipment_bonuses.damage
	speed = base_speed + equipment_bonuses.speed
	resources = cargo.duplicate()
	current_health = max_health
	velocity = Vector2.ZERO
	_attack_remaining = 0.0
	_attack_flash = 0.0
	_hurt_flash = 0.0
	movement_input.clear_virtual_direction()
	stats_changed.emit()


func _ready() -> void:
	current_health = max_health
	add_to_group("player")
	stats_changed.emit()


func _physics_process(delta: float) -> void:
	_attack_flash = maxf(0.0, _attack_flash - delta)
	_hurt_flash = maxf(0.0, _hurt_flash - delta)
	if not is_alive():
		velocity = Vector2.ZERO
		queue_redraw()
		return
	move_in_direction(movement_input.get_direction())
	_attack_remaining = maxf(0.0, _attack_remaining - delta)
	if _attack_remaining <= 0.0:
		var target := find_nearest_enemy()
		if target != null:
			_attack_point = to_local(target.global_position)
			_attack_flash = 0.16
			_attack_remaining = attack_cooldown
			target.take_damage(damage, self)
	queue_redraw()


func move_in_direction(direction: Vector2) -> void:
	# CharacterBody2D uses pixels/second; move_and_slide applies physics delta.
	# Multiplying velocity by delta here would make movement frame-rate dependent.
	velocity = direction.limit_length(1.0) * speed
	if not velocity.is_zero_approx():
		_facing = velocity.normalized()
	move_and_slide()


func find_nearest_enemy() -> Node2D:
	var nearest: Node2D = null
	var nearest_distance := attack_range * attack_range
	for candidate in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(candidate) or not candidate.is_alive():
			continue
		var distance := global_position.distance_squared_to(candidate.global_position)
		if distance <= nearest_distance:
			nearest_distance = distance
			nearest = candidate
	return nearest


func is_alive() -> bool:
	return current_health > 0


func take_damage(amount: int) -> void:
	if not is_alive() or amount <= 0:
		return
	current_health = maxi(0, current_health - amount)
	_hurt_flash = 0.18
	stats_changed.emit()
	if not is_alive():
		velocity = Vector2.ZERO
		died.emit()


func xp_required() -> int:
	return 30 + (level - 1) * 20


func gain_experience(amount: int) -> void:
	if not is_alive() or amount <= 0:
		return
	experience += amount
	while experience >= xp_required():
		experience -= xp_required()
		level += 1
		max_health += 15
		damage += 4
		current_health = mini(max_health, current_health + 25)
		level_gained.emit(level)
	stats_changed.emit()


func add_resource(resource_name: String, amount: int) -> void:
	if not is_alive() or not resources.has(resource_name) or amount <= 0:
		return
	resources[resource_name] += amount
	resource_gained.emit(resource_name, amount)
	stats_changed.emit()


func _draw() -> void:
	draw_circle(Vector2(0, 9), 20, Color(0.03, 0.06, 0.06, 0.3))
	if not is_alive():
		draw_circle(Vector2.ZERO, 16, Color("66767e"))
		return
	draw_arc(Vector2.ZERO, attack_range, 0, TAU, 64, Color(0.6, 0.86, 1.0, 0.13), 1.0)
	draw_circle(Vector2.ZERO, 19, Color("142e46"))
	draw_circle(Vector2.ZERO, 15, Color.WHITE if _hurt_flash > 0 else Color("62b5ef"))
	draw_circle(_facing * 9, 4, Color("d8f4ff"))
	# A tiny crown keeps the placeholder recognizable without any external assets.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-10, -12), Vector2(-12, -23), Vector2(-4, -18),
		Vector2(0, -27), Vector2(5, -18), Vector2(12, -23), Vector2(10, -12)
	]), Color("f3cc75"))
	if _attack_flash > 0:
		var alpha := _attack_flash / 0.16
		draw_line(Vector2.ZERO, _attack_point, Color(1.0, 0.9, 0.55, alpha), 5, true)
		draw_arc(_attack_point, 12 + (1 - alpha) * 14, 0, TAU, 24,
			Color(1.0, 0.94, 0.7, alpha), 3, true)


func apply_equipment(progress: Dictionary, equipped: Dictionary, permanent_speed: float) -> void:
	level = progress.level
	experience = progress.xp
	equipment_bonuses = InventoryData.bonuses(equipped)
	base_speed = permanent_speed
	damage = progress.damage + equipment_bonuses.damage
	max_health = progress.max_health + equipment_bonuses.max_health
	speed = base_speed + equipment_bonuses.speed
	# Swapping armor never heals or resurrects.
	current_health = mini(current_health, max_health)
	stats_changed.emit()
