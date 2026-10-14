extends "res://scripts/systems/world.gd"


func _ready() -> void:
	_add_wall(Vector2(640, -20), Vector2(1360, 40))
	_add_wall(Vector2(640, 740), Vector2(1360, 40))
	_add_wall(Vector2(-20, 360), Vector2(40, 720))
	_add_wall(Vector2(1300, 360), Vector2(40, 720))


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("284b43"))
	draw_rect(Rect2(8, 8, 1264, 704), Color("8a9b74"), false, 10)
	draw_circle(Vector2(640, 385), 175, Color("3b5548"))
	draw_line(Vector2(420, 385), Vector2(940, 385), Color("5b6852"), 80)
	draw_circle(Vector2(640, 385), 68, Color("667761"))
	draw_circle(Vector2(640, 385), 60, Color("536854"))
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(420, 122), "VILA DO PEQUENO REINO", HORIZONTAL_ALIGNMENT_CENTER,
		440, 25, Color("e8d5a2"))
	draw_string(font, Vector2(420, 155), "Explore. Retorne. Guarde seu futuro.", HORIZONTAL_ALIGNMENT_CENTER,
		440, 18, Color("b4c7ad"))
	for point in [Vector2(90, 320), Vector2(1160, 310), Vector2(340, 610), Vector2(900, 600)]:
		_draw_tree(point)
	_draw_rock(Vector2(720, 600))
