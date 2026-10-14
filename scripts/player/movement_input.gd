class_name MovementInput
extends Node
## The movement source is independent of physics and combat.
## A future joystick calls set_virtual_direction(), then clear_virtual_direction()
## on touch release/cancel. Analog intensity is preserved; diagonals are capped.

var _virtual_direction := Vector2.ZERO
var _virtual_active := false


func get_direction() -> Vector2:
	if _virtual_active:
		return _virtual_direction
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")


func set_virtual_direction(direction: Vector2) -> void:
	_virtual_direction = direction.limit_length(1.0)
	_virtual_active = true


func clear_virtual_direction() -> void:
	_virtual_direction = Vector2.ZERO
	_virtual_active = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		clear_virtual_direction()
