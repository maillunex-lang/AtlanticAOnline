class_name WeaponType
extends RefCounted
## Типы оружия. Тип оружия определяет навыки и роль бойца.

const ALL: Array[String] = ["sword", "spear", "axe", "gun", "bow", "cannon", "staff"]


static func is_valid(id: String) -> bool:
	return id in ALL
