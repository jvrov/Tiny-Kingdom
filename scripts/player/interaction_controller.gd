class_name InteractionController
extends Node

signal prompt_changed(text: String)

var enabled := true
var current_target: KingdomInteractable
@onready var actor: KingdomPlayer = get_parent()


func _process(_delta: float) -> void:
	_refresh_target()


func _refresh_target() -> void:
	current_target = null
	var distance := INF
	if enabled and actor.is_alive():
		for candidate in get_tree().get_nodes_in_group("interactables"):
			if candidate is KingdomInteractable and candidate.can_interact(actor):
				var next_distance := actor.global_position.distance_squared_to(candidate.global_position)
				if next_distance < distance:
					current_target = candidate
					distance = next_distance
	prompt_changed.emit("E — " + current_target.prompt if current_target != null else "")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and not event.is_echo():
		if interact():
			get_viewport().set_input_as_handled()


func interact() -> bool:
	# A future touchscreen button can call this same entry point.
	_refresh_target()
	return current_target.interact(actor) if current_target != null else false
