class_name VillageBuilding
extends KingdomInteractable

@export_enum("town_hall", "blacksmith", "archer_tower") var building_id := "town_hall"
signal health_changed
@export var max_health := 150
var current_health := 150
var defending := false
var level := 0
@onready var game_state: Node = get_node("/root/GameState")


func _ready() -> void:
	super._ready()
	action = "building"
	add_to_group("buildings")
	game_state.changed.connect(refresh)
	if building_id == "town_hall":
		max_health = 300
	current_health = max_health
	refresh()


func refresh() -> void:
	level = game_state.building_level(building_id)
	var point: Dictionary = game_state.buildings[building_id].position
	position = Vector2(point.x, point.y)
	var data := BuildingData.definition(building_id)
	prompt = "Construir " + data.name if level == 0 else "Ver " + data.name
	if level > 0 and building_id == "blacksmith":
		prompt = "Melhorar arma no Ferreiro"
	queue_redraw()


func _draw() -> void:
	var data := BuildingData.definition(building_id)
	var font := ThemeDB.fallback_font
	if level == 0:
		draw_rect(Rect2(-51, -35, 102, 70), Color("344e42"))
		draw_rect(Rect2(-51, -35, 102, 70), Color("b3bd8e"), false, 2)
		draw_line(Vector2(-43, -27), Vector2(43, 27), Color("6d8768"), 1)
		draw_line(Vector2(-43, 27), Vector2(43, -27), Color("6d8768"), 1)
		draw_string(font, Vector2(-115, 56), "Terreno disponível", HORIZONTAL_ALIGNMENT_CENTER, 230, 16, Color("d6d8aa"))
		draw_string(font, Vector2(-115, 78), data.name, HORIZONTAL_ALIGNMENT_CENTER, 230, 17, Color("d6d8aa"))
		return
	if defending:
		draw_rect(Rect2(-45, 70, 90, 6), Color("312329"))
		draw_rect(Rect2(-45, 70, 90.0 * current_health / max_health, 6), Color("e8a57b"))
	draw_circle(Vector2(0, 14), 46, Color(0.05, 0.1, 0.1, 0.3))
	match building_id:
		"town_hall":
			draw_rect(Rect2(-42, -24, 84, 58), Color("c4ae7c"))
			draw_colored_polygon(PackedVector2Array([Vector2(-54, -22), Vector2(0, -66), Vector2(54, -22)]), Color("608eac"))
			draw_rect(Rect2(-12, 4, 24, 30), Color("344944"))
			draw_line(Vector2(0, -64), Vector2(0, -85), Color("dfce95"), 3)
			draw_colored_polygon(PackedVector2Array([Vector2(1, -85), Vector2(26, -78), Vector2(1, -71)]), Color("edc566"))
		"blacksmith":
			draw_rect(Rect2(-42, -28, 84, 60), Color("827b72"))
			draw_rect(Rect2(-47, -36, 94, 12), Color("b76d49"))
			draw_rect(Rect2(20, -60, 16, 30), Color("646963"))
			draw_circle(Vector2(-19, 10), 15, Color("ed9b48"))
			draw_colored_polygon(PackedVector2Array([Vector2(0, -2), Vector2(36, -2), Vector2(29, 9), Vector2(23, 9), Vector2(23, 23), Vector2(10, 23), Vector2(10, 9)]), Color("d2d9ce"))
		"archer_tower":
			draw_rect(Rect2(-22, -55, 44, 89), Color("967b54"))
			draw_rect(Rect2(-36, -64, 72, 22), Color("bdac7c"))
			for x in [-32, -7, 18]:
				draw_rect(Rect2(x, -77, 14, 16), Color("bdac7c"))
			draw_line(Vector2(-12, -31), Vector2(12, -31), Color("283f3c"), 5)
			draw_line(Vector2(-12, -7), Vector2(12, -7), Color("283f3c"), 5)
	draw_string(font, Vector2(-125, 58), "%s · Nv. %d" % [data.name, level], HORIZONTAL_ALIGNMENT_CENTER, 250, 17, Color("e7d3a0"))


func set_defending(value: bool) -> void:
	defending = value
	current_health = max_health
	modulate = Color.WHITE
	health_changed.emit()
	queue_redraw()


func is_alive() -> bool:
	return level > 0 and current_health > 0


func take_damage(amount: int) -> void:
	if not defending or not is_alive() or amount <= 0:
		return
	current_health = maxi(0, current_health - amount)
	modulate = Color("676767") if current_health == 0 else Color.WHITE
	health_changed.emit()
	queue_redraw()
