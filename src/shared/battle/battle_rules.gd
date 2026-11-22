class_name BattleRules
extends RefCounted
## Параметры боя. Хранятся отдельно от логики, чтобы настраивать баланс без правки кода.
## Сетка стороны 3x3: слот = ряд * 3 + колонка, колонка 0 ближайшая к врагу (передняя линия).
## Модель очков действий (AP) повторяет правила оригинала (docs/plan/COMBAT_REVISION.md, WP-10).

const SIDE_A := 0
const SIDE_B := 1
const GRID_COLS := 3
const GRID_ROWS := 3
const SLOTS_PER_SIDE := GRID_COLS * GRID_ROWS

## Минимум AP, чтобы боец мог действовать в свой ход.
var ap_act_threshold := 100
## Границы запаса AP.
var ap_max := 299
var ap_min := -50
## Сколько бойцов одной стороны могут действовать за ход (берутся с наибольшим AP).
var active_cap := 5
## Стоимость действий в AP. Навыки имеют свою цену в данных.
var attack_cost := 100
## Бонус к базовой атаке за свободные места в своей формации.
var attack_empty_slot_pct := 12
var attack_empty_slot_cap := 3
var guard_cost := 50
var move_cost := 50
## Добавка к приросту AP за каждого отсутствующего бойца полной формации (в оригинале прирост растёт, точная формула не подтверждена).
var ap_gain_per_missing := 0
var reserve_swap_limit := 0
var battle_rooms := 0
## Защита (Guard): бонус к защите в процентах до начала следующего хода бойца.
var guard_def_pct := 50
## Сколько физических попаданий подряд (по ходам) оглушают бойца.
var stun_combo := 3
## Восстановление маны за свой ход, в процентах от максимума.
var mp_regen_pct := 10
## Время хода игрока в секундах (применяют PvP-матч и клиент).
var turn_seconds := 30
## Через сколько раундов бой объявляется ничьей.
var max_rounds := 40
## Сколько ходов подряд никто не может действовать, прежде чем объявить ничью.
var max_idle_turns := 12
## Разброс урона в процентах (±).
var variance_pct := 10
var crit_chance_pct := 5
var crit_mult_pct := 150
var hit_chance_pct := 100
var multi_hit_power_pct := 50
var multi_hit_combo_pct := 5
## Чем больше число, тем слабее защита снижает урон: урон = атака * K / (K + защита).
var def_scale := 100
## Прирост силы навыка за каждый его уровень, в процентах.
var skill_power_per_level_pct := 10
