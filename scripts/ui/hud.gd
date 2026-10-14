class_name KingdomHUD
extends CanvasLayer

signal restart_requested

const RESOURCE_NAMES := {"wood": "Madeira", "stone": "Pedra", "gold": "Ouro"}
var player: KingdomPlayer
var _toast_remaining: float = 0.0

@onready var health_bar: ProgressBar = %HealthBar
@onready var xp_bar: ProgressBar = %XPBar
@onready var health_text: Label = %HealthText
@onready var xp_text: Label = %XPText
@onready var level_text: Label = %LevelText
@onready var resource_text: Label = %ResourceText
@onready var objective_text: Label = %ObjectiveText
@onready var toast: Label = %Toast
@onready var result_panel: PanelContainer = %ResultPanel
@onready var result_title: Label = %ResultTitle
@onready var result_description: Label = %ResultDescription


func _ready() -> void:
	var panel := _panel_style(Color("152c2b"), Color("49605a"))
	%StatsPanel.add_theme_stylebox_override("panel", panel)
	%SuppliesPanel.add_theme_stylebox_override("panel", panel)
	result_panel.add_theme_stylebox_override("panel", panel)
	_style_bar(health_bar, Color("8fcca8"))
	_style_bar(xp_bar, Color("78b4e2"))
	%RestartButton.add_theme_stylebox_override("normal",
		_panel_style(Color("3a5c51"), Color("91b39b")))
	%RestartButton.add_theme_stylebox_override("hover",
		_panel_style(Color("4a7564"), Color("d9cea1")))
	%RestartButton.add_theme_font_size_override("font_size", 20)
	%RestartButton.pressed.connect(func(): restart_requested.emit())


func bind_player(value: KingdomPlayer) -> void:
	player = value
	player.stats_changed.connect(refresh)
	player.level_gained.connect(_on_level_gained)
	player.resource_gained.connect(_on_resource_gained)
	refresh()


func refresh() -> void:
	if not is_instance_valid(player):
		return
	health_bar.max_value = player.max_health
	health_bar.value = player.current_health
	xp_bar.max_value = player.xp_required()
	xp_bar.value = player.experience
	health_text.text = "VIDA  %d / %d" % [player.current_health, player.max_health]
	xp_text.text = "XP  %d / %d" % [player.experience, player.xp_required()]
	level_text.text = "NÍVEL %02d  ·  DANO %d" % [player.level, player.damage]
	resource_text.text = "Madeira   %03d\nPedra       %03d\nOuro         %03d" % [
		player.resources["wood"], player.resources["stone"], player.resources["gold"]]


func update_objective(remaining: int, total: int) -> void:
	objective_text.text = "PROTEJA A CLAREIRA\nErrantes derrotados  %02d / %02d" % [total - remaining, total]


func show_result(victory: bool) -> void:
	result_title.text = "Clareira protegida!" if victory else "Seu reino precisa de você."
	result_description.text = (
		"Os errantes foram derrotados.\nA futura vila tem um novo começo."
		if victory else "Você caiu em combate.\nMova-se para evitar cercos e tente novamente."
	)
	result_panel.show()
	%RestartButton.grab_focus()


func _on_level_gained(new_level: int) -> void:
	toast.text = "Nível %d!  +15 vida máxima · +4 dano · +25 cura" % new_level
	_toast_remaining = 3.5


func _on_resource_gained(kind: String, amount: int) -> void:
	# Do not immediately overwrite the level-up message from the same kill.
	if _toast_remaining > 0:
		return
	toast.text = "+%d %s" % [amount, RESOURCE_NAMES[kind]]
	_toast_remaining = 1.8


func _process(delta: float) -> void:
	_toast_remaining = maxf(0.0, _toast_remaining - delta)
	toast.visible = _toast_remaining > 0


func _panel_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	return style


func _style_bar(bar: ProgressBar, color: Color) -> void:
	var background := StyleBoxFlat.new()
	background.bg_color = Color("263f3a")
	background.set_corner_radius_all(4)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)
