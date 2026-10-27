class_name WorldItem
extends Node2D

signal collected(id: String)
signal pickup_failed(message: String)
@export var item_id := "rusty_sword"
@export var pickup_range := 30.0
var _retry := 0.0
@onready var game_state: Node = get_node("/root/GameState")


func _ready() -> void:
	add_to_group("world_items")
	queue_redraw()


func _physics_process(delta: float) -> void:
	_retry = maxf(0, _retry - delta)
	var player := get_tree().get_first_node_in_group("player") as KingdomPlayer
	if _retry == 0 and is_instance_valid(player) and player.is_alive() and global_position.distance_to(player.global_position) <= pickup_range:
		try_pickup(player)


func try_pickup(player: KingdomPlayer) -> bool:
	if is_queued_for_deletion() or not player.is_alive() or global_position.distance_to(player.global_position) > pickup_range:
		return false
	if game_state.collect_item(item_id):
		set_physics_process(false)
		remove_from_group("world_items")
		collected.emit(item_id)
		queue_free()
		return true
	_retry = 2.0
	pickup_failed.emit(game_state.action_message)
	return false


func _draw() -> void:
	var item := ItemData.definition(item_id)
	if item.is_empty(): return
	var color: Color = ItemData.COLORS[item.rarity]
	draw_circle(Vector2.ZERO, 23, Color(color, 0.16))
	draw_rect(Rect2(-15, -15, 30, 30), Color("193330"))
	draw_rect(Rect2(-15, -15, 30, 30), color, false, 3)
	draw_string(ThemeDB.fallback_font, Vector2(-15, 5), item.icon, HORIZONTAL_ALIGNMENT_CENTER, 30, 12, color)
	draw_string(ThemeDB.fallback_font, Vector2(-115, -30), item.name, HORIZONTAL_ALIGNMENT_CENTER, 230, 15, color)
	if item.rarity == "epic":
		draw_arc(Vector2.ZERO, 26, 0, TAU, 32, color, 2)
