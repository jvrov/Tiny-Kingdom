class_name BuildingPanel
extends Control

signal purchase_requested(id: String, action: String, expected_level: int)

var building_id := ""
var offer: Dictionary = {}
@onready var game_state: Node = get_node("/root/GameState")
@onready var confirm_button: Button = $Center/Panel/Content/Buttons/Confirm
@onready var reason_label: Label = $Center/Panel/Content/Reason


func _ready() -> void:
	hide()
	set_process_input(false)
	confirm_button.pressed.connect(confirm_purchase)
	$Center/Panel/Content/Buttons/Cancel.pressed.connect(close)
	game_state.changed.connect(refresh)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("152c2b")
	style.border_color = Color("c5b780")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	$Center/Panel.add_theme_stylebox_override("panel", style)


func open(id: String) -> void:
	building_id = id
	show()
	get_tree().paused = true
	set_process_input(true)
	refresh()
	if confirm_button.disabled:
		$Center/Panel/Content/Buttons/Cancel.grab_focus()
	else:
		confirm_button.grab_focus()


func close() -> void:
	hide()
	set_process_input(false)
	get_tree().paused = false
	building_id = ""


func refresh() -> void:
	if not visible:
		return
	offer = game_state.building_offer(building_id)
	if offer.is_empty():
		close()
		return
	$Center/Panel/Content/Title.text = "%s · Nv. %d / 1" % [offer.name, offer.level]
	$Center/Panel/Content/Description.text = offer.description
	$Center/Panel/Content/Cost.text = "Custo: " + _resources(offer.cost) if not offer.cost.is_empty() else "Construção concluída"
	$Center/Panel/Content/Available.text = "Armazenado: " + _resources(game_state.village_resources)
	confirm_button.text = offer.button
	confirm_button.disabled = not offer.enabled
	reason_label.text = offer.reason


func _resources(values: Dictionary) -> String:
	return "Madeira %d · Pedra %d · Ouro %d" % [values.get("wood", 0), values.get("stone", 0), values.get("gold", 0)]


func confirm_purchase() -> void:
	if visible and not confirm_button.disabled:
		# Copy the quote: state signals can refresh the panel during the transaction.
		var quote := offer.duplicate(true)
		purchase_requested.emit(building_id, quote.action, quote.expected_level)


func show_error(message: String) -> void:
	refresh()
	reason_label.text = message


func _input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		confirm_purchase()
		get_viewport().set_input_as_handled()
