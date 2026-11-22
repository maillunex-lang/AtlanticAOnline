class_name WeaponType
extends RefCounted
## Типы оружия. Тип оружия определяет навыки и роль бойца.

const ALL: Array[String] = ["sword", "spear", "axe", "gun", "bow", "cannon", "staff",
	"whip", "dual_sword", "armor_fist", "power_saw", "instrument"]


static func is_valid(id: String) -> bool:
	return id in ALL
