#!/usr/bin/env python3
"""Генератор каталога навыков (WP-47): дополняет data/skills.json навыками по типам оружия
и раскладывает пулы навыков классов героя в data/classes.json.
Исходные 22 навыка остаются как есть; запуск идемпотентен (новые id заменяются).
Запуск: python3 tools/gen_skills.py"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SK = ROOT / "data" / "skills.json"
CL = ROOT / "data" / "classes.json"


def dmg(id, name, weapon, target, power, lvl, cd=0, ap=150, ranged=False, magic=False, mp=0, **kw):
    d = {"id": id, "name": name, "weapon": weapon, "cost_ap": ap, "cooldown": cd, "target": target, "effect": "damage",
         "power_pct": power, "ranged": ranged, "unlock_level": lvl}
    if magic:
        d["magic"] = True
    if mp:
        d["cost_mp"] = mp
    d.update(kw)
    return d


def buff(id, name, weapon, target, stat, value, turns, lvl, cd=3, ap=100, magic=False, mp=0, kind="percent"):
    d = {"id": id, "name": name, "weapon": weapon, "cost_ap": ap, "cooldown": cd, "target": target, "effect": "modify",
         "power_pct": 0, "ranged": False, "unlock_level": lvl, "mod": {"stat": stat, "kind": kind, "value": value, "turns": turns}}
    if magic:
        d["magic"] = True
    if mp:
        d["cost_mp"] = mp
    return d


def debuff(id, name, weapon, stat, value, turns, lvl, cd=2, ap=150, ranged=False, magic=False, mp=0):
    d = buff(id, name, weapon, "enemy_one", stat, value, turns, lvl, cd, ap, magic, mp)
    d["ranged"] = ranged
    return d


def dispel(id, name, weapon, target, lvl, cd=3, ap=100, magic=False, mp=0):
    d = {"id": id, "name": name, "weapon": weapon, "cost_ap": ap, "cooldown": cd, "target": target, "effect": "dispel",
         "power_pct": 0, "ranged": False, "unlock_level": lvl}
    if magic:
        d["magic"] = True
    if mp:
        d["cost_mp"] = mp
    return d


def heal(id, name, weapon, target, power, lvl, cd=1, ap=150, mp=15):
    return {"id": id, "name": name, "weapon": weapon, "cost_ap": ap, "cooldown": cd, "target": target, "effect": "heal",
            "power_pct": power, "ranged": False, "unlock_level": lvl, "magic": True, "cost_mp": mp}


def passive(id, name, weapon, lvl, mods):
    return {"id": id, "name": name, "weapon": weapon, "cost_ap": 0, "cooldown": 0, "target": "self", "effect": "modify",
            "power_pct": 0, "ranged": False, "unlock_level": lvl, "passive": True, "group": "passive",
            "passive_mods": [{"stat": s, "kind": k, "value": v} for s, k, v in mods]}


NEW = [
    # --- Меч ---
    dmg("sword_cleave", "Широкий разруб", "sword", "enemy_column", 100, 8, 1, 140),
    dmg("sword_cleanse_strike", "Рассекающий выпад", "sword", "enemy_one", 140, 16, 2, 150, pierce_pct=25),
    dispel("sword_cleanse", "Очищение", "sword", "self", 18),
    dmg("sword_bleed", "Рваная рана", "sword", "enemy_one", 90, 20, 2, 150, status={"kind": "dot", "chance": 100, "turns": 3, "power": 40}),
    dmg("sword_flurry", "Шквал ударов", "sword", "enemy_one", 60, 24, 3, 170, hits=3),
    dmg("sword_bash", "Удар эфесом", "sword", "enemy_one", 80, 28, 3, 140, status={"kind": "stun", "chance": 50, "turns": 1, "power": 0}),
    dmg("sword_blood", "Кровавый клинок", "sword", "enemy_one", 130, 36, 3, 150, lifesteal_pct=40),
    buff("sword_ironwill", "Железная воля", "sword", "self", "def", 60, 3, 44, 4, 90),
    dmg("sword_lethal", "Смертельный выпад", "sword", "enemy_one", 260, 60, 4, 170, combo_from="sword_bash", combo_bonus_pct=80, group="combo"),
    passive("sword_mastery", "Мастерство меча", "sword", 10, [("atk", "percent", 6)]),
    passive("sword_hardening", "Закалка", "sword", 30, [("hp", "percent", 8)]),
    passive("sword_parry", "Парирование", "sword", 50, [("def", "percent", 8)]),
    passive("sword_keen", "Точный удар", "sword", 70, [("crit", "flat", 5)]),
    # --- Копьё ---
    dmg("spear_sweep", "Круговой взмах", "spear", "enemy_column", 100, 10, 2, 140),
    dmg("spear_lunge", "Бросок копья", "spear", "enemy_one", 150, 14, 2, 150, pierce_pct=30),
    dmg("spear_impale", "Пронзание", "spear", "enemy_column", 120, 22, 3, 150, status={"kind": "dot", "chance": 100, "turns": 3, "power": 30}),
    debuff("spear_hamstring", "Подсечка", "spear", "evasion", -30, 3, 18),
    dmg("spear_triple", "Тройной выпад", "spear", "enemy_one", 55, 26, 3, 160, hits=3),
    dmg("spear_stun", "Тупой конец", "spear", "enemy_one", 80, 32, 3, 140, status={"kind": "stun", "chance": 50, "turns": 1, "power": 0}),
    buff("spear_wall", "Стена копий", "spear", "ally_all", "def", 20, 3, 40, 4, 120),
    dmg("spear_dragon", "Удар дракона", "spear", "enemy_column", 200, 62, 4, 170, pierce_pct=40, combo_from="spear_hamstring", combo_bonus_pct=60, group="combo"),
    passive("spear_mastery", "Мастерство копья", "spear", 10, [("atk", "percent", 6)]),
    passive("spear_stance", "Стойка", "spear", 30, [("def", "percent", 8)]),
    passive("spear_reach", "Дальний выпад", "spear", 50, [("accuracy", "flat", 6)]),
    passive("spear_vigor", "Выносливость", "spear", 70, [("hp", "percent", 8)]),
    # --- Топор ---
    dmg("axe_cleave", "Тяжёлый удар", "axe", "enemy_one", 170, 9, 2, 150),
    dmg("axe_rend", "Кровопускание", "axe", "enemy_one", 100, 16, 2, 150, status={"kind": "dot", "chance": 100, "turns": 3, "power": 45}),
    dmg("axe_fury", "Ярость", "axe", "enemy_one", 65, 22, 3, 170, hits=3),
    dmg("axe_stunning", "Оглушающий удар", "axe", "enemy_one", 90, 26, 3, 150, status={"kind": "stun", "chance": 55, "turns": 1, "power": 0}),
    dmg("axe_split", "Раскол строя", "axe", "enemy_column", 130, 34, 3, 160, pierce_pct=25),
    buff("axe_warcry", "Боевой рёв", "axe", "self", "atk", 35, 3, 38, 4, 90),
    debuff("axe_weaken", "Подрыв сил", "axe", "atk", -25, 3, 30),
    dmg("axe_exe", "Казнь", "axe", "enemy_one", 280, 62, 4, 170, combo_from="axe_weaken", combo_bonus_pct=70, group="combo"),
    passive("axe_mastery", "Мастерство топора", "axe", 10, [("atk", "percent", 7)]),
    passive("axe_brawn", "Могучее сложение", "axe", 30, [("hp", "percent", 8)]),
    passive("axe_bloodlust", "Жажда крови", "axe", 50, [("crit", "flat", 5)]),
    passive("axe_thick", "Толстая шкура", "axe", 70, [("def", "percent", 8)]),
    # --- Ружьё ---
    dmg("gun_double", "Двойной выстрел", "gun", "enemy_one", 70, 9, 2, 160, ranged=True, hits=2),
    dmg("gun_pierce", "Бронебойный", "gun", "enemy_one", 140, 15, 2, 150, ranged=True, pierce_pct=40),
    dmg("gun_incendiary", "Зажигательная пуля", "gun", "enemy_one", 80, 20, 2, 150, ranged=True, status={"kind": "dot", "chance": 100, "turns": 3, "power": 40}),
    dmg("gun_legshot", "Выстрел по ногам", "gun", "enemy_one", 70, 24, 3, 140, ranged=True, status={"kind": "stun", "chance": 45, "turns": 1, "power": 0}),
    dmg("gun_barrage", "Шквальный огонь", "gun", "enemy_all", 55, 30, 3, 160, ranged=True),
    buff("gun_steady", "Твёрдая рука", "gun", "self", "accuracy", 20, 3, 34, 4, 80, kind="flat"),
    debuff("gun_blind", "Ослепление", "gun", "accuracy", -25, 3, 40, 3, 140, True),
    dmg("gun_headshot", "Выстрел в голову", "gun", "enemy_one", 300, 62, 4, 170, ranged=True, combo_from="gun_blind", combo_bonus_pct=70, group="combo"),
    passive("gun_mastery", "Мастерство стрельбы", "gun", 10, [("atk", "percent", 6)]),
    passive("gun_eye", "Верный глаз", "gun", 30, [("accuracy", "flat", 8)]),
    passive("gun_crit", "Меткость", "gun", 50, [("crit", "flat", 6)]),
    passive("gun_quick", "Быстрая перезарядка", "gun", 70, [("ap_regen", "flat", 5)]),
    # --- Лук ---
    dmg("bow_double", "Двойная стрела", "bow", "enemy_one", 65, 9, 2, 160, ranged=True, hits=2),
    dmg("bow_pierce", "Пробивающая стрела", "bow", "enemy_one", 130, 14, 2, 150, ranged=True, pierce_pct=35),
    dmg("bow_poison", "Отравленная стрела", "bow", "enemy_one", 70, 18, 2, 150, ranged=True, status={"kind": "dot", "chance": 100, "turns": 4, "power": 35}),
    dmg("bow_pin", "Пригвоздить", "bow", "enemy_one", 80, 24, 3, 140, ranged=True, status={"kind": "stun", "chance": 50, "turns": 1, "power": 0}),
    dmg("bow_rain", "Дождь стрел", "bow", "enemy_all", 60, 30, 3, 160, ranged=True, hits=2),
    buff("bow_swift", "Стремительность", "bow", "self", "ap_regen", 12, 3, 36, 4, 80, kind="flat"),
    debuff("bow_mark", "Метка охотника", "bow", "def", -25, 3, 32, 2, 140, True),
    dmg("bow_snipe", "Снайперский выстрел", "bow", "enemy_one", 290, 62, 4, 170, ranged=True, combo_from="bow_mark", combo_bonus_pct=70, group="combo"),
    passive("bow_mastery", "Мастерство лука", "bow", 10, [("atk", "percent", 6)]),
    passive("bow_agility", "Ловкость", "bow", 30, [("evasion", "flat", 6)]),
    passive("bow_crit", "Охотничий глаз", "bow", 50, [("crit", "flat", 6)]),
    passive("bow_range", "Дальний прицел", "bow", 70, [("accuracy", "flat", 8)]),
    # --- Пушка ---
    dmg("cannon_grape", "Картечь", "cannon", "enemy_column", 130, 10, 2, 150, ranged=True),
    dmg("cannon_incendiary", "Зажигательное ядро", "cannon", "enemy_column", 80, 18, 3, 150, ranged=True, status={"kind": "dot", "chance": 100, "turns": 3, "power": 35}),
    dmg("cannon_shock", "Оглушающий залп", "cannon", "enemy_one", 100, 24, 3, 150, ranged=True, status={"kind": "stun", "chance": 55, "turns": 1, "power": 0}),
    dmg("cannon_bunker", "Бронебойное ядро", "cannon", "enemy_one", 180, 28, 3, 150, ranged=True, pierce_pct=45),
    dmg("cannon_salvo", "Двойной залп", "cannon", "enemy_all", 60, 36, 3, 170, ranged=True, hits=2),
    buff("cannon_range", "Наводка", "cannon", "self", "accuracy", 20, 3, 34, 4, 80, kind="flat"),
    debuff("cannon_breach", "Пробоина", "cannon", "def", -30, 3, 40, 3, 150, True),
    dmg("cannon_doom", "Залп судного дня", "cannon", "enemy_all", 150, 66, 4, 180, ranged=True, combo_from="cannon_breach", combo_bonus_pct=60, group="combo"),
    passive("cannon_mastery", "Мастерство артиллерии", "cannon", 10, [("atk", "percent", 7)]),
    passive("cannon_crew", "Выучка расчёта", "cannon", 30, [("ap_regen", "flat", 4)]),
    passive("cannon_armor", "Щиты орудия", "cannon", 50, [("def", "percent", 8)]),
    passive("cannon_calib", "Калибровка", "cannon", 70, [("accuracy", "flat", 8)]),
    # --- Посох ---
    dmg("staff_spark", "Искра", "staff", "enemy_one", 90, 6, 0, 120, True, True, 6),
    dmg("staff_chain", "Цепная молния", "staff", "enemy_column", 100, 14, 2, 150, True, True, 16),
    dmg("staff_burn", "Пламя", "staff", "enemy_one", 80, 18, 2, 150, True, True, 14, status={"kind": "dot", "chance": 100, "turns": 3, "power": 45}),
    dmg("staff_freeze", "Оковы льда", "staff", "enemy_one", 90, 22, 3, 150, True, True, 18, status={"kind": "stun", "chance": 50, "turns": 1, "power": 0}),
    dmg("staff_drain", "Похищение сил", "staff", "enemy_one", 100, 26, 2, 150, True, True, 14, lifesteal_pct=50, mp_burn=10),
    dmg("staff_nova", "Вспышка", "staff", "enemy_all", 80, 34, 3, 160, True, True, 28),
    heal("staff_mend", "Малое исцеление", "staff", "ally_one", 90, 8, 0, 100, 8),
    heal("staff_mass_heal", "Волна исцеления", "staff", "ally_all", 90, 24, 3, 160, 30),
    dispel("staff_purify", "Очищение света", "staff", "ally_all", 20, 3, 100, True, 14),
    dispel("staff_disenchant", "Развеять чары", "staff", "enemy_one", 28, 3, 100, True, 14),
    debuff("staff_curse", "Проклятие", "staff", "atk", -25, 3, 16, 2, 140, True, True, 12),
    buff("staff_haste", "Ускорение", "staff", "ally_one", "ap_regen", 12, 3, 30, 3, 100, True, 16, "flat"),
    dmg("staff_meteor", "Метеор", "staff", "enemy_all", 170, 66, 4, 180, True, True, 40, combo_from="staff_curse", combo_bonus_pct=50, group="combo"),
    passive("staff_mastery", "Мастерство магии", "staff", 10, [("intelligence", "percent", 8)]),
    passive("staff_focus", "Сосредоточение", "staff", 30, [("atk", "percent", 6)]),
    passive("staff_ward", "Магический покров", "staff", 50, [("magic_def", "percent", 10)]),
    passive("staff_vitality", "Жизненная сила", "staff", 70, [("hp", "percent", 8)]),
]

# Пулы героя: slot4 (открывает улучшение на 100) и spec (специализация, улучшение на 120).
POOLS = {
    "sword": (["sword_blood", "sword_flurry", "sword_ironwill"], ["sword_lethal"]),
    "spear": (["spear_wall", "spear_triple", "spear_impale"], ["spear_dragon"]),
    "axe": (["axe_warcry", "axe_split", "axe_stunning"], ["axe_exe"]),
    "gun": (["gun_barrage", "gun_pierce", "gun_blind"], ["gun_headshot"]),
    "bow": (["bow_rain", "bow_mark", "bow_poison"], ["bow_snipe"]),
    "cannon": (["cannon_salvo", "cannon_bunker", "cannon_breach"], ["cannon_doom"]),
    "staff": (["staff_mass_heal", "staff_nova", "staff_drain"], ["staff_meteor"]),
}


def main():
    skills = json.loads(SK.read_text(encoding="utf-8"))
    new_ids = {n["id"] for n in NEW}
    skills = [s for s in skills if s["id"] not in new_ids] + NEW
    SK.write_text(json.dumps(skills, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    cls = json.loads(CL.read_text(encoding="utf-8"))
    by_weapon = {}
    for s in skills:
        by_weapon.setdefault(s["weapon"], []).append(s)
    for c in cls["classes"]:
        if not c["enabled"] or c["weapon"] not in POOLS:
            continue
        slot4, spec = POOLS[c["weapon"]]
        slot4 = list(dict.fromkeys(c["skills"]["slot4"] + slot4))
        spec = list(dict.fromkeys(c["skills"]["spec"] + spec))
        base_old = [x for x in c["skills"]["base"][:3] if x not in slot4 and x not in spec]
        rest = [s["id"] for s in sorted(by_weapon[c["weapon"]], key=lambda s: (s["unlock_level"], s["id"]))
                if s["id"] not in slot4 and s["id"] not in spec and s["id"] not in base_old]
        c["skills"] = {"base": base_old + rest, "slot4": slot4, "spec": spec}
    CL.write_text(json.dumps(cls, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print("навыков:", len(skills), "новых:", len(NEW))


if __name__ == "__main__":
    main()
