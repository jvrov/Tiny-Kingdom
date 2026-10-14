class_name KingdomHUD
extends CanvasLayer

signal reset_requested

const RESOURCE_NAMES := {"wood": "Madeira", "stone": "Pedra", "gold": "Ouro"}
var player: KingdomPlayer
var _toast_remaining: float = 0.0
var in_village := true

@onready var game_state: Node = get_node("/root/GameState")
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
@onready var building_panel: BuildingPanel = %BuildingPanel


func _ready() -> void:
	var panel := _panel_style(Color("152c2b"), Color("49605a"))
	%StatsPanel.add_theme_stylebox_override("panel", panel)
	%SuppliesPanel.add_theme_stylebox_override("panel", panel)
	result_panel.add_theme_stylebox_override("panel", panel)
	_style_bar(health_bar, Color("8fcca8"))
	_style_bar(xp_bar, Color("78b4e2"))
	%ResetConfirmation.canceled.connect(func(): get_tree().paused = false)
	%ResetConfirmation.confirmed.connect(func():
		get_tree().paused = false
		reset_requested.emit())
	game_state.changed.connect(refresh)
	game_state.save_status_changed.connect(_on_save_status)
	_on_save_status(game_state.save_status)
	%Hint.text = "WASD / SETAS   mover     ·     E   interagir     ·     ATAQUE AUTOMÁTICO"
	if OS.is_debug_build():
		%Hint.text += "     ·     F9   reset (dev)"


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
	var shown: Dictionary = game_state.village_resources if in_village else player.resources
	resource_text.text = "Madeira   %03d\nPedra       %03d\nOuro         %03d" % [
		shown["wood"], shown["stone"], shown["gold"]]
	%CarryingText.visible = in_village
	%CarryingText.text = "Carregando: M %d · P %d · O %d" % [
		player.resources["wood"], player.resources["stone"], player.resources["gold"]]
	if in_village:
		%SuppliesTitle.text = "ARMAZENADO · Vila Nv. %d" % game_state.building_level("town_hall")
		objective_text.text = "VILA · EXPEDIÇÕES CONCLUÍDAS: %d\nDeposite antes de partir novamente." % game_state.expeditions_completed


func update_objective(remaining: int, total: int) -> void:
	objective_text.text = "PROTEJA A CLAREIRA\nErrantes derrotados  %02d / %02d" % [total - remaining, total]


func show_failure() -> void:
	result_title.text = "Expedição falhou"
	result_description.text = "Recursos não depositados foram perdidos.\nNível e XP foram mantidos.\nRetornando à vila…"
	result_panel.show()


func set_location(village: bool) -> void:
	in_village = village
	%SuppliesTitle.text = "ARMAZENADO · VILA" if village else "CARREGANDO · EXPEDIÇÃO"
	refresh()


func show_message(text: String, duration: float = 3.5) -> void:
	toast.text = text
	_toast_remaining = duration


func set_interaction_prompt(text: String) -> void:
	%InteractionPrompt.text = text


func _on_save_status(text: String) -> void:
	%SaveStatus.text = text
	%SaveStatus.visible = not text.is_empty()


func confirm_reset() -> void:
	if OS.is_debug_build() and not %ResetConfirmation.visible and not building_panel.visible:
		get_tree().paused = true
		%ResetConfirmation.popup_centered()


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
