class_name BattleRules
extends RefCounted
## Параметры боя. Хранятся отдельно от логики, чтобы настраивать баланс без правки кода.
## Сетка стороны 3x3: слот = ряд * 3 + колонка, колонка 0 ближайшая к врагу (передняя линия).

const SIDE_A := 0
const SIDE_B := 1
const GRID_COLS := 3
const GRID_ROWS := 3
const SLOTS_PER_SIDE := GRID_COLS * GRID_ROWS

## Сколько бойцов могут действовать на первом ходу стороны.
var active_start := 1
## На сколько растёт это число с каждым следующим ходом той же стороны.
var active_growth := 1
## Потолок числа действующих за ход.
var active_cap := 5
var ap_max := 100
var attack_cost := 40
var move_cost := 30
## Через сколько раундов бой объявляется ничьей.
var max_rounds := 40
## Разброс урона в процентах (±).
var variance_pct := 10
var crit_chance_pct := 5
var crit_mult_pct := 150
## Чем больше число, тем слабее защита снижает урон: урон = атака * K / (K + защита).
var def_scale := 100
