class_name AttributeStats
extends RefCounted
## Base offsets preserve old totals, even customized legacy saves.


static func legacy_base(progress: Dictionary, weapon_level: int) -> Dictionary:
	return {"damage": int(progress.damage) - (int(progress.level) - 1) * 4 - BuildingData.weapon_bonus(weapon_level),
		"max_health": int(progress.max_health) - (int(progress.level) - 1) * 15, "speed": 230}


static func permanent(base: Dictionary, level: int, weapon_level: int) -> Dictionary:
	return {"damage": base.damage + (level - 1) * 4 + BuildingData.weapon_bonus(weapon_level),
		"max_health": base.max_health + (level - 1) * 15, "speed": base.speed}


static func breakdown(base: Dictionary, level: int, weapon_level: int, equipment: Dictionary) -> Dictionary:
	var gear := InventoryData.bonuses(equipment)
	var total := permanent(base, level, weapon_level)
	for key in gear:
		total[key] += gear[key]
	return {"base": base.duplicate(), "level": {"damage": (level - 1) * 4, "max_health": (level - 1) * 15},
		"blacksmith": BuildingData.weapon_bonus(weapon_level), "equipment": gear, "total": total}
