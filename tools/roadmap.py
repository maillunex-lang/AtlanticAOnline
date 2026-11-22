#!/usr/bin/env python3
"""Дорожная карта как единый источник правды: docs/plan/tasks.json.
ROADMAP.md генерируется командой `render`, руками его не правят.

Команды:
  next                    показать следующую задачу (первая готовая по порядку) и всё, что нужно для работы
  show WP-xx              карточка задачи
  start WP-xx [--take]    взять задачу в работу (зависимости должны быть выполнены; чужую задачу брать только с --take)
  done WP-xx --note "..." (--commit HASH | --ci URL | --manual "что проверено") [--tests N]   закрыть задачу с подтверждением
                          (задача должна быть в работе; у ручных задач только --manual)
  partial WP-xx --note "..."   выполнено частично (остаток записать в заметку)
  block WP-xx --note "..."     заблокирована (причина)
  log WP-xx --note "..."       добавить запись в журнал задачи, статус не менять
  note --text "..."        общая запись в журнал проекта (решение, находка, риск)
  ask --text "..." [--wp WP-xx]   вопрос владельцу (решение, которое исполнитель принимать не вправе); работа продолжается над другими задачами
  decide ID --text "..."   записать ответ владельца на вопрос
  tests N                  записать число проходящих тестов
  check                    проверить целостность (зависимости, циклы, ссылки на документы)
  render                   пересобрать ROADMAP.md
"""
import json, sys, os, re, argparse, datetime

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TASKS = os.path.join(ROOT, "docs", "plan", "tasks.json")
OUT = os.path.join(ROOT, "ROADMAP.md")
ST = {"todo": "[ ]", "in_progress": "[~]", "partial": "[◐]", "blocked": "[!]", "done": "[x]"}
WHO = os.environ.get("ROADMAP_AUTHOR", "ИИ-исполнитель")


def load():
    return json.load(open(TASKS, encoding="utf-8"))


def save(d):
    with open(TASKS, "w", encoding="utf-8") as f:
        json.dump(d, f, ensure_ascii=False, indent=1)
        f.write("\n")


def by_id(d):
    return {t["id"]: t for t in d["tasks"]}


def today():
    return datetime.date.today().isoformat()


def ready(d, me=None):
    """Готовые к работе: зависимости выполнены. Чужие задачи в работе не выдаются."""
    ids = by_id(d)
    out = []
    for t in d["tasks"]:
        if t["status"] not in ("todo", "partial", "in_progress"):
            continue
        if not all(x in ids and ids[x]["status"] == "done" for x in t["deps"]):
            continue
        if t["status"] == "in_progress" and t.get("owner") not in (None, me):
            continue
        out.append(t)
    out.sort(key=lambda t: (not (t["status"] == "in_progress" and t.get("owner") == me), t.get("order", 999)))
    return out


def card(d, t):
    ids = by_id(d)
    ph = d["phases"][t["phase"]]
    L = [f"{t['id']}  {t['title']}  [{t['status']}]  размер {t['size']}",
         f"Фаза: {ph['title']}  (веха {t['milestone']})",
         "Зависит от: " + (", ".join(f"{x} ({ids[x]['status']})" for x in t["deps"]) or "—") + (f"  ({t['deps_note']})" if t.get("deps_note") else ""),
         "Что сделать: " + t["what"],
         "Приёмка: " + t["acceptance"],
         "Читать до начала: " + "; ".join(["docs/plan/DESIGN_GUARD.md"] + t["sources"]),
         "Шлюз GitHub: " + ph["gate"] + " (docs/plan/GITHUB_RESEARCH.md)"]
    if t.get("notes"):
        L.append("Заметки: " + t["notes"])
    for e in t.get("log", []):
        L.append(f"  - {e['date']} {e['who']}" + (f" {e['commit']}" if e.get("commit") else "") + f": {e['text']}")
    return "\n".join(L)


def render(d):
    ids = by_id(d)
    tasks = d["tasks"]
    n = {k: sum(1 for t in tasks if t["status"] == k) for k in ST}
    total = len(tasks)
    completion = n["done"] * 100 // total if total else 0
    rd = ready(d, None)
    cur = [t for t in tasks if t["status"] == "in_progress"]
    L = []
    A = L.append
    A("# ROADMAP — Atlantic Online")
    A("")
    A("> **Файл сгенерирован** `python3 tools/roadmap.py render` из `docs/plan/tasks.json`. Руками не править: меняйте задачи командами `tools/roadmap.py`.")
    A("")
    A("## 0. Как работать (одинаково для любого ИИ-исполнителя; вы и директор, и исполнитель)")
    A("")
    A("**Роль директора (выбор и контроль):**")
    A("1. Прочитайте `docs/plan/AI_HANDOFF.md` (состояние проекта, команды, грабли) и `docs/plan/DESIGN_GUARD.md` (что нельзя ломать).")
    A("2. `python3 tools/roadmap.py next` покажет следующую задачу (первая по порядку, у которой выполнены зависимости), документы для чтения, приёмку и шлюз GitHub.")
    A("3. Если задачу уже кто-то взял (`[~]`), не берите её: возьмите следующую из списка «Готовы к работе» ниже.")
    A("4. Если фаза новая: выполните **шлюз** (поиск на GitHub по `docs/plan/GITHUB_RESEARCH.md`), запишите результат в `docs/stages/<фаза>_GITHUB_CANDIDATES.md`.")
    A("")
    A("**Роль исполнителя (работа):**")
    A("5. `python3 tools/roadmap.py start WP-xx` (отметка «в работе»).")
    A("6. Прочитайте источники из карточки (`show WP-xx`): правила оригинала в `docs/plan/wiki/`, дизайн в соответствующих GDD и документах `docs/plan/`.")
    A("7. Реализуйте: логика в `src/shared` (чистая, детерминированная), числа и контент в `data/*.json`, тесты gdUnit4, для интерфейса скриншоты (16:9 и 2.2:1). Команды сборки и тестов в `docs/plan/AI_HANDOFF.md`.")
    A("8. **Приёмка (директор проверяет себя):** все тесты зелёные, `GameData.validate()` проходит, критерий приёмки из карточки выполнен, нет нарушений DESIGN_GUARD.md, документ раздела обновлён, `docs/DECISIONS.md` дополнен, если приняты решения.")
    A("9. Закройте: `python3 tools/roadmap.py done WP-xx --note \"что сделано, что осталось, какие решения\" --commit <хеш> --tests <число>`; затем `python3 tools/roadmap.py render`. Частично выполнено: `partial` (остаток опишите, он остаётся в очереди). Мешает внешняя причина: `block`.")
    A("10. Начинайте работу в отдельной ветке от актуальной `origin/main`. После проверок включите код, данные, `tasks.json` и сгенерированный `ROADMAP.md` в один этап, слейте в `main` и проверьте удалённый коммит. При конфликте или красных проверках остановите слияние. Force push запрещён.")
    A("")
    A("**Правила журнала:** любое решение, находку, ошибку или риск записывайте `tools/roadmap.py note --text \"...\"` или `log WP-xx --note \"...\"`; честно отмечайте непроверенное («на устройстве не запускалось»). Правила работают без истории чата: всё нужное лежит в репозитории.")
    A("")
    A("**Полномочия (что решает исполнитель-директор, что владелец):**")
    A("- *Решает исполнитель сам:* реализация и структура кода; числа баланса в данных; контент по плану (свои названия и тексты); выбор библиотек MIT/Apache/BSD/CC0/CC-BY по шлюзу GitHub; исправления и тесты; обновление документов; порядок работ в рамках зависимостей. Решение записывается в `docs/DECISIONS.md`.")
    A("- *Только с ответом владельца (`ask`, затем ждать `decide`):* изменение правил `docs/plan/DESIGN_GUARD.md` и утверждённых механик в GDD; смена движка, серверной модели, подключение внешнего бэкенда (например, Nakama) сверх оценки; модель монетизации, цены, валюты; юридические решения и политика магазина; смена визуального стиля; удаление или замена утверждённой функции; любые платные сервисы и учётные данные; правки истории репозитория.")
    A("- *Где хранится утверждение:* вопрос и ответ в разделе «Ждут решения владельца» и в `docs/plan/tasks.json` (`pending_decisions`), итог переносится в `docs/DECISIONS.md` со словами «утверждено владельцем» и датой.")
    A("- Пока ответа нет, исполнитель не блокирует проект: берёт другие готовые задачи; если задача целиком зависит от решения, помечает её `block`.")
    A("")
    A("**Статусы:** `[ ]` не начата, `[~]` в работе, `[◐]` частично (остаток в заметке), `[!]` заблокирована, `[x]` сделано.")
    A("")
    A("## 1. Состояние")
    A(f"- Готово **{n['done']}/{total} ({completion}%)**. Частично {n['partial']}, в работе {n['in_progress']}, заблокировано {n['blocked']}, не начато {n['todo']}.")
    A(f"- Тестов проходит: **{d['meta']['tests']}** (на {d['meta']['tests_date']}).")
    if d["meta"].get("verified_commit") and d["meta"].get("verified_ci"):
        A(f"- Проверенная база: `{d['meta']['verified_commit']}`. [GitHub Actions]({d['meta']['verified_ci']}).")
    if ids.get("WP-03", {}).get("status") == "done":
        A("- Проверка APK на физическом Android закрыта (WP-03). Детали и оставшиеся замеры указаны в журнале.")
    else:
        A("- Проверка APK на физическом Android отслеживается в WP-03.")
    A("- Демо использует общее ядро `src/shared`. SQLite и тестовый вход по ENet готовы. Полный сетевой сценарий движения, боя и награды относится к M3.")
    A("- Видение зафиксировано: пиксель-арт 16x16 x4, вид сверху, бой формаций 3x3, горизонтальная ориентация (`docs/GDD.md` п. 2.1). Графика Kenney CC0 временная.")
    A("")
    A("## 2. Сейчас делать")
    if cur:
        A("**В работе:** " + ", ".join(f"{t['id']} {t['title']} ({t.get('owner', '?')})" for t in cur))
    if rd:
        t = rd[0]
        A(f"**Следующая задача: {t['id']} — {t['title']}** (размер {t['size']}, фаза «{d['phases'][t['phase']]['title']}»).")
        A(f"- Что сделать: {t['what']}")
        A(f"- Приёмка: {t['acceptance']}")
        A("- Читать: " + "; ".join(t["sources"]))
        A("")
        A("Готовы к работе (зависимости выполнены), по порядку:")
        for t in rd[:12]:
            A(f"- {t['id']} {t['title']} ({t['size']})")
    blocked = [t for t in tasks if t["status"] == "blocked"]
    if blocked:
        A("")
        A("**Заблокированные задачи:**")
        for t in blocked:
            reason = next((e["text"].removeprefix("ЗАБЛОКИРОВАНО: ") for e in reversed(t.get("log", []))
                           if e["text"].startswith("ЗАБЛОКИРОВАНО: ")), "")
            A(f"- {t['id']} {t['title']}. {reason}".rstrip())
    op = [q for q in d.get("pending_decisions", []) if q["status"] == "open"]
    A("")
    A("**Ждут решения владельца** (исполнитель продолжает другие задачи):")
    if not op:
        A("- Открытых вопросов нет.")
    for q in op:
        A(f"- #{q['id']} ({q['date']}" + (f", {q['wp']}" if q.get("wp") else "") + f"): {q['text']}")
    A("")
    A("## 3. Вехи")
    A("| Веха | Содержание | Задач | Готово |")
    A("|------|-----------|--------|--------|")
    for m in d["milestones"]:
        ts = [t for t in tasks if t["milestone"] == m["id"]]
        dn = sum(1 for t in ts if t["status"] == "done")
        A(f"| {m['id']} | {m['title']} | {len(ts)} | {dn}/{len(ts)} |")
    A("")
    A("## 4. Все задачи по порядку")
    A("Таблицы сгруппированы по фазам. **Порядок выполнения задаёт поле `order` в tasks.json** (его учитывает `next`); зависимости обязательны. Сеть (фаза 7) можно вести параллельно фазам 2-4.")
    for pid, ph in d["phases"].items():
        A("")
        A(f"### {ph['title']}")
        A(f"Шлюз GitHub: {ph['gate']}. Источники: " + "; ".join(ph["sources"]))
        A("")
        A("| | WP | Задача | Разм. | Зависит | Приёмка |")
        A("|--|----|--------|-------|---------|---------|")
        for t in tasks:
            if t["phase"] != pid:
                continue
            dep = ", ".join(t["deps"]) or "—"
            if t.get("deps_note"):
                dep += f" ({t['deps_note']})"
            A(f"| {ST[t['status']]} | {t['id']} | {t['title']} | {t['size']} | {dep} | {t['acceptance']} |")
    A("")
    A("## 5. Журнал работ (последние 25 записей)")
    ent = []
    for t in tasks:
        for e in t.get("log", []):
            ent.append((e["date"], t["id"], e))
    for e in d.get("journal", []):
        ent.append((e["date"], "—", e))
    ent.sort(key=lambda x: x[0], reverse=True)
    if not ent:
        A("Записей пока нет.")
    for date, tid, e in ent[:25]:
        A(f"- {date} **{tid}** {e['who']}" + (f" (`{e['commit']}`)" if e.get("commit") else "") + f": {e['text']}")
    A("")
    A("## 6. Известные пробелы и риски")
    for r in d["risks"]:
        A(f"- {r}")
    A("")
    A("## 7. Где что лежит")
    A("- Вход для Claude Code: [CLAUDE.md](CLAUDE.md). Протокол и состояние проекта: `docs/plan/AI_HANDOFF.md`. Охранные правила: `docs/plan/DESIGN_GUARD.md`. Описание всех систем: `docs/plan/GAME_SPEC.md`.")
    A("- Правила оригинала и числа: `docs/plan/wiki/` и `docs/plan/reference/wiki_numbers.json`. Мир: `docs/plan/WORLD_DESIGN.md`. Квесты: `docs/plan/QUEST_DESIGN.md`. Как добавлять контент: `docs/plan/CONTENT_PIPELINE.md`.")
    A("- Задания для Kimi (WP-101): [дизайн героев](docs/plan/art/KIMI_HERO_DESIGN.md) и [анимация героев](docs/plan/art/KIMI_HERO_ANIMATION.md).")
    A("- Принятое и реализованное: `docs/GDD*.md`, `docs/DECISIONS.md`. Поиск на GitHub: `docs/plan/GITHUB_RESEARCH.md`, результаты `docs/stages/`. Указатель: `docs/README.md`.")
    open(OUT, "w", encoding="utf-8").write("\n".join(L) + "\n")


def check(d):
    ids = by_id(d)
    err = []
    if len(ids) != len(d["tasks"]):
        err.append("повторяющиеся id")
    for t in d["tasks"]:
        if t["status"] not in ST:
            err.append(f"{t['id']}: статус {t['status']}")
        if t["phase"] not in d["phases"]:
            err.append(f"{t['id']}: нет фазы")
        for x in t["deps"]:
            if x not in ids:
                err.append(f"{t['id']}: нет зависимости {x}")
        for s in t["sources"]:
            p = s.split("#")[0].split(" ")[0]
            if not os.path.exists(os.path.join(ROOT, p)):
                err.append(f"{t['id']}: нет файла {p}")
        if t["status"] == "done" and any(ids[x]["status"] != "done" for x in t["deps"] if x in ids):
            err.append(f"{t['id']}: сделана раньше зависимостей")
        if t["status"] == "done" and not any(e.get("commit") or e.get("ci") or e.get("manual") for e in t.get("log", [])):
            err.append(f"{t['id']}: сделана без подтверждения (коммит, CI или ручная проверка)")
        if t["status"] == "in_progress" and not t.get("owner"):
            err.append(f"{t['id']}: в работе без владельца")
    seen, stack = set(), set()

    def dfs(x):
        if x in stack:
            err.append(f"цикл через {x}")
            return
        if x in seen:
            return
        stack.add(x)
        for y in ids[x]["deps"]:
            if y in ids:
                dfs(y)
        stack.discard(x)
        seen.add(x)
    for x in ids:
        dfs(x)
    return err


def main():
    ap = argparse.ArgumentParser(add_help=False)
    ap.add_argument("cmd")
    ap.add_argument("arg", nargs="?")
    ap.add_argument("--note", default="")
    ap.add_argument("--text", default="")
    ap.add_argument("--commit", default="")
    ap.add_argument("--tests", default="")
    ap.add_argument("--ci", default="")
    ap.add_argument("--manual", default="")
    ap.add_argument("--take", action="store_true")
    ap.add_argument("--wp", default="")
    a = ap.parse_args()
    d = load()
    ids = by_id(d)
    c = a.cmd
    if c in ("-h", "--help", "help"):
        print(__doc__)
        return
    if c == "next":
        rd = ready(d, WHO)
        if not rd:
            print("Готовых задач нет: проверьте блокировки (`check`).")
            return
        print(card(d, rd[0]))
        mine = rd[0]["status"] == "in_progress" and rd[0].get("owner") == WHO
        print("\n" + ("Это ваша задача в работе: продолжайте её." if mine else "Свободная задача: возьмите командой start."))
        print("Другие готовые: " + ", ".join(t["id"] for t in rd[1:8]))
        busy = [t for t in d["tasks"] if t["status"] == "in_progress" and t.get("owner") != WHO]
        if busy:
            print("Заняты другими: " + ", ".join(f"{t['id']} ({t['owner']})" for t in busy))
        return
    if c == "show":
        print(card(d, ids[a.arg]))
        return
    if c in ("start", "done", "partial", "block", "log"):
        if a.arg not in ids:
            sys.exit("нет такой задачи")
        t = ids[a.arg]
        ev = {}
        for k in ("commit", "ci", "manual"):
            if getattr(a, k):
                ev[k] = getattr(a, k)
        entry = lambda txt: {"date": today(), "who": WHO, "text": txt, **ev}
        if t["status"] == "done" and c != "log":
            sys.exit(f"{t['id']} уже выполнена; повторное открытие делайте через `log` и новую задачу")
        if c == "start":
            miss = [x for x in t["deps"] if ids[x]["status"] != "done"]
            if miss:
                sys.exit("зависимости не выполнены: " + ", ".join(miss) + (f" ({t['deps_note']})" if t.get("deps_note") else ""))
            if t["status"] == "in_progress":
                if t.get("owner") == WHO:
                    sys.exit("задача уже ваша, продолжайте работу")
                if not a.take:
                    sys.exit(f"задача занята: {t.get('owner')}; чтобы забрать, укажите --take")
            t["status"] = "in_progress"
            t["owner"] = WHO
            t.setdefault("log", []).append(entry("взята в работу" + (" (перехвачена)" if a.take else "")))
        elif c == "done":
            if not a.note:
                sys.exit("нужен --note с отчётом")
            if t["status"] not in ("in_progress", "partial"):
                sys.exit("закрывать можно задачу в работе: сначала `start`")
            if t["status"] == "in_progress" and t.get("owner") != WHO and not a.take:
                sys.exit(f"задача в работе у {t.get('owner')}")
            miss = [x for x in t["deps"] if ids[x]["status"] != "done"]
            if miss:
                sys.exit("зависимости не выполнены: " + ", ".join(miss))
            if t.get("manual"):
                if not a.manual:
                    sys.exit("задача ручная: нужно --manual с описанием проверки (устройство, версия, результат)")
            elif not ev:
                sys.exit("нужно подтверждение: --commit ХЕШ, --ci ССЫЛКА или --manual ОПИСАНИЕ")
            t["status"] = "done"
            t["done_date"] = today()
            t.pop("owner", None)
            t.setdefault("log", []).append(entry("СДЕЛАНО: " + a.note))
        elif c == "partial":
            t["status"] = "partial"
            t.pop("owner", None)
            t.setdefault("log", []).append(entry("ЧАСТИЧНО: " + a.note))
        elif c == "block":
            t["status"] = "blocked"
            t.pop("owner", None)
            t.setdefault("log", []).append(entry("ЗАБЛОКИРОВАНО: " + a.note))
        else:
            t.setdefault("log", []).append(entry(a.note))
        if a.tests:
            d["meta"]["tests"] = int(a.tests)
            d["meta"]["tests_date"] = today()
    elif c == "ask":
        qs = d.setdefault("pending_decisions", [])
        qs.append({"id": (max([q["id"] for q in qs]) + 1) if qs else 1, "date": today(), "who": WHO, "wp": a.wp, "text": a.text or a.note, "status": "open"})
    elif c == "decide":
        q = next((q for q in d.get("pending_decisions", []) if str(q["id"]) == str(a.arg)), None)
        if not q:
            sys.exit("нет такого вопроса")
        q["status"] = "answered"
        q["answer"] = a.text or a.note
        q["answer_date"] = today()
        d.setdefault("journal", []).append({"date": today(), "who": WHO, "text": f"Ответ владельца на вопрос #{q['id']}: {q['answer']}"})
    elif c == "note":
        d.setdefault("journal", []).append({"date": today(), "who": WHO, "text": a.text or a.note, **({"commit": a.commit} if a.commit else {})})
    elif c == "tests":
        d["meta"]["tests"] = int(a.arg)
        d["meta"]["tests_date"] = today()
    elif c == "check":
        e = check(d)
        print("OK" if not e else "\n".join(e))
        sys.exit(1 if e else 0)
    elif c == "render":
        pass
    else:
        sys.exit("неизвестная команда, см. help")
    save(d)
    render(d)
    print("готово: tasks.json и ROADMAP.md обновлены")


if __name__ == "__main__":
    main()
