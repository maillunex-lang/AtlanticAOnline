class_name SkillDef
extends RefCounted
## Описание навыка. Данные лежат в data/skills.json.

enum Target { ENEMY_ONE, ENEMY_COLUMN, ENEMY_ALL, ALLY_ONE, ALLY_ALL, SELF, ALLY_DEAD }
enum Effect { DAMAGE, HEAL, MODIFY, REVIVE, DISPEL }

const TARGET_NAMES := {
	"enemy_one": Target.ENEMY_ONE, "enemy_column": Target.ENEMY_COLUMN, "enemy_all": Target.ENEMY_ALL,
	"ally_one": Target.ALLY_ONE, "ally_all": Target.ALLY_ALL, "self": Target.SELF, "ally_dead": Target.ALLY_DEAD,
}
const EFFECT_NAMES := {"damage": Effect.DAMAGE, "heal": Effect.HEAL, "modify": Effect.MODIFY, "revive": Effect.REVIVE, "dispel": Effect.DISPEL}

var id := ""
var name := ""
var weapon := ""
var cost_ap := 150
## Цена в очках магии.
var cost_mp := 0
## Магический навык не продвигает счётчик оглушения.
var magic := false
var cooldown := 0
var target := Target.ENEMY_ONE
var effect := Effect.DAMAGE
var power_pct := 100
## Предыдущий успешный навык на той же цели в текущем ходу стороны.
var combo_from := ""
var combo_bonus_pct := 0
## Дальний навык игнорирует правило передней колонки.
var ranged := false
var unlock_level := 1
var mod_stat := ""
var mod_kind := StatBlock.Kind.PERCENT
var mod_value := 0
var mod_turns := 0
## Пассивный навык не тратится в бою: его бонусы (passive_mods) действуют с начала боя.
var passive := false
var passive_mods: Array = []
## Число ударов за применение (многократный удар).
var hits := 1
## Часть защиты цели, которую игнорирует удар.
var pierce_pct := 0
## Доля нанесённого урона, возвращаемая как лечение.
var lifesteal_pct := 0
## Сколько очков магии сжигает у цели.
var mp_burn := 0
## Статус на цель при попадании: "stun" (пропуск хода) или "dot" (урон за ход, power_pct от атаки).
var status_kind := ""
var status_chance := 100
var status_turns := 1
var status_power := 0
## Группа каталога: active, passive, legion, combo (для интерфейса и проверок).
var group := "active"
## Книга навыка: сколько уровней открыто без книги задаёт правило, книга даёт следующую ступень.
var book := ""


static func from_dict(d: Dictionary) -> SkillDef:
	var s := SkillDef.new()
	s.id = str(d.get("id", ""))
	s.name = str(d.get("name", s.id))
	s.weapon = str(d.get("weapon", ""))
	s.cost_ap = int(d.get("cost_ap", s.cost_ap))
	s.cost_mp = int(d.get("cost_mp", 0))
	s.magic = bool(d.get("magic", false))
	s.cooldown = int(d.get("cooldown", 0))
	s.target = TARGET_NAMES.get(str(d.get("target", "")), -1)
	s.effect = EFFECT_NAMES.get(str(d.get("effect", "")), -1)
	s.power_pct = int(d.get("power_pct", 100))
	s.combo_from = str(d.get("combo_from", ""))
	s.combo_bonus_pct = int(d.get("combo_bonus_pct", 0))
	s.ranged = bool(d.get("ranged", false))
	s.unlock_level = int(d.get("unlock_level", 1))
	s.passive = bool(d.get("passive", false))
	s.passive_mods = d.get("passive_mods", [])
	s.hits = maxi(1, int(d.get("hits", 1)))
	s.pierce_pct = int(d.get("pierce_pct", 0))
	s.lifesteal_pct = int(d.get("lifesteal_pct", 0))
	s.mp_burn = int(d.get("mp_burn", 0))
	if d.has("status"):
		var st: Dictionary = d["status"]
		s.status_kind = str(st.get("kind", ""))
		s.status_chance = int(st.get("chance", 100))
		s.status_turns = int(st.get("turns", 1))
		s.status_power = int(st.get("power", 0))
	s.group = str(d.get("group", "passive" if s.passive else "active"))
	if d.has("mod"):
		var m: Dictionary = d["mod"]
		s.mod_stat = str(m.get("stat", ""))
		s.mod_kind = StatBlock.Kind.PERCENT if str(m.get("kind", "percent")) == "percent" else StatBlock.Kind.FLAT
		s.mod_value = int(m.get("value", 0))
		s.mod_turns = int(m.get("turns", 0))
	return s


func targets_enemies() -> bool:
	return target in [Target.ENEMY_ONE, Target.ENEMY_COLUMN, Target.ENEMY_ALL]
