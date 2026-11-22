class_name SkillDef
extends RefCounted
## Описание навыка. Данные лежат в data/skills.json.

enum Target { ENEMY_ONE, ENEMY_COLUMN, ENEMY_ALL, ALLY_ONE, ALLY_ALL, SELF }
enum Effect { DAMAGE, HEAL, MODIFY }

const TARGET_NAMES := {
	"enemy_one": Target.ENEMY_ONE, "enemy_column": Target.ENEMY_COLUMN, "enemy_all": Target.ENEMY_ALL,
	"ally_one": Target.ALLY_ONE, "ally_all": Target.ALLY_ALL, "self": Target.SELF,
}
const EFFECT_NAMES := {"damage": Effect.DAMAGE, "heal": Effect.HEAL, "modify": Effect.MODIFY}

var id := ""
var name := ""
var weapon := ""
var cost_ap := 40
var cooldown := 0
var target := Target.ENEMY_ONE
var effect := Effect.DAMAGE
var power_pct := 100
## Дальний навык игнорирует правило передней колонки.
var ranged := false
var unlock_level := 1
var mod_stat := ""
var mod_kind := StatBlock.Kind.PERCENT
var mod_value := 0
var mod_turns := 0


static func from_dict(d: Dictionary) -> SkillDef:
	var s := SkillDef.new()
	s.id = str(d.get("id", ""))
	s.name = str(d.get("name", s.id))
	s.weapon = str(d.get("weapon", ""))
	s.cost_ap = int(d.get("cost_ap", 40))
	s.cooldown = int(d.get("cooldown", 0))
	s.target = TARGET_NAMES.get(str(d.get("target", "")), -1)
	s.effect = EFFECT_NAMES.get(str(d.get("effect", "")), -1)
	s.power_pct = int(d.get("power_pct", 100))
	s.ranged = bool(d.get("ranged", false))
	s.unlock_level = int(d.get("unlock_level", 1))
	if d.has("mod"):
		var m: Dictionary = d["mod"]
		s.mod_stat = str(m.get("stat", ""))
		s.mod_kind = StatBlock.Kind.PERCENT if str(m.get("kind", "percent")) == "percent" else StatBlock.Kind.FLAT
		s.mod_value = int(m.get("value", 0))
		s.mod_turns = int(m.get("turns", 0))
	return s


func targets_enemies() -> bool:
	return target in [Target.ENEMY_ONE, Target.ENEMY_COLUMN, Target.ENEMY_ALL]
