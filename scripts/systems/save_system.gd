class_name SaveSystem
extends RefCounted
## Versioned, validated JSON. A failed write never replaces the last good file.

const VERSION := 1
const DEFAULT_PATH := "user://save.json"
const MAX_VALUE := 1000000000
var path: String
var message := ""
var write_blocked := false
var needs_save := false


func _init(save_path: String = DEFAULT_PATH) -> void:
	path = save_path


static func defaults() -> Dictionary:
	return {
		"version": VERSION,
		"resources": {"wood": 0, "stone": 0, "gold": 0},
		"player": {"level": 1, "xp": 0, "max_health": 100, "damage": 18},
		"expeditions_completed": 0
	}


func load_data() -> Dictionary:
	message = ""
	write_blocked = false
	needs_save = false
	if not FileAccess.file_exists(path):
		needs_save = true
		return defaults()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		write_blocked = true
		message = "Não foi possível ler o save. O arquivo foi preservado."
		return defaults()
	# Refuse oversized input before parsing it; normal saves are under 1 KiB.
	if file.get_length() > 1048576:
		file.close()
		return _recover_corrupt()
	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	file.close()
	if error != OK or not json.data is Dictionary:
		return _recover_corrupt()
	var data: Dictionary = json.data
	if _integer(data.get("version"), 1, MAX_VALUE) and int(data.version) != VERSION:
		write_blocked = true
		message = "Versão de save incompatível. Arquivo preservado; gravação bloqueada."
		return defaults()
	if not valid_data(data):
		return _recover_corrupt()
	# JSON numbers arrive as floats; normalize before using them in gameplay.
	var normalized := defaults()
	for key in normalized.resources:
		normalized.resources[key] = int(data.resources[key])
	for key in normalized.player:
		normalized.player[key] = int(data.player[key])
	normalized.expeditions_completed = int(data.expeditions_completed)
	return normalized


func _recover_corrupt() -> Dictionary:
	var backup := path + ".corrupt-" + str(Time.get_unix_time_from_system()).replace(".", "-")
	var error := DirAccess.copy_absolute(path, backup)
	if error != OK:
		write_blocked = true
		message = "Save inválido; não foi possível criar backup. Gravação bloqueada."
	else:
		needs_save = true
		message = "Save inválido preservado em .corrupt-*. Novo progresso iniciado."
	return defaults()


static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	if not (value is int or value is float):
		return false
	return is_finite(float(value)) and value >= minimum and value <= maximum and floor(value) == value


static func valid_data(data: Dictionary) -> bool:
	if not _integer(data.get("version"), VERSION, VERSION):
		return false
	if not data.get("resources") is Dictionary or not data.get("player") is Dictionary:
		return false
	for key in ["wood", "stone", "gold"]:
		if not _integer(data.resources.get(key), 0, MAX_VALUE):
			return false
	var player: Dictionary = data.player
	if not _integer(player.get("level"), 1, 10000):
		return false
	if not _integer(player.get("xp"), 0, 29 + (int(player.level) - 1) * 20):
		return false
	for key in ["max_health", "damage"]:
		if not _integer(player.get(key), 1, MAX_VALUE):
			return false
	return _integer(data.get("expeditions_completed"), 0, MAX_VALUE)


func save_data(data: Dictionary) -> bool:
	if write_blocked:
		return false
	message = ""
	if not valid_data(data):
		message = "Dados inválidos: o save anterior foi preservado."
		return false
	var directory := ProjectSettings.globalize_path(path).get_base_dir()
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		message = "Não foi possível criar a pasta do save."
		return false
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		message = "Não foi possível gravar o save. Verifique espaço e permissões."
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	var error := file.get_error()
	file.close()
	if error == OK:
		error = DirAccess.rename_absolute(temporary, path)
	if error != OK:
		message = "Falha ao concluir o save. O arquivo anterior foi preservado."
		return false
	needs_save = false
	return true


func erase() -> bool:
	if FileAccess.file_exists(path) and DirAccess.remove_absolute(path) != OK:
		message = "Não foi possível apagar o save. Progresso mantido."
		return false
	if FileAccess.file_exists(path + ".tmp"):
		DirAccess.remove_absolute(path + ".tmp")
	write_blocked = false
	message = ""
	return true
