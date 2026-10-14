class_name KingdomInteractable
extends Node2D
## Objects publish an action; keyboard/touch input lives on the player.

signal interacted(actor: KingdomPlayer)

@export_enum("deposit", "depart", "return") var action: String = "deposit"
@export var prompt := "Depositar recursos"
@export var interaction_range: float = 90.0


func _ready() -> void:
	add_to_group("interactables")


func can_interact(actor: KingdomPlayer) -> bool:
	return is_visible_in_tree() and actor.is_alive() and global_position.distance_to(actor.global_position) <= interaction_range


func interact(actor: KingdomPlayer) -> bool:
	if not can_interact(actor):
		return false
	interacted.emit(actor)
	return true


func _draw() -> void:
	var color := Color("d9bd79") if action == "deposit" else Color("76c6cf")
	draw_circle(Vector2(0, 10), 38, Color(0.05, 0.1, 0.1, 0.3))
	if action == "deposit":
		draw_rect(Rect2(-30, -25, 60, 50), Color("826441"))
		draw_rect(Rect2(-30, -25, 60, 50), color, false, 3)
		draw_line(Vector2(-30, -6), Vector2(30, -6), color, 3)
		draw_rect(Rect2(-5, -12, 10, 16), color)
	else:
		draw_circle(Vector2.ZERO, 31, Color("233d42"))
		draw_arc(Vector2.ZERO, 32, 0, TAU, 48, color, 4, true)
		draw_line(Vector2(-15, 0), Vector2(15, 0), color, 4)
		draw_line(Vector2(15, 0), Vector2(5, -10), color, 4)
		draw_line(Vector2(15, 0), Vector2(5, 10), color, 4)
	var label := "DEPÓSITO" if action == "deposit" else ("EXPEDIÇÃO" if action == "depart" else "VOLTAR À VILA")
	draw_string(ThemeDB.fallback_font, Vector2(-105, 62), label,
		HORIZONTAL_ALIGNMENT_CENTER, 210, 18, color)
