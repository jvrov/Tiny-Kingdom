extends Node2D
## Deterministic placeholder scenery; only the perimeter has physical collision.

const SIZE := Vector2(2600, 1800)
const VILLAGE := Rect2(330, 670, 450, 420)


func _ready() -> void:
	_add_wall(Vector2(SIZE.x / 2, -20), Vector2(SIZE.x + 80, 40))
	_add_wall(Vector2(SIZE.x / 2, SIZE.y + 20), Vector2(SIZE.x + 80, 40))
	_add_wall(Vector2(-20, SIZE.y / 2), Vector2(40, SIZE.y))
	_add_wall(Vector2(SIZE.x + 20, SIZE.y / 2), Vector2(40, SIZE.y))


func _add_wall(center: Vector2, dimensions: Vector2) -> void:
	var wall := StaticBody2D.new()
	wall.position = center
	wall.collision_layer = 1
	wall.collision_mask = 6
	var collider := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = dimensions
	collider.shape = rectangle
	wall.add_child(collider)
	add_child(wall)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SIZE), Color("284b43"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 12071
	for index in range(460):
		var point := Vector2(rng.randf_range(20, SIZE.x - 20), rng.randf_range(20, SIZE.y - 20))
		draw_line(point, point + Vector2(3, -7), Color("35594b"), 2)
		draw_line(point + Vector2(5, 0), point + Vector2(8, -5), Color("35594b"), 2)
	# A simple trail links the future village to the exploration area.
	draw_polyline(PackedVector2Array([
		Vector2(550, 900), Vector2(1100, 920), Vector2(1500, 700), Vector2(2220, 800)
	]), Color("4e6251"), 92, true)
	draw_circle(Vector2(1680, 980), 300, Color(0.4, 0.55, 0.4, 0.09))
	draw_rect(VILLAGE, Color("374e43"))
	var corners := [VILLAGE.position, Vector2(VILLAGE.end.x, VILLAGE.position.y),
		VILLAGE.end, Vector2(VILLAGE.position.x, VILLAGE.end.y)]
	for index in range(4):
		draw_dashed_line(corners[index], corners[(index + 1) % 4], Color("abaf7d"), 2, 10)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(370, 708), "FUTURA VILA", HORIZONTAL_ALIGNMENT_LEFT,
		-1, 20, Color("ded9af"))
	draw_string(font, Vector2(370, 735), "Um pequeno reino começa aqui.",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("a8b9a4"))
	draw_string(font, Vector2(1480, 490), "CLAREIRA DOS ERRANTES", HORIZONTAL_ALIGNMENT_LEFT,
		-1, 22, Color("a3bba5"))
	# Camp marker and tent are scenery, not buildable structures yet.
	draw_line(Vector2(420, 850), Vector2(420, 775), Color("c5b18a"), 4)
	draw_colored_polygon(PackedVector2Array([
		Vector2(422, 775), Vector2(466, 788), Vector2(422, 804)
	]), Color("6cabe0"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(650, 795), Vector2(608, 850), Vector2(698, 850)
	]), Color("c3aa73"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(650, 806), Vector2(634, 850), Vector2(668, 850)
	]), Color("4d5040"))
	for point in [Vector2(200, 400), Vector2(340, 340), Vector2(480, 420),
		Vector2(900, 590), Vector2(1120, 480), Vector2(1380, 250), Vector2(2200, 350),
		Vector2(2350, 560), Vector2(2400, 1200), Vector2(1850, 1500), Vector2(1500, 1440),
		Vector2(850, 1300), Vector2(380, 1280), Vector2(200, 1000)]:
		_draw_tree(point)
	for point in [Vector2(960, 1100), Vector2(1250, 680), Vector2(1750, 410),
		Vector2(2130, 1300), Vector2(650, 1450), Vector2(150, 650), Vector2(2300, 1550)]:
		_draw_rock(point)
	draw_rect(Rect2(Vector2(5, 5), SIZE - Vector2(10, 10)), Color("8a9b74"), false, 10)


func _draw_tree(point: Vector2) -> void:
	draw_circle(point + Vector2(6, 12), 34, Color(0.04, 0.1, 0.08, 0.25))
	draw_rect(Rect2(point + Vector2(-6, -10), Vector2(12, 35)), Color("8f7452"))
	draw_circle(point + Vector2(0, -20), 31, Color("183e38"))
	draw_circle(point + Vector2(-9, -30), 23, Color("3c7056"))
	draw_circle(point + Vector2(15, -18), 21, Color("467c5d"))


func _draw_rock(point: Vector2) -> void:
	draw_circle(point + Vector2(5, 8), 24, Color(0.04, 0.1, 0.08, 0.25))
	draw_colored_polygon(PackedVector2Array([
		point + Vector2(-24, 7), point + Vector2(-15, -15), point + Vector2(7, -23),
		point + Vector2(24, -2), point + Vector2(14, 14)
	]), Color("8eaaa4"))
	draw_line(point + Vector2(-15, -15), point + Vector2(7, -23), Color("c1cec0"), 3)
