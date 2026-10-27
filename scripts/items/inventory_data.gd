class_name InventoryData
extends RefCounted
## Pure fixed-slot operations. GameState owns persistence.
const CAPACITY := 20


static func empty_slots() -> Array:
	var result: Array = []
	for index in range(CAPACITY):
		result.append({})
	return result


static func empty_equipment() -> Dictionary:
	return {"weapon": "", "armor": "", "boots": ""}


static func add(slots: Array, id: String, quantity: int = 1) -> Array:
	var item := ItemData.definition(id)
	if item.is_empty() or quantity <= 0:
		return []
	var result := slots.duplicate(true)
	var remaining := quantity
	for entry in result:
		if entry.get("id") == id and entry.quantity < item.max_stack:
			var amount := mini(remaining, item.max_stack - entry.quantity)
			entry.quantity += amount
			remaining -= amount
	for index in range(result.size()):
		if remaining > 0 and result[index].is_empty():
			var amount := mini(remaining, item.max_stack)
			result[index] = {"id": id, "quantity": amount}
			remaining -= amount
	return result if remaining == 0 else []


static func count(slots: Array, id: String) -> int:
	var total := 0
	for entry in slots:
		if entry.get("id") == id:
			total += entry.quantity
	return total


static func bonuses(equipment: Dictionary) -> Dictionary:
	var result := {"damage": 0, "max_health": 0, "speed": 0}
	for slot in ItemData.SLOTS:
		var item := ItemData.definition(equipment.get(slot, ""))
		if not item.is_empty():
			result[item.stat] += item.value
	return result
